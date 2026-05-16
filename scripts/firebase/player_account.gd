extends Node
# AutoLoad: PlayerAccount
# Owns the local player's identity, persistence, and online status.

const SAVE_PATH = "user://player_data.json"

var player_id: String = ""
var player_username: String = ""
var friends_list: Array = []

signal player_ready(player_id: String)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_or_create_player_id()
	# Wait one frame so other AutoLoads are ready
	await get_tree().process_frame
	await register_in_database()
	player_ready.emit(player_id)

func _load_or_create_player_id():
	print("💾 Using save file: ", SAVE_PATH)
	
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		var json = JSON.new()
		var parse_result = json.parse(file.get_as_text())
		file.close()
		
		if parse_result == OK:
			var data = json.data
			player_id = data.get("player_id", "")
			player_username = data.get("username", "")
			friends_list = data.get("friends", [])
	
	if player_id.is_empty():
		player_id = _generate_uuid()
		player_username = "Player_" + player_id.substr(0, 6)
		save()
	
	print("✅ PlayerID: ", player_id)
	print("👤 Username: ", player_username)

func save():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var data = {
		"player_id": player_id,
		"username": player_username,
		"friends": friends_list
	}
	file.store_string(JSON.stringify(data))
	file.close()

func _generate_uuid() -> String:
	var uuid = ""
	for i in range(32):
		uuid += "0123456789abcdef"[randi() % 16]
	return uuid

# Register player as online in Firebase
func register_in_database() -> bool:
	print("📝 Registering player in Firebase...")
	var data = {
		"username": player_username,
		"online": true,
		"current_session": "",
		"last_seen": Time.get_unix_time_from_system()
	}
	var result = await FirebaseHelper.put_data("/players/" + player_id + ".json", data)
	if result.success:
		print("✅ Player registered in Firebase!")
	else:
		push_error("❌ Failed to register: " + str(result.code))
	return result.success

# Mark player as offline (called on game exit)
func mark_offline() -> bool:
	var data = {
		"online": false,
		"current_session": "",
		"last_seen": Time.get_unix_time_from_system()
	}
	var result = await FirebaseHelper.patch_data("/players/" + player_id + ".json", data)
	return result.success

# Update the player's current_session field
func update_session_reference(session_id: String) -> bool:
	var result = await FirebaseHelper.put_data(
		"/players/" + player_id + "/current_session.json",
		session_id
	)
	return result.success
