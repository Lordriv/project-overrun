extends Control
## Crosshair UI — drawn directly via _draw().
## Bound to a WeaponHolder; rebinds to whichever weapon is active.
## Two visibility states: active (full crosshair + ammo dots) and idle (dimmed center diamond only).

# Neon-industrial palette — matches HUD
const COLOR_DEFAULT:     Color = Color("#e8e8f0")         # slightly blue-white
const COLOR_AMMO_FILLED: Color = Color("#ff2060")         # magenta, matches weapon accent
const COLOR_AMMO_EMPTY:  Color = Color(0.1, 0.08, 0.15, 0.35)

const BASELINE_OPACITY:     float = 0.65
const IDLE_DIAMOND_SCALE:   float = 0.75   # idle diamond shrinks to 75%
const IDLE_DIAMOND_OPACITY: float = 0.75   # × baseline ≈ 49% effective

# Base sizes at 1080p — multiplied by _draw_scale at draw time
const DIAMOND_SIZE:       float = 16.0
const DIAMOND_LINE_WIDTH: float = 1.5
const CHEVRON_OFFSET:     float = 32.0
const CHEVRON_SIZE:       float = 8.0
const CHEVRON_LINE_WIDTH: float = 1.5
const TICK_GAP:           float = 11.0
const TICK_LENGTH:        float = 14.0
const TICK_LINE_WIDTH:    float = 1.5
const AMMO_DOT_COUNT:     int   = 8
const AMMO_DOT_RADIUS:    float = 2.0
const AMMO_DOT_SPACING:   float = 5.0

const IDLE_TIMEOUT:               float = 3.0
const FADE_DURATION:              float = 0.2
const FIRING_OFFSET_FADE_DURATION: float = 0.1

var weapon_holder:    WeaponHolder   = null
var _current_weapon:  WeaponComponent = null

var _time_since_activity:    float = 0.0
var _outer_visibility:       float = 0.0
var _diamond_visibility:     float = 0.0
var _firing_offset_progress: float = 0.0
var _draw_scale:             float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	_draw_scale = get_viewport().size.y / 1080.0

	var is_active := _is_currently_active()
	if is_active:
		_time_since_activity = 0.0
	else:
		_time_since_activity += delta

	var vis_target: float = 1.0 if _time_since_activity < IDLE_TIMEOUT else 0.0
	var vis_step   := delta / FADE_DURATION
	_outer_visibility   = move_toward(_outer_visibility,   vis_target, vis_step)
	_diamond_visibility = move_toward(_diamond_visibility, vis_target, vis_step)

	var fire_target: float = 1.0 if Input.is_action_pressed("attack1") else 0.0
	_firing_offset_progress = move_toward(_firing_offset_progress, fire_target, delta / FIRING_OFFSET_FADE_DURATION)

	queue_redraw()


func _is_currently_active() -> bool:
	return Input.is_action_pressed("ads") or Input.is_action_pressed("attack1")


# --- Public API ---

func set_weapon_holder(holder: WeaponHolder) -> void:
	if weapon_holder != null:
		weapon_holder.weapon_changed.disconnect(_on_weapon_changed)
	weapon_holder = holder
	if holder != null:
		holder.weapon_changed.connect(_on_weapon_changed)
		_bind_to_weapon(holder.active_weapon)


func _on_weapon_changed(new_weapon: WeaponComponent) -> void:
	_bind_to_weapon(new_weapon)


func _bind_to_weapon(weapon: WeaponComponent) -> void:
	if _current_weapon != null:
		if _current_weapon.fired.is_connected(_on_weapon_fired):
			_current_weapon.fired.disconnect(_on_weapon_fired)
		if _current_weapon.reload_progress_changed.is_connected(_on_reload_tick):
			_current_weapon.reload_progress_changed.disconnect(_on_reload_tick)
		if _current_weapon.reload_completed.is_connected(_on_reload_done):
			_current_weapon.reload_completed.disconnect(_on_reload_done)

	_current_weapon = weapon

	if _current_weapon != null:
		_current_weapon.fired.connect(_on_weapon_fired)
		_current_weapon.reload_progress_changed.connect(_on_reload_tick)
		_current_weapon.reload_completed.connect(_on_reload_done)

	queue_redraw()


func _on_weapon_fired(_ammo: int) -> void:  queue_redraw()
func _on_reload_tick(_p: float)   -> void:  queue_redraw()
func _on_reload_done()            -> void:  queue_redraw()


# --- Drawing ---

func _draw() -> void:
	var center := get_viewport_rect().size / 2.0
	var s      := _draw_scale

	# Diamond: always present, blends size + opacity between idle and active
	var d_scale:   float = lerp(IDLE_DIAMOND_SCALE, 1.0, _diamond_visibility)
	var d_opacity: float = lerp(IDLE_DIAMOND_OPACITY, 1.0, _diamond_visibility)
	var d_color   := COLOR_DEFAULT
	d_color.a = BASELINE_OPACITY * d_opacity
	_draw_diamond(center, DIAMOND_SIZE * d_scale * s, d_color)

	if _outer_visibility <= 0.0:
		return

	var outer_color := COLOR_DEFAULT
	outer_color.a = BASELINE_OPACITY * _outer_visibility

	var firing_extra := 0.0
	if _current_weapon != null:
		firing_extra = _current_weapon.firing_chevron_offset * _firing_offset_progress

	var ch_off    := (CHEVRON_OFFSET + firing_extra) * s
	var left_tip  := center + Vector2(-ch_off, 0.0)
	var right_tip := center + Vector2(ch_off, 0.0)

	_draw_left_chevron(left_tip,   CHEVRON_SIZE * s, outer_color)
	_draw_right_chevron(right_tip, CHEVRON_SIZE * s, outer_color)
	_draw_tick(left_tip  + Vector2(-TICK_GAP * s, 0.0), TICK_LENGTH * s, outer_color, true)
	_draw_ammo_display(right_tip + Vector2(TICK_GAP * s, 0.0), s)


func _draw_diamond(c: Vector2, size: float, col: Color) -> void:
	var lw := maxf(1.0, DIAMOND_LINE_WIDTH * _draw_scale)
	draw_line(c + Vector2(0.0,  -size), c + Vector2(size,  0.0), col, lw)
	draw_line(c + Vector2(size,  0.0), c + Vector2(0.0,  size), col, lw)
	draw_line(c + Vector2(0.0,  size), c + Vector2(-size, 0.0), col, lw)
	draw_line(c + Vector2(-size, 0.0), c + Vector2(0.0, -size), col, lw)


func _draw_left_chevron(tip: Vector2, s: float, col: Color) -> void:
	var lw := maxf(1.0, CHEVRON_LINE_WIDTH * _draw_scale)
	draw_line(tip + Vector2(s, -s), tip, col, lw)
	draw_line(tip, tip + Vector2(s,  s), col, lw)


func _draw_right_chevron(tip: Vector2, s: float, col: Color) -> void:
	var lw := maxf(1.0, CHEVRON_LINE_WIDTH * _draw_scale)
	draw_line(tip + Vector2(-s, -s), tip, col, lw)
	draw_line(tip, tip + Vector2(-s,  s), col, lw)


func _draw_tick(start: Vector2, length: float, col: Color, going_left: bool) -> void:
	var lw  := maxf(1.0, TICK_LINE_WIDTH * _draw_scale)
	var dir: float = -1.0 if going_left else 1.0
	draw_line(start, start + Vector2(length * dir, 0.0), col, lw)


func _draw_ammo_display(start: Vector2, s: float) -> void:
	var filled  := _calculate_filled_dots()
	var radius  := AMMO_DOT_RADIUS * s
	var spacing := AMMO_DOT_SPACING * s
	for i in range(AMMO_DOT_COUNT):
		var pos := start + Vector2(i * spacing, 0.0)
		var col: Color
		if i < filled:
			col   = COLOR_AMMO_FILLED
			col.a = BASELINE_OPACITY * _outer_visibility
		else:
			col   = COLOR_AMMO_EMPTY
			col.a = COLOR_AMMO_EMPTY.a * _outer_visibility
		draw_circle(pos, radius, col)


func _calculate_filled_dots() -> int:
	if _current_weapon == null or _current_weapon.magazine_size <= 0:
		return AMMO_DOT_COUNT
	var ratio := float(_current_weapon.current_ammo) / float(_current_weapon.magazine_size)
	return int(ceil(ratio * AMMO_DOT_COUNT))
