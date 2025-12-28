extends Node3D

func _ready():
	# Eğer her parça kendi AnimationPlayer'ına sahipse:
	for child in get_children():
		if child.has_node("AnimationPlayer"):
			child.get_node("AnimationPlayer").play("YikilmaAnimasyonu")

# REWIND (Geri Sarma) için:
func rewind_bridge():
	for child in get_children():
		if child.has_node("AnimationPlayer"):
			child.get_node("AnimationPlayer").play_backwards("YikilmaAnimasyonu")
