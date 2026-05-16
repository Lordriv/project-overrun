extends CanvasLayer
class_name Tutorial

signal completed()

const STEPS: Array = [
	{"text": "Use 🖱️ to look around", "action": "look"},
	{"text": "Try WASD keys to move", "action": "move"},
	{"text": "Try L 🖱️ button to shoot", "action": "shoot"},
	{"text": "Press Q to swap weapons", "action": "swap"},
	{"text": "Try shooting the shotgun", "action": "shoot_shotgun"},
	{"text": "Press C to dash", "action": "dash"},
]

const FILL_PER_INPUT: float = 1.0   # 100% per single trigger (per your spec)

var _step_index: int = 0
var _progress: float = 0.0
var _label: Label
var _bar: ProgressBar
var _player_weapon_holder: WeaponHolder = null


func _ready() -> void:
	# Build minimal UI
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.position = Vector2(-340, -50)
	panel.size = Vector2(320, 100)
	add_child(panel)
	
	_label = Label.new()
	_label.position = Vector2(20, 15)
	_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(_label)
	
	_bar = ProgressBar.new()
	_bar.position = Vector2(20, 60)
	_bar.size = Vector2(280, 8)
	_bar.max_value = 1.0
	_bar.show_percentage = false
	panel.add_child(_bar)
	
	_show_current_step()


func set_player(weapon_holder: WeaponHolder) -> void:
	_player_weapon_holder = weapon_holder


func _show_current_step() -> void:
	if _step_index >= STEPS.size():
		completed.emit()
		queue_free()
		return
	_label.text = STEPS[_step_index].text
	_progress = 0.0
	_bar.value = 0.0


func _process(_delta: float) -> void:
	if _step_index >= STEPS.size():
		return
	
	var action: String = STEPS[_step_index].action
	var triggered: bool = false
	
	match action:
		"look":
			# Continuous fill while moving mouse — handled via _input
			pass
		"move":
			if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right") \
			or Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_down"):
				_progress = min(_progress + 0.1, 1.0)
				_bar.value = _progress
				if _progress >= 1.0:
					await get_tree().create_timer(0.3).timeout
					_step_index += 1
					_show_current_step()
		"shoot":
			if Input.is_action_just_pressed("attack1"):
				triggered = true
		"swap":
			if Input.is_action_just_pressed("weapon_swap"):
				triggered = true
		"shoot_shotgun":
			if Input.is_action_just_pressed("attack1") and _player_weapon_holder != null:
				if _player_weapon_holder.active_slot == 2:
					triggered = true
		"dash":
			if Input.is_action_just_pressed("dash"):
				triggered = true
	
	if triggered:
		_progress = 1.0
		_bar.value = _progress
		await get_tree().create_timer(0.3).timeout
		_step_index += 1
		_show_current_step()


func _input(event: InputEvent) -> void:
	if _step_index >= STEPS.size():
		return
	if STEPS[_step_index].action == "look" and event is InputEventMouseMotion:
		_progress = min(_progress + event.relative.length() * 0.00167, 1.0)
		_bar.value = _progress
		if _progress >= 1.0:
			_step_index += 1
			_show_current_step()
