class_name AugmentPickUI
extends CanvasLayer
## Shown when a player interacts with an active tech terminal.
## Full-screen overlay. Three columns: WEAPON augments | PLAYER augments | AURA slot.
## Active weapon stats live-update in the AURA column footer.
## Code-driven — no @onready deps on the .tscn.

signal augment_chosen(augment: Augment)

const FONT := preload("res://assets/font/BebasNeue-Regular.ttf")

const C_OVERLAY  := Color(0.06, 0.035, 0.016, 0.93)
const C_CARD_BG  := Color("#120a04")
const C_BORDER   := Color("#b86a1c")
const C_ACCENT   := Color("#e89a35")
const C_DIM      := Color("#5a3520")
const C_SUBTLE   := Color("#7a4a28")
const C_TEXT_PRI := Color("#d4b890")
const C_TEXT_SEC := Color("#a6692f")
const C_FILL_BG  := Color("#200f05")

const MAX_WEAPON_CARDS:  int = 3
const MAX_AUGMENT_CARDS: int = 3
const MAX_AURA_CARDS:    int = 1
const ROLL_COUNT:        int = 30

var _target_player:  Node         = null
var _weapon_holder:  WeaponHolder = null
var _rolled_weapon:  Array[Augment] = []
var _rolled_augment: Array[Augment] = []
var _rolled_aura:    Array[Augment] = []

var _weapon_name_label: Label     = null
var _atk_fill:          ColorRect = null
var _mag_fill:          ColorRect = null
var _spd_fill:          ColorRect = null


static func open(player: Node) -> AugmentPickUI:
	var ui := AugmentPickUI.new()
	ui._target_player = player
	ui._weapon_holder = player.get_node_or_null("WeaponHolder") as WeaponHolder
	player.get_tree().current_scene.add_child(ui)
	return ui


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_roll_and_partition()
	_build_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	if _weapon_holder:
		_weapon_holder.weapon_changed.connect(_on_weapon_changed)
	await get_tree().process_frame
	_refresh_weapon_panel()


func _exit_tree() -> void:
	if is_instance_valid(_weapon_holder) and _weapon_holder.weapon_changed.is_connected(_on_weapon_changed):
		_weapon_holder.weapon_changed.disconnect(_on_weapon_changed)


# ── Partition ────────────────────────────────────────────────────────────────

func _roll_and_partition() -> void:
	var all: Array[Augment] = AugmentPool.roll(ROLL_COUNT)
	for aug in all:
		if aug.scope == Augment.Scope.AURA:
			if _rolled_aura.size() < MAX_AURA_CARDS:
				_rolled_aura.append(aug)
		elif aug.target == Augment.Target.ACTIVE_WEAPON:
			if _rolled_weapon.size() < MAX_WEAPON_CARDS:
				_rolled_weapon.append(aug)
		else:
			if _rolled_augment.size() < MAX_AUGMENT_CARDS:
				_rolled_augment.append(aug)


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = C_OVERLAY
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left",   52)
	root.add_theme_constant_override("margin_right",  52)
	root.add_theme_constant_override("margin_top",    36)
	root.add_theme_constant_override("margin_bottom", 36)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	root.add_child(vbox)

	_build_header(vbox)
	_add_spacer(vbox, 8)
	_add_hairline(vbox)
	_add_spacer(vbox, 18)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 0)
	vbox.add_child(cols)

	_build_column(cols, "WEAPON",  _rolled_weapon)
	_add_col_separator(cols)
	_build_column(cols, "AUGMENT", _rolled_augment)
	_add_col_separator(cols)
	_build_aura_column(cols)

	_add_spacer(vbox, 18)
	_add_hairline(vbox)
	_add_spacer(vbox, 10)
	_build_footer(vbox)


func _build_header(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	row.add_child(left)

	var title := Label.new()
	title.text = "DWRF // TECH"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", C_ACCENT)
	left.add_child(title)

	var sub := Label.new()
	sub.text = "AUGMENT TERMINAL"
	sub.add_theme_font_override("font", FONT)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", C_DIM)
	left.add_child(sub)

	var wave := Label.new()
	wave.text = "WAVE %02d" % max(WaveManager._current_wave, 1)
	wave.add_theme_font_override("font", FONT)
	wave.add_theme_font_size_override("font_size", 20)
	wave.add_theme_color_override("font_color", C_SUBTLE)
	wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	wave.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(wave)


func _build_footer(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)

	var left := Label.new()
	left.text = "DWARFCORE // TECH TERMINAL"
	left.add_theme_font_override("font", FONT)
	left.add_theme_font_size_override("font_size", 11)
	left.add_theme_color_override("font_color", C_DIM)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var right := Label.new()
	right.text = "[LMB]  SELECT AUGMENT"
	right.add_theme_font_override("font", FONT)
	right.add_theme_font_size_override("font_size", 11)
	right.add_theme_color_override("font_color", C_ACCENT)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(right)


func _build_column(parent: HBoxContainer, heading: String, augments: Array[Augment]) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)

	_add_col_header(col, heading)
	_add_spacer(col, 10)

	if augments.is_empty():
		_build_locked_card(col)
	else:
		for aug in augments:
			_build_card(col, aug)
			_add_spacer(col, 8)

	var fill_spacer := Control.new()
	fill_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill_spacer)


func _build_aura_column(parent: HBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)

	_add_col_header(col, "AURA")
	_add_spacer(col, 10)

	if _rolled_aura.is_empty():
		_build_locked_card(col)
	else:
		for aug in _rolled_aura:
			_build_card(col, aug)
			_add_spacer(col, 8)

	var fill_spacer := Control.new()
	fill_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill_spacer)

	_build_weapon_panel(col)


func _add_col_header(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", C_ACCENT)
	parent.add_child(lbl)
	_add_hairline(parent)


func _build_card(parent: Control, aug: Augment) -> void:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.clip_contents = false
	btn.add_theme_stylebox_override("normal",  _make_card_style(C_CARD_BG,          C_BORDER))
	btn.add_theme_stylebox_override("hover",   _make_card_style(Color("#1c0e06"),    C_ACCENT))
	btn.add_theme_stylebox_override("pressed", _make_card_style(Color("#2a1208"),    C_ACCENT))
	btn.add_theme_stylebox_override("focus",   _make_card_style(C_CARD_BG,          C_BORDER))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vbox)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = aug.display_name.to_upper()
	name_lbl.add_theme_font_override("font", FONT)
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", C_TEXT_PRI)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(name_lbl)

	var tag := Label.new()
	tag.text = aug.get_scope_label()
	tag.add_theme_font_override("font", FONT)
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", C_SUBTLE)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(tag)

	if aug.description_upside != "":
		var up := Label.new()
		up.text = "+  " + aug.description_upside
		up.add_theme_font_override("font", FONT)
		up.add_theme_font_size_override("font_size", 13)
		up.add_theme_color_override("font_color", C_TEXT_SEC)
		up.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		up.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(up)

	if aug.description_downside != "":
		var down := Label.new()
		down.text = "-  " + aug.description_downside
		down.add_theme_font_override("font", FONT)
		down.add_theme_font_size_override("font_size", 11)
		down.add_theme_color_override("font_color", C_DIM)
		down.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		down.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(down)

	btn.pressed.connect(_on_card_pressed.bind(aug))
	parent.add_child(btn)


func _make_card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(0)
	s.border_width_left = 3
	s.set_corner_radius_all(0)
	s.content_margin_left   = 14
	s.content_margin_right  = 12
	s.content_margin_top    = 10
	s.content_margin_bottom = 10
	return s


func _build_locked_card(parent: Control) -> void:
	var p := Panel.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 64)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("#0d0704")
	ps.border_color = C_DIM
	ps.set_border_width_all(0)
	ps.border_width_left = 2
	ps.set_corner_radius_all(0)
	p.add_theme_stylebox_override("panel", ps)

	var inner := MarginContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 14)
	inner.add_theme_constant_override("margin_top",  12)
	p.add_child(inner)

	var lbl := Label.new()
	lbl.text = "LOCKED"
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", C_DIM)
	inner.add_child(lbl)

	parent.add_child(p)


# ── Active weapon panel (AURA column footer) ──────────────────────────────────

func _build_weapon_panel(parent: Control) -> void:
	_add_hairline(parent)
	_add_spacer(parent, 10)

	var header := Label.new()
	header.text = "ACTIVE WEAPON"
	header.add_theme_font_override("font", FONT)
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", C_DIM)
	parent.add_child(header)

	_add_spacer(parent, 3)

	_weapon_name_label = Label.new()
	_weapon_name_label.add_theme_font_override("font", FONT)
	_weapon_name_label.add_theme_font_size_override("font_size", 24)
	_weapon_name_label.add_theme_color_override("font_color", C_ACCENT)
	parent.add_child(_weapon_name_label)

	_add_spacer(parent, 8)

	_atk_fill = _add_mini_bar(parent, "ATK")
	_add_spacer(parent, 4)
	_mag_fill = _add_mini_bar(parent, "MAG")
	_add_spacer(parent, 4)
	_spd_fill = _add_mini_bar(parent, "SPD")
	_add_spacer(parent, 8)


func _add_mini_bar(parent: Control, label_text: String) -> ColorRect:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_SUBTLE)
	lbl.custom_minimum_size.x = 30
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var outer := Panel.new()
	outer.custom_minimum_size = Vector2(0, 5)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bos := StyleBoxFlat.new()
	bos.bg_color = C_FILL_BG
	bos.border_color = C_SUBTLE
	bos.set_border_width_all(1)
	bos.set_corner_radius_all(0)
	outer.add_theme_stylebox_override("panel", bos)
	row.add_child(outer)

	var fill := ColorRect.new()
	fill.color = C_ACCENT
	fill.position = Vector2(1, 1)
	fill.size = Vector2(0, 3)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(fill)

	return fill


func _on_weapon_changed(_w: WeaponComponent) -> void:
	_refresh_weapon_panel()


func _refresh_weapon_panel() -> void:
	if not is_instance_valid(_weapon_name_label):
		return

	var weapon: WeaponComponent = _weapon_holder.active_weapon if _weapon_holder else null
	if weapon == null:
		_weapon_name_label.text = "NO WEAPON"
		return

	_weapon_name_label.text = (weapon.weapon_name if weapon.weapon_name != "" else weapon.name).to_upper()
	_set_bar(_atk_fill, clampf(weapon.projectile_damage / 50.0, 0.0, 1.0))
	_set_bar(_mag_fill, clampf(float(weapon.magazine_size)  / 60.0, 0.0, 1.0))
	_set_bar(_spd_fill, clampf(weapon.fire_rate             / 15.0, 0.0, 1.0))


func _set_bar(fill: ColorRect, t: float) -> void:
	if not is_instance_valid(fill):
		return
	var outer := fill.get_parent() as Panel
	if outer == null:
		return
	var max_w := maxf(outer.size.x - 2.0, 0.0)
	fill.size.x = max_w * t


# ── Interaction ───────────────────────────────────────────────────────────────

func _on_card_pressed(augment: Augment) -> void:
	var active_weapon: WeaponComponent = _weapon_holder.active_weapon if _weapon_holder else null
	augment.apply(_target_player, active_weapon)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	augment_chosen.emit(augment)
	queue_free()


# ── Layout helpers ────────────────────────────────────────────────────────────

func _add_spacer(parent: Control, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)


func _add_hairline(parent: Control) -> void:
	var line := ColorRect.new()
	line.color = C_BORDER
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(line)


func _add_col_separator(parent: HBoxContainer) -> void:
	var sp1 := Control.new()
	sp1.custom_minimum_size = Vector2(16, 0)
	parent.add_child(sp1)

	var line := ColorRect.new()
	line.color = C_DIM
	line.custom_minimum_size = Vector2(1, 0)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(line)

	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(16, 0)
	parent.add_child(sp2)
