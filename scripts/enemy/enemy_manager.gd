# enemy_manager.gd
# Autoload — registers as "EnemyManager" in Project Settings
extends Node

var players: Array[Node] = []
var enemies: Array[Node] = []

func register_player(player: Node) -> void:
	if not players.has(player):
		players.append(player)

func unregister_player(player: Node) -> void:
	players.erase(player)

func register_enemy(enemy: Node) -> void:
	if not enemies.has(enemy):
		enemies.append(enemy)

func unregister_enemy(enemy: Node) -> void:
	enemies.erase(enemy)

## Clear all enemy references and free any still-alive enemy nodes.
## Called at the start of a new run to wipe stale state.
func clear_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()

## Returns only alive, non-downed players
func get_valid_targets() -> Array[Node]:
	# Clean up any freed/invalid player references first
	players = players.filter(func(p): return is_instance_valid(p))
	
	var valid: Array[Node] = []
	for p in players:
		var health := p.get_node_or_null("HealthComponent") as HealthComponent
		if health and health.is_alive():
			valid.append(p)
	return valid
