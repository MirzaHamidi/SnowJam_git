extends Node2D

## Ara Sahne Scripti
## 'S' tuşuna basıldığında bir sonraki resme geçer
## Son resimden sonra game_scene.tscn'e geçer

@onready var texture_rect = $slayt

# Resimlerin listesi
var images: Array[Texture2D] = [
	preload("res://Assets/cutscene/cs1.png"),
	preload("res://Assets/cutscene/cs2.png"),
	preload("res://Assets/cutscene/cs3.png"),
	preload("res://Assets/cutscene/cs4.png"),
	preload("res://Assets/cutscene/cs5.png")
]

var current_index: int = 0

func _ready() -> void:
	# TextureRect'i ekranı kaplayacak şekilde ayarla
	if texture_rect:
		texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		# İlk resmi yükle
		if images.size() > 0:
			texture_rect.texture = images[0]
	else:
		print("HATA: 'slayt' isimli TextureRect bulunamadı!")

func _input(event: InputEvent) -> void:
	# Sadece tuşa basılma anını yakala (basılı tutma değil)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S:
			_next_slide()

func _next_slide() -> void:
	current_index += 1
	
	if current_index < images.size():
		# Sıradaki resmi göster
		texture_rect.texture = images[current_index]
		print("Ara Sahne: Resim ", current_index + 1, "/", images.size())
	else:
		# Resimler bitti, oyun sahnesine geç (LoadingManager kullanarak)
		print("Ara Sahne: Bitti, oyun sahnesine geçiliyor...")
		
		# LoadingManager zaten preload yapmış olmalı, change_to_game() ile direkt geçiş yapacak
		# Eğer preload bitmediyse loading ekranı gösterecek
		LoadingManager.change_to_game()

