extends Node
# AutoLoad: SettingsManager

const CONFIG_PATH := "user://settings.cfg"

signal fov_changed(value: float)
signal mouse_sensitivity_changed(value: float)
signal screen_shake_changed(value: float)

const DEFAULTS: Dictionary = {
	"audio/master_volume":    80,
	"audio/music_volume":     55,
	"audio/sfx_volume":       90,
	"audio/voice_volume":     100,
	"audio/output_device":    "Default",
	"audio/subtitles":        true,
	"video/display_mode":     "Fullscreen",
	"video/resolution":       "",
	"video/quality_preset":   "High",
	"video/vsync":            true,
	"video/frame_limit":      144,
	"video/fov":              90,
	"video/mouse_sensitivity": 5,
	"video/screen_shake":     100,
}

var _config := ConfigFile.new()


func _ready() -> void:
	_ensure_audio_buses()
	_config.load(CONFIG_PATH)
	_apply_saved_keybinds()
	apply_all()


func _ensure_audio_buses() -> void:
	for bus_name: String in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _apply_saved_keybinds() -> void:
	if not _config.has_section("keybinds"):
		return
	for action: String in _config.get_section_keys("keybinds"):
		if not InputMap.has_action(action):
			continue
		var data: Dictionary = _config.get_value("keybinds", action, {})
		if data.get("type") == "key":
			var ev := InputEventKey.new()
			ev.physical_keycode = data.get("physical_keycode", KEY_NONE)
			ev.keycode          = data.get("keycode", KEY_NONE)
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, ev)
		elif data.get("type") == "mouse":
			var ev := InputEventMouseButton.new()
			ev.button_index = data.get("button_index", MOUSE_BUTTON_LEFT)
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, ev)


func apply_all() -> void:
	for key: String in DEFAULTS.keys():
		_apply(key, get_value(key))


func get_value(key: String) -> Variant:
	var parts := key.split("/", false, 1)
	return _config.get_value(parts[0], parts[1], DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	var parts := key.split("/", false, 1)
	_config.set_value(parts[0], parts[1], value)
	_config.save(CONFIG_PATH)
	_apply(key, value)


func reset_category(section: String) -> void:
	for key: String in DEFAULTS.keys():
		if key.begins_with(section + "/"):
			set_value(key, DEFAULTS[key])


func _apply(key: String, value: Variant) -> void:
	match key:
		"audio/master_volume": _set_bus_db("Master", int(value))
		"audio/music_volume":  _set_bus_db("Music",  int(value))
		"audio/sfx_volume":    _set_bus_db("SFX",    int(value))
		"audio/voice_volume":  _set_bus_db("Voice",  int(value))
		"audio/output_device":
			if str(value) != "Default" and str(value) in AudioServer.get_output_device_list():
				AudioServer.output_device = str(value)
		"video/display_mode":
			if not OS.has_feature("editor"):
				_apply_display_mode(str(value))
		"video/resolution":
			if str(value) != "" and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
				var parts := str(value).split("x")
				if parts.size() == 2:
					DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
		"video/vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if bool(value) else DisplayServer.VSYNC_DISABLED
			)
		"video/frame_limit":
			Engine.max_fps = 0 if int(value) == 0 else int(value)
		"video/fov":
			fov_changed.emit(float(value))
		"video/mouse_sensitivity":
			mouse_sensitivity_changed.emit(float(value))
		"video/screen_shake":
			screen_shake_changed.emit(float(value))
		"video/quality_preset":
			_apply_quality_preset(str(value))


func _set_bus_db(bus_name: String, volume_0_100: int) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var db := linear_to_db(float(volume_0_100) / 100.0) if volume_0_100 > 0 else -80.0
	AudioServer.set_bus_volume_db(idx, db)


func _apply_quality_preset(preset: String) -> void:
	var vp := get_viewport()
	match preset:
		"Low":
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_debanding = false
		"Medium":
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.use_debanding = false
		"High":
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.use_debanding = true
		"Ultra":
			vp.msaa_3d = Viewport.MSAA_4X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.use_debanding = true


func _apply_display_mode(mode: String) -> void:
	match mode:
		"Fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"Borderless":  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"Windowed":   DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func get_keybind_display(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	var e := events[0]
	if e is InputEventKey:
		var kc: Key = (e as InputEventKey).physical_keycode
		if kc == KEY_NONE:
			kc = (e as InputEventKey).keycode
		return OS.get_keycode_string(kc).to_upper()
	if e is InputEventMouseButton:
		match (e as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:   return "LMB"
			MOUSE_BUTTON_RIGHT:  return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			_: return "M%d" % (e as InputEventMouseButton).button_index
	return "?"


func save_keybind(action: String, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	if event is InputEventKey:
		_config.set_value("keybinds", action, {
			"type": "key",
			"physical_keycode": (event as InputEventKey).physical_keycode,
			"keycode": (event as InputEventKey).keycode,
		})
	elif event is InputEventMouseButton:
		_config.set_value("keybinds", action, {
			"type": "mouse",
			"button_index": (event as InputEventMouseButton).button_index,
		})
	_config.save(CONFIG_PATH)
