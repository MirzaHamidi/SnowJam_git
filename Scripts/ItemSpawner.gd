extends Node3D

## Item Spawner - Dünyada rastgele item'lar spawn eder (genel sistem)
## 
## REFACTOR NOTES:
## 1) Debug log'lar debug_enabled flag ile kontrol edilir
## 2) Spawn logic, helper functions ayrı bölümlerde
## 3) Magic number'lar const/export yapıldı
## 4) Tip eklemeleri yapıldı (typed GDScript)
## 5) Erken return pattern kullanıldı

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

@export_group("Debug")
@export var debug_enabled: bool = false

# ============================================
# CONSTANTS
# ============================================
const MAX_SPAWN_ATTEMPTS_MULTIPLIER: int = 15
const MAX_SINGLE_SPAWN_ATTEMPTS: int = 15
const GROUND_OFFSET: float = 0.1
const DEFAULT_COLLISION_LAYER: int = 1

# ============================================
# NODE REFERENCES
# ============================================
var player: Node3D = null
var space_state: PhysicsDirectSpaceState3D = null

# ============================================
# RUNTIME STATE
# ============================================
var spawned_items: Array[Node] = []
var respawn_timer: float = 0.0
var spawn_center: Vector3 = Vector3.ZERO

# ============================================
# GODOT CALLBACKS
# ============================================
func _ready() -> void:
	if items.is_empty():
		push_warning("ItemSpawner: items array is empty! No items will be spawned.")
		return
	
	_find_player()
	_setup_space_state()
	_setup_spawn_center()
	call_deferred("_spawn_all_items")


func _process(delta: float) -> void:
	if not respawn:
		return
	
	respawn_timer -= delta
	if respawn_timer <= 0.0:
		respawn_timer = respawn_interval
		_check_and_respawn()

# ============================================
# PUBLIC API
# ============================================
func respawn_all() -> void:
	"""Tüm item'leri temizle ve yeniden spawn et."""
	for item in spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	
	spawned_items.clear()
	call_deferred("_spawn_all_items")


func set_spawn_center(center: Vector3) -> void:
	"""Spawn merkezini ayarla (player pozisyonu veya başka bir nokta)."""
	spawn_center = center

# ============================================
# PRIVATE HELPERS - SETUP
# ============================================
func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("ItemSpawner: Player not found in 'player' group! Will try again later.")
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")


func _setup_space_state() -> void:
	space_state = get_world_3d().direct_space_state


func _setup_spawn_center() -> void:
	spawn_center = global_position

# ============================================
# PRIVATE HELPERS - SPAWN SYSTEM
# ============================================
func _spawn_all_items() -> void:
	if items.is_empty():
		return
	
	if not player:
		push_warning("ItemSpawner: Cannot spawn - player not found!")
		return
	
	_update_spawn_center()
	
	var spawned = 0
	var max_attempts = spawn_count * MAX_SPAWN_ATTEMPTS_MULTIPLIER
	var attempts = 0
	
	while spawned < spawn_count and attempts < max_attempts:
		attempts += 1
		
		var item_scene = _select_random_item()
		if not item_scene:
			continue
		
		var spawn_pos = _find_valid_spawn_position()
		if spawn_pos != Vector3.ZERO:
			_spawn_item_at_position(item_scene, spawn_pos)
			spawned += 1
			if debug_enabled:
				print("ItemSpawner: Spawned item ", spawned, " at ", spawn_pos)
	
	if spawned < spawn_count:
		push_warning("ItemSpawner: Only spawned ", spawned, " out of ", spawn_count, " items!")
	elif debug_enabled:
		print("ItemSpawner: Successfully spawned ", spawned, " items!")


func _update_spawn_center() -> void:
	if player:
		spawn_center = player.global_position
	else:
		spawn_center = global_position


func _select_random_item() -> PackedScene:
	return items[randi() % items.size()]


func _spawn_item_at_position(item_scene: PackedScene, spawn_pos: Vector3) -> void:
	var item_instance = item_scene.instantiate()
	if not item_instance:
		push_warning("ItemSpawner: Failed to instantiate item!")
		return
	
	get_tree().current_scene.add_child(item_instance)
	item_instance.global_position = spawn_pos
	spawned_items.append(item_instance)
	
	if item_instance.has_signal("tree_exiting"):
		item_instance.tree_exiting.connect(func(): _remove_item(item_instance))


func _find_valid_spawn_position() -> Vector3:
	if not space_state:
		return Vector3.ZERO
	
	var test_pos = _generate_random_position()
	
	if not _is_position_far_from_items(test_pos):
		return Vector3.ZERO
	
	var ground_pos = _find_ground_position(test_pos)
	if ground_pos == Vector3.ZERO:
		return Vector3.ZERO
	
	if not _is_far_from_player(ground_pos):
		return Vector3.ZERO
	
	return ground_pos


func _generate_random_position() -> Vector3:
	var angle = randf() * TAU
	var distance = randf_range(min_distance_from_player, spawn_radius)
	var x = spawn_center.x + cos(angle) * distance
	var z = spawn_center.z + sin(angle) * distance
	var y = spawn_center.y + ground_ray_height
	return Vector3(x, y, z)


func _find_ground_position(start_pos: Vector3) -> Vector3:
	if not space_state:
		return Vector3.ZERO
	
	var end_pos = start_pos + Vector3.DOWN * max_ground_ray
	var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
	query.collision_mask = DEFAULT_COLLISION_LAYER
	
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return Vector3.ZERO
	
	var hit_pos = result["position"]
	hit_pos.y += GROUND_OFFSET
	return hit_pos


func _is_position_far_from_items(pos: Vector3) -> bool:
	for item in spawned_items:
		if not is_instance_valid(item):
			continue
		
		var distance = (pos - item.global_position).length()
		if distance < avoid_overlap_radius:
			return false
	
	return true


func _is_far_from_player(pos: Vector3) -> bool:
	if not player:
		return true
	
	var final_distance = (pos - player.global_position).length()
	return final_distance >= min_distance_from_player


func _remove_item(item: Node) -> void:
	var index = spawned_items.find(item)
	if index >= 0:
		spawned_items.remove_at(index)

# ============================================
# PRIVATE HELPERS - RESPAWN SYSTEM
# ============================================
func _check_and_respawn() -> void:
	var valid_items = _count_valid_items()
	if valid_items < max_alive:
		var to_spawn = max_alive - valid_items
		for i in range(to_spawn):
			_spawn_single_item()


func _count_valid_items() -> int:
	var valid_items = 0
	for item in spawned_items:
		if is_instance_valid(item):
			valid_items += 1
	return valid_items


func _spawn_single_item() -> void:
	if items.is_empty():
		return
	
	var item_scene = _select_random_item()
	if not item_scene:
		return
	
	var spawn_pos = Vector3.ZERO
	for attempt in range(MAX_SINGLE_SPAWN_ATTEMPTS):
		spawn_pos = _find_valid_spawn_position()
		if spawn_pos != Vector3.ZERO:
			break
	
	if spawn_pos == Vector3.ZERO:
		return
	
	var item_instance = item_scene.instantiate()
	if not item_instance:
		return
	
	get_tree().current_scene.add_child(item_instance)
	item_instance.global_position = spawn_pos
	spawned_items.append(item_instance)
	
	if debug_enabled:
		print("ItemSpawner: Respawned item at ", spawn_pos)
