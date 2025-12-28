extends Area3D

## ProjectileBall - EnemyShooter'dan fırlatılan kırmızı top (deflect edilebilir, sarıya döner)
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
	add_to_group("projectile")
	_initialize_life_timer()
	_setup_mesh_instance()
	_apply_red_material()
	
	# Collision'ı bir frame sonra aktif et (spawn collision'ı önlemek için)
	# Önce collision mask'i ayarla ama signal'ları sonra bağla
	_setup_collision_mask(false)
	
	# Signal'ları bir frame sonra bağla (spawn collision'ı önlemek için)
	call_deferred("_connect_signals")
	
	# Collision detection'ı bir frame geciktir (spawn anında hemen collision algılamasın)
	monitoring = false
	call_deferred("_enable_monitoring")
	
	if debug_enabled:
		print("[PROJECTILE] Spawned at position: ", global_position, " color=RED, enemy-collision=OFF")


func _physics_process(delta: float) -> void:
	life_timer -= delta
	if life_timer <= 0.0:
		if debug_enabled:
			print("[PROJECTILE] Life time expired, destroying")
		queue_free()
		return
	
	# Projectile hareketi (gravity'den etkilenmez - Area3D olduğu için)
	# Velocity sabit kalır, sadece direction * speed ile hareket eder
	global_position += velocity * delta
	
	if _is_out_of_bounds():
		if debug_enabled:
			print("[PROJECTILE] Out of bounds (x=", global_position.x, " z=", global_position.z, " y=", global_position.y, "), destroying")
		queue_free()
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
	if is_deflected:
		if debug_enabled:
			print("[PROJECTILE] Already deflected, ignoring duplicate deflect call")
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
	
	if debug_enabled:
		print("[PROJECTILE] Deflected -> yellow, enemy-collision ON, dmg x2")
		print("[PROJECTILE] Deflected! new_velocity=", velocity, " direction=", dir.normalized(), " force=", force)


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
	if debug_enabled:
		print("[PROJECTILE] Monitoring enabled after spawn delay")


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
	mask |= (1 << (LAYER_WORLD - 1))
	mask |= (1 << (LAYER_SHIELD - 1))
	
	if enable_enemy:
		mask |= (1 << (LAYER_ENEMY - 1))
		mask &= ~(1 << (LAYER_PLAYER - 1))
	else:
		mask |= (1 << (LAYER_PLAYER - 1))
		mask &= ~(1 << (LAYER_ENEMY - 1))
	
	collision_mask = mask
	
	if debug_enabled:
		print("[PROJECTILE] Collision mask updated. Enemy enabled: ", enable_enemy)

# ============================================
# PRIVATE HELPERS - COLLISION HANDLING
# ============================================
func _on_body_entered(body: Node) -> void:
	_handle_collision(body)


func _on_area_entered(area: Area3D) -> void:
	if area.name == "BlockArea":
		return
	
	_handle_collision(area)


func _handle_collision(target: Node) -> void:
	if _is_player(target):
		_hit_player(target)
		return
	
	if _is_enemy(target):
		_hit_enemy(target)
		return
	
	if _is_world(target):
		_hit_world()
		return


func _is_player(target: Node) -> bool:
	return target.is_in_group("player") or (target.get_parent() and target.get_parent().is_in_group("player"))


func _is_enemy(target: Node) -> bool:
	return target.is_in_group("enemy") or (target.get_parent() and target.get_parent().is_in_group("enemy"))


func _is_world(target: Node) -> bool:
	return target is StaticBody3D or (target is CharacterBody3D and not target.is_in_group("player") and not target.is_in_group("enemy"))


func _hit_player(target: Node) -> void:
	if is_deflected:
		if debug_enabled:
			print("[PROJECTILE] Deflected projectile hit player, ignoring damage")
		queue_free()
		return
	
	var player = _find_player_root(target)
	if not player:
		queue_free()
		return
	
	if player.has_method("take_damage"):
		player.take_damage(base_damage)
		if debug_enabled:
			print("[PROJECTILE] Hit player for ", base_damage, " damage!")
	else:
		if debug_enabled:
			print("[PROJECTILE] Hit player but no take_damage method found!")
	
	queue_free()


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
		if debug_enabled:
			print("[PROJECTILE] ERROR: Non-deflected projectile hit enemy (should not happen)!")
		queue_free()
		return
	
	var enemy = find_enemy_root(target)
	if not enemy:
		if debug_enabled:
			print("[PROJECTILE] Hit enemy collider but could not find enemy root!")
		queue_free()
		return
	
	# Deflect edilmiş projectile kendi sahibini (orijinal shooter) vurmamalı
	if original_shooter and enemy == original_shooter:
		if debug_enabled:
			print("[PROJECTILE] Deflected projectile hit its original owner (", enemy.name, "), ignoring to prevent self-damage!")
		queue_free()
		return
	
	var final_damage = base_damage * damage_multiplier
	_apply_damage_to_enemy(enemy, final_damage)
	_apply_knockback_to_enemy(enemy)
	queue_free()


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
		if debug_enabled:
			print("[PROJECTILE] Hit enemy: ", enemy.name, " damage=", damage)
	elif enemy.has_method("hit"):
		enemy.hit(damage)
		if debug_enabled:
			print("[PROJECTILE] Hit enemy: ", enemy.name, " damage=", damage, " (via hit method)")
	else:
		if debug_enabled:
			print("[PROJECTILE] Hit enemy but no take_damage/hit method found!")


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
	queue_free()

# ============================================
# PRIVATE HELPERS - UTILITY
# ============================================
func _is_out_of_bounds() -> bool:
	return abs(global_position.x) > MAP_BOUNDS or abs(global_position.z) > MAP_BOUNDS or abs(global_position.y) > MAP_BOUNDS
