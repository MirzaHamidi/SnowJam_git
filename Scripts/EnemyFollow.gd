extends CharacterBody3D

## Enemy Follow System with NavigationAgent3D
## Player'ı takip eder, engelleri aşar, mesafe kontrolü yapar

# ============================================
# EXPORT PARAMETERS
# ============================================
@export_group("Movement")
@export var move_speed: float = 3.5
@export var acceleration: float = 10.0
@export var rotation_speed: float = 5.0

@export_group("Distances")
@export var stop_distance: float = 1.5  # Bu mesafede durur (titreme önleme)
@export var attack_distance: float = 3.0  # Bu mesafede attack_ready = true

@export_group("Navigation")
@export var path_update_interval: float = 0.2  # Path güncelleme sıklığı (spam önleme)
@export var path_desired_distance: float = 0.5
@export var target_desired_distance: float = 0.5

@export_group("Health")
@export var max_health: int = 20
@export var current_health: int = 20

# ============================================
# INTERNAL VARIABLES
# ============================================
var player: Node3D = null
var nav_agent: NavigationAgent3D = null
var visual_node: Node3D = null
var attack_range_area: Area3D = null

var is_dead: bool = false
var attack_ready: bool = false
var path_update_timer: float = 0.0
var last_player_position: Vector3 = Vector3.ZERO
var position_update_threshold: float = 1.0  # Player bu kadar hareket ederse path güncelle

# Fallback: NavAgent yoksa direkt follow
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
		print("WARNING: Enemy - NavAgent not found! Using direct follow fallback.")
		use_direct_follow = true
	else:
		use_direct_follow = false
	
	# Visual node (mesh/anim burada)
	visual_node = get_node_or_null("Visual")
	if not visual_node:
		print("WARNING: Enemy - Visual node not found!")
	
	# AttackRange Area3D (opsiyonel)
	attack_range_area = get_node_or_null("AttackRange")
	if attack_range_area:
		# Attack range signal'larını bağla
		attack_range_area.body_entered.connect(_on_attack_range_entered)
		attack_range_area.body_exited.connect(_on_attack_range_exited)


func _find_player() -> void:
	"""Player'ı 'player' grubundan bul."""
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		print("WARNING: Enemy - Player not found in 'player' group! Enemy will be idle.")
		return
	
	# Player Node3D ise CharacterBody3D'yi al (eğer varsa)
	if player is Node3D and not player is CharacterBody3D:
		var character_body = player.get_node_or_null("CharacterBody3D")
		if character_body:
			player = character_body
	
	last_player_position = player.global_position
	print("Enemy - Player found: ", player.name)


func _setup_navigation() -> void:
	"""NavigationAgent3D ayarlarını yap."""
	if not nav_agent:
		return
	
	# Navigation ayarları
	nav_agent.path_desired_distance = path_desired_distance
	nav_agent.target_desired_distance = target_desired_distance
	nav_agent.path_max_distance = 50.0  # Maksimum path mesafesi
	
	# Avoidance (opsiyonel - açık bırakılabilir)
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.5
	
	# İlk target pozisyonunu ayarla
	if player:
		nav_agent.target_position = player.global_position
	
	# Navigation hazır olana kadar bekle
	await get_tree().physics_frame
	await get_tree().physics_frame


# ============================================
# PHYSICS PROCESS
# ============================================
func _physics_process(delta: float) -> void:
	# Ölüyse hiçbir şey yapma
	if is_dead:
		return
	
	# Player yoksa idle
	if not player:
		_find_player()
		if not player:
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0, acceleration * delta)
			_apply_gravity(delta)
			move_and_slide()
			return
	
	# Gravity her zaman uygula
	_apply_gravity(delta)
	
	# Mesafe kontrolü
	var distance_to_player = _get_distance_to_player()
	
	# Attack distance kontrolü
	if distance_to_player <= attack_distance:
		attack_ready = true
		# Attack mesafesinde dur
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		# Sadece player'a bak
		_look_at_player(delta)
		move_and_slide()
		return
	else:
		attack_ready = false
	
	# Stop distance kontrolü
	if distance_to_player <= stop_distance:
		# Çok yakınsa dur (titreme önleme)
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		_look_at_player(delta)
		move_and_slide()
		return
	
	# Navigation ile hareket
	if not use_direct_follow and nav_agent:
		_follow_navigation(delta)
	else:
		_follow_direct(delta)
	
	# Hareketi uygula
	move_and_slide()
	
	# Rotation güncelle (hareket yönüne)
	_update_rotation(delta)


func _apply_gravity(delta: float) -> void:
	"""Y ekseninde gravity uygula."""
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	else:
		# Yerdeyse y hızını sıfırla
		if velocity.y < 0:
			velocity.y = 0


func _follow_navigation(delta: float) -> void:
	"""NavigationAgent3D ile player'ı takip et."""
	if not nav_agent or not player:
		return
	
	# Path update timer
	path_update_timer -= delta
	
	# Player pozisyonu değişti mi kontrol et
	var player_moved = (player.global_position - last_player_position).length() > position_update_threshold
	
	# Path güncelle (interval veya player hareket ettiyse)
	if path_update_timer <= 0.0 or player_moved:
		nav_agent.target_position = player.global_position
		last_player_position = player.global_position
		path_update_timer = path_update_interval
	
	# Navigation hazır mı kontrol et
	if not nav_agent.is_navigation_finished():
		# Next path position al
		var next_path_pos = nav_agent.get_next_path_position()
		var current_pos = global_position
		
		# Next point çok yakınsa jitter fix
		var distance_to_next = (next_path_pos - current_pos).length()
		if distance_to_next < 0.1:
			velocity.x = move_toward(velocity.x, 0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0, acceleration * delta)
			return
		
		# Next point'e doğru hareket et
		var direction = (next_path_pos - current_pos)
		direction.y = 0  # Sadece yatay
		direction = direction.normalized()
		
		# Hızı acceleration ile güncelle
		var target_velocity = direction * move_speed
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	else:
		# Navigation bitti, dur
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)


func _follow_direct(delta: float) -> void:
	"""Fallback: NavAgent yoksa direkt player'a doğru git (engelsiz)."""
	if not player:
		return
	
	var direction = (player.global_position - global_position)
	direction.y = 0  # Sadece yatay
	var distance = direction.length()
	
	if distance > stop_distance:
		direction = direction.normalized()
		var target_velocity = direction * move_speed
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	else:
		# Çok yakınsa dur
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)


func _update_rotation(delta: float) -> void:
	"""Enemy'nin rotation'ını hareket yönüne smooth çevir (sadece Y ekseni)."""
	# Attack ready ise player'a bak
	if attack_ready and player:
		_look_at_player(delta)
		return
	
	# Hareket yönüne bak
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	if horizontal_velocity.length() > 0.1:
		var target_direction = horizontal_velocity.normalized()
		var target_rotation_y = atan2(target_direction.x, target_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * delta)


func _look_at_player(delta: float) -> void:
	"""Player'a doğru bak (sadece Y ekseni)."""
	if not player:
		return
	
	var direction = (player.global_position - global_position)
	direction.y = 0
	if direction.length() > 0.01:
		var target_rotation_y = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * delta)


func _get_distance_to_player() -> float:
	"""Player'a olan yatay mesafeyi döndür."""
	if not player:
		return INF
	
	var to_player = player.global_position - global_position
	to_player.y = 0  # Sadece yatay mesafe
	return to_player.length()


# ============================================
# ATTACK RANGE
# ============================================
func _on_attack_range_entered(body: Node) -> void:
	"""Attack range'a bir şey girdi."""
	if body == player or body.get_parent() == player or body.is_in_group("player"):
		attack_ready = true


func _on_attack_range_exited(body: Node) -> void:
	"""Attack range'dan bir şey çıktı."""
	if body == player or body.get_parent() == player or body.is_in_group("player"):
		attack_ready = false


# ============================================
# HEALTH & DAMAGE
# ============================================
func take_damage(amount: int, push_direction: Vector3 = Vector3.ZERO) -> void:
	"""Enemy'ye hasar ver."""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(0, current_health)
	
	print("Enemy took ", amount, " damage. Health: ", current_health, "/", max_health)
	
	# Push uygula
	if push_direction != Vector3.ZERO:
		var horizontal_push = push_direction
		horizontal_push.y = 0
		horizontal_push = horizontal_push.normalized()
		var push_force = horizontal_push * 8.0
		velocity.x += push_force.x
		velocity.z += push_force.z
		velocity.y += 2.0
	
	# Health 0 olursa öl
	if current_health <= 0:
		_die()


func _die() -> void:
	"""Enemy'yi öldür."""
	if is_dead:
		return
	
	is_dead = true
	set_physics_process(false)
	
	# Collision'ı kapat
	var collision = get_node_or_null("CollisionShape3D")
	if collision:
		collision.disabled = true
	
	# Scale animasyonu ile yok ol
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)


# ============================================
# ANIMATION
# ============================================
func _play_mixamo_animation() -> void:
	"""mixamo_com_001 animasyonunu loop modunda oynat."""
	if not visual_node:
		return
	
	# AnimationPlayer'ı bul
	var animation_player = visual_node.get_node_or_null("AnimationPlayer")
	if not animation_player:
		animation_player = _find_animation_player_recursive(visual_node)
	
	if not animation_player:
		print("WARNING: Enemy - Could not find AnimationPlayer!")
		return
	
	# mixamo_com_001 animasyonunu loop modunda oynat
	if animation_player.has_animation("mixamo_com_001"):
		var anim = animation_player.get_animation("mixamo_com_001")
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
		
		if not animation_player.animation_finished.is_connected(_on_mixamo_animation_finished):
			animation_player.animation_finished.connect(_on_mixamo_animation_finished)
		
		animation_player.play("mixamo_com_001")
		print("Enemy - Playing mixamo_com_001 animation in loop mode")
	else:
		print("WARNING: Enemy - Animation 'mixamo_com_001' not found! Available: ", animation_player.get_animation_list())


func _on_mixamo_animation_finished(anim_name: String) -> void:
	"""mixamo_com_001 animasyonu bitince tekrar başlat."""
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
# PUBLIC API
# ============================================
func set_player(new_player: Node3D) -> void:
	"""Player referansını dışarıdan set et."""
	player = new_player
	if player:
		last_player_position = player.global_position
		if nav_agent:
			nav_agent.target_position = player.global_position

