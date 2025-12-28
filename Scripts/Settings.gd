extends Node

## Settings - Global pause system
## ESC tuşu ile oyunu pause/unpause yapar ve UI scene'ini popup olarak açar
## 
## REFACTOR NOTES:
## 1) Pause/unpause sistemi
## 2) ESC tuşu kontrolü
## 3) UI scene'ini popup olarak açma
## 4) Oyunu bozmadan sadece pause eder

# ============================================
# CONSTANTS
# ============================================
const UI_SCENE_PATH: String = "res://Scenes/uı.tscn"

# ============================================
# RUNTIME STATE
# ============================================
var is_paused: bool = false
var ui_scene_instance: Node = null
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

# ============================================
# GODOT CALLBACKS
# ============================================
func _ready() -> void:
	# Input'u her zaman dinle (pause durumunda bile)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	# ESC tuşu ile pause/unpause
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			toggle_pause()

# ============================================
# PUBLIC API
# ============================================
func toggle_pause() -> void:
	"""
	Pause durumunu değiştir (pause <-> unpause).
	"""
	if is_paused:
		unpause_game()
	else:
		pause_game()


func pause_game() -> void:
	"""
	Oyunu pause et ve UI scene'ini popup olarak aç.
	"""
	if is_paused:
		return
	
	# Mevcut mouse mode'u kaydet
	previous_mouse_mode = Input.mouse_mode
	
	# Mouse'u visible yap (UI ile etkileşim için)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	is_paused = true
	get_tree().paused = true
	
	# UI scene'ini popup olarak aç
	_open_ui_popup()
	
	print("[Settings] Game paused - Mouse mode: VISIBLE")


func unpause_game() -> void:
	"""
	Oyunu devam ettir (unpause) ve UI popup'ını kapat.
	"""
	if not is_paused:
		return
	
	is_paused = false
	get_tree().paused = false
	
	# UI popup'ını kapat (unpause'dan sonra)
	_close_ui_popup()
	
	# Mouse mode'u geri yükle (sadece game scene'deyken captured)
	# Eğer game scene'deysek captured yap, değilse visible bırak
	if _is_in_game_scene():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		previous_mouse_mode = Input.MOUSE_MODE_CAPTURED
		print("[Settings] Game unpaused - Mouse mode: CAPTURED")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		previous_mouse_mode = Input.MOUSE_MODE_VISIBLE
		print("[Settings] Game unpaused - Mouse mode: VISIBLE (not in game scene)")


func is_game_paused() -> bool:
	"""
	Oyun pause durumunda mı?
	"""
	return is_paused

# ============================================
# PRIVATE HELPERS - UI POPUP
# ============================================
func _open_ui_popup() -> void:
	"""
	UI scene'ini popup olarak aç.
	"""
	if ui_scene_instance:
		# Zaten açık
		return
	
	# UI scene'ini yükle ve instantiate et
	var ui_scene = load(UI_SCENE_PATH)
	if not ui_scene:
		push_error("Settings: Could not load UI scene: ", UI_SCENE_PATH)
		return
	
	ui_scene_instance = ui_scene.instantiate()
	if not ui_scene_instance:
		push_error("Settings: Could not instantiate UI scene!")
		return
	
	# UI scene'inin root'u zaten CanvasLayer, direkt root'a ekle
	# Pause durumunda da çalışması için process_mode ayarla
	_set_process_mode_recursive(ui_scene_instance, Node.PROCESS_MODE_ALWAYS)
	
	# Root'a ekle (her zaman üstte görünsün)
	get_tree().root.add_child(ui_scene_instance)
	
	# Back button'a bağlan (eğer varsa)
	_connect_back_button()
	
	print("[Settings] UI popup opened")


func _close_ui_popup() -> void:
	"""
	UI popup'ını kapat.
	"""
	if not ui_scene_instance:
		return
	
	# UI scene instance'ını sil
	ui_scene_instance.queue_free()
	ui_scene_instance = null
	
	print("[Settings] UI popup closed")


func _set_process_mode_recursive(node: Node, mode: Node.ProcessMode) -> void:
	"""
	Recursive olarak tüm node'ların process_mode'unu ayarla.
	"""
	node.process_mode = mode
	
	for child in node.get_children():
		_set_process_mode_recursive(child, mode)


func _connect_back_button() -> void:
	"""
	UI scene'indeki Back button'a bağlan (ESC ile kapatma için).
	"""
	if not ui_scene_instance:
		return
	
	# Back button'u bul
	var back_button = _find_back_button(ui_scene_instance)
	if back_button:
		# Eğer zaten bağlı değilse bağla
		if not back_button.pressed.is_connected(_on_back_button_pressed):
			back_button.pressed.connect(_on_back_button_pressed)
		print("[Settings] Back button connected")
	else:
		print("[Settings] Back button not found in UI scene")


func _find_back_button(node: Node) -> Button:
	"""
	Recursive olarak Back button'u bul.
	"""
	if node is Button:
		var button = node as Button
		if "back" in button.name.to_lower() or "geri" in button.name.to_lower():
			return button
	
	for child in node.get_children():
		var result = _find_back_button(child)
		if result:
			return result
	
	return null


func _on_back_button_pressed() -> void:
	"""
	Back button'a basıldığında pause'ı kapat.
	"""
	unpause_game()


func _is_in_game_scene() -> bool:
	"""
	Şu anda game scene'de miyiz?
	"""
	var current_scene = get_tree().current_scene
	if not current_scene:
		return false
	
	# Game scene group'unda mı kontrol et
	if current_scene.is_in_group("game_scene"):
		return true
	
	# Veya scene path'i kontrol et
	var scene_path = current_scene.scene_file_path
	if scene_path and "game_scene" in scene_path:
		return true
	
	return false

