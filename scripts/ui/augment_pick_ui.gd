class_name AugmentPickUI
extends CanvasLayer
## Shown when player interacts with an active terminal.
## Layout: vertical augment card stack on the left, current weapon panel on the right.
## Hovering a card previews its effect on the active weapon.
## Player can swap weapons (Q / 1 / 2) while UI is open to retarget the augment.

const SCENE_PATH: String = "res://scenes/ui/augment_pick_ui.tscn"
const ROLL_COUNT: int = 3

signal augment_chosen(augment: Augment)

@onready var card_container: VBoxContainer = %CardContainer
@onready var card_template: Button = %CardTemplate
@onready var weapon_name_label: Label = %WeaponNameLabel
@onready var stats_container: VBoxContainer = %StatsContainer

var _target_player: Node = null
var _weapon_holder: WeaponHolder = null
var _rolled: Array[Augment] = []
var _hovered_augment: Augment = null

# Stats we display in the right panel for weapons.
# Order matters here — defines display order top-to-bottom.
const WEAPON_STATS: Array[Dictionary] = [
	{"key": "fire_rate", "label": "Fire Rate", "format": "%.1f/s"},
	{"key": "projectile_damage", "label": "Damage", "format": "%.0f"},
	{"key": "projectile_speed", "label": "Speed", "format": "%.0f m/s"},
	{"key": "spread_degrees", "label": "Spread", "format": "%.1f°"},
	{"key": "magazine_size", "label": "Magazine", "format": "%d"},
	{"key": "knockback_per_shot", "label": "Knockback", "format": "%.1f"},
	{"key": "pellets_per_shot", "label": "Pellets", "format": "%d"},
]


static func open(player: Node) -> AugmentPickUI:
	var scene: PackedScene = load(SCENE_PATH)
	var ui: AugmentPickUI = scene.instantiate()
	ui._target_player = player
	ui._weapon_holder = player.get_node_or_null("WeaponHolder") as WeaponHolder
	player.get_tree().current_scene.add_child(ui)
	ui._roll_and_show()
	return ui


func _roll_and_show() -> void:
	_rolled = AugmentPool.roll(ROLL_COUNT)
	card_template.visible = false
	
	for augment in _rolled:
		var card := card_template.duplicate() as Button
		card.visible = true
		card.text = "%s\n[%s]\n+ %s\n- %s" % [
			augment.display_name,
			augment.get_scope_label(),
			augment.description_upside,
			augment.description_downside,
		]
		card.pressed.connect(_on_card_pressed.bind(augment))
		card.mouse_entered.connect(_on_card_hovered.bind(augment))
		card.mouse_exited.connect(_on_card_unhovered.bind(augment))
		card_container.add_child(card)
	
	# Listen to weapon swaps so the panel updates live
	if _weapon_holder:
		_weapon_holder.weapon_changed.connect(_on_weapon_changed)
	
	# Show current weapon stats with no preview yet
	_refresh_weapon_panel()
	
	# Mouse + pause setup
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	# Clean up the signal connection
	if _weapon_holder and _weapon_holder.weapon_changed.is_connected(_on_weapon_changed):
		_weapon_holder.weapon_changed.disconnect(_on_weapon_changed)


func _on_card_hovered(augment: Augment) -> void:
	_hovered_augment = augment
	_refresh_weapon_panel()


func _on_card_unhovered(_augment: Augment) -> void:
	_hovered_augment = null
	_refresh_weapon_panel()


func _on_weapon_changed(_new_weapon: WeaponComponent) -> void:
	_refresh_weapon_panel()


func _on_card_pressed(augment: Augment) -> void:
	var active_weapon: WeaponComponent = _weapon_holder.active_weapon if _weapon_holder else null
	augment.apply(_target_player, active_weapon)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	augment_chosen.emit(augment)
	queue_free()


func _refresh_weapon_panel() -> void:
	# Clear existing stat rows
	for child in stats_container.get_children():
		child.queue_free()
	
	var weapon: WeaponComponent = _weapon_holder.active_weapon if _weapon_holder else null
	if weapon == null:
		weapon_name_label.text = "NO WEAPON"
		return
	
	# Weapon name (use the node's name as a fallback — replace with proper weapon name later)
	weapon_name_label.text = weapon.name.to_upper()
	
	# Get preview values if we're hovering a weapon-targeting augment
	var preview: Dictionary = {}
	if _hovered_augment != null and _hovered_augment.target == Augment.Target.ACTIVE_WEAPON:
		preview = _hovered_augment.preview_weapon_stats(weapon)
	
	# Build a stat row for each entry in WEAPON_STATS
	for stat_def in WEAPON_STATS:
		var key: String = stat_def["key"]
		var label_text: String = stat_def["label"]
		var fmt: String = stat_def["format"]
		
		if not key in weapon:
			continue  # weapon doesn't have this stat (e.g. older weapon without knockback)
		
		var current_value = weapon.get(key)
		var row := _make_stat_row(label_text, current_value, preview.get(key, null), fmt)
		stats_container.add_child(row)


func _make_stat_row(stat_name: String, current_value, preview_value, fmt: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	
	var name_label := Label.new()
	name_label.text = stat_name + ":"
	name_label.custom_minimum_size.x = 110
	row.add_child(name_label)
	
	var current_label := Label.new()
	current_label.text = fmt % current_value
	row.add_child(current_label)
	
	# Show arrow + new value if a preview exists AND it's different from current
	if preview_value != null and not is_same_value(current_value, preview_value):
		var arrow := Label.new()
		arrow.text = "  →  "
		row.add_child(arrow)
		
		var new_label := Label.new()
		new_label.text = fmt % preview_value
		# Color the projection: green if better, red if worse (rough heuristic)
		var is_increase: bool = float(preview_value) > float(current_value)
		var is_better := _is_increase_good(stat_name, is_increase)
		new_label.add_theme_color_override("font_color",
			Color(0.4, 1.0, 0.4) if is_better else Color(1.0, 0.5, 0.5))
		row.add_child(new_label)
	
	return row


func is_same_value(a, b) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		return abs(float(a) - float(b)) < 0.001
	return a == b


# Heuristic: for some stats, increasing is good (damage). For others, increasing is bad (spread).
func _is_increase_good(stat_name: String, is_increase: bool) -> bool:
	var bad_when_higher: Array[String] = ["Spread:", "Spread"]
	var lowercase := stat_name.to_lower().rstrip(":")
	if "spread" in lowercase:
		return not is_increase
	# Knockback is ambiguous (the player might want it for chaos), default to "increase = good"
	return is_increase
