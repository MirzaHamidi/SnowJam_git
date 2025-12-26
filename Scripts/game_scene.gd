extends Node3D


func _ready() -> void:
	# Ensure music loops regardless of which file is loaded
	add_to_group("game_scene")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_open_settings()


func _open_settings() -> void:
	# Record previous scene and open settings
	get_node("/root/SceneState").previous_scene_path = "res://Scenes/game_scene.tscn"
	get_tree().change_scene_to_file("res://Scenes/uı.tscn")
