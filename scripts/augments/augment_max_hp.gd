class_name AugmentMaxHP
extends Augment

@export var hp_bonus: float = 50.0
@export var move_speed_penalty: float = 0.85


func _init() -> void:
	target = Augment.Target.PLAYER


func apply_to_player(player: Node) -> void:
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		push_error("AugmentMaxHP: player has no HealthComponent")
		return
	health.max_hp += hp_bonus
	health.current_hp += hp_bonus
