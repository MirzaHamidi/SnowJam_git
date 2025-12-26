extends Node3D

# Export Variables
@export var enemy_scene: PackedScene = null
@export var terrain: Node3D = null  # Terrain node'u (assignable)
@export var player: Node3D = null  # Player node'u (assignable)
@export var spawn_count: int = 10
@export var spawn_interval: float = 0.7  # Saniye
@export var spawn_area_radius: float = 30.0
@export var ray_height: float = 100.0  # Y'den yukarıdan ray atma yüksekliği
@export var max_tries: int = 10  # Ground bulamazsa kaç kez denenecek

# Internal Variables
var spawn_timer: float = 0.0
var spawned_count: int = 0
var is_spawning: bool = false


func _ready() -> void:
	# Enemy scene kontrolü
	if not enemy_scene:
		print("WARNING: EnemySpawner - enemy_scene is not assigned!")
		set_process(false)
		return
	
	# Terrain kontrolü
	if not terrain:
		print("WARNING: EnemySpawner - terrain is not assigned!")
		set_process(false)
		return
	
	# Player kontrolü (opsiyonel - enemy kendi bulabilir)
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
			print("WARNING: EnemySpawner - player is not assigned and not found in 'player' group!")
	
	# Spawn işlemini başlat
	_start_spawning()


func _process(delta: float) -> void:
	# Spawn işlemi devam ediyor mu?
	if not is_spawning:
		return
	
	# Tüm enemyleri spawn ettik mi?
	if spawned_count >= spawn_count:
		is_spawning = false
		return
	
	# Spawn timer'ı güncelle
	spawn_timer -= delta
	
	# Spawn zamanı geldi mi?
	if spawn_timer <= 0.0:
		_spawn_enemy()
		spawn_timer = spawn_interval
		spawned_count += 1


func _start_spawning() -> void:
	"""Spawn işlemini başlat."""
	is_spawning = true
	spawn_timer = 0.0  # İlk enemy hemen spawn olsun
	spawned_count = 0


func _spawn_enemy() -> void:
	"""Terrain üzerinde rastgele bir noktada enemy spawn et."""
	if not enemy_scene:
		return
	
	# Ground pozisyonunu bul
	var ground_position = _find_ground_position()
	
	if ground_position == Vector3.ZERO:
		print("WARNING: EnemySpawner - Could not find ground position after ", max_tries, " tries!")
		return
	
	# Enemy instance'ı oluştur
	var enemy_instance = enemy_scene.instantiate()
	if not enemy_instance:
		print("ERROR: EnemySpawner - Failed to instantiate enemy scene!")
		return
	
	# Enemy'yi sahneye ekle
	get_tree().current_scene.add_child(enemy_instance)
	
	# Enemy'yi ground pozisyonuna yerleştir
	enemy_instance.global_position = ground_position
	
	# Enemy'ye player referansını ver (eğer assign edilmişse)
	if player:
		# Player Node3D ise CharacterBody3D'yi bul
		var player_to_assign = player
		if player is Node3D and not player is CharacterBody3D:
			var character_body = player.get_node_or_null("CharacterBody3D")
			if character_body:
				player_to_assign = character_body
		
		# Enemy script'ine player'ı set et
		if enemy_instance.has_method("set_player"):
			enemy_instance.set_player(player_to_assign)
	else:
		# Player yoksa enemy kendi bulacak (_ready'de)
		pass
	
	# Enemy'yi başlangıçta scale 0 yap (spawn animasyonu için)
	enemy_instance.scale = Vector3.ZERO
	
	# Enemy'nin physics process'ini aktif et (gravity için)
	enemy_instance.set_physics_process(true)
	
	# Spawn animasyonunu başlat
	_play_spawn_animation(enemy_instance)


func _find_ground_position() -> Vector3:
	"""Raycast ile terrain üzerinde rastgele bir ground pozisyonu bul."""
	if not terrain:
		return global_position
	
	var space_state = get_world_3d().direct_space_state
	
	# Spawner pozisyonunu merkez al (terrain değil)
	var spawn_center = global_position
	
	# Maksimum deneme sayısı kadar dene
	for try in range(max_tries):
		# Rastgele XZ pozisyonu seç (spawn_area_radius içinde)
		# Her denemede farklı rastgele değerler için randomize seed kullan
		var random_angle = randf() * TAU  # 0-2π arası açı
		# Minimum mesafe ekle (enemy'ler çok yakın doğmasın)
		var min_distance = 2.0
		var random_distance = randf_range(min_distance, spawn_area_radius)
		var random_x = spawn_center.x + cos(random_angle) * random_distance
		var random_z = spawn_center.z + sin(random_angle) * random_distance
		
		# Ray başlangıç ve bitiş noktaları (yukarıdan aşağıya)
		# Yüksek bir noktadan başla (terrain'in üstünde)
		var ray_start = Vector3(random_x, spawn_center.y + ray_height, random_z)
		var ray_end = Vector3(random_x, spawn_center.y - ray_height, random_z)
		
		# Raycast query oluştur
		var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.collision_mask = 1  # Layer 1 (terrain collision layer)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		# Raycast at
		var result = space_state.intersect_ray(query)
		
		# Ground bulundu mu?
		if result:
			var hit_position = result.get("position")
			# Enemy'nin ayakları yere değsin (biraz yukarıda spawn et)
			return hit_position + Vector3(0, 0.5, 0)
	
	# Ground bulunamadı - spawner pozisyonunu döndür (fallback)
	print("WARNING: Could not find ground, using spawner position")
	return spawn_center


func _play_spawn_animation(enemy: Node3D) -> void:
	"""Enemy spawn animasyonunu oynat (scale 0'dan 1'e)."""
	# Tween oluştur
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)  # Bounce efekti için
	
	# Scale animasyonu (0'dan 1'e, 1 saniyede)
	tween.tween_property(enemy, "scale", Vector3.ONE, 1.0)
	
	# Animasyon bitince enemy'yi aktif et
	tween.tween_callback(_on_spawn_animation_finished.bind(enemy))


func _on_spawn_animation_finished(enemy: Node3D) -> void:
	"""Spawn animasyonu bitince enemy'yi aktif et."""
	# Enemy'nin activate() fonksiyonu var mı kontrol et
	if enemy.has_method("activate"):
		enemy.activate()
	else:
		print("WARNING: EnemySpawner - Enemy does not have activate() method!")
