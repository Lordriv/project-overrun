extends CanvasLayer
## HUD — self-view HUD. HP/shield bottom-center, wave/state top-right, weapon name cards bottom-right.
## All pixel constants are 1080p base values; _scale multiplies them at build time.
## Rebuilds on viewport resize so layout always matches the current resolution.

const FONT: FontFile = preload("res://assets/font/BebasNeue-Regular.ttf")

# Industrial-amber palette — matches pause menu
const HP_COLOR     := Color("#c44a2f")   # burnt orange — damage/danger
const HP_BG_COLOR  := Color("#180a06")   # near-black red-brown
const HP_BORDER    := Color("#8c2e1f")   # dark burnt orange

const SHIELD_COLOR    := Color("#e89a35")   # warm amber — protective layer
const SHIELD_BG_COLOR := Color("#1a1206")   # near-black amber-brown
const SHIELD_BORDER   := Color("#b86a1c")   # mid amber

const VALUE_COLOR          := Color("#d4b890")   # warm off-white
const WAVE_LABEL_COLOR     := Color("#c8a878")   # muted amber-tan
const WAVE_SEPARATOR_COLOR := Color("#5a3520")   # dark brown

const STATE_COLOR_COMBAT   := Color("#c44a2f")   # burnt orange
const STATE_COLOR_EXPLORE  := Color("#e89a35")   # amber
const STATE_COLOR_SCOUTING := Color("#d4721c")   # mid orange
const STATE_COLOR_TECH     := Color("#b86a1c")   # dark amber
const STATE_COLOR_EXTRACT  := Color("#e0c070")   # pale gold

const WEAPON_ACCENT_ACTIVE := Color("#e89a35")   # amber
const WEAPON_ACCENT_IDLE   := Color(0.22, 0.14, 0.08)

# 1080p base geometry — multiply by _scale before use
const PANEL_WIDTH:       float = 340.0
const SHIELD_BAR_H:      float = 30.0
const HP_BAR_H:          float = 36.0
const BAR_GAP:           float = 5.0
const BOTTOM_MARGIN:     float = 40.0
const BORDER_W:          int   = 1
const OUTER_GAP:         int   = 2

const WAVE_TOP_MARGIN:   float = 24.0
const WAVE_RIGHT_MARGIN: float = 32.0
const STATE_FADE:        float = 0.25

const CARD_WIDTH:   float = 210.0
const CARD_ACTIVE_H: float = 62.0
const CARD_SEC_H:    float = 44.0
const CARD_GAP:      float = 4.0
const CARD_R_MARGIN: float = 20.0

enum HudState { COMBAT, EXPLORE, SCOUTING, TECH, EXTRACT }

var _health:              HealthComponent = null
var _shield_fill:         ColorRect
var _hp_fill:             ColorRect
var _shield_fill_max_w:   float = 0.0
var _hp_fill_max_w:       float = 0.0
var _shield_value:        Label
var _hp_value:            Label

var _wave_label:   Label
var _state_label:  Label
var _current_state: HudState = HudState.COMBAT
var _state_tween:  Tween = null

var _weapon_holder:  WeaponHolder = null
var _active_card:    Dictionary = {}
var _secondary_card: Dictionary = {}

var _scale: float = 1.0


func _ready() -> void:
	layer = 10
	add_to_group("hud")
	_scale = _compute_scale()
	_build_ui()
	visible = false
	_connect_wave_manager()
	get_viewport().size_changed.connect(_on_viewport_resized)


func set_dim(alpha: float) -> void:
	for child in get_children():
		if child is CanvasItem:
			child.modulate.a = alpha


func _compute_scale() -> float:
	return get_viewport().size.y / 1080.0


func _on_viewport_resized() -> void:
	_scale = _compute_scale()
	if _state_tween and _state_tween.is_valid():
		_state_tween.kill()
	_state_tween = null
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	_build_ui()
	if _health != null:
		_refresh_vitals()
	_refresh_wave_text()
	_apply_state_text()
	if _weapon_holder != null and is_instance_valid(_weapon_holder):
		_on_weapon_changed(_weapon_holder.active_weapon)


# Shorthand helpers — apply _scale to a pixel value or font size
func _s(v: float) -> float: return v * _scale
func _fs(v: int) -> int:    return maxi(8, int(v * _scale))


func bind_to_player(player: Node) -> void:
	var health := _find_health(player)
	if health == null:
		push_error("[HUD] Player has no HealthComponent in: ", player.name)
		return
	_health = health
	_refresh_vitals()
	_refresh_wave_text()
	visible = true
	if not health.damaged.is_connected(_on_damaged):
		health.damaged.connect(_on_damaged)
	if not health.healed.is_connected(_on_healed):
		health.healed.connect(_on_healed)
	var body := player.get_node_or_null("CharacterBody3D")
	if body:
		var holder := body.get_node_or_null("WeaponHolder") as WeaponHolder
		if holder:
			_bind_weapon_holder(holder)


func _find_health(node: Node) -> HealthComponent:
	if node is HealthComponent:
		return node
	for child in node.get_children():
		var found := _find_health(child)
		if found:
			return found
	return null


func _process(_delta: float) -> void:
	if _health != null and not _health.is_dead:
		_refresh_vitals()


# ============================================================
# VITALS
# ============================================================

func _refresh_vitals() -> void:
	if _health == null:
		return
	if not is_instance_valid(_shield_fill) or not is_instance_valid(_hp_fill):
		return
	var sp: float = clamp(_health.current_shield / _health.max_shield, 0.0, 1.0) if _health.max_shield > 0.0 else 0.0
	var hp: float = clamp(_health.current_hp    / _health.max_hp,     0.0, 1.0) if _health.max_hp     > 0.0 else 0.0
	_shield_fill.size.x = _shield_fill_max_w * sp
	_hp_fill.size.x     = _hp_fill_max_w * hp
	_shield_value.text  = "%d / %d" % [int(_health.current_shield), int(_health.max_shield)]
	_hp_value.text      = "%d / %d" % [int(_health.current_hp),     int(_health.max_hp)]


func _on_damaged(_amount: float, _hp: float, _shield: float) -> void: _refresh_vitals()
func _on_healed(_amount: float, _hp: float)                  -> void: _refresh_vitals()


# ============================================================
# WAVE + STATE
# ============================================================

func _connect_wave_manager() -> void:
	if WaveManager.wave_started.is_connected(_on_wave_started):
		return
	WaveManager.wave_started.connect(_on_wave_started)
	WaveManager.state_changed.connect(_on_wave_state_changed)


func _on_wave_started(_n: int, _t: int) -> void: _refresh_wave_text()


func _on_wave_state_changed(new_state: int) -> void:
	match new_state:
		WaveManager.State.EXPLORE:  _set_state(HudState.EXPLORE)
		WaveManager.State.SCOUTING: _set_state(HudState.SCOUTING)
		WaveManager.State.COMBAT:   _set_state(HudState.COMBAT)
		WaveManager.State.TECH:     _set_state(HudState.TECH)


func _refresh_wave_text() -> void:
	_wave_label.text = "WAVE %d" % max(WaveManager._current_wave, 1)


func _set_state(new_state: HudState) -> void:
	if new_state == _current_state:
		return
	_current_state = new_state
	if _state_tween and _state_tween.is_valid():
		_state_tween.kill()
	_state_tween = create_tween()
	_state_tween.tween_property(_state_label, "modulate:a", 0.0, STATE_FADE * 0.5)
	_state_tween.tween_callback(_apply_state_text)
	_state_tween.tween_property(_state_label, "modulate:a", 1.0, STATE_FADE * 0.5)


func _apply_state_text() -> void:
	var text:  String
	var color: Color
	match _current_state:
		HudState.COMBAT:   text = "COMBAT";   color = STATE_COLOR_COMBAT
		HudState.EXPLORE:  text = "EXPLORE";  color = STATE_COLOR_EXPLORE
		HudState.SCOUTING: text = "SCOUTING"; color = STATE_COLOR_SCOUTING
		HudState.TECH:     text = "TECH";     color = STATE_COLOR_TECH
		HudState.EXTRACT:  text = "EXTRACT";  color = STATE_COLOR_EXTRACT
		_:                 text = "COMBAT";   color = STATE_COLOR_COMBAT
	_state_label.text = text
	_state_label.add_theme_color_override("font_color", color)


# ============================================================
# UI CONSTRUCTION
# ============================================================

func _build_ui() -> void:
	_build_vitals()
	_build_wave_indicator()
	_build_weapon_panel()


func _build_vitals() -> void:
	var pw  := _s(PANEL_WIDTH)
	var sh  := _s(SHIELD_BAR_H)
	var hh  := _s(HP_BAR_H)
	var gap := _s(BAR_GAP)
	var bot := _s(BOTTOM_MARGIN)

	var root := VBoxContainer.new()
	root.name = "VitalsRoot"
	root.custom_minimum_size = Vector2(pw, 0.0)
	root.add_theme_constant_override("separation", int(gap))
	root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	root.position = Vector2(-pw / 2.0, -(sh + hh + gap + bot))
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var sr := _make_bar_row(sh, pw, SHIELD_COLOR, SHIELD_BG_COLOR, SHIELD_BORDER)
	root.add_child(sr.container)
	_shield_fill      = sr.fill
	_shield_value     = sr.value
	_shield_fill_max_w = sr.fill_max_w

	var hr := _make_bar_row(hh, pw, HP_COLOR, HP_BG_COLOR, HP_BORDER)
	root.add_child(hr.container)
	_hp_fill      = hr.fill
	_hp_value     = hr.value
	_hp_fill_max_w = hr.fill_max_w


func _make_bar_row(bar_h: float, panel_w: float, fill_col: Color, bg_col: Color, border_col: Color) -> Dictionary:
	var outer := Panel.new()
	outer.custom_minimum_size = Vector2(panel_w, bar_h)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var os := StyleBoxFlat.new()
	os.bg_color = Color(0, 0, 0, 0)
	os.border_color = border_col
	os.set_border_width_all(BORDER_W)
	os.set_corner_radius_all(0)
	outer.add_theme_stylebox_override("panel", os)

	var io := BORDER_W + OUTER_GAP
	var inner := Panel.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.position = Vector2(io, io)
	inner.size = Vector2(panel_w - io * 2, bar_h - io * 2)
	var is_ := StyleBoxFlat.new()
	is_.bg_color = bg_col
	is_.border_color = border_col
	is_.set_border_width_all(BORDER_W)
	is_.set_corner_radius_all(0)
	inner.add_theme_stylebox_override("panel", is_)
	outer.add_child(inner)

	var fill := ColorRect.new()
	fill.color = fill_col
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(BORDER_W, BORDER_W)
	var fill_max_w := inner.size.x - BORDER_W * 2
	fill.size = Vector2(fill_max_w, inner.size.y - BORDER_W * 2)
	inner.add_child(fill)

	var val := Label.new()
	val.text = "0 / 0"
	val.add_theme_font_override("font", FONT)
	val.add_theme_font_size_override("font_size", _fs(18))
	val.add_theme_color_override("font_color", VALUE_COLOR)
	val.add_theme_constant_override("outline_size", 3)
	val.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	val.set_anchors_preset(Control.PRESET_FULL_RECT)
	val.offset_left = 8
	val.offset_right = -10
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(val)

	return { "container": outer, "fill": fill, "value": val, "fill_max_w": fill_max_w }


func _build_wave_indicator() -> void:
	var row := HBoxContainer.new()
	row.name = "WaveIndicator"
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.position = Vector2(-_s(WAVE_RIGHT_MARGIN), _s(WAVE_TOP_MARGIN))
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.add_theme_constant_override("separation", _fs(8))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_wave_label = _make_wave_lbl("WAVE 1", WAVE_LABEL_COLOR)
	row.add_child(_wave_label)
	row.add_child(_make_wave_lbl("//", WAVE_SEPARATOR_COLOR))
	_state_label = _make_wave_lbl("COMBAT", STATE_COLOR_COMBAT)
	row.add_child(_state_label)


func _make_wave_lbl(text: String, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", _fs(22))
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# ============================================================
# WEAPON PANEL (bottom-right) — name + tag only, no ammo dots
# ============================================================

func _build_weapon_panel() -> void:
	var cw  := _s(CARD_WIDTH)
	var ah  := _s(CARD_ACTIVE_H)
	var sh  := _s(CARD_SEC_H)
	var gap := _s(CARD_GAP)
	var bot := _s(BOTTOM_MARGIN)
	var rm  := _s(CARD_R_MARGIN)

	var root := VBoxContainer.new()
	root.name = "WeaponPanel"
	root.custom_minimum_size = Vector2(cw, 0.0)
	root.add_theme_constant_override("separation", int(gap))
	root.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	root.position = Vector2(-(cw + rm), -(ah + gap + sh + bot))
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_secondary_card = _make_weapon_card(sh, cw, false)
	root.add_child(_secondary_card.panel)

	_active_card = _make_weapon_card(ah, cw, true)
	root.add_child(_active_card.panel)


func _make_weapon_card(card_h: float, card_w: float, is_active: bool) -> Dictionary:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(card_w, card_h)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.10, 0.92)
	style.border_color = Color(0.18, 0.14, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", style)

	# Left accent bar
	var accent := ColorRect.new()
	accent.color = WEAPON_ACCENT_ACTIVE if is_active else WEAPON_ACCENT_IDLE
	accent.size = Vector2(_s(3.0), card_h)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(accent)

	# Swap key badge on secondary card
	if not is_active:
		var badge := Label.new()
		badge.text = "Q"
		badge.add_theme_font_override("font", FONT)
		badge.add_theme_font_size_override("font_size", _fs(11))
		badge.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		badge.position = Vector2(_s(10.0), _s(5.0))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(badge)

	# Weapon name
	var name_lbl := Label.new()
	name_lbl.text = "—"
	name_lbl.add_theme_font_override("font", FONT)
	name_lbl.add_theme_font_size_override("font_size", _fs(20 if is_active else 16))
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0) if is_active else Color(0.5, 0.5, 0.6))
	name_lbl.position = Vector2(_s(10.0), _s(8.0 if is_active else 4.0))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_lbl)

	# Tag badge (weapon type, e.g. "AUTO", "PUMP")
	var tag_lbl := Label.new()
	tag_lbl.text = ""
	tag_lbl.add_theme_font_override("font", FONT)
	tag_lbl.add_theme_font_size_override("font_size", _fs(11))
	tag_lbl.add_theme_color_override("font_color", SHIELD_COLOR)
	tag_lbl.position = Vector2(_s(10.0), _s(32.0 if is_active else 24.0))
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tag_lbl)

	return { "panel": panel, "name": name_lbl, "tag": tag_lbl, "accent": accent }


func _bind_weapon_holder(holder: WeaponHolder) -> void:
	if _weapon_holder != null and is_instance_valid(_weapon_holder):
		if _weapon_holder.weapon_changed.is_connected(_on_weapon_changed):
			_weapon_holder.weapon_changed.disconnect(_on_weapon_changed)
	_weapon_holder = holder
	holder.weapon_changed.connect(_on_weapon_changed)
	_on_weapon_changed(holder.active_weapon)


func _on_weapon_changed(active: WeaponComponent) -> void:
	if active == null or _weapon_holder == null:
		return
	var inactive: WeaponComponent = _weapon_holder.slot_2 if _weapon_holder.active_slot == 1 else _weapon_holder.slot_1
	_refresh_weapon_card(_active_card, active, true)
	_refresh_weapon_card(_secondary_card, inactive, false)


func _refresh_weapon_card(card: Dictionary, weapon: WeaponComponent, is_active: bool) -> void:
	if weapon == null:
		card.name.text    = "—"
		card.tag.text     = ""
		card.accent.color = WEAPON_ACCENT_IDLE
		return
	card.name.text    = weapon.weapon_name if weapon.weapon_name != "" else "WEAPON"
	card.tag.text     = weapon.weapon_tag
	card.accent.color = WEAPON_ACCENT_ACTIVE if is_active else WEAPON_ACCENT_IDLE
