extends SceneTree

const OUTPUT_PATH := "res://artifacts/world_one_camera_clearance.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_4X
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") \
		as PackedScene).instantiate()
	root.add_child(gallery)
	current_scene = gallery
	for _frame in 12:
		await process_frame
	var player := gallery.get_node("Player3D") as CharacterBody3D
	var camera := gallery.get_node("Camera3D") as Camera3D
	var world := gallery.get_node(
		"ArtCastleFloatingWorld/MindSparkWorldOne") as MindSparkWorldOne
	player.global_position = world.to_global(
		world.get_zone_position("03_constellation_court") + Vector3.UP * 3.0)
	player.velocity = Vector3.ZERO
	for _frame in 120:
		await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("World One camera-clearance capture requires a rendering display")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Could not save World One camera-clearance capture: %s" % error_string(error))
		quit(1)
		return
	print("WorldOneCameraClearance: PASS — %s" % OUTPUT_PATH)
	quit()
