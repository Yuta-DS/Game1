extends Node

var BASE_URL: String = _configured_base_url()
var LOGIN_URL = BASE_URL + "/login"
var REGISTER_URL = BASE_URL + "/register"

var UPLOAD_ARTWORK_URL = BASE_URL + "/upload_artwork"
var MY_ARTWORKS_URL = BASE_URL + "/my_artworks"
var CREATIVE_GUIDE_URL = BASE_URL + "/ai/creative-guide"
var WORLD_BUILDER_URL = BASE_URL + "/ai/world-builder"
var AI_STATUS_URL = BASE_URL + "/ai/status"

var auth_token = ""

var _refresh_token := ""
var _session_generation := 0
var _refresh_timer: SceneTreeTimer

func _configured_base_url() -> String:
	var configured := OS.get_environment("ARTEA_API_BASE").strip_edges().trim_suffix("/")
	if OS.has_feature("web"):
		configured = str(JavaScriptBridge.eval('window.ARTEA_API_BASE || ((location.hostname === "localhost" || location.hostname === "127.0.0.1") ? "http://127.0.0.1:8000" : location.origin + "/api")', true))
	if configured.is_empty(): configured = "http://127.0.0.1:8000"
	if not configured.begins_with("https://") and not configured.begins_with("http://127.0.0.1:") and not configured.begins_with("http://localhost:"):
		push_error("Remote authentication requires HTTPS")
		return "https://invalid.invalid/api"
	return configured

func uses_managed_accounts() -> bool:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.get_interface("window").ARTEA_AUTH_MODE) == "cognito"
	return OS.get_environment("ARTEA_AUTH_MODE") == "cognito"

func login(username: String, password: String, callback: Callable):
	clear_session()
	var generation := _session_generation
	_post_account("/login", {"username": username, "password": password}, func(ok, data):
		if generation != _session_generation: return
		if ok and data is Dictionary and data.has("token"):
			_remember_session(data)
		if callback.is_valid(): callback.call(ok, data)
	)

func register(username: String, password: String, callback: Callable, email := ""):
	_post_account("/register", {"username": username, "password": password, "email": email}, callback)

func confirm_account(username: String, code: String, callback: Callable):
	_post_account("/confirm_registration", {"username": username, "code": code}, callback)

func resend_confirmation(username: String, callback: Callable):
	_post_account("/resend_confirmation", {"username": username}, callback)

func request_password_reset(username: String, callback: Callable):
	_post_account("/forgot_password", {"username": username}, callback)

func reset_password(username: String, code: String, password: String, callback: Callable):
	_post_account("/reset_password", {"username": username, "code": code, "password": password}, callback)

func _remember_session(data: Dictionary) -> void:
	_session_generation += 1
	var generation := _session_generation
	auth_token = str(data.token)
	if data.has("refresh_token"): _refresh_token = str(data.refresh_token)
	if Global.auth_token != "OFFLINE_GUEST_TOKEN": Global.auth_token = auth_token
	if _refresh_token.is_empty(): return
	_refresh_timer = get_tree().create_timer(maxf(30, float(data.get("expires_in", 3600)) - 120))
	_refresh_timer.timeout.connect(func():
		if generation != _session_generation or Global.auth_token == "OFFLINE_GUEST_TOKEN": return
		_post_account("/refresh", {"refresh_token": _refresh_token}, func(ok, response):
			if generation != _session_generation or Global.auth_token == "OFFLINE_GUEST_TOKEN": return
			if ok: _remember_session(response)
			else: clear_session()
		)
	)

func _post_account(path: String, payload: Dictionary, callback: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = 20
	add_child(http)
	http.request_completed.connect(func(result, status, _headers, body):
		var data = JSON.parse_string(body.get_string_from_utf8())
		if not data is Dictionary:
			data = {"error": "Could not reach the account server. Please try again."}
		if callback.is_valid(): callback.call(result == HTTPRequest.RESULT_SUCCESS and status in [200, 201], data)
		http.queue_free()
	)
	var error := http.request(BASE_URL + path, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		http.queue_free()
		if callback.is_valid(): callback.call(false, {"error": "Could not connect to the account server."})


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
			var response = JSON.parse_string(body.get_string_from_utf8())
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
			var response = JSON.parse_string(body.get_string_from_utf8())
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

func clear_session() -> void:
	_session_generation += 1
	_refresh_token = ""
	auth_token = ""
	Global.auth_token = ""
