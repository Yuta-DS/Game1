extends SceneTree

# Visual reference capture for the full 3 km Mind Spark Kingdom embedded in
# the Art Castle Galaxy. These are presentation-only cameras; gameplay and
# authored world geometry are left untouched.

const OUT_DIR := "res://artifacts/mind_spark_world_reference"
const SHOTS := [
	{"name": "01_world_overview_south", "eye": Vector3(-600, 430, 2070), "look": Vector3(-600, 15, 1640), "fov": 60.0},
	{"name": "02_world_overview_north", "eye": Vector3(-600, 410, 1190), "look": Vector3(-600, 18, 1640), "fov": 60.0},
	{"name": "03_world_overview_west", "eye": Vector3(-1050, 360, 1640), "look": Vector3(-600, 20, 1640), "fov": 60.0},
	{"name": "04_world_overview_east", "eye": Vector3(-155, 340, 1640), "look": Vector3(-600, 20, 1640), "fov": 60.0},
	{"name": "05_mind_spark_entry_frame", "eye": Vector3(-760, 42, 1420), "look": Vector3(-692, 35, 1544), "fov": 56.0},
	{"name": "06_rune_tile_constellation", "eye": Vector3(-600, 175, 1850), "look": Vector3(-600, 0, 1640), "fov": 57.0},
	{"name": "07_rune_cube_court", "eye": Vector3(-810, 58, 1730), "look": Vector3(-625, 18, 1665), "fov": 55.0},
	{"name": "08_computer_tower_forest", "eye": Vector3(-815, 76, 1470), "look": Vector3(-665, 35, 1600), "fov": 58.0},
	{"name": "09_living_vines_and_towers", "eye": Vector3(-720, 48, 1515), "look": Vector3(-655, 28, 1620), "fov": 52.0},
	{"name": "10_fear_gate", "eye": Vector3(-835, 48, 1710), "look": Vector3(-718, 25, 1664), "fov": 53.0},
	{"name": "11_proof_gate", "eye": Vector3(-745, 52, 1400), "look": Vector3(-640, 24, 1522), "fov": 53.0},
	{"name": "12_truth_gate", "eye": Vector3(-420, 55, 1425), "look": Vector3(-528, 24, 1535), "fov": 53.0},
	{"name": "13_thought_storm_close", "eye": Vector3(-600, 55, 1495), "look": Vector3(-600, 68, 1640), "fov": 55.0},
	{"name": "14_thought_storm_wide", "eye": Vector3(-405, 155, 1840), "look": Vector3(-600, 55, 1640), "fov": 58.0},
	{"name": "15_oldest_tree_sanctuary", "eye": Vector3(-300, 70, 1780), "look": Vector3(-482, 38, 1685), "fov": 54.0},
	{"name": "16_star_of_wisdom", "eye": Vector3(-355, 92, 1605), "look": Vector3(-482, 67, 1685), "fov": 48.0},
	{"name": "17_floating_island_profile", "eye": Vector3(-980, 30, 1940), "look": Vector3(-600, -25, 1640), "fov": 58.0},
	{"name": "18_mind_spark_hero", "eye": Vector3(-900, 190, 1320), "look": Vector3(-590, 35, 1620), "fov": 57.0},
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	print("MIND_SPARK_REFERENCE: capture start")
	root.size = Vector2i(1536, 864)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	# Reuse the Art Castle Galaxy's authored sky and lighting, but deliberately
	# omit its hub, gallery, Heart and Creator geometry. The kingdom builder is
	# invoked for Mind only so every pixel in this reference set belongs to
	# World One.
	var world := (load("res://scenes/art_castle_floating_world.tscn") as PackedScene).instantiate()
	print("MIND_SPARK_REFERENCE: base world instantiated")
	world.set_script(null)
	var authored_player := world.get_node_or_null("Player3D")
	if authored_player != null:
		authored_player.queue_free()
	var authored_camera := world.get_node_or_null("Camera3D")
	if authored_camera != null:
		authored_camera.queue_free()
	root.add_child(world)
	current_scene = world
	print("MIND_SPARK_REFERENCE: base world attached")

	var mind_world := Node3D.new()
	mind_world.name = "MindSparkWorldCapture"
	mind_world.set_script(load("res://scripts/art_castle_floating_world.gd"))
	mind_world.call("_build_materials")
	print("MIND_SPARK_REFERENCE: materials ready")
	mind_world.call("_build_mind_district")
	print("MIND_SPARK_REFERENCE: district ready")
	mind_world.call("_build_mind_story_landmarks")
	print("MIND_SPARK_REFERENCE: landmarks ready")
	mind_world.set_script(null)
	world.add_child(mind_world)

	# Generated geometry and lighting need a short render warm-up.
	for _frame in 8:
		await process_frame

	var camera := Camera3D.new()
	world.add_child(camera)
	camera.far = 2500.0
	camera.near = 0.2
	camera.make_current()

	for shot in SHOTS:
		camera.fov = float(shot["fov"])
		camera.global_position = shot["eye"] as Vector3
		camera.look_at(shot["look"] as Vector3, Vector3.UP)
		for _frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [OUT_DIR, shot["name"]]
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("MIND_SPARK_REFERENCE: failed %s (%s)" % [path, error_string(error)])
			quit(error)
			return
		print("MIND_SPARK_REFERENCE: wrote %s" % path)

	print("MIND_SPARK_REFERENCE: PASS — wrote %d views" % SHOTS.size())
	quit()
