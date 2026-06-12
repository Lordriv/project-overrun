extends CanvasLayer

const LOBBY_SCENE_PATH := "res://scenes/levels/Lobby.tscn"
const BEBAS_FONT := preload("res://assets/font/BebasNeue-Regular.ttf")

const C_BG        := Color("#1a0f08")
const C_SECOND_BG := Color("#160c05")
const C_BORDER    := Color("#b86a1c")
const C_ACCENT    := Color("#e89a35")
const C_SUBTLE    := Color("#7a4a28")
const C_DIM       := Color("#5a3520")
const C_TEXT_SEC  := Color("#a6692f")
const C_DANGER    := Color("#c44a2f")
const C_DANGER_BD := Color("#8c2e1f")

const PAUSE_PANEL_L   := 32.0
const PAUSE_PANEL_R   := 472.0
const PAUSE_PANEL_HALF := 280.0
const SECOND_PANEL_W  := 380.0

const CATEGORIES := ["AUDIO", "VIDEO", "KEYBINDS", "FRIENDS", "HELP"]

var _is_open: bool = false
var _active_category: String = ""
var _second_panel: Panel      = null
var _settings_content: SettingsPanel = null
var _category_btns: Dictionary = {}

var _confirm_dialog: ConfirmationDialog
var _kick_dialog: ConfirmationDialog
var _pending_kick_target: String = ""


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_connect_squad_hud()
	hide()


func _connect_squad_hud() -> void:
	if SquadHUD:
		if not SquadHUD.leave_session_requested.is_connected(_show_leave_confirm):
			SquadHUD.leave_session_requested.connect(_show_leave_confirm)
		if not SquadHUD.kick_player_requested.is_connected(_show_kick_confirm):
			SquadHUD.kick_player_requested.connect(_show_kick_confirm)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo):
		return
	var kc: Key = (event as InputEventKey).physical_keycode

	# Let settings_panel consume events during keybind capture
	if _settings_content and is_instance_valid(_settings_content) and _settings_content.is_capturing():
		return

	match kc:
		KEY_ESCAPE:
			if _second_panel.visible:
				_close_category()
				get_viewport().set_input_as_handled()
			elif _is_open:
				close_menu()
				get_viewport().set_input_as_handled()
			else:
				open_menu()
				get_viewport().set_input_as_handled()
		KEY_R:
			if _second_panel.visible:
				_reset_current_category()
				get_viewport().set_input_as_handled()
		KEY_LEFT, KEY_BACKSPACE:
			if _second_panel.visible:
				_close_category()
				get_viewport().set_input_as_handled()


func open_menu() -> void:
	_is_open = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.call("set_dim", 0.4)
	if SquadHUD:
		SquadHUD.set_interactive(true)
	show()


func close_menu() -> void:
	_close_category()
	_is_open = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	for hud in get_tree().get_nodes_in_group("hud"):
		hud.call("set_dim", 1.0)
	if SquadHUD:
		SquadHUD.set_interactive(false)
	hide()


func _open_category(cat: String) -> void:
	if _active_category == cat:
		_close_category()
		return

	_active_category = cat
	_refresh_category_btn_styles()

	# Replace content
	if _settings_content and is_instance_valid(_settings_content):
		_settings_content.queue_free()
		_settings_content = null

	_settings_content = SettingsPanel.new()
	_settings_content.init(cat)
	_settings_content.close_requested.connect(_close_category)
	_second_panel.get_node("Content").add_child(_settings_content)
	_second_panel.show()


func _close_category() -> void:
	_active_category = ""
	_refresh_category_btn_styles()
	if _settings_content and is_instance_valid(_settings_content):
		_settings_content.queue_free()
		_settings_content = null
	_second_panel.hide()


func _reset_current_category() -> void:
	if _settings_content and is_instance_valid(_settings_content):
		_settings_content.reset_to_defaults()


func _refresh_category_btn_styles() -> void:
	for cat in _category_btns:
		_style_category_btn(_category_btns[cat] as Button, cat == _active_category)


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
	vec3 left  = vec3(0.102, 0.059, 0.031);
	vec3 mid   = vec3(0.16,  0.09,  0.04);
	vec3 right = vec3(0.02,  0.01,  0.005);
	float x = UV.x;
	vec3 col = mix(left, mid, smoothstep(0.0, 0.45, x));
	col = mix(col, right, smoothstep(0.35, 1.0, x));
	COLOR = vec4(col, 0.88);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	bg.material = mat
	add_child(bg)

	_build_pause_panel()
	_build_second_panel()


func _build_pause_panel() -> void:
	var panel := Panel.new()
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.anchor_left   = 0.0
	panel.anchor_right  = 0.0
	panel.offset_top    = -PAUSE_PANEL_HALF
	panel.offset_bottom =  PAUSE_PANEL_HALF
	panel.offset_left   = PAUSE_PANEL_L
	panel.offset_right  = PAUSE_PANEL_R
	var ps := StyleBoxFlat.new()
	ps.bg_color = C_BG
	ps.border_color = C_BORDER
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(0)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left   =  22.0
	vbox.offset_right  = -22.0
	vbox.offset_top    =  20.0
	vbox.offset_bottom = -20.0
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	var header := Label.new()
	header.text = "PAUSED"
	header.add_theme_font_override("font", BEBAS_FONT)
	header.add_theme_font_size_override("font_size", 52)
	header.add_theme_color_override("font_color", C_ACCENT)
	vbox.add_child(header)

	_add_spacer(vbox, 12)

	var hrule := ColorRect.new()
	hrule.color = C_BORDER
	hrule.custom_minimum_size = Vector2(0, 1)
	hrule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hrule)

	_add_spacer(vbox, 10)

	var subline := Label.new()
	subline.text = "WAVE %d // COMBAT" % max(WaveManager._current_wave, 1)
	subline.add_theme_font_override("font", BEBAS_FONT)
	subline.add_theme_font_size_override("font_size", 13)
	subline.add_theme_color_override("font_color", C_TEXT_SEC)
	vbox.add_child(subline)

	_add_spacer(vbox, 16)

	var btn_stack := VBoxContainer.new()
	btn_stack.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_stack)

	_add_primary_btn(btn_stack, "RESUME", C_ACCENT, C_BORDER, close_menu)

	_add_spacer(btn_stack, 4)

	for cat in CATEGORIES:
		var btn := _build_category_btn(cat)
		_category_btns[cat] = btn
		btn_stack.add_child(btn)

	var expand := Control.new()
	expand.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(expand)

	_add_primary_btn(vbox, "ABANDON RUN", C_DANGER, C_DANGER_BD, _on_abandon)

	_add_spacer(vbox, 10)

	var footer := HBoxContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(footer)

	var fl := Label.new()
	fl.text = "DWARFCORE"
	fl.add_theme_font_override("font", BEBAS_FONT)
	fl.add_theme_font_size_override("font_size", 10)
	fl.add_theme_color_override("font_color", C_DIM)
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(fl)

	var fr := Label.new()
	fr.text = "[LMB] SELECT   [ESC] RESUME"
	fr.add_theme_font_override("font", BEBAS_FONT)
	fr.add_theme_font_size_override("font_size", 10)
	fr.add_theme_color_override("font_color", C_SUBTLE)
	fr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(fr)


func _build_second_panel() -> void:
	_second_panel = Panel.new()
	_second_panel.anchor_top    = 0.5
	_second_panel.anchor_bottom = 0.5
	_second_panel.anchor_left   = 0.0
	_second_panel.anchor_right  = 0.0
	_second_panel.offset_top    = -PAUSE_PANEL_HALF
	_second_panel.offset_bottom =  PAUSE_PANEL_HALF
	_second_panel.offset_left   = PAUSE_PANEL_R - 2.0   # overlap border seam by 2px
	_second_panel.offset_right  = PAUSE_PANEL_R - 2.0 + SECOND_PANEL_W

	var ps := StyleBoxFlat.new()
	ps.bg_color     = C_SECOND_BG
	ps.border_color = C_BORDER
	ps.set_border_width_all(2)
	ps.border_width_left = 0   # shared with pause panel's right border
	ps.set_corner_radius_all(0)
	_second_panel.add_theme_stylebox_override("panel", ps)

	# Named anchor for SettingsPanel to attach into
	var content := Control.new()
	content.name = "Content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_second_panel.add_child(content)

	add_child(_second_panel)
	_second_panel.hide()


func _build_category_btn(cat: String) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_contents = false
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Inner layout: label (expand) + arrow
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 0)
	btn.add_child(hbox)

	var name_lbl := Label.new()
	name_lbl.text = cat
	name_lbl.add_theme_font_override("font", BEBAS_FONT)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	var arrow_lbl := Label.new()
	arrow_lbl.name = "Arrow"
	arrow_lbl.text = "›"
	arrow_lbl.add_theme_font_override("font", BEBAS_FONT)
	arrow_lbl.add_theme_font_size_override("font_size", 18)
	arrow_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(arrow_lbl)

	# Left margin for inner hbox
	hbox.offset_left = 12.0
	hbox.offset_right = -8.0

	_style_category_btn(btn, false)
	btn.pressed.connect(_open_category.bind(cat))
	return btn


func _style_category_btn(btn: Button, active: bool) -> void:
	var name_lbl := btn.get_child(0).get_child(0) as Label
	var arrow_lbl := btn.get_child(0).get_node("Arrow") as Label

	if active:
		var s := StyleBoxFlat.new()
		s.bg_color     = Color("#2a1810")
		s.border_color = C_ACCENT
		s.set_border_width_all(1)
		s.set_corner_radius_all(0)
		s.content_margin_left = 0.0
		btn.add_theme_stylebox_override("normal",  s)
		btn.add_theme_stylebox_override("hover",   s)
		btn.add_theme_stylebox_override("pressed", s)
		btn.add_theme_stylebox_override("focus",   s)
		if name_lbl:  name_lbl.add_theme_color_override("font_color", C_ACCENT)
		if arrow_lbl: arrow_lbl.add_theme_color_override("font_color", C_ACCENT)
	else:
		var ns := StyleBoxFlat.new()
		ns.bg_color     = Color(0, 0, 0, 0)
		ns.border_color = C_DIM
		ns.set_border_width_all(1)
		ns.set_corner_radius_all(0)
		ns.content_margin_left = 0.0
		btn.add_theme_stylebox_override("normal", ns)

		var hs := StyleBoxFlat.new()
		hs.bg_color     = Color(C_DIM.r, C_DIM.g, C_DIM.b, 0.2)
		hs.border_color = C_SUBTLE
		hs.set_border_width_all(1)
		hs.set_corner_radius_all(0)
		hs.content_margin_left = 0.0
		btn.add_theme_stylebox_override("hover",   hs)
		btn.add_theme_stylebox_override("pressed", hs)
		btn.add_theme_stylebox_override("focus",   ns)
		if name_lbl:  name_lbl.add_theme_color_override("font_color", C_TEXT_SEC)
		if arrow_lbl: arrow_lbl.add_theme_color_override("font_color", C_DIM)


func _add_spacer(parent: Control, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)


func _add_primary_btn(parent: VBoxContainer, label: String, accent: Color, border: Color, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_override("font", BEBAS_FONT)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color",         Color("#e8ddd0"))
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var ns := StyleBoxFlat.new()
	ns.bg_color    = Color(accent.r, accent.g, accent.b, 0.12)
	ns.border_color = border
	ns.set_border_width_all(1)
	ns.set_corner_radius_all(0)
	ns.content_margin_left = 12.0
	btn.add_theme_stylebox_override("normal", ns)

	var hs := StyleBoxFlat.new()
	hs.bg_color    = Color(accent.r, accent.g, accent.b, 0.28)
	hs.border_color = accent
	hs.set_border_width_all(1)
	hs.set_corner_radius_all(0)
	hs.content_margin_left = 12.0
	btn.add_theme_stylebox_override("hover",   hs)
	btn.add_theme_stylebox_override("pressed", hs)

	btn.pressed.connect(callback)
	parent.add_child(btn)


# ── Actions ──────────────────────────────────────────────────────────────────

func _on_abandon() -> void:
	close_menu()
	await get_tree().process_frame
	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)


# ── Squad HUD leave / kick dialogs ───────────────────────────────────────────

func _show_leave_confirm() -> void:
	if not _confirm_dialog:
		_confirm_dialog = ConfirmationDialog.new()
		_confirm_dialog.title = "Leave Session?"
		_confirm_dialog.ok_button_text = "Leave"
		_confirm_dialog.cancel_button_text = "Stay"
		_confirm_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
		_confirm_dialog.confirmed.connect(_on_leave_confirmed)
		add_child(_confirm_dialog)
	if SessionManager.is_host and SessionManager.session_players.size() > 1:
		_confirm_dialog.dialog_text = "You are the HOST. Leaving will end the session for all players.\n\nAre you sure?"
	else:
		_confirm_dialog.dialog_text = "Leave the current session and return to the lobby?\n\nAre you sure?"
	_confirm_dialog.popup_centered()


func _on_leave_confirmed() -> void:
	close_menu()
	await SessionManager.leave_session()
	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)


func _show_kick_confirm(target_player_id: String) -> void:
	_pending_kick_target = target_player_id
	var username := "this player"
	if SessionManager.session_players.has(target_player_id):
		username = SessionManager.session_players[target_player_id].get("username", "this player")
	if not _kick_dialog:
		_kick_dialog = ConfirmationDialog.new()
		_kick_dialog.title = "Kick Player?"
		_kick_dialog.ok_button_text = "Kick"
		_kick_dialog.cancel_button_text = "Cancel"
		_kick_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
		_kick_dialog.confirmed.connect(_on_kick_confirmed)
		add_child(_kick_dialog)
	_kick_dialog.dialog_text = "Kick %s from the session?" % username
	_kick_dialog.popup_centered()


func _on_kick_confirmed() -> void:
	if _pending_kick_target.is_empty():
		return
	var target := _pending_kick_target
	_pending_kick_target = ""
	await SessionManager.kick_player(target)
