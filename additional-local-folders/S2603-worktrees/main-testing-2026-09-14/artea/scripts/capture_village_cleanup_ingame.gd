extends SceneTree

const OUTPUT := "res://artifacts/village_cleanup_ingame.png"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/New_Hub_World.tscn") as PackedScene
	var hub := packed.instantiate() as Node3D
	# Keep all village objects and the production brick-overgrowth system. Omit
	# unrelated whole-island scatter and collectible spawning for a quick proof.
	for path in ["Environment/Grass", "Environment/Objects", "AppleSpawner", "ClamSpawner"]:
		var expensive := hub.get_node_or_null(path)
		if expensive != null:
			expensive.get_parent().remove_child(expensive)
			expensive.free()
	root.add_child(hub)
	for layer in hub.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var camera := Camera3D.new()
	camera.fov = 60.0
	camera.far = 500.0
	hub.add_child(camera)
	camera.make_current()
	camera.global_position = Vector3(88.0, 72.0, 38.0)
	camera.look_at(Vector3(72.0, 19.5, -27.0), Vector3.UP)
	for _frame in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var error := root.get_texture().get_image().save_png(OUTPUT)
	if error != OK:
		push_error("VILLAGE_INGAME_CAPTURE: failed: %s" % error_string(error))
		quit(1)
		return
	print("VILLAGE_INGAME_CAPTURE: PASS — wrote %s" % OUTPUT)
	quit()
