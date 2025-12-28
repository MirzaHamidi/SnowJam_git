extends Node3D

func _ready() -> void:
	# UI'lerin çalışması için "game_scene" group'una ekle
	add_to_group("game_scene")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_open_settings()

func _open_settings() -> void:
	print("[Inside Level] Opening settings...")
	
	# Record previous scene and open settings
	var state = get_node("/root/SceneState")
	state.previous_scene_path = "res://Scenes/inside_level.tscn"
	print("[Inside Level] Previous scene path set to: ", state.previous_scene_path)
	
	# Mouse mode'u visible yap (UI button'ların çalışması için)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Settings autoload varsa pause yap
	if has_node("/root/Settings"):
		var settings = get_node("/root/Settings")
		settings.pause_game()
		settings.open_ui_popup()
	else:
		# Settings autoload yoksa direkt scene değiştir
		get_tree().change_scene_to_file("res://Scenes/uı.tscn")
