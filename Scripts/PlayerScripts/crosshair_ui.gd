extends Control

@onready var crosshair_line_h: Line2D = $CrosshairH
@onready var crosshair_line_v: Line2D = $CrosshairV

var default_color: Color = Color.WHITE


func _ready() -> void:
	set_crosshair_color(default_color)
	# Crosshair'i ekranın ortasına yerleştir
	_update_crosshair_position()


func _update_crosshair_position() -> void:
	var screen_size = get_viewport().get_visible_rect().size
	var center_x = screen_size.x / 2
	var center_y = screen_size.y / 2
	
	if crosshair_line_h:
		crosshair_line_h.position = Vector2(center_x, center_y)
	if crosshair_line_v:
		crosshair_line_v.position = Vector2(center_x, center_y)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_crosshair_position()


func set_crosshair_color(color: Color) -> void:
	if crosshair_line_h:
		crosshair_line_h.default_color = color
	if crosshair_line_v:
		crosshair_line_v.default_color = color

