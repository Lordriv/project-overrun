class_name Terminal
extends Area3D
## Interactable that activates when WaveManager.wave_completed fires.
## When player enters and presses interact, opens AugmentPickUI.

signal terminal_activated
signal terminal_used

@export var interaction_prompt: Node3D  # InteractionPrompt scene instance

var is_active: bool = false
var _player_in_range: Node = null


func _ready() -> void:
	WaveManager.wave_completed.connect(_on_wave_completed)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_hide_prompt()


func _process(_delta: float) -> void:
	if not is_active or _player_in_range == null:
		return
	if Input.is_action_just_pressed("interact"):
		_use_terminal()


func _on_wave_completed(_wave_number: int) -> void:
	print("[Terminal] wave completed, activating. Player in range: ", _player_in_range)
	is_active = true
	if _player_in_range != null:
		_show_prompt()
	terminal_activated.emit()


func _on_body_entered(body: Node3D) -> void:
	print("[Terminal] body_entered: ", body.name, " | in player group: ", body.is_in_group("player"))
	if body.is_in_group("player"):
		_player_in_range = body
		if is_active:
			_show_prompt()


func _on_body_exited(body: Node3D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		_hide_prompt()


func _use_terminal() -> void:
	if not is_active or _player_in_range == null:
		return
	WaveManager.pause_run()
	_hide_prompt()
	var ui := AugmentPickUI.open(_player_in_range)
	await ui.augment_chosen
	WaveManager.resume_run()
	is_active = false
	terminal_used.emit()


func _show_prompt() -> void:
	if interaction_prompt and interaction_prompt.has_method("show_prompt"):
		interaction_prompt.show_prompt()


func _hide_prompt() -> void:
	if interaction_prompt and interaction_prompt.has_method("hide_prompt"):
		interaction_prompt.hide_prompt()
