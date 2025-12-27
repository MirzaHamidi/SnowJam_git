extends CharacterBody3D

# Export Variables
@export var move_speed: float = 2.0  # Mouse hareket hızı
@export var lifetime: float = 5.0  # Mouse'un sahnede kalma süresi (saniye)
@export var fade_duration: float = 1.0  # Fade out süresi (saniye)
@export var rotation_lerp_speed: float = 8.0  # Dönüş hızı (lerp faktörü - yüksek = hızlı dönüş)
@export var min_move_speed: float = 1.5  # Minimum hareket hızı (rastgele varyasyon için)
@export var max_move_speed: float = 2.5  # Maksimum hareket hızı (rastgele varyasyon için)
@export var min_lifetime: float = 4.0  # Minimum yaşam süresi (rastgele varyasyon için)
@export var max_lifetime: float = 6.0  # Maksimum yaşam süresi (rastgele varyasyon için)
@export var min_direction_change_interval: float = 0.8  # Minimum yön değiştirme aralığı (saniye)
@export var max_direction_change_interval: float = 1.5  # Maksimum yön değiştirme aralığı (saniye)

# Internal Variables
var current_direction: Vector3 = Vector3.ZERO  # Mevcut hareket yönü (stabil - timer ile değişir)
var direction_change_timer: float = 0.0  # Yön değiştirme timer'ı
var direction_change_interval: float = 1.0  # Yön değiştirme aralığı (saniye)
var lifetime_timer: float = 0.0  # Yaşam süresi timer'ı
var is_fading: bool = false  # Fade out yapılıyor mu?
var mesh_instance: MeshInstance3D = null  # Mesh referansı (transparency için)
var initial_direction_set: bool = false  # Başlangıç yönü set edildi mi?


func _ready() -> void:
	"""Mouse spawn olduğunda çağrılır."""
	print("Mouse spawned at position: ", global_position)
	
	# MeshInstance3D'yi bul (FareScene içinde olabilir)
	mesh_instance = get_node_or_null("MeshInstance3D")
	if not mesh_instance:
		# FareScene içinde MeshInstance3D ara
		var fare_scene = get_node_or_null("FareScene")
		if fare_scene:
			mesh_instance = _find_mesh_instance(fare_scene)
	
	if mesh_instance:
		print("Mouse MeshInstance3D found!")
		if mesh_instance.mesh:
			print("Mouse mesh loaded: ", mesh_instance.mesh.resource_path)
		else:
			print("WARNING: Mouse mesh is null!")
	else:
		print("WARNING: Mouse MeshInstance3D not found!")
	
	# Rastgele hız ve lifetime ayarla (her mouse farklı olabilir)
	move_speed = randf_range(min_move_speed, max_move_speed)
	lifetime = randf_range(min_lifetime, max_lifetime)
	
	# İlk rastgele yön seç (eğer set_initial_direction çağrılmadıysa)
	if not initial_direction_set:
		_change_direction()
	
	# İlk yön değiştirme aralığını ayarla
	direction_change_interval = randf_range(min_direction_change_interval, max_direction_change_interval)
	
	# Timer'ları başlat
	lifetime_timer = 0.0
	direction_change_timer = 0.0
	is_fading = false


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	"""Recursive olarak MeshInstance3D bul."""
	if node is MeshInstance3D:
		return node as MeshInstance3D
	
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	
	return null


func set_initial_direction(direction: Vector3) -> void:
	"""Dışarıdan başlangıç yönü set et (spawn sırasında çağrılır)."""
	# Yönü normalize et (sadece yatay düzlemde)
	var horizontal_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	
	# Eğer yön geçerli değilse rastgele yön seç
	if horizontal_direction.length() < 0.1:
		_change_direction()
	else:
		# current_direction'ı set et (timer ile değişecek)
		current_direction = horizontal_direction
		initial_direction_set = true
		
		# Başlangıç rotation'ını da ayarla (hızlı başlangıç için)
		var initial_angle = atan2(horizontal_direction.z, horizontal_direction.x)
		rotation.y = initial_angle
		
		print("Mouse initial direction set: ", current_direction, " (angle: ", rad_to_deg(initial_angle), " degrees)")


func _physics_process(delta: float) -> void:
	"""Her fizik frame'de çağrılır."""
	# Yaşam süresi kontrolü
	lifetime_timer += delta
	
	# Lifetime doldu mu?
	if lifetime_timer >= lifetime and not is_fading:
		_start_fade_out()
	
	# Fade out yapılıyorsa sadece fade işlemini yap
	if is_fading:
		return
	
	# Yön değiştirme timer'ı (stabil hareket için timer tabanlı)
	# Bu sayede her frame yön değişmez, sadece belirli aralıklarla değişir
	direction_change_timer += delta
	if direction_change_timer >= direction_change_interval:
		_change_direction()
		direction_change_timer = 0.0
		# Yeni yön değiştirme aralığı belirle
		direction_change_interval = randf_range(min_direction_change_interval, max_direction_change_interval)
	
	# Hareket uygula (sadece mevcut direction ile - titreme önlenir)
	_move_mouse(delta)
	
	# Gravity uygula
	if not is_on_floor():
		velocity.y -= 9.8 * delta  # Gravity
	
	# Hareketi uygula
	move_and_slide()
	
	# Rotation, velocity üzerinden hesapla (stabil ve yumuşak)
	_update_rotation_from_velocity(delta)
	
	# Duvara çarptıysa yön değiştir
	if get_slide_collision_count() > 0:
		_change_direction()


func _move_mouse(delta: float) -> void:
	"""Mouse'u hareket ettir (stabil - sadece current_direction kullanır)."""
	# Yatay düzlemde hareket (sadece X ve Z)
	# current_direction timer ile değiştiği için her frame aynı yön kullanılır
	# Bu sayede titreme (jitter) oluşmaz
	var horizontal_velocity = current_direction * move_speed
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func _update_rotation_from_velocity(delta: float) -> void:
	"""Velocity üzerinden rotation hesapla (stabil ve yumuşak dönüş)."""
	# Yatay düzlemdeki velocity'yi al (X ve Z bileşenleri)
	var horizontal_velocity = Vector3(velocity.x, 0.0, velocity.z)
	
	# Eğer hareket yoksa veya çok küçükse dönme (titreme önlenir)
	if horizontal_velocity.length() < 0.1:
		return
	
	# Hareket yönünü normalize et
	var move_direction = horizontal_velocity.normalized()
	
	# +X ekseni forward olduğu için, hareket yönünden Y ekseni etrafında açı hesapla
	# atan2(z, x) kullanarak: +X ekseni 0 radyan, +Z ekseni PI/2 radyan
	var target_angle = atan2(move_direction.z, move_direction.x)
	
	# Mevcut rotation'dan Y açısını al
	var current_angle = rotation.y
	
	# Açı farkını normalize et (-PI ile PI arası - en kısa yolu seç)
	var angle_diff = target_angle - current_angle
	
	# Açı farkını -PI ile PI arasına getir (en kısa dönüş yolu)
	while angle_diff > PI:
		angle_diff -= TAU
	while angle_diff < -PI:
		angle_diff += TAU
	
	# lerp_angle ile yumuşak dönüş uygula
	# rotation_lerp_speed * delta ile lerp faktörü hesapla
	# Yüksek rotation_lerp_speed = hızlı dönüş, düşük = yavaş dönüş
	var lerp_factor = rotation_lerp_speed * delta
	var new_angle = lerp_angle(current_angle, current_angle + angle_diff, lerp_factor)
	
	# Y ekseni etrafında dönüşü uygula (sadece yatay düzlem - pitch/roll yok)
	rotation.y = new_angle


func _change_direction() -> void:
	"""Rastgele yeni bir hareket yönü seç (timer ile çağrılır - titreme önlenir)."""
	# Rastgele açı seç (0-360 derece)
	var random_angle = randf() * TAU  # TAU = 2 * PI
	
	# Yön vektörü oluştur (sadece yatay düzlemde)
	# current_direction sadece burada değişir, _physics_process'te sabit kalır
	current_direction = Vector3(
		cos(random_angle),
		0.0,
		sin(random_angle)
	).normalized()


func _start_fade_out() -> void:
	"""Fade out animasyonunu başlat."""
	if is_fading:
		return
	
	is_fading = true
	
	# MeshInstance3D'yi bul ve material'ı al
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D")
	
	if mesh_instance:
		# Material'ı al veya oluştur
		var material = mesh_instance.get_surface_override_material(0)
		if not material:
			# Eğer material yoksa, mesh'ten al
			if mesh_instance.mesh:
				var mesh_material = mesh_instance.mesh.surface_get_material(0)
				if mesh_material:
					material = mesh_material.duplicate()
					mesh_instance.set_surface_override_material(0, material)
		
		# Material varsa transparency animasyonu yap
		if material:
			# StandardMaterial3D ise albedo alpha'yı düşür
			if material is StandardMaterial3D:
				var std_material = material as StandardMaterial3D
				var tween = create_tween()
				tween.tween_method(
					func(alpha: float): std_material.albedo_color.a = alpha,
					1.0,  # Başlangıç alpha
					0.0,  # Bitiş alpha
					fade_duration
				)
				tween.tween_callback(_destroy_mouse)
			else:
				# Diğer material tipleri için direkt destroy
				_destroy_mouse()
		else:
			# Material yoksa direkt destroy
			_destroy_mouse()
	else:
		# MeshInstance3D yoksa direkt destroy
		_destroy_mouse()


func _destroy_mouse() -> void:
	"""Mouse'u sahneden sil."""
	queue_free()
