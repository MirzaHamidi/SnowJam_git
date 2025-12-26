extends Node2D


func _ready() -> void:
	# Mouse'u visible yap (main menu'de her zaman görünür olmalı)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Connect the Play button's pressed signal to change scene
	$Buttons/Play.pressed.connect(_on_play_pressed)
	# Connect the Exit button's pressed signal to quit the game
	$Buttons/Exit.pressed.connect(_on_exit_pressed)
	# Connect the Settings button's pressed signal to open settings UI
	$Buttons/Settings.pressed.connect(_on_settings_pressed)
	# Connect the Credit button's pressed signal to open credit scene
	$Buttons/Credit.pressed.connect(_on_credit_pressed)
	
	# Ensure music loops regardless of which file is loaded
	_setup_music_loop($MainMenu_Music)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/game_scene.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_settings_pressed() -> void:
	get_node("/root/SceneState").previous_scene_path = "res://Scenes/main_menu.tscn"
	get_tree().change_scene_to_file("res://Scenes/uı.tscn")


func _on_credit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/credit.tscn")


func _setup_music_loop(player: AudioStreamPlayer2D) -> void:
	if player.stream == null:
		return
	
	# Simply connect finished signal to loop the music
	# Don't modify the stream at all to avoid corruption
	player.finished.connect(_on_music_finished.bind(player))


func _on_music_finished(player: AudioStreamPlayer2D) -> void:
	# Restart the music when it finishes
	player.play()
