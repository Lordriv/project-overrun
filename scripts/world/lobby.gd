extends Node3D
## Lobby scene root.

@onready var host_spawn_point: Node3D = $HostSpawns/TerminalSpawn
@onready var chute_spawns:     Node3D = $ChuteArea/ChuteSpawns

# --- Cinematic ---
@onready var cinematic_cam:   Camera3D = $Cinematic/CinematicCamera
@onready var cinematic_start: Node3D   = $Cinematic/CinematicStart
@onready var wall_plate:      Node3D   = $Cinematic/WallPlate
@onready var cinematic:       Node     = $Cinematic/LobbyIntroCinematic

var spawned_characters: Dictionary = {}
var chute_assignments:  Dictionary = {}
var _cinematic_played:  bool = false


func _ready() -> void:
	SessionManager.players_updated.connect(_on_players_updated)
	SessionManager.session_left.connect(_on_session_left)
	if PlayerAccount.player_id.is_empty():
		await PlayerAccount.player_ready
	if SessionManager.current_session_id.is_empty():
		await SessionManager.create_session("friends")
	if not SessionManager.session_players.is_empty():
		_on_players_updated(SessionManager.session_players)


func _on_cinematic_finished() -> void:
	SquadHUD.show_hud()


func _on_players_updated(players: Dictionary) -> void:
	for player_id in players.keys():
		if not spawned_characters.has(player_id):
			_spawn_character_for(player_id)
	var to_despawn: Array = []
	for player_id in spawned_characters.keys():
		if not players.has(player_id):
			to_despawn.append(player_id)
	for player_id in to_despawn:
		_despawn_character_for(player_id)


func _on_session_left() -> void:
	for player_id in spawned_characters.keys():
		var character = spawned_characters[player_id]
		if is_instance_valid(character):
			character.queue_free()
	spawned_characters.clear()
	chute_assignments.clear()


func _spawn_character_for(player_id: String) -> void:
	var spawn_point: Node3D = _get_spawn_point_for(player_id)
	if spawn_point == null:
		push_error("[Lobby] No spawn point available for player %s" % player_id)
		return
	var character = PlayerSpawner.spawn_player(spawn_point)
	if character == null:
		return
	spawned_characters[player_id] = character

	if player_id == SessionManager.session_host_id and not _cinematic_played:
		# Host — play cinematic, show HUD when it finishes
		_cinematic_played = true
		cinematic.finished.connect(_on_cinematic_finished, CONNECT_ONE_SHOT)
		cinematic.play(cinematic_cam, cinematic_start, wall_plate, [], character)
	elif player_id != SessionManager.session_host_id:
		# Joiner — no cinematic, show HUD immediately
		SquadHUD.show_hud()


func _despawn_character_for(player_id: String) -> void:
	var character = spawned_characters.get(player_id)
	if character != null and is_instance_valid(character):
		character.queue_free()
	spawned_characters.erase(player_id)
	chute_assignments.erase(player_id)


func _get_spawn_point_for(player_id: String) -> Node3D:
	if player_id == SessionManager.session_host_id:
		return host_spawn_point
	if chute_assignments.has(player_id):
		return _get_chute_spawn(chute_assignments[player_id])
	var used_indices: Array = chute_assignments.values()
	for i in range(3):
		if not used_indices.has(i):
			chute_assignments[player_id] = i
			return _get_chute_spawn(i)
	return null


func _get_chute_spawn(index: int) -> Node3D:
	var chute_name: String = "Chute%d" % (index + 1)
	var chute: Node = chute_spawns.get_node_or_null(chute_name)
	if chute == null:
		return null
	return chute.get_node_or_null("SpawnPoint")
