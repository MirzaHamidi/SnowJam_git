extends Area3D

## Projectile - EnemyShooter'dan fırlatılan mermi

# ============================================
# EXPORT PARAMETERS
# ============================================
@export var speed: float = 18.0
@export var damage: int = 1
@export var life_time: float = 3.0

# ============================================
# INTERNAL VARIABLES
# ============================================
var dir: Vector3 = Vector3.ZERO
var life_timer: float = 0.0

# ============================================
# READY
# ============================================
func _ready() -> void:
	# Gruplara ekle
	add_to_group("projectile")
	
	# Signal'ları bağla
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Life timer başlat
	life_timer = life_time


# ============================================
# SETUP
# ============================================
func setup(direction: Vector3, projectile_speed: float, projectile_damage: int) -> void:
	"""Projectile ayarlarını yap (EnemyShooter'dan çağrılır)."""
	dir = direction.normalized()
	speed = projectile_speed
	damage = projectile_damage


# ============================================
# PHYSICS PROCESS
# ============================================
func _physics_process(delta: float) -> void:
	# Life timer
	life_timer -= delta
	if life_timer <= 0.0:
		queue_free()
		return
	
	# Hareket
	global_position += dir * speed * delta


# ============================================
# COLLISION HANDLING
# ============================================
func _on_body_entered(body: Node) -> void:
	"""Bir body'ye çarptığında."""
	_handle_collision(body)


func _on_area_entered(area: Area3D) -> void:
	"""Bir area'ya çarptığında."""
	_handle_collision(area)


func _handle_collision(target: Node) -> void:
	"""Collision'ı işle."""
	# Player'a çarptı mı?
	if target.is_in_group("player") or (target.get_parent() and target.get_parent().is_in_group("player")):
		_hit_player(target)
		return
	
	# Shield'e çarptı mı?
	if target.is_in_group("shield") or (target.get_parent() and target.get_parent().is_in_group("shield")):
		_hit_shield(target)
		return
	
	# BlockArea'ya çarptı mı? (Shield'in BlockArea'sı)
	if target.name == "BlockArea":
		var shield = target.get_parent()
		if shield and shield.is_in_group("shield"):
			_hit_shield(shield)
			return
	
	# World/StaticBody'e çarptı mı?
	if target is StaticBody3D or target is CharacterBody3D:
		_hit_world()
		return


func _hit_player(target: Node) -> void:
	"""Player'a hasar ver."""
	var player = target
	if target.get_parent() and target.get_parent().is_in_group("player"):
		player = target.get_parent()
	
	# Player'ın CharacterBody3D'sini bul
	if player is Node3D and not player is CharacterBody3D:
		var character_body = player.get_node_or_null("CharacterBody3D")
		if character_body:
			player = character_body
	
	# Damage ver (duck typing)
	if player.has_method("take_damage"):
		player.take_damage(damage)
		print("Projectile: Hit player for ", damage, " damage!")
	else:
		print("Projectile: Hit player but no take_damage method found!")
	
	# Projectile'i yok et
	queue_free()


func _hit_shield(target: Node) -> void:
	"""Shield'e çarptı - hem projectile hem shield yok ol."""
	var shield = target
	
	# Eğer target BlockArea ise parent'ı al
	if target.name == "BlockArea":
		shield = target.get_parent()
	
	# ShieldItem'i bul
	if not shield.is_in_group("shield"):
		# Parent'ta ara
		var parent = shield.get_parent()
		if parent and parent.is_in_group("shield"):
			shield = parent
	
	# ShieldItem'in consume_block() metodunu çağır
	if shield.has_method("consume_block"):
		shield.consume_block()
		print("Projectile: Hit shield, both destroyed!")
	else:
		# Duck typing: direkt destroy et
		if shield.has_method("queue_free"):
			shield.queue_free()
		print("Projectile: Hit shield but no consume_block method found!")
	
	# Projectile'i yok et
	queue_free()


func _hit_world() -> void:
	"""World'e çarptı."""
	print("Projectile: Hit world, destroyed!")
	queue_free()

