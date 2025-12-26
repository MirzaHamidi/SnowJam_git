extends Control

@onready var health_fill: ColorRect = $HealthFill

func _ready() -> void:
	# Health bar'ı ekranın üst sol köşesine yerleştir
	anchors_preset = Control.PRESET_TOP_LEFT
	offset_left = 20
	offset_top = 20
	offset_right = 320
	offset_bottom = 60
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	
	# Başlangıçta tam health göster
	if health_fill:
		health_fill.offset_right = -4
