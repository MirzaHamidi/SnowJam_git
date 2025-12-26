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

# Internal Variables
var current_state: State = State.NORMAL
var player: Node3D = null
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var next_dash_check_time: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var is_active: bool = false  # Spawn animasyonu bitene kadar false


func _ready() -> void:
	# Player'ı bul
	player = get_tree().get_first_node_in_group("player")
	
	if not player:
		print("WARNING: Enemy could not find player in 'player' group!")
		set_physics_process(false)
		return
	
	# İlk dash kontrol zamanını ayarla
	next_dash_check_time = randf_range(min_dash_interval, max_dash_interval)
	
	# Spawn olduğunda hareket kapalı (activate() çağrılana kadar)
	is_active = false


func _physics_process(delta: float) -> void:
	# Player yoksa dur
	if not player:
		return
	
	# Enemy aktif değilse (spawn animasyonu devam ediyorsa) hareket etme
	if not is_active:
		# Sadece gravity uygula (yere düşmesin)
		if not is_on_floor():
			velocity += get_gravity() * delta
			move_and_slide()
		return
	
	# Gravity uygula
	if not is_on_floor():
		velocity += get_gravity() * delta
	
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
	"""Normal yürüyüş hareketi - player'a doğru."""
	# Player'a doğru yön hesapla (sadece XZ düzleminde)
	var direction = (player.global_position - global_position)
	direction.y = 0  # Y eksenini sıfırla (sadece yatay hareket)
	direction = direction.normalized()
	
	# Hızı ayarla
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)


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
	current_state = State.DASH
	dash_timer = dash_duration
	
	# Player'a doğru dash yönü hesapla
	var direction = (player.global_position - global_position)
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
	print("Enemy activated - starting movement towards player")
