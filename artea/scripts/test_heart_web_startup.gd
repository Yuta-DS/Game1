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
	# Exercise the production offline entry point.  An old branch exposed a
	# private Heart Melody preview method here, but the merged start screen now
	# routes every guest through the integrated World One scene.
	current_scene.call("_on_guest_button_pressed")
	await process_frame
	await process_frame
	if current_scene.scene_file_path != "res://scenes/art_gallery_3d_inprogress.tscn":
		_fail("Offline guest transition to World One failed")
		return
	var global := root.get_node("Global")
	if global.auth_token != "OFFLINE_GUEST_TOKEN":
		_fail("Guest startup must use an offline session")
		return
	print("PASS normal startup and offline guest World One transition")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
