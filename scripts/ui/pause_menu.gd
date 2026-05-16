extends CanvasLayer

const LOBBY_SCENE_PATH = "res://scenes/levels/Lobby.tscn"

var is_menu_open = false
var tween
var active_button = ""

const SETTINGS = {
	"AUDIO": ["Master", "Music", "UI", "Enemies", "Players", "Voice-chat", "Environment"],
	"VIDEO": ["Brightness", "Resolution Scale", "FOV", "Motion Blur"],
	"KEYBINDS": ["Move Forward", "Move Back", "Strafe Left", "Strafe Right", "Sprint", "Jump", "Dash"],
	"HELP": []
}

var saved_settings = {}
var main_panel: Panel
var left_panel: VBoxContainer
var right_panel: Panel
var friends_panel: Panel
var settings_container: VBoxContainer
var friends_container: VBoxContainer
var settings_title: Label
var friends_title: Label
var menu_title: Label
var buttons = {}

var confirm_dialog: ConfirmationDialog
var kick_dialog: ConfirmationDialog
var _pending_kick_target: String = ""
var _friends_refresh_timer: Timer


func _ready():
	_build_ui()
	_connect_squad_hud()
	hide()


func _connect_squad_hud():
	if SquadHUD:
		if not SquadHUD.leave_session_requested.is_connected(_show_leave_session_confirm):
			SquadHUD.leave_session_requested.connect(_show_leave_session_confirm)
		if not SquadHUD.kick_player_requested.is_connected(_show_kick_confirm):
			SquadHUD.kick_player_requested.connect(_show_kick_confirm)


func _build_ui():
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	main_panel = Panel.new()
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.1, 0.0)
	main_panel.add_theme_stylebox_override("panel", style)
	add_child(main_panel)

	var bolt = _create_bolt_shape()
	main_panel.add_child(bolt)

	left_panel = VBoxContainer.new()
	left_panel.set_anchor(SIDE_LEFT, 0)
	left_panel.set_anchor(SIDE_TOP, 0)
	left_panel.set_anchor(SIDE_RIGHT, 0)
	left_panel.set_anchor(SIDE_BOTTOM, 1)
	left_panel.offset_left = 80
	left_panel.offset_right = 380
	left_panel.add_theme_constant_override("separation", 16)
	main_panel.add_child(left_panel)

	menu_title = Label.new()
	menu_title.text = "MENU"
	menu_title.add_theme_font_size_override("font_size", 48)
	menu_title.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	menu_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu_title.custom_minimum_size.y = 120
	left_panel.add_child(menu_title)

	var button_names = ["AUDIO", "VIDEO", "KEYBINDS", "FRIENDS", "HELP", "RETURN"]
	for btn_name in button_names:
		var btn = Button.new()
		btn.text = btn_name
		btn.custom_minimum_size = Vector2(260, 52)
		btn.add_theme_font_size_override("font_size", 20)
		_style_button(btn, false)
		btn.mouse_entered.connect(_on_button_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_button_hover.bind(btn, false))
		btn.pressed.connect(_on_menu_button.bind(btn_name, btn))
		left_panel.add_child(btn)
		buttons[btn_name] = btn

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(spacer)

	right_panel = Panel.new()
	right_panel.set_anchor(SIDE_LEFT, 0)
	right_panel.set_anchor(SIDE_TOP, 0)
	right_panel.set_anchor(SIDE_RIGHT, 0)
	right_panel.set_anchor(SIDE_BOTTOM, 1)
	right_panel.offset_left = 420
	right_panel.offset_right = 900
	var settings_style = StyleBoxFlat.new()
	settings_style.bg_color = Color(0.04, 0.06, 0.12, 0.97)
	settings_style.border_color = Color(0.0, 0.95, 1.0, 0.3)
	settings_style.set_border_width_all(1)
	settings_style.set_corner_radius_all(4)
	right_panel.add_theme_stylebox_override("panel", settings_style)
	right_panel.modulate.a = 0.0
	right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_panel.add_child(right_panel)

	settings_container = VBoxContainer.new()
	settings_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_container.offset_left = 32
	settings_container.offset_right = -32
	settings_container.offset_top = 32
	settings_container.add_theme_constant_override("separation", 20)
	right_panel.add_child(settings_container)

	settings_title = Label.new()
	settings_title.add_theme_font_size_override("font_size", 28)
	settings_title.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	settings_container.add_child(settings_title)

	friends_panel = Panel.new()
	friends_panel.set_anchor(SIDE_LEFT, 1)
	friends_panel.set_anchor(SIDE_TOP, 0)
	friends_panel.set_anchor(SIDE_RIGHT, 1)
	friends_panel.set_anchor(SIDE_BOTTOM, 1)
	friends_panel.offset_left = -500
	friends_panel.offset_right = -40
	friends_panel.offset_top = 40
	friends_panel.offset_bottom = -40
	var friends_style = StyleBoxFlat.new()
	friends_style.bg_color = Color(0.04, 0.06, 0.12, 0.97)
	friends_style.border_color = Color(0.0, 0.95, 1.0, 0.3)
	friends_style.set_border_width_all(1)
	friends_style.set_corner_radius_all(4)
	friends_panel.add_theme_stylebox_override("panel", friends_style)
	friends_panel.modulate.a = 0.0
	friends_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_panel.add_child(friends_panel)

	friends_container = VBoxContainer.new()
	friends_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	friends_container.offset_left = 32
	friends_container.offset_right = -32
	friends_container.offset_top = 32
	friends_container.offset_bottom = -32
	friends_container.add_theme_constant_override("separation", 20)
	friends_panel.add_child(friends_container)

	friends_title = Label.new()
	friends_title.text = "FRIENDS"
	friends_title.add_theme_font_size_override("font_size", 28)
	friends_title.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	friends_container.add_child(friends_title)


func _create_bolt_shape() -> Node2D:
	var fade = Polygon2D.new()
	fade.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(480, 0), Vector2(420, 200),
		Vector2(500, 200), Vector2(360, 500), Vector2(440, 500),
		Vector2(220, 1080), Vector2(0, 1080)
	])
	fade.color = Color(0.08, 0.0, 0.2, 0.25)

	var mid = Polygon2D.new()
	mid.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(380, 0), Vector2(320, 200),
		Vector2(400, 200), Vector2(260, 500), Vector2(340, 500),
		Vector2(140, 1080), Vector2(0, 1080)
	])
	mid.color = Color(0.15, 0.0, 0.35, 0.4)
	fade.add_child(mid)

	var core = Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(320, 0), Vector2(260, 200),
		Vector2(340, 200), Vector2(200, 500), Vector2(280, 500),
		Vector2(80, 1080), Vector2(0, 1080)
	])
	core.color = Color(0.3, 0.0, 0.5, 0.7)
	fade.add_child(core)

	return fade


func _style_button(btn: Button, hovered: bool):
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.6, 0.8, 0.15) if hovered else Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = Color(0.0, 0.95, 1.0, 0.8) if hovered else Color(0.0, 0.95, 1.0, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0) if hovered else Color(0.7, 0.9, 1.0))


func _on_button_hover(btn: Button, hovered: bool):
	_style_button(btn, hovered)
	var t = create_tween()
	t.tween_property(btn, "scale", Vector2(1.04, 1.04) if hovered else Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_OUT)
	btn.pivot_offset = btn.size / 2


func _on_menu_button(btn_name: String, _btn: Button):
	if btn_name == "RETURN":
		close_menu()
		return

	if active_button == btn_name:
		active_button = ""
		_hide_right_panel()
		_hide_friends_panel()
		return

	active_button = btn_name

	if btn_name == "FRIENDS":
		_hide_right_panel()
		_show_friends_panel()
	else:
		_hide_friends_panel()
		if btn_name == "HELP":
			_show_right_panel("HELP", [])
		elif SETTINGS.has(btn_name):
			_show_right_panel(btn_name, SETTINGS[btn_name])


func _is_in_multiplayer() -> bool:
	if not SessionManager:
		return false
	return SessionManager.session_players.size() > 1


func _should_pause() -> bool:
	return not _is_in_multiplayer()


func _show_right_panel(title: String, items: Array):
	for child in settings_container.get_children():
		if child != settings_title:
			child.queue_free()

	settings_title.text = title

	if title == "HELP":
		var help = Label.new()
		help.text = "WASD — Move\nMouse — Look\nShift — Sprint\nSpace — Jump\nCtrl — Dash\nEsc — Menu\n\nClick your icon in SQUAD HUD to leave session.\nHosts: click another player's icon to kick them."
		help.add_theme_font_size_override("font_size", 16)
		help.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
		settings_container.add_child(help)
	else:
		for item in items:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 16)

			var lbl = Label.new()
			lbl.text = item
			lbl.custom_minimum_size.x = 160
			lbl.add_theme_font_size_override("font_size", 15)
			lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
			row.add_child(lbl)

			var slider = HSlider.new()
			slider.min_value = 0.0
			slider.max_value = 1.0
			slider.step = 0.01
			slider.value = saved_settings.get(item, 0.5)
			slider.custom_minimum_size.x = 200
			slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slider.value_changed.connect(_on_slider_changed.bind(item))
			row.add_child(slider)

			var val_label = Label.new()
			val_label.text = "%.2f" % slider.value
			val_label.custom_minimum_size.x = 40
			val_label.add_theme_font_size_override("font_size", 13)
			val_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
			slider.value_changed.connect(func(v): val_label.text = "%.2f" % v)
			row.add_child(val_label)

			settings_container.add_child(row)

	right_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	if tween:
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	right_panel.position.x = -200
	right_panel.modulate.a = 0.0
	tween.tween_property(right_panel, "position:x", 0.0, 0.25)
	tween.parallel().tween_property(right_panel, "modulate:a", 1.0, 0.15)


func _hide_right_panel():
	right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tween:
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(right_panel, "position:x", -200.0, 0.2)
	tween.parallel().tween_property(right_panel, "modulate:a", 0.0, 0.15)


func _hide_friends_panel():
	friends_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stop_friends_refresh()
	var t = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(friends_panel, "position:x", 200.0, 0.2)
	t.parallel().tween_property(friends_panel, "modulate:a", 0.0, 0.15)


func _on_slider_changed(value: float, item: String):
	saved_settings[item] = value


func _input(event):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if confirm_dialog and confirm_dialog.visible:
			confirm_dialog.hide()
			return
		if is_menu_open:
			close_menu()
		else:
			open_menu()


func open_menu():
	is_menu_open = true
	menu_title.text = "PAUSED" if _should_pause() else "MENU"
	show()
	if SquadHUD:
		SquadHUD.set_interactive(true)
	if _should_pause():
		get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close_menu():
	is_menu_open = false
	active_button = ""
	_hide_right_panel()
	_hide_friends_panel()
	if SquadHUD:
		SquadHUD.set_interactive(false)
	hide()
	_stop_friends_refresh()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# --- LEAVE SESSION ---

func _show_leave_session_confirm():
	if not confirm_dialog:
		confirm_dialog = ConfirmationDialog.new()
		confirm_dialog.title = "Leave Session?"
		confirm_dialog.ok_button_text = "Leave"
		confirm_dialog.cancel_button_text = "Stay"
		confirm_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
		confirm_dialog.confirmed.connect(_on_leave_session_confirmed)
		add_child(confirm_dialog)

	if SessionManager.is_host and SessionManager.session_players.size() > 1:
		confirm_dialog.dialog_text = "You are the HOST. Leaving will end the session for all players.\n\nAre you sure?"
	elif SessionManager.is_host:
		confirm_dialog.dialog_text = "You will leave the current session and return to the lobby.\n\nAre you sure?"
	else:
		confirm_dialog.dialog_text = "You will leave " + SessionManager.session_host_id.substr(0, 6) + "'s session and return to the lobby.\n\nAre you sure?"

	confirm_dialog.popup_centered()


func _on_leave_session_confirmed():
	close_menu()
	await SessionManager.leave_session()
	get_tree().change_scene_to_file(LOBBY_SCENE_PATH)


func _show_kick_confirm(target_player_id: String):
	_pending_kick_target = target_player_id

	var target_username = "this player"
	if SessionManager.session_players.has(target_player_id):
		target_username = SessionManager.session_players[target_player_id].get("username", "this player")

	if not kick_dialog:
		kick_dialog = ConfirmationDialog.new()
		kick_dialog.title = "Kick Player?"
		kick_dialog.ok_button_text = "Kick"
		kick_dialog.cancel_button_text = "Cancel"
		kick_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
		kick_dialog.confirmed.connect(_on_kick_confirmed)
		add_child(kick_dialog)

	kick_dialog.dialog_text = "Kick %s from the session?\n\nThey will not be able to rejoin." % target_username
	kick_dialog.popup_centered()


func _on_kick_confirmed():
	if _pending_kick_target.is_empty():
		return
	var target = _pending_kick_target
	_pending_kick_target = ""
	await SessionManager.kick_player(target)


# --- FRIENDS PANEL ---

func _show_friends_panel():
	for child in friends_container.get_children():
		if child != friends_title:
			child.queue_free()

	_start_friends_refresh()

	var your_id_label = Label.new()
	your_id_label.text = "Your PlayerID (share with friends):"
	your_id_label.add_theme_font_size_override("font_size", 13)
	your_id_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	friends_container.add_child(your_id_label)

	var id_display = LineEdit.new()
	id_display.text = PlayerAccount.player_id
	id_display.editable = false
	id_display.custom_minimum_size.y = 35
	id_display.add_theme_font_size_override("font_size", 12)
	friends_container.add_child(id_display)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size.y = 20
	friends_container.add_child(spacer1)

	var add_label = Label.new()
	add_label.text = "Add Friend by PlayerID:"
	add_label.add_theme_font_size_override("font_size", 13)
	add_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	friends_container.add_child(add_label)

	var friend_input = LineEdit.new()
	friend_input.placeholder_text = "Paste friend's PlayerID here..."
	friend_input.custom_minimum_size.y = 35
	friends_container.add_child(friend_input)

	var add_btn = Button.new()
	add_btn.text = "ADD FRIEND"
	add_btn.custom_minimum_size = Vector2(200, 40)
	add_btn.pressed.connect(func():
		var friend_id = friend_input.text.strip_edges()
		if not friend_id.is_empty():
			FriendsManager.add_friend(friend_id)
			friend_input.text = ""
			FriendsManager.refresh_friends_status()
			_show_friends_panel()
	)
	friends_container.add_child(add_btn)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 20
	friends_container.add_child(spacer2)

	var friends_label = Label.new()
	friends_label.text = "Friends:"
	friends_label.add_theme_font_size_override("font_size", 14)
	friends_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	friends_container.add_child(friends_label)

	if not FriendsManager.friends_status_updated.is_connected(_on_friends_status_updated):
		FriendsManager.friends_status_updated.connect(_on_friends_status_updated)

	if not PlayerAccount.friends_list.is_empty():
		var loading = Label.new()
		loading.name = "LoadingLabel"
		loading.text = "Loading friends..."
		loading.add_theme_font_size_override("font_size", 12)
		loading.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		friends_container.add_child(loading)
	else:
		var no_friends = Label.new()
		no_friends.name = "NoFriendsLabel"
		no_friends.text = "No friends added yet"
		no_friends.add_theme_font_size_override("font_size", 12)
		no_friends.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		friends_container.add_child(no_friends)

	FriendsManager.refresh_friends_status()

	friends_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var t = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	friends_panel.position.x = 200
	friends_panel.modulate.a = 0.0
	t.tween_property(friends_panel, "position:x", 0.0, 0.25)
	t.parallel().tween_property(friends_panel, "modulate:a", 1.0, 0.15)


func _on_friends_status_updated(friends_data: Array):
	var loading = friends_container.find_child("LoadingLabel", false, false)
	if loading:
		loading.queue_free()

	var no_friends_old = friends_container.find_child("NoFriendsLabel", false, false)
	if no_friends_old:
		no_friends_old.queue_free()

	for child in friends_container.get_children():
		if child.name.begins_with("FriendEntry"):
			friends_container.remove_child(child)
			child.queue_free()

	if friends_data.is_empty():
		var no_friends = Label.new()
		no_friends.name = "NoFriendsLabel"
		no_friends.text = "No friends added yet"
		no_friends.add_theme_font_size_override("font_size", 12)
		no_friends.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		friends_container.add_child(no_friends)
		return

	for friend in friends_data:
		var friend_entry = HBoxContainer.new()
		friend_entry.name = "FriendEntry_" + friend.player_id
		friend_entry.add_theme_constant_override("separation", 10)
		friends_container.add_child(friend_entry)

		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		friend_entry.add_child(info)

		var name_label = Label.new()
		name_label.text = friend.username
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
		info.add_child(name_label)

		var status_label = Label.new()
		if friend.online and not friend.current_session.is_empty():
			var privacy = friend.get("session_privacy", "private")
			var count = friend.get("session_player_count", 1)
			var max_p = friend.get("session_max_players", 4)
			var joinable = friend.get("is_joinable", false)
			var privacy_label = privacy.capitalize()
			var is_same_session = (friend.current_session == SessionManager.current_session_id)
			if is_same_session:
				status_label.text = "🔵 In your session (%d/%d)" % [count, max_p]
				status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
			elif privacy == "private":
				status_label.text = "🟡 In Private Game (%d/%d)" % [count, max_p]
				status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.0))
			elif joinable:
				status_label.text = "🟢 In %s Game (%d/%d) - Joinable" % [privacy_label, count, max_p]
				status_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.3))
			else:
				status_label.text = "🟠 In %s Game (%d/%d) - Full" % [privacy_label, count, max_p]
				status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
		elif friend.online:
			status_label.text = "🟢 Online (Menu)"
			status_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.3))
		else:
			status_label.text = "⚫ Offline"
			status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

		status_label.add_theme_font_size_override("font_size", 11)
		info.add_child(status_label)

		var is_my_current_session = (friend.current_session == SessionManager.current_session_id)
		if friend.get("is_joinable", false) and not is_my_current_session:
			var join_btn = Button.new()
			join_btn.text = "JOIN"
			join_btn.custom_minimum_size = Vector2(80, 35)
			join_btn.pressed.connect(func():
				SessionManager.join_session(friend.current_session)
			)
			friend_entry.add_child(join_btn)

		var remove_btn = Button.new()
		remove_btn.text = "✕"
		remove_btn.custom_minimum_size = Vector2(35, 35)
		remove_btn.tooltip_text = "Remove friend"
		var fid = friend.player_id
		remove_btn.pressed.connect(func():
			FriendsManager.remove_friend(fid)
		)
		friend_entry.add_child(remove_btn)


func _start_friends_refresh():
	if _friends_refresh_timer and is_instance_valid(_friends_refresh_timer):
		_friends_refresh_timer.queue_free()
	_friends_refresh_timer = Timer.new()
	_friends_refresh_timer.wait_time = 2.0
	_friends_refresh_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_friends_refresh_timer.timeout.connect(_on_friends_refresh_tick)
	add_child(_friends_refresh_timer)
	_friends_refresh_timer.start()


func _stop_friends_refresh():
	if _friends_refresh_timer and is_instance_valid(_friends_refresh_timer):
		_friends_refresh_timer.queue_free()
		_friends_refresh_timer = null


func _on_friends_refresh_tick():
	if active_button == "FRIENDS":
		FriendsManager.refresh_friends_status()
	else:
		_stop_friends_refresh()
