extends CanvasLayer
## HUD — self-view HUD. HP/shield bottom-center, wave/state top-right.
## Listens directly to the local player's HealthComponent and to WaveManager.

const FONT: FontFile = preload("res://assets/font/BebasNeue-Regular.ttf")

# Warm-industrial palette per GDD v0.4 Section 19
const HP_COLOR := Color("#c4543e")
const HP_BG_COLOR := Color("#1a0a08")
const HP_BORDER := Color("#d96b50")

const SHIELD_COLOR := Color("#d4a040")
const SHIELD_BG_COLOR := Color("#1a1208")
const SHIELD_BORDER := Color("#e0b558")

const VALUE_COLOR := Color("#f0e0c4")
const WAVE_LABEL_COLOR := Color("#d4c4a8")        # bone, per GDD palette
const WAVE_SEPARATOR_COLOR := Color("#7a5a3a")    # faded brown

# State colors per GDD v0.4 Section 11
const STATE_COLOR_COMBAT := Color("#c4543e")      # rust-red
const STATE_COLOR_EXPLORE := Color("#d4a040")     # amber
const STATE_COLOR_SCOUTING := Color("#d47500")    # rust-orange
const STATE_COLOR_TECH := Color("#a04040")        # blood-red
const STATE_COLOR_EXTRACT := Color("#e0b558")     # gold

# HP/shield bar geometry
const PANEL_WIDTH: float = 340.0
const SHIELD_BAR_HEIGHT: float = 30.0
const HP_BAR_HEIGHT: float = 36.0
const BAR_GAP: float = 5.0
const BOTTOM_MARGIN: float = 40.0
const BORDER_WIDTH: int = 1
const OUTER_GAP: int = 2

# Wave indicator geometry
const WAVE_TOP_MARGIN: float = 24.0
const WAVE_RIGHT_MARGIN: float = 32.0
const STATE_FADE_DURATION: float = 0.25

enum HudState { COMBAT, EXPLORE, SCOUTING, TECH, EXTRACT }

var _health: HealthComponent = null
var _shield_fill: ColorRect
var _hp_fill: ColorRect
var _shield_fill_max_width: float = 0.0
var _hp_fill_max_width: float = 0.0
var _shield_value: Label
var _hp_value: Label

var _wave_label: Label
var _state_label: Label
var _current_state: HudState = HudState.COMBAT
var _state_tween: Tween = null


func _ready() -> void:
	layer = 10
	_build_ui()
	visible = false
	_connect_wave_manager()


func bind_to_player(player: Node) -> void:
	var health: HealthComponent = _find_health(player)
	if health == null:
		push_error("[HUD] Player has no HealthComponent (searched in: ", player.name, ")")
		return
	_health = health
	_refresh_vitals()
	_refresh_wave_text()
	visible = true
	if not health.damaged.is_connected(_on_damaged):
		health.damaged.connect(_on_damaged)
	if not health.healed.is_connected(_on_healed):
		health.healed.connect(_on_healed)


func _find_health(node: Node) -> HealthComponent:
	if node is HealthComponent:
		return node
	for child in node.get_children():
		var found := _find_health(child)
		if found != null:
			return found
	return null


func _process(_delta: float) -> void:
	if _health != null and not _health.is_dead:
		_refresh_vitals()
	_update_derived_state()


# ============================================================
# VITALS (HP / SHIELD)
# ============================================================

func _refresh_vitals() -> void:
	if _health == null:
		return
	var shield_pct: float = clamp(_health.current_shield / _health.max_shield, 0.0, 1.0) if _health.max_shield > 0.0 else 0.0
	var hp_pct: float = clamp(_health.current_hp / _health.max_hp, 0.0, 1.0) if _health.max_hp > 0.0 else 0.0
	_shield_fill.size.x = _shield_fill_max_width * shield_pct
	_hp_fill.size.x = _hp_fill_max_width * hp_pct
	_shield_value.text = "%d / %d" % [int(_health.current_shield), int(_health.max_shield)]
	_hp_value.text = "%d / %d" % [int(_health.current_hp), int(_health.max_hp)]


func _on_damaged(_amount: float, _hp: float, _shield: float) -> void:
	_refresh_vitals()


func _on_healed(_amount: float, _hp: float) -> void:
	_refresh_vitals()


# ============================================================
# WAVE + STATE
# ============================================================

func _connect_wave_manager() -> void:
	if WaveManager.wave_started.is_connected(_on_wave_started):
		return
	WaveManager.wave_started.connect(_on_wave_started)
	WaveManager.wave_completed.connect(_on_wave_completed)


func _on_wave_started(_wave_number: int, _total_enemies: int) -> void:
	_refresh_wave_text()
	_set_state(HudState.COMBAT)


func _on_wave_completed(_wave_number: int) -> void:
	_set_state(HudState.EXPLORE)


## Polls WaveManager to derive state changes that don't have signals.
## Specifically: when the augment-pick UI opens, WaveManager is paused -> TECH.
## When resumed and a wave hasn't started, we infer back to EXPLORE.
func _update_derived_state() -> void:
	if WaveManager._paused and _current_state != HudState.TECH:
		_set_state(HudState.TECH)
	# COMBAT and EXPLORE are driven by signals from WaveManager directly,
	# so we don't override them here.


func _refresh_wave_text() -> void:
	var wave_num: int = max(WaveManager._current_wave, 1)
	_wave_label.text = "WAVE %d" % wave_num


func _set_state(new_state: HudState) -> void:
	if new_state == _current_state:
		return
	_current_state = new_state
	_animate_state_change()


func _animate_state_change() -> void:
	# Kill any in-flight tween so consecutive changes don't stack.
	if _state_tween != null and _state_tween.is_valid():
		_state_tween.kill()
	_state_tween = create_tween()
	_state_tween.tween_property(_state_label, "modulate:a", 0.0, STATE_FADE_DURATION * 0.5)
	_state_tween.tween_callback(_apply_state_text)
	_state_tween.tween_property(_state_label, "modulate:a", 1.0, STATE_FADE_DURATION * 0.5)


func _apply_state_text() -> void:
	match _current_state:
		HudState.COMBAT:
			_state_label.text = "COMBAT"
			_state_label.add_theme_color_override("font_color", STATE_COLOR_COMBAT)
		HudState.EXPLORE:
			_state_label.text = "EXPLORE"
			_state_label.add_theme_color_override("font_color", STATE_COLOR_EXPLORE)
		HudState.SCOUTING:
			_state_label.text = "SCOUTING"
			_state_label.add_theme_color_override("font_color", STATE_COLOR_SCOUTING)
		HudState.TECH:
			_state_label.text = "TECH"
			_state_label.add_theme_color_override("font_color", STATE_COLOR_TECH)
		HudState.EXTRACT:
			_state_label.text = "EXTRACT"
			_state_label.add_theme_color_override("font_color", STATE_COLOR_EXTRACT)


# ============================================================
# UI CONSTRUCTION
# ============================================================

func _build_ui() -> void:
	_build_vitals()
	_build_wave_indicator()


func _build_vitals() -> void:
	var root := VBoxContainer.new()
	root.name = "VitalsRoot"
	root.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	root.add_theme_constant_override("separation", int(BAR_GAP))
	root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	root.position = Vector2(-PANEL_WIDTH / 2.0, -SHIELD_BAR_HEIGHT - HP_BAR_HEIGHT - BAR_GAP - BOTTOM_MARGIN)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var shield_row := _make_bar_row(SHIELD_BAR_HEIGHT, SHIELD_COLOR, SHIELD_BG_COLOR, SHIELD_BORDER)
	root.add_child(shield_row.container)
	_shield_fill = shield_row.fill
	_shield_value = shield_row.value
	_shield_fill_max_width = shield_row.fill_max_width

	var hp_row := _make_bar_row(HP_BAR_HEIGHT, HP_COLOR, HP_BG_COLOR, HP_BORDER)
	root.add_child(hp_row.container)
	_hp_fill = hp_row.fill
	_hp_value = hp_row.value
	_hp_fill_max_width = hp_row.fill_max_width


func _build_wave_indicator() -> void:
	# Anchored top-right. HBox so wave + separator + state read as a single line.
	var row := HBoxContainer.new()
	row.name = "WaveIndicator"
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.position = Vector2(-WAVE_RIGHT_MARGIN, WAVE_TOP_MARGIN)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # extend leftward from the right anchor
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_wave_label = Label.new()
	_wave_label.text = "WAVE 1"
	_wave_label.add_theme_font_override("font", FONT)
	_wave_label.add_theme_font_size_override("font_size", 22)
	_wave_label.add_theme_color_override("font_color", WAVE_LABEL_COLOR)
	_wave_label.add_theme_constant_override("outline_size", 3)
	_wave_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_wave_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_wave_label)

	var sep := Label.new()
	sep.text = "//"
	sep.add_theme_font_override("font", FONT)
	sep.add_theme_font_size_override("font_size", 22)
	sep.add_theme_color_override("font_color", WAVE_SEPARATOR_COLOR)
	sep.add_theme_constant_override("outline_size", 3)
	sep.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sep)

	_state_label = Label.new()
	_state_label.text = "COMBAT"
	_state_label.add_theme_font_override("font", FONT)
	_state_label.add_theme_font_size_override("font_size", 22)
	_state_label.add_theme_color_override("font_color", STATE_COLOR_COMBAT)
	_state_label.add_theme_constant_override("outline_size", 3)
	_state_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_state_label)


## Builds one bar row with nested-border structure for precision-instrument look.
func _make_bar_row(bar_height: float, fill_color: Color, bg_color: Color, border_color: Color) -> Dictionary:
	var outer_panel := Panel.new()
	outer_panel.custom_minimum_size = Vector2(PANEL_WIDTH, bar_height)
	outer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = Color(0, 0, 0, 0)
	outer_style.border_color = border_color
	outer_style.set_border_width_all(BORDER_WIDTH)
	outer_style.set_corner_radius_all(0)
	outer_panel.add_theme_stylebox_override("panel", outer_style)

	var inner_panel := Panel.new()
	inner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner_offset: int = BORDER_WIDTH + OUTER_GAP
	inner_panel.position = Vector2(inner_offset, inner_offset)
	inner_panel.size = Vector2(PANEL_WIDTH - inner_offset * 2, bar_height - inner_offset * 2)
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = bg_color
	inner_style.border_color = border_color
	inner_style.set_border_width_all(BORDER_WIDTH)
	inner_style.set_corner_radius_all(0)
	inner_panel.add_theme_stylebox_override("panel", inner_style)
	outer_panel.add_child(inner_panel)

	var fill := ColorRect.new()
	fill.color = fill_color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(BORDER_WIDTH, BORDER_WIDTH)
	var fill_max_width := inner_panel.size.x - BORDER_WIDTH * 2
	var fill_height := inner_panel.size.y - BORDER_WIDTH * 2
	fill.size = Vector2(fill_max_width, fill_height)
	inner_panel.add_child(fill)

	var value := Label.new()
	value.text = "0 / 0"
	value.add_theme_font_override("font", FONT)
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", VALUE_COLOR)
	value.add_theme_constant_override("outline_size", 3)
	value.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	value.set_anchors_preset(Control.PRESET_FULL_RECT)
	value.offset_left = 8
	value.offset_right = -10
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_panel.add_child(value)

	return {
		"container": outer_panel,
		"fill": fill,
		"value": value,
		"fill_max_width": fill_max_width,
	}
