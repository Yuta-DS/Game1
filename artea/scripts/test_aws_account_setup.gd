extends SceneTree

func _init() -> void:
	run.call_deferred()

func run() -> void:
	var api = root.get_node("APIManager")
	assert(api.BASE_URL == "http://127.0.0.1:8000", "native local Flask default remains usable")
	assert(root.get_node("Global").SERVER_BASE == api.BASE_URL)
	assert(api.MY_ARTWORKS_URL == api.BASE_URL + "/my_artworks")
	var scene = load("res://scenes/start_screen.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	if OS.get_environment("ARTEA_AUTH_MODE") == "cognito":
		assert(api.uses_managed_accounts())
		var buttons = scene.find_children("*", "Button", true, false)
		assert(buttons.any(func(button): return button.text == "Verify account / reset password"))
	var dialog = scene._account_form("Verification test", ["Verification code"], func(_values, _done): pass)
	assert(dialog.exclusive and dialog.visible)
	assert(dialog.find_children("*", "LineEdit", true, false).size() == 1)
	dialog.queue_free()
	await process_frame
	scene._managed_confirm("test-user")
	await process_frame
	var windows = scene.find_children("*", "Window", true, false)
	assert(not windows.is_empty(), "managed accounts expose email verification")
	print("AWS ACCOUNT SETUP: PASS")
	scene.queue_free()
	await process_frame
	await process_frame
	quit()
