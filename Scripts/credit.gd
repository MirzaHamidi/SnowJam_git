extends CanvasLayer


func _ready() -> void:
	# Set all labels to white color
	var vbox = $VBoxContainer
	for child in vbox.get_children():
		if child is Label:
			child.add_theme_color_override("font_color", Color.WHITE)
	
	# Connect back button
	$VBoxContainer/BackButton.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
##############
