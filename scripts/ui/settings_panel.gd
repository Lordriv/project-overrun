class_name SettingsPanel
extends Control

signal close_requested()

const FONT := preload("res://assets/font/BebasNeue-Regular.ttf")

const C_BG        := Color("#160c05")
const C_BORDER    := Color("#b86a1c")
const C_ACCENT    := Color("#e89a35")
const C_SUBTLE    := Color("#7a4a28")
const C_DIM       := Color("#5a3520")
const C_ROW_LABEL := Color("#a6692f")

const LABEL_W := 140

const CATEGORY_TAGS := {
	"AUDIO":    "DWARFCORE.SND",
	"VIDEO":    "DWARFCORE.GFX",
	"KEYBINDS": "DWARFCORE.BIND",
	"FRIENDS":  "DWARFCORE.NET",
	"HELP":     "DWARFCORE.MAN",
}

const BIND_ACTIONS := [
	["MOVE",         ""],
	["FIRE",         "attack1"],
	["ADS",          "ads"],
	["RELOAD",       "reload"],
	["INTERACT",     "interact"],
	["SPRINT",       "sprint"],
	["DASH",         "dash"],
	["SWAP WEAPON",  "weapon_swap"],
	["SLOT 1",       "weapon_slot_1"],
	["SLOT 2",       "weapon_slot_2"],
	["SLOT 3",       "weapon_slot_3"],
]

var _category: String
var _rows: VBoxContainer
var _capture_action: String = ""
var _capture_btn: Button    = null


func init(category: String) -> SettingsPanel:
	_category = category
	return self


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",  18)
	margin.add_theme_constant_override("margin_right", 18)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	_add_spacer(vbox, 22)
	_build_header(vbox)
	_add_hairline(vbox)
	_add_spacer(vbox, 10)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 0)
	scroll.add_child(_rows)

	_build_rows()

	_add_spacer(vbox, 10)
	_add_hairline(vbox)
	_build_footer(vbox)
	_add_spacer(vbox, 22)


func _build_header(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = _category
	name_lbl.add_theme_font_override("font", FONT)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", C_ACCENT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var tag_lbl := Label.new()
	tag_lbl.text = "[ %s ]" % CATEGORY_TAGS.get(_category, "")
	tag_lbl.add_theme_font_override("font", FONT)
	tag_lbl.add_theme_font_size_override("font_size", 10)
	tag_lbl.add_theme_color_override("font_color", C_DIM)
	tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	tag_lbl.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(tag_lbl)

	_add_spacer(parent, 6)


func _build_footer(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var back_btn := Button.new()
	back_btn.text = "← BACK"
	back_btn.flat = true
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.add_theme_font_override("font", FONT)
	back_btn.add_theme_font_size_override("font_size", 10)
	back_btn.add_theme_color_override("font_color", C_SUBTLE)
	back_btn.add_theme_color_override("font_hover_color", C_ACCENT)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.pressed.connect(close_requested.emit)
	row.add_child(back_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var reset_btn := Button.new()
	reset_btn.text = "[R] RESET DEFAULTS"
	reset_btn.flat = true
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.add_theme_font_override("font", FONT)
	reset_btn.add_theme_font_size_override("font_size", 10)
	reset_btn.add_theme_color_override("font_color", C_SUBTLE)
	reset_btn.add_theme_color_override("font_hover_color", C_ACCENT)
	reset_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reset_btn.pressed.connect(reset_to_defaults)
	row.add_child(reset_btn)

	_add_spacer(parent, 4)


func _build_rows() -> void:
	match _category:
		"AUDIO":    _build_audio()
		"VIDEO":    _build_video()
		"KEYBINDS": _build_keybinds()
		"FRIENDS":  _build_friends()
		"HELP":     _build_help()


func _build_audio() -> void:
	_make_slider("MASTER VOLUME", "audio/master_volume", 0, 100)
	_make_slider("MUSIC",         "audio/music_volume",  0, 100)
	_make_slider("SFX",           "audio/sfx_volume",    0, 100)
	_make_slider("VEGA / VOICE",  "audio/voice_volume",  0, 100)

	var devices := ["Default"] + Array(AudioServer.get_output_device_list())
	_make_dropdown("OUTPUT DEVICE", "audio/output_device", devices, devices)
	_make_toggle("SUBTITLES", "audio/subtitles")


func _build_video() -> void:
	_make_dropdown("DISPLAY MODE",   "video/display_mode",
		["Fullscreen", "Borderless", "Windowed"],
		["Fullscreen", "Borderless", "Windowed"])

	var screen_sz := DisplayServer.screen_get_size()
	var all_res   := [Vector2i(3840,2160), Vector2i(2560,1440), Vector2i(1920,1080),
					  Vector2i(1600,900),  Vector2i(1280,720),  Vector2i(1024,768)]
	var valid_res : Array[String] = []
	for r in all_res:
		if r.x <= screen_sz.x and r.y <= screen_sz.y:
			valid_res.append("%dx%d" % [r.x, r.y])
	if valid_res.is_empty():
		valid_res.append("%dx%d" % [screen_sz.x, screen_sz.y])
	_make_dropdown("RESOLUTION", "video/resolution", valid_res, valid_res)

	_make_dropdown("QUALITY PRESET", "video/quality_preset",
		["Low", "Medium", "High", "Ultra"],
		["Low", "Medium", "High", "Ultra"])

	_make_toggle("VSYNC", "video/vsync")

	_make_dropdown("FRAME LIMIT", "video/frame_limit",
		["60", "120", "144", "Unlimited"],
		[60,   120,   144,   0])

	_make_slider("FIELD OF VIEW",      "video/fov",              60, 120)
	_make_slider("MOUSE SENSITIVITY", "video/mouse_sensitivity",  1,  20)
	_make_slider("SCREEN SHAKE",      "video/screen_shake",       0, 100)


func _build_keybinds() -> void:
	for entry in BIND_ACTIONS:
		var label: String  = entry[0]
		var action: String = entry[1]
		if action == "":
			_make_static_bind_row(label, "WASD / ARROWS")
		else:
			_make_bind_row(label, action)


func _build_friends() -> void:
	_add_spacer(_rows, 24)
	var lbl := Label.new()
	lbl.text = "NO CONNECTION"
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", C_DIM)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(lbl)
	var sub := Label.new()
	sub.text = "MULTIPLAYER FRIEND LIST — COMING SOON"
	sub.add_theme_font_override("font", FONT)
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", C_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_child(sub)


func _build_help() -> void:
	const LINES := [
		["CONTROLS", ""],
		["MOVE",       "WASD"],
		["SPRINT",     "SHIFT + WASD"],
		["DASH",       "C"],
		["FIRE",       "LMB"],
		["ADS",        "RMB"],
		["RELOAD",     "R"],
		["SWAP WEAPON","Q"],
		["INTERACT",   "E"],
		["PAUSE",      "ESC"],
		["", ""],
		["WAVE LOOP", ""],
		["EXPLORE",    "ROAM — FIND THE SCOUTING TRIGGER"],
		["SCOUTING",   "SCOUTS ACTIVE — STAY SUPPRESSED"],
		["COMBAT",     "ELIMINATE ALL ENEMIES"],
		["TECH",       "INTERACT WITH TERMINAL FOR AUGMENT"],
		["", ""],
		["TERMINAL", ""],
		["ACTIVATE",   "LOOK AT TERMINAL + E"],
		["PICK AUGMENT","LMB ON CARD TO SELECT"],
	]
	_add_spacer(_rows, 8)
	for pair in LINES:
		var k: String = pair[0]
		var v: String = pair[1]
		if k == "" and v == "":
			_add_spacer(_rows, 8)
			continue
		if v == "":
			var header := Label.new()
			header.text = k
			header.add_theme_font_override("font", FONT)
			header.add_theme_font_size_override("font_size", 13)
			header.add_theme_color_override("font_color", C_ACCENT)
			_rows.add_child(header)
			_add_hairline(_rows)
			_add_spacer(_rows, 4)
		else:
			var row := HBoxContainer.new()
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_rows.add_child(row)
			var lk := Label.new()
			lk.text = k
			lk.add_theme_font_override("font", FONT)
			lk.add_theme_font_size_override("font_size", 12)
			lk.add_theme_color_override("font_color", C_ROW_LABEL)
			lk.custom_minimum_size.x = LABEL_W
			row.add_child(lk)
			var lv := Label.new()
			lv.text = v
			lv.add_theme_font_override("font", FONT)
			lv.add_theme_font_size_override("font_size", 12)
			lv.add_theme_color_override("font_color", C_ACCENT)
			row.add_child(lv)
			_add_spacer(_rows, 4)


# ── Widget builders ──────────────────────────────────────────────────────────

func _make_slider(label: String, key: String, min_v: float, max_v: float) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	_rows.add_child(row)

	var lbl := _row_label(label)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step      = 1.0
	slider.value     = float(SettingsManager.get_value(key))
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 20

	var track := StyleBoxFlat.new()
	track.bg_color = Color("#2a1810")
	track.border_color = Color("#5a3520")
	track.set_border_width_all(1)
	track.content_margin_top    = 1.5
	track.content_margin_bottom = 1.5
	slider.add_theme_stylebox_override("slider", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = C_ACCENT
	fill.set_border_width_all(0)
	fill.content_margin_top    = 1.5
	fill.content_margin_bottom = 1.5
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)

	var thumb_img := Image.create(8, 12, false, Image.FORMAT_RGBA8)
	thumb_img.fill(C_ACCENT)
	var thumb_tex := ImageTexture.create_from_image(thumb_img)
	slider.add_theme_icon_override("grabber",           thumb_tex)
	slider.add_theme_icon_override("grabber_highlight", thumb_tex)
	slider.add_theme_icon_override("grabber_disabled",  thumb_tex)

	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.add_theme_font_override("font", FONT)
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", C_ACCENT)
	val_lbl.custom_minimum_size.x = 32
	val_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.text = str(int(slider.value))
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = str(int(v))
		SettingsManager.set_value(key, int(v))
	)

	_add_spacer(_rows, 10)


func _make_toggle(label: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	_rows.add_child(row)

	var lbl := _row_label(label)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var state := [bool(SettingsManager.get_value(key))]

	var on_btn  := _toggle_half("ON")
	var off_btn := _toggle_half("OFF")
	row.add_child(on_btn)
	row.add_child(off_btn)

	var refresh := func() -> void:
		_style_toggle_half(on_btn,  state[0])
		_style_toggle_half(off_btn, not state[0])

	refresh.call()

	on_btn.pressed.connect(func() -> void:
		if not state[0]:
			state[0] = true
			SettingsManager.set_value(key, true)
			refresh.call()
	)
	off_btn.pressed.connect(func() -> void:
		if state[0]:
			state[0] = false
			SettingsManager.set_value(key, false)
			refresh.call()
	)

	_add_spacer(_rows, 10)


func _toggle_half(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(46, 26)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 13)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return btn


func _style_toggle_half(btn: Button, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(0)
	s.set_border_width_all(1)
	if active:
		s.bg_color     = C_ACCENT
		s.border_color = C_ACCENT
		btn.add_theme_color_override("font_color",         Color("#1a0f08"))
		btn.add_theme_color_override("font_hover_color",   Color("#1a0f08"))
		btn.add_theme_color_override("font_pressed_color", Color("#1a0f08"))
	else:
		s.bg_color     = Color("#1a0f08")
		s.border_color = C_DIM
		btn.add_theme_color_override("font_color",         C_DIM)
		btn.add_theme_color_override("font_hover_color",   C_ROW_LABEL)
		btn.add_theme_color_override("font_pressed_color", C_ROW_LABEL)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus",   s)


func _make_dropdown(label: String, key: String, display_opts: Array, stored_vals: Array) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	_rows.add_child(row)

	var lbl := _row_label(label)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	opt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	opt.add_theme_font_override("font", FONT)
	opt.add_theme_font_size_override("font_size", 13)
	opt.add_theme_color_override("font_color", C_ACCENT)

	var ns := StyleBoxFlat.new()
	ns.bg_color    = Color("#1a0f08")
	ns.border_color = C_DIM
	ns.set_border_width_all(1)
	ns.set_corner_radius_all(0)
	ns.content_margin_left  = 8.0
	ns.content_margin_right = 8.0
	ns.content_margin_top    = 4.0
	ns.content_margin_bottom = 4.0
	opt.add_theme_stylebox_override("normal",  ns)
	opt.add_theme_stylebox_override("focus",   ns)

	var hs := ns.duplicate() as StyleBoxFlat
	hs.bg_color     = Color("#2a1810")
	hs.border_color = C_ACCENT
	opt.add_theme_stylebox_override("hover",   hs)
	opt.add_theme_stylebox_override("pressed", hs)

	var current_val: Variant = SettingsManager.get_value(key)
	var selected_idx := 0
	for i in stored_vals.size():
		opt.add_item(str(display_opts[i]))
		if str(stored_vals[i]) == str(current_val):
			selected_idx = i
	opt.select(selected_idx)

	opt.item_selected.connect(func(idx: int) -> void:
		SettingsManager.set_value(key, stored_vals[idx])
	)

	row.add_child(opt)
	_add_spacer(_rows, 10)


func _make_bind_row(label: String, action: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	_rows.add_child(row)

	var lbl := _row_label(label)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var btn := Button.new()
	btn.text = SettingsManager.get_keybind_display(action)
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", C_ACCENT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.custom_minimum_size = Vector2(80, 26)

	var ns := StyleBoxFlat.new()
	ns.bg_color     = Color("#1a0f08")
	ns.border_color = C_DIM
	ns.set_border_width_all(1)
	ns.set_corner_radius_all(0)
	ns.content_margin_left  = 8.0
	ns.content_margin_right = 8.0
	btn.add_theme_stylebox_override("normal", ns)

	var hs := ns.duplicate() as StyleBoxFlat
	hs.bg_color     = Color("#2a1810")
	hs.border_color = C_ACCENT
	btn.add_theme_stylebox_override("hover",   hs)
	btn.add_theme_stylebox_override("pressed", hs)
	btn.add_theme_stylebox_override("focus",   ns)

	btn.pressed.connect(func() -> void:
		_start_capture(action, btn)
	)
	row.add_child(btn)
	_add_spacer(_rows, 8)


func _make_static_bind_row(label: String, display: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	_rows.add_child(row)

	var lbl := _row_label(label)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var val := Label.new()
	val.text = display
	val.add_theme_font_override("font", FONT)
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", C_DIM)
	val.custom_minimum_size.x = 80
	val.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)

	_add_spacer(_rows, 8)


# ── Keybind capture ──────────────────────────────────────────────────────────

func is_capturing() -> bool:
	return _capture_action != ""


func _start_capture(action: String, btn: Button) -> void:
	if _capture_action != "":
		_cancel_capture()
	_capture_action = action
	_capture_btn    = btn
	btn.text = "PRESS A KEY..."
	btn.add_theme_color_override("font_color", C_SUBTLE)


func _cancel_capture() -> void:
	if is_instance_valid(_capture_btn):
		_capture_btn.text = SettingsManager.get_keybind_display(_capture_action)
		_capture_btn.add_theme_color_override("font_color", C_ACCENT)
	_capture_action = ""
	_capture_btn    = null


func _finish_capture(event: InputEvent) -> void:
	var action := _capture_action
	var btn    := _capture_btn
	_capture_action = ""
	_capture_btn    = null
	SettingsManager.save_keybind(action, event)
	if is_instance_valid(btn):
		btn.text = SettingsManager.get_keybind_display(action)
		btn.add_theme_color_override("font_color", C_ACCENT)


func _input(event: InputEvent) -> void:
	if _capture_action.is_empty():
		return
	if event is InputEventKey:
		if not (event as InputEventKey).pressed or (event as InputEventKey).echo:
			return
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			_cancel_capture()
		else:
			_finish_capture(event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_finish_capture(event)
		get_viewport().set_input_as_handled()


# ── Reset ────────────────────────────────────────────────────────────────────

func reset_to_defaults() -> void:
	if _capture_action != "":
		_cancel_capture()
	SettingsManager.reset_category(_category.to_lower())
	for child in _rows.get_children():
		child.free()
	_build_rows()


# ── Layout helpers ───────────────────────────────────────────────────────────

func _row_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_ROW_LABEL)
	lbl.custom_minimum_size.x = LABEL_W
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl


func _add_spacer(parent: Control, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)


func _add_hairline(parent: Control) -> void:
	var line := ColorRect.new()
	line.color = C_DIM
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(line)
