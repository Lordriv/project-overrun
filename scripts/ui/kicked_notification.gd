extends CanvasLayer
class_name KickedNotification
# Shows a brief overlay when the local player is kicked from a session.
# Auto-attaches to the scene tree as a child of the SessionManager AutoLoad.

const DISPLAY_DURATION = 4.0  # Seconds to show the notification
const FADE_DURATION = 0.4

var notification_panel: Panel
var message_label: Label

func _ready():
	# Render above everything else
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_build_ui()
	hide()
	
	# Listen for kick events
	if not SessionManager.kicked_from_session.is_connected(_on_kicked):
		SessionManager.kicked_from_session.connect(_on_kicked)

func _build_ui():
	notification_panel = Panel.new()
	notification_panel.set_anchor(SIDE_LEFT, 0.5)
	notification_panel.set_anchor(SIDE_RIGHT, 0.5)
	notification_panel.set_anchor(SIDE_TOP, 0.0)
	notification_panel.set_anchor(SIDE_BOTTOM, 0.0)
	notification_panel.offset_left = -250
	notification_panel.offset_right = 250
	notification_panel.offset_top = 80
	notification_panel.offset_bottom = 160
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.05, 0.05, 0.95)
	style.border_color = Color(1.0, 0.3, 0.3, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	notification_panel.add_theme_stylebox_override("panel", style)
	add_child(notification_panel)
	
	# Title row
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_right = -20
	vbox.offset_top = 12
	vbox.offset_bottom = -12
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	notification_panel.add_child(vbox)
	
	var title_label = Label.new()
	title_label.text = "✕ KICKED FROM SESSION"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	vbox.add_child(title_label)
	
	message_label = Label.new()
	message_label.text = "You were kicked by the host"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 13)
	message_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.85))
	vbox.add_child(message_label)

func _on_kicked(reason: String):
	if not message_label:
		return
	
	message_label.text = reason
	show()
	
	# Fade in
	notification_panel.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(notification_panel, "modulate:a", 1.0, FADE_DURATION)
	
	# Wait, then fade out
	await get_tree().create_timer(DISPLAY_DURATION).timeout
	
	var fade_out = create_tween()
	fade_out.tween_property(notification_panel, "modulate:a", 0.0, FADE_DURATION)
	await fade_out.finished
	hide()
