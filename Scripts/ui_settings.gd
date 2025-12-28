extends Node

const RESOLUTIONS := [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1280, 720)
]


func _ready() -> void:
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

	apply_btn.pressed.connect(_on_apply_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)

	# If we came from main menu, hide the Main Menu button (gereksiz)
	var state = get_node("/root/SceneState")
	if state.previous_scene_path == "res://Scenes/main_menu.tscn":
		main_menu_btn.visible = false
	else:
		main_menu_btn.visible = true


func _on_apply_pressed() -> void:
	# Apply resolution
	var option_button: OptionButton = get_node("../Panel/VBox/ResolutionHBox/ResolutionOptions")
	var index := option_button.get_selected_id()
	if index >= 0 and index < RESOLUTIONS.size():
		var target_res: Vector2i = RESOLUTIONS[index]
		DisplayServer.window_set_size(target_res)

	# Apply master volume
	var vol_slider: HSlider = get_node("../Panel/VBox/VolumeHBox/VolumeSlider")
	var master_idx := AudioServer.get_bus_index("Master")
	var db := linear_to_db(vol_slider.value)
	AudioServer.set_bus_volume_db(master_idx, db)

	# Apply window mode (borderless / windowed)
	var window_mode_opt: OptionButton = get_node("../Panel/VBox/WindowModeHBox/WindowModeOptions")
	var wm_index := window_mode_opt.get_selected_id()
	if wm_index == 1:
		# Borderless windowed
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	else:
		# Normal windowed
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)


func _on_back_pressed() -> void:
	# Eğer Settings autoload varsa ve pause durumundaysa, sadece unpause yap
	if has_node("/root/Settings"):
		var settings = get_node("/root/Settings")
		if settings.is_game_paused():
			settings.unpause_game()
			return
	
	# Normal scene değişimi (main menu'den açıldıysa)
	var state = get_node("/root/SceneState")
	if state.previous_scene_path != "":
		get_tree().change_scene_to_file(state.previous_scene_path)
	else:
		# Fallback
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
