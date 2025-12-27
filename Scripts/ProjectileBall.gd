extends Area3D

## ProjectileBall - EnemyShooter'dan fırlatılan kırmızı top (deflect edilebilir, sarıya döner)

# ============================================
# EXPORT PARAMETERS
# ============================================
@export var speed: float = 18.0
@export var base_damage: int = 1  # Base damage (deflect sonrası 2x olacak)
@export var life_time: float = 3.0
@export var push_strength: float = 10.0  # Knockback gücü (sadece deflected projectile için)

@export_group("Collision Layers")
@export var LAYER_PLAYER: int = 2
@export var LAYER_ENEMY: int = 3
@export var LAYER_WORLD: int = 1
@export var LAYER_SHIELD: int = 5  # Shield BlockArea için

# ============================================
# INTERNAL VARIABLES
# ============================================
var velocity: Vector3 = Vector3.ZERO
var projectile_owner: Node = null  # Projectile'i fırlatan (EnemyShooter)
var is_deflected: bool = false
var life_timer: float = 0.0
var damage_multiplier: int = 1  # Deflect sonrası 2 olacak

var mesh_instance: MeshInstance3D = null
var material: StandardMaterial3D = null

# ============================================
# READY
# ============================================
func _ready() -> void:
	# Gruplara ekle
	add_to_group("projectile")
	
	# Signal'ları bağla
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Life timer başlat
	life_timer = life_time
	
	# MeshInstance3D'yi bul
	mesh_instance = get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		print("WARNING: ProjectileBall - MeshInstance3D not found!")
	
	# Kırmızı materyal set et (başlangıç)
	apply_color(Color(1, 0, 0, 1))  # Kırmızı
	
	# Collision mask ayarla (başlangıç: Player + World + ShieldBlockArea, Enemy KAPALI)
	_setup_collision_mask(false)
	
	print("[PROJECTILE] Spawned at position: ", global_position, " color=RED, enemy-collision=OFF")


func _setup_collision_mask(enable_enemy: bool) -> void:
	"""Collision mask'ı ayarla."""
	var mask = 0
	
	# World layer (her zaman açık)
	mask |= (1 << (LAYER_WORLD - 1))
	
	# Player layer (kırmızı iken açık, sarı iken kapalı olabilir ama şimdilik açık bırakıyoruz)
	if not is_deflected:
		mask |= (1 << (LAYER_PLAYER - 1))
	
	# Shield layer (BlockArea için)
	mask |= (1 << (LAYER_SHIELD - 1))
	
	# Enemy layer (sadece deflect edilmişse açık)
	if enable_enemy:
		mask |= (1 << (LAYER_ENEMY - 1))
	
	collision_mask = mask


func apply_color(color: Color) -> void:
	"""MeshInstance3D'ye renk uygula (runtime)."""
	if not mesh_instance:
		return
	
	# Eğer materyal yoksa oluştur
	if not material:
		material = StandardMaterial3D.new()
		material.metallic = 0.0
		material.roughness = 0.5
		mesh_instance.material_override = material
	
	# Renk set et
	material.albedo_color = color


# ============================================
# SETUP
# ============================================
func setup(direction: Vector3, projectile_speed: float, projectile_damage: int, shooter: Node = null) -> void:
	"""Projectile ayarlarını yap (EnemyShooter'dan çağrılır)."""
	velocity = direction.normalized() * projectile_speed
	speed = projectile_speed
	base_damage = projectile_damage
	projectile_owner = shooter
	is_deflected = false
	damage_multiplier = 1
	print("[PROJECTILE] Setup: velocity=", velocity, " speed=", projectile_speed, " base_damage=", projectile_damage)


# ============================================
# PHYSICS PROCESS
# ============================================
func _physics_process(delta: float) -> void:
	# Life timer
	life_timer -= delta
	if life_timer <= 0.0:
		print("[PROJECTILE] Life time expired, destroying")
		queue_free()
		return
	
	# Hareket (SADECE velocity kullan, ASLA player'a tekrar yönelme)
	global_position += velocity * delta
	
	# Map sınırları kontrolü (X, Z, Y eksenlerinde ±15 birim)
	if abs(global_position.x) > 15.0 or abs(global_position.z) > 15.0 or abs(global_position.y) > 15.0:
		print("[PROJECTILE] Out of bounds (x=", global_position.x, " z=", global_position.z, " y=", global_position.y, "), destroying")
		queue_free()
		return


# ============================================
# DEFLECT MECHANISM
# ============================================
func deflect(dir: Vector3, force: float, source: Node) -> void:
	"""Projectile'i deflect et (kalkan tarafından çağrılır)."""
	if is_deflected:
		print("[PROJECTILE] Already deflected, ignoring duplicate deflect call")
		return  # Zaten deflect edilmiş
	
	is_deflected = true
	projectile_owner = source  # Yeni owner deflector (shield)
	damage_multiplier = 2  # Deflect sonrası 2x hasar
	
	# Yeni velocity set et
	velocity = dir.normalized() * force
	
	# Küçük offset: kalkanın içine takılmasın
	global_position += dir.normalized() * 0.3
	
	# Renk sarıya dön
	apply_color(Color(1, 1, 0, 1))  # Sarı
	
	# Enemy collision'ı aç
	_setup_collision_mask(true)
	
	print("[PROJECTILE] Deflected -> yellow, enemy-collision ON, dmg x2")
	print("[PROJECTILE] Deflected! new_velocity=", velocity, " direction=", dir.normalized(), " force=", force)


# ============================================
# ENEMY FINDING
# ============================================
func find_enemy_root(node: Node) -> Node:
	"""Enemy root'u bul (parent chain'de ara)."""
	var cur: Node = node
	while cur != null:
		# Enemy grubunda mı?
		if cur.is_in_group("enemy"):
			return cur
		
		# take_damage metodu var mı? (enemy script'i)
		if cur.has_method("take_damage"):
			return cur
		
		# Parent'a geç
		cur = cur.get_parent()
	
	return null


# ============================================
# COLLISION HANDLING
# ============================================
func _on_body_entered(body: Node) -> void:
	"""Bir body'ye çarptığında."""
	_handle_collision(body)


func _on_area_entered(area: Area3D) -> void:
	"""Bir area'ya çarptığında."""
	# BlockArea kontrolü - deflect mekanizması BlockArea'da çalışacak
	if area.name == "BlockArea":
		# BlockArea'da deflect çalışacak, burada ignore et
		return
	
	_handle_collision(area)


func _handle_collision(target: Node) -> void:
	"""Collision'ı işle."""
	# Player'a çarptı mı?
	if target.is_in_group("player") or (target.get_parent() and target.get_parent().is_in_group("player")):
		_hit_player(target)
		return
	
	# Enemy'ye çarptı mı? (sadece deflect edilmişse buraya girer çünkü mask'te enemy kapalı)
	if target.is_in_group("enemy") or (target.get_parent() and target.get_parent().is_in_group("enemy")):
		_hit_enemy(target)
		return
	
	# World/StaticBody'e çarptı mı?
	if target is StaticBody3D or (target is CharacterBody3D and not target.is_in_group("player") and not target.is_in_group("enemy")):
		_hit_world()
		return


func _hit_player(target: Node) -> void:
	"""Player'a hasar ver (sadece deflect edilmemiş projectile)."""
	if is_deflected:
		# Deflect edilmiş projectile player'a hasar vermesin (friendly fire kapalı)
		print("[PROJECTILE] Deflected projectile hit player, ignoring damage")
		queue_free()
		return
	
	# Deflect edilmemiş projectile player'a hasar ver
	var player = target
	if target.get_parent() and target.get_parent().is_in_group("player"):
		player = target.get_parent()
	
	# Player'ın CharacterBody3D'sini bul
	if player is Node3D and not player is CharacterBody3D:
		var character_body = player.get_node_or_null("CharacterBody3D")
		if character_body:
			player = character_body
	
	# Damage ver (duck typing)
	if player.has_method("take_damage"):
		player.take_damage(base_damage)
		print("[PROJECTILE] Hit player for ", base_damage, " damage!")
	else:
		print("[PROJECTILE] Hit player but no take_damage method found!")
	
	# Projectile'i yok et
	queue_free()


func _hit_enemy(target: Node) -> void:
	"""Enemy'ye hasar ver (sadece deflect edilmiş projectile)."""
	if not is_deflected:
		# Bu durum teorik olarak olmamalı (mask'te enemy kapalı) ama güvenlik için
		print("[PROJECTILE] ERROR: Non-deflected projectile hit enemy (should not happen)!")
		queue_free()
		return
	
	# Enemy root'u bul (parent chain'de)
	var enemy = find_enemy_root(target)
	if not enemy:
		print("[PROJECTILE] Hit enemy collider but could not find enemy root!")
		queue_free()
		return
	
	# Hasar hesapla (2x)
	var final_damage = base_damage * damage_multiplier
	
	# Damage ver (duck typing)
	if enemy.has_method("take_damage"):
		enemy.take_damage(final_damage)
		print("[PROJECTILE] Hit enemy: ", enemy.name, " damage=", final_damage)
	elif enemy.has_method("hit"):
		enemy.hit(final_damage)
		print("[PROJECTILE] Hit enemy: ", enemy.name, " damage=", final_damage, " (via hit method)")
	else:
		print("[PROJECTILE] Hit enemy but no take_damage/hit method found!")
	
	# Knockback uygula (sadece deflected projectile için)
	if is_deflected:
		var push_dir = velocity.normalized()
		# Knockback yönü projectile velocity yönü
		if enemy.has_method("apply_knockback"):
			enemy.apply_knockback(push_dir, push_strength)
		elif enemy.has_method("knockback"):
			enemy.knockback(push_dir, push_strength)
		else:
			print("[PROJECTILE] Enemy has no knockback method")
	
	# Projectile'i yok et
	queue_free()


func _hit_world() -> void:
	"""World'e çarptı."""
	print("[PROJECTILE] Hit world, destroyed!")
	queue_free()
