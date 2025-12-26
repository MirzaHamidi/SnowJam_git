extends RigidBody3D

# İlk pozisyon ve rotasyon (sahne başladığında kaydedilecek)
var initial_position: Vector3
var initial_rotation: Vector3
# Animasyon süresi (saniye)
const RESET_DURATION := 0.5
# R tuşuna basılı tutuluyor mu?
var is_r_pressed := false


func _ready() -> void:
	# İlk pozisyon ve rotasyonu kaydet
	initial_position = global_position
	initial_rotation = rotation
	
	# Fizik simülasyonunun aktif olduğundan emin ol
	freeze = false
	# Collision layer ve mask ayarlarını kontrol et
	collision_layer = 1
	collision_mask = 1


func _input(event: InputEvent) -> void:
	# R tuşuna basıldığında
	if event is InputEventKey:
		if event.keycode == KEY_R:
			if event.pressed and not event.echo:
				# R tuşuna basıldı
				is_r_pressed = true
				_reset_to_initial_position()
			elif not event.pressed:
				# R tuşu bırakıldı - fizik simülasyonunu tekrar aktif et
				is_r_pressed = false
				# Eğer freeze edilmişse, unfreeze et
				if freeze:
					freeze = false
					linear_velocity = Vector3.ZERO
					angular_velocity = Vector3.ZERO
					# Collision ayarlarını koru
					collision_layer = 1
					collision_mask = 1


func _reset_to_initial_position() -> void:
	"""Küpü ilk pozisyonuna yumuşak bir şekilde döndür."""
	# Fizik simülasyonunu geçici olarak durdur (daha kontrollü animasyon için)
	freeze = true
	
	# Hızı sıfırla
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	# Tween ile pozisyon ve rotasyonu animasyonla değiştir
	var tween = get_tree().create_tween()
	tween.set_parallel(true)  # Paralel animasyonlar
	
	# Pozisyon animasyonu
	tween.tween_property(self, "global_position", initial_position, RESET_DURATION)
	# Rotasyon animasyonu
	tween.tween_property(self, "rotation", initial_rotation, RESET_DURATION)
	
	# Animasyon bittiğinde fizik simülasyonunu tekrar başlat
	tween.tween_callback(_unfreeze_after_reset)


func _unfreeze_after_reset() -> void:
	"""Animasyon bittiğinde fizik simülasyonunu tekrar başlat."""
	# Eğer R tuşu hala basılı tutulmuyorsa unfreeze et
	if not is_r_pressed:
		freeze = false
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		# Collision ayarlarını koru
		collision_layer = 1
		collision_mask = 1


func _physics_process(_delta: float) -> void:
	# R tuşuna basılı tutuluyorsa sürekli ilk pozisyonda tut
	if is_r_pressed:
		# Fizik simülasyonunu durdur ve ilk pozisyonda tut
		if not freeze:
			freeze = true
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
		
		# İlk pozisyona doğru yumuşak bir şekilde hareket et
		if global_position.distance_to(initial_position) > 0.01:
			global_position = global_position.lerp(initial_position, 0.2)
			rotation = rotation.lerp(initial_rotation, 0.2)
		else:
			# İlk pozisyona ulaştıysa tam olarak ayarla
			global_position = initial_position
			rotation = initial_rotation
	else:
		# R tuşu basılı değilse, freeze durumunu kontrol et
		# Eğer freeze edilmişse ve R tuşu basılı değilse, unfreeze et
		if freeze:
			freeze = false
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
			# Collision ayarlarını koru
			collision_layer = 1
			collision_mask = 1
