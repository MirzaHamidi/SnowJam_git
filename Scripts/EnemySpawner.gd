extends Node3D

## Enemy Spawner - Array tabanlı enemy spawn sistemi (Enemy, EnemyShooter, vb.)
## 
## REFACTOR NOTES:
## 1) Debug log'lar debug_enabled flag ile kontrol edilir
## 2) Spawn logic, ground finding ayrı bölümlerde
## 3) Magic number'lar const/export yapıldı
## 4) Tip eklemeleri yapıldı (typed GDScript)
## 5) Erken return pattern kullanıldı

# ============================================
# EXPORT PARAMETERS
# ============================================
@export var enemy_scenes: Array[PackedScene] = []
@export var terrain: Node3D = null
@export var player: Node3D = null
@export var spawn_count: int = 10
@export var spawn_interval: float = 0.7
@export var spawn_area_radius: float = 30.0
@export var ray_height: float = 100.0
@export var max_tries: int = 10

@export_group("Debug")
@export var debug_enabled: bool = false

# ============================================
# CONSTANTS
# ============================================
const MIN_SPAWN_DISTANCE: float = 2.0
const ENEMY_FEET_OFFSET: float = 0.5
const DEFAULT_COLLISION_LAYER: int = 1
const SPAWN_ANIMATION_TIME: float = 1.0

# ============================================
# RUNTIME STATE
# ============================================
var spawn_timer: float = 0.0
var spawned_count: int = 0
var is_spawning: bool = false

# ============================================
# GODOT CALLBACKS
# ============================================
func _ready() -> void:
	_handle_backward_compatibility()
	
	if enemy_scenes.is_empty():
		print("WARNING: EnemySpawner - enemy_scenes array is empty! No enemies will be spawned.")
		set_process(false)
		return
	
	if not terrain:
		print("WARNING: EnemySpawner - terrain is not assigned!")
		set_process(false)
		return
	
	_find_player_if_needed()
	_start_spawning()


func _process(delta: float) -> void:
	if not is_spawning:
		return
	
	if spawned_count >= spawn_count:
		is_spawning = false
		return
	
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_enemy()
		spawn_timer = spawn_interval
		spawned_count += 1

# ============================================
# PRIVATE HELPERS - SETUP
# ============================================
func _handle_backward_compatibility() -> void:
	# Backward compatibility için eski enemy_scene'i array'e ekle
	# Not: enemy_scene export'u deprecated, sadece array kullanılmalı
	# Bu fonksiyon şu an kullanılmıyor ama gelecekte gerekirse eklenebilir
	pass


func _find_player_if_needed() -> void:
	if player:
		return
	
	var player_node = get_tree().get_first_node_in_group("player")
	if not player_node:
		if debug_enabled:
			print("WARNING: EnemySpawner - player is not assigned and not found in 'player' group!")
		return
	
	var character_body = player_node.get_node_or_null("CharacterBody3D")
	if character_body:
		player = character_body
	else:
		player = player_node


func _start_spawning() -> void:
	is_spawning = true
	spawn_timer = 0.0
	spawned_count = 0

# ============================================
# PRIVATE HELPERS - SPAWN SYSTEM
# ============================================
func _spawn_enemy() -> void:
	if enemy_scenes.is_empty():
		return
	
	var selected_scene = _select_random_enemy_scene()
	if not selected_scene:
		return
	
	var ground_position = _find_ground_position()
	if ground_position == Vector3.ZERO:
		if debug_enabled:
			print("WARNING: EnemySpawner - Could not find ground position after ", max_tries, " tries!")
		return
	
	var enemy_instance = selected_scene.instantiate()
	if not enemy_instance:
		if debug_enabled:
			print("ERROR: EnemySpawner - Failed to instantiate enemy scene!")
		return
	
	get_tree().current_scene.add_child(enemy_instance)
	enemy_instance.global_position = ground_position
	
	_assign_player_to_enemy(enemy_instance)
	_initialize_enemy_spawn(enemy_instance)
	_play_spawn_animation(enemy_instance)


func _select_random_enemy_scene() -> PackedScene:
	var selected = enemy_scenes[randi() % enemy_scenes.size()]
	if not selected and debug_enabled:
		print("WARNING: EnemySpawner - Selected enemy scene is null!")
	return selected


func _assign_player_to_enemy(enemy: Node) -> void:
	if not player:
		return
	
	var player_to_assign = player
	if player is Node3D and not player is CharacterBody3D:
		var character_body = player.get_node_or_null("CharacterBody3D")
		if character_body:
			player_to_assign = character_body
	
	if enemy.has_method("set_player"):
		enemy.set_player(player_to_assign)


func _initialize_enemy_spawn(enemy: Node) -> void:
	enemy.scale = Vector3.ZERO
	enemy.set_physics_process(true)


func _find_ground_position() -> Vector3:
	if not terrain:
		return global_position
	
	var space_state = get_world_3d().direct_space_state
	var spawn_center = global_position
	
	for try in range(max_tries):
		var test_pos = _generate_random_spawn_position(spawn_center)
		var ground_pos = _raycast_to_ground(space_state, test_pos)
		
		if ground_pos != Vector3.ZERO:
			return ground_pos + Vector3(0, ENEMY_FEET_OFFSET, 0)
	
	if debug_enabled:
		print("WARNING: Could not find ground, using spawner position")
	return spawn_center


func _generate_random_spawn_position(center: Vector3) -> Vector3:
	var random_angle = randf() * TAU
	var random_distance = randf_range(MIN_SPAWN_DISTANCE, spawn_area_radius)
	var random_x = center.x + cos(random_angle) * random_distance
	var random_z = center.z + sin(random_angle) * random_distance
	var ray_start_y = center.y + ray_height
	return Vector3(random_x, ray_start_y, random_z)


func _raycast_to_ground(space_state: PhysicsDirectSpaceState3D, start_pos: Vector3) -> Vector3:
	var ray_end = Vector3(start_pos.x, start_pos.y - ray_height * 2, start_pos.z)
	var query = PhysicsRayQueryParameters3D.create(start_pos, ray_end)
	query.collision_mask = DEFAULT_COLLISION_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	if result:
		return result.get("position")
	
	return Vector3.ZERO

# ============================================
# PRIVATE HELPERS - ANIMATION
# ============================================
func _play_spawn_animation(enemy: Node3D) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(enemy, "scale", Vector3.ONE, SPAWN_ANIMATION_TIME)
	tween.tween_callback(_on_spawn_animation_finished.bind(enemy))


func _on_spawn_animation_finished(enemy: Node3D) -> void:
	if enemy.has_method("activate"):
		enemy.activate()
	elif debug_enabled:
		print("WARNING: EnemySpawner - Enemy does not have activate() method!")
