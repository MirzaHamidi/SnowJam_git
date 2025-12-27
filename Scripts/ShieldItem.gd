extends RigidBody3D

## Shield Item - 1-hit block shield (telekinesis ile tutulabilir)

signal blocked(hit_pos: Vector3)
signal broken(shield: Node)

# ============================================
# EXPORT PARAMETERS
# ============================================
@export_group("Block")
@export var blocks_left: int = 1  # Kaç saldırı bloklayabilir
@export var block_enabled: bool = true
@export var deflect_force: float = 26.0  # Deflect edilmiş projectile'in hızı

@export_group("Aim Assist")
@export var aim_max_distance: float = 25.0  # Maksimum hedef mesafesi
@export var aim_cone_angle_deg: float = 25.0  # Açı filtresi (derece)
@export var aim_strength: float = 0.65  # Aim assist gücü (0 = yok, 1 = tam kilit)
@export var los_required: bool = false  # Line of sight gerekli mi?

@export_group("Physics (Held State)")
@export var held_gravity_scale: float = 0.2  # Tutulurken gravity azalt
@export var held_linear_damp: float = 5.0  # Tutulurken linear damping
@export var held_angular_damp: float = 5.0  # Tutulurken angular damping

# ============================================
# INTERNAL VARIABLES
# ============================================
var is_held: bool = false
var original_gravity_scale: float = 1.0
var original_linear_damp: float = 0.0
var original_angular_damp: float = 0.0
var original_collision_layer: int = 1
var original_collision_mask: int = 1
var held_by: Node3D = null  # Kim tutuyor (Player)

var block_area: Area3D = null  # Block detection için Area3D
var collision_shape: CollisionShape3D = null  # CollisionShape3D referansı

# ============================================
# READY
# ============================================
func _ready() -> void:
	# Gruplara ekle
	add_to_group("grabbable")
	add_to_group("shield")
	print("[Shield] ready. grabbable=", is_in_group("grabbable"), " shield=", is_in_group("shield"))
	
	# Orijinal physics değerlerini kaydet
	original_gravity_scale = gravity_scale
	original_linear_damp = linear_damp
	original_angular_damp = angular_damp
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask
	
	# CollisionShape3D'yi bul
	collision_shape = get_node_or_null("CollisionShape3D")
	
	# GrabProxy Area3D'yi bul ve ayarla
	var grab_proxy = get_node_or_null("GrabProxy")
	if grab_proxy:
		grab_proxy.monitoring = true
		grab_proxy.monitorable = true
		grab_proxy.add_to_group("grabbable_proxy")
		print("[Shield] GrabProxy found and configured")
	else:
		print("[Shield] WARNING: GrabProxy not found!")
	
	# Block Area3D'yi bul
	block_area = get_node_or_null("BlockArea")
	
	# BlockArea signal'larını bağla (ZORUNLU)
	if block_area:
		# BlockArea'nın monitoring ve monitorable ayarlarını yap
		block_area.monitoring = true
		block_area.monitorable = true
		
		# BlockArea'nın altında CollisionShape3D var mı kontrol et
		var block_collision = block_area.get_node_or_null("CollisionShape3D")
		if not block_collision:
			# CollisionShape3D yoksa oluştur
			block_collision = CollisionShape3D.new()
			block_collision.name = "CollisionShape3D"
			# Shield'in CollisionShape3D'sini kopyala veya yeni bir shape oluştur
			if collision_shape and collision_shape.shape:
				# Aynı shape'i kullan (daha büyük olabilir)
				block_collision.shape = collision_shape.shape.duplicate()
			else:
				# Varsayılan BoxShape3D oluştur
				var box_shape = BoxShape3D.new()
				box_shape.size = Vector3(2.0, 2.0, 0.2)
				block_collision.shape = box_shape
			block_area.add_child(block_collision)
			print("[SHIELD] Created CollisionShape3D for BlockArea")
		
		block_area.area_entered.connect(_on_block_area_area_entered)
		print("[SHIELD] BlockArea found and area_entered signal connected")
		print("[SHIELD] BlockArea monitoring=", block_area.monitoring, " monitorable=", block_area.monitorable)
	else:
		push_error("[SHIELD] BlockArea NOT FOUND! Deflect will not work!")
	
	# Collision signal'larını bağla (doğrudan collision ile block)
	body_entered.connect(_on_body_entered)


# ============================================
# HELD STATE
# ============================================
func set_held(held: bool, holder: Node3D = null) -> void:
	"""Shield'in tutulma durumunu ayarla."""
	is_held = held
	held_by = holder
	
	if is_held:
		# Tutulurken physics ayarlarını değiştir
		gravity_scale = held_gravity_scale
		linear_damp = held_linear_damp
		angular_damp = held_angular_damp
		
		# Freeze = true yap (player'a kuvvet vermesin, stabil olsun)
		freeze = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		
		# Collision'ı kapat (player ve enemy ile çarpışmasın)
		if collision_shape:
			collision_shape.disabled = true
		
		# Collision layer/mask'i sıfırla (hiçbir şeyle çarpışmasın)
		collision_layer = 0
		collision_mask = 0
		
		# BlockArea açık kalsın (projectile ile etkileşim için)
		if block_area:
			block_area.monitoring = true
			block_area.monitorable = true  # Projectile'ların BlockArea'yı algılaması için
			print("[SHIELD] Shield held - BlockArea monitoring enabled")
	else:
		# Bırakılınca orijinal değerlere dön
		gravity_scale = original_gravity_scale
		linear_damp = original_linear_damp
		angular_damp = original_angular_damp
		
		# Freeze'i kaldır (normal fizik)
		freeze = false
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		
		# Collision'ı tekrar aç
		if collision_shape:
			collision_shape.disabled = false
		
		# Collision layer/mask'i geri yükle
		collision_layer = original_collision_layer
		collision_mask = original_collision_mask
		
		held_by = null
		print("[SHIELD] Shield dropped - BlockArea monitoring disabled")


# ============================================
# BLOCK LOGIC (PROJECTILE DEFLECT)
# ============================================
func _on_block_area_area_entered(area: Area3D) -> void:
	"""Block Area3D'ye bir area girdiğinde (PROJECTILE DEFLECT)."""
	if not block_area:
		print("[SHIELD] ERROR: BlockArea is null in _on_block_area_area_entered!")
		return
	
	# Sadece eldeyken deflect yap
	if not is_held:
		print("[SHIELD] Projectile hit BlockArea but shield is NOT held - ignoring")
		return
	
	if not block_enabled:
		print("[SHIELD] Block disabled - ignoring projectile")
		return
	
	# Projectile kontrolü
	if not area.is_in_group("projectile"):
		print("[SHIELD] Area entered BlockArea but not a projectile: ", area.name)
		return
	
	# ProjectileBall kontrolü (deflect() metodu var mı?)
	if not area.has_method("deflect"):
		print("[SHIELD] ERROR: Projectile does not have deflect() method! Projectile type: ", area.get_script())
		return
	
	# Deflect yönünü al (aim assist ile)
	var deflect_dir = get_deflect_direction_with_assist()
	
	# Console log
	print("[SHIELD] Projectile blocked!")
	print("[SHIELD] Deflect direction: ", deflect_dir)
	
	# Deflect et
	area.deflect(deflect_dir, deflect_force, self)
	
	# Block tüket (deflect de 1 blok saysın)
	consume_block()


func _on_body_entered(body: Node) -> void:
	"""Bir body shield'e çarptığında (enemy attack için)."""
	if not is_held or not block_enabled or blocks_left <= 0:
		return
	
	# Enemy attack kontrolü
	if body.is_in_group("enemy_attack"):
		_check_block(body)
		return


func _check_block(target: Node) -> void:
	"""Saldırıyı blokla (body için - enemy attack)."""
	# Enemy attack kontrolü
	if target.is_in_group("enemy_attack"):
		# Saldırıyı iptal et
		_cancel_attack(target)
		
		# Block efekti
		var hit_pos = global_position
		if target is RigidBody3D:
			hit_pos = target.global_position
		elif target is Area3D:
			hit_pos = target.global_position
		
		# Block signal emit et
		blocked.emit(hit_pos)
		
		# Blocks left azalt
		blocks_left -= 1
		print("ShieldItem: Blocked attack from: ", target.name, " (", blocks_left, " blocks left)")
		
		# Blocks left 0 ise shield'i yok et
		if blocks_left <= 0:
			_destroy_shield()


func _cancel_attack(attack_source: Node) -> void:
	"""Saldırıyı iptal et - attack source'a signal gönder veya damage vermeyi engelle."""
	# Attack source'un damage verme metodunu çağırma veya signal gönder
	if attack_source.has_method("on_blocked"):
		attack_source.on_blocked()
	
	# Eğer attack bir Area3D ise, disable et
	if attack_source is Area3D:
		var area = attack_source as Area3D
		area.monitoring = false
		area.monitorable = false


func get_deflect_direction() -> Vector3:
	"""Kalkanın gösterdiği yönü döndür (kamera forward veya shield forward)."""
	# Eğer shield tutuluyorsa, player'ın kamerasının forward yönünü al
	if is_held and held_by:
		# Player'dan Camera3D'yi bul
		var player_node = held_by
		
		# CharacterBody3D ise direkt Camera3D'yi bul
		if player_node is CharacterBody3D:
			var camera = player_node.get_node_or_null("Camera3D")
			if camera:
				# Kamera forward yönü
				var camera_forward = -camera.global_transform.basis.z
				return camera_forward.normalized()
		
		# Node3D ise CharacterBody3D'yi bul
		if player_node is Node3D:
			var character_body = player_node.get_node_or_null("CharacterBody3D")
			if character_body:
				var camera = character_body.get_node_or_null("Camera3D")
				if camera:
					var camera_forward = -camera.global_transform.basis.z
					return camera_forward.normalized()
		
		# PlayerGrab'dan camera'yı al (fallback)
		var player_grab = player_node.get_node_or_null("PlayerGrab")
		if player_grab:
			# PlayerGrab'ın camera referansını al (duck typing)
			if "camera" in player_grab:
				var camera = player_grab.camera
				if camera:
					var camera_forward = -camera.global_transform.basis.z
					return camera_forward.normalized()
	
	# Fallback: Shield'in kendi forward yönü
	return -global_transform.basis.z.normalized()


func get_deflect_direction_with_assist() -> Vector3:
	"""Kalkanın gösterdiği yönü döndür (aim assist ile enemy hedefleme)."""
	# Kamera forward al
	var camera: Camera3D = null
	var origin: Vector3 = Vector3.ZERO
	
	if is_held and held_by:
		var player_node = held_by
		
		# CharacterBody3D ise direkt Camera3D'yi bul
		if player_node is CharacterBody3D:
			camera = player_node.get_node_or_null("Camera3D")
		# Node3D ise CharacterBody3D'yi bul
		elif player_node is Node3D:
			var character_body = player_node.get_node_or_null("CharacterBody3D")
			if character_body:
				camera = character_body.get_node_or_null("Camera3D")
		
		# PlayerGrab'dan camera'yı al (fallback)
		if not camera:
			var player_grab = player_node.get_node_or_null("PlayerGrab")
			if player_grab and "camera" in player_grab:
				camera = player_grab.camera
	
	# Kamera bulunamadıysa fallback
	if not camera:
		return get_deflect_direction()
	
	origin = camera.global_transform.origin
	var fwd = (-camera.global_transform.basis.z).normalized()
	
	# En iyi hedefi bul
	var best_target: Node = null
	var best_score: float = INF
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	var cone_angle_rad = deg_to_rad(aim_cone_angle_deg)
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		var enemy_pos = enemy.global_position
		var dir_to_enemy = (enemy_pos - origin)
		var dist = dir_to_enemy.length()
		
		# Mesafe filtresi
		if dist > aim_max_distance:
			continue
		
		# Açı filtresi
		dir_to_enemy = dir_to_enemy.normalized()
		var angle = acos(fwd.dot(dir_to_enemy))
		if angle > cone_angle_rad:
			continue
		
		# LOS kontrolü (opsiyonel)
		if los_required:
			if not _check_line_of_sight(origin, enemy_pos):
				continue
		
		# Skorla (küçük skor daha iyi)
		var angle_weight = 0.6
		var dist_weight = 0.4
		var normalized_dist = dist / aim_max_distance
		var score = angle_weight * angle + dist_weight * normalized_dist
		
		if score < best_score:
			best_score = score
			best_target = enemy
	
	# En iyi hedef varsa aim assist uygula
	if best_target:
		var enemy_pos = best_target.global_position
		var aim_dir = (enemy_pos - origin).normalized()
		var final_dir = fwd.slerp(aim_dir, aim_strength).normalized()
		
		# Debug log
		var angle_deg = rad_to_deg(acos(fwd.dot(aim_dir)))
		var dist = (enemy_pos - origin).length()
		print("[AIM] target=", best_target.name, " angle_deg=", angle_deg, " dist=", dist)
		
		return final_dir
	else:
		# Hedef yoksa normal forward
		print("[AIM] no target -> forward")
		return fwd


func _check_line_of_sight(origin: Vector3, target_pos: Vector3) -> bool:
	"""Line of sight kontrolü (raycast ile)."""
	var space_state = get_world_3d().direct_space_state
	
	# Yükseklik offset (enemy'nin göğsüne bak)
	var ray_start = origin
	var ray_end = target_pos + Vector3.UP * 0.8
	
	# Raycast query
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 1  # World layer
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = []  # Enemy'yi exclude etme (hedefi görmek için)
	
	var result = space_state.intersect_ray(query)
	
	# Eğer hiçbir şey yoksa veya direkt enemy'ye çarptıysa görüyoruz
	if not result:
		return true
	
	# Çarpan şey enemy mi?
	var collider = result.get("collider")
	if collider and (collider.is_in_group("enemy") or collider.get_parent() and collider.get_parent().is_in_group("enemy")):
		return true
	
	# World'e çarptıysa görmüyoruz
	return false


# ============================================
# BLOCK CONSUMPTION
# ============================================
func consume_block() -> void:
	"""Block tüket (projectile veya başka bir şey tarafından çağrılır)."""
	if blocks_left <= 0:
		return
	
	blocks_left -= 1
	print("ShieldItem: Block consumed! (", blocks_left, " blocks left)")
	
	# Block signal emit et
	blocked.emit(global_position)
	
	# Blocks left 0 ise shield'i yok et
	if blocks_left <= 0:
		# Broken signal emit et (PlayerGrab için)
		broken.emit(self)
		_destroy_shield()


func _destroy_shield() -> void:
	"""Shield'i yok et (1-hit sonrası)."""
	print("ShieldItem: Shield destroyed after blocking attack!")
	
	# Shield'i yok et
	queue_free()


# ============================================
# PUBLIC API
# ============================================
func is_shield_held() -> bool:
	"""Shield tutuluyor mu?"""
	return is_held


func get_blocks_left() -> int:
	"""Kalan block sayısını döndür."""
	return blocks_left
