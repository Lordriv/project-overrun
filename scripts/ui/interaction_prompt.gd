extends Label3D

@export var prompt_text: String = "[E] Interact"
@export var show_max_wave: bool = false


func _ready() -> void:
	_update_text()
	visible = false


func show_prompt() -> void:
	_update_text()  # refresh max wave each time it appears
	visible = true


func hide_prompt() -> void:
	visible = false


func _update_text() -> void:
	if show_max_wave:
		text = "%s\nMax wave: %d" % [prompt_text, PlayerData.max_wave_reached]
	else:
		text = prompt_text
