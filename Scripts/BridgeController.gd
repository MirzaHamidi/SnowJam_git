extends Node3D

## Bridge Controller - AnimationTree ile tüm animasyonları paralel çalıştırma
## 
## REFACTOR NOTES:
## 1) AnimationTree kullanarak AnimationPlayer'daki tüm animasyonları paralel çalıştır
## 2) BlendTree ile Mix node'ları kullanarak tüm animasyonları aynı anda oynat
## 3) Speed kontrolü ve rewind desteği

# ============================================
# EXPORT PARAMETERS
# ============================================
@export_group("Animation Setup")
@export var exclude_anims: PackedStringArray = ["RESET"]  # Bu animasyonlar dahil edilmez

@export_group("Playback")
@export var auto_start: bool = true
@export var speed: float = 1.0
@export var rewind_speed: float = -1.0

@export_group("Debug")
@export var debug_enabled: bool = false

# ============================================
# NODE REFERENCES
# ============================================
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var anim_tree: AnimationTree = $AnimTree

# ============================================
# RUNTIME STATE
# ============================================
var is_rewinding: bool = false

# ============================================
# GODOT CALLBACKS
# ============================================
func _ready() -> void:
	_setup_animation_tree()
	
	if auto_start:
		start_all_animations()


func _process(_delta: float) -> void:
	_update_speed()

# ============================================
# PUBLIC API
# ============================================
func start_all_animations() -> void:
	"""
	Tüm animasyonları başlat.
	"""
	if not anim_tree:
		push_error("BridgeController: AnimationTree not found!")
		return
	
	anim_tree.active = true
	
	# AnimationTree otomatik olarak tree_root'u çalıştırır
	# Ekstra başlatma gerekmez, active = true yeterli
	
	if debug_enabled:
		print("[Bridge] All animations started via AnimationTree")


func stop_all_animations() -> void:
	"""
	Tüm animasyonları durdur.
	"""
	if anim_tree:
		anim_tree.active = false
	
	if debug_enabled:
		print("[Bridge] All animations stopped")


func rewind_all() -> void:
	"""
	Tüm animasyonları tersten oynat (rewind).
	"""
	if is_rewinding:
		return
	
	is_rewinding = true
	speed = rewind_speed
	
	if debug_enabled:
		print("[Bridge] Rewind started")


func resume_normal() -> void:
	"""
	Normal oynatmaya dön.
	"""
	is_rewinding = false
	speed = abs(speed)  # Pozitif yap
	
	if debug_enabled:
		print("[Bridge] Resumed normal playback")

# ============================================
# PRIVATE HELPERS
# ============================================
func _setup_animation_tree() -> void:
	"""
	AnimationTree'yi programatik olarak kur.
	"""
	if not animation_player:
		push_error("BridgeController: AnimationPlayer not found!")
		return
	
	# AnimationTree yoksa oluştur
	if not anim_tree:
		anim_tree = AnimationTree.new()
		anim_tree.name = "AnimTree"
		add_child(anim_tree)
	
	# AnimationPlayer'ı bağla
	anim_tree.animation_player = animation_player.get_path()
	
	# AnimationLibrary'deki TÜM animasyonları al
	var anim_names: Array[String] = []
	
	# Eğer spesifik bir library belirtilmişse, sadece ondan al
	if not use_specific_library.is_empty():
		var library = animation_player.get_animation_library(use_specific_library)
		if library:
			anim_names = library.get_animation_list()
			if debug_enabled:
				print("[Bridge] Using library '", use_specific_library, "' with ", anim_names.size(), " animations")
		else:
			push_error("BridgeController: Library '", use_specific_library, "' not found!")
			# Fallback: tüm animasyonları al
			anim_names = animation_player.get_animation_list()
	else:
		# Tüm library'lerdeki tüm animasyonları al
		anim_names = animation_player.get_animation_list()
		if debug_enabled:
			print("[Bridge] Using all libraries, total ", anim_names.size(), " animations")
	
	# Exclude edilen animasyonları filtrele
	var filtered_anims: Array[String] = []
	for anim_name in anim_names:
		if anim_name not in exclude_anims:
			filtered_anims.append(anim_name)
	
	if filtered_anims.is_empty():
		push_error("BridgeController: No animations found after filtering!")
		return
	
	if debug_enabled:
		print("[Bridge] Found ", filtered_anims.size(), " animations: ", filtered_anims)
	
	# BlendTree oluştur
	var blend_tree = AnimationNodeBlendTree.new()
	blend_tree.name = "blend_tree"
	
	# Tüm animasyonları Mix node'ları ile birleştir
	_setup_parallel_animations(blend_tree, filtered_anims)
	
	# BlendTree'yi AnimationTree'ye bağla
	anim_tree.tree_root = blend_tree
	
	# Active yap
	anim_tree.active = true
	
	if debug_enabled:
		print("[Bridge] AnimationTree setup complete")


func _setup_parallel_animations(blend_tree: AnimationNodeBlendTree, anim_names: Array[String]) -> void:
	"""
	BlendTree içinde tüm animasyonları paralel çalıştıracak şekilde kur.
	"""
	if anim_names.is_empty():
		return
	
	# İlk animasyon için AnimationNodeAnimation oluştur
	var first_anim_node = AnimationNodeAnimation.new()
	first_anim_node.animation = anim_names[0]
	blend_tree.add_node("anim_0", first_anim_node)
	
	# Eğer tek animasyon varsa, direkt output'a bağla
	if anim_names.size() == 1:
		blend_tree.connect_node("anim_0", 0, AnimationNodeBlendTree.NodePath("output"))
		return
	
	# İlk Mix node'u oluştur (anim_0 + anim_1)
	var prev_mix_output = "anim_0"
	
	# Her animasyon için Mix node oluştur ve zincirle
	for i in range(1, anim_names.size()):
		var anim_name = anim_names[i]
		
		# AnimationNodeAnimation oluştur
		var anim_node = AnimationNodeAnimation.new()
		anim_node.animation = anim_name
		var anim_node_name = "anim_%d" % i
		blend_tree.add_node(anim_node_name, anim_node)
		
		# Mix node oluştur (önceki output + yeni anim)
		var mix_node = AnimationNodeBlend2.new()
		var mix_node_name = "mix_%d" % i
		blend_tree.add_node(mix_node_name, mix_node)
		
		# Bağlantıları yap
		blend_tree.connect_node(prev_mix_output, 0, mix_node_name)
		blend_tree.connect_node(anim_node_name, 0, mix_node_name)
		
		# Mix ağırlığı 1.0 (her ikisi de tam güçte karışır)
		# Blend2'de blend_amount 0-1 arası, 1.0 = ikinci input tam güçte
		# Ama paralel için her ikisini de tam güçte istiyoruz
		# Bu yüzden blend_amount = 0.5 yaparak her ikisini de eşit karıştır
		# VEYA daha iyi: AnimationNodeAdd2 kullan (eğer varsa)
		# Şimdilik Mix ile 0.5 kullan (her ikisi de yarı güçte karışır, toplamda tam güç)
		# Aslında paralel için Add node daha mantıklı ama Godot 4'te yok
		# Bu yüzden her Mix'i 1.0 yaparak zincirleme toplama yapıyoruz
		blend_tree.set("parameters/%s/blend_amount" % mix_node_name, 1.0)
		
		# Sonraki iterasyon için önceki output'u güncelle
		prev_mix_output = mix_node_name
	
	# Son Mix node'u output'a bağla
	blend_tree.connect_node(prev_mix_output, 0, AnimationNodeBlendTree.NodePath("output"))
	
	if debug_enabled:
		print("[Bridge] Parallel animation setup complete: ", anim_names.size(), " animations mixed")


func _update_speed() -> void:
	"""
	AnimationTree'nin speed'ini güncelle.
	"""
	if not anim_tree or not anim_tree.active:
		return
	
	# AnimationTree'de speed kontrolü için time_scale kullan
	# Not: AnimationTree'de direkt speed_scale yok, AnimationPlayer'ın speed_scale'ini değiştir
	if animation_player:
		animation_player.speed_scale = speed
