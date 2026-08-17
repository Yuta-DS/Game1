extends SceneTree

const OUTPUT_PATH := "res://artifacts/aether_atlas_removed.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/New_Hub_World.tscn") as PackedScene
	if packed == null:
		push_error("AETHER_ATLAS_CAPTURE: hub scene failed to load")
		quit(1)
		return

	var hub := packed.instantiate() as Node3D
	root.add_child(hub)
	for _frame in 48:
		await process_frame

	for node in hub.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false

	var camera := Camera3D.new()
	camera.fov = 64.0
	camera.far = 900.0
	hub.add_child(camera)
	camera.make_current()
	# Ground-level view aimed directly through the former atlas position.
	camera.global_position = Vector3(24.0, 19.0, 18.0)
	camera.look_at(Vector3(17.0, 34.0, -9.0), Vector3.UP)

	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	if error != OK:
		push_error("AETHER_ATLAS_CAPTURE: failed (%s)" % error_string(error))
		quit(1)
		return

	print("AETHER_ATLAS_CAPTURE: PASS — wrote %s" % OUTPUT_PATH)
	quit()
