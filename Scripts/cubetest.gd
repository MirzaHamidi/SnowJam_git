extends RigidBody3D

# İlk pozisyon ve rotasyon (sahne başladığında kaydedilecek)
var initial_position: Vector3
var initial_rotation: Vector3
# Animasyon süresi (saniye)
const RESET_DURATION := 0.5
# R tuşuna basılı tutuluyor mu?
var is_r_pressed := false
# Enemy collision algılama için
var hit_enemies: Array = []  # Çarptığımız enemy'leri kaydet (tekrar çarpmayı önlemek için)


func _ready() -> void:
	# İlk pozisyon ve rotasyonu kaydet
	initial_position = global_position
	initial_rotation = rotation
	
	# Fizik simülasyonunun aktif olduğundan emin ol
	freeze = false
	# Collision layer ve mask ayarlarını kontrol et
	collision_layer = 1
	collision_mask = 1
	
	# Area3D signal'larını bağla
	var area = get_node_or_null("CollisionArea")
	if area:
		area.body_entered.connect(_on_enemy_entered)
	
	# RigidBody3D ayarlarını optimize et (daha doğal hareket için)
	# Not: Bu ayarlar scene dosyasında da tanımlı, burada sadece kontrol ediyoruz
	if mass == 0.0:
		mass = 1.0  # Kütle
	if gravity_scale == 0.0:
		gravity_scale = 1.0  # Gravity ölçeği


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
	# Area3D'yi freeze durumuna göre kontrol et
	var area = get_node_or_null("CollisionArea")
	if area:
		# Freeze durumundaysa Area3D'yi devre dışı bırak (taşınırken enemy'yi öldürmesin)
		area.monitoring = not freeze
		area.monitorable = not freeze
	
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
	

func _on_enemy_entered(body: Node3D) -> void:
	"""Enemy area'ya girdiğinde çağrılır."""
	# Cube taşınıyorsa (freeze durumunda) enemy'yi öldürme
	# Sadece fırlatıldığında (hızlı hareket ederken) öldür
	if freeze:
		return  # Cube taşınıyor, enemy'yi öldürme
	
	# Cube'un hızını kontrol et - yeterince hızlı değilse öldürme
	# Bu sayede sadece fırlatıldığında enemy'yi öldürür
	var speed_threshold: float = 5.0  # Minimum hız eşiği (fırlatılmış olması için - daha yüksek)
	var current_speed = linear_velocity.length()
	
	if current_speed < speed_threshold:
		return  # Cube yeterince hızlı değil, taşınıyor olabilir
	
	# Ek kontrol: Y ekseni hızını da kontrol et (düşüyorsa veya yukarı gidiyorsa)
	# Sadece yatay düzlemde hızlı hareket ediyorsa öldür
	var horizontal_velocity = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var horizontal_speed = horizontal_velocity.length()
	
	if horizontal_speed < speed_threshold:
		return  # Yatay düzlemde yeterince hızlı değil
	
	# Enemy'yi bul (sadece Enemy script'ine sahip CharacterBody3D)
	var enemy_char: CharacterBody3D = null
	
	# Önce body'yi kontrol et
	if body is CharacterBody3D:
		var body_char = body as CharacterBody3D
		# Enemy script'ine sahip mi kontrol et (script path'ine bakarak)
		if body_char.get_script() and body_char.get_script().resource_path.ends_with("Enemy.gd"):
			enemy_char = body_char
	else:
		# Parent'ı kontrol et
		var parent = body.get_parent()
		if parent is CharacterBody3D:
			var parent_char = parent as CharacterBody3D
			# Enemy script'ine sahip mi kontrol et
			if parent_char.get_script() and parent_char.get_script().resource_path.ends_with("Enemy.gd"):
				enemy_char = parent_char
	
	# Enemy bulundu mu?
	if not enemy_char:
		return
	
	# Aynı enemy'ye tekrar çarpmayı önle
	if enemy_char in hit_enemies:
		return
	
	# Enemy aktif mi kontrol et (spawn animasyonu bitmiş mi?)
	if enemy_char.has_method("get") and enemy_char.get("is_active") == false:
		return  # Enemy henüz spawn olmadı, damage verme
	
	# Enemy ölü mü kontrol et
	if enemy_char.has_method("get") and enemy_char.get("is_dead") == true:
		return  # Enemy zaten ölü
	
	# Fırlatma yönü (küpten enemy'ye)
	var push_direction = (enemy_char.global_position - global_position).normalized()
	
	# Enemy'yi öldür (yeterince büyük hasar ver)
	var damage_amount = 999
	enemy_char.take_damage(damage_amount, push_direction)
	hit_enemies.append(enemy_char)
	print("Cubetest hit enemy! Enemy died!")
	
	# Küpün hızını biraz azalt (çarpışma efekti)
	if linear_velocity.length() > 0.5:
		linear_velocity *= 0.7
