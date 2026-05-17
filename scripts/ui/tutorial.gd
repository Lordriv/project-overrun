extends CanvasLayer
class_name Tutorial

signal completed()

const FONT := preload("res://assets/font/BebasNeue-Regular.ttf")

const C_BG       := Color("#1a0f08")
const C_BORDER   := Color("#b86a1c")
const C_ACCENT   := Color("#e89a35")
const C_DIM      := Color("#5a3520")
const C_SUBTLE   := Color("#7a4a28")
const C_TEXT_SEC := Color("#a6692f")
const C_FILL_BG  := Color("#200f05")
const C_COMPLETE := Color("#c8e060")   # brief flash when step clears

# Fill rates for held inputs
const FILL_RATE:      float = 0.78    # ~1.3s — default for shoot, sprint, shotgun
const FILL_RATE_MOVE: float = 0.52    # ~1.9s — walk is 50% longer than default
const MOUSE_RATE:     float = 0.00114 # ~1.75x longer than original 0.002

const STEPS: Array[Dictionary] = [
	{"heading": "LOOK AROUND",   "hint": "MOVE YOUR MOUSE",          "action": "look",          "hold": true},
	{"heading": "ON THE MOVE",   "hint": "HOLD   W  A  S  D",        "action": "move",          "hold": true},
	{"heading": "SPRINT",        "hint": "HOLD SHIFT WHILE MOVING",  "action": "sprint",        "hold": true},
	{"heading": "OPEN FIRE",     "hint": "HOLD LEFT MOUSE BUTTON",   "action": "shoot",         "hold": true},
	{"heading": "SWAP WEAPON",   "hint": "PRESS  Q",                 "action": "swap",          "hold": false},
	{"heading": "SCATTER FIRE",  "hint": "SHOOT WITH THE SCATTER",   "action": "shoot_shotgun", "hold": true},
	{"heading": "DASH",          "hint": "PRESS  C",                 "action": "dash",          "hold": false},
]

var _step_index: int   = 0
var _progress:   float = 0.0
var _advancing:  bool  = false

var _panel:     Panel
var _counter:   Label
var _heading:   Label
var _hint:      Label
var _bar_outer: Panel
var _fill:      ColorRect

var _player_weapon_holder: WeaponHolder = null


func _ready() -> void:
	layer = 5
	_build_ui()
	await get_tree().process_frame
	_update_display()


func set_player(weapon_holder: WeaponHolder) -> void:
	_player_weapon_holder = weapon_holder


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_panel.position  = Vector2(-318, -75)
	_panel.size      = Vector2(298, 150)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color = C_BG
	ps.border_color = C_BORDER
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(0)
	_panel.add_theme_stylebox_override("panel", ps)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   =  14.0
	vbox.offset_right  = -14.0
	vbox.offset_top    =  11.0
	vbox.offset_bottom = -11.0
	vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(vbox)

	# ── Top row: step counter + branding ──
	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(top_row)

	_counter = Label.new()
	_counter.add_theme_font_override("font", FONT)
	_counter.add_theme_font_size_override("font_size", 11)
	_counter.add_theme_color_override("font_color", C_DIM)
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_counter)

	var brand := Label.new()
	brand.text = "DWARFCORE // TRAINING"
	brand.add_theme_font_override("font", FONT)
	brand.add_theme_font_size_override("font_size", 11)
	brand.add_theme_color_override("font_color", C_DIM)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(brand)

	_add_spacer(vbox, 5)

	var sep := ColorRect.new()
	sep.color = C_BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(sep)

	_add_spacer(vbox, 7)

	# ── Heading ──
	_heading = Label.new()
	_heading.add_theme_font_override("font", FONT)
	_heading.add_theme_font_size_override("font_size", 38)
	_heading.add_theme_color_override("font_color", C_ACCENT)
	_heading.add_theme_constant_override("outline_size", 2)
	_heading.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	vbox.add_child(_heading)

	# ── Hint ──
	_hint = Label.new()
	_hint.add_theme_font_override("font", FONT)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", C_TEXT_SEC)
	vbox.add_child(_hint)

	_add_spacer(vbox, 10)

	# ── Progress bar ──
	_bar_outer = Panel.new()
	_bar_outer.custom_minimum_size = Vector2(0, 8)
	_bar_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bos := StyleBoxFlat.new()
	bos.bg_color = C_FILL_BG
	bos.border_color = C_SUBTLE
	bos.set_border_width_all(1)
	bos.set_corner_radius_all(0)
	_bar_outer.add_theme_stylebox_override("panel", bos)
	vbox.add_child(_bar_outer)

	_fill = ColorRect.new()
	_fill.color = C_ACCENT
	_fill.position = Vector2(1, 1)
	_fill.size = Vector2(0, 6)
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_outer.add_child(_fill)


func _add_spacer(parent: Control, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)


# ── Display ──────────────────────────────────────────────────────────────────

func _update_display() -> void:
	if _step_index >= STEPS.size():
		return
	var step: Dictionary = STEPS[_step_index]
	_heading.text = step.heading
	_hint.text    = "▸  " + step.hint
	_counter.text = "STEP %02d / %02d" % [_step_index + 1, STEPS.size()]
	_fill.color   = C_ACCENT
	_update_bar()


func _update_bar() -> void:
	if not is_instance_valid(_bar_outer) or not is_instance_valid(_fill):
		return
	var max_w := maxf(_bar_outer.size.x - 2.0, 0.0)
	_fill.size.x = max_w * clampf(_progress, 0.0, 1.0)


# ── Input handling ────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _advancing or _step_index >= STEPS.size():
		return

	var action: String = STEPS[_step_index].action
	var gained: float  = 0.0

	match action:
		"look":
			pass  # mouse motion handled in _input
		"move":
			if Input.is_action_pressed("ui_left")  or Input.is_action_pressed("ui_right") \
			or Input.is_action_pressed("ui_up")    or Input.is_action_pressed("ui_down"):
				gained = FILL_RATE_MOVE * delta
		"sprint":
			if Input.is_action_pressed("sprint") and (
					Input.is_action_pressed("ui_left")  or Input.is_action_pressed("ui_right") \
					or Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down")):
				gained = FILL_RATE * delta
		"shoot":
			if Input.is_action_pressed("attack1"):
				gained = FILL_RATE * delta
		"swap":
			if Input.is_action_just_pressed("weapon_swap"):
				gained = 1.5   # overflow intentional — spam skips naturally
		"shoot_shotgun":
			if Input.is_action_pressed("attack1") and _player_weapon_holder != null:
				if _player_weapon_holder.active_slot == 2:
					gained = FILL_RATE * delta
		"dash":
			if Input.is_action_just_pressed("dash"):
				gained = 1.5

	if gained > 0.0:
		_progress += gained
		_update_bar()
		if _progress >= 1.0:
			_complete_step(_progress - 1.0)


func _input(event: InputEvent) -> void:
	if _advancing or _step_index >= STEPS.size():
		return
	if STEPS[_step_index].action == "look" and event is InputEventMouseMotion:
		_progress += event.relative.length() * MOUSE_RATE
		_update_bar()
		if _progress >= 1.0:
			_complete_step(_progress - 1.0)


# ── Step completion ───────────────────────────────────────────────────────────

func _complete_step(overflow: float) -> void:
	_advancing = true
	_progress  = 1.0
	_fill.color = C_COMPLETE
	_update_bar()

	await get_tree().create_timer(0.22).timeout

	_step_index += 1
	_progress   = overflow
	_advancing  = false

	if _step_index >= STEPS.size():
		completed.emit()
		queue_free()
		return

	_update_display()
	_update_bar()

	# Overflow >= 1.0 means the player was spamming — skip the next step too
	if _progress >= 1.0:
		await get_tree().create_timer(0.1).timeout
		_complete_step(_progress - 1.0)
