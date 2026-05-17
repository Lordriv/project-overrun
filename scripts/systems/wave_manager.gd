extends Node
## WaveManager — autoloaded singleton.
## FSM: IDLE → EXPLORE → SCOUTING → COMBAT → EXPLORE → (TECH) → repeat

enum State { IDLE, EXPLORE, SCOUTING, COMBAT, TECH }

const SCOUT_SCENE: PackedScene = preload("res://scenes/characters/scout_enemy.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/characters/enemy.tscn")

const SCOUT_KILL_DELAY:  float = 5.0
const WAVE_SPAWN_DELAY:  float = 2.0
const MAX_WAVE_SIZE:     int   = 20
const MAX_CONCURRENT_SPAWNS: int = 4
const SPAWN_INTERVAL:    float = 1.0
const SPAWN_DISPLACEMENT: float = 1.5

var _state: State = State.IDLE
var _spawn_point: Node3D = null
var _current_wave: int = 0
var _scouts: Array = []

signal state_changed(new_state: State)
signal wave_started(wave_number: int, total_enemies: int)
signal wave_completed(wave_number: int)


# --- Public API ---

func begin_explore(spawn_point: Node3D) -> void:
	_spawn_point = spawn_point
	_current_wave = 0
	_set_state(State.EXPLORE)


func stop() -> void:
	_cleanup_scouts()
	EnemyManager.clear_enemies()
	_spawn_point = null
	_state = State.IDLE
	state_changed.emit(State.IDLE)


func stop_run() -> void:
	stop()


func trigger_scouting() -> void:
	if _state != State.EXPLORE:
		return
	_set_state(State.SCOUTING)


func notify_weapon_fired(suppressed: bool) -> void:
	if _state != State.SCOUTING or suppressed:
		return
	_set_state(State.COMBAT)


func notify_scout_retreated() -> void:
	if _state != State.SCOUTING:
		return
	_trigger_wave_after_delay(WAVE_SPAWN_DELAY)


func notify_scout_killed() -> void:
	if _state != State.SCOUTING:
		return
	_scouts = _scouts.filter(func(s): return is_instance_valid(s))
	if _scouts.is_empty():
		_trigger_wave_after_delay(SCOUT_KILL_DELAY)


func enter_tech() -> void:
	if _state != State.EXPLORE:
		return
	_set_state(State.TECH)


func exit_tech() -> void:
	if _state != State.TECH:
		return
	_set_state(State.EXPLORE)


# --- FSM ---

func _set_state(new_state: State) -> void:
	if new_state == _state:
		return
	_state = new_state
	state_changed.emit(_state)
	_enter_state(_state)


func _enter_state(s: State) -> void:
	match s:
		State.EXPLORE:
			_cleanup_scouts()
			_arm_scouting_triggers()
			_check_terminal_active()
		State.SCOUTING:
			_disarm_scouting_triggers()
			_spawn_scouts()
		State.COMBAT:
			_cleanup_scouts()
			call_deferred("_run_wave")
		State.TECH:
			_disarm_scouting_triggers()
		State.IDLE:
			_cleanup_scouts()
			EnemyManager.clear_enemies()


func _check_terminal_active() -> void:
	for terminal in get_tree().get_nodes_in_group("tech_terminal"):
		if terminal.is_active:
			_set_state(State.TECH)
			return


# --- Scouts ---

func _spawn_scouts() -> void:
	_scouts.clear()
	for i in range(2):
		var scout = SCOUT_SCENE.instantiate()
		get_tree().current_scene.add_child(scout)
		var offset := Vector3(
			randf_range(-SPAWN_DISPLACEMENT, SPAWN_DISPLACEMENT),
			0.0,
			randf_range(-SPAWN_DISPLACEMENT, SPAWN_DISPLACEMENT)
		)
		var spawn_pos := _spawn_point.global_position + offset
		scout.setup(spawn_pos)
		scout.retreated.connect(notify_scout_retreated)
		scout.get_node("HealthComponent").died.connect(notify_scout_killed)
		_scouts.append(scout)


func _cleanup_scouts() -> void:
	for s in _scouts:
		if is_instance_valid(s):
			s.queue_free()
	_scouts.clear()


func _trigger_wave_after_delay(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if _state == State.SCOUTING:
		_set_state(State.COMBAT)


# --- Scouting triggers ---

func _arm_scouting_triggers() -> void:
	for trigger in get_tree().get_nodes_in_group("scouting_trigger"):
		trigger.set_armed(true)


func _disarm_scouting_triggers() -> void:
	for trigger in get_tree().get_nodes_in_group("scouting_trigger"):
		trigger.set_armed(false)


# --- Wave ---

func _run_wave() -> void:
	if _state != State.COMBAT:
		return
	_current_wave += 1
	var count := _wave_size(_current_wave)
	wave_started.emit(_current_wave, count)
	await _spawn_wave(count)
	await _wait_for_wave_clear()
	if _state != State.COMBAT:
		return
	if _current_wave > PlayerData.max_wave_reached:
		PlayerData.max_wave_reached = _current_wave
	wave_completed.emit(_current_wave)
	_set_state(State.EXPLORE)


func _wave_size(wave_number: int) -> int:
	return mini(int(pow(2, wave_number - 1)), MAX_WAVE_SIZE)


func _spawn_wave(count: int) -> void:
	var spawned: int = 0
	while spawned < count:
		if _state != State.COMBAT:
			return
		var batch_size: int = mini(MAX_CONCURRENT_SPAWNS, count - spawned)
		for i in range(batch_size):
			_spawn_one_enemy()
			spawned += 1
		if spawned < count:
			await get_tree().create_timer(SPAWN_INTERVAL).timeout


func _spawn_one_enemy() -> void:
	if _spawn_point == null:
		push_error("[WaveManager] Cannot spawn — no spawn point set")
		return
	var enemy = ENEMY_SCENE.instantiate()
	get_tree().current_scene.add_child(enemy)
	var offset := Vector3(
		randf_range(-SPAWN_DISPLACEMENT, SPAWN_DISPLACEMENT),
		0.0,
		randf_range(-SPAWN_DISPLACEMENT, SPAWN_DISPLACEMENT)
	)
	enemy.global_position = _spawn_point.global_position + offset


func _wait_for_wave_clear() -> void:
	while _state == State.COMBAT and EnemyManager.enemies.size() > 0:
		await get_tree().create_timer(0.5).timeout
