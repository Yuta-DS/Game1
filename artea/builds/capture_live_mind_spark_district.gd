extends SceneTree

const OUTPUT_DIR := "res://builds/user_screenshots/mind_spark_walkable_world"
const SHOTS := [
	{"name": "00_gallery_engineered_approach", "eye": Vector3(30, 23, -5), "look": Vector3(0, 2, 96), "fov": 58.0},
	{"name": "01_gallery_to_world_one", "eye": Vector3(-90, 235, 620), "look": Vector3(-340, 10, 1110), "fov": 58.0},
	{"name": "02_world_one_overhead", "eye": Vector3(-600, 430, 1160), "look": Vector3(-600, 0, 1160), "fov": 54.0},
	{"name": "03_walk_in_from_central_tree", "eye": Vector3(-325, 35, 1160), "look": Vector3(-600, 18, 1160), "fov": 58.0},
	{"name": "04_puzzle_and_network_courts", "eye": Vector3(-430, 105, 1325), "look": Vector3(-615, 12, 1160), "fov": 57.0},
	{"name": "05_warden_and_oldest_tree", "eye": Vector3(-790, 90, 1325), "look": Vector3(-610, 28, 1200), "fov": 54.0},
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 16:
		await process_frame
	for canvas in gallery.find_children("*", "CanvasLayer", true, false):
		(canvas as CanvasLayer).visible = false
	var floating_world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var regions := floating_world.get_node_or_null("KingdomRegions3000m") as Node3D
	if regions != null:
		regions.visible = false
	var world_one := floating_world.get_node("MindSparkWorldOne") as MindSparkWorldOne
	world_one.set_world_state("waking")
	world_one.activate_enemy_wave("network")
	var warden := world_one.get_warden() as MindSparkWardenBoss
	if warden != null:
		warden.start_battle()
	var camera := gallery.get_node("Camera3D") as Camera3D
	camera.set_script(null)
	camera.near = 0.2
	camera.far = 4000.0
	camera.make_current()
	for shot in SHOTS:
		camera.fov = float(shot.fov)
		camera.global_position = shot.eye
		camera.look_at(shot.look, Vector3.UP)
		for _frame in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var output := "%s/%s.png" % [OUTPUT_DIR, shot.name]
		var error := root.get_texture().get_image().save_png(output)
		if error != OK:
			push_error("MIND_SPARK_WALKABLE_CAPTURE: %s" % error_string(error))
			quit(1)
			return
		print("MIND_SPARK_WALKABLE_CAPTURE: wrote %s" % output)
	print("MIND_SPARK_WALKABLE_CAPTURE: PASS")
	quit()
