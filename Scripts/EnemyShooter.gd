extends CharacterBody3D

## Enemy Shooter - Uzak mesafe düşman, player'ı takip eder ve projectile fırlatır
## 
## REFACTOR NOTES:
## 1) EnemyFollow.gd benzeri yapı (bağımsız script)
## 2) Mesafe ayarları yok, sadece takip
## 3) Projectile fırlatma sistemi
## 4) Debug log'lar debug_enabled flag ile kontrol edilir

# ============================================
# EXPORT PARAMETERS
# ============================================
@export_group("Movement")
@export var move_speed: float = 3.5
@export var acceleration: float = 10.0
@export var rotation_speed: float = 5.0

@export_group("Navigation")
@export var path_update_interval: float = 0.2
@export var path_desired_distance: float = 0.5
@export var target_desired_distance: float = 0.5

@export_group("Combat")
@export var projectile_scene: PackedScene = null
@export var fire_rate: float = 1.2
@export var projectile_speed: float = 8.0
@export var projectile_damage: int = 5
@export var projectile_lifetime: float = 3.0
@export var max_range: float = 35.0
@export var aim_offset: Vector3 = Vector3(0, 1.0, 0)

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
var muzzle: Node3D = null
var muzzle_flash: GPUParticles3D = null

# ============================================
# RUNTIME STATE
# ============================================
var is_dead: bool = false
var path_update_timer: float = 0.0
var last_player_position: Vector3 = Vector3.ZERO
var position_update_threshold: float = 1.0
var use_direct_follow: bool = false
var knockback_vel: Vector3 = Vector3.ZERO
var fire_cooldown: float = 0.0

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
	_handle_follow_movement(delta)
	_try_shoot(delta)
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
		print("[ENEMYSHOOTER] Knockback applied: ", knockback_vel, " strength=", strength)


func take_damage(amount: int, push_direction: Vector3 = Vector3.ZERO) -> void:
	"""Enemy'ye hasar ver."""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(0, current_health)
	
	if debug_enabled:
		print("EnemyShooter took ", amount, " damage. Health: ", current_health, "/", max_health)
	
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
			print("WARNING: EnemyShooter - NavAgent not found! Using direct follow fallback.")
		use_direct_follow = true
	else:
		use_direct_follow = false
		if debug_enabled:
			print("[ENEMYSHOOTER] NavAgent found: ", nav_agent.name)
	
	visual_node = get_node_or_null("Visual")
	if not visual_node and debug_enabled:
		print("WARNING: EnemyShooter - Visual node not found!")
	
	muzzle = get_node_or_null("Muzzle")
	if not muzzle:
		push_error("EnemyShooter - Muzzle node not found!")
	else:
		muzzle_flash = muzzle.get_node_or_null("MuzzleFlash")
	if not muzzle_flash and debug_enabled:
		print("WARNING: EnemyShooter - MuzzleFlash particle not found!")
	
	_validate_projectile_scene()


func _validate_projectile_scene() -> void:
	if not projectile_scene:
		push_warning("EnemyShooter - projectile_scene not set! Will not be able to shoot.")
	elif debug_enabled:
		print("EnemyShooter - Projectile scene set: ", projectile_scene.resource_path)


func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		if debug_enabled:
			print("WARNING: EnemyShooter - Player not found in 'player' group! Enemy will be idle.")
		return
	
	if player is Node3D and not player is CharacterBody3D:
		var character_body = player.get_node_or_null("CharacterBody3D")
		if character_body:
			player = character_body
	
	last_player_position = player.global_position
	
	if debug_enabled:
		print("EnemyShooter - Player found: ", player.name)


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


func _handle_follow_movement(delta: float) -> void:
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
		if debug_enabled:
			print("[ENEMYSHOOTER] _follow_navigation: nav_agent or player is null")
		return
	
	# Her frame target_position'ı güncelle (daha responsive takip için)
	nav_agent.target_position = player.global_position
	last_player_position = player.global_position
	
	# Navigation path hazır mı kontrol et
	if not nav_agent.is_navigation_finished():
		_move_towards_next_path_position(delta)
	else:
		# Path yoksa veya tamamlandıysa, direkt player'a doğru git
		var distance_to_player = (player.global_position - global_position).length()
		if distance_to_player > MIN_DISTANCE_TO_NEXT:
			_follow_direct(delta)
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
	direction = direction.normalized()
	
	var target_velocity = direction * move_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

# ============================================
# PRIVATE HELPERS - ROTATION
# ============================================
func _update_rotation(delta: float) -> void:
	if player:
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
# PRIVATE HELPERS - SHOOTING
# ============================================
func _try_shoot(delta: float) -> void:
	if not projectile_scene or not muzzle:
		return
	
	if not _ensure_player_valid(delta):
		return
	
	fire_cooldown -= delta
	if fire_cooldown > 0.0:
		return
	
	var distance = _get_distance_to_player()
	if distance > max_range:
		return
	
	_shoot()


func _shoot() -> void:
	if not _can_shoot():
		return
	
	var projectile_instance = projectile_scene.instantiate()
	if not projectile_instance:
		push_error("EnemyShooter - Failed to instantiate projectile!")
		return
	
	# Instantiate edilen node'un class'ını print et
	print("[Shooter] spawned projectile:", projectile_instance.name, " type=", projectile_instance.get_class(), " groups=", projectile_instance.get_groups())
	
	var current_scene = get_tree().current_scene
	if not current_scene:
		push_error("EnemyShooter - No current scene found!")
		return
	
	var target_pos = player.global_position + aim_offset
	var direction = (target_pos - muzzle.global_position).normalized()
	
	# Projectile'ı spawn et ve pozisyonunu biraz ileriye al (spawn collision'ı önlemek için)
	current_scene.add_child(projectile_instance)
	# Spawn pozisyonunu direction yönünde daha büyük bir offset ile ileriye al
	var spawn_offset = direction * 5  # 0.5 birim ileriye al (spawn collision'ı önlemek için)
	projectile_instance.global_position = muzzle.global_position + spawn_offset
	
	_configure_projectile(projectile_instance, direction)
	_trigger_muzzle_flash(direction)
	
	fire_cooldown = fire_rate
	
	if debug_enabled:
		print("[ENEMYSHOOTER] Fired projectile at player! Direction: ", direction, " Target: ", target_pos)


func _can_shoot() -> bool:
	if not projectile_scene or not muzzle:
		if debug_enabled:
			print("WARNING: EnemyShooter - Cannot shoot: missing projectile_scene or muzzle!")
		return false
	
	if not player or not is_instance_valid(player):
		if debug_enabled:
			print("WARNING: EnemyShooter - Cannot shoot: player not found!")
		_find_player()
		return false
	
	return true


func _configure_projectile(projectile: Node, direction: Vector3) -> void:
	if not projectile.is_in_group("projectile"):
		projectile.add_to_group("projectile")
		if debug_enabled:
			print("[ENEMYSHOOTER] Added projectile to 'projectile' group")
	
	if projectile.has_method("setup"):
		# Check argument count of setup method to maintain backward compatibility
		# setup(direction, speed, damage, shooter, lifetime) -> 5 args
		# setup(direction, speed, damage, shooter) -> 4 args
		projectile.setup(direction, projectile_speed, projectile_damage, self, projectile_lifetime)
		if debug_enabled:
			print("[ENEMYSHOOTER] Projectile fired with setup() method")
	else:
		_configure_projectile_legacy(projectile, direction)


func _configure_projectile_legacy(projectile: Node, direction: Vector3) -> void:
	if "velocity" in projectile:
		projectile.velocity = direction.normalized() * projectile_speed
	if "speed" in projectile:
		projectile.speed = projectile_speed
	if "damage" in projectile:
		projectile.damage = projectile_damage
	if "projectile_owner" in projectile:
		projectile.projectile_owner = self
	if "life_time" in projectile:
		projectile.life_time = projectile_lifetime
	
	if debug_enabled:
		print("[ENEMYSHOOTER] Projectile fired with direct property assignment")


func _trigger_muzzle_flash(direction: Vector3) -> void:
	if not muzzle_flash:
		return
	
	# MuzzleFlash partiküllerinin yönünü projectile yönüne göre ayarla
	var material = muzzle_flash.process_material as ParticleProcessMaterial
	if material:
		var new_material = material.duplicate() as ParticleProcessMaterial
		if new_material:
			# Direction'ı local space'e çevir (muzzle node'una göre)
			var local_direction = muzzle.to_local(muzzle.global_position + direction) - muzzle.to_local(muzzle.global_position)
			local_direction = local_direction.normalized()
			new_material.direction = local_direction
			muzzle_flash.process_material = new_material
	
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	
	if debug_enabled:
		print("[ENEMYSHOOTER] MuzzleFlash triggered with direction: ", direction)

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
			print("EnemyShooter - Playing mixamo_com_001 animation in loop mode")
	else:
		if debug_enabled:
			print("WARNING: EnemyShooter - Animation 'mixamo_com_001' not found! Available: ", animation_player.get_animation_list())


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
