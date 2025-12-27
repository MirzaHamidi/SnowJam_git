extends Node

## Player Grab System - Telekinesis ile objeleri tutma sistemi
## Player CharacterBody3D'ye eklenir

# ============================================
# EXPORT PARAMETERS
# ============================================
@export_group("Grab Settings")
@export var grab_ray_length: float = 7.0  # GrabRay uzunluğu
@export var pull_strength: float = 50.0  # Spring force gücü
@export var damping: float = 10.0  # Damping katsayısı
@export var rotation_strength: float = 5.0  # Rotation damping (opsiyonel)

@export_group("Hold Point")
@export var hold_distance: float = 1.5  # Kameradan uzaklık (yakın tut)
@export var hold_offset_right: float = 0.3  # Sağa offset
@export var hold_offset_up: float = -0.2  # Yukarı offset
@export var follow_lerp: float = 0.35  # Transform interpolasyon hızı (0.25-0.5 arası)

# ============================================
# INTERNAL VARIABLES
# ============================================
var player: CharacterBody3D = null
var camera: Camera3D = null
var grab_ray: RayCast3D = null
var hold_point: Node3D = null

var held_body: RigidBody3D = null
var is_grabbing: bool = false

# ============================================
# READY
# ============================================
func _ready() -> void:
	# Player referansını al (parent CharacterBody3D)
	player = get_parent() as CharacterBody3D
	if not player:
		push_error("PlayerGrab: Parent must be CharacterBody3D!")
		return
	
	# Camera ve RayCast'i bul
	camera = player.get_node_or_null("Camera3D")
	if not camera:
		push_error("PlayerGrab: Camera3D not found!")
		return
	
	# GrabRay'i bul veya oluştur
	_setup_grab_ray()
	
	# HoldPoint'i bul veya oluştur
	_setup_hold_point()
	
	# Input Map kontrolü
	if not InputMap.has_action("grab"):
		push_warning("PlayerGrab: 'grab' action not found in Input Map! Please add it.")


func _setup_grab_ray() -> void:
	"""GrabRay'i bul veya oluştur."""
	grab_ray = camera.get_node_or_null("GrabRay")
	
	if not grab_ray:
		# GrabRay yoksa oluştur
		grab_ray = RayCast3D.new()
		grab_ray.name = "GrabRay"
		grab_ray.enabled = true
		grab_ray.target_position = Vector3(0, 0, -grab_ray_length)
		grab_ray.collision_mask = 1  # Default collision layer
		camera.add_child(grab_ray)
		print("PlayerGrab: GrabRay created")
	else:
		# GrabRay varsa ayarlarını güncelle
		grab_ray.enabled = true
		grab_ray.target_position = Vector3(0, 0, -grab_ray_length)
		print("PlayerGrab: GrabRay found")


func _setup_hold_point() -> void:
	"""HoldPoint'i bul veya oluştur."""
	hold_point = camera.get_node_or_null("HoldPoint")
	
	if not hold_point:
		# HoldPoint yoksa oluştur
		hold_point = Node3D.new()
		hold_point.name = "HoldPoint"
		hold_point.position = Vector3(hold_offset_right, hold_offset_up, -hold_distance)
		camera.add_child(hold_point)
		print("PlayerGrab: HoldPoint created")
	else:
		# HoldPoint varsa pozisyonunu güncelle
		hold_point.position = Vector3(hold_offset_right, hold_offset_up, -hold_distance)
		print("PlayerGrab: HoldPoint found")


# ============================================
# INPUT HANDLING
# ============================================
func _input(event: InputEvent) -> void:
	# RMB (mouse right) kontrolü
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# RMB basıldı - grab dene
				_try_grab()
			else:
				# RMB bırakıldı - drop
				_drop()


func _process(delta: float) -> void:
	# Sürekli kontrol (Input Map action ile) - RMB basılı tutma için
	if Input.is_action_pressed("grab"):
		if not is_grabbing:
			_try_grab()
	elif Input.is_action_just_released("grab"):
		if is_grabbing:
			_drop()


# ============================================
# GRAB SYSTEM
# ============================================
func _try_grab() -> void:
	"""GrabRay ile "grabbable" obje bul ve tut."""
	if is_grabbing:
		return  # Zaten bir şey tutuluyor
	
	if not grab_ray or not grab_ray.is_colliding():
		return
	
	var collider = grab_ray.get_collider()
	if not collider:
		return
	
	# Grabbable grup kontrolü
	if not collider.is_in_group("grabbable"):
		return
	
	# RigidBody3D kontrolü
	var rigid_body: RigidBody3D = null
	if collider is RigidBody3D:
		rigid_body = collider as RigidBody3D
	elif collider.get_parent() is RigidBody3D:
		rigid_body = collider.get_parent() as RigidBody3D
	
	if not rigid_body:
		return
	
	# Tut
	_grab(rigid_body)


func _grab(body: RigidBody3D) -> void:
	"""Objeyi tut."""
	held_body = body
	is_grabbing = true
	
	# Shield ise held state'e al (set_held metodu varsa)
	if body.has_method("set_held"):
		body.set_held(true, player)
	
	print("PlayerGrab: Grabbed ", body.name)


func _drop() -> void:
	"""Tutulan objeyi bırak."""
	if not is_grabbing or not held_body:
		return
	
	# Shield ise held state'den çıkar (set_held metodu varsa)
	if held_body.has_method("set_held"):
		held_body.set_held(false, null)
	
	held_body = null
	is_grabbing = false
	print("PlayerGrab: Dropped object")


# ============================================
# PHYSICS PROCESS (Transform Interpolation for Shield)
# ============================================
func _physics_process(delta: float) -> void:
	if not is_grabbing or not held_body or not hold_point:
		return
	
	# Shield ise transform interpolasyonu kullan (stabil, jitter-free)
	if held_body.is_in_group("shield"):
		_update_shield_transform(delta)
	else:
		# Diğer objeler için spring force (eski sistem)
		_update_spring_force(delta)


func _update_shield_transform(delta: float) -> void:
	"""Shield için transform interpolasyonu (stabil, jitter-free)."""
	if not held_body or not hold_point or not camera:
		return
	
	# HoldPoint'in global transform'u
	var target_transform = hold_point.global_transform
	
	# Shield'in mevcut transform'u
	var current_transform = held_body.global_transform
	
	# Position interpolasyonu
	var target_pos = target_transform.origin
	var current_pos = current_transform.origin
	var new_pos = current_pos.lerp(target_pos, follow_lerp)
	
	# Rotation interpolasyonu (sadece Y ekseni - yaw)
	var target_basis = target_transform.basis
	var current_basis = current_transform.basis
	
	# Kameranın yönüne göre rotation (sadece Y ekseni)
	var camera_forward = -camera.global_transform.basis.z
	var target_yaw = atan2(camera_forward.x, camera_forward.z)
	var current_yaw = atan2(current_basis.z.x, current_basis.z.z)
	var new_yaw = lerp_angle(current_yaw, target_yaw, follow_lerp)
	
	# Yeni transform oluştur
	var new_basis = Basis()
	new_basis = new_basis.rotated(Vector3.UP, new_yaw)
	var new_transform = Transform3D(new_basis, new_pos)
	
	# Transform'u uygula (freeze=true olduğu için direkt set edilebilir)
	held_body.global_transform = new_transform


func _update_spring_force(delta: float) -> void:
	"""Diğer objeler için spring force (eski sistem)."""
	if not held_body or not hold_point:
		return
	
	# HoldPoint'in global pozisyonu
	var desired_pos = hold_point.global_position
	
	# Objenin mevcut pozisyonu ve hızı
	var current_pos = held_body.global_position
	var current_vel = held_body.linear_velocity
	
	# Spring force hesapla
	var displacement = desired_pos - current_pos
	var spring_force = displacement * pull_strength
	
	# Damping force (hızı azalt)
	var damping_force = -current_vel * damping
	
	# Toplam force
	var total_force = spring_force + damping_force
	
	# Force uygula
	held_body.apply_central_force(total_force)
	
	# Rotation damping (opsiyonel - objeyi sabitle)
	if rotation_strength > 0.0:
		var angular_vel = held_body.angular_velocity
		var rotation_damping = -angular_vel * rotation_strength
		held_body.apply_torque(rotation_damping)




# ============================================
# PUBLIC API
# ============================================
func is_holding_shield() -> bool:
	"""Shield tutuluyor mu?"""
	return is_grabbing and held_body and held_body.is_in_group("shield")


func get_held_body() -> RigidBody3D:
	"""Tutulan objeyi döndür."""
	return held_body

