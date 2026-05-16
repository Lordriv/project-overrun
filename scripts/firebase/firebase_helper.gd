extends Node
# AutoLoad: FirebaseHelper
# Stateless utility for Firebase REST API access.
# Owns the database URL and provides a clean async HTTP helper.

const DATABASE_URL = "https://overrun-3a54d-default-rtdb.asia-southeast1.firebasedatabase.app"

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

# Make a Firebase REST request and await the response.
# Returns: { success: bool, code: int, data: Variant }
# - data is parsed JSON, or null if response was empty/null
# - HTTPRequest is auto-freed after completion (no memory leak)
func request(method: int, path: String, body = null) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)
	
	var headers = ["Content-Type: application/json"]
	var json_body = ""
	if body != null:
		json_body = JSON.stringify(body)
	
	var url = DATABASE_URL + path
	var err = http.request(url, headers, method, json_body)
	
	if err != OK:
		http.queue_free()
		push_error("HTTP request failed to start: " + str(err))
		return {"success": false, "code": -1, "data": null}
	
	var result = await http.request_completed
	http.queue_free()
	
	var response_code = result[1]
	var response_body = result[3]
	
	var parsed = null
	if response_body.size() > 0:
		var body_str = response_body.get_string_from_utf8()
		if body_str != "null" and body_str != "":
			var json = JSON.new()
			if json.parse(body_str) == OK:
				parsed = json.data
	
	return {
		"success": response_code == 200,
		"code": response_code,
		"data": parsed
	}

# Convenience wrappers
func get_data(path: String) -> Dictionary:
	return await request(HTTPClient.METHOD_GET, path)

func put_data(path: String, body) -> Dictionary:
	return await request(HTTPClient.METHOD_PUT, path, body)

func patch_data(path: String, body) -> Dictionary:
	return await request(HTTPClient.METHOD_PATCH, path, body)

func delete_data(path: String) -> Dictionary:
	return await request(HTTPClient.METHOD_DELETE, path)
