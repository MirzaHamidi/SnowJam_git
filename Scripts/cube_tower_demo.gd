extends Node3D

# Küp sayısı
const CUBE_COUNT := 4
# Küpler arası dikey mesafe (kule oluştururken)
const CUBE_SPACING := 1.1
# Küp boyutu
const CUBE_SIZE := 1.0
# Rastgele pozisyon aralığı
const RANDOM_POS_MIN := -4.0
const RANDOM_POS_MAX := 4.0
# Başlangıç Y pozisyonu
const START_Y := 0.0
# Animasyon süresi (saniye)
const ANIMATION_DURATION := 0.5

# Küplerin referanslarını tutan array
var cubes: Array[Node3D] = []
# Kule modunda mıyız?
var is_tower_mode := false


func _ready() -> void:
	# Sahne başladığında küpleri oluştur
	_create_cubes()


func _input(event: InputEvent) -> void:
	# R tuşuna basıldığında küpleri düzenle
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			if is_tower_mode:
				_scatter_cubes()
			else:
				_arrange_cubes_in_tower()


func _create_cubes() -> void:
	"""Sahne başladığında rastgele pozisyonlarda küpler oluştur."""
	cubes.clear()
	
	for i in range(CUBE_COUNT):
		var cube = _create_single_cube(i)
		# Rastgele X ve Z pozisyonları
		var random_x = randf_range(RANDOM_POS_MIN, RANDOM_POS_MAX)
		var random_z = randf_range(RANDOM_POS_MIN, RANDOM_POS_MAX)
		
		cube.position = Vector3(random_x, START_Y, random_z)
		add_child(cube)
		cubes.append(cube)


func _create_single_cube(index: int) -> MeshInstance3D:
	"""Tek bir küp oluştur ve döndür."""
	var cube = MeshInstance3D()
	
	# Küp mesh'i oluştur
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(CUBE_SIZE, CUBE_SIZE, CUBE_SIZE)
	cube.mesh = box_mesh
	
	# Her küpe farklı bir renk ver (görsel olarak ayırt etmek için)
	var material = StandardMaterial3D.new()
	var hue = float(index) / float(CUBE_COUNT)  # 0-1 arası hue değeri
	material.albedo_color = Color.from_hsv(hue, 0.8, 0.9)
	cube.material_override = material
	
	# Küp için bir isim ver
	cube.name = "Cube_" + str(index)
	
	return cube


func _arrange_cubes_in_tower() -> void:
	"""Küpleri kule şeklinde düzenle (ortada, üst üste)."""
	if cubes.is_empty():
		return
	
	is_tower_mode = true
	
	# Her küp için hedef pozisyonu hesapla ve animasyonla hareket ettir
	for i in range(cubes.size()):
		var cube = cubes[i]
		var target_y = START_Y + (i * CUBE_SPACING)
		var target_position = Vector3(0.0, target_y, 0.0)
		
		_animate_cube_to_position(cube, target_position)


func _scatter_cubes() -> void:
	"""Küpleri tekrar rastgele pozisyonlara dağıt."""
	if cubes.is_empty():
		return
	
	is_tower_mode = false
	
	# Her küp için rastgele hedef pozisyon oluştur
	for cube in cubes:
		var random_x = randf_range(RANDOM_POS_MIN, RANDOM_POS_MAX)
		var random_z = randf_range(RANDOM_POS_MIN, RANDOM_POS_MAX)
		var target_position = Vector3(random_x, START_Y, random_z)
		
		_animate_cube_to_position(cube, target_position)


func _animate_cube_to_position(cube: Node3D, target_position: Vector3) -> void:
	"""Bir küpü Tween kullanarak hedef pozisyona yumuşak bir şekilde hareket ettir."""
	# Yeni bir Tween oluştur
	var tween = create_tween()
	tween.set_parallel(true)  # Paralel animasyonlar için
	
	# Pozisyon animasyonu
	tween.tween_property(cube, "position", target_position, ANIMATION_DURATION)
	tween.set_ease(Tween.EASE_OUT)  # Yumuşak bitiş
	tween.set_trans(Tween.TRANS_CUBIC)  # Kübik geçiş (daha akıcı)
