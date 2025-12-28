extends Area3D

## ProjectileBall - EnemyShooter'dan fırlatılan kırmızı top (deflect edilebilir, sarıya döner)

# KESİN: Signal'lar (sadece bildirim, gameplay değiştirmez)
signal deflected
signal destroyed
## 
## REFACTOR NOTES:
## 1) Debug log'lar debug_enabled flag ile kontrol edilir
## 2) Color management, collision mask, deflect state ayrı bölümlerde
## 3) Magic number'lar const/export yapıldı
## 4) Tip eklemeleri yapıldı (typed GDScript)
## 5) Erken return pattern kullanıldı

# ============================================
# EXPORT PARAMETERS
# ============================================
@export var speed: float = 18.0
@export var base_damage: int = 1
@export var life_time: float = 3.0
@export var push_strength: float = 10.0

@export_group("Collision Layers")
@export var LAYER_PLAYER: int = 2
@export var LAYER_ENEMY: int = 3
@export var LAYER_WORLD: int = 1
@export var LAYER_SHIELD: int = 5

@export_group("Debug")
@export var debug_enabled: bool = false

# ============================================
# CONSTANTS
# ============================================
const MAP_BOUNDS: float = 15.0
const DEFLECT_OFFSET: float = 0.3
const DEFLECT_DAMAGE_MULTIPLIER: int = 2
const RED_COLOR: Color = Color(1, 0, 0, 1)
const YELLOW_COLOR: Color = Color(1, 1, 0, 1)
const MATERIAL_METALLIC: float = 0.0
const MATERIAL_ROUGHNESS: float = 0.5

# ============================================
# NODE REFERENCES
# ============================================
var mesh_instance: MeshInstance3D = null
var material: StandardMaterial3D = null

# ============================================
# RUNTIME STATE
# ============================================
var velocity: Vector3 = Vector3.ZERO
var projectile_owner: Node = null
var original_shooter: Node = null  # Orijinal shooter (deflect edildikten sonra da korunur, kendi kendine vurmayı önlemek için)
var is_deflected: bool = false
var life_timer: float = 0.0
var damage_multiplier: int = 1

# ============================================
# GODOT CALLBACKS
# ============================================
func _ready() -> void:
	# DEBUG: Projectile ROOT tipi
	print("[Projectile] ready type=", get_class(), " root=", name)
	
	add_to_group("projectile")
	_initialize_life_timer()
	_setup_mesh_instance()
	_apply_red_material()
	
	# Area3D'ler birbirini algılamak için monitorable = true olmalı (BlockArea projectile'ı algılayabilmek için)
	monitorable = true
	
	# TEST AMAÇLI: Collision layer/mask ALL
	collision_layer = 4294967295
	collision_mask = 4294967295
	print("[Projectile] TEST: collision_layer=ALL mask=ALL monitorable=", monitorable)
	
	# Signal'ları bir frame sonra bağla (spawn collision'ı önlemek için)
	call_deferred("_connect_signals")
	
	# Collision detection'ı bir frame geciktir (spawn anında hemen collision algılamasın)
	monitoring = false
	call_deferred("_enable_monitoring")
	
	print("[Projectile] Spawned at position: ", global_position, " color=RED, enemy-collision=OFF")


func _physics_process(delta: float) -> void:
	# Velocity 0 ise hareket etme (henüz setup çağrılmamış olabilir)
	if velocity.length() < 0.01:
		return
	
	# ZORUNLU STATE: is_deflected true ise yön tekrar hesaplanmayacak
	# (homing / follow / aim logic DEVRE DIŞI)
	if is_deflected:
		# Deflect edildikten sonra velocity sabit kalır, overwrite edilmez
		pass
	
	life_timer -= delta
	if life_timer <= 0.0:
		if debug_enabled:
			print("[PROJECTILE] Life time expired, destroying")
		_destroy_projectile()
		return
	
	# Projectile hareketi (gravity'den etkilenmez - Area3D olduğu için)
	# Velocity sabit kalır, sadece direction * speed ile hareket eder
	global_position += velocity * delta
	
	if _is_out_of_bounds():
		if debug_enabled:
			print("[PROJECTILE] Out of bounds (x=", global_position.x, " z=", global_position.z, " y=", global_position.y, "), destroying")
		_destroy_projectile()
		return

# ============================================
# PUBLIC API
# ============================================
func setup(direction: Vector3, projectile_speed: float, projectile_damage: int, shooter: Node = null) -> void:
	"""Projectile ayarlarını yap (EnemyShooter'dan çağrılır)."""
	# Direction'ı normalize et ve velocity'yi ayarla
	var normalized_direction = direction.normalized()
	velocity = normalized_direction * projectile_speed
	speed = projectile_speed
	base_damage = projectile_damage
	projectile_owner = shooter
	original_shooter = shooter  # Orijinal shooter'ı sakla (deflect edildikten sonra da korunur)
	is_deflected = false
	damage_multiplier = 1
	_setup_collision_mask(false)
	
	if debug_enabled:
		print("[PROJECTILE] Setup: direction=", normalized_direction, " velocity=", velocity, " speed=", projectile_speed, " base_damage=", base_damage, " original_shooter=", shooter)


func deflect(dir: Vector3, force: float, source: Node) -> void:
	"""Projectile'i deflect et (kalkan tarafından çağrılır)."""
	print("[Projectile] deflect() called. is_deflected=", is_deflected, " dir=", dir, " force=", force)
	
	if is_deflected:
		print("[Projectile] Already deflected, ignoring duplicate deflect call")
		return
	
	is_deflected = true
	projectile_owner = source
	damage_multiplier = DEFLECT_DAMAGE_MULTIPLIER
	
	# Deflect direction'ı normalize et ve velocity'yi ayarla
	var normalized_dir = dir.normalized()
	velocity = normalized_dir * force
	speed = force  # Speed'i de güncelle
	global_position += normalized_dir * DEFLECT_OFFSET
	
	apply_color(YELLOW_COLOR)
	_setup_collision_mask(true)
	
	# KESİN: Deflect signal'ı emit et
	deflected.emit()
	
	print("[Projectile] deflected OK -> yellow, enemy-collision ON, dmg x2")
	print("[Projectile] Deflected! new_velocity=", velocity, " direction=", dir.normalized(), " force=", force)


func apply_color(color: Color) -> void:
	"""MeshInstance3D'ye renk uygula (runtime)."""
	if not mesh_instance:
		return
	
	if not material:
		_create_material()
	
	material.albedo_color = color

# ============================================
# PRIVATE HELPERS - SETUP
# ============================================
func _connect_signals() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _enable_monitoring() -> void:
	"""Collision monitoring'i aktif et (spawn collision'ı önlemek için bir frame sonra)."""
	monitoring = true
	print("[Projectile] Monitoring enabled. monitoring=", monitoring, " monitorable=", monitorable, " layer=", collision_layer, " mask=", collision_mask)


func _initialize_life_timer() -> void:
	life_timer = life_time


func _setup_mesh_instance() -> void:
	mesh_instance = get_node_or_null("MeshInstance3D")
	if not mesh_instance and debug_enabled:
		print("WARNING: ProjectileBall - MeshInstance3D not found!")


func _create_material() -> void:
	material = StandardMaterial3D.new()
	material.metallic = MATERIAL_METALLIC
	material.roughness = MATERIAL_ROUGHNESS
	mesh_instance.material_override = material


func _apply_red_material() -> void:
	apply_color(RED_COLOR)


func _setup_collision_mask(enable_enemy: bool) -> void:
	var mask = 0
	# Layer 1: World, Shield ve Enemy (hepsi layer 1'de)
	mask |= (1 << (LAYER_WORLD - 1))  # Layer 1: World, Shield ve Enemy
	
	if enable_enemy:
		# Enemy'ler de layer 1'de olduğu için zaten mask'te var
		# Player'ı kaldır
		mask &= ~(1 << (LAYER_PLAYER - 1))
	else:
		# Player layer'ını ekle
		mask |= (1 << (LAYER_PLAYER - 1))
	
	collision_mask = mask
	
	print("[PROJECTILE] Collision mask updated. Enemy enabled: ", enable_enemy, " mask=", mask, " (Layer 1 = World+Shield+Enemy)")

# ============================================
# PRIVATE HELPERS - COLLISION HANDLING
# ============================================
func _on_body_entered(body: Node) -> void:
	print("[Projectile] body_entered:", body.name, " type=", body.get_class(), " groups=", body.get_groups(), " is_deflected=", is_deflected)
	
	# Shield ile collision kontrolü (en önce)
	if body.is_in_group("shield"):
		var shield = body
		if shield.has_method("get_deflect_direction_with_assist"):
			# Shield tutuluyor mu kontrol et
			if shield.has_method("is_shield_held") and shield.is_shield_held():
				print("[PROJECTILE] Hit shield body, deflecting...")
				# Deflect direction'ı al
				var deflect_dir = shield.get_deflect_direction_with_assist()
				var deflect_force = shield.deflect_force if "deflect_force" in shield else 26.0
				deflect(deflect_dir, deflect_force, shield)
				# Shield'in consume_block metodunu çağır
				if shield.has_method("consume_block"):
					shield.consume_block()
				return
	
	_handle_collision(body)


func _on_area_entered(area: Area3D) -> void:
	print("[Projectile] area_entered:", area.name, " type=", area.get_class(), " groups=", area.get_groups(), " is_deflected=", is_deflected)
	
	# BlockArea veya shield ile collision (Area3D olarak)
	if area.name == "BlockArea":
		var shield = area.get_parent()
		if shield and shield.is_in_group("shield"):
			print("[Projectile] Hit BlockArea, shield found:", shield.name)
			# ShieldItem zaten _try_deflect'i çağıracak, burada sadece log
			return
	
	_handle_collision(area)


func _handle_collision(target: Node) -> void:
	print("[Projectile] _handle_collision:", target.name, " type=", target.get_class(), " is_deflected=", is_deflected)
	
	# Shield/BlockArea kontrolü (en önce kontrol et)
	if _is_shield(target):
		# Shield deflect işlemi ShieldItem tarafından yapılacak
		# Burada sadece return et, deflect zaten ShieldItem'de yapılıyor
		print("[Projectile] Collision with shield, ignoring (deflect already handled)")
		return
	
	if _is_player(target):
		_hit_player(target)
		return
	
	if _is_enemy(target):
		print("[Projectile] Enemy detected, calling _hit_enemy")
		_hit_enemy(target)
		return
	
	if _is_world(target):
		_hit_world()
		return
	
	print("[Projectile] Unknown collision target, ignoring")


func _is_player(target: Node) -> bool:
	return target.is_in_group("player") or (target.get_parent() and target.get_parent().is_in_group("player"))


func _is_shield(target: Node) -> bool:
	"""Shield veya BlockArea mı kontrol et."""
	if target.name == "BlockArea":
		var shield = target.get_parent()
		if shield and shield.is_in_group("shield"):
			return true
	return target.is_in_group("shield") or (target.get_parent() and target.get_parent().is_in_group("shield"))


func _is_enemy(target: Node) -> bool:
	return target.is_in_group("enemy") or (target.get_parent() and target.get_parent().is_in_group("enemy"))


func _is_world(target: Node) -> bool:
	# Sadece StaticBody3D'leri world olarak algıla, CharacterBody3D'leri değil
	# (CharacterBody3D'ler enemy veya player olabilir)
	return target is StaticBody3D


func _hit_player(target: Node) -> void:
	if is_deflected:
		if debug_enabled:
			print("[PROJECTILE] Deflected projectile hit player, ignoring damage")
		_destroy_projectile()
		return
	
	var player = _find_player_root(target)
	if not player:
		_destroy_projectile()
		return
	
	if player.has_method("take_damage"):
		player.take_damage(base_damage)
		if debug_enabled:
			print("[PROJECTILE] Hit player for ", base_damage, " damage!")
	else:
		if debug_enabled:
			print("[PROJECTILE] Hit player but no take_damage method found!")
	
	_destroy_projectile()


func _find_player_root(target: Node) -> Node:
	var player = target
	if target.get_parent() and target.get_parent().is_in_group("player"):
		player = target.get_parent()
	
	if player is Node3D and not player is CharacterBody3D:
		var character_body = player.get_node_or_null("CharacterBody3D")
		if character_body:
			player = character_body
	
	return player


func _hit_enemy(target: Node) -> void:
	if not is_deflected:
		print("[PROJECTILE] ERROR: Non-deflected projectile hit enemy (should not happen)!")
		_destroy_projectile()
		return
	
	var enemy = find_enemy_root(target)
	if not enemy:
		print("[PROJECTILE] Hit enemy collider but could not find enemy root! Target: ", target.name, " class: ", target.get_class())
		_destroy_projectile()
		return
	
	# Deflect edilmiş projectile kendi sahibini (orijinal shooter) vurmamalı
	if original_shooter and enemy == original_shooter:
		print("[PROJECTILE] Deflected projectile hit its original owner (", enemy.name, "), ignoring to prevent self-damage!")
		_destroy_projectile()
		return
	
	var final_damage = base_damage * damage_multiplier
	print("[PROJECTILE] Deflected projectile hitting enemy: ", enemy.name, " damage=", final_damage, " (base=", base_damage, " x multiplier=", damage_multiplier, ")")
	_apply_damage_to_enemy(enemy, final_damage)
	_apply_knockback_to_enemy(enemy)
	_destroy_projectile()


func find_enemy_root(node: Node) -> Node:
	"""Enemy root'u bul (parent chain'de ara)."""
	var cur: Node = node
	while cur != null:
		if cur.is_in_group("enemy"):
			return cur
		
		if cur.has_method("take_damage"):
			return cur
		
		cur = cur.get_parent()
	
	return null


func _apply_damage_to_enemy(enemy: Node, damage: int) -> void:
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
		print("[PROJECTILE] Hit enemy: ", enemy.name, " damage=", damage)
	elif enemy.has_method("hit"):
		enemy.hit(damage)
		print("[PROJECTILE] Hit enemy: ", enemy.name, " damage=", damage, " (via hit method)")
	else:
		print("[PROJECTILE] Hit enemy but no take_damage/hit method found! Enemy: ", enemy.name, " class: ", enemy.get_class())


func _apply_knockback_to_enemy(enemy: Node) -> void:
	if not is_deflected:
		return
	
	var push_dir = velocity.normalized()
	if enemy.has_method("apply_knockback"):
		enemy.apply_knockback(push_dir, push_strength)
	elif enemy.has_method("knockback"):
		enemy.knockback(push_dir, push_strength)
	elif debug_enabled:
		print("[PROJECTILE] Enemy has no knockback method")


func _hit_world() -> void:
	if debug_enabled:
		print("[PROJECTILE] Hit world, destroyed!")
	_destroy_projectile()

# ============================================
# PRIVATE HELPERS - UTILITY
# ============================================
func _is_out_of_bounds() -> bool:
	# MAP_BOUNDS çok küçük olabilir, daha büyük bir değer kullan
	var bounds = 100.0  # Daha büyük bir sınır
	return abs(global_position.x) > bounds or abs(global_position.z) > bounds or abs(global_position.y) > 50.0


func _destroy_projectile() -> void:
	"""KESİN: Projectile'ı yok et (her yok oluş yolunda çağrılır)."""
	# Signal emit et (shooter'a bildir)
	destroyed.emit()
	queue_free()


func _destroy_projectile() -> void:
	"""KESİN: Projectile'ı yok et (her yok oluş yolunda çağrılır)."""
	# Signal emit et (shooter'a bildir)
	destroyed.emit()
	queue_free()
