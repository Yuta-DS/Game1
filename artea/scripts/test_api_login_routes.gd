extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var api := root.get_node("APIManager")
	assert(api.get_base_url() == "http://127.0.0.1:8000")
	assert(api._resolve_web_base_url("localhost", "http://localhost:8801", "", "")
		== "http://127.0.0.1:8000")
	assert(api._resolve_web_base_url("artea-web.vercel.app",
		"https://artea-web.vercel.app", "", "")
		== "https://artea-web.vercel.app",
		"public Web must never send login details to the visitor's localhost")
	assert(api._resolve_web_base_url("artea-web.vercel.app",
		"https://artea-web.vercel.app", "https://api.example.test/", "")
		== "https://api.example.test")
	assert(api._auth_error(HTTPRequest.RESULT_CANT_CONNECT, 0, null).error.contains(
		"unavailable"))
	assert(api._auth_error(HTTPRequest.RESULT_SUCCESS, 200, null).error.contains(
		"not configured"))
	var username := OS.get_environment("ARTEA_TEST_LOGIN_USER")
	var password := OS.get_environment("ARTEA_TEST_LOGIN_PASSWORD")
	if not username.is_empty() and not password.is_empty():
		var successful := await _attempt(api, username, password)
		assert(successful.success and api._looks_like_jwt(api.auth_token),
			"the real Flask login must return a usable token")
		var rejected := await _attempt(api, username, password + "incorrect")
		assert(not rejected.success and str(rejected.data.get("error", "")) == "Invalid credentials")
		assert(api.auth_token.is_empty(), "failed login must clear an old token")
		print("API_LOGIN_ROUTES: PASS — local account login, rejection and URL resolution")
	else:
		print("API_LOGIN_ROUTES: PASS — URL resolution and error mapping (live login skipped)")
	quit()


func _attempt(api: Node, username: String, password: String) -> Dictionary:
	var answer := {"done": false, "success": false, "data": {}}
	api.login(username, password, func(success: bool, data: Variant):
		answer.success = success
		answer.data = data
		answer.done = true)
	var deadline := Time.get_ticks_msec() + 25000
	while not answer.done and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(answer.done, "login callback must finish or report a network error")
	return answer
