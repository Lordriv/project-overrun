extends Control
## Crosshair UI — drawn directly via _draw().
## Bound to a WeaponHolder; rebinds to whichever weapon is active.
## Has two visibility states: active (full crosshair) and idle (just the dimmed center).

# --- Visual constants ---
const BASELINE_OPACITY: float = 0.65
const COLOR_DEFAULT: Color = Color.WHITE
const COLOR_AMMO_EMPTY: Color = Color(1, 1, 1, 0.2)

const DIAMOND_SIZE: float = 16.0
const DIAMOND_LINE_WIDTH: float = 2.0
const IDLE_DIAMOND_SCALE: float = 0.75      # idle diamond shrinks to 75%
const IDLE_DIAMOND_OPACITY: float = 0.75    # × baseline = ~49% effective

const CHEVRON_OFFSET: float = 32.0
const CHEVRON_SIZE: float = 8.0
const CHEVRON_LINE_WIDTH: float = 2.0
const FIRING_OFFSET_FADE_DURATION: float = 0.1   

const TICK_GAP: float = 11.0
const TICK_LENGTH: float = 14.0
const TICK_LINE_WIDTH: float = 2.0

const AMMO_DOT_COUNT: int = 8
const AMMO_DOT_RADIUS: float = 2.0
const AMMO_DOT_SPACING: float = 5.0

# --- Idle behavior ---
const IDLE_TIMEOUT: float = 3.0    # seconds of no firing/ADS before idle
const FADE_DURATION: float = 0.2   # how fast outer elements fade in/out

# --- State ---
var weapon_holder: WeaponHolder = null
var _current_weapon: WeaponComponent = null

var _time_since_activity: float = 0.0
var _outer_visibility: float = 0.0   # 0.0 = idle/hidden, 1.0 = fully active
var _diamond_visibility: float = 1.0  # 0.0 = full idle (small/dim), 1.0 = active
var _firing_offset_progress: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(queue_redraw)
	# Start in idle state until something happens
	_outer_visibility = 0.0
	_diamond_visibility = 0.0


func _process(delta: float) -> void:
	# Track activity: firing or ADS counts as activity
	var is_active: bool = _is_currently_active()
	var is_firing: bool = Input.is_action_pressed("attack1")
	
	if is_active:
		_time_since_activity = 0.0
	else:
		_time_since_activity += delta
	
	# Visibility fade (idle → active)
	var visibility_target: float = 1.0 if _time_since_activity < IDLE_TIMEOUT else 0.0
	var visibility_step: float = delta / FADE_DURATION
	_outer_visibility = move_toward(_outer_visibility, visibility_target, visibility_step)
	_diamond_visibility = move_toward(_diamond_visibility, visibility_target, visibility_step)
	
	# Chevron breathing (firing → resting)
	var firing_target: float = 1.0 if is_firing else 0.0
	var firing_step: float = delta / FIRING_OFFSET_FADE_DURATION
	_firing_offset_progress = move_toward(_firing_offset_progress, firing_target, firing_step)
	
	queue_redraw()


func _is_currently_active() -> bool:
	# ADS is held → active
	if Input.is_action_pressed("ads"):
		return true
	# Firing → active
	if Input.is_action_pressed("attack1"):
		return true
	return false


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
		if _current_weapon.fired.is_connected(_on_weapon_state_changed):
			_current_weapon.fired.disconnect(_on_weapon_state_changed)
		if _current_weapon.reload_progress_changed.is_connected(_on_reload_progress):
			_current_weapon.reload_progress_changed.disconnect(_on_reload_progress)
		if _current_weapon.reload_completed.is_connected(_on_reload_completed):
			_current_weapon.reload_completed.disconnect(_on_reload_completed)
	
	_current_weapon = weapon
	
	if _current_weapon != null:
		_current_weapon.fired.connect(_on_weapon_state_changed)
		_current_weapon.reload_progress_changed.connect(_on_reload_progress)
		_current_weapon.reload_completed.connect(_on_reload_completed)
	
	queue_redraw()


# Repaint hooks — note _process also calls queue_redraw every frame for fade
func _on_weapon_state_changed(_remaining_ammo: int) -> void:
	queue_redraw()

func _on_reload_progress(_progress: float) -> void:
	queue_redraw()

func _on_reload_completed() -> void:
	queue_redraw()


# --- Drawing ---

func _draw() -> void:
	var center: Vector2 = get_viewport_rect().size / 2.0
	
	# Diamond is always drawn, but its size and opacity blend between idle and active
	var diamond_scale: float = lerp(IDLE_DIAMOND_SCALE, 1.0, _diamond_visibility)
	var diamond_opacity_mult: float = lerp(IDLE_DIAMOND_OPACITY, 1.0, _diamond_visibility)
	var diamond_color: Color = COLOR_DEFAULT
	diamond_color.a = BASELINE_OPACITY * diamond_opacity_mult
	_draw_diamond(center, DIAMOND_SIZE * diamond_scale, diamond_color)
	
	# Outer elements only visible when active (or fading)
	if _outer_visibility <= 0.0:
		return
	
	var outer_color: Color = COLOR_DEFAULT
	outer_color.a = BASELINE_OPACITY * _outer_visibility
	
	var firing_offset: float = 0.0
	if _current_weapon != null:
		firing_offset = _current_weapon.firing_chevron_offset * _firing_offset_progress
	var current_chevron_offset: float = CHEVRON_OFFSET + firing_offset
	var left_chevron_tip: Vector2 = center + Vector2(-current_chevron_offset, 0)
	var right_chevron_tip: Vector2 = center + Vector2(current_chevron_offset, 0)
	var left_tick_start: Vector2 = left_chevron_tip + Vector2(-TICK_GAP, 0)
	var right_tick_start: Vector2 = right_chevron_tip + Vector2(TICK_GAP, 0)
	
	_draw_left_chevron(left_chevron_tip, CHEVRON_SIZE, outer_color)
	_draw_right_chevron(right_chevron_tip, CHEVRON_SIZE, outer_color)
	_draw_tick(left_tick_start, TICK_LENGTH, outer_color, true)
	_draw_ammo_display(right_tick_start, outer_color)


func _draw_diamond(c: Vector2, s: float, col: Color) -> void:
	var top := c + Vector2(0, -s)
	var right := c + Vector2(s, 0)
	var bottom := c + Vector2(0, s)
	var left := c + Vector2(-s, 0)
	draw_line(top, right, col, DIAMOND_LINE_WIDTH)
	draw_line(right, bottom, col, DIAMOND_LINE_WIDTH)
	draw_line(bottom, left, col, DIAMOND_LINE_WIDTH)
	draw_line(left, top, col, DIAMOND_LINE_WIDTH)


func _draw_left_chevron(tip: Vector2, s: float, col: Color) -> void:
	var upper := tip + Vector2(s, -s)
	var lower := tip + Vector2(s, s)
	draw_line(upper, tip, col, CHEVRON_LINE_WIDTH)
	draw_line(tip, lower, col, CHEVRON_LINE_WIDTH)


func _draw_right_chevron(tip: Vector2, s: float, col: Color) -> void:
	var upper := tip + Vector2(-s, -s)
	var lower := tip + Vector2(-s, s)
	draw_line(upper, tip, col, CHEVRON_LINE_WIDTH)
	draw_line(tip, lower, col, CHEVRON_LINE_WIDTH)


func _draw_tick(start: Vector2, length: float, col: Color, going_left: bool) -> void:
	var direction: float = -1.0 if going_left else 1.0
	var end_point := start + Vector2(length * direction, 0)
	draw_line(start, end_point, col, TICK_LINE_WIDTH)


func _draw_ammo_display(start: Vector2, col: Color) -> void:
	var filled_dots: int = _calculate_filled_dots()
	for i in range(AMMO_DOT_COUNT):
		var dot_pos := start + Vector2(i * AMMO_DOT_SPACING, 0)
		# Empty-dot color also scales with outer fade
		var empty_color: Color = COLOR_AMMO_EMPTY
		empty_color.a = COLOR_AMMO_EMPTY.a * _outer_visibility
		var dot_color: Color = col if i < filled_dots else empty_color
		draw_circle(dot_pos, AMMO_DOT_RADIUS, dot_color)


func _calculate_filled_dots() -> int:
	if _current_weapon == null:
		return AMMO_DOT_COUNT
	if _current_weapon.magazine_size <= 0:
		return 0
	var ratio: float = float(_current_weapon.current_ammo) / float(_current_weapon.magazine_size)
	return int(ceil(ratio * AMMO_DOT_COUNT))
