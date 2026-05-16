extends Node
# AutoLoad: FriendsManager
# Owns the friends list and queries their online/session status.

var friends_status_data: Dictionary = {}

signal friends_status_updated(friends_data: Array)

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

# --- Friend list management ---

func add_friend(friend_id: String):
	if friend_id == PlayerAccount.player_id:
		print("⚠️ Cannot add yourself as a friend")
		return
	if PlayerAccount.friends_list.has(friend_id):
		print("⚠️ Already friends with this player")
		return
	
	PlayerAccount.friends_list.append(friend_id)
	PlayerAccount.save()
	print("✅ Added friend: ", friend_id)

func remove_friend(friend_id: String):
	if PlayerAccount.friends_list.has(friend_id):
		PlayerAccount.friends_list.erase(friend_id)
		friends_status_data.erase(friend_id)
		PlayerAccount.save()
		print("🗑️ Removed friend: ", friend_id)
		_emit_update()

# --- Status refresh ---

func refresh_friends_status():
	if PlayerAccount.friends_list.is_empty():
		friends_status_updated.emit([])
		return
	
	# Query each friend in parallel
	for friend_id in PlayerAccount.friends_list:
		_query_friend(friend_id)

func _query_friend(friend_id: String):
	var result = await FirebaseHelper.get_data("/players/" + friend_id + ".json")
	
	# Friend record missing or null body
	if not result.success or result.data == null:
		print("⚠️ Friend record missing or null: ", friend_id)
		friends_status_data[friend_id] = {
			"username": "Unknown (deleted)",
			"online": false,
			"current_session": ""
		}
		_emit_update()
		return
	
	# Got friend data
	friends_status_data[friend_id] = {
		"username": result.data.get("username", "Unknown"),
		"online": result.data.get("online", false),
		"current_session": result.data.get("current_session", "")
	}
	
	# If they're in a session, fetch its details
	var session_id = friends_status_data[friend_id].current_session
	if not session_id.is_empty():
		await _query_friend_session(friend_id, session_id)
	
	_emit_update()

func _query_friend_session(friend_id: String, session_id: String):
	var result = await FirebaseHelper.get_data("/sessions/" + session_id + ".json")
	
	if not result.success or result.data == null:
		# Session was deleted — friend's record is stale
		if friends_status_data.has(friend_id):
			friends_status_data[friend_id]["current_session"] = ""
		return
	
	var data = result.data
	var privacy = data.get("privacy", "private")
	var max_p = data.get("max_players", 4)
	var host = data.get("host", "")
	var players_dict = data.get("players", {})
	var player_count = players_dict.size() if players_dict else 0
	
	if friends_status_data.has(friend_id):
		friends_status_data[friend_id]["session_privacy"] = privacy
		friends_status_data[friend_id]["session_host"] = host
		friends_status_data[friend_id]["session_player_count"] = player_count
		friends_status_data[friend_id]["session_max_players"] = max_p
		# Joinable = not private AND has space
		friends_status_data[friend_id]["is_joinable"] = (privacy != "private") and (player_count < max_p)

func _emit_update():
	# Convert dict to array for easier UI iteration
	var friends_array = []
	for friend_id in PlayerAccount.friends_list:
		if friends_status_data.has(friend_id):
			var data = friends_status_data[friend_id].duplicate()
			data["player_id"] = friend_id
			friends_array.append(data)
	friends_status_updated.emit(friends_array)
