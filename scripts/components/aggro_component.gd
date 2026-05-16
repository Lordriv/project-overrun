class_name AggroComponent
extends Node
## Child node on every enemy. Tracks threat per player and picks the current target.
## Players generate passive threat over time based on proximity, and threat decays
## for non-current targets.

@export var passive_threat_rate: float = 2.0
@export var retarget_interval: float = 0.5
@export var threat_decay_rate: float = 1.0

var threat_table: Dictionary = {}    # Node (player) → float (threat)
var current_target: Node = null

signal target_changed(new_target: Node)

var _retarget_timer: float = 0.0


func _process(delta: float) -> void:
	_tick_passive_threat(delta)
	_tick_threat_decay(delta)
	
	_retarget_timer += delta
	if _retarget_timer >= retarget_interval:
		_retarget_timer = 0.0
		_evaluate_target()


# --- Threat ticking ---

func _tick_passive_threat(delta: float) -> void:
	# Closest valid player accrues passive threat each frame
	var nearest: Node = _find_nearest_player()
	if nearest != null:
		add_threat(nearest, passive_threat_rate * delta)


func _tick_threat_decay(delta: float) -> void:
	# Non-current targets bleed threat over time
	for player in threat_table.keys():
		if player == current_target:
			continue
		threat_table[player] = maxf(threat_table[player] - threat_decay_rate * delta, 0.0)


func _find_nearest_player() -> Node:
	var valid := EnemyManager.get_valid_targets()
	if valid.is_empty():
		return null
	
	var owner_pos: Vector3 = get_parent().global_position
	var nearest: Node = null
	var nearest_dist: float = INF
	for p in valid:
		var d: float = owner_pos.distance_to(p.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = p
	return nearest


# --- Target selection ---

func _evaluate_target() -> void:
	_prune_invalid_threats()
	
	if threat_table.is_empty():
		_set_current_target(null)
		return
	
	var best: Node = null
	var best_threat: float = -1.0
	for player in threat_table.keys():
		if threat_table[player] > best_threat:
			best_threat = threat_table[player]
			best = player
	_set_current_target(best)


func _prune_invalid_threats() -> void:
	# Drop entries for players who died/disconnected
	var valid := EnemyManager.get_valid_targets()
	for player in threat_table.keys():
		if not valid.has(player):
			threat_table.erase(player)


func _set_current_target(new_target: Node) -> void:
	if new_target == current_target:
		return
	current_target = new_target
	target_changed.emit(new_target)


# --- Public API ---

func add_threat(player: Node, amount: float) -> void:
	if not threat_table.has(player):
		threat_table[player] = 0.0
	threat_table[player] += amount


func taunt(player: Node, threat_bonus: float = 500.0) -> void:
	add_threat(player, threat_bonus)
	_evaluate_target()
