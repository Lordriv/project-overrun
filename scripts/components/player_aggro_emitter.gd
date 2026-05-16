# player_aggro_emitter.gd
# Child node on every player. Call generate_threat() when dealing damage.
class_name PlayerAggroEmitter
extends Node

@export var threat_per_damage: float = 1.0

func generate_threat(enemy: Node, damage_dealt: float) -> void:
	var aggro := enemy.get_node_or_null("AggroComponent") as AggroComponent
	if aggro:
		aggro.add_threat(get_parent(), damage_dealt * threat_per_damage)

func taunt_all_nearby(radius: float = 15.0, threat_bonus: float = 500.0) -> void:
	for enemy in EnemyManager.enemies:
		var d: float = get_parent().global_position.distance_to(enemy.global_position)
		if d <= radius:
			var aggro := enemy.get_node_or_null("AggroComponent") as AggroComponent
			if aggro:
				aggro.taunt(get_parent(), threat_bonus)

func taunt_enemy(enemy: Node, threat_bonus: float = 500.0) -> void:
	var aggro := enemy.get_node_or_null("AggroComponent") as AggroComponent
	if aggro:
		aggro.taunt(get_parent(), threat_bonus)
