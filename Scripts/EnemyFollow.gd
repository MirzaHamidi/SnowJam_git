extends CharacterBody3D

## Enemy Follow System with NavigationAgent3D
## Player'ı takip eder, engelleri aşar, mesafe kontrolü yapar
## 
## REFACTOR NOTES:
## 1) Debug log'lar debug_enabled flag ile kontrol edilir
## 2) Navigation, movement, knockback ayrı bölümlerde
## 3) Magic number'lar const/export yapıldı
## 4) Tip eklemeleri yapıldı (typed GDScript)
## 5) Erken return pattern kullanıldı

# ============================================
# EXPORT PARAMETERS
# ============================================
@export_group("Movement")
@export var move_speed: float = 3.5
@export var acceleration: float = 10.0
@export var rotation_speed: float = 5.0

@export_group("Distances")
@export var stop_distance: float = 1.5
@export var attack_distance: float = 3.0

@export_group("Navigation")
@export var path_update_interval: float = 0.2
@export var path_desired_distance: float = 0.5
@export var target_desired_distance: float = 0.5

@export_group("Health")
@export var max_health: int = 20
@export var current_health: int = 20

@export_group("Knockback")
@export var knockback_decay: float = 18.0

@export_group("Debug")
@export var debug_enabled: bool = false

# ============================================
# CONSTANTS
# ============================================
const NAV_PATH_MAX_DISTANCE: float = 50.0
const NAV_AVOIDANCE_RADIUS: float = 0.5
const MIN_DISTANCE_TO_NEXT: float = 0.1
const MIN_VELOCITY_THRESHOLD: float = 0.1
const MIN_ROTATION_VELOCITY: float = 0.1
const PUSH_FORCE_MULTIPLIER: float = 8.0
const PUSH_Y_VELOCITY: float = 2.0
const DEATH_SCALE_TIME: float = 0.3

# ============================================
# NODE REFERENCES
# ============================================
var player: Node3D = null
var nav_agent: NavigationAgent3D = null
var visual_node: Node3D = null
var attack_range_area: Area3D = null

# ============================================
# RUNTIME STATE
# ============================================
var is_dead: bool = false
var attack_ready: bool = false
var path_update_timer: float = 0.0
var last_player_position: Vector3 = Vector3.ZERO
var position_update_threshold: float = 1.0
var use_direct_follow: bool = false
var knockback_vel: Vector3 = Vector3.ZERO

# ============================================
# GODOT CALLBACKS
# ============================================
func _ready() -> void:
	current_health = max_health
	is_dead = false
	add_to_group("enemy")
	_setup_nodes()
	_find_player()
	_setup_navigation()
	call_deferred("_play_mixamo_animation")


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if not _ensure_player_valid(delta):
		return
	
	_apply_gravity(delta)
	
	var distance_to_player = _get_distance_to_player()
	
	if distance_to_player <= attack_distance:
		_handle_attack_range(delta)
		return
	
	if distance_to_player <= stop_distance:
		_handle_stop_range(delta)
		return
	
	_handle_follow_movement(delta)
	_apply_knockback(delta)
	move_and_slide()
	_update_rotation(delta)

# ============================================
# PUBLIC API
# ============================================
func set_player(new_player: Node3D) -> void:
	"""Player referansını dışarıdan set et."""
	player = new_player
	if player:
		last_player_position = player.global_position
		if nav_agent:
			nav_agent.target_position = player.global_position


func apply_knockback(dir: Vector3, strength: float) -> void:
	"""Knockback uygula (deflected projectile tarafından çağrılır)."""
	dir.y = 0
	knockback_vel = dir.normalized() * strength
	
	if debug_enabled:
		print("[ENEMY] Knockback applied: ", knockback_vel, " strength=", strength)


func take_damage(amount: int, push_direction: Vector3 = Vector3.ZERO) -> void:
	"""Enemy'ye hasar ver."""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(0, current_health)
	
	if debug_enabled:
		print("Enemy took ", amount, " damage. Health: ", current_health, "/", max_health)
	
	if push_direction != Vector3.ZERO:
		_apply_push(push_direction)
	
	if current_health <= 0:
		_die()

# ============================================
# PRIVATE HELPERS - SETUP
# ============================================
func _setup_nodes() -> void:
	nav_agent = get_node_or_null("NavAgent")
	if not nav_agent:
		if debug_enabled:
			print("WARNING: Enemy - NavAgent not found! Using direct follow fallback.")
		use_direct_follow = true
	else:
		use_direct_follow = false
	
	visual_node = get_node_or_null("Visual")
	if not visual_node and debug_enabled:
		print("WARNING: Enemy - Visual node not found!")
	
	attack_range_area = get_node_or_null("AttackRange")
	if attack_range_area:
		_connect_attack_range_signals()


func _connect_attack_range_signals() -> void:
	attack_range_area.body_entered.connect(_on_attack_range_entered)
	attack_range_area.body_exited.connect(_on_attack_range_exited)


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		if debug_enabled:
			print("WARNING: Enemy - Player not found in 'player' group! Enemy will be idle.")
		return
	
	if player is Node3D and not player is CharacterBody3D:
		var character_body = player.get_node_or_null("CharacterBody3D")
		if character_body:
			player = character_body
	
	last_player_position = player.global_position
	
	if debug_enabled:
		print("Enemy - Player found: ", player.name)


func _setup_navigation() -> void:
	if not nav_agent:
		return
	
	nav_agent.path_desired_distance = path_desired_distance
	nav_agent.target_desired_distance = target_desired_distance
	nav_agent.path_max_distance = NAV_PATH_MAX_DISTANCE
	nav_agent.avoidance_enabled = true
	nav_agent.radius = NAV_AVOIDANCE_RADIUS
	
	if player:
		nav_agent.target_position = player.global_position
	
	await get_tree().physics_frame
	await get_tree().physics_frame

# ============================================
# PRIVATE HELPERS - PHYSICS PROCESS
# ============================================
func _ensure_player_valid(delta: float) -> bool:
	if not player:
		_find_player()
		if not player:
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0, acceleration * delta)
			_apply_gravity(delta)
			move_and_slide()
			return false
	return true


func _handle_attack_range(delta: float) -> void:
	attack_ready = true
	velocity.x = move_toward(velocity.x, 0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0, acceleration * delta)
	_look_at_player(delta)
	_apply_knockback(delta)
	move_and_slide()


func _handle_stop_range(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0, acceleration * delta)
	_look_at_player(delta)
	_apply_knockback(delta)
	move_and_slide()


func _handle_follow_movement(delta: float) -> void:
	attack_ready = false
	
	if not use_direct_follow and nav_agent:
		_follow_navigation(delta)
	else:
		_follow_direct(delta)

# ============================================
# PRIVATE HELPERS - MOVEMENT
# ============================================
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	else:
		if velocity.y < 0:
			velocity.y = 0


func _follow_navigation(delta: float) -> void:
	if not nav_agent or not player:
		return
	
	path_update_timer -= delta
	var player_moved = (player.global_position - last_player_position).length() > position_update_threshold
	
	if path_update_timer <= 0.0 or player_moved:
		nav_agent.target_position = player.global_position
		last_player_position = player.global_position
		path_update_timer = path_update_interval
	
	if not nav_agent.is_navigation_finished():
		_move_towards_next_path_position(delta)
	else:
		_stop_movement(delta)


func _move_towards_next_path_position(delta: float) -> void:
	var next_path_pos = nav_agent.get_next_path_position()
	var current_pos = global_position
	var distance_to_next = (next_path_pos - current_pos).length()
	
	if distance_to_next < MIN_DISTANCE_TO_NEXT:
		_stop_movement(delta)
		return
	
	var direction = (next_path_pos - current_pos)
	direction.y = 0
	direction = direction.normalized()
	
	var target_velocity = direction * move_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)


func _stop_movement(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0, acceleration * delta)


func _follow_direct(delta: float) -> void:
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
		_stop_movement(delta)

# ============================================
# PRIVATE HELPERS - ROTATION
# ============================================
func _update_rotation(delta: float) -> void:
	if attack_ready and player:
		_look_at_player(delta)
		return
	
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	if horizontal_velocity.length() > MIN_ROTATION_VELOCITY:
		var target_direction = horizontal_velocity.normalized()
		var target_rotation_y = atan2(target_direction.x, target_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * delta)


func _look_at_player(delta: float) -> void:
	if not player:
		return
	
	var direction = (player.global_position - global_position)
	direction.y = 0
	if direction.length() > 0.01:
		var target_rotation_y = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * delta)

# ============================================
# PRIVATE HELPERS - KNOCKBACK
# ============================================
func _apply_knockback(delta: float) -> void:
	if knockback_vel.length() < MIN_VELOCITY_THRESHOLD:
		knockback_vel = Vector3.ZERO
		return
	
	velocity.x += knockback_vel.x
	velocity.z += knockback_vel.z
	knockback_vel = knockback_vel.move_toward(Vector3.ZERO, knockback_decay * delta)

# ============================================
# PRIVATE HELPERS - UTILITY
# ============================================
func _get_distance_to_player() -> float:
	if not player:
		return INF
	
	var to_player = player.global_position - global_position
	to_player.y = 0
	return to_player.length()


func _apply_push(push_direction: Vector3) -> void:
	var horizontal_push = push_direction
	horizontal_push.y = 0
	horizontal_push = horizontal_push.normalized()
	var push_force = horizontal_push * PUSH_FORCE_MULTIPLIER
	velocity.x += push_force.x
	velocity.z += push_force.z
	velocity.y += PUSH_Y_VELOCITY

# ============================================
# PRIVATE HELPERS - ATTACK RANGE
# ============================================
func _on_attack_range_entered(body: Node) -> void:
	if body == player or body.get_parent() == player or body.is_in_group("player"):
		attack_ready = true


func _on_attack_range_exited(body: Node) -> void:
	if body == player or body.get_parent() == player or body.is_in_group("player"):
		attack_ready = false

# ============================================
# PRIVATE HELPERS - HEALTH & DEATH
# ============================================
func _die() -> void:
	if is_dead:
		return
	
	is_dead = true
	set_physics_process(false)
	
	var collision = get_node_or_null("CollisionShape3D")
	if collision:
		collision.disabled = true
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, DEATH_SCALE_TIME)
	tween.tween_callback(queue_free)

# ============================================
# PRIVATE HELPERS - ANIMATION
# ============================================
func _play_mixamo_animation() -> void:
	if not visual_node:
		return
	
	var animation_player = _find_animation_player()
	if not animation_player:
		return
	
	if animation_player.has_animation("mixamo_com_001"):
		var anim = animation_player.get_animation("mixamo_com_001")
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
		
		if not animation_player.animation_finished.is_connected(_on_mixamo_animation_finished):
			animation_player.animation_finished.connect(_on_mixamo_animation_finished)
		
		animation_player.play("mixamo_com_001")
		
		if debug_enabled:
			print("Enemy - Playing mixamo_com_001 animation in loop mode")
	else:
		if debug_enabled:
			print("WARNING: Enemy - Animation 'mixamo_com_001' not found! Available: ", animation_player.get_animation_list())


func _find_animation_player() -> AnimationPlayer:
	var animation_player = visual_node.get_node_or_null("AnimationPlayer")
	if animation_player:
		return animation_player
	
	return _find_animation_player_recursive(visual_node)


func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	
	for child in node.get_children():
		var result = _find_animation_player_recursive(child)
		if result:
			return result
	
	return null


func _on_mixamo_animation_finished(anim_name: String) -> void:
	if anim_name == "mixamo_com_001" and visual_node:
		var animation_player = _find_animation_player()
		if animation_player and animation_player.has_animation("mixamo_com_001"):
			animation_player.play("mixamo_com_001")
