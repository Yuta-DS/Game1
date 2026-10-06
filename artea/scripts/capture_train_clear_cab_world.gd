extends SceneTree
## Native capture of the real gallery/world scene using its own player/camera.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1440, 900)
	Engine.max_fps = 30
	var gallery := load("res://scenes/art_gallery_3d_inprogress.tscn").instantiate() as Node3D
	var camera := gallery.get_node("Camera3D") as Camera3D
	camera.set("capture_mouse", false)
	root.add_child(gallery)
	camera.set_process_input(false)
	for i in 6:
		await process_frame
	var player := gallery.get_node("Player3D") as CharacterBody3D
	player.set_process_unhandled_input(false)
	var railway := gallery.get_node("ArtCastleFloatingWorld/StoryCrownRailway") as Node3D
	railway.set_process_unhandled_input(false)
	player.global_position = railway.call("get_driver_interaction_position")
	if not railway.call("board_as_driver"):
		push_error("CLEAR_CAB_WORLD: could not board driver")
		quit(1)
		return
	camera.call("set_view_mode", "first")
	await _save("train_clear_cab_world_station")
	for i in 330:
		railway.call("drive_manual", 1.0, 1.0 / 60.0)
		await process_frame
	await _save("train_clear_cab_world_driving")
	camera.call("set_view_mode", "third")
	await _save("train_clear_cab_world_exterior")
	print("CLEAR_CAB_WORLD: PASS — real world, player, first-person camera and driving screenshots")
	quit()

func _save(label: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://artifacts/" + label + ".png")
	if error != OK:
		push_error("CLEAR_CAB_WORLD: screenshot save failed: " + str(error))
		quit(1)

