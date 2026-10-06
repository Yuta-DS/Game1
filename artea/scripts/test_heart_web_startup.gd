extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var result := change_scene_to_file("res://scenes/start_screen.tscn")
	if result != OK:
		_fail("Start screen failed to load")
		return
	await process_frame
	await process_frame
	if current_scene.scene_file_path != "res://scenes/start_screen.tscn":
		_fail("Normal startup must remain on the start screen")
		return
	current_scene.call("_open_heart_preview")
	await process_frame
	await process_frame
	if current_scene.scene_file_path != "res://scenes/heart_melody/heart_melody_world.tscn":
		_fail("Runtime preview transition failed")
		return
	var global := root.get_node("Global")
	if global.auth_token != "OFFLINE_GUEST_TOKEN":
		_fail("Preview must use an offline session")
		return
	print("PASS normal startup and offline Heart preview scene transition")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
