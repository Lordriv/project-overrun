extends Node
# AutoLoad: SessionManager
# Owns the current game session: create, join, leave, and player polling.

const POLL_INTERVAL_SEC = 2.0

var current_session_id: String = ""
var is_host: bool = false
var session_host_id: String = ""
var session_players: Dictionary = {}
var kicked_players: Array = []

var _polling: bool = false
var _was_kicked: bool = false

signal session_created(session_id: String)
signal session_joined(session_id: String)
signal session_left()
signal players_updated(players: Dictionary)
signal kicked_from_session(reason: String)


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS


func create_session(privacy: String = "private") -> bool:
	if PlayerAccount.player_id.is_empty():
		push_error("Cannot create session: No PlayerID")
		return false

	var session_id = _generate_uuid()
	var session_data = {
		"host": PlayerAccount.player_id,
		"host_username": PlayerAccount.player_username,
		"privacy": privacy,
		"max_players": 4,
		"created_at": Time.get_unix_time_from_system(),
		"players": {
			PlayerAccount.player_id: _make_player_entry()
		},
		"kicked_players": []
	}

	var result = await FirebaseHelper.put_data("/sessions/" + session_id + ".json", session_data)

	if result.success:
		current_session_id = session_id
		is_host = true
		session_host_id = PlayerAccount.player_id
		kicked_players = []
		await PlayerAccount.update_session_reference(session_id)
		session_created.emit(session_id)
		_start_polling()
		return true
	else:
		push_error("Failed to create session: " + str(result.code))
		return false


func join_session(session_id: String) -> bool:
	if PlayerAccount.player_id.is_empty():
		push_error("Cannot join session: No PlayerID")
		return false

	if session_id == current_session_id:
		return false

	var kick_check = await FirebaseHelper.get_data("/sessions/" + session_id + "/kicked_players.json")
	if kick_check.success and kick_check.data is Array:
		if PlayerAccount.player_id in kick_check.data:
			kicked_from_session.emit("You were previously kicked from this session")
			return false

	if not current_session_id.is_empty() and current_session_id != session_id:
		await leave_session()

	var result = await FirebaseHelper.put_data(
		"/sessions/" + session_id + "/players/" + PlayerAccount.player_id + ".json",
		_make_player_entry()
	)

	if result.success:
		current_session_id = session_id
		is_host = false
		kicked_players = []
		await PlayerAccount.update_session_reference(session_id)
		session_joined.emit(session_id)
		_start_polling()
		return true
	else:
		push_error("Failed to join session: " + str(result.code))
		return false


func leave_session() -> bool:
	if current_session_id.is_empty():
		return true

	var session_to_leave = current_session_id
	var was_host = is_host

	current_session_id = ""
	session_players = {}
	session_host_id = ""
	kicked_players = []
	is_host = false
	_polling = false

	if was_host:
		await FirebaseHelper.delete_data("/sessions/" + session_to_leave + ".json")
	else:
		await FirebaseHelper.delete_data(
			"/sessions/" + session_to_leave + "/players/" + PlayerAccount.player_id + ".json"
		)

	await PlayerAccount.update_session_reference("")
	session_left.emit()
	return true


func kick_player(target_id: String) -> bool:
	if not is_host:
		push_error("Only the host can kick players")
		return false

	if target_id == PlayerAccount.player_id:
		push_error("Cannot kick yourself")
		return false

	if current_session_id.is_empty():
		push_error("No active session")
		return false

	if not session_players.has(target_id):
		push_error("Target player not in session: " + target_id)
		return false

	var kick_result = await FirebaseHelper.get_data("/sessions/" + current_session_id + "/kicked_players.json")
	var current_kicked = []
	if kick_result.success and kick_result.data is Array:
		current_kicked = kick_result.data

	if not target_id in current_kicked:
		current_kicked.append(target_id)

	var write_result = await FirebaseHelper.put_data(
		"/sessions/" + current_session_id + "/kicked_players.json",
		current_kicked
	)

	if not write_result.success:
		push_error("Failed to update kicked_players list")
		return false

	var remove_result = await FirebaseHelper.delete_data(
		"/sessions/" + current_session_id + "/players/" + target_id + ".json"
	)

	if not remove_result.success:
		push_error("Failed to remove kicked player from session")
		return false

	return true


func update_my_stats(health: int, shield: int):
	if current_session_id.is_empty() or PlayerAccount.player_id.is_empty():
		return
	var data = {"health": health, "shield": shield}
	await FirebaseHelper.patch_data(
		"/sessions/" + current_session_id + "/players/" + PlayerAccount.player_id + ".json",
		data
	)


# --- Polling ---

func _start_polling():
	if _polling:
		return
	_polling = true
	_poll_loop()


func _poll_loop():
	while _polling and not current_session_id.is_empty():
		await _poll_once()
		if not _polling:
			break
		await get_tree().create_timer(POLL_INTERVAL_SEC).timeout


func _poll_once():
	if current_session_id.is_empty():
		return

	var result = await FirebaseHelper.get_data("/sessions/" + current_session_id + ".json")

	if result.success and result.data:
		var fetched_host = result.data.get("host", "")
		if not fetched_host.is_empty():
			session_host_id = fetched_host

		var fetched_kicked = result.data.get("kicked_players", [])
		if fetched_kicked is Array:
			kicked_players = fetched_kicked

		var players = result.data.get("players", {})
		session_players = players if players else {}

		if not is_host and not _was_kicked and not session_players.has(PlayerAccount.player_id):
			_was_kicked = true
			players_updated.emit(session_players)
			_handle_being_kicked()
			return

		players_updated.emit(session_players)
	else:
		session_players = {}
		session_host_id = ""
		current_session_id = ""
		kicked_players = []
		_polling = false
		players_updated.emit({})
		session_left.emit()


func _handle_being_kicked():
	current_session_id = ""
	session_players = {}
	session_host_id = ""
	kicked_players = []
	is_host = false
	_polling = false
	_was_kicked = false

	await PlayerAccount.update_session_reference("")
	kicked_from_session.emit("You were kicked from the session")
	session_left.emit()


# --- Helpers ---

func _make_player_entry() -> Dictionary:
	return {
		"username": PlayerAccount.player_username,
		"health": int(PlayerData.current_hp),
		"shield": int(PlayerData.current_shield),
		"character": "default",
		"ready": false
	}


func _generate_uuid() -> String:
	var uuid = ""
	for i in range(32):
		uuid += "0123456789abcdef"[randi() % 16]
	return uuid


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().set_auto_accept_quit(false)
		await _cleanup_on_exit()
		get_tree().quit()


func _cleanup_on_exit():
	await leave_session()
	await PlayerAccount.mark_offline()
