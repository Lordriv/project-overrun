extends Area3D
## ScoutingTrigger — place in the world between the player spawn and the anchor.
## When a player walks through it during EXPLORE, transitions WaveManager to SCOUTING.
## WaveManager arms/disarms this each cycle via the "scouting_trigger" group.

var _armed: bool = false


func _ready() -> void:
	add_to_group("scouting_trigger")
	body_entered.connect(_on_body_entered)
	monitoring = false


func set_armed(armed: bool) -> void:
	_armed = armed
	monitoring = armed


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		WaveManager.trigger_scouting.call_deferred()
