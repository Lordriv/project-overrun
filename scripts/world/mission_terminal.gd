extends StaticBody3D
class_name MissionTerminal

# Path to the mission scene to launch
@export_file("*.tscn") var mission_scene: String = "res://scenes/levels/world.tscn"

@onready var interaction_zone: Area3D = $InteractionZone
@onready var prompt = $InteractionPrompt

var player_in_range: bool = false

signal player_entered_range()
signal player_exited_range()
signal interacted()

func _ready() -> void:
	interaction_zone.body_entered.connect(_on_body_entered)
	interaction_zone.body_exited.connect(_on_body_exited)
	if prompt:
		prompt.hide_prompt()

func _process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact"):
		_on_interact()

func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return

	player_in_range = true

	if prompt:
		prompt.show_prompt()

	player_entered_range.emit()

func _on_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return

	player_in_range = false

	if prompt:
		prompt.hide_prompt()

	player_exited_range.emit()

func _is_player(body: Node) -> bool:
	return body.is_in_group("player")

func _on_interact() -> void:
	interacted.emit()
	_launch_mission()

func _launch_mission() -> void:
	if mission_scene.is_empty():
		push_error("No mission scene set")
		return

	if not ResourceLoader.exists(mission_scene):
		push_error("Mission scene not found: " + mission_scene)
		return

	var tree := get_tree()
	if tree:
		tree.change_scene_to_file(mission_scene)
