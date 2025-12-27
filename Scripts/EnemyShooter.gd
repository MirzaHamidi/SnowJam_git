extends CharacterBody3D

## Enemy Shooter - Uzak mesafe düşman, projectile fırlatır

# ============================================
# EXPORT PARAMETERS
# ============================================
@export_group("Movement")
@export var move_speed: float = 3.0
@export var acceleration: float = 10.0
@export var rotation_speed: float = 5.0

@export_group("Distances")
@export var desired_distance: float = 10.0  # İdeal mesafe (player'dan uzak durur)
@export var stop_distance: float = 8.0  # Bu mesafede durur
@export var retreat_distance: float = 6.0  # Bu mesafeden yakınsa geri kaçar

@export_group("Combat")
@export var projectile_scene: PackedScene = null
@export var fire_rate: float = 1.2  # Saniyede bir atış
@export var projectile_speed: float = 18.0
@export var projectile_damage: int = 1
@export var max_range: float = 35.0
@export var aim_offset: Vector3 = Vector3(0, 1.0, 0)  # Player'ın göğsüne nişan al

@export_group("Navigation")
@export var path_update_interval: float = 0.2
@export var path_desired_distance: float = 0.5
@export var target_desired_distance: float = 0.5

@export_group("Health")
@export var max_health: int = 15
@export var current_health: int = 15

# ============================================
# INTERNAL VARIABLES
# ============================================
var player: Node3D = null
var nav_agent: NavigationAgent3D = null
var visual_node: Node3D = null
var muzzle: Node3D = null
var muzzle_flash: GPUParticles3D = null
var line_of_sight: RayCast3D = null

var is_dead: bool = false
var fire_cooldown: float = 0.0
var path_update_timer: float = 0.0
var last_player_position: Vector3 = Vector3.ZERO
var position_update_threshold: float = 1.0

var use_direct_follow: bool = false

# ============================================
# READY
# ============================================
func _ready() -> void:
	# Health başlat
	current_health = max_health
	is_dead = false
	
	# Node referanslarını bul
	_setup_nodes()
	
	# Player'ı bul
	_find_player()
	
	# NavigationAgent ayarlarını yap
	_setup_navigation()
	
	# Animasyonu başlat
	call_deferred("_play_mixamo_animation")


func _setup_nodes() -> void:
	"""Gerekli node'ları bul ve kaydet."""
	# NavigationAgent3D
	nav_agent = get_node_or_null("NavAgent")
	if not nav_agent:
		print("WARNING: EnemyShooter - NavAgent not found! Using direct follow fallback.")
		use_direct_follow = true
	else:
		use_direct_follow = false
	
	# Visual node
	visual_node = get_node_or_null("Visual")
	if not visual_node:
		print("WARNING: EnemyShooter - Visual node not found!")
	
	# Muzzle (silah ucu)
	muzzle = get_node_or_null("Muzzle")
	if not muzzle:
		push_error("EnemyShooter - Muzzle node not found!")
	else:
		# MuzzleFlash particle'ı bul
		muzzle_flash = muzzle.get_node_or_null("MuzzleFlash")
		if not muzzle_flash:
			print("WARNING: EnemyShooter - MuzzleFlash particle not found!")
	
	# Line of sight
	line_of_sight = get_node_or_null("LineOfSight")
	if line_of_sight:
		line_of_sight.enabled = true


func _find_player() -> void:
	"""Player'ı 'player' grubundan bul."""
	var player_node = get_tree().get_first_node_in_group("player")
	
	if not player_node:
		print("WARNING: EnemyShooter - Player not found in 'player' group!")
		player = null
		return
	
	# Player Node3D ise CharacterBody3D'yi al
	if player_node is Node3D and not player_node is CharacterBody3D:
		var character_body = player_node.get_node_or_null("CharacterBody3D")
		if character_body:
			player = character_body
		else:
			player = player_node
	else:
		player = player_node
	
	if player:
		last_player_position = player.global_position
		print("EnemyShooter: Player found at position: ", player.global_position)


func _setup_navigation() -> void:
	"""NavigationAgent3D ayarlarını yap."""
	if not nav_agent:
		return
	
	nav_agent.path_desired_distance = path_desired_distance
	nav_agent.target_desired_distance = target_desired_distance
	nav_agent.path_max_distance = 50.0
	
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.5
	
	if player:
		nav_agent.target_position = player.global_position
	
	await get_tree().physics_frame
	await get_tree().physics_frame


# ============================================
# PHYSICS PROCESS
# ============================================
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Player'ı sürekli kontrol et (bulunamazsa tekrar dene)
	# Player'ı sürekli kontrol et (bulunamazsa tekrar dene)
	if not player:
		_find_player()
		if not player:
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0, acceleration * delta)
			_apply_gravity(delta)
			move_and_slide()
			return
	
	# Player geçersiz hale gelmişse tekrar bul
	if not is_instance_valid(player):
		_find_player()
		if not player:
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0, acceleration * delta)
			_apply_gravity(delta)
			move_and_slide()
			return
	
	# Player geçersiz hale gelmişse tekrar bul
	if not is_instance_valid(player):
		_find_player()
		if not player:
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0, acceleration * delta)
			_apply_gravity(delta)
			move_and_slide()
			return
	
	# Gravity
	_apply_gravity(delta)
	
	# Mesafe kontrolü
	var distance_to_player = _get_distance_to_player()
	
	# Çok yakınsa geri kaç
	if distance_to_player < retreat_distance:
		_retreat_from_player(delta)
		move_and_slide()
		_update_rotation(delta)
		return
	
	# İdeal mesafede dur veya uzaklaş
	if distance_to_player <= stop_distance:
		# Dur ve ateş et
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		_look_at_player(delta)
		_try_shoot(delta)
		move_and_slide()
		return
	
	# İdeal mesafeden uzaksa yaklaş
	if distance_to_player > desired_distance:
		_follow_player(delta)
	else:
		# İdeal mesafede, dur ve ateş et
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		_look_at_player(delta)
		_try_shoot(delta)
	
	move_and_slide()
	_update_rotation(delta)


func _apply_gravity(delta: float) -> void:
	"""Y ekseninde gravity uygula."""
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	else:
		if velocity.y < 0:
			velocity.y = 0


func _follow_player(delta: float) -> void:
	"""Player'ı takip et (navigation veya direkt)."""
	if not nav_agent or use_direct_follow:
		_follow_direct(delta)
		return
	
	# Path update
	path_update_timer -= delta
	var player_moved = (player.global_position - last_player_position).length() > position_update_threshold
	
	if path_update_timer <= 0.0 or player_moved:
		nav_agent.target_position = player.global_position
		last_player_position = player.global_position
		path_update_timer = path_update_interval
	
	# Navigation ile hareket
	if not nav_agent.is_navigation_finished():
		var next_path_pos = nav_agent.get_next_path_position()
		var current_pos = global_position
		
		var distance_to_next = (next_path_pos - current_pos).length()
		if distance_to_next < 0.1:
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0, acceleration * delta)
			return
		
		var direction = (next_path_pos - current_pos)
		direction.y = 0
		direction = direction.normalized()
		
		var target_velocity = direction * move_speed
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)


func _follow_direct(delta: float) -> void:
	"""Fallback: Direkt player'a doğru git."""
	if not player:
		return
	
	var direction = (player.global_position - global_position)
	direction.y = 0
	var distance = direction.length()
	
	if distance > stop_distance:
		direction = direction.normalized()
		var target_velocity = direction * move_speed
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)


func _retreat_from_player(delta: float) -> void:
	"""Player'dan geri kaç."""
	if not player:
		return
	
	var direction = (global_position - player.global_position)
	direction.y = 0
	direction = direction.normalized()
	
	var target_velocity = direction * move_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)


func _update_rotation(delta: float) -> void:
	"""Player'a doğru dön (sadece Y ekseni)."""
	if not player:
		return
	
	var direction = (player.global_position - global_position)
	direction.y = 0
	if direction.length() > 0.01:
		var target_rotation_y = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * delta)


func _look_at_player(delta: float) -> void:
	"""Player'a doğru bak."""
	_update_rotation(delta)


func _get_distance_to_player() -> float:
	"""Player'a olan yatay mesafeyi döndür."""
	if not player:
		return INF
	
	var to_player = player.global_position - global_position
	to_player.y = 0
	return to_player.length()


# ============================================
# SHOOTING
# ============================================
func _try_shoot(delta: float) -> void:
	"""Ateş etmeyi dene."""
	if not projectile_scene or not muzzle:
		return
	
	if not player or not is_instance_valid(player):
		_find_player()
		if not player:
			return
	
	# Cooldown kontrolü
	fire_cooldown -= delta
	if fire_cooldown > 0.0:
		return
	
	# Mesafe kontrolü (öncelik - çok uzaksa ateş etme)
	var distance = _get_distance_to_player()
	if distance > max_range:
		return
	
	# Line of sight kontrolü (opsiyonel - eğer varsa ve çok katı değilse)
	# Not: Line of sight çok katı olabilir, bu yüzden şimdilik devre dışı bırakıyoruz
	# İsterseniz bu kontrolü açabilirsiniz
	# if line_of_sight:
	# 	# Line of sight kontrolü...
	# 	pass
	
	# Ateş et
	_shoot()


func _shoot() -> void:
	"""Projectile fırlat."""
	if not projectile_scene or not muzzle:
		print("WARNING: EnemyShooter - Cannot shoot: missing projectile_scene or muzzle!")
		return
	
	if not player or not is_instance_valid(player):
		print("WARNING: EnemyShooter - Cannot shoot: player not found!")
		_find_player()
		return
	
	# Projectile instance oluştur
	var projectile_instance = projectile_scene.instantiate()
	if not projectile_instance:
		push_error("EnemyShooter - Failed to instantiate projectile!")
		return
	
	# Sahneye ekle (world'a)
	var current_scene = get_tree().current_scene
	if not current_scene:
		push_error("EnemyShooter - No current scene found!")
		return
	
	current_scene.add_child(projectile_instance)
	
	# Pozisyon ve yön
	projectile_instance.global_position = muzzle.global_position
	
	# Yön hesapla (player'a doğru + aim offset)
	var target_pos = player.global_position + aim_offset
	var direction = (target_pos - muzzle.global_position).normalized()
	
	# Projectile ayarlarını set et
	if projectile_instance.has_method("setup"):
		projectile_instance.setup(direction, projectile_speed, projectile_damage)
	else:
		# Duck typing: direkt property'leri set et
		if "dir" in projectile_instance:
			projectile_instance.dir = direction
		if "speed" in projectile_instance:
			projectile_instance.speed = projectile_speed
		if "damage" in projectile_instance:
			projectile_instance.damage = projectile_damage
	
	# Cooldown başlat
	fire_cooldown = fire_rate
	
	# Muzzle flash efekti
	if muzzle_flash:
		muzzle_flash.restart()
		muzzle_flash.emitting = true
	
	print("EnemyShooter: Fired projectile at player! Direction: ", direction, " Target: ", target_pos)


# ============================================
# ANIMATION
# ============================================
func _play_mixamo_animation() -> void:
	"""mixamo_com_001 animasyonunu loop modunda oynat."""
	if not visual_node:
		return
	
	var animation_player = visual_node.get_node_or_null("AnimationPlayer")
	if not animation_player:
		animation_player = _find_animation_player_recursive(visual_node)
	
	if not animation_player:
		return
	
	if animation_player.has_animation("mixamo_com_001"):
		var anim = animation_player.get_animation("mixamo_com_001")
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
		
		if not animation_player.animation_finished.is_connected(_on_mixamo_animation_finished):
			animation_player.animation_finished.connect(_on_mixamo_animation_finished)
		
		animation_player.play("mixamo_com_001")


func _on_mixamo_animation_finished(anim_name: String) -> void:
	"""Animasyon bitince tekrar başlat."""
	if anim_name == "mixamo_com_001" and visual_node:
		var animation_player = visual_node.get_node_or_null("AnimationPlayer")
		if not animation_player:
			animation_player = _find_animation_player_recursive(visual_node)
		
		if animation_player and animation_player.has_animation("mixamo_com_001"):
			animation_player.play("mixamo_com_001")


func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	"""Recursive olarak AnimationPlayer'ı bul."""
	if node is AnimationPlayer:
		return node as AnimationPlayer
	
	for child in node.get_children():
		var result = _find_animation_player_recursive(child)
		if result:
			return result
	
	return null


# ============================================
# HEALTH & DAMAGE
# ============================================
func take_damage(amount: int, push_direction: Vector3 = Vector3.ZERO) -> void:
	"""Enemy'ye hasar ver."""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(0, current_health)
	
	print("EnemyShooter took ", amount, " damage. Health: ", current_health, "/", max_health)
	
	if push_direction != Vector3.ZERO:
		var horizontal_push = push_direction
		horizontal_push.y = 0
		horizontal_push = horizontal_push.normalized()
		var push_force = horizontal_push * 8.0
		velocity.x += push_force.x
		velocity.z += push_force.z
		velocity.y += 2.0
	
	if current_health <= 0:
		_die()


func _die() -> void:
	"""Enemy'yi öldür."""
	if is_dead:
		return
	
	is_dead = true
	set_physics_process(false)
	
	var collision = get_node_or_null("CollisionShape3D")
	if collision:
		collision.disabled = true
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)

