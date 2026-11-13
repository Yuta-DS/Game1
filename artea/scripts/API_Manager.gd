extends Node

const SceneLoader := preload("res://scripts/scene_loader.gd")

var BASE_URL: String = _configured_base_url()
var LOGIN_URL = BASE_URL + "/login"
var REGISTER_URL = BASE_URL + "/register"
var ADMIN_RESET_PASSWORD_URL = BASE_URL + "/admin/reset-password"
var RESET_PASSWORD_WITH_CODE_URL = BASE_URL + "/reset-password-with-code"

var UPLOAD_ARTWORK_URL = BASE_URL + "/upload_artwork"
var MY_ARTWORKS_URL = BASE_URL + "/my_artworks"
var CREATIVE_GUIDE_URL = BASE_URL + "/ai/creative-guide"
var WORLD_BUILDER_URL = BASE_URL + "/ai/world-builder"
var AI_STATUS_URL = BASE_URL + "/ai/status"

var auth_token = ""
var SESSION_URL = BASE_URL + "/session"
# One login per account, newest wins (server.py). While signed in the game asks
# every SESSION_CHECK_SECONDS whether this login is still the account's latest;
# when it isn't, it signs out and the start screen shows `sign_out_reason`. At
# 30 s a replaced device kept playing for up to half a minute, which looked like
# it never signed out; the check is one token check and one database read,
# cheap at this rate.
const SESSION_CHECK_SECONDS := 5.0
const START_SCREEN := "res://scenes/start_screen.tscn"
var sign_out_reason := ""
var _watching_session := false
var _last_session_check := 0
var _refresh_token := ""
var _session_generation := 0
var _refresh_timer: SceneTreeTimer


func _configured_base_url() -> String:
	var configured := OS.get_environment("ARTEA_API_BASE").strip_edges().trim_suffix("/")
	if configured.is_empty():
		configured = str(ProjectSettings.get_setting(
			"artea/network/api_base_url", "")).strip_edges().trim_suffix("/")
	return configured if not configured.is_empty() else "http://127.0.0.1:8000"


func uses_managed_accounts() -> bool:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("window.ARTEA_AUTH_MODE || ''", true)) == "cognito"
	return OS.get_environment("ARTEA_AUTH_MODE") == "cognito"


func get_base_url() -> String:
	var configured := str(ProjectSettings.get_setting(
		"artea/network/api_base_url", "")).strip_edges().trim_suffix("/")
	if OS.has_feature("web"):
		var page_setting: Variant = JavaScriptBridge.eval(
			"window.ARTEA_API_BASE_URL || ''", true)
		return _resolve_web_base_url(
			str(JavaScriptBridge.eval("window.location.hostname", true)),
			str(JavaScriptBridge.eval("window.location.origin", true)),
			str(page_setting) if page_setting is String else "", configured)
	if not configured.is_empty():
		return configured
	return BASE_URL


func _resolve_web_base_url(browser_host: String, browser_origin: String,
		page_setting: String, project_setting: String) -> String:
	if not page_setting.strip_edges().is_empty():
		return page_setting.strip_edges().trim_suffix("/")
	if not project_setting.strip_edges().is_empty():
		return project_setting.strip_edges().trim_suffix("/")
	if browser_host.to_lower() in ["localhost", "127.0.0.1", "::1", "[::1]"]:
		return BASE_URL
	# A visitor's loopback address is their own computer. Public Web needs
	# an API on this origin, or an explicit URL from the hosting page.
	return browser_origin.trim_suffix("/")


func get_api_url(path: String) -> String:
	return get_base_url() + path


func get_upload_artwork_url() -> String:
	return get_api_url("/upload_artwork")


func can_reach_configured_backend() -> bool:
	if not OS.has_feature("web"):
		return true
	var backend_url := get_base_url().to_lower()
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
	_watch_session()
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
	var error := http.request(get_api_url(path), ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		http.queue_free()
		if callback.is_valid(): callback.call(false, {"error": "Could not connect to the account server."})

# =========================
# SELF-SERVICE PASSWORD RESET
# =========================

func reset_password_with_code(username: String, recovery_code: String, new_password: String, callback: Callable) -> void:

	var http = HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)

	http.request_completed.connect(
		func(result, response_code, headers, body):

			var json: Variant = JSON.parse_string(body.get_string_from_utf8())
			if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 \
					and json is Dictionary and json.get("token") is String \
					and not str(json["token"]).is_empty():
				auth_token = str(json["token"])
				callback.call(true, json)
			else:
				auth_token = ""
				callback.call(false, _auth_error(result, response_code, json))

			http.queue_free()
	)

	var body_data = {
		"username": username,
		"recovery_code": recovery_code,
		"new_password": new_password
	}

	var json_body = JSON.stringify(body_data)

	var headers = [
		"Content-Type: application/json"
	]

	var request_error := http.request(
		get_api_url("/reset-password-with-code"),
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)
	if request_error != OK:
		callback.call(false, {"error": "Authentication server is unavailable. Use Offline Guest or check the API address."})
		http.queue_free()

# =========================
# ADMIN PASSWORD RESET
# =========================

func admin_reset_password(admin_key: String, username: String, new_password: String, callback: Callable) -> void:

	var http = HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)

	http.request_completed.connect(
		func(result, response_code, headers, body):

			var json: Variant = JSON.parse_string(body.get_string_from_utf8())

			if result == HTTPRequest.RESULT_SUCCESS and response_code == 201:

				callback.call(true, json)

			else:

				callback.call(false, _auth_error(result, response_code, json))

			http.queue_free()
	)

	var body_data = {
		"admin_key": admin_key,
		"username": username,
		"new_password": new_password
	}

	var json_body = JSON.stringify(body_data)

	var headers = [
		"Content-Type: application/json"
	]

	var request_error := http.request(
		get_api_url("/admin/reset-password"),
		headers,
		HTTPClient.METHOD_POST,
		json_body
	)
	if request_error != OK:
		callback.call(false, {"error": "Account service is unavailable. Use Offline Guest or check the API address."})
		http.queue_free()


func _auth_error(result: int, response_code: int, parsed: Variant) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS or response_code == 0:
		return {"error": "Authentication server is unavailable. Use Offline Guest or check the API address."}
	if parsed is Dictionary and parsed.get("error") is String:
		return parsed
	if response_code == 404 or response_code == 200:
		return {"error": "Account service is not configured at this address. Use Offline Guest."}
	return {"error": "Account service failed (HTTP %d). Try again later." % response_code}


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

	_post_ai_json(get_api_url("/ai/creative-guide"), payload, callback)


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

	_post_ai_json(get_api_url("/ai/world-builder"), payload, callback)


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

	var request_error := http.request(get_api_url("/ai/status"))
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

func clear_session() -> void:
	_session_generation += 1
	_refresh_token = ""
	auth_token = ""
	Global.auth_token = ""
	_watching_session = false


func _watch_session() -> void:
	if uses_managed_accounts():
		return  # Cognito manages its own sessions
	# Keeps checking (and its requests running) while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_watching_session = true
	_last_session_check = Time.get_ticks_msec()


# Timed by the clock, not a Timer: a hidden browser tab or a locked phone runs
# no frames, so a Timer would wait out its whole interval again afterwards. The
# first frame back is already overdue here, so it checks straight away.
func _process(_delta: float) -> void:
	if _watching_session \
			and Time.get_ticks_msec() - _last_session_check >= SESSION_CHECK_SECONDS * 1000.0:
		_last_session_check = Time.get_ticks_msec()
		_check_session()


func _check_session() -> void:
	if not _looks_like_jwt(auth_token):
		return
	var generation := _session_generation
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, status, _headers, body):
		http.queue_free()
		# Offline or the server is down: stay signed in and ask again later.
		if generation != _session_generation or result != HTTPRequest.RESULT_SUCCESS or status != 401:
			return
		var data = JSON.parse_string(body.get_string_from_utf8())
		var elsewhere: bool = data is Dictionary and data.get("error") == "signed_in_elsewhere"
		sign_out(
			"You were signed out because this account signed in on another device."
			if elsewhere else "Your sign-in has expired. Please sign in again.")
	)
	if http.request(get_api_url("/session"), ["Authorization: Bearer " + auth_token]) != OK:
		http.queue_free()


## Ends this login and returns to the start screen, which shows `reason`.
func sign_out(reason: String) -> void:
	clear_session()
	sign_out_reason = reason
	SceneLoader.change_scene(get_tree(), START_SCREEN)
