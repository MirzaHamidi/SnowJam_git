extends RigidBody3D

## Shield Script - Telekinesis ile tutulabilir, saldırıları bloklar

signal shield_blocked(hit_position: Vector3)

# ============================================
# EXPORT PARAMETERS
# ============================================
@export_group("Block")
@export var block_enabled: bool = true
@export var block_angle_threshold: float = 60.0  # Derece - bu açıdan gelen saldırılar bloklanır

@export_group("Physics (Held State)")
@export var held_gravity_scale: float = 0.2  # Tutulurken gravity azalt
@export var held_linear_damp: float = 5.0  # Tutulurken linear damping
@export var held_angular_damp: float = 5.0  # Tutulurken angular damping

# ============================================
# INTERNAL VARIABLES
# ============================================
var is_held: bool = false
var original_gravity_scale: float = 1.0
var original_linear_damp: float = 0.0
var original_angular_damp: float = 0.0
var held_by: Node3D = null  # Kim tutuyor (Player)

var block_area: Area3D = null  # Block detection için Area3D (opsiyonel)

# ============================================
# READY
# ============================================
func _ready() -> void:
	# Gruplara ekle
	add_to_group("grabbable")
	add_to_group("shield")
	
	# Orijinal physics değerlerini kaydet
	original_gravity_scale = gravity_scale
	original_linear_damp = linear_damp
	original_angular_damp = angular_damp
	
	# Block Area3D'yi bul (opsiyonel - eğer varsa)
	block_area = get_node_or_null("BlockArea")
	
	# Area3D signal'larını bağla (eğer varsa)
	if block_area:
		block_area.body_entered.connect(_on_block_area_entered)
		block_area.area_entered.connect(_on_block_area_area_entered)
	
	# Collision signal'larını bağla (doğrudan collision ile block)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


# ============================================
# HELD STATE
# ============================================
func set_held(held: bool, holder: Node3D = null) -> void:
	"""Shield'in tutulma durumunu ayarla."""
	is_held = held
	held_by = holder
	
	if is_held:
		# Tutulurken physics ayarlarını değiştir
		gravity_scale = held_gravity_scale
		linear_damp = held_linear_damp
		angular_damp = held_angular_damp
		# Freeze kapatma - physics aktif kalsın ama force ile kontrol edilecek
		freeze = false
	else:
		# Bırakılınca orijinal değerlere dön
		gravity_scale = original_gravity_scale
		linear_damp = original_linear_damp
		angular_damp = original_angular_damp
		held_by = null


func is_shield_held() -> bool:
	"""Shield tutuluyor mu?"""
	return is_held


# ============================================
# BLOCK LOGIC
# ============================================
func _on_body_entered(body: Node) -> void:
	"""Bir body shield'e çarptığında."""
	if not is_held or not block_enabled:
		return
	
	_check_block(body)


func _on_area_entered(area: Area3D) -> void:
	"""Bir area shield'e çarptığında."""
	if not is_held or not block_enabled:
		return
	
	# Enemy attack area kontrolü
	if area.is_in_group("enemy_attack"):
		_check_block_area(area)


func _on_block_area_entered(body: Node) -> void:
	"""Block Area3D'ye bir body girdiğinde."""
	if not is_held or not block_enabled:
		return
	
	_check_block(body)


func _on_block_area_area_entered(area: Area3D) -> void:
	"""Block Area3D'ye bir area girdiğinde."""
	if not is_held or not block_enabled:
		return
	
	if area.is_in_group("enemy_attack"):
		_check_block_area(area)


func _check_block(target: Node) -> void:
	"""Saldırıyı blokla (body için)."""
	# Enemy attack kontrolü
	if target.is_in_group("enemy_attack"):
		# Saldırıyı iptal et
		_cancel_attack(target)
		
		# Block efekti
		var hit_pos = global_position
		if target is RigidBody3D:
			hit_pos = target.global_position
		elif target is Area3D:
			hit_pos = target.global_position
		
		shield_blocked.emit(hit_pos)
		print("Shield blocked attack from: ", target.name)


func _check_block_area(area: Area3D) -> void:
	"""Saldırıyı blokla (area için)."""
	if area.is_in_group("enemy_attack"):
		# Saldırıyı iptal et
		_cancel_attack(area)
		
		# Block efekti
		var hit_pos = area.global_position
		shield_blocked.emit(hit_pos)
		print("Shield blocked attack from area: ", area.name)


func _cancel_attack(attack_source: Node) -> void:
	"""Saldırıyı iptal et - attack source'a signal gönder veya damage vermeyi engelle."""
	# Attack source'un damage verme metodunu çağırma veya signal gönder
	if attack_source.has_method("on_blocked"):
		attack_source.on_blocked()
	
	# Eğer attack bir Area3D ise ve içinde body'ler varsa, onlara da haber ver
	if attack_source is Area3D:
		var area = attack_source as Area3D
		for body in area.get_overlapping_bodies():
			if body.has_method("on_blocked"):
				body.on_blocked()


# ============================================
# PHYSICS
# ============================================
func _physics_process(delta: float) -> void:
	# Tutulurken block açısı kontrolü (opsiyonel - daha gelişmiş block)
	if is_held and block_enabled:
		# Shield'in yönüne göre gelen saldırıları kontrol et
		# Bu kısım daha gelişmiş block sistemi için kullanılabilir
		pass


# ============================================
# PUBLIC API
# ============================================
func get_hold_point_offset() -> Vector3:
	"""Shield'in tutulma noktası offset'i (HoldPoint'e göre)."""
	# Shield'in merkez noktası (genellikle 0,0,0)
	return Vector3.ZERO

