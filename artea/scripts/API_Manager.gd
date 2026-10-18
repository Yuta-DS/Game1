extends Node

const BASE_URL = "http://127.0.0.1:8000"
const LOGIN_URL = BASE_URL + "/login"
const REGISTER_URL = BASE_URL + "/register"

const UPLOAD_ARTWORK_URL = BASE_URL + "/upload_artwork"
const MY_ARTWORKS_URL = BASE_URL + "/my_artworks"
const CREATIVE_GUIDE_URL = BASE_URL + "/ai/creative-guide"
const WORLD_BUILDER_URL = BASE_URL + "/ai/world-builder"
const AI_STATUS_URL = BASE_URL + "/ai/status"

var auth_token = ""


func can_reach_configured_backend() -> bool:
	if not OS.has_feature("web"):
		return true
	var backend_url := BASE_URL.to_lower()
	var backend_is_loopback := backend_url.begins_with("http://127.0.0.1") \
		or backend_url.begins_with("http://localhost") \
		or backend_url.begins_with("http://[::1]")
	if not backend_is_loopback:
		return true
	var browser_host := str(JavaScriptBridge.eval("window.location.hostname", true)).to_lower()
	return browser_host in ["localhost", "127.0.0.1", "::1", "[::1]"]

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


# =========================
# CREATIVE GUIDE
# =========================

func request_creative_guide(
	prompt: String,
	artwork: Image,
	title: String,
	callback: Callable
) -> void:
	var encoded_artwork := _prepare_ai_artwork(artwork)
	var payload := {
		"prompt": prompt,
		"title": title,
		"mime_type": str(encoded_artwork.get("mime_type", "image/jpeg"))
	}

	if encoded_artwork.has("artwork_base64"):
		payload["artwork_base64"] = encoded_artwork["artwork_base64"]

	_post_ai_json(CREATIVE_GUIDE_URL, payload, callback)


# =========================
# WORLD BUILDER
# =========================

func request_world_manifest(
	prompt: String,
	creative_brief: Dictionary,
	artwork: Image,
	title: String,
	callback: Callable,
	existing_manifest: Dictionary = {}
) -> void:
	var encoded_artwork := _prepare_ai_artwork(artwork)
	var payload := {
		"prompt": prompt,
		"title": title,
		"creative_brief": creative_brief,
		"existing_manifest": existing_manifest,
		"mime_type": str(encoded_artwork.get("mime_type", "image/jpeg"))
	}

	if encoded_artwork.has("artwork_base64"):
		payload["artwork_base64"] = encoded_artwork["artwork_base64"]

	_post_ai_json(WORLD_BUILDER_URL, payload, callback)


func request_ai_recovery_status(callback: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)

	http.request_completed.connect(
		func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
			# Network/proxy errors can return empty or HTML bodies. Use the
			# existing structured fallback without emitting an engine parse error.
			var decoder := JSON.new()
			var decoded := decoder.parse(body.get_string_from_utf8())
			var response: Variant = decoder.data if decoded == OK else null
			if not response is Dictionary:
				response = {
					"error": "Could not read AI recovery status.",
					"network_result": result
				}
			callback.call(response_code == 200, response)
			http.queue_free()
	)

	var request_error := http.request(AI_STATUS_URL)
	if request_error != OK:
		callback.call(false, {"error": "Could not contact the AI recovery monitor."})
		http.queue_free()


func ai_response_is_degraded(response: Dictionary) -> bool:
	return bool(response.get("degraded", false))


func _post_ai_json(url: String, payload: Dictionary, callback: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = 120.0
	add_child(http)

	http.request_completed.connect(
		func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
			var decoder := JSON.new()
			var decoded := decoder.parse(body.get_string_from_utf8())
			var response: Variant = decoder.data if decoded == OK else null
			if not response is Dictionary:
				response = {
					"error": "The creative AI returned an unreadable response.",
					"network_result": result
				}

			callback.call(response_code == 200, response)
			http.queue_free()
	)

	var token: String = str(auth_token)
	var global := get_node_or_null("/root/Global")
	if token.is_empty() and global != null:
		token = str(global.get("auth_token"))
	var headers := PackedStringArray(["Content-Type: application/json"])
	# Guest play is supported by the loopback-only development server. Sending
	# an empty Bearer value makes Flask-JWT reject the otherwise valid request.
	if _looks_like_jwt(token):
		headers.append("Authorization: Bearer " + token)
	var request_error := http.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if request_error != OK:
		callback.call(false, {"error": "Could not contact the creative AI server."})
		http.queue_free()


func _looks_like_jwt(token: String) -> bool:
	# Guest mode deliberately stores OFFLINE_GUEST_TOKEN in Global. Only a real
	# three-part JWT belongs in Authorization; any placeholder makes
	# Flask-JWT-Extended return 422 before the loopback guest route can run.
	var parts := token.strip_edges().split(".")
	return parts.size() == 3 and not parts[0].is_empty() \
		and not parts[1].is_empty() and not parts[2].is_empty()


func _prepare_ai_artwork(artwork: Image) -> Dictionary:
	if artwork == null or artwork.is_empty():
		return {"mime_type": "image/jpeg"}
	# Image.load() expands JPEGs in memory. Re-encoding that expansion as PNG
	# made castle paintings exceed the server's 8 MB request limit. Work on a
	# duplicate, cap only the AI preview resolution, and preserve the original.
	var preview := artwork.duplicate()
	var max_side := maxi(preview.get_width(), preview.get_height())
	if max_side > 1600:
		var ratio := 1600.0 / float(max_side)
		preview.resize(
			maxi(1, int(preview.get_width() * ratio)),
			maxi(1, int(preview.get_height() * ratio)),
			Image.INTERPOLATE_LANCZOS
		)
	var encoded: PackedByteArray = preview.save_jpg_to_buffer(0.88)
	return {
		"mime_type": "image/jpeg",
		"artwork_base64": Marshalls.raw_to_base64(encoded),
		"encoded_bytes": encoded.size(),
	}
