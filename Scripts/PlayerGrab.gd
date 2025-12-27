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
var held_item: Node = null  # ShieldItem veya diğer tutulan item'lar
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
	
	var hit = grab_ray.get_collider()
	if not hit:
		return
	
	# Debug log
	print("[Grab] Ray hit: ", hit, " class=", hit.get_class(), " name=", hit.name)
	
	# RigidBody3D kontrolü
	var rigid_body: RigidBody3D = null
	
	# Eğer hit bir Area3D ise (GrabProxy olabilir)
	if hit is Area3D:
		# GrabProxy kontrolü
		if hit.name == "GrabProxy" or hit.is_in_group("grabbable_proxy"):
			# Gerçek objeyi bul (parent Shield)
			var shield = hit.get_parent()
			if shield is RigidBody3D:
				rigid_body = shield as RigidBody3D
				print("[Grab] Found shield via GrabProxy: ", rigid_body.name)
			else:
				print("[Grab] GrabProxy parent is not RigidBody3D: ", shield.get_class())
		else:
			print("[Grab] Area3D hit but not GrabProxy: ", hit.name)
	# Eğer hit doğrudan RigidBody3D ise
	elif hit is RigidBody3D:
		rigid_body = hit as RigidBody3D
		print("[Grab] Direct RigidBody3D hit: ", rigid_body.name)
	# Eğer hit'in parent'ı RigidBody3D ise
	elif hit.get_parent() is RigidBody3D:
		rigid_body = hit.get_parent() as RigidBody3D
		print("[Grab] Found RigidBody3D via parent: ", rigid_body.name)
	
	if not rigid_body:
		print("[Grab] No RigidBody3D found from hit")
		return
	
	# Grabbable grup kontrolü
	if not rigid_body.is_in_group("grabbable"):
		print("[Grab] RigidBody3D is not in 'grabbable' group")
		return
	
	# Debug log
	print("[Grab] held_body: ", rigid_body.name)
	
	# Tut
	_grab(rigid_body)


func _grab(body: RigidBody3D) -> void:
	"""Objeyi tut."""
	held_body = body
	held_item = body  # ShieldItem script'i body'de olduğu için direkt body
	is_grabbing = true
	
	# Freeze yap (elde stabil)
	body.freeze = true
	
	# Shield ise held state'e al (set_held metodu varsa)
	if body.has_method("set_held"):
		body.set_held(true, player)
	
	# ShieldItem ise broken ve tree_exited signal'larını bağla
	if body.has_signal("broken"):
		if not body.broken.is_connected(_on_held_broken):
			body.broken.connect(_on_held_broken)
	
	# tree_exited signal'ını bağla (güvenlik)
	if not body.tree_exiting.is_connected(_on_held_tree_exiting):
		body.tree_exiting.connect(_on_held_tree_exiting)
	
	print("[Grab] PlayerGrab: Grabbed ", body.name, " freeze=", body.freeze)


func _drop() -> void:
	"""Tutulan objeyi bırak."""
	if not is_grabbing:
		return
	
	clear_held()


func clear_held() -> void:
	"""Held item'ı temizle (kırılma veya drop için)."""
	if held_item and is_instance_valid(held_item):
		# Signal bağlantılarını kaldır
		if held_item.has_signal("broken") and held_item.broken.is_connected(_on_held_broken):
			held_item.broken.disconnect(_on_held_broken)
		if held_item.tree_exiting.is_connected(_on_held_tree_exiting):
			held_item.tree_exiting.disconnect(_on_held_tree_exiting)
		
		# Shield ise held state'den çıkar (set_held metodu varsa)
		if held_item.has_method("set_held"):
			held_item.set_held(false, null)
	
	if held_body and is_instance_valid(held_body):
		# Freeze'i kaldır
		held_body.freeze = false
	
	var dropped_name = ""
	if held_body and is_instance_valid(held_body):
		dropped_name = held_body.name
	
	held_body = null
	held_item = null
	is_grabbing = false
	print("[Grab] cleared held item: ", dropped_name)


func _on_held_broken(_shield: Node) -> void:
	"""Held shield kırıldığında çağrılır."""
	print("[Grab] held shield broken -> clearing")
	clear_held()


func _on_held_tree_exiting() -> void:
	"""Held item tree'den çıkarken çağrılır (güvenlik)."""
	print("[Grab] held item tree_exiting -> clearing")
	clear_held()


# ============================================
# PHYSICS PROCESS (Transform Interpolation for Shield)
# ============================================
func _physics_process(delta: float) -> void:
	# Validity kontrolü (fallback - held item geçersiz hale gelirse temizle)
	if is_grabbing:
		if held_body == null or not is_instance_valid(held_body):
			print("[Grab] held_body invalid -> clearing")
			clear_held()
			return
		
		if held_item != null and not is_instance_valid(held_item):
			print("[Grab] held_item invalid -> clearing")
			clear_held()
			return
	
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

