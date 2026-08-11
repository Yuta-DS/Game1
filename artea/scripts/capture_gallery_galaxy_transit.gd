extends SceneTree


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _i in 80:
		await process_frame
	for node in gallery.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	var camera := gallery.get_node("Camera3D") as Camera3D
	camera.set_script(null)
	camera.global_position = Vector3(10.0, 13.0, 31.0)
	camera.look_at(Vector3(-21.5, 3.5, 15.0), Vector3.UP)
	await _save("res://artifacts/art_castle_galaxy_transit.png")
	gallery.queue_free()
	await process_frame

	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _i in 50:
		await process_frame
	for node in hub.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	var inspect := Camera3D.new()
	inspect.fov = 68.0
	hub.add_child(inspect)
	inspect.make_current()
	inspect.global_position = Vector3(-5.0, 55.0, -8.0)
	inspect.look_at(Vector3(-31.0, 50.0, 13.0), Vector3.UP)
	await _save("res://artifacts/castle_stair_clearance.png")
	print("GALAXY_CAPTURE: PASS")
	quit()


func _save(path: String) -> void:
	for _i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("GALAXY_CAPTURE: failed %s" % path)
