extends Node3D


func _ready() -> void:
	# Ensure music loops regardless of which file is loaded
	add_to_group("game_scene")


# ESC tuşu kontrolü artık Settings autoload'unda
# Eğer settings UI açmak isterseniz, Settings.gd'ye ekleyebilirsiniz
