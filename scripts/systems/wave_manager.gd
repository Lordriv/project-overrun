extends Node
## WaveManager — autoloaded singleton.
## Manages enemy waves with staggered spawning.
## Wave size doubles each wave up to MAX_WAVE_SIZE, then holds steady.
## Enemies spawn in batches, max MAX_CONCURRENT_SPAWNS alive at a time.

const ENEMY_SCENE: PackedScene = preload("res://scenes/characters/enemy.tscn")

const WAVE_START_DELAY: float = 2.0
const INTER_WAVE_DELAY: float = 5.0
const SPAWN_INTERVAL: float = 1.0
const MAX_CONCURRENT_SPAWNS: int = 4
const SPAWN_DISPLACEMENT: float = 1.5
const MAX_WAVE_SIZE: int = 20

var _spawn_point: Node3D = null
var _current_wave: int = 0
var _enemies_to_spawn_this_wave: int = 0
var _running: bool = false
var _paused: bool = false

signal wave_started(wave_number: int, total_enemies: int)
signal wave_completed(wave_number: int)


func pause_run() -> void:
	_paused = true


func resume_run() -> void:
	_paused = false


func start_run(spawn_point: Node3D) -> void:
	print("[WaveManager] start_run called. _running=", _running, " _current_wave=", _current_wave, " enemies.size=", EnemyManager.enemies.size())
	if _running:
		push_warning("WaveManager.start_run called while already running")
		return
	EnemyManager.clear_enemies()
	_spawn_point = spawn_point
	_current_wave = 0
	_running = true

	await get_tree().create_timer(WAVE_START_DELAY).timeout

	while _running:
		while _paused and _running:
			await get_tree().create_timer(0.1).timeout
		if not _running:
			break

		_current_wave += 1
		_enemies_to_spawn_this_wave = _wave_size(_current_wave)

		wave_started.emit(_current_wave, _enemies_to_spawn_this_wave)

		await _spawn_wave(_enemies_to_spawn_this_wave)
		await _wait_for_wave_clear()

		if not _running:
			break

		if _current_wave > PlayerData.max_wave_reached:
			PlayerData.max_wave_reached = _current_wave

		wave_completed.emit(_current_wave)

		await get_tree().create_timer(INTER_WAVE_DELAY).timeout


func stop_run() -> void:
	_running = false
	_spawn_point = null


func _wave_size(wave_number: int) -> int:
	return mini(int(pow(2, wave_number - 1)), MAX_WAVE_SIZE)


func _spawn_wave(count: int) -> void:
	var spawned: int = 0
	while spawned < count and _running:
		while _paused and _running:
			await get_tree().create_timer(0.1).timeout
		if not _running:
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
	while _running and EnemyManager.enemies.size() > 0:
		await get_tree().create_timer(0.5).timeout
