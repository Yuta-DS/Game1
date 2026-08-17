extends SceneTree

const OUTPUT_PATH := "res://artifacts/castle_bridge_underside_fixed.png"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(hub)
	for _frame in 20:
		await process_frame
	for layer in hub.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 54.0
	camera.far = 500.0
	hub.add_child(camera)
	camera.global_position = Vector3(-4.0, 61.0, 42.0)
	camera.look_at(Vector3(-13.1, 68.0, 27.41), Vector3.UP)
	camera.make_current()
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	if error != OK:
		push_error("BRIDGE_UNDERSIDE_CAPTURE: failed %s" % error_string(error))
		quit(1)
		return
	print("BRIDGE_UNDERSIDE_CAPTURE: PASS — %s" % OUTPUT_PATH)
	quit()
