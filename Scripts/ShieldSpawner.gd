extends Node3D

## Shield Spawner - Dünyada rastgele shield spawn eder

# ============================================
# EXPORT PARAMETERS
# ============================================
@export var shield_scene: PackedScene = null
@export var spawn_count: int = 8
@export var spawn_radius: float = 40.0
@export var min_distance_from_player: float = 8.0
@export var min_distance_between_shields: float = 5.0  # Shield'ler birbirine çok yakın olmasın

# ============================================
# INTERNAL VARIABLES
# ============================================
var player: Node3D = null
var spawned_shields: Array[RigidBody3D] = []
var space_state: PhysicsDirectSpaceState3D = null

# ============================================
# READY
# ============================================
func _ready() -> void:
	# Shield scene kontrolü
	if not shield_scene:
		push_error("ShieldSpawner: shield_scene not set!")
		return
	
	# Player'ı bul
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("ShieldSpawner: Player not found! Will try again later.")
		# Bir sonraki frame'de tekrar dene
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
	
	# Space state al
	space_state = get_world_3d().direct_space_state
	
	# Spawn'ları yap
	call_deferred("_spawn_all_shields")


# ============================================
# SPAWN SYSTEM
# ============================================
func _spawn_all_shields() -> void:
	"""Tüm shield'leri spawn et."""
	if not shield_scene or not player:
		push_error("ShieldSpawner: Cannot spawn - missing shield_scene or player!")
		return
	
	var spawned = 0
	var max_attempts = spawn_count * 10  # Maksimum deneme sayısı
	var attempts = 0
	
	while spawned < spawn_count and attempts < max_attempts:
		attempts += 1
		
		# Rastgele pozisyon dene
		var spawn_pos = _find_valid_spawn_position()
		
		if spawn_pos != Vector3.ZERO:
			# Shield spawn et
			var shield_instance = shield_scene.instantiate()
			if not shield_instance:
				push_error("ShieldSpawner: Failed to instantiate shield!")
				continue
			
			# Sahneye ekle
			get_tree().current_scene.add_child(shield_instance)
			
			# Pozisyonu ayarla
			shield_instance.global_position = spawn_pos
			
			# Listeye ekle
			if shield_instance is RigidBody3D:
				spawned_shields.append(shield_instance)
			
			spawned += 1
			print("ShieldSpawner: Spawned shield ", spawned, " at ", spawn_pos)
		else:
			# Geçerli pozisyon bulunamadı, devam et
			continue
	
	if spawned < spawn_count:
		push_warning("ShieldSpawner: Only spawned ", spawned, " out of ", spawn_count, " shields!")
	else:
		print("ShieldSpawner: Successfully spawned ", spawned, " shields!")


func _find_valid_spawn_position() -> Vector3:
	"""Geçerli bir spawn pozisyonu bul (zemin üzerinde, player'dan uzak, diğer shield'lerden uzak)."""
	if not player or not space_state:
		return Vector3.ZERO
	
	var player_pos = player.global_position
	
	# Rastgele açı ve mesafe
	var angle = randf() * TAU  # 0-2π
	var distance = randf_range(min_distance_from_player, spawn_radius)
	
	# XZ düzleminde pozisyon
	var x = player_pos.x + cos(angle) * distance
	var z = player_pos.z + sin(angle) * distance
	var y = player_pos.y + 20.0  # Yüksekten başla (raycast ile aşağı düşecek)
	
	var test_pos = Vector3(x, y, z)
	
	# Diğer shield'lerden uzak mı kontrol et
	if not _is_position_far_from_shields(test_pos):
		return Vector3.ZERO
	
	# Zemin bul (raycast ile aşağı)
	var ground_pos = _find_ground_position(test_pos)
	
	if ground_pos == Vector3.ZERO:
		return Vector3.ZERO
	
	# Player'dan yeterince uzak mı kontrol et (final pozisyon)
	var final_distance = (ground_pos - player_pos).length()
	if final_distance < min_distance_from_player:
		return Vector3.ZERO
	
	return ground_pos


func _find_ground_position(start_pos: Vector3) -> Vector3:
	"""Raycast ile zemini bul."""
	if not space_state:
		return Vector3.ZERO
	
	# Aşağı doğru raycast
	var query = PhysicsRayQueryParameters3D.create(start_pos, start_pos + Vector3.DOWN * 50.0)
	query.collision_mask = 1  # Default collision layer
	
	var result = space_state.intersect_ray(query)
	
	if result.is_empty():
		return Vector3.ZERO
	
	# Hit pozisyonu
	var hit_pos = result["position"]
	
	# Küçük offset ekle (zemin üzerinde)
	hit_pos.y += 0.1
	
	return hit_pos


func _is_position_far_from_shields(pos: Vector3) -> bool:
	"""Pozisyon diğer shield'lerden yeterince uzak mı?"""
	for shield in spawned_shields:
		if not is_instance_valid(shield):
			continue
		
		var distance = (pos - shield.global_position).length()
		if distance < min_distance_between_shields:
			return false
	
	return true


# ============================================
# PUBLIC API
# ============================================
func respawn_shields() -> void:
	"""Tüm shield'leri temizle ve yeniden spawn et."""
	# Mevcut shield'leri temizle
	for shield in spawned_shields:
		if is_instance_valid(shield):
			shield.queue_free()
	
	spawned_shields.clear()
	
	# Yeniden spawn et
	call_deferred("_spawn_all_shields")

