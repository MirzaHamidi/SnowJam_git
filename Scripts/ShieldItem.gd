extends RigidBody3D

## Shield Item - 1-hit block shield (telekinesis ile tutulabilir)

signal blocked(hit_pos: Vector3)

# ============================================
# EXPORT PARAMETERS
# ============================================
@export_group("Block")
@export var blocks_left: int = 1  # Kaç saldırı bloklayabilir
@export var block_enabled: bool = true

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
var original_collision_layer: int = 1
var original_collision_mask: int = 1
var held_by: Node3D = null  # Kim tutuyor (Player)

var block_area: Area3D = null  # Block detection için Area3D
var collision_shape: CollisionShape3D = null  # CollisionShape3D referansı

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
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask
	
	# CollisionShape3D'yi bul
	collision_shape = get_node_or_null("CollisionShape3D")
	
	# Block Area3D'yi bul
	block_area = get_node_or_null("BlockArea")
	
	# Area3D signal'larını bağla (eğer varsa)
	if block_area:
		block_area.body_entered.connect(_on_block_area_entered)
		block_area.area_entered.connect(_on_block_area_area_entered)
	
	# Collision signal'larını bağla (doğrudan collision ile block)
	# Not: RigidBody3D'de sadece body_entered var, area_entered yok
	body_entered.connect(_on_body_entered)


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
		
		# Freeze = true yap (player'a kuvvet vermesin, stabil olsun)
		freeze = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		
		# Collision'ı kapat (player ve enemy ile çarpışmasın)
		# CollisionShape3D'yi disable et
		if collision_shape:
			collision_shape.disabled = true
		
		# Collision layer/mask'i sıfırla (hiçbir şeyle çarpışmasın)
		# Sadece BlockArea açık kalacak (enemy_attack için)
		collision_layer = 0
		collision_mask = 0
		
		# BlockArea açık kalsın (enemy_attack ile etkileşim için)
		if block_area:
			block_area.monitoring = true
			block_area.monitorable = false
	else:
		# Bırakılınca orijinal değerlere dön
		gravity_scale = original_gravity_scale
		linear_damp = original_linear_damp
		angular_damp = original_angular_damp
		
		# Freeze'i kaldır (normal fizik)
		freeze = false
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		
		# Collision'ı tekrar aç
		if collision_shape:
			collision_shape.disabled = false
		
		# Collision layer/mask'i geri yükle
		collision_layer = original_collision_layer
		collision_mask = original_collision_mask
		
		held_by = null


func is_shield_held() -> bool:
	"""Shield tutuluyor mu?"""
	return is_held


# ============================================
# BLOCK LOGIC
# ============================================
func _on_body_entered(body: Node) -> void:
	"""Bir body shield'e çarptığında."""
	if not is_held or not block_enabled or blocks_left <= 0:
		return
	
	# Eğer body bir Area3D ise (enemy attack area olabilir)
	if body is Area3D:
		var area = body as Area3D
		if area.is_in_group("enemy_attack"):
			_check_block_area(area)
		else:
			_check_block(body)
	else:
		_check_block(body)


func _on_block_area_entered(body: Node) -> void:
	"""Block Area3D'ye bir body girdiğinde."""
	if not is_held or not block_enabled or blocks_left <= 0:
		return
	
	_check_block(body)


func _on_block_area_area_entered(area: Area3D) -> void:
	"""Block Area3D'ye bir area girdiğinde."""
	if not is_held or not block_enabled or blocks_left <= 0:
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
		
		# Block signal emit et
		blocked.emit(hit_pos)
		
		# Blocks left azalt
		blocks_left -= 1
		print("ShieldItem: Blocked attack from: ", target.name, " (", blocks_left, " blocks left)")
		
		# Blocks left 0 ise shield'i yok et
		if blocks_left <= 0:
			_destroy_shield()


func _check_block_area(area: Area3D) -> void:
	"""Saldırıyı blokla (area için)."""
	if area.is_in_group("enemy_attack"):
		# Saldırıyı iptal et
		_cancel_attack(area)
		
		# Block efekti
		var hit_pos = area.global_position
		blocked.emit(hit_pos)
		
		# Blocks left azalt
		blocks_left -= 1
		print("ShieldItem: Blocked attack from area: ", area.name, " (", blocks_left, " blocks left)")
		
		# Blocks left 0 ise shield'i yok et
		if blocks_left <= 0:
			_destroy_shield()


func _cancel_attack(attack_source: Node) -> void:
	"""Saldırıyı iptal et - attack source'a signal gönder veya damage vermeyi engelle."""
	# Attack source'un damage verme metodunu çağırma veya signal gönder
	if attack_source.has_method("on_blocked"):
		attack_source.on_blocked()
	
	# Eğer attack bir Area3D ise, disable et veya queue_free
	if attack_source is Area3D:
		var area = attack_source as Area3D
		
		# Duck typing: active, enabled, set_active gibi metodlar varsa çağır
		if area.has_method("set_active"):
			area.set_active(false)
		elif area.has_method("set_enabled"):
			area.set_enabled(false)
		else:
			# Area3D'yi deaktif et (monitoring kapat)
			area.monitoring = false
			area.monitorable = false
		
		# İçindeki body'lere de haber ver
		for body in area.get_overlapping_bodies():
			if body.has_method("on_blocked"):
				body.on_blocked()
	
	# Attack layer kontrolü (collision layer ile de kontrol et)
	# Eğer attack_source bir collision layer'ı varsa, onu da kontrol edebiliriz
	# Bu kısım enemy attack sistemine göre özelleştirilebilir


func _destroy_shield() -> void:
	"""Shield'i yok et (1-hit sonrası)."""
	print("ShieldItem: Shield destroyed after blocking attack!")
	
	# Kısa bir efekt bırak (opsiyonel - particle, ses, vb.)
	# Bu kısım isteğe bağlı olarak genişletilebilir
	
	# Shield'i yok et
	queue_free()


# ============================================
# PUBLIC API
# ============================================
func get_blocks_left() -> int:
	"""Kalan block sayısını döndür."""
	return blocks_left


func reset_blocks() -> void:
	"""Block sayısını sıfırla (opsiyonel - power-up için)."""
	blocks_left = 1
