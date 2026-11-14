extends SceneTree

const OUTPUT_DIR := "res://builds/user_screenshots"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	current_scene = gallery
	var player := gallery.get_node_or_null("Player3D") as Node3D
	if player != null:
		player.global_position = Vector3(0, 10000, 0)
	for _frame in 80:
		await process_frame
	for layer in gallery.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var camera := gallery.get_node("Camera3D") as Camera3D
	camera.set_script(null)
	camera.fov = 72.0
	camera.far = 8000.0
	camera.make_current()
	var poses := [
		[Vector3(0, 5, 16), Vector3(0, 3, 0), "gallery_interior_central.png"],
		[Vector3(15, 5, 18), Vector3(0, 3, 0), "gallery_interior_east.png"],
		[Vector3(-25, 5, 18), Vector3(-25, 3, 0), "gallery_interior_west.png"],
		[Vector3(0, 8, 25), Vector3(0, 3, 0), "gallery_interior_wide.png"],
	]
	for pose in poses:
		camera.look_at_from_position(pose[0], pose[1], Vector3.UP)
		for _frame in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s" % [OUTPUT_DIR, pose[2]]
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Gallery screenshot failed: %s" % path)
			quit(1)
			return
		print("GALLERY_CAPTURE: %s" % path)
	quit()
