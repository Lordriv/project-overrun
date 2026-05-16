# main_menu.gd
extends Control

@onready var play_button:     Button   = $VBoxContainer/PlayButton
@onready var settings_button: Button   = $VBoxContainer/SettingsButton
@onready var quit_button:     Button   = $VBoxContainer/QuitButton
@onready var accent_shape:    Polygon2D = $AccentShape

func _ready() -> void:
	_setup_buttons()
	_create_accent_shape()
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _setup_buttons() -> void:
	var buttons := [play_button, settings_button, quit_button]
	for button in buttons:
		button.pivot_offset = button.size / 2.0
		_style_button(button)
		button.mouse_entered.connect(_on_button_hover.bind(button))
		button.mouse_exited.connect(_on_button_unhover.bind(button))

func _style_button(button: Button) -> void:
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style_normal.border_color = Color(0.3, 0.8, 1.0, 0.6)
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.corner_radius_top_left = 4
	style_normal.corner_radius_top_right = 4
	style_normal.corner_radius_bottom_left = 4
	style_normal.corner_radius_bottom_right = 4
	var style_hover := style_normal.duplicate()
	style_hover.bg_color = Color(0.15, 0.15, 0.25, 0.9)
	style_hover.border_color = Color(0.5, 1.0, 1.0, 1.0)
	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = Color(0.2, 0.3, 0.4, 1.0)
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))

func _create_accent_shape() -> void:
	var points := PackedVector2Array([
		Vector2(100, 200), Vector2(300, 150), Vector2(250, 400),
		Vector2(400, 350), Vector2(350, 600), Vector2(150, 550),
	])
	accent_shape.polygon = points
	accent_shape.color = Color(0.2, 0.6, 0.9, 0.15)
	accent_shape.position = Vector2(50, 100)

func _on_button_hover(button: Button) -> void:
	create_tween().tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)

func _on_button_unhover(button: Button) -> void:
	create_tween().tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)

func _on_play_pressed() -> void:
	play_button.disabled = true
	get_tree().change_scene_to_file("res://scenes/levels/Lobby.tscn")

func _on_settings_pressed() -> void:
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()
