extends Node3D
## World scene root.
## Reactively spawns/despawns player characters based on SessionManager state.
## Same pattern as lobby.gd, but all players share a single spawn point
## and there's no host/joiner asymmetry.

@onready var player_spawn: Node3D = %PlayerSpawn
@onready var enemy_spawn: Node3D = %EnemySpawn

# Maps player_id → spawned character node
var spawned_characters: Dictionary = {}


func _ready() -> void:
	SessionManager.players_updated.connect(_on_players_updated)
	SessionManager.session_left.connect(_on_session_left)

	# If session data is already populated when we load in, apply it now.
	# DEBUG: F6 / direct-launch fallback. If no session exists, fake one.
	if SessionManager.session_players.is_empty():
		print("[World] No session active — injecting debug solo player")
		SessionManager.session_players = {"debug_player": {"name": "Debug"}}
	if not SessionManager.session_players.is_empty():
		_on_players_updated(SessionManager.session_players)

	WaveManager.begin_explore(enemy_spawn)

	# NEW: start tutorial after world fully loads
	if not PlayerData.tutorial_completed:
		call_deferred("_start_tutorial")


func _start_tutorial() -> void:
	var tutorial = preload("res://scripts/ui/tutorial.gd").new()
	add_child(tutorial)

	# Find player weapon holder
	for node in get_tree().get_nodes_in_group("player"):
		var holder = node.get_node_or_null("WeaponHolder")
		if holder:
			tutorial.set_player(holder)
			break

	tutorial.completed.connect(_on_tutorial_done)


func _on_tutorial_done() -> void:
	PlayerData.tutorial_completed = true


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
	WaveManager.stop_run()

	for player_id in spawned_characters.keys():
		var character = spawned_characters[player_id]
		if is_instance_valid(character):
			character.queue_free()

	spawned_characters.clear()


func _spawn_character_for(player_id: String) -> void:
	if player_spawn == null:
		push_error("[World] PlayerSpawn marker not found")
		return
	var character = PlayerSpawner.spawn_player(player_spawn)
	if character != null:
		spawned_characters[player_id] = character
		print("[World] Spawned character for %s (%d in world)" % [player_id, spawned_characters.size()])
		# Bind self-HUD to the local player only
		if player_id == PlayerAccount.player_id or player_id == "debug_player":
			_bind_hud_to(character)


func _bind_hud_to(character: Node) -> void:
	var HudScript: Script = load("res://scripts/ui/hud.gd")
	var hud: CanvasLayer = HudScript.new()
	hud.name = "HUD"
	add_child(hud)
	await get_tree().process_frame
	if is_instance_valid(character):
		hud.bind_to_player(character)


func _despawn_character_for(player_id: String) -> void:
	var character = spawned_characters.get(player_id)

	if character != null and is_instance_valid(character):
		character.queue_free()

	spawned_characters.erase(player_id)
	print("[World] Despawned character for %s" % player_id)
