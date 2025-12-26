extends CharacterBody3D


const SPEED = 5.0
const DASH_SPEED = 10.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003
const MAX_LOOK_UP = deg_to_rad(90)
const MAX_LOOK_DOWN = deg_to_rad(-90)
const PROJECTILE_SPEED = 20.0
const PROJECTILE_LIFETIME = 3.0

var camera_rotation_x: float = 0.0
var crosshair_ui: Control = null

@onready var camera: Camera3D = $Camera3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var magic_particles: GPUParticles3D = $Camera3D/MagicParticles
@onready var magic_particles2: GPUParticles3D = $Camera3D/MagicParticles2
@onready var asa_animation_player: AnimationPlayer = $Camera3D/asa/AnimationPlayer


func _ready() -> void:
	_setup_music_loop($Camera3D/GameScene_Music)
	# Mouse'u yakala ve kilitle
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Raycast'i ayarla
	if raycast:
		raycast.enabled = true
		raycast.target_position = Vector3(0, 0, -100)  # İleri doğru 100 birim
	
	# Crosshair UI'yi bul (oyun başladıktan sonra bulunabilir)
	call_deferred("_find_crosshair_ui")
	
	# AnimationPlayer'ın animasyon bitiş signal'ını bağla
	call_deferred("_setup_asa_animation")
	
	# AnimationPlayer'ın animasyon bitiş signal'ını bağla
	if asa_animation_player:
		asa_animation_player.animation_finished.connect(_on_asa_animation_finished)
func _update_crosshair_color() -> void:
	if not crosshair_ui:
		return
	
	var is_in_trigger = false
	
	# Space state kullanarak Area3D'leri de algıla
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
		if collider and collider.has_method("is_trigger_area"):
			is_in_trigger = collider.is_trigger_area()
	
	# Crosshair rengini güncelle
	if is_in_trigger:
		crosshair_ui.set_crosshair_color(Color.YELLOW)
	else:
		crosshair_ui.set_crosshair_color(Color.WHITE)

func _find_crosshair_ui() -> void:
	# Crosshair UI'yi bul
	var game_scene = get_tree().get_first_node_in_group("game_scene")
	if game_scene:
		crosshair_ui = game_scene.get_node_or_null("CrosshairUI")

func _setup_music_loop(player: AudioStreamPlayer2D) -> void:
	if player.stream == null:
		return
	
	# Simply connect finished signal to loop the music
	# Don't modify the stream at all to avoid corruption
	player.finished.connect(_on_music_finished.bind(player))


func _on_music_finished(player: AudioStreamPlayer2D) -> void:
	# Restart the music when it finishes
	player.play()

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
	
	# Attack input kontrolü - Sol tıklama
	if Input.is_action_just_pressed("Attack") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_cast_magic_spell()

func _physics_process(delta: float) -> void:
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
			
			# RigidBody3D'ye kuvvet uygula
			# Kuvvet = hız * kütle faktörü
			var push_force = push_velocity * 1.1  # İtme kuvveti çarpanı
			
			# Çarpışma noktasına göre kuvvet uygula
			rigid_body.apply_impulse(push_force, collision_point - rigid_body.global_position)

func _cast_magic_spell() -> void:
	"""Büyücü partikül efektiyle ateş eder - crosshair'ın olduğu yöne (ekranın ortasına)."""
	if not magic_particles or not camera:
		return
	
	# asa_attack animasyonunu oynat
	if asa_animation_player:
		if asa_animation_player.has_animation("asa_attack"):
			asa_animation_player.play("asa_attack")
	
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
	"""Büyünün bir şeye çarptığında çağrılır."""
	# Eğer çarptığı obje bir RigidBody3D ise, ona kuvvet uygula
	if collider is RigidBody3D:
		var rigid_body = collider as RigidBody3D
		if not rigid_body.freeze:
			var direction = (hit_point - camera.global_position).normalized()
			var force = direction * 50.0  # Büyü kuvveti
			rigid_body.apply_impulse(force, hit_point - rigid_body.global_position)
