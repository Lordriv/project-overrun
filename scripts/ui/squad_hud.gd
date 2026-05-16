extends CanvasLayer

const MAX_PLAYERS = 4
const SLOT_SIZE = Vector2(72, 72)
const SLOT_SPACING = 8

var slot_nodes: Array = []
var slot_player_ids: Array = []
var is_interactive: bool = false

signal leave_session_requested()
signal kick_player_requested(player_id: String)

func _ready():
	layer = 10
	_build_ui()
	
	for i in range(MAX_PLAYERS):
		slot_player_ids.append("")
	
	# Hidden by default — only visible when a scene tells us to show
	visible = false
	set_interactive(false)
	
	await get_tree().process_frame
	if SessionManager:
		if not SessionManager.players_updated.is_connected(_on_players_updated):
			SessionManager.players_updated.connect(_on_players_updated)
		if not SessionManager.session_left.is_connected(_on_session_left):
			SessionManager.session_left.connect(_on_session_left)

func show_hud():
	visible = true

func hide_hud():
	visible = false

func _on_session_left():
	visible = false
	visible = false

func _build_ui():
	var row = HBoxContainer.new()
	row.name = "SlotRow"
	row.set_anchor(SIDE_RIGHT, 1.0)
	row.set_anchor(SIDE_LEFT, 1.0)
	row.offset_left = -((SLOT_SIZE.x + SLOT_SPACING) * MAX_PLAYERS) - 12
	row.offset_right = -12
	row.offset_top = 12
	row.add_theme_constant_override("separation", SLOT_SPACING)
	add_child(row)
	
	for i in range(MAX_PLAYERS):
		var slot = _create_slot(i)
		row.add_child(slot)
		slot_nodes.append(slot)

func _create_slot(slot_index: int) -> Control:
	# Outer button = whole icon is clickable
	var btn = Button.new()
	btn.name = "Slot" + str(slot_index)
	btn.custom_minimum_size = SLOT_SIZE
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_ARROW
	
	# Background portrait box
	var bg = Panel.new()
	bg.name = "BG"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_empty_style(bg)
	btn.add_child(bg)
	
	# Crown for host (top-left)
	var crown = Label.new()
	crown.name = "Crown"
	crown.text = "★"
	crown.add_theme_font_size_override("font_size", 14)
	crown.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	crown.position = Vector2(4, 2)
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crown.visible = false
	btn.add_child(crown)
	
	# Shield bar (thin, top-inside)
	var shield = ProgressBar.new()
	shield.name = "ShieldBar"
	shield.show_percentage = false
	shield.max_value = 100
	shield.value = 0
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shield.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shield.offset_left = 4
	shield.offset_right = -4
	shield.offset_top = SLOT_SIZE.y - 18
	shield.offset_bottom = SLOT_SIZE.y - 12
	_style_bar(shield, Color(0.0, 0.8, 1.0))
	btn.add_child(shield)
	
	# HP bar (thin, bottom-inside, just below shield)
	var hp = ProgressBar.new()
	hp.name = "HealthBar"
	hp.show_percentage = false
	hp.max_value = 100
	hp.value = 0
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hp.offset_left = 4
	hp.offset_right = -4
	hp.offset_top = SLOT_SIZE.y - 10
	hp.offset_bottom = SLOT_SIZE.y - 4
	_style_bar(hp, Color(0.0, 1.0, 0.3))
	btn.add_child(hp)
	
	# X overlay (hover for actionable, or dead state)
	var x = Label.new()
	x.name = "XOverlay"
	x.text = "✕"
	x.add_theme_font_size_override("font_size", 44)
	x.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	x.set_anchors_preset(Control.PRESET_FULL_RECT)
	x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	x.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	x.visible = false
	btn.add_child(x)
	
	# Wire up signals
	btn.mouse_entered.connect(_on_slot_hover_enter.bind(slot_index))
	btn.mouse_exited.connect(_on_slot_hover_exit.bind(slot_index))
	btn.pressed.connect(_on_slot_pressed.bind(slot_index))
	
	return btn

func _apply_empty_style(panel: Panel):
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.15, 0.15, 0.2, 0.6)
	s.border_color = Color(0.3, 0.3, 0.35, 0.5)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", s)

func _apply_active_style(panel: Panel):
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.3, 0.8, 0.9, 1.0)
	s.border_color = Color(0.0, 1.0, 1.0, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", s)

func _style_bar(bar: ProgressBar, color: Color):
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.05, 0.85)
	bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)
	var fg = StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fg)

# === STATE UPDATES ===

func _on_players_updated(players: Dictionary):
	if slot_nodes.is_empty():
		return
	
	var player_ids = players.keys()
	var host_id = SessionManager.session_host_id
	
	# Host first
	if not host_id.is_empty() and player_ids.has(host_id):
		player_ids.erase(host_id)
		player_ids.push_front(host_id)
	
	for i in range(MAX_PLAYERS):
		var slot: Button = slot_nodes[i]
		var bg: Panel = slot.get_node("BG")
		var crown: Label = slot.get_node("Crown")
		var shield: ProgressBar = slot.get_node("ShieldBar")
		var hp: ProgressBar = slot.get_node("HealthBar")
		
		if i < player_ids.size():
			var pid = player_ids[i]
			var pdata = players[pid]
			slot_player_ids[i] = pid
			
			_apply_active_style(bg)
			crown.visible = (pid == host_id)
			shield.value = pdata.get("shield", 0)
			hp.value = pdata.get("health", 0)
			
			_configure_slot_interaction(pid, slot)
		else:
			slot_player_ids[i] = ""
			_apply_empty_style(bg)
			crown.visible = false
			shield.value = 0
			hp.value = 0
			slot.disabled = true
			slot.tooltip_text = ""

func _configure_slot_interaction(pid: String, btn: Button):
	var my_id = PlayerAccount.player_id
	var im_host = SessionManager.is_host
	var im_in_session = not SessionManager.current_session_id.is_empty()
	
	if not im_in_session:
		btn.disabled = true
		btn.tooltip_text = ""
		return
	
	if pid == my_id:
		btn.disabled = false
		btn.tooltip_text = "Click to leave session"
	elif im_host:
		btn.disabled = false
		btn.tooltip_text = "Click to kick player"
	else:
		btn.disabled = true
		btn.tooltip_text = ""

# === HOVER / CLICK ===

func _on_slot_hover_enter(idx: int):
	if not is_interactive:
		return
	var pid = slot_player_ids[idx]
	if pid.is_empty():
		return
	
	var my_id = PlayerAccount.player_id
	var im_host = SessionManager.is_host
	
	if pid == my_id or (im_host and pid != my_id):
		var x: Label = slot_nodes[idx].get_node("XOverlay")
		x.visible = true
		slot_nodes[idx].get_node("BG").modulate = Color(1.0, 1.0, 1.0, 0.5)

func _on_slot_hover_exit(idx: int):
	var x: Label = slot_nodes[idx].get_node("XOverlay")
	x.visible = false
	slot_nodes[idx].get_node("BG").modulate = Color.WHITE

func _on_slot_pressed(idx: int):
	if not is_interactive:
		return
	var pid = slot_player_ids[idx]
	if pid.is_empty():
		return
	
	var my_id = PlayerAccount.player_id
	if pid == my_id:
		leave_session_requested.emit()
	elif SessionManager.is_host:
		kick_player_requested.emit(pid)

# === PUBLIC API ===

# Called by pause menu: true when paused (cursor unlocked, clicks land here),

func set_interactive(interactive: bool):
	is_interactive = interactive
	for slot in slot_nodes:
		slot.mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
