extends Node3D

## Item Spawner - Dünyada rastgele item'lar spawn eder (genel sistem)

# ============================================
# EXPORT PARAMETERS
# ============================================
@export var items: Array[PackedScene] = []
@export var spawn_count: int = 10
@export var spawn_radius: float = 40.0
@export var min_distance_from_player: float = 8.0
@export var ground_ray_height: float = 30.0
@export var max_ground_ray: float = 80.0
@export var avoid_overlap_radius: float = 2.0
@export var respawn: bool = false
@export var respawn_interval: float = 10.0
@export var max_alive: int = 20

# ============================================
# INTERNAL VARIABLES
# ============================================
var player: Node3D = null
var spawned_items: Array[Node] = []
var space_state: PhysicsDirectSpaceState3D = null
var respawn_timer: float = 0.0
var spawn_center: Vector3 = Vector3.ZERO  # Spawn merkezi (spawner pozisyonu veya player)

# ============================================
# READY
# ============================================
func _ready() -> void:
	# Items array kontrolü
	if items.is_empty():
		push_warning("ItemSpawner: items array is empty! No items will be spawned.")
		return
	
	# Player'ı bul
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("ItemSpawner: Player not found in 'player' group! Will try again later.")
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
	
	# Space state al
	space_state = get_world_3d().direct_space_state
	
	# Spawn merkezini ayarla (spawner pozisyonu)
	spawn_center = global_position
	
	# İlk spawn'ları yap
	call_deferred("_spawn_all_items")


# ============================================
# PROCESS
# ============================================
func _process(delta: float) -> void:
	# Respawn kontrolü
	if respawn:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			respawn_timer = respawn_interval
			_check_and_respawn()


# ============================================
# SPAWN SYSTEM
# ============================================
func _spawn_all_items() -> void:
	"""Tüm item'ları spawn et."""
	if items.is_empty():
		return
	
	if not player:
		push_warning("ItemSpawner: Cannot spawn - player not found!")
		return
	
	# Spawn merkezini güncelle (player pozisyonu veya spawner pozisyonu)
	if player:
		spawn_center = player.global_position
	else:
		spawn_center = global_position
	
	var spawned = 0
	var max_attempts = spawn_count * 15  # Maksimum deneme sayısı (performans için limitli)
	var attempts = 0
	
	while spawned < spawn_count and attempts < max_attempts:
		attempts += 1
		
		# Rastgele item seç
		var item_scene = items[randi() % items.size()]
		if not item_scene:
			continue
		
		# Rastgele pozisyon dene
		var spawn_pos = _find_valid_spawn_position()
		
		if spawn_pos != Vector3.ZERO:
			# Item spawn et
			var item_instance = item_scene.instantiate()
			if not item_instance:
				push_warning("ItemSpawner: Failed to instantiate item!")
				continue
			
			# Sahneye ekle
			get_tree().current_scene.add_child(item_instance)
			
			# Pozisyonu ayarla
			item_instance.global_position = spawn_pos
			
			# Listeye ekle
			spawned_items.append(item_instance)
			
			# Item silindiğinde listeden çıkar
			if item_instance.has_signal("tree_exiting"):
				item_instance.tree_exiting.connect(func(): _remove_item(item_instance))
			
			spawned += 1
			print("ItemSpawner: Spawned item ", spawned, " at ", spawn_pos)
		else:
			# Geçerli pozisyon bulunamadı, devam et
			continue
	
	if spawned < spawn_count:
		push_warning("ItemSpawner: Only spawned ", spawned, " out of ", spawn_count, " items!")
	else:
		print("ItemSpawner: Successfully spawned ", spawned, " items!")


func _find_valid_spawn_position() -> Vector3:
	"""Geçerli bir spawn pozisyonu bul (zemin üzerinde, player'dan uzak, diğer item'lerden uzak)."""
	if not space_state:
		return Vector3.ZERO
	
	# Rastgele açı ve mesafe
	var angle = randf() * TAU  # 0-2π
	var distance = randf_range(min_distance_from_player, spawn_radius)
	
	# XZ düzleminde pozisyon (spawn merkezine göre)
	var x = spawn_center.x + cos(angle) * distance
	var z = spawn_center.z + sin(angle) * distance
	var y = spawn_center.y + ground_ray_height  # Yüksekten başla (raycast ile aşağı düşecek)
	
	var test_pos = Vector3(x, y, z)
	
	# Diğer item'lerden uzak mı kontrol et
	if not _is_position_far_from_items(test_pos):
		return Vector3.ZERO
	
	# Zemin bul (raycast ile aşağı)
	var ground_pos = _find_ground_position(test_pos)
	
	if ground_pos == Vector3.ZERO:
		return Vector3.ZERO
	
	# Player'dan yeterince uzak mı kontrol et (final pozisyon)
	if player:
		var final_distance = (ground_pos - player.global_position).length()
		if final_distance < min_distance_from_player:
			return Vector3.ZERO
	
	return ground_pos


func _find_ground_position(start_pos: Vector3) -> Vector3:
	"""Raycast ile zemini bul."""
	if not space_state:
		return Vector3.ZERO
	
	# Aşağı doğru raycast
	var end_pos = start_pos + Vector3.DOWN * max_ground_ray
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.collision_mask = 1  # Default collision layer
	
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		return Vector3.ZERO
	
	# Hit pozisyonu
	var hit_pos = result["position"]
	
	# Küçük offset ekle (zemin üzerinde)
	hit_pos.y += 0.1
	
	return hit_pos


func _is_position_far_from_items(pos: Vector3) -> bool:
	"""Pozisyon diğer item'lerden yeterince uzak mı?"""
	for item in spawned_items:
		if not is_instance_valid(item):
			continue
		
		var distance = (pos - item.global_position).length()
		if distance < avoid_overlap_radius:
			return false
	
	return true


func _remove_item(item: Node) -> void:
	"""Item listeden çıkar (item silindiğinde)."""
	var index = spawned_items.find(item)
	if index >= 0:
		spawned_items.remove_at(index)


# ============================================
# RESPAWN SYSTEM
# ============================================
func _check_and_respawn() -> void:
	"""Maksimum item sayısını kontrol et ve gerekirse yeni item spawn et."""
	# Geçerli item'leri say
	var valid_items = 0
	for item in spawned_items:
		if is_instance_valid(item):
			valid_items += 1
	
	# Maksimum sayıdan azsa yeni spawn et
	if valid_items < max_alive:
		var to_spawn = max_alive - valid_items
		# Kısa bir spawn yap (sadece eksik olanları)
		for i in range(to_spawn):
			_spawn_single_item()


func _spawn_single_item() -> void:
	"""Tek bir item spawn et (respawn için)."""
	if items.is_empty():
		return
	
	# Rastgele item seç
	var item_scene = items[randi() % items.size()]
	if not item_scene:
		return
	
	# Rastgele pozisyon dene (max 15 deneme)
	var spawn_pos = Vector3.ZERO
	for attempt in range(15):
		spawn_pos = _find_valid_spawn_position()
		if spawn_pos != Vector3.ZERO:
			break
	
	if spawn_pos == Vector3.ZERO:
		return  # Geçerli pozisyon bulunamadı
	
	# Item spawn et
	var item_instance = item_scene.instantiate()
	if not item_instance:
		return
	
	# Sahneye ekle
	get_tree().current_scene.add_child(item_instance)
	item_instance.global_position = spawn_pos
	
	# Listeye ekle
	spawned_items.append(item_instance)
	
	print("ItemSpawner: Respawned item at ", spawn_pos)


# ============================================
# PUBLIC API
# ============================================
func respawn_all() -> void:
	"""Tüm item'leri temizle ve yeniden spawn et."""
	# Mevcut item'leri temizle
	for item in spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	
	spawned_items.clear()
	
	# Yeniden spawn et
	call_deferred("_spawn_all_items")


func set_spawn_center(center: Vector3) -> void:
	"""Spawn merkezini ayarla (player pozisyonu veya başka bir nokta)."""
	spawn_center = center

