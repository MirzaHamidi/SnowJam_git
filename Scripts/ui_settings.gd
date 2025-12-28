extends Node

## UI Settings - Settings panel controller
## Pause durumunda da çalışması için process_mode ALWAYS

const RESOLUTIONS := [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1280, 720)
]


func _ready() -> void:
	# Pause durumunda da çalışması için
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Mouse mode'u visible yap (button'ların çalışması için)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	print("[UI Settings] _ready() called. process_mode=", process_mode, " mouse_mode=", Input.mouse_mode)
	
	# Fill resolution options
	var option_button: OptionButton = get_node("../Panel/VBox/ResolutionHBox/ResolutionOptions")
	option_button.clear()
	for res in RESOLUTIONS:
		option_button.add_item("%dx%d" % [res.x, res.y])

	# Set current resolution index if it matches
	var current_size: Vector2i = DisplayServer.window_get_size()
	var current_index := RESOLUTIONS.find(current_size)
	if current_index != -1:
		option_button.select(current_index)

	# Set initial volume slider from master bus
	var vol_slider: HSlider = get_node("../Panel/VBox/VolumeHBox/VolumeSlider")
	var master_idx := AudioServer.get_bus_index("Master")
	var db := AudioServer.get_bus_volume_db(master_idx)
	# map from dB (-80..0) to 0..1
	vol_slider.value = db_to_linear(db)

	# Setup window mode options (Windowed / Borderless)
	var window_mode_opt: OptionButton = get_node("../Panel/VBox/WindowModeHBox/WindowModeOptions")
	window_mode_opt.clear()
	window_mode_opt.add_item("Windowed")   # id 0
	window_mode_opt.add_item("Borderless") # id 1

	# Read current borderless flag to select correct item
	var is_borderless := DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	if is_borderless:
		window_mode_opt.select(1)
	else:
		window_mode_opt.select(0)

	# Connect buttons
	var apply_btn = get_node("../Panel/VBox/ButtonsHBox/ApplyButton")
	var back_btn = get_node("../Panel/VBox/ButtonsHBox/BackButton")
	var main_menu_btn = get_node("../Panel/VBox/ButtonsHBox/MainMenuButton")
	
	# Button'ları bulamazsa hata ver
	if not apply_btn:
		push_error("[UI Settings] ApplyButton not found!")
		return
	if not back_btn:
		push_error("[UI Settings] BackButton not found!")
		return
	if not main_menu_btn:
		push_error("[UI Settings] MainMenuButton not found!")
		return
	
	# Eğer zaten bağlıysa disconnect et
	if apply_btn.pressed.is_connected(_on_apply_pressed):
		apply_btn.pressed.disconnect(_on_apply_pressed)
	if back_btn.pressed.is_connected(_on_back_pressed):
		back_btn.pressed.disconnect(_on_back_pressed)
	if main_menu_btn.pressed.is_connected(_on_main_menu_pressed):
		main_menu_btn.pressed.disconnect(_on_main_menu_pressed)
	
	# Button'ları bağla
	apply_btn.pressed.connect(_on_apply_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	
	print("[UI Settings] Buttons connected: apply=", apply_btn.pressed.is_connected(_on_apply_pressed), " back=", back_btn.pressed.is_connected(_on_back_pressed), " main_menu=", main_menu_btn.pressed.is_connected(_on_main_menu_pressed))

	# If we came from main menu, hide the Main Menu button (gereksiz)
	var state = get_node("/root/SceneState")
	if state.previous_scene_path == "res://Scenes/main_menu.tscn":
		main_menu_btn.visible = false
	else:
		main_menu_btn.visible = true


func _on_apply_pressed() -> void:
	print("[UI Settings] Apply button pressed")
	
	# Apply resolution
	var option_button: OptionButton = get_node("../Panel/VBox/ResolutionHBox/ResolutionOptions")
	var index := option_button.get_selected_id()
	if index >= 0 and index < RESOLUTIONS.size():
		var target_res: Vector2i = RESOLUTIONS[index]
		DisplayServer.window_set_size(target_res)
		print("[UI Settings] Resolution applied: ", target_res)

	# Apply master volume
	var vol_slider: HSlider = get_node("../Panel/VBox/VolumeHBox/VolumeSlider")
	var master_idx := AudioServer.get_bus_index("Master")
	var db := linear_to_db(vol_slider.value)
	AudioServer.set_bus_volume_db(master_idx, db)
	print("[UI Settings] Volume applied: ", vol_slider.value)

	# Apply window mode (borderless / windowed)
	var window_mode_opt: OptionButton = get_node("../Panel/VBox/WindowModeHBox/WindowModeOptions")
	var wm_index := window_mode_opt.get_selected_id()
	if wm_index == 1:
		# Borderless windowed
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
		print("[UI Settings] Window mode: Borderless")
	else:
		# Normal windowed
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		print("[UI Settings] Window mode: Windowed")


func _on_back_pressed() -> void:
	print("[UI Settings] Back button pressed")
	
	# Eğer Settings autoload varsa ve pause durumundaysa, sadece unpause yap
	if has_node("/root/Settings"):
		var settings = get_node("/root/Settings")
		if settings.is_game_paused():
			print("[UI Settings] Game is paused, unpausing...")
			settings.unpause_game()
			return
	
	# Normal scene değişimi (main menu'den açıldıysa)
	var state = get_node("/root/SceneState")
	print("[UI Settings] Previous scene path: ", state.previous_scene_path)
	if state.previous_scene_path != "":
		get_tree().change_scene_to_file(state.previous_scene_path)
	else:
		# Fallback
		print("[UI Settings] No previous scene, going to main menu")
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func _on_main_menu_pressed() -> void:
	print("[UI Settings] Main Menu button pressed")
	
	# Eğer Settings autoload varsa ve pause durumundaysa, önce pause'ı kapat
	if has_node("/root/Settings"):
		var settings = get_node("/root/Settings")
		if settings.is_game_paused():
			print("[UI Settings] Game is paused, closing UI popup...")
			# Pause'ı kapat (UI popup'ı kapanır)
			# unpause_game() çağrılmayacak çünkü o mouse mode'u game scene için ayarlıyor
			# Sadece pause flag'ini ve UI'yi kapat
			settings.close_ui_popup()
			settings.is_paused = false
			
			# Pause'ı kapat (scene değişimi için gerekli)
			get_tree().paused = false
			
			# Mouse mode'u visible yap (main menu için)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Güvenlik: Pause'ı kesinlikle kapat
	get_tree().paused = false
	
	# Main menu'ye scene değişimi (deferred call ile pause durumundan bağımsız)
	call_deferred("_change_to_main_menu")


func _change_to_main_menu() -> void:
	"""
	Main menu'ye scene değişimi (deferred call ile).
	"""
	get_tree().paused = false  # Güvenlik kontrolü
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
