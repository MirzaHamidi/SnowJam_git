extends CharacterBody3D


const SPEED = 5.0
const DASH_SPEED = 10.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003
const MAX_LOOK_UP = deg_to_rad(90)
const MAX_LOOK_DOWN = deg_to_rad(-90)
const PROJECTILE_SPEED = 20.0
const PROJECTILE_LIFETIME = 3.0

@export var max_health: int = 100  # Maksimum can
var current_health: int = 100  # Mevcut can
var is_dead: bool = false  # Ölü mü?

var camera_rotation_x: float = 0.0
var crosshair_ui: Control = null
var health_bar_ui: Control = null  # Health bar UI referansı
var selected_enemy: Node3D = null  # Seçili enemy
var grabbed_cube: RigidBody3D = null  # Tutulan cubetest
var grab_distance: float = 3.0  # Tutma mesafesi

@onready var camera: Camera3D = $Camera3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var magic_particles: GPUParticles3D = $Camera3D/MagicParticles
@onready var magic_particles2: GPUParticles3D = $Camera3D/MagicParticles2
@onready var asa_animation_player: AnimationPlayer = $Camera3D/asa/AnimationPlayer
@onready var spell_audio: AudioStreamPlayer2D = $Camera3D/spell
@onready var walk_audio: AudioStreamPlayer2D = $Camera3D/walk


func _ready() -> void:
	# Health'i başlat
	current_health = max_health
	is_dead = false
	
	# Player'ı "player" group'una ekle
	add_to_group("player")
	
	_setup_music_loop($Camera3D/GameScene_Music)
	# Mouse'u yakala ve kilitle
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Raycast'i ayarla
	if raycast:
		raycast.enabled = true
		raycast.target_position = Vector3(0, 0, -100)  # İleri doğru 100 birim
	
	# Crosshair UI'yi bul (oyun başladıktan sonra bulunabilir)
	call_deferred("_find_crosshair_ui")
	
	# Health bar UI'yi bul
	call_deferred("_find_health_bar_ui")
	
	# AnimationPlayer'ın animasyon bitiş signal'ını bağla
	call_deferred("_setup_asa_animation")
	
	# AnimationPlayer'ın animasyon bitiş signal'ını bağla
	if asa_animation_player:
		asa_animation_player.animation_finished.connect(_on_asa_animation_finished)
	
	# Walk audio için loop ayarı (finished signal ile loop yapacağız)
	if walk_audio:
		# Walk audio bitince tekrar çal (finished signal ile)
		walk_audio.finished.connect(_on_walk_audio_finished)
func _update_crosshair_color() -> void:
	if not crosshair_ui:
		return
	
	var is_in_trigger = false
	var is_enemy_in_range = false
	
	# Space state kullanarak Area3D'leri ve Enemy'leri algıla
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + (-camera.global_transform.basis.z * 100.0)  # Kameranın baktığı yöne 100 birim
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1  # Layer 1'i kontrol et
	query.collide_with_areas = true  # Area3D'leri de algıla
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.get("collider")
		
		# Trigger area kontrolü
		if collider and collider.has_method("is_trigger_area"):
			is_in_trigger = collider.is_trigger_area()
		
		# Enemy kontrolü - attack range içinde mi?
		if collider and collider.has_method("take_damage"):
			var enemy = collider
			# Player'dan enemy'ye olan mesafeyi hesapla
			var to_enemy = enemy.global_position - global_position
			to_enemy.y = 0  # Sadece yatay mesafe
			var distance = to_enemy.length()
			if distance <= enemy.attack_range:
				is_enemy_in_range = true
	
	# Crosshair rengini güncelle (öncelik: trigger > enemy > normal)
	if is_in_trigger:
		crosshair_ui.set_crosshair_color(Color.YELLOW)
	elif is_enemy_in_range:
		crosshair_ui.set_crosshair_color(Color.YELLOW)
	else:
		crosshair_ui.set_crosshair_color(Color.WHITE)

func _find_crosshair_ui() -> void:
	# Crosshair UI'yi bul
	var game_scene = get_tree().get_first_node_in_group("game_scene")
	if game_scene:
		crosshair_ui = game_scene.get_node_or_null("CrosshairUI")

func _find_health_bar_ui() -> void:
	# Health bar UI'yi bul
	var game_scene = get_tree().get_first_node_in_group("game_scene")
	if game_scene:
		health_bar_ui = game_scene.get_node_or_null("PlayerHealthBar")
		if health_bar_ui:
			_update_health_bar()

func _setup_music_loop(player: AudioStreamPlayer2D) -> void:
	if player.stream == null:
		return
	
	# Simply connect finished signal to loop the music
	# Don't modify the stream at all to avoid corruption
	player.finished.connect(_on_music_finished.bind(player))


func _on_music_finished(player: AudioStreamPlayer2D) -> void:
	# Restart the music when it finishes
	player.play()

func _on_walk_audio_finished() -> void:
	"""Walk audio bitince, eğer hala hareket ediyorsa tekrar çal."""
	if walk_audio:
		var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var is_moving = input_dir.length() > 0.0
		if is_moving and is_on_floor():
			walk_audio.play()

func _setup_asa_animation() -> void:
	"""AnimationPlayer'ın animasyon bitiş signal'ını bağla."""
	if asa_animation_player:
		# Signal zaten bağlı değilse bağla
		if not asa_animation_player.animation_finished.is_connected(_on_asa_animation_finished):
			asa_animation_player.animation_finished.connect(_on_asa_animation_finished)

func _on_asa_animation_finished(anim_name: StringName) -> void:
	"""asa_attack animasyonu bitince RESET animasyonuna dön."""
	if anim_name == "asa_attack":
		if asa_animation_player and asa_animation_player.has_animation("RESET"):
			asa_animation_player.play("RESET")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yatay rotasyon (karakter sağa/sola döner)
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		# Dikey rotasyon (kamera yukarı/aşağı bakar)
		camera_rotation_x -= event.relative.y * MOUSE_SENSITIVITY
		camera_rotation_x = clamp(camera_rotation_x, MAX_LOOK_DOWN, MAX_LOOK_UP)
		camera.rotation.x = camera_rotation_x
	
	# ESC ile mouse'u serbest bırak/al
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Sol tık ile cubetest fırlatma veya attack
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.pressed:
			if grabbed_cube:
				# Cubetest tutuluyorsa fırlat
				_throw_cube()
			else:
				# Normal attack
				if Input.is_action_just_pressed("Attack"):
					_cast_magic_spell()
	
	# Sağ tık ile cubetest tutma/bırakma veya enemy seçme
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if event.pressed:
				# Sağ tık basıldı - cubetest tut veya enemy seç
				_try_grab_cube()
				if not grabbed_cube:
					_select_enemy()
			else:
				# Sağ tık bırakıldı - cubetest'i bırak
				_release_cube()
	
	# Sol tık ile cubetest fırlatma veya attack
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event.pressed:
			if grabbed_cube:
				# Cubetest tutuluyorsa fırlat
				_throw_cube()
			else:
				# Normal attack
				if Input.is_action_just_pressed("Attack"):
					_cast_magic_spell()
	
	# R tuşu ile seçili enemy'yi rewind et
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if selected_enemy and selected_enemy.has_method("rewind"):
			selected_enemy.rewind()

func _physics_process(delta: float) -> void:
	# Ölüyse hiçbir şey yapma
	if is_dead:
		return
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Dash kontrolü - Shift tuşuna basılıyken koş
	var current_speed = DASH_SPEED if Input.is_action_pressed("Dash") else SPEED
	
	# Walk sesi kontrolü - WASD tuşlarına basılıyken çal
	var is_moving = input_dir.length() > 0.0
	if is_moving and is_on_floor():
		if walk_audio and not walk_audio.playing:
			walk_audio.play()
	else:
		if walk_audio and walk_audio.playing:
			walk_audio.stop()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

	move_and_slide()
	
	# RigidBody3D'leri it
	_push_rigid_bodies()
	
	# Raycast ile tetikleyici kontrolü
	_update_crosshair_color()
	
	# Cubetest taşıma kontrolü
	if grabbed_cube:
		_update_cube_grab()
	
	# Enemy collision kontrolü (enemy'ler kendileri kontrol edecek)


func _push_rigid_bodies() -> void:
	"""Karakterin çarptığı RigidBody3D'leri iter."""
	# Son çarpışmaları kontrol et
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Eğer çarptığımız obje bir RigidBody3D ise
		if collider is RigidBody3D:
			var rigid_body = collider as RigidBody3D
			
			# Eğer freeze edilmişse atla (R tuşuna basılı tutuluyorsa)
			if rigid_body.freeze:
				continue
			
			# Çarpışma noktası ve normal
			var collision_point = collision.get_position()
			var collision_normal = collision.get_normal()
			
			# Karakterin hızını al (sadece yatay düzlemde)
			var push_velocity = Vector3(velocity.x, 0, velocity.z)
			var push_speed = push_velocity.length()
			
			# Eğer hız yoksa veya çok düşükse itme
			if push_speed < 0.1:
				continue
			
			# İtme yönü (karakterin hareket yönü)
			var push_direction = push_velocity.normalized()
			
			# Yatay itme kuvveti (sürekli ve akıcı - apply_force kullan)
			var horizontal_force = push_direction * push_speed * 15.0
			
			# Up velocity (ufak havalanma efekti - Y ekseninde)
			var up_force = Vector3(0, 3.0, 0)  # Hafif yukarı kuvvet
			
			# Toplam kuvvet (yatay + dikey)
			var total_force = horizontal_force + up_force
			
			# Çarpışma noktasına göre sürekli kuvvet uygula (apply_force - akıcı itme)
			rigid_body.apply_force(total_force, collision_point - rigid_body.global_position)

func _cast_magic_spell() -> void:
	"""Büyücü partikül efektiyle ateş eder - crosshair'ın olduğu yöne (ekranın ortasına)."""
	if not magic_particles or not camera:
		return
	
	# asa_attack animasyonunu oynat
	if asa_animation_player:
		if asa_animation_player.has_animation("asa_attack"):
			asa_animation_player.play("asa_attack")
	
	# Spell sesini çal
	if spell_audio:
		spell_audio.play()
	else:
		print("Spell audio not found! Check if node exists at Camera3D/spell")
	
	# Kameranın baktığı yöne doğru raycast at (crosshair'ın olduğu yön)
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var forward = -camera.global_transform.basis.z  # Kameranın baktığı yön (crosshair yönü)
	var to = from + forward * 100.0
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	# Crosshair'ın olduğu yöndeki hedef noktayı belirle
	var target_point: Vector3
	if result:
		target_point = result.get("position")
		# Çarpışma noktasında ek efekt oynatılabilir
		_handle_spell_hit(target_point, result.get("collider"))
	else:
		# Hiçbir şeye çarpmadıysa, maksimum mesafedeki noktayı hedef al
		target_point = to
	
	# Hedef noktaya doğru direction hesapla (local space'de)
	var target_direction = camera.to_local(target_point) - camera.to_local(camera.global_position)
	target_direction = target_direction.normalized()
	
	# Mor renk oluştur (parlak mor)
	var purple_color = Color(0.6, 0.2, 1.0, 0.9)  # RGB: Parlak mor
	
	# MagicParticles için partikül process material'ını güncelle
	var material = magic_particles.process_material as ParticleProcessMaterial
	if material:
		var new_material = material.duplicate() as ParticleProcessMaterial
		if new_material:
			new_material.color = purple_color
			# Crosshair'ın olduğu yöne doğru (hedef noktaya)
			new_material.direction = target_direction
			magic_particles.process_material = new_material
	
	# Partikül efektini başlat
	magic_particles.restart()
	magic_particles.emitting = true
	
	# MagicParticles2 için de aynısını yap
	if not magic_particles2:
		return
	
	# Partikül process material'ını güncelle
	material = magic_particles2.process_material as ParticleProcessMaterial
	if material:
		var new_material = material.duplicate() as ParticleProcessMaterial
		if new_material:
			new_material.color = purple_color
			# Crosshair'ın olduğu yöne doğru (hedef noktaya)
			new_material.direction = target_direction
			magic_particles2.process_material = new_material
	
	# Partikül efektini başlat
	magic_particles2.restart()
	magic_particles2.emitting = true

func _handle_spell_hit(hit_point: Vector3, collider: Object) -> void:
	"""Büyünün bir şeye çarptığında çağrılır - apply_impulse kullan (anlık güçlü vuruş)."""
	# Enemy kontrolü - attack range içinde mi ve damage ver
	if collider and collider.has_method("take_damage"):
		var enemy = collider
		# Player'dan enemy'ye olan mesafeyi hesapla
		var to_enemy = enemy.global_position - global_position
		to_enemy.y = 0  # Sadece yatay mesafe
		var distance = to_enemy.length()
		if distance <= enemy.attack_range:
			# Push yönü: Player'dan enemy'ye doğru (geriye push için)
			var push_direction = to_enemy.normalized()
			# Enemy'ye damage ver (5 hasar) ve push uygula
			enemy.take_damage(5, push_direction)
	
	# Eğer çarptığı obje bir RigidBody3D ise, ona kuvvet uygula
	if collider is RigidBody3D:
		var rigid_body = collider as RigidBody3D
		if not rigid_body.freeze:
			# Vuruş yönü (kameradan hedefe)
			var direction = (hit_point - camera.global_position)
			direction.y = 0  # Sadece yatay
			direction = direction.normalized()
			
			# Yatay kuvvet
			var horizontal_force = direction * 50.0  # Büyü kuvveti
			
			# Up velocity (ufak havalanma efekti - Y ekseninde)
			var up_force = Vector3(0, 8.0, 0)  # Attack'ta daha güçlü yukarı kuvvet
			
			# Toplam kuvvet (yatay + dikey)
			var total_force = horizontal_force + up_force
			
			# Anlık kuvvet uygula (apply_impulse - attack için)
			rigid_body.apply_impulse(total_force, hit_point - rigid_body.global_position)


func take_damage(amount: int) -> void:
	"""Player'a hasar ver."""
	if is_dead:
		return
	
	current_health -= amount
	current_health = max(0, current_health)
	
	print("Player took ", amount, " damage. Health: ", current_health, "/", max_health)
	
	# Health bar'ı güncelle
	_update_health_bar()
	
	# Health 0 olursa öl
	if current_health <= 0:
		_die()


func _update_health_bar() -> void:
	"""Health bar'ın görsel durumunu güncelle."""
	if not health_bar_ui:
		return
	
	var fill = health_bar_ui.get_node_or_null("HealthFill")
	if not fill:
		return
	
	# Health yüzdesini hesapla
	var health_percent = float(current_health) / float(max_health)
	health_percent = clamp(health_percent, 0.0, 1.0)
	
	# Fill genişliğini güncelle (offset_right kullanarak)
	var bar_width = health_bar_ui.size.x - 4  # Margin için
	if bar_width > 0:
		fill.offset_right = -bar_width + (bar_width * health_percent)
	
	# Renk değiştir (yeşil -> sarı -> kırmızı)
	if health_percent > 0.5:
		fill.color = Color(0.0, 1.0, 0.0, 0.9)  # Yeşil
	elif health_percent > 0.25:
		fill.color = Color(1.0, 1.0, 0.0, 0.9)  # Sarı
	else:
		fill.color = Color(1.0, 0.0, 0.0, 0.9)  # Kırmızı


func _die() -> void:
	"""Player'ı öldür - ana menüye dön."""
	if is_dead:
		return
	
	is_dead = true
	
	print("Player died! Returning to main menu...")
	
	# Ana menüye geç
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func _select_enemy() -> void:
	"""Sağ tık ile enemy seç (raycast ile)."""
	# Önceki seçili enemy'yi temizle
	if selected_enemy and selected_enemy.has_method("set_selected"):
		selected_enemy.set_selected(false)
	
	selected_enemy = null
	
	# Raycast ile enemy bul
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var forward = -camera.global_transform.basis.z
	var to = from + forward * 100.0
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.get("collider")
		# Enemy mi kontrol et
		if collider and collider.has_method("set_selected"):
			selected_enemy = collider
			selected_enemy.set_selected(true)
			print("Enemy selected!")

func _try_grab_cube() -> void:
	"""Raycast ile cubetest'i tut."""
	# Önce tutulan cubetest'i bırak
	if grabbed_cube:
		_release_cube()
	
	# Raycast ile cubetest bul
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var forward = -camera.global_transform.basis.z
	var to = from + forward * 10.0  # 10 birim mesafe
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.get("collider")
		# Cubetest mi kontrol et (RigidBody3D ve parent node'u "cubetest" mi?)
		if collider is RigidBody3D:
			var rigid_body = collider as RigidBody3D
			# Parent node'un adı "cubetest" mi kontrol et
			var parent = rigid_body.get_parent()
			if parent and parent.name == "cubetest":
				grabbed_cube = rigid_body
				grabbed_cube.freeze = true  # Fizik simülasyonunu durdur
				print("Cubetest grabbed!")

func _release_cube() -> void:
	"""Tutulan cubetest'i bırak."""
	if grabbed_cube:
		grabbed_cube.freeze = false  # Fizik simülasyonunu tekrar başlat
		grabbed_cube = null
		print("Cubetest released!")

func _update_cube_grab() -> void:
	"""Tutulan cubetest'i kameranın önünde tut."""
	if not grabbed_cube or not camera:
		return
	
	# Kameranın önünde tutma pozisyonu
	var forward = -camera.global_transform.basis.z
	var grab_position = camera.global_position + forward * grab_distance
	
	# Yumuşak bir şekilde pozisyonu güncelle
	grabbed_cube.global_position = grabbed_cube.global_position.lerp(grab_position, 0.3)

func _throw_cube() -> void:
	"""Tutulan cubetest'i fırlat."""
	if not grabbed_cube or not camera:
		return
	
	# Fizik simülasyonunu tekrar başlat
	grabbed_cube.freeze = false
	
	# Fırlatma yönü (kameranın baktığı yön)
	var forward = -camera.global_transform.basis.z
	var throw_force = forward * 20.0  # Fırlatma kuvveti
	
	# Kuvvet uygula
	grabbed_cube.apply_impulse(throw_force, grabbed_cube.global_position - grabbed_cube.global_position)
	
	print("Cubetest thrown!")
	grabbed_cube = null
