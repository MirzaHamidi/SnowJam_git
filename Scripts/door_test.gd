extends Node3D

var player_in_range: bool = false
var player: CharacterBody3D = null
var press_e_label: Label = null

func _ready() -> void:
	# Player'ı bul
	call_deferred("_find_player")
	
	# Area3D signal'larını bağla
	var area = get_node_or_null("Area3D")
	if area:
		area.body_entered.connect(_on_area_3d_body_entered)
		area.body_exited.connect(_on_area_3d_body_exited)
		print("Door_test: Area3D signal'ları bağlandı")
	else:
		print("Door_test: Area3D bulunamadı!")
	
	# Press E label'ını bul
	call_deferred("_find_press_e_label")

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player")

func _find_press_e_label() -> void:
	# Press E label'ını bul
	var game_scene = get_tree().get_first_node_in_group("game_scene")
	if game_scene:
		press_e_label = game_scene.get_node_or_null("PressELabel")

func _input(event: InputEvent) -> void:
	# E tuşuna basıldığında ve player range içindeyse
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		print("E tuşuna basıldı. player_in_range: ", player_in_range, " player: ", player)
		if player_in_range and player:
			_enter_door()
		else:
			print("Door_test: Player range içinde değil veya player bulunamadı!")

func _enter_door() -> void:
	"""Inside level sahnesine geçiş yap."""
	print("Entering inside_level...")
	get_tree().change_scene_to_file("res://Scenes/inside_level.tscn")

func _on_area_3d_body_entered(body: Node3D) -> void:
	"""Player collision area'ya girdiğinde."""
	print("Door_test: Body entered: ", body, " is_in_group('player'): ", body.is_in_group("player"))
	if body.is_in_group("player"):
		player_in_range = true
		player = body
		print("Player entered door area")
		# Press E label'ını göster
		if press_e_label:
			press_e_label.visible = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	"""Player collision area'dan çıktığında."""
	if body.is_in_group("player"):
		player_in_range = false
		print("Player exited door area")
		# Press E label'ını gizle
		if press_e_label:
			press_e_label.visible = false

