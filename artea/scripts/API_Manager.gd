extends Node

const FALLBACK_API_BASE := "http://54.252.162.122"

var BASE_URL := FALLBACK_API_BASE
var LOGIN_URL := BASE_URL + "/login"
var REGISTER_URL := BASE_URL + "/register"
var UPLOAD_ARTWORK_URL := BASE_URL + "/upload_artwork"
var MY_ARTWORKS_URL := BASE_URL + "/my_artworks"
var AI_CHAT_URL := BASE_URL + "/ai/chat"

var auth_token = ""

func _enter_tree() -> void:
	BASE_URL = _resolve_api_base()
	LOGIN_URL = BASE_URL + "/login"
	REGISTER_URL = BASE_URL + "/register"
	UPLOAD_ARTWORK_URL = BASE_URL + "/upload_artwork"
	MY_ARTWORKS_URL = BASE_URL + "/my_artworks"
	AI_CHAT_URL = BASE_URL + "/ai/chat"

func _resolve_api_base() -> String:
	if not OS.has_feature("web"):
		return FALLBACK_API_BASE

	# HTTPS pages cannot call the legacy HTTP endpoint. Production hosting
	# proxies /api to Flask; local HTTP builds keep using the development API.
	var resolved = JavaScriptBridge.eval("""
		(() => {
			const configured = globalThis.ARTEA_API_BASE;
			if (typeof configured === 'string' && configured.length > 0) {
				return configured;
			}
			return location.protocol === 'https:'
				? location.origin + '/api'
				: 'http://54.252.162.122';
		})()
	""", true)
	return str(resolved).trim_suffix("/")

# =========================
# LOGIN
# =========================

func login(username: String, password: String, callback: Callable):

	var http = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(
		func(result, response_code, headers, body):

			var json = JSON.parse_string(body.get_string_from_utf8())

			if response_code == 200:

				auth_token = json["token"]

				callback.call(true, json)

			else:

				callback.call(false, json)

			http.queue_free()
	)

	var body_data = {
		"username": username,
		"password": password
	}

	var json_body = JSON.stringify(body_data)

	var headers = [
		"Content-Type: application/json"
	]

	http.request(
		BASE_URL + "/login",
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)

# =========================
# REGISTER
# =========================

func register(username: String, password: String, callback: Callable):

	var http = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(
		func(result, response_code, headers, body):

			var json = JSON.parse_string(body.get_string_from_utf8())

			if response_code == 201:

				callback.call(true, json)

			else:

				callback.call(false, json)

			http.queue_free()
	)

	var body_data = {
		"username": username,
		"password": password
	}

	var json_body = JSON.stringify(body_data)

	var headers = [
		"Content-Type: application/json"
	]

	http.request(
		BASE_URL + "/register",
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)
