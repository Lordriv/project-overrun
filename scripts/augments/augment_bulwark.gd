class_name AugmentBulwark
extends Augment

@export var armor_bonus:              float = 20.0
@export var shield_regen_multiplier:  float = 0.6


func _init() -> void:
	target = Augment.Target.PLAYER


func apply_to_player(player: Node) -> void:
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	if health == null:
		push_error("AugmentBulwark: player has no HealthComponent")
		return
	health.armor            += armor_bonus
	health.shield_regen_rate *= shield_regen_multiplier
