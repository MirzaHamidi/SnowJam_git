extends Control

## Loading Screen - Minimal UI for scene loading progress
## 
## REFACTOR NOTES:
## 1) Simple progress bar and status label
## 2) Progress update via set_progress()
## 3) No design/animations, just functional

# ============================================
# NODE REFERENCES
# ============================================
@onready var status_label: Label = $LoadingLayer/VBoxContainer/StatusLabel
@onready var loading_bar: ProgressBar = $LoadingLayer/VBoxContainer/LoadingBar
@onready var percent_label: Label = $LoadingLayer/VBoxContainer/PercentLabel

# ============================================
# GODOT CALLBACKS
# ============================================
func _ready() -> void:
	# Initial state
	set_progress(1)
	status_label.text = "Loading..."

# ============================================
# PUBLIC API
# ============================================
func set_progress(pct: int) -> void:
	"""
	Progress bar ve percent label'ı güncelle.
	
	Parameters:
	- pct: Progress percentage (1-100)
	"""
	pct = clamp(pct, 1, 100)
	loading_bar.value = pct
	percent_label.text = "%d%%" % pct


func set_status(text: String) -> void:
	"""
	Status label'ı güncelle.
	
	Parameters:
	- text: Status text
	"""
	status_label.text = text
