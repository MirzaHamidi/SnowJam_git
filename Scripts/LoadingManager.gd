extends Node

## Loading Manager - Autoload singleton for threaded scene loading
## 
## REFACTOR NOTES:
## 1) Threaded loading with ResourceLoader.load_threaded_request
## 2) Progress polling in _process
## 3) Cached node references for performance
## 4) Clean state management

# ============================================
# CONSTANTS
# ============================================
const LOADING_SCENE_PATH: String = "res://Scenes/loading.tscn"

# ============================================
# RUNTIME STATE
# ============================================
var current_path: String = ""
var loading_screen_ref: Control = null
var last_pct: int = 1
var is_loading: bool = false

# ============================================
# GODOT CALLBACKS
# ============================================
func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if not is_loading or current_path.is_empty():
		set_process(false)
		return
	
	# Poll loading status
	var progress: Array = []
	var status = ResourceLoader.load_threaded_get_status(current_path, progress)
	
	# Update progress bar
	if progress.size() > 0:
		var pct = clamp(int(round(progress[0] * 100.0)), 1, 100)
		last_pct = pct
		if loading_screen_ref:
			loading_screen_ref.set_progress(pct)
	
	# Check if loading is complete
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_on_load_complete()
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		_on_load_failed()
	elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_on_load_failed()

# ============================================
# PUBLIC API
# ============================================
func load_game_scene() -> void:
	"""
	GameScene'i threaded olarak yükle.
	"""
	change_scene_with_loading("res://Scenes/game_scene.tscn")


func change_scene_with_loading(path: String) -> void:
	"""
	Scene'i threaded loading ile yükle ve LoadingScreen göster.
	
	Parameters:
	- path: Scene path (e.g., "res://Scenes/game_scene.tscn")
	"""
	if path.is_empty():
		push_error("LoadingManager: Empty scene path!")
		return
	
	current_path = path
	last_pct = 1
	is_loading = false
	
	# Instantiate loading screen
	var loading_scene = load(LOADING_SCENE_PATH)
	if not loading_scene:
		push_error("LoadingManager: Could not load loading screen scene!")
		# Fallback to direct scene change
		get_tree().change_scene_to_file(path)
		return
	
	loading_screen_ref = loading_scene.instantiate()
	if not loading_screen_ref:
		push_error("LoadingManager: Could not instantiate loading screen!")
		get_tree().change_scene_to_file(path)
		return
	
	# Add loading screen to root
	get_tree().root.add_child(loading_screen_ref)
	
	# Wait for UI to render
	await get_tree().process_frame
	
	# Start threaded loading
	var error = ResourceLoader.load_threaded_request(path)
	if error != OK:
		push_error("LoadingManager: Failed to start threaded load! Error: ", error)
		loading_screen_ref.set_status("Load failed")
		# Fallback after delay
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file(path)
		loading_screen_ref.queue_free()
		loading_screen_ref = null
		return
	
	# Start polling
	is_loading = true
	set_process(true)
	
	if loading_screen_ref:
		loading_screen_ref.set_progress(1)
		loading_screen_ref.set_status("Loading...")

# ============================================
# PRIVATE HELPERS
# ============================================
func _on_load_complete() -> void:
	"""
	Loading tamamlandığında çağrılır.
	"""
	set_process(false)
	is_loading = false
	
	# Get loaded scene
	var packed = ResourceLoader.load_threaded_get(current_path)
	if not packed:
		push_error("LoadingManager: Loaded scene is null!")
		_on_load_failed()
		return
	
	# Update UI to 100%
	if loading_screen_ref:
		loading_screen_ref.set_progress(100)
		loading_screen_ref.set_status("Complete!")
	
	# Wait one frame so UI shows 100%
	await get_tree().process_frame
	
	# Change scene
	get_tree().change_scene_to_packed(packed)
	
	# Clean up
	if loading_screen_ref:
		loading_screen_ref.queue_free()
		loading_screen_ref = null
	
	current_path = ""
	last_pct = 1


func _on_load_failed() -> void:
	"""
	Loading başarısız olduğunda çağrılır.
	"""
	set_process(false)
	is_loading = false
	
	if loading_screen_ref:
		loading_screen_ref.set_status("Load failed")
		loading_screen_ref.set_progress(0)
	
	push_error("LoadingManager: Failed to load scene: ", current_path)
	
	# Optional: Retry once after delay
	await get_tree().create_timer(2.0).timeout
	
	# Clean up and try direct load as fallback
	if loading_screen_ref:
		loading_screen_ref.queue_free()
		loading_screen_ref = null
	
	# Fallback to direct scene change
	if not current_path.is_empty():
		get_tree().change_scene_to_file(current_path)
	
	current_path = ""
	last_pct = 1

