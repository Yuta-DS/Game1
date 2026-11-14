extends SceneTree
var callbacks := 0
func _init() -> void: run.call_deferred()
func run() -> void:
	var api = root.get_node("APIManager")
	api.login("test", "test", func(_ok, _data): callbacks += 1)
	api.clear_session()
	root.get_node("Global").auth_token = "OFFLINE_GUEST_TOKEN"
	await create_timer(0.8).timeout
	assert(callbacks == 0 and api.auth_token.is_empty(), "late login cannot restore a canceled session")
	assert(root.get_node("Global").auth_token == "OFFLINE_GUEST_TOKEN")
	api.login("test", "test", func(ok, _data):
		assert(ok)
		callbacks += 1
	)
	await create_timer(0.8).timeout
	assert(callbacks == 1 and api.auth_token == "test.access.token")
	api.clear_session()
	assert(api.auth_token.is_empty() and root.get_node("Global").auth_token.is_empty())
	print("AWS ACCOUNT SESSIONS: PASS")
	quit()
