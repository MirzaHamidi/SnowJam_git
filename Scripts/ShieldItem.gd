extends RigidBody3D

## Shield Item - 1-hit block shield (telekinesis ile tutulabilir)
## 
## REFACTOR NOTES:
## 1) Debug log'lar debug_enabled flag ile kontrol edilir
## 2) Aim assist, block logic, held state ayrı bölümlerde
## 3) Magic number'lar const/export yapıldı
## 4) Tip eklemeleri yapıldı (typed GDScript)
## 5) Erken return pattern kullanıldı

signal blocked(hit_pos: Vector3)
signal broken(shield: Node)

# ============================================
# EXPORT PARAMETERS
# ============================================
@export_group("Block")
@export var blocks_left: int = 6
@export var block_enabled: bool = true
@export var deflect_force: float = 26.0

@export_group("Aim Assist")
@export var aim_max_distance: float = 30.0  # Güvenli default
@export var aim_cone_angle_deg: float = 30.0  # Güvenli default
@export var aim_strength: float = 0.7  # Güvenli default
@export var los_required: bool = false  # Şimdilik false

@export_group("Physics (Held State)")
@export var held_gravity_scale: float = 0.2
@export var held_linear_damp: float = 5.0
@export var held_angular_damp: float = 5.0

@export_group("Debug")
@export var debug_enabled: bool = false

# ============================================
# CONSTANTS
# ============================================
const DEFAULT_BOX_SIZE: Vector3 = Vector3(2.0, 2.0, 0.2)
const ENEMY_CHEST_OFFSET: float = 0.8
const AIM_ANGLE_WEIGHT: float = 0.6
const AIM_DIST_WEIGHT: float = 0.4
const WORLD_LAYER_MASK: int = 1

# ============================================
# NODE REFERENCES
# ============================================
@onready var block_area: Area3D = $BlockArea
var collision_shape: CollisionShape3D = null
var grab_proxy: Area3D = null

# ============================================
# RUNTIME STATE
# ============================================
var is_held: bool = false
var held_by: Node3D = null

var original_gravity_scale: float = 1.0
var original_linear_damp: float = 1.0
var original_angular_damp: float = 1.0
var original_collision_layer: int = 1
var original_collision_mask: int = 1

# ============================================
# GODOT CALLBACKS
# ============================================
func _ready() -> void:
	# DEBUG: Shield ready
	print("[Shield] ready type=", get_class(), " root=", name)
	
	_add_to_groups()
	_save_original_physics()
	_setup_nodes()
	_force_connect_block_area_signals()
	_connect_signals()


func _on_block_area_area_entered(area: Area3D) -> void:
	"""BlockArea'ya Area3D girdiğinde."""
	print("[Shield] area_entered:", area.name, " type=", area.get_class(), " groups=", area.get_groups(), " is_held=", is_held, " is_in_group(projectile)=", area.is_in_group("projectile"))
	_try_deflect(area)


func _on_block_body_entered(body: Node) -> void:
	"""BlockArea'ya RigidBody3D/CharacterBody3D girdiğinde."""
	print("[Shield] body_entered:", body.name, " type=", body.get_class(), " groups=", body.get_groups(), " is_held=", is_held)
	_try_deflect(body)


func _try_deflect(n: Node) -> void:
	"""Projectile'ı bul ve deflect et (FAIL-SAFE)."""
	if not _can_block():
		print("[Shield] Cannot block - _can_block() returned false")
		return
	
	# FAIL-SAFE: Projectile'ı parent chain'de bul
	var projectile = find_projectile(n)
	
	if projectile == null:
		print("[Shield] Not a projectile -> ignore. Node: ", n.name, " class: ", n.get_class())
		return
	
	if not projectile.has_method("deflect"):
		print("[Shield] ERROR: Projectile found but no deflect() method! Node: ", projectile.name)
		return
	
	# Deflect direction'ı al (aim assist ile - MEVCUT FONKSİYON KORUNUYOR)
	var dir = get_deflect_direction_with_assist()
	print("[Shield] DEFLECT TRIGGERED ->", projectile.name, " dir=", dir, " force=", deflect_force)
	
	# Deflect çağır
	projectile.call("deflect", dir, deflect_force, self)
	
	# Block tüket
	consume_block()


func find_projectile(n: Node) -> Node:
	"""ZORUNLU helper: Parent chain'de projectile bul."""
	var cur := n
	var depth = 0
	while cur and depth < 10:  # Max 10 level yukarı çık
		print("[Shield] find_projectile depth=", depth, " node=", cur.name, " is_in_group(projectile)=", cur.is_in_group("projectile"), " has_method(deflect)=", cur.has_method("deflect"))
		if cur.is_in_group("projectile") or cur.has_method("deflect"):
			print("[Shield] Projectile found:", cur.name)
			return cur
		cur = cur.get_parent()
		depth += 1
	print("[Shield] Projectile NOT found in parent chain")
	return null




func _on_body_entered(body: Node) -> void:
	if not _can_block():
		return
	
	if body.is_in_group("enemy_attack"):
		_check_block(body)

# ============================================
# PUBLIC API
# ============================================
func set_held(held: bool, holder: Node3D = null) -> void:
	"""Shield'in tutulma durumunu ayarla."""
	is_held = held
	held_by = holder
	
	if is_held:
		_apply_held_physics()
	else:
		_restore_dropped_physics()


func consume_block() -> void:
	"""Block tüket (projectile veya başka bir şey tarafından çağrılır)."""
	if blocks_left <= 0:
		return
	
	blocks_left -= 1
	blocked.emit(global_position)
	
	if debug_enabled:
		print("ShieldItem: Block consumed! (", blocks_left, " blocks left)")
	
	if blocks_left <= 0:
		broken.emit(self)
		_destroy_shield()


func is_shield_held() -> bool:
	"""Shield tutuluyor mu?"""
	return is_held


func get_blocks_left() -> int:
	"""Kalan block sayısını döndür."""
	return blocks_left


func get_deflect_direction_with_assist() -> Vector3:
	"""Kalkanın gösterdiği yönü döndür (aim assist ile enemy hedefleme)."""
	print("[DEFLECT] get_deflect_direction_with_assist() called")
	
	if not is_held or not held_by:
		print("[AIM] shield not held -> fallback")
		return _get_fallback_direction()
	
	var camera = _find_camera()
	print("[AIM] cam_null=", camera == null)
	if not camera:
		print("[AIM] camera not found -> fallback")
		return _get_fallback_direction()
	
	var origin = camera.global_transform.origin
	var fwd = (-camera.global_transform.basis.z).normalized()
	
	var best_target = _find_best_enemy_target(origin, fwd)
	if best_target:
		var dir = _calculate_aim_assist_direction(origin, fwd, best_target)
		print("[DEFLECT] using aim dir=", dir, " target=", best_target.name)
		return dir
	else:
		print("[AIM] no target -> forward")
		return fwd

# ============================================
# PRIVATE HELPERS - SETUP
# ============================================
func _add_to_groups() -> void:
	add_to_group("grabbable")
	add_to_group("shield")
	
	if debug_enabled:
		print("[Shield] ready. grabbable=", is_in_group("grabbable"), " shield=", is_in_group("shield"))


func _save_original_physics() -> void:
	original_gravity_scale = gravity_scale
	original_linear_damp = linear_damp
	original_angular_damp = angular_damp
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask


func _setup_nodes() -> void:
	collision_shape = get_node_or_null("CollisionShape3D")
	_setup_grab_proxy()
	_setup_block_area()


func _setup_grab_proxy() -> void:
	grab_proxy = get_node_or_null("GrabProxy")
	if grab_proxy:
		grab_proxy.monitoring = true
		grab_proxy.monitorable = true
		grab_proxy.add_to_group("grabbable_proxy")
		if debug_enabled:
			print("[Shield] GrabProxy found and configured")
	else:
		if debug_enabled:
			print("[Shield] WARNING: GrabProxy not found!")


func _setup_block_area() -> void:
	block_area = get_node_or_null("BlockArea")
	if not block_area:
		push_error("[SHIELD] BlockArea NOT FOUND! Deflect will not work!")
		return
	
	# DEBUG: BlockArea tipi
	print("[Shield] BlockArea found: type=", block_area.get_class(), " name=", block_area.name)
	
	# Area3D'ler birbirini algılamak için monitoring ve monitorable kullanır
	# ÖNEMLİ: Area3D'ler birbirini algılamak için collision_layer/mask kullanmaz, sadece monitoring/monitorable kullanır
	block_area.monitoring = true
	block_area.monitorable = true  # BlockArea'nın kendisi algılanabilir olmalı
	block_area.add_to_group("shield")  # Projectile tarafından algılanabilmesi için
	
	# BlockArea'nın collision_layer'ını 5 (Shield) yap
	# Projectile bu layer'ı maskesine ekleyecek
	block_area.collision_layer = (1 << 4) # Layer 5 (bit 4)
	block_area.collision_mask = 0 # Mask önemli değil, projectile onu bulacak
	
	_ensure_block_area_collision_shape()
	
	# DEBUG: CollisionShape kontrolü
	var block_collision = block_area.get_node_or_null("CollisionShape3D")
	if block_collision:
		print("[Shield] BlockArea CollisionShape3D found: disabled=", block_collision.disabled)
	else:
		print("[Shield] WARNING: BlockArea CollisionShape3D NOT FOUND!")
	
	print("[Shield] BlockArea configured: monitoring=", block_area.monitoring, " monitorable=", block_area.monitorable, " layer=", block_area.collision_layer, " mask=", block_area.collision_mask)


func _ensure_block_area_collision_shape() -> void:
	var block_collision = block_area.get_node_or_null("CollisionShape3D")
	if block_collision:
		return
	
	block_collision = CollisionShape3D.new()
	block_collision.name = "CollisionShape3D"
	
	if collision_shape and collision_shape.shape:
		block_collision.shape = collision_shape.shape.duplicate()
	else:
		var box_shape = BoxShape3D.new()
		box_shape.size = DEFAULT_BOX_SIZE
		block_collision.shape = box_shape
	
	block_area.add_child(block_collision)
	
	if debug_enabled:
		print("[SHIELD] Created CollisionShape3D for BlockArea")


func _force_connect_block_area_signals() -> void:
	"""BlockArea sinyallerini ZORLA bağla + debug."""
	if not block_area:
		push_error("[SHIELD] BlockArea NOT FOUND in _force_connect_block_area_signals!")
		return
	
	# BlockArea ayarlarını garanti et
	block_area.monitoring = true
	block_area.monitorable = true
	
	# Sinyalleri zorla bağla (eğer zaten bağlıysa disconnect et)
	if block_area.area_entered.is_connected(_on_block_area_area_entered):
		block_area.area_entered.disconnect(_on_block_area_area_entered)
	if block_area.body_entered.is_connected(_on_block_body_entered):
		block_area.body_entered.disconnect(_on_block_body_entered)
	
	block_area.area_entered.connect(_on_block_area_area_entered)
	block_area.body_entered.connect(_on_block_body_entered)
	
	print("[Shield] BlockArea ready. layer=", block_area.collision_layer, " mask=", block_area.collision_mask, " monitoring=", block_area.monitoring, " monitorable=", block_area.monitorable)
	print("[Shield] BlockArea signals connected: area_entered=", block_area.area_entered.is_connected(_on_block_area_area_entered), " body_entered=", block_area.body_entered.is_connected(_on_block_body_entered))
	
	# CollisionShape kontrolü
	var block_collision = block_area.get_node_or_null("CollisionShape3D")
	if block_collision:
		print("[Shield] BlockArea CollisionShape3D: disabled=", block_collision.disabled, " shape=", block_collision.shape)
	else:
		print("[Shield] WARNING: BlockArea CollisionShape3D NOT FOUND!")


func _connect_signals() -> void:
	body_entered.connect(_on_body_entered)

# ============================================
# PRIVATE HELPERS - HELD STATE
# ============================================
func _apply_held_physics() -> void:
	gravity_scale = held_gravity_scale
	linear_damp = held_linear_damp
	angular_damp = held_angular_damp
	
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	if collision_shape:
		collision_shape.disabled = true
	
	# Shield tutulurken bile collision_layer = 1'de kalmalı ki ProjectileBall onu algılayabilsin
	# collision_mask = 0 yapıyoruz çünkü shield hiçbir şeyi algılamasın
	collision_layer = 1  # ProjectileBall'ın algılayabilmesi için
	collision_mask = 0  # Shield hiçbir şeyi algılamasın
	
	if block_area:
		# Shield tutulurken BlockArea'nın monitoring ve monitorable'ını garanti et
		block_area.monitoring = true
		block_area.monitorable = true
		print("[Shield] Shield held - BlockArea monitoring=", block_area.monitoring, " monitorable=", block_area.monitorable)


func _restore_dropped_physics() -> void:
	gravity_scale = original_gravity_scale
	linear_damp = original_linear_damp
	angular_damp = original_angular_damp
	
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	if collision_shape:
		collision_shape.disabled = false
	
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask
	held_by = null
	
	if debug_enabled:
		print("[SHIELD] Shield dropped - BlockArea monitoring disabled")

# ============================================
# PRIVATE HELPERS - BLOCK LOGIC
# ============================================
func _can_block() -> bool:
	if not is_held:
		print("[Shield] Cannot block - shield NOT held. is_held=", is_held)
		return false
	
	if not block_enabled:
		print("[Shield] Cannot block - block disabled")
		return false
	
	if blocks_left <= 0:
		print("[Shield] Cannot block - no blocks left. blocks_left=", blocks_left)
		return false
	
	return true




func _check_block(target: Node) -> void:
	if not target.is_in_group("enemy_attack"):
		return
	
	_cancel_attack(target)
	
	var hit_pos = _get_hit_position(target)
	blocked.emit(hit_pos)
	
	blocks_left -= 1
	if debug_enabled:
		print("ShieldItem: Blocked attack from: ", target.name, " (", blocks_left, " blocks left)")
	
	if blocks_left <= 0:
		_destroy_shield()


func _get_hit_position(target: Node) -> Vector3:
	if target is RigidBody3D or target is Area3D:
		return target.global_position
	return global_position


func _cancel_attack(attack_source: Node) -> void:
	if attack_source.has_method("on_blocked"):
		attack_source.on_blocked()
	
	if attack_source is Area3D:
		var area = attack_source as Area3D
		area.monitoring = false
		area.monitorable = false


func _destroy_shield() -> void:
	if debug_enabled:
		print("ShieldItem: Shield destroyed after blocking attack!")
	queue_free()

# ============================================
# PRIVATE HELPERS - AIM ASSIST
# ============================================
func _find_camera() -> Camera3D:
	if not is_held or not held_by:
		return null
	
	# Önce viewport'tan camera al (fallback)
	var viewport_cam = get_viewport().get_camera_3d()
	if viewport_cam:
		print("[AIM] Using viewport camera: ", viewport_cam.name)
		return viewport_cam
	
	var player_node = held_by
	if player_node is CharacterBody3D:
		var cam = player_node.get_node_or_null("Camera3D")
		if cam:
			print("[AIM] Using player CharacterBody3D camera: ", cam.name)
			return cam
	elif player_node is Node3D:
		var character_body = player_node.get_node_or_null("CharacterBody3D")
		if character_body:
			var cam = character_body.get_node_or_null("Camera3D")
			if cam:
				print("[AIM] Using player Node3D->CharacterBody3D camera: ", cam.name)
				return cam
	
	var player_grab = player_node.get_node_or_null("PlayerGrab")
	if player_grab and "camera" in player_grab:
		var cam = player_grab.camera
		if cam:
			print("[AIM] Using PlayerGrab camera: ", cam.name)
			return cam
	
	print("[AIM] WARNING: No camera found!")
	return null


func _get_fallback_direction() -> Vector3:
	return -global_transform.basis.z.normalized()


func _find_best_enemy_target(origin: Vector3, fwd: Vector3) -> Node:
	var best_target: Node = null
	var best_score: float = INF
	var cone_angle_rad = deg_to_rad(aim_cone_angle_deg)
	
	var enemies = get_tree().get_nodes_in_group("enemy")
	print("[AIM] enemies_total=", enemies.size())
	
	var candidates_in_range = 0
	var candidates_in_cone = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == held_by:
			continue
		
		var enemy_pos = enemy.global_position + Vector3.UP * ENEMY_CHEST_OFFSET
		var dir_to_enemy = (enemy_pos - origin)
		var dist = dir_to_enemy.length()
		
		if dist > aim_max_distance:
			continue
		
		candidates_in_range += 1
		
		dir_to_enemy = dir_to_enemy.normalized()
		var dot = fwd.dot(dir_to_enemy)
		var angle = acos(clamp(dot, -1.0, 1.0))
		
		if angle > cone_angle_rad:
			continue
		
		candidates_in_cone += 1
		
		if los_required and not _check_line_of_sight(origin, enemy_pos):
			continue
		
		var score = _calculate_target_score(angle, dist)
		if score < best_score:
			best_score = score
			best_target = enemy
			print("[AIM] candidate: ", enemy.name, " dot=", dot, " dist=", dist, " score=", score)
	
	print("[AIM] candidates_in_range=", candidates_in_range, " candidates_in_cone=", candidates_in_cone)
	
	if best_target:
		var enemy_pos = best_target.global_position + Vector3.UP * ENEMY_CHEST_OFFSET
		var dir_to_enemy = (enemy_pos - origin).normalized()
		var dot = fwd.dot(dir_to_enemy)
		var dist = (enemy_pos - origin).length()
		print("[AIM] chosen=", best_target.name, " dot=", dot, " dist=", dist)
	
	return best_target


func _calculate_target_score(angle: float, dist: float) -> float:
	var normalized_dist = dist / aim_max_distance
	return AIM_ANGLE_WEIGHT * angle + AIM_DIST_WEIGHT * normalized_dist


func _calculate_aim_assist_direction(origin: Vector3, fwd: Vector3, target: Node) -> Vector3:
	var enemy_pos = target.global_position + Vector3.UP * ENEMY_CHEST_OFFSET
	var aim_dir = (enemy_pos - origin).normalized()
	var final_dir = fwd.slerp(aim_dir, aim_strength).normalized()
	
	if debug_enabled:
		var angle_deg = rad_to_deg(acos(fwd.dot(aim_dir)))
		var dist = (enemy_pos - origin).length()
		print("[AIM] target=", target.name, " angle_deg=", angle_deg, " dist=", dist)
	
	return final_dir


func _check_line_of_sight(origin: Vector3, target_pos: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state
	var ray_end = target_pos
	
	var query = PhysicsRayQueryParameters3D.create(origin, ray_end)
	query.collision_mask = WORLD_LAYER_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [self, held_by]
	
	var result = space_state.intersect_ray(query)
	return not result
