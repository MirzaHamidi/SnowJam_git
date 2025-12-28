extends CharacterBody3D

# Enemy State
enum State {
	NORMAL,
	DASH
}

# Export Variables
@export var move_speed: float = 3.5
@export var dash_speed: float = 12.0
@export var dash_duration: float = 0.25
@export var min_dash_interval: float = 1.5
@export var max_dash_interval: float = 3.5
@export var dash_chance: float = 0.4  # 0.0 - 1.0
@export var rotation_speed: float = 5.0  # Rotation lerp hızı
@export var player_distance_threshold: float = 20.0  # Player'dan bu mesafeden uzaktaysa rastgele hareket
@export var random_wander_speed: float = 2.0  # Rastgele hareket hızı
@export var max_health: int = 20  # Maksimum can
@export var attack_range: float = 15.0  # Attack alabileceği mesafe

# Internal Variables
var current_state: State = State.NORMAL
var player: Node3D = null
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var next_dash_check_time: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var is_active: bool = false  # Spawn animasyonu bitene kadar false
var random_wander_direction: Vector3 = Vector3.ZERO
var wander_direction_timer: float = 0.0
var wander_direction_change_interval: float = 2.0  # Rastgele yön değiştirme süresi
var current_health: int = 20  # Mevcut can
var is_dead: bool = false  # Ölü mü?
##var health_bar: Control = null  # Health bar UI referansı
var damage_timer: float = 0.0  # Player'a damage verme timer'ı
const DAMAGE_INTERVAL: float = 3.0  # 3 saniyede bir damage
const DAMAGE_AMOUNT: int = 50  # Her damage'de verilen hasar

# Pozisyon kayıt sistemi (son 5 saniye)
const REWIND_DURATION: float = 15.0  # 5 saniye geri al
const REWIND_ANIMATION_DURATION: float = 0.6  # Rewind animasyonu 3 saniye sürer
var position_history: Array[Dictionary] = []  # {time: float, position: Vector3, rotation: Vector3}
var is_rewinding: bool = false  # Rewind yapılıyor mu?
var rewind_tween: Tween = null  # Rewind tween'i
var is_selected: bool = false  # Seçili enemy mi?
var selection_timer: float = 0.0  # Seçim timer'ı (10 saniye)
const SELECTION_DURATION: float = 10.0  # Seçim süresi (10 saniye)
var mesh_instance: MeshInstance3D = null  # MeshInstance3D referansı
var original_material: Material = null  # Orijinal material


func _ready() -> void:
	# Health'i başlat
	current_health = max_health
	is_dead = false
	
	# MeshInstance3D'yi bul ve orijinal material'ı kaydet
	mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance and mesh_instance.mesh:
		var mesh = mesh_instance.mesh as CapsuleMesh
		if mesh and mesh.material:
			original_material = mesh.material
	
	# Health bar'ı oluştur
	#call_deferred("_setup_health_bar")
	
	# Player'ı bul (eğer set_player ile set edilmediyse)
	if not player:
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			# Player Node3D root'u içindeki CharacterBody3D'yi bul
			var character_body = player_node.get_node_or_null("CharacterBody3D")
			if character_body:
				player = character_body
			else:
				player = player_node
	
	if not player:
		print("WARNING: Enemy could not find player in 'player' group!")
		return
	
	# İlk dash kontrol zamanını ayarla
	next_dash_check_time = randf_range(min_dash_interval, max_dash_interval)
	
	# Spawn olduğunda hareket kapalı (activate() çağrılana kadar)
	is_active = false
	
	# İlk rastgele yön seç
	random_wander_direction = Vector3(cos(randf() * TAU), 0, sin(randf() * TAU))
	wander_direction_timer = 0.0
	
	# mixamo_com animasyonunu oynat
	_play_mixamo_animation()


func set_player(new_player: Node3D) -> void:
	"""Player referansını dışarıdan set et (spawner'dan çağrılabilir)."""
	player = new_player


func _play_mixamo_animation() -> void:
	"""mixamo_com animasyonunu loop modunda oynat."""
	# Blend dosyası instance'ını bul
	var blend_node = get_node_or_null("CollisionShape3D/MirzaDance(Bronze_Gurz)")
	if not blend_node:
		print("WARNING: Enemy - Could not find blend node!")
		return
	
	# AnimationPlayer'ı bul (blend node'un altında veya içinde olabilir)
	var animation_player = blend_node.get_node_or_null("AnimationPlayer")
	if not animation_player:
		# Belki doğrudan blend node'un kendisi AnimationPlayer'dır
		if blend_node is AnimationPlayer:
			animation_player = blend_node
		else:
			# Tüm alt node'larda ara
			animation_player = _find_animation_player_recursive(blend_node)
	
	if not animation_player:
		print("WARNING: Enemy - Could not find AnimationPlayer in blend node!")
		return
	
	# mixamo_com animasyonunu loop modunda oynat
	if animation_player.has_animation("mixamo_com"):
		# Animasyonun loop modunu ayarla
		var anim = animation_player.get_animation("mixamo_com")
		if anim:
			anim.loop_mode = Animation.LOOP_LINEAR
		
		# Animasyon bitince tekrar başlatmak için signal bağla
		if not animation_player.animation_finished.is_connected(_on_mixamo_animation_finished):
			animation_player.animation_finished.connect(_on_mixamo_animation_finished)
		
		# Animasyonu oynat
		animation_player.play("mixamo_com")
		print("Enemy - Playing mixamo_com animation in loop mode")
	else:
		print("WARNING: Enemy - Animation 'mixamo_com' not found! Available animations: ", animation_player.get_animation_list())


func _on_mixamo_animation_finished(anim_name: String) -> void:
	"""mixamo_com animasyonu bitince tekrar başlat."""
	if anim_name == "mixamo_com":
		# Blend dosyası instance'ını bul
		var blend_node = get_node_or_null("Enemy_05(DanceAnim)_blend1")
		if not blend_node:
			return
		
		# AnimationPlayer'ı bul
		var animation_player = blend_node.get_node_or_null("AnimationPlayer")
		if not animation_player:
			if blend_node is AnimationPlayer:
				animation_player = blend_node
			else:
				animation_player = _find_animation_player_recursive(blend_node)
		
		if animation_player and animation_player.has_animation("mixamo_com"):
			# Animasyonu tekrar oynat
			animation_player.play("mixamo_com")


func _find_animation_player_recursive(node: Node) -> AnimationPlayer:
	"""Recursive olarak AnimationPlayer'ı bul."""
	if node is AnimationPlayer:
		return node as AnimationPlayer
	
	for child in node.get_children():
		var result = _find_animation_player_recursive(child)
		if result:
			return result
	
	return null


func _physics_process(delta: float) -> void:
	# Ölüyse hiçbir şey yapma
	if is_dead:
		return
	
	# Rewind yapılıyorsa sadece gravity uygula ve hareket etme
	if is_rewinding:
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		#_update_health_bar_position()
		return
	
	# Player yoksa tekrar bul
	if not player:
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			var character_body = player_node.get_node_or_null("CharacterBody3D")
			if character_body:
				player = character_body
			else:
				player = player_node
		
		if not player:
			# Sadece gravity uygula
			if not is_on_floor():
				velocity += get_gravity() * delta
				move_and_slide()
			return
	
	# Gravity her zaman uygula
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Enemy aktif değilse (spawn animasyonu devam ediyorsa) sadece gravity uygula
	if not is_active:
		move_and_slide()
		#_update_health_bar_position()
		return
	
	# Enemy aktif - normal hareket
	
	# State'e göre hareket et
	match current_state:
		State.NORMAL:
			_normal_movement(delta)
			_check_dash_opportunity(delta)
		State.DASH:
			_dash_movement(delta)
	
	# Hareketi uygula
	move_and_slide()
	
	# Pozisyon kaydı (rewind için - rewind sırasında kayıt yapma)
	_record_position()
	
	# Player ile collision kontrolü ve damage verme
	_check_player_collision(delta)
	
	# Rotation'ı yumuşak bir şekilde hareket yönüne çevir
	_update_rotation(delta)
	
	# Seçim timer'ını güncelle
	_update_selection_visual(delta)
	
	# Health bar pozisyonunu güncelle
	#_update_health_bar_position()


func _normal_movement(delta: float) -> void:
	"""Normal yürüyüş hareketi - player'a yakınsa player'a doğru, uzaksa rastgele hareket."""
	if not player:
		# Player'ı tekrar bul
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return
	
	# Player'ın gerçek pozisyonunu al (CharacterBody3D'nin pozisyonu)
	var player_position: Vector3 = player.global_position
	
	# Player'a olan mesafeyi hesapla (sadece XZ düzleminde)
	var to_player = player_position - global_position
	to_player.y = 0  # Y eksenini sıfırla
	var distance_to_player = to_player.length()
	
	# Çok yakınsa dur (player'a çok yaklaşmasın)
	if distance_to_player < 1.0:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	
	var direction: Vector3
	var current_speed: float
	
	# Player'dan 20m uzaktaysa rastgele hareket et
	if distance_to_player > player_distance_threshold:
		direction = _get_random_wander_direction(delta)
		current_speed = random_wander_speed
	else:
		# Player'a yakınsa player'a doğru yürü
		direction = to_player.normalized()
		current_speed = move_speed
	
	# Hızı ayarla
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)


func _get_random_wander_direction(delta: float) -> Vector3:
	"""Rastgele yön değiştirme - belirli aralıklarla yeni rastgele yön seç."""
	wander_direction_timer -= delta
	
	# Yön değiştirme zamanı geldi mi?
	if wander_direction_timer <= 0.0:
		# Yeni rastgele yön seç (XZ düzleminde)
		var random_angle = randf() * TAU  # 0-2π arası açı
		random_wander_direction = Vector3(cos(random_angle), 0, sin(random_angle))
		wander_direction_timer = wander_direction_change_interval
	
	return random_wander_direction


func _check_dash_opportunity(delta: float) -> void:
	"""Dash fırsatını kontrol et ve rastgele dash at."""
	# Dash cooldown kontrolü
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
		return
	
	# Dash kontrol zamanı geldi mi?
	next_dash_check_time -= delta
	
	if next_dash_check_time <= 0.0:
		# Dash şansı var mı?
		if randf() < dash_chance:
			_start_dash()
		
		# Bir sonraki dash kontrol zamanını ayarla
		next_dash_check_time = randf_range(min_dash_interval, max_dash_interval)


func _start_dash() -> void:
	"""Dash'i başlat."""
	if not player:
		return
	
	current_state = State.DASH
	dash_timer = dash_duration
	
	# Player'ın gerçek pozisyonunu al (CharacterBody3D'nin pozisyonu)
	var player_position: Vector3 = player.global_position
	
	# Player'a doğru dash yönü hesapla
	var direction = (player_position - global_position)
	direction.y = 0  # Sadece yatay
	direction = direction.normalized()
	dash_direction = direction
	
	print("DASH")
	
	# Dash hızını ayarla
	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed


func _dash_movement(delta: float) -> void:
	"""Dash hareketi."""
	# Dash timer'ı güncelle
	dash_timer -= delta
	
	# Dash sırasında duvara çarptıysa erken bitir
	if is_on_wall():
		_end_dash()
		return
	
	# Dash süresi doldu mu?
	if dash_timer <= 0.0:
		_end_dash()
		return
	
	# Dash yönünde hareket et (sadece yatay)
	velocity.x = dash_direction.x * dash_speed
	velocity.z = dash_direction.z * dash_speed


func _end_dash() -> void:
	"""Dash'i bitir ve normal duruma dön."""
	current_state = State.NORMAL
	dash_timer = 0.0
	
	# Dash cooldown başlat (dash bitince hemen tekrar dash olmasın)
	dash_cooldown_timer = 0.5  # Kısa bir cooldown
	
	# Hızı sıfırla (normal hareket başlayacak)
	velocity.x = 0.0
	velocity.z = 0.0


func _update_rotation(delta: float) -> void:
	"""Enemy'nin rotation'ını hareket yönüne yumuşak bir şekilde çevir."""
	# Enemy aktif değilse rotation güncelleme
	if not is_active:
		return
	
	# Hareket yönü var mı?
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	
	if horizontal_velocity.length() > 0.1:
		# Hareket yönünü hesapla
		var target_direction = horizontal_velocity.normalized()
		
		# Y ekseni etrafında rotasyon hesapla
		var target_rotation_y = atan2(target_direction.x, target_direction.z)
		
		# Yumuşak rotasyon (lerp)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, rotation_speed * delta)


func activate() -> void:
	"""Spawn animasyonu bitince enemy'yi aktif et - player'a doğru yürümeye başlar."""
	is_active = true
	
	# Eğer player yoksa tekrar bul
	if not player:
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			var character_body = player_node.get_node_or_null("CharacterBody3D")
			if character_body:
				player = character_body
			else:
				player = player_node
		
		if not player:
			print("WARNING: Enemy activated but player not found!")
			return
	
	print("Enemy activated at position: ", global_position, " - Player at: ", player.global_position)
	set_physics_process(true)


#func _setup_health_bar() -> void:
	#"""Health bar UI'yi oluştur ve enemy'nin üstüne yerleştir."""
	## SubViewport ve Control oluştur
	#var subviewport = SubViewport.new()
	#subviewport.size = Vector2i(200, 30)
	#subviewport.transparent_bg = true
	#
	#var control = Control.new()
	#control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	#subviewport.add_child(control)
	#
	## Health bar background (kırmızı)
	#var bg = ColorRect.new()
	#bg.color = Color(0.3, 0.0, 0.0, 0.8)
	#bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	#control.add_child(bg)
	#
	## Health bar fill (yeşil)
	#var fill = ColorRect.new()
	#fill.color = Color(0.0, 1.0, 0.0, 0.9)
	#fill.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	#fill.anchor_right = 1.0
	#fill.offset_left = 2
	#fill.offset_top = 2
	#fill.offset_right = -2
	#fill.offset_bottom = -2
	#control.add_child(fill)
	#fill.name = "HealthFill"
	#
	## SubViewport'u Sprite3D'e ekle
	#var sprite = Sprite3D.new()
	#sprite.texture = subviewport.get_texture()
	#sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	#sprite.pixel_size = 0.01
	#sprite.position = Vector3(0, 2.5, 0)  # Enemy'nin üstünde
	#sprite.name = "HealthBar"
	#add_child(sprite)
	#
	#health_bar = control


##func _update_health_bar_position() -> void:
	#"""Health bar'ın pozisyonunu ve görünürlüğünü güncelle."""
	#if not health_bar or is_dead:
		#return
	#
	#var sprite = get_node_or_null("HealthBar")
	#if not sprite:
		#return
	
	# Health bar'ı her zaman kameraya doğru çevir (billboard zaten yapıyor ama emin olmak için)
	# Sprite3D billboard özelliği zaten bunu yapıyor


#func _update_health_bar() -> void:
	#"""Health bar'ın görsel durumunu güncelle."""
	#if not health_bar or is_dead:
		## Health bar'ı gizle
		#var sprite = get_node_or_null("HealthBar")
		#if sprite:
			#sprite.visible = false
		#return
	#
	#var fill = health_bar.get_node_or_null("HealthFill")
	#if not fill:
		#return
	#
	## Health bar'ı göster
	#var sprite = get_node_or_null("HealthBar")
	#if sprite:
		#sprite.visible = true
	
	# Health yüzdesini hesapla
	#var health_percent = float(current_health) / float(max_health)
	#health_percent = clamp(health_percent, 0.0, 1.0)
	#
	## Fill genişliğini güncelle (offset_right kullanarak)
	#var bar_width = 196  # 200 - 4 (margin)
	#fill.offset_right = -bar_width + (bar_width * health_percent)
	#
	## Renk değiştir (yeşil -> sarı -> kırmızı)
	#if health_percent > 0.5:
		#fill.color = Color(0.0, 1.0, 0.0, 0.9)  # Yeşil
	#elif health_percent > 0.25:
		#fill.color = Color(1.0, 1.0, 0.0, 0.9)  # Sarı
	#else:
		#fill.color = Color(1.0, 0.0, 0.0, 0.9)  # Kırmızı


func take_damage(amount: int, push_direction: Vector3 = Vector3.ZERO) -> void:
	"""Enemy'ye hasar ver ve geriye doğru push uygula."""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(0, current_health)
	
	print("Enemy took ", amount, " damage. Health: ", current_health, "/", max_health)
	
	# Push uygula (geriye doğru)
	if push_direction != Vector3.ZERO:
		# Push yönünü normalize et (sadece yatay düzlemde)
		var horizontal_push = push_direction
		horizontal_push.y = 0
		horizontal_push = horizontal_push.normalized()
		
		# Geriye doğru push kuvveti (yatay)
		var push_force = horizontal_push * 8.0  # Push kuvveti
		
		# Velocity'ye ekle (mevcut velocity'ye eklenir)
		velocity.x += push_force.x
		velocity.z += push_force.z
		
		# Hafif yukarı doğru da push (daha doğal görünüm)
		velocity.y += 2.0
	
	# Health bar'ı güncelle
	#_update_health_bar()
	
	# Health 0 olursa öl
	if current_health <= 0:
		_die()


func _die() -> void:
	"""Enemy'yi öldür - özellikleri deaktif et, Mouse spawn et, destroy et."""
	if is_dead:
		return
	
	is_dead = true
	
	# Tüm özellikleri deaktif et
	is_active = false
	set_physics_process(false)
	
	# Collision'ı kapat
	var collision = get_node_or_null("CollisionShape3D")
	if collision:
		collision.disabled = true
	
	# Mouse sahnesini yükle ve rastgele sayıda spawn et
	var mouse_scene_path = "res://Scenes/Mouse.tscn"
	var mouse_scene = load(mouse_scene_path)
	
	if not mouse_scene:
		print("WARNING: Enemy - Could not load Mouse scene from: ", mouse_scene_path)
		return
	
	var current_scene = get_tree().current_scene
	if not current_scene:
		print("WARNING: Enemy - No current scene found for Mouse spawn!")
		return
	
	# Rastgele mouse sayısı (1-5 arası)
	var mouse_count = randi_range(1, 5)
	print("Spawning ", mouse_count, " mice at enemy death position: ", global_position)
	
	# Her mouse için spawn et
	for i in range(mouse_count):
		var mouse_instance = mouse_scene.instantiate()
		if mouse_instance:
			# Mouse'u sahneye ekle
			current_scene.add_child(mouse_instance)
			
			# Mouse'u enemy'nin pozisyonuna yerleştir (biraz rastgele offset ile)
			var spawn_offset = Vector3(
				randf_range(-0.5, 0.5),  # X offset
				0.0,  # Y offset (yerde)
				randf_range(-0.5, 0.5)   # Z offset
			)
			mouse_instance.global_position = global_position + spawn_offset
			
			# Mouse'a rastgele başlangıç yönü ver (set_initial_direction metodu varsa)
			if mouse_instance.has_method("set_initial_direction"):
				# Rastgele açı (0-360 derece)
				var random_angle = randf() * TAU
				var initial_direction = Vector3(
					cos(random_angle),
					0.0,
					sin(random_angle)
				).normalized()
				mouse_instance.set_initial_direction(initial_direction)
			
			print("Mouse ", i + 1, " spawned at: ", mouse_instance.global_position)
	
	# Size'ı 0'a indir (tween ile)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(_destroy_after_animation)


func _destroy_after_animation() -> void:
	"""Animasyon bitince enemy'yi destroy et."""
	queue_free()


func get_distance_to_player() -> float:
	"""Player'a olan mesafeyi döndür (attack range kontrolü için)."""
	if not player:
		# Player'ı tekrar bul
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			var character_body = player_node.get_node_or_null("CharacterBody3D")
			if character_body:
				player = character_body
			else:
				player = player_node
		
		if not player:
			return INF
	
	var to_player = player.global_position - global_position
	to_player.y = 0  # Sadece yatay mesafe
	return to_player.length()


func _check_player_collision(delta: float) -> void:
	"""Player ile collision kontrolü ve 3 saniyede bir damage verme."""
	if not player:
		return
	
	# Damage timer'ı güncelle
	damage_timer += delta
	
	# Collision kontrolü - player ile çarpışma var mı?
	var collision_count = get_slide_collision_count()
	for i in collision_count:
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Player'a çarptı mı?
		if collider == player or collider.get_parent() == player or collider.is_in_group("player"):
			# 3 saniye geçti mi?
			if damage_timer >= DAMAGE_INTERVAL:
				# Player'a damage ver
				if player.has_method("take_damage"):
					player.take_damage(DAMAGE_AMOUNT)
					print("Enemy hit player! Player took ", DAMAGE_AMOUNT, " damage.")
					# Timer'ı sıfırla
					damage_timer = 0.0
				break


func _record_position() -> void:
	"""Enemy'nin pozisyonunu kaydet (son 5 saniye için)."""
	if not is_active or is_rewinding or is_dead:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0  # Saniye cinsinden
	
	# Pozisyon ve rotasyon kaydet
	position_history.append({
		"time": current_time,
		"position": global_position,
		"rotation": rotation
	})
	
	# 5 saniyeden eski kayıtları sil
	var cutoff_time = current_time - REWIND_DURATION
	var filtered_history: Array[Dictionary] = []
	for record in position_history:
		if record["time"] >= cutoff_time:
			filtered_history.append(record)
	position_history = filtered_history


func set_selected(selected: bool) -> void:
	"""Enemy'yi seçili/seçili değil olarak işaretle."""
	is_selected = selected
	
	if selected:
		# Seçim timer'ını başlat (10 saniye)
		selection_timer = SELECTION_DURATION
		_apply_blue_color()
	else:
		# Seçim kaldırıldıysa timer'ı sıfırla
		selection_timer = 0.0
		_restore_original_color()
	
	if selected:
		# Seçim timer'ını başlat (10 saniye)
		selection_timer = SELECTION_DURATION
		_apply_blue_color()
	else:
		# Seçim kaldırıldıysa timer'ı sıfırla
		selection_timer = 0.0
		_restore_original_color()


func rewind() -> void:
	"""Enemy'nin son 5 saniyesini geri al (geldiği yolu geri dön)."""
	if is_rewinding or position_history.size() < 2:
		print("Cannot rewind: is_rewinding=", is_rewinding, " history_size=", position_history.size())
		return
	
	is_rewinding = true
	is_active = false  # Rewind sırasında hareket etmesin
	velocity = Vector3.ZERO  # Hızı sıfırla
	
	# Pozisyon geçmişini ters sırada al (en yeni -> en eski)
	var reversed_history = position_history.duplicate()
	reversed_history.reverse()
	
	# Mevcut pozisyonu başlangıç olarak ekle
	reversed_history.insert(0, {
		"time": Time.get_ticks_msec() / 1000.0,
		"position": global_position,
		"rotation": rotation
	})
	
	# Tween ile pozisyonları geri oynat
	if rewind_tween:
		rewind_tween.kill()
	
	rewind_tween = create_tween()
	rewind_tween.set_parallel(true)
	
	# En eski pozisyonu hedef al (5 saniye önceki)
	var target_record = reversed_history[reversed_history.size() - 1]
	
	# 3 saniyede 5 saniye önceki pozisyona git (yumuşak animasyon)
	rewind_tween.tween_property(self, "global_position", target_record["position"], REWIND_ANIMATION_DURATION)
	rewind_tween.parallel().tween_property(self, "rotation", target_record["rotation"], REWIND_ANIMATION_DURATION)
	
	# Rewind bitince normal duruma dön
	rewind_tween.tween_callback(_on_rewind_finished)


func _on_rewind_finished() -> void:
	"""Rewind animasyonu bitince normal duruma dön."""
	is_rewinding = false
	is_active = true
	rewind_tween = null
	
	# Pozisyon geçmişini temizle (rewind sonrası yeni kayıtlar başlasın)
	position_history.clear()
	
	# Hızı sıfırla (rewind sonrası temiz başlangıç)
	velocity = Vector3.ZERO
	
	# Normal hareket durumuna dön
	current_state = State.NORMAL
	
	# Dash timer'ları sıfırla (hemen takibe başlasın)
	dash_cooldown_timer = 0.0
	next_dash_check_time = randf_range(min_dash_interval, max_dash_interval)
	
	print("Enemy rewind finished! Enemy can move again.")


func _update_selection_visual(delta: float) -> void:
	"""Seçim görsel efektini güncelle (10 saniye mavi renk)."""
	if selection_timer > 0.0:
		selection_timer -= delta
		
		# Timer bitince orijinal renge dön
		if selection_timer <= 0.0:
			selection_timer = 0.0
			_restore_original_color()
			is_selected = false


func _apply_blue_color() -> void:
	"""Enemy'yi mavi renge çevir."""
	if not mesh_instance:
		return
	
	var mesh = mesh_instance.mesh as CapsuleMesh
	if not mesh:
		return
	
	# Yeni mavi material oluştur
	var blue_material = StandardMaterial3D.new()
	blue_material.albedo_color = Color(0.2, 0.4, 1.0, 1.0)  # Parlak mavi
	
	# Material'ı uygula
	mesh.material = blue_material


func _restore_original_color() -> void:
	"""Enemy'yi orijinal rengine döndür."""
	if not mesh_instance:
		return
	
	var mesh = mesh_instance.mesh as CapsuleMesh
	if not mesh:
		return
	
	# Orijinal material'ı geri yükle
	if original_material:
		mesh.material = original_material
	else:
		# Orijinal material yoksa varsayılan kırmızı-pembe rengi kullan
		var default_material = StandardMaterial3D.new()
		default_material.albedo_color = Color(0.6284565, 0, 0.20009631, 1)
		mesh.material = default_material
