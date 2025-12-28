extends Node2D

## Main Menu - Button transition system with icon switching and fade
## 
## REFACTOR NOTES:
## 1) Simple icon switching (idle_icon / press_icon)
## 2) Fade transition for scene changes
## 3) Button press animation delay (0.5s)
## 4) Inspector-friendly button registration

# ============================================
# EXPORT PARAMETERS
# ============================================
@export_group("Timing")
@export var button_delay: float = 0.5
@export var fade_duration: float = 0.3

@export_group("Hover Effect")
@export var hover_scale: Vector2 = Vector2(1.15, 1.15)
@export var hover_duration: float = 0.15

@export_group("Button Icons - Play")
@export var play_idle_icon: Texture2D = null
@export var play_press_icon: Texture2D = null

@export_group("Button Icons - Settings")
@export var settings_idle_icon: Texture2D = null
@export var settings_press_icon: Texture2D = null

@export_group("Button Icons - Exit")
@export var exit_idle_icon: Texture2D = null
@export var exit_press_icon: Texture2D = null

@export_group("Button Icons - Credit")
@export var credit_idle_icon: Texture2D = null
@export var credit_press_icon: Texture2D = null

@export_group("Debug")
@export var debug_enabled: bool = false

# ============================================
# CONSTANTS
# ============================================
const FADE_ALPHA_MAX: float = 1.0
const FADE_ALPHA_MIN: float = 0.0

# ============================================
# NODE REFERENCES
# ============================================
var transition_layer: CanvasLayer = null
var fade_rect: ColorRect = null
var buttons_node: Node = null

# ============================================
# RUNTIME STATE
# ============================================
var button_data: Dictionary = {}  # button_node -> {icon_node, idle_icon, press_icon, action, use_fade, is_pressed}
var is_transitioning: bool = false
var hover_tweens: Dictionary = {}  # icon_node -> Tween (hover animasyonları için)

# ============================================
# GODOT CALLBACKS
# ============================================
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_setup_transition_layer()
	_setup_buttons()
	_setup_music_loop($MainMenu_Music)
	
	# Fade in (isteğe bağlı - main menu açılırken)
	_fade_in()

# ============================================
# PUBLIC API
# ============================================
func register_button(button: Control, icon_node: Node, idle_icon: Texture2D, press_icon: Texture2D, action: Callable, use_fade: bool = true) -> void:
	"""
	Buton kaydet (icon switching desteği ile).
	
	Parameters:
	- button: Button veya TextureButton node
	- icon_node: Icon node (TextureRect, Sprite2D, vb.) - opsiyonel, null olabilir
	- idle_icon: Normal durum icon'u (Texture2D)
	- press_icon: Basıldığında gösterilecek icon (Texture2D)
	- action: Buton basıldığında çalışacak Callable
	- use_fade: Fade kullanılsın mı? (default: true)
	"""
	if not button:
		push_error("MainMenu: register_button - button is null!")
		return
	
	button_data[button] = {
		"icon_node": icon_node,
		"idle_icon": idle_icon,
		"press_icon": press_icon,
		"action": action,
		"use_fade": use_fade,
		"is_pressed": false  # Hover efekti sadece idle icon gösterilirken çalışır
	}
	
	# Alpha değişimini engelle: button ve icon_node modulate'ını sabit tut
	_fix_button_alpha(button, icon_node)
	
	# İlk icon'u set et (idle)
	_set_icon_idle(button, icon_node, idle_icon)
	
	# Hover efekti kurulumu (Control veya Node2D destekler)
	if icon_node and ("scale" in icon_node):
		setup_hover_scale(button, icon_node)
	
	# Signal bağla
	if button.pressed.is_connected(_on_button_pressed):
		button.pressed.disconnect(_on_button_pressed)
	button.pressed.connect(_on_button_pressed.bind(button))
	
	if debug_enabled:
		print("MainMenu: Registered button: ", button.name)

# ============================================
# PRIVATE HELPERS - SETUP
# ============================================
func _setup_transition_layer() -> void:
	transition_layer = get_node_or_null("TransitionLayer")
	if not transition_layer:
		_create_transition_layer()
	
	fade_rect = transition_layer.get_node_or_null("FadeRect")
	if not fade_rect:
		_create_fade_rect()


func _create_transition_layer() -> void:
	transition_layer = CanvasLayer.new()
	transition_layer.name = "TransitionLayer"
	add_child(transition_layer)
	
	if debug_enabled:
		print("MainMenu: Created TransitionLayer")


func _create_fade_rect() -> void:
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.color = Color.BLACK
	fade_rect.anchor_left = 0.0
	fade_rect.anchor_top = 0.0
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = FADE_ALPHA_MIN
	transition_layer.add_child(fade_rect)
	
	if debug_enabled:
		print("MainMenu: Created FadeRect")


func _setup_buttons() -> void:
	buttons_node = get_node_or_null("Buttons")
	if not buttons_node:
		push_error("MainMenu: Buttons node not found!")
		return
	
	# Mevcut butonları kaydet (icon'ları inspector'dan atanacak)
	_register_existing_buttons()


func _register_existing_buttons() -> void:
	# Play button
	var play_button = buttons_node.get_node_or_null("Play")
	if play_button:
		var play_icon = play_button.get_node_or_null("Icon")
		register_button(
			play_button,
			play_icon,  # Icon node (opsiyonel)
			play_idle_icon,  # Inspector'dan atanacak
			play_press_icon,  # Inspector'dan atanacak
			_on_play_action,
			false  # use_fade (loading screen kendi fade'ini yapacak)
		)
	
	# Settings button
	var settings_button = buttons_node.get_node_or_null("Settings")
	if settings_button:
		var settings_icon = settings_button.get_node_or_null("Icon")
		register_button(
			settings_button,
			settings_icon,
			settings_idle_icon,
			settings_press_icon,
			_on_settings_action,
			true  # use_fade
		)
	
	# Exit button
	var exit_button = buttons_node.get_node_or_null("Exit")
	if exit_button:
		var exit_icon = exit_button.get_node_or_null("Icon")
		register_button(
			exit_button,
			exit_icon,
			exit_idle_icon,
			exit_press_icon,
			_on_exit_action,
			false  # use_fade (quit için fade gerekmez)
		)
	
	# Credit button
	var credit_button = buttons_node.get_node_or_null("Credit")
	if credit_button:
		var credit_icon = credit_button.get_node_or_null("Icon")
		register_button(
			credit_button,
			credit_icon,
			credit_idle_icon,
			credit_press_icon,
			_on_credit_action,
			true  # use_fade
		)

# ============================================
# PRIVATE HELPERS - BUTTON HANDLING
# ============================================
func _on_button_pressed(button: Control) -> void:
	if is_transitioning:
		return
	
	if not button in button_data:
		if debug_enabled:
			print("MainMenu: Button not registered: ", button.name)
		return
	
	var data = button_data[button]
	
	# Buton basıldı olarak işaretle (hover efekti artık çalışmayacak)
	data.is_pressed = true
	
	# Alpha değişimini engelle (basıldığında da sabit kalsın)
	_fix_button_alpha(button, data.icon_node)
	
	# Icon'u press_icon'a değiştir
	_set_icon_press(button, data.icon_node, data.press_icon)
	
	# Hover scale'ı resetle (press icon gösterilirken hover çalışmaz)
	if data.icon_node and "scale" in data.icon_node:
		_reset_icon_scale(data.icon_node)
	
	# Butonu geçici disable et (spam click önle)
	button.disabled = true
	
	# Disabled olduğunda da alpha sabit kalsın
	button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if data.icon_node:
		data.icon_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	# 0.5 sn bekle
	await get_tree().create_timer(button_delay).timeout
	
	# Fade out (eğer use_fade true ise)
	if data.use_fade:
		await _fade_out()
	
	# Action'ı çalıştır
	if data.action:
		data.action.call()
	else:
		if debug_enabled:
			print("MainMenu: Button action is null for: ", button.name)

# ============================================
# PRIVATE HELPERS - ICON MANAGEMENT
# ============================================
func _fix_button_alpha(button: Control, icon_node: Node) -> void:
	"""
	Button ve icon_node'un alpha'sını sabit tut ve basılma efektini kapat.
	"""
	# Button'un modulate'ını sabit tut
	button.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	# Icon node varsa onun da modulate'ını sabit tut
	if icon_node:
		icon_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	# Button basılma efektini kapat
	if button is Button:
		# Button'un flat property'sini true yap (basılma efekti olmaz)
		button.flat = true
		# Theme override ile pressed/hover state'lerini normal ile aynı yap
		var normal_style = button.get_theme_stylebox("normal")
		if normal_style:
			button.add_theme_stylebox_override("pressed", normal_style)
			button.add_theme_stylebox_override("hover", normal_style)
			button.add_theme_stylebox_override("hover_pressed", normal_style)
			button.add_theme_stylebox_override("disabled", normal_style)
	elif button is TextureButton:
		# TextureButton için pressed/hover texture'larını normal ile aynı yap
		var normal_texture = button.texture_normal
		if normal_texture:
			button.texture_pressed = normal_texture
			button.texture_hover = normal_texture
			button.texture_hover_pressed = normal_texture
			button.texture_disabled = normal_texture


func _set_icon_idle(button: Control, icon_node: Node, idle_icon: Texture2D) -> void:
	if not idle_icon:
		return
	
	# Önce icon_node'u kontrol et
	if icon_node:
		_set_node_icon(icon_node, idle_icon)
	else:
		# Icon node yoksa, button'un kendi icon property'sini kullan
		_set_button_icon(button, idle_icon)
	
	if debug_enabled:
		print("MainMenu: Set idle icon for: ", button.name)


func _set_icon_press(button: Control, icon_node: Node, press_icon: Texture2D) -> void:
	if not press_icon:
		return
	
	# Önce icon_node'u kontrol et
	if icon_node:
		_set_node_icon(icon_node, press_icon)
	else:
		# Icon node yoksa, button'un kendi icon property'sini kullan
		_set_button_icon(button, press_icon)
	
	if debug_enabled:
		print("MainMenu: Set press icon for: ", button.name)


func _set_node_icon(icon_node: Node, icon: Texture2D) -> void:
	if icon_node is TextureRect:
		icon_node.texture = icon
	elif icon_node is Sprite2D:
		icon_node.texture = icon
	elif icon_node is AnimatedSprite2D:
		# AnimatedSprite2D için texture property'sini kullan
		if "texture" in icon_node:
			icon_node.texture = icon
	else:
		# Fallback: texture property'sini dene
		if "texture" in icon_node:
			icon_node.texture = icon


func _set_button_icon(button: Control, icon: Texture2D) -> void:
	if button is Button:
		button.icon = icon
	elif button is TextureButton:
		button.texture_normal = icon
	else:
		if "icon" in button:
			button.icon = icon

# ============================================
# PRIVATE HELPERS - HOVER EFFECT
# ============================================
func setup_hover_scale(button: Control, icon: Node) -> void:
	"""
	Buton için hover scale efekti kurulumu.
	
	Parameters:
	- button: Control (Button veya TextureButton)
	- icon: Node (TextureRect, Sprite2D, AnimatedSprite2D vb. - scale property'si olan herhangi bir node)
	"""
	if not button or not icon:
		if debug_enabled:
			print("MainMenu: setup_hover_scale - button or icon is null")
		return
	
	if not is_instance_valid(button) or not is_instance_valid(icon):
		if debug_enabled:
			print("MainMenu: setup_hover_scale - button or icon is not valid")
		return
	
	# Icon'un scale property'si var mı kontrol et
	if not "scale" in icon:
		if debug_enabled:
			print("MainMenu: Icon does not have scale property: ", icon.name, " type: ", icon.get_class())
		return
	
	# Button'un mouse_entered/exited signal'ları var mı kontrol et
	if not "mouse_entered" in button or not "mouse_exited" in button:
		if debug_enabled:
			print("MainMenu: Button does not support mouse_entered/exited: ", button.name)
		return
	
	# Icon'un başlangıç scale'ını kaydet (eğer Vector2.ZERO ise Vector2.ONE yap)
	if icon.scale == Vector2.ZERO:
		icon.scale = Vector2.ONE
	
	# Eski signal bağlantılarını temizle
	if button.mouse_entered.is_connected(_on_button_mouse_entered):
		button.mouse_entered.disconnect(_on_button_mouse_entered)
	if button.mouse_exited.is_connected(_on_button_mouse_exited):
		button.mouse_exited.disconnect(_on_button_mouse_exited)
	
	# Yeni signal bağlantıları
	button.mouse_entered.connect(_on_button_mouse_entered.bind(button, icon))
	button.mouse_exited.connect(_on_button_mouse_exited.bind(button, icon))
	
	if debug_enabled:
		print("MainMenu: Hover scale setup for button: ", button.name, " icon: ", icon.name, " icon_type: ", icon.get_class())


func _on_button_mouse_entered(button: Control, icon: Node) -> void:
	"""
	Mouse butonun üzerine geldiğinde icon'u büyüt.
	Hover efekti SADECE idle icon gösterilirken çalışır.
	"""
	if not is_instance_valid(button) or not is_instance_valid(icon):
		if debug_enabled:
			print("MainMenu: _on_button_mouse_entered - invalid button or icon")
		return
	
	# Icon'un scale property'si var mı kontrol et
	if not "scale" in icon:
		if debug_enabled:
			print("MainMenu: Icon does not have scale property in mouse_entered")
		return
	
	# Buton disabled ise hover çalışmasın
	if "disabled" in button and button.disabled:
		_reset_icon_scale(icon)
		if debug_enabled:
			print("MainMenu: Button disabled, resetting scale")
		return
	
	# Buton basıldı mı kontrol et (press icon gösteriliyorsa hover çalışmaz)
	if button in button_data:
		var data = button_data[button]
		if data.is_pressed:
			if debug_enabled:
				print("MainMenu: Button is pressed (press icon showing), hover disabled")
			_reset_icon_scale(icon)
			return
		
		# Mevcut icon'un idle icon mu yoksa press icon mu olduğunu kontrol et
		var current_icon_texture: Texture2D = null
		if icon is TextureRect:
			current_icon_texture = icon.texture
		elif icon is Sprite2D:
			current_icon_texture = icon.texture
		elif "texture" in icon:
			current_icon_texture = icon.texture
		
		# Eğer mevcut icon press_icon ise hover çalışmasın
		if current_icon_texture and data.press_icon and current_icon_texture == data.press_icon:
			if debug_enabled:
				print("MainMenu: Current icon is press_icon, hover disabled")
			_reset_icon_scale(icon)
			return
		
		# Sadece idle_icon gösterilirken hover çalışır
		if current_icon_texture and data.idle_icon and current_icon_texture != data.idle_icon:
			if debug_enabled:
				print("MainMenu: Current icon is not idle_icon, hover disabled")
			_reset_icon_scale(icon)
			return
	
	# Eski tween'i durdur
	_kill_hover_tween(icon)
	
	# Yeni tween oluştur
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(icon, "scale", hover_scale, hover_duration)
	
	hover_tweens[icon] = tween
	
	if debug_enabled:
		print("MainMenu: Hover enter - button: ", button.name, " icon: ", icon.name, " target_scale: ", hover_scale)


func _on_button_mouse_exited(button: Control, icon: Node) -> void:
	"""
	Mouse butondan ayrıldığında icon'u eski boyutuna döndür.
	"""
	if not is_instance_valid(button) or not is_instance_valid(icon):
		if debug_enabled:
			print("MainMenu: _on_button_mouse_exited - invalid button or icon")
		return
	
	# Icon'un scale property'si var mı kontrol et
	if not "scale" in icon:
		if debug_enabled:
			print("MainMenu: Icon does not have scale property in mouse_exited")
		return
	
	_reset_icon_scale(icon)
	
	if debug_enabled:
		print("MainMenu: Hover exit - button: ", button.name, " icon: ", icon.name)


func _reset_icon_scale(icon: Node) -> void:
	"""
	Icon'un scale'ını Vector2.ONE'a döndür.
	"""
	if not is_instance_valid(icon):
		return
	
	# Icon'un scale property'si var mı kontrol et
	if not "scale" in icon:
		return
	
	# Eski tween'i durdur
	_kill_hover_tween(icon)
	
	# Yeni tween ile reset
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(icon, "scale", Vector2.ONE, hover_duration)
	
	hover_tweens[icon] = tween
	
	if debug_enabled:
		print("MainMenu: Reset icon scale - icon: ", icon.name)


func _kill_hover_tween(icon: Node) -> void:
	"""
	Icon için aktif hover tween'i durdur.
	"""
	if icon in hover_tweens:
		var tween = hover_tweens[icon]
		if tween and is_instance_valid(tween):
			tween.kill()
		hover_tweens.erase(icon)

# ============================================
# PRIVATE HELPERS - FADE TRANSITION
# ============================================
func _fade_out() -> void:
	if not fade_rect:
		return
	
	is_transitioning = true
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", FADE_ALPHA_MAX, fade_duration)
	await tween.finished
	
	if debug_enabled:
		print("MainMenu: Fade out completed")


func _fade_in() -> void:
	if not fade_rect:
		return
	
	fade_rect.modulate.a = FADE_ALPHA_MAX
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", FADE_ALPHA_MIN, fade_duration)
	await tween.finished
	
	is_transitioning = false
	
	if debug_enabled:
		print("MainMenu: Fade in completed")

# ============================================
# PRIVATE HELPERS - BUTTON ACTIONS
# ============================================
func _on_play_action() -> void:
	# LoadingManager autoload singleton'ını kullan
	LoadingManager.change_scene_with_loading("res://Scenes/game_scene.tscn")


func _on_settings_action() -> void:
	get_node("/root/SceneState").previous_scene_path = "res://Scenes/main_menu.tscn"
	get_tree().change_scene_to_file("res://Scenes/uı.tscn")


func _on_exit_action() -> void:
	get_tree().quit()


func _on_credit_action() -> void:
	get_tree().change_scene_to_file("res://Scenes/credit.tscn")

# ============================================
# PRIVATE HELPERS - MUSIC
# ============================================
func _setup_music_loop(player: AudioStreamPlayer2D) -> void:
	if player.stream == null:
		return
	
	player.finished.connect(_on_music_finished.bind(player))


func _on_music_finished(player: AudioStreamPlayer2D) -> void:
	player.play()
