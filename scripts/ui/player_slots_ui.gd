extends Panel
class_name PlayerSlotsUI

const MAX_PLAYERS = 4
var player_slot_containers = []

# Track which slots map to which player_ids (in display order)
var slot_player_ids: Array = []

signal leave_session_requested()
signal kick_player_requested(player_id: String)

func _ready():
	_build_ui()
	await get_tree().process_frame
	if not SessionManager.players_updated.is_connected(_on_players_updated):
		SessionManager.players_updated.connect(_on_players_updated)
	
	# Initialize slot_player_ids
	for i in range(MAX_PLAYERS):
		slot_player_ids.append("")

func _build_ui():
	set_anchor(SIDE_LEFT, 1.0)
	set_anchor(SIDE_TOP, 0.0)
	set_anchor(SIDE_RIGHT, 1.0)
	set_anchor(SIDE_BOTTOM, 0.0)
	offset_left = -320
	offset_right = -20
	offset_top = 20
	offset_bottom = 440
	
	var slot_style = StyleBoxFlat.new()
	slot_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	slot_style.border_color = Color(0.0, 0.9, 0.9, 0.8)
	slot_style.set_border_width_all(2)
	slot_style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", slot_style)
	visible = false
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 15
	vbox.offset_right = -15
	vbox.offset_top = 15
	vbox.offset_bottom = -15
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	
	var title = Label.new()
	title.name = "SquadTitle"
	title.text = "SQUAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	vbox.add_child(title)
	
	for i in range(MAX_PLAYERS):
		var slot_container = _create_player_slot(i)
		vbox.add_child(slot_container)
		player_slot_containers.append(slot_container)

func _create_player_slot(slot_index: int) -> Control:
	var container = HBoxContainer.new()
	container.name = "PlayerSlot" + str(slot_index)
	container.custom_minimum_size.y = 80
	container.add_theme_constant_override("separation", 12)
	
	# === ICON (interactive button) ===
	var icon_button = Button.new()
	icon_button.name = "IconButton"
	icon_button.custom_minimum_size = Vector2(64, 64)
	icon_button.flat = true
	icon_button.focus_mode = Control.FOCUS_NONE
	icon_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	
	# Background panel (the colored square)
	var icon_bg = Panel.new()
	icon_bg.name = "IconBG"
	icon_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color(0.2, 0.2, 0.25, 0.5)
	icon_style.border_color = Color(0.3, 0.3, 0.35, 0.5)
	icon_style.set_border_width_all(2)
	icon_style.set_corner_radius_all(4)
	icon_bg.add_theme_stylebox_override("panel", icon_style)
	icon_button.add_child(icon_bg)
	
	# Red ✕ overlay (hidden by default, shown on hover for actionable slots)
	var x_overlay = Label.new()
	x_overlay.name = "XOverlay"
	x_overlay.text = "✕"
	x_overlay.add_theme_font_size_override("font_size", 40)
	x_overlay.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	x_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	x_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	x_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	x_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	x_overlay.visible = false
	icon_button.add_child(x_overlay)
	
	# Connect signals
	icon_button.mouse_entered.connect(_on_icon_hover_enter.bind(slot_index))
	icon_button.mouse_exited.connect(_on_icon_hover_exit.bind(slot_index))
	icon_button.pressed.connect(_on_icon_pressed.bind(slot_index))
	
	container.add_child(icon_button)
	
	# === INFO AREA (unchanged) ===
	var info_box = VBoxContainer.new()
	info_box.name = "InfoBox"
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 6)
	container.add_child(info_box)
	
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	info_box.add_child(name_row)
	
	var crown_label = Label.new()
	crown_label.name = "CrownLabel"
	crown_label.text = "★"
	crown_label.add_theme_font_size_override("font_size", 16)
	crown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	crown_label.visible = false
	name_row.add_child(crown_label)
	
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = "[ EMPTY SLOT ]"
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	name_row.add_child(name_label)
	
	var shield_container = VBoxContainer.new()
	shield_container.add_theme_constant_override("separation", 2)
	info_box.add_child(shield_container)
	
	var shield_label = Label.new()
	shield_label.text = "SHIELD"
	shield_label.add_theme_font_size_override("font_size", 10)
	shield_label.add_theme_color_override("font_color", Color(0.0, 0.7, 0.9, 0.7))
	shield_container.add_child(shield_label)
	
	var shield_bar = ProgressBar.new()
	shield_bar.name = "ShieldBar"
	shield_bar.custom_minimum_size.y = 14
	shield_bar.max_value = 100
	shield_bar.value = 0
	shield_bar.show_percentage = false
	_style_bar(shield_bar, Color(0.0, 0.8, 1.0))
	shield_container.add_child(shield_bar)
	
	var health_container = VBoxContainer.new()
	health_container.add_theme_constant_override("separation", 2)
	info_box.add_child(health_container)
	
	var health_label = Label.new()
	health_label.text = "HEALTH"
	health_label.add_theme_font_size_override("font_size", 10)
	health_label.add_theme_color_override("font_color", Color(0.0, 0.9, 0.3, 0.7))
	health_container.add_child(health_label)
	
	var health_bar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.custom_minimum_size.y = 14
	health_bar.max_value = 100
	health_bar.value = 0
	health_bar.show_percentage = false
	_style_bar(health_bar, Color(0.0, 1.0, 0.3))
	health_container.add_child(health_bar)
	
	return container

func _style_bar(bar: ProgressBar, color: Color):
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", bg)
	
	var fg = StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fg)

# === SLOT UPDATE LOGIC ===

func _on_players_updated(players: Dictionary):
	if player_slot_containers.is_empty():
		print("⚠️ UI not built yet, skipping update")
		return
	
	var player_ids = players.keys()
	var host_id = SessionManager.session_host_id
	var my_id = PlayerAccount.player_id
	
	# Sort: host first, then everyone else
	if not host_id.is_empty() and player_ids.has(host_id):
		player_ids.erase(host_id)
		player_ids.push_front(host_id)
	
	for i in range(MAX_PLAYERS):
		var slot = player_slot_containers[i]
		var icon_button: Button = slot.find_child("IconButton", true, false)
		var icon_bg: Panel = slot.find_child("IconBG", true, false)
		var x_overlay: Label = slot.find_child("XOverlay", true, false)
		var name_label: Label = slot.find_child("NameLabel", true, false)
		var crown_label: Label = slot.find_child("CrownLabel", true, false)
		var shield_bar: ProgressBar = slot.find_child("ShieldBar", true, false)
		var health_bar: ProgressBar = slot.find_child("HealthBar", true, false)
		
		if not icon_bg or not name_label or not shield_bar or not health_bar:
			continue
		
		if i < player_ids.size():
			# === ACTIVE PLAYER SLOT ===
			var pid = player_ids[i]
			var player_data = players[pid]
			slot_player_ids[i] = pid
			
			var icon_style = StyleBoxFlat.new()
			icon_style.bg_color = Color(0.3, 0.8, 0.9, 1.0)
			icon_style.border_color = Color(0.0, 1.0, 1.0, 1.0)
			icon_style.set_border_width_all(2)
			icon_style.set_corner_radius_all(4)
			icon_bg.add_theme_stylebox_override("panel", icon_style)
			
			name_label.text = player_data.username
			name_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
			
			if crown_label:
				crown_label.visible = (pid == host_id and not host_id.is_empty())
			
			shield_bar.value = player_data.get("shield", 0)
			health_bar.value = player_data.get("health", 0)
			
			# Configure interaction state for this slot
			_configure_slot_interaction(pid, my_id, icon_button)
		else:
			# === EMPTY SLOT ===
			slot_player_ids[i] = ""
			
			var icon_style = StyleBoxFlat.new()
			icon_style.bg_color = Color(0.2, 0.2, 0.25, 0.5)
			icon_style.border_color = Color(0.3, 0.3, 0.35, 0.5)
			icon_style.set_border_width_all(2)
			icon_style.set_corner_radius_all(4)
			icon_bg.add_theme_stylebox_override("panel", icon_style)
			
			name_label.text = "[ EMPTY SLOT ]"
			name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			
			if crown_label:
				crown_label.visible = false
			
			shield_bar.value = 0
			health_bar.value = 0
			
			# Disable interaction on empty slots
			if icon_button:
				icon_button.disabled = true
				icon_button.tooltip_text = ""
				icon_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
			if x_overlay:
				x_overlay.visible = false

func _configure_slot_interaction(player_id: String, my_id: String, icon_button: Button):
	if not icon_button:
		return
	
	var im_in_session = not SessionManager.current_session_id.is_empty()
	var im_host = SessionManager.is_host
	
	if not im_in_session:
		icon_button.disabled = true
		icon_button.tooltip_text = ""
		icon_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	elif player_id == my_id:
		# This is ME - click to leave
		icon_button.disabled = false
		icon_button.tooltip_text = "Click to leave session"
		icon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif im_host and player_id != my_id:
		# This is someone else AND I'm host - click to kick
		icon_button.disabled = false
		icon_button.tooltip_text = "Click to kick player"
		icon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		# This is someone else and I'm NOT host - no interaction
		icon_button.disabled = true
		icon_button.tooltip_text = ""
		icon_button.mouse_default_cursor_shape = Control.CURSOR_ARROW

# === HOVER HANDLERS ===

func _on_icon_hover_enter(slot_index: int):
	var pid = slot_player_ids[slot_index]
	if pid.is_empty():
		return
	
	var slot = player_slot_containers[slot_index]
	var x_overlay: Label = slot.find_child("XOverlay", true, false)
	var icon_bg: Panel = slot.find_child("IconBG", true, false)
	
	var my_id = PlayerAccount.player_id
	var im_host = SessionManager.is_host
	
	# Show ✕ overlay if this is an actionable slot
	if pid == my_id or (im_host and pid != my_id):
		if x_overlay:
			x_overlay.visible = true
		if icon_bg:
			icon_bg.modulate = Color(1.0, 1.0, 1.0, 0.4)

func _on_icon_hover_exit(slot_index: int):
	var slot = player_slot_containers[slot_index]
	var x_overlay: Label = slot.find_child("XOverlay", true, false)
	var icon_bg: Panel = slot.find_child("IconBG", true, false)
	
	if x_overlay:
		x_overlay.visible = false
	if icon_bg:
		icon_bg.modulate = Color(1.0, 1.0, 1.0, 1.0)

# === CLICK HANDLER ===

func _on_icon_pressed(slot_index: int):
	var pid = slot_player_ids[slot_index]
	if pid.is_empty():
		return
	
	var my_id = PlayerAccount.player_id
	var im_host = SessionManager.is_host
	
	if pid == my_id:
		# Click on self - emit leave request (pause menu shows confirm dialog)
		print("👋 Self-leave requested via icon click")
		leave_session_requested.emit()
	elif im_host and pid != my_id:
		# Click on other as host - emit kick request (pause menu shows confirm dialog)
		print("🚫 Kick requested for: ", pid)
		kick_player_requested.emit(pid)
