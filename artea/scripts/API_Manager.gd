extends Node

const DEFAULT_DESKTOP_BASE_URL := "http://54.252.162.122"
const API_BASE_SETTING := "artea/network/api_base_url"

var auth_token := ""

func get_base_url() -> String:
	var configured_url := str(ProjectSettings.get_setting(API_BASE_SETTING, "")).strip_edges()
	if not configured_url.is_empty():
		return configured_url.trim_suffix("/")
	if OS.get_name() == "Web":
		# Use same-origin HTTPS unless hosting explicitly supplies another API origin.
		# The repository's local static server uses :8765 while Flask uses port 80.
		var browser_url = JavaScriptBridge.eval("""
			window.ARTEA_API_BASE_URL ||
			((window.location.hostname === "127.0.0.1" || window.location.hostname === "localhost") && window.location.port === "8765"
				? window.location.protocol + "//" + window.location.hostname
				: window.location.origin)
		""", true)
		if browser_url is String and not browser_url.is_empty():
			return browser_url.trim_suffix("/")
	return DEFAULT_DESKTOP_BASE_URL

func get_login_url() -> String:
	return get_base_url() + "/login"

func get_register_url() -> String:
	return get_base_url() + "/register"

func get_upload_artwork_url() -> String:
	return get_base_url() + "/upload_artwork"

func get_my_artworks_url() -> String:
	return get_base_url() + "/my_artworks"

func get_ai_chat_url() -> String:
	return get_base_url() + "/ai/chat"

func login(username: String, password: String, callback: Callable) -> void:
	_request_json(get_login_url(), HTTPClient.METHOD_POST, {"username": username, "password": password}, func(success: bool, response_code: int, data):
		if success and response_code == 200 and data is Dictionary and data.has("token"):
			auth_token = str(data["token"])
			callback.call(true, data)
		else:
			callback.call(false, data)
	)

func register(username: String, password: String, callback: Callable) -> void:
	_request_json(get_register_url(), HTTPClient.METHOD_POST, {"username": username, "password": password}, func(success: bool, response_code: int, data):
		callback.call(success and response_code == 201, data)
	)

func chat(messages: Array, callback: Callable) -> void:
	_request_json(get_ai_chat_url(), HTTPClient.METHOD_POST, {"messages": messages}, func(success: bool, response_code: int, data):
		if success and response_code == 200 and data is Dictionary and data.has("reply"):
			callback.call(true, str(data["reply"]))
			return
		var message := "The counselor service is unavailable. Please try again."
		if data is Dictionary and data.has("error"):
			message = str(data["error"])
		callback.call(false, message)
	)

func _request_json(url: String, method: HTTPClient.Method, payload: Dictionary, callback: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		var data = JSON.parse_string(body.get_string_from_utf8())
		if data == null:
			data = {"error": "The server returned an invalid response."}
		callback.call(result == HTTPRequest.RESULT_SUCCESS, response_code, data)
		http.queue_free()
	)
	var error := http.request(url, ["Content-Type: application/json"], method, JSON.stringify(payload))
	if error != OK:
		callback.call(false, 0, {"error": "Could not connect to the server."})
		http.queue_free()
