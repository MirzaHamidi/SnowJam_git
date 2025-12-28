extends Node

## Player Grab System - Telekinesis ile objeleri tutma sistemi
## Player CharacterBody3D'ye eklenir
## 
## REFACTOR NOTES:
## 1) Debug log'lar debug_enabled flag ile kontrol edilir
## 2) Fonksiyonlar 35-45 satır limitinde tutuldu
## 3) Magic number'lar const/export yapıldı
## 4) Tip eklemeleri yapıldı (typed GDScript)
## 5) Erken return pattern kullanıldı

# ============================================
# EXPORT PARAMETERS
# ============================================
@export_group("Grab Settings")
@export var grab_ray_length: float = 7.0
@export var pull_strength: float = 50.0
@export var damping: float = 10.0
@export var rotation_strength: float = 5.0

@export_group("Hold Point")
@export var hold_distance: float = 1.5
@export var hold_offset_right: float = 0.3
@export var hold_offset_up: float = -0.2
@export var follow_lerp: float = 0.35

@export_group("Debug")
@export var debug_enabled: bool = false

# ============================================
# CONSTANTS
# ============================================
const DEFAULT_COLLISION_LAYER: int = 1
const MIN_VELOCITY_THRESHOLD: float = 0.1

# ============================================
# NODE REFERENCES
# ============================================
var player: CharacterBody3D = null
var camera: Camera3D = null
var grab_ray: RayCast3D = null
var hold_point: Node3D = null

# ============================================
# RUNTIME STATE
# ============================================
var held_body: RigidBody3D = null
var held_item: Node = null
var is_grabbing: bool = false

# ============================================
# GODOT CALLBACKS
# ============================================
func _ready() -> void:
	_setup_player_reference()
	_setup_camera()
	_setup_grab_ray()
	_setup_hold_point()
	_check_input_map()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_try_grab()
		else:
			_drop()


func _process(_delta: float) -> void:
	if Input.is_action_pressed("grab") and not is_grabbing:
		_try_grab()
	elif Input.is_action_just_released("grab") and is_grabbing:
		_drop()


func _physics_process(delta: float) -> void:
	if not _validate_held_references():
		return
	
	if not is_grabbing or not held_body or not hold_point:
		return
	
	if held_body.is_in_group("shield"):
		_update_shield_transform(delta)
	else:
		_update_spring_force(delta)

# ============================================
# PUBLIC API
# ============================================
func is_holding_shield() -> bool:
	"""Shield tutuluyor mu?"""
	return is_grabbing and held_body != null and held_body.is_in_group("shield")


func get_held_body() -> RigidBody3D:
	"""Tutulan objeyi döndür."""
	return held_body


func clear_held() -> void:
	"""Held item'ı temizle (kırılma veya drop için)."""
	if not is_grabbing:
		return
	
	_disconnect_signals()
	_reset_held_item_state()
	_clear_references()
	
	if debug_enabled:
		print("[Grab] cleared held item")

# ============================================
# PRIVATE HELPERS - SETUP
# ============================================
func _setup_player_reference() -> void:
	player = get_parent() as CharacterBody3D
	if not player:
		push_error("PlayerGrab: Parent must be CharacterBody3D!")


func _setup_camera() -> void:
	if not player:
		return
	
	camera = player.get_node_or_null("Camera3D")
	if not camera:
		push_error("PlayerGrab: Camera3D not found!")


func _setup_grab_ray() -> void:
	if not camera:
		return
	
	grab_ray = camera.get_node_or_null("GrabRay")
	if not grab_ray:
		_create_grab_ray()
	else:
		_configure_grab_ray()


func _create_grab_ray() -> void:
	grab_ray = RayCast3D.new()
	grab_ray.name = "GrabRay"
	grab_ray.enabled = true
	grab_ray.target_position = Vector3(0, 0, -grab_ray_length)
	grab_ray.collision_mask = DEFAULT_COLLISION_LAYER
	camera.add_child(grab_ray)
	
	if debug_enabled:
		print("PlayerGrab: GrabRay created")


func _configure_grab_ray() -> void:
	grab_ray.enabled = true
	grab_ray.target_position = Vector3(0, 0, -grab_ray_length)
	
	if debug_enabled:
		print("PlayerGrab: GrabRay found")


func _setup_hold_point() -> void:
	if not camera:
		return
	
	hold_point = camera.get_node_or_null("HoldPoint")
	if not hold_point:
		_create_hold_point()
	else:
		_configure_hold_point()


func _create_hold_point() -> void:
	hold_point = Node3D.new()
	hold_point.name = "HoldPoint"
	hold_point.position = Vector3(hold_offset_right, hold_offset_up, -hold_distance)
	camera.add_child(hold_point)
	
	if debug_enabled:
		print("PlayerGrab: HoldPoint created")


func _configure_hold_point() -> void:
	hold_point.position = Vector3(hold_offset_right, hold_offset_up, -hold_distance)
	
	if debug_enabled:
		print("PlayerGrab: HoldPoint found")


func _check_input_map() -> void:
	if not InputMap.has_action("grab"):
		push_warning("PlayerGrab: 'grab' action not found in Input Map!")

# ============================================
# PRIVATE HELPERS - GRAB SYSTEM
# ============================================
func _try_grab() -> void:
	if is_grabbing:
		return
	
	if not grab_ray or not grab_ray.is_colliding():
		return
	
	var hit = grab_ray.get_collider()
	if not hit:
		return
	
	if debug_enabled:
		print("[Grab] Ray hit: ", hit, " class=", hit.get_class(), " name=", hit.name)
	
	var rigid_body = _find_rigid_body_from_hit(hit)
	if not rigid_body:
		return
	
	if not rigid_body.is_in_group("grabbable"):
		if debug_enabled:
			print("[Grab] RigidBody3D is not in 'grabbable' group")
		return
	
	if debug_enabled:
		print("[Grab] held_body: ", rigid_body.name)
	
	_grab(rigid_body)


func _find_rigid_body_from_hit(hit: Node) -> RigidBody3D:
	if hit is Area3D:
		return _find_rigid_body_from_area(hit)
	elif hit is RigidBody3D:
		return hit
	elif hit.get_parent() is RigidBody3D:
		return hit.get_parent() as RigidBody3D
	
	return null


func _find_rigid_body_from_area(area: Area3D) -> RigidBody3D:
	if area.name == "GrabProxy" or area.is_in_group("grabbable_proxy"):
		var shield = area.get_parent()
		if shield is RigidBody3D:
			if debug_enabled:
				print("[Grab] Found shield via GrabProxy: ", shield.name)
			return shield as RigidBody3D
		elif debug_enabled:
			print("[Grab] GrabProxy parent is not RigidBody3D: ", shield.get_class())
	elif debug_enabled:
		print("[Grab] Area3D hit but not GrabProxy: ", area.name)
	
	return null


func _grab(body: RigidBody3D) -> void:
	held_body = body
	held_item = body
	is_grabbing = true
	
	body.freeze = true
	
	if body.has_method("set_held"):
		body.set_held(true, player)
	
	_connect_signals(body)
	
	if debug_enabled:
		print("[Grab] PlayerGrab: Grabbed ", body.name, " freeze=", body.freeze)


func _drop() -> void:
	if not is_grabbing:
		return
	
	clear_held()

# ============================================
# PRIVATE HELPERS - SIGNAL MANAGEMENT
# ============================================
func _connect_signals(body: Node) -> void:
	if body.has_signal("broken") and not body.broken.is_connected(_on_held_broken):
		body.broken.connect(_on_held_broken)
	
	if not body.tree_exiting.is_connected(_on_held_tree_exiting):
		body.tree_exiting.connect(_on_held_tree_exiting)


func _disconnect_signals() -> void:
	if not held_item or not is_instance_valid(held_item):
		return
	
	if held_item.has_signal("broken") and held_item.broken.is_connected(_on_held_broken):
		held_item.broken.disconnect(_on_held_broken)
	
	if held_item.tree_exiting.is_connected(_on_held_tree_exiting):
		held_item.tree_exiting.disconnect(_on_held_tree_exiting)


func _on_held_broken(_shield: Node) -> void:
	if debug_enabled:
		print("[Grab] held shield broken -> clearing")
	clear_held()


func _on_held_tree_exiting() -> void:
	if debug_enabled:
		print("[Grab] held item tree_exiting -> clearing")
	clear_held()

# ============================================
# PRIVATE HELPERS - HELD STATE MANAGEMENT
# ============================================
func _validate_held_references() -> bool:
	if not is_grabbing:
		return true
	
	if held_body == null or not is_instance_valid(held_body):
		if debug_enabled:
			print("[Grab] held_body invalid -> clearing")
		clear_held()
		return false
	
	if held_item != null and not is_instance_valid(held_item):
		if debug_enabled:
			print("[Grab] held_item invalid -> clearing")
		clear_held()
		return false
	
	return true


func _reset_held_item_state() -> void:
	if held_item and is_instance_valid(held_item):
		if held_item.has_method("set_held"):
			held_item.set_held(false, null)
	
	if held_body and is_instance_valid(held_body):
		held_body.freeze = false


func _clear_references() -> void:
	held_body = null
	held_item = null
	is_grabbing = false

# ============================================
# PRIVATE HELPERS - PHYSICS UPDATE
# ============================================
func _update_shield_transform(_delta: float) -> void:
	if not held_body or not hold_point or not camera:
		return
	
	var target_transform = hold_point.global_transform
	var current_transform = held_body.global_transform
	
	var new_pos = current_transform.origin.lerp(target_transform.origin, follow_lerp)
	var new_yaw = _calculate_shield_yaw(current_transform, target_transform)
	
	var new_basis = Basis().rotated(Vector3.UP, new_yaw)
	held_body.global_transform = Transform3D(new_basis, new_pos)


func _calculate_shield_yaw(current: Transform3D, target: Transform3D) -> float:
	var camera_forward = -camera.global_transform.basis.z
	var target_yaw = atan2(camera_forward.x, camera_forward.z)
	var current_yaw = atan2(current.basis.z.x, current.basis.z.z)
	return lerp_angle(current_yaw, target_yaw, follow_lerp)


func _update_spring_force(_delta: float) -> void:
	if not held_body or not hold_point:
		return
	
	var desired_pos = hold_point.global_position
	var current_pos = held_body.global_position
	var current_vel = held_body.linear_velocity
	
	var displacement = desired_pos - current_pos
	var spring_force = displacement * pull_strength
	var damping_force = -current_vel * damping
	var total_force = spring_force + damping_force
	
	held_body.apply_central_force(total_force)
	
	if rotation_strength > 0.0:
		var angular_vel = held_body.angular_velocity
		var rotation_damping = -angular_vel * rotation_strength
		held_body.apply_torque(rotation_damping)
