extends CharacterBody3D
## Scout enemy — approaches the player until in detection range, then retreats
## to its spawn point. Does NOT register with EnemyManager and deals no damage.
## Retreating to spawn triggers wave spawning; being killed delays it by 5s.

@export var move_speed: float  = 6.0
@export var detect_range: float = 8.0

signal retreated

@onready var health: HealthComponent = $HealthComponent

enum ScoutState { APPROACH, RETREAT, DONE }
var _scout_state: ScoutState = ScoutState.APPROACH
var _spawn_position: Vector3


func setup(spawn_pos: Vector3) -> void:
	global_position = spawn_pos
	_spawn_position = spawn_pos


func _ready() -> void:
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if health.is_dead or not is_inside_tree():
		return
	match _scout_state:
		ScoutState.APPROACH: _do_approach(delta)
		ScoutState.RETREAT:  _do_retreat(delta)
	move_and_slide()


func _do_approach(delta: float) -> void:
	var nearest := _nearest_player()
	if nearest == null:
		velocity = Vector3.ZERO
		return
	if global_position.distance_to(nearest.global_position) <= detect_range:
		_scout_state = ScoutState.RETREAT
		return
	_move_toward(nearest.global_position, delta)


func _do_retreat(delta: float) -> void:
	if global_position.distance_to(_spawn_position) < 1.0:
		_scout_state = ScoutState.DONE
		retreated.emit()
		call_deferred("queue_free")
		return
	_move_toward(_spawn_position, delta)


func _move_toward(target: Vector3, delta: float) -> void:
	var dir := global_position.direction_to(target)
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 30.0 * delta


func _nearest_player() -> Node:
	var players := EnemyManager.get_valid_targets()
	var nearest: Node = null
	var nearest_dist: float = INF
	for p in players:
		var d := global_position.distance_to(p.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = p
	return nearest


func _on_died() -> void:
	call_deferred("queue_free")
