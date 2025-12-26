extends CharacterBody3D

# Enemy State
enum State {
	NORMAL,
	DASH
}

# Export Variables
@export var move_speed: float = 3.5
@export var dash_speed: float = 12.0
@export var dash_duration: float = 0.25
@export var min_dash_interval: float = 1.5
@export var max_dash_interval: float = 3.5
@export var dash_chance: float = 0.4  # 0.0 - 1.0
@export var rotation_speed: float = 5.0  # Rotation lerp hızı
@export var player_distance_threshold: float = 20.0  # Player'dan bu mesafeden uzaktaysa rastgele hareket
@export var random_wander_speed: float = 2.0  # Rastgele hareket hızı

# Internal Variables
var current_state: State = State.NORMAL
var player: Node3D = null
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var next_dash_check_time: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var is_active: bool = false  # Spawn animasyonu bitene kadar false
var random_wander_direction: Vector3 = Vector3.ZERO
var wander_direction_timer: float = 0.0
var wander_direction_change_interval: float = 2.0  # Rastgele yön değiştirme süresi


func _ready() -> void:
	# Player'ı bul (eğer set_player ile set edilmediyse)
	if not player:
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			# Player Node3D root'u içindeki CharacterBody3D'yi bul
			var character_body = player_node.get_node_or_null("CharacterBody3D")
			if character_body:
				player = character_body
			else:
				player = player_node
	
	if not player:
		print("WARNING: Enemy could not find player in 'player' group!")
		return
	
	# İlk dash kontrol zamanını ayarla
	next_dash_check_time = randf_range(min_dash_interval, max_dash_interval)
	
	# Spawn olduğunda hareket kapalı (activate() çağrılana kadar)
	is_active = false
	
	# İlk rastgele yön seç
	random_wander_direction = Vector3(cos(randf() * TAU), 0, sin(randf() * TAU))
	wander_direction_timer = 0.0


func set_player(new_player: Node3D) -> void:
	"""Player referansını dışarıdan set et (spawner'dan çağrılabilir)."""
	player = new_player


func _physics_process(delta: float) -> void:
	# Player yoksa tekrar bul
	if not player:
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			var character_body = player_node.get_node_or_null("CharacterBody3D")
			if character_body:
				player = character_body
			else:
				player = player_node
		
		if not player:
			# Sadece gravity uygula
			if not is_on_floor():
				velocity += get_gravity() * delta
				move_and_slide()
			return
	
	# Gravity her zaman uygula
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Enemy aktif değilse (spawn animasyonu devam ediyorsa) sadece gravity uygula
	if not is_active:
		move_and_slide()
		return
	
	# Enemy aktif - normal hareket
	
	# State'e göre hareket et
	match current_state:
		State.NORMAL:
			_normal_movement(delta)
			_check_dash_opportunity(delta)
		State.DASH:
			_dash_movement(delta)
	
	# Hareketi uygula
	move_and_slide()
	
	# Rotation'ı yumuşak bir şekilde hareket yönüne çevir
	_update_rotation(delta)


func _normal_movement(delta: float) -> void:
	"""Normal yürüyüş hareketi - player'a yakınsa player'a doğru, uzaksa rastgele hareket."""
	if not player:
		# Player'ı tekrar bul
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return
	
	# Player'ın gerçek pozisyonunu al (CharacterBody3D'nin pozisyonu)
	var player_position: Vector3 = player.global_position
	
	# Player'a olan mesafeyi hesapla (sadece XZ düzleminde)
	var to_player = player_position - global_position
	to_player.y = 0  # Y eksenini sıfırla
	var distance_to_player = to_player.length()
	
	# Çok yakınsa dur (player'a çok yaklaşmasın)
	if distance_to_player < 1.0:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	
	var direction: Vector3
	var current_speed: float
	
	# Player'dan 20m uzaktaysa rastgele hareket et
	if distance_to_player > player_distance_threshold:
		direction = _get_random_wander_direction(delta)
		current_speed = random_wander_speed
	else:
		# Player'a yakınsa player'a doğru yürü
		direction = to_player.normalized()
		current_speed = move_speed
	
	# Hızı ayarla
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)


func _get_random_wander_direction(delta: float) -> Vector3:
	"""Rastgele yön değiştirme - belirli aralıklarla yeni rastgele yön seç."""
	wander_direction_timer -= delta
	
	# Yön değiştirme zamanı geldi mi?
	if wander_direction_timer <= 0.0:
		# Yeni rastgele yön seç (XZ düzleminde)
		var random_angle = randf() * TAU  # 0-2π arası açı
		random_wander_direction = Vector3(cos(random_angle), 0, sin(random_angle))
		wander_direction_timer = wander_direction_change_interval
	
	return random_wander_direction


func _check_dash_opportunity(delta: float) -> void:
	"""Dash fırsatını kontrol et ve rastgele dash at."""
	# Dash cooldown kontrolü
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
		return
	
	# Dash kontrol zamanı geldi mi?
	next_dash_check_time -= delta
	
	if next_dash_check_time <= 0.0:
		# Dash şansı var mı?
		if randf() < dash_chance:
			_start_dash()
		
		# Bir sonraki dash kontrol zamanını ayarla
		next_dash_check_time = randf_range(min_dash_interval, max_dash_interval)


func _start_dash() -> void:
	"""Dash'i başlat."""
	if not player:
		return
	
	current_state = State.DASH
	dash_timer = dash_duration
	
	# Player'ın gerçek pozisyonunu al (CharacterBody3D'nin pozisyonu)
	var player_position: Vector3 = player.global_position
	
	# Player'a doğru dash yönü hesapla
	var direction = (player_position - global_position)
	direction.y = 0  # Sadece yatay
	direction = direction.normalized()
	dash_direction = direction
	
	print("DASH")
	
	# Dash hızını ayarla
	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed


func _dash_movement(delta: float) -> void:
	"""Dash hareketi."""
	# Dash timer'ı güncelle
	dash_timer -= delta
	
	# Dash sırasında duvara çarptıysa erken bitir
	if is_on_wall():
		_end_dash()
		return
	
	# Dash süresi doldu mu?
	if dash_timer <= 0.0:
		_end_dash()
		return
	
	# Dash yönünde hareket et (sadece yatay)
	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed


func _end_dash() -> void:
	"""Dash'i bitir ve normal duruma dön."""
	current_state = State.NORMAL
	dash_timer = 0.0
	
	# Dash cooldown başlat (dash bitince hemen tekrar dash olmasın)
	dash_cooldown_timer = 0.5  # Kısa bir cooldown
	
	# Hızı sıfırla (normal hareket başlayacak)
	velocity.x = 0.0
	velocity.z = 0.0


func _update_rotation(delta: float) -> void:
	"""Enemy'nin rotation'ını hareket yönüne yumuşak bir şekilde çevir."""
	# Enemy aktif değilse rotation güncelleme
	if not is_active:
		return
	
	# Hareket yönü var mı?
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	
	if horizontal_velocity.length() > 0.1:
		# Hareket yönünü hesapla
		var target_direction = horizontal_velocity.normalized()
		
		# Y ekseni etrafında rotasyon hesapla
		var target_rotation_y = atan2(target_direction.x, target_direction.z)
		
		# Yumuşak rotasyon (lerp)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * delta)


func activate() -> void:
	"""Spawn animasyonu bitince enemy'yi aktif et - player'a doğru yürümeye başlar."""
	is_active = true
	
	# Eğer player yoksa tekrar bul
	if not player:
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			var character_body = player_node.get_node_or_null("CharacterBody3D")
			if character_body:
				player = character_body
			else:
				player = player_node
		
		if not player:
			print("WARNING: Enemy activated but player not found!")
			return
	
	print("Enemy activated at position: ", global_position, " - Player at: ", player.global_position)
	set_physics_process(true)
