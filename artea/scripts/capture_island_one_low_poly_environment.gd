extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const OUTPUT := "res://artifacts/island_one_low_poly_environment_v44"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.defer_world_build = true
	root.add_child(world)
	world._build_materials()
	var puzzle := MindSparkIslandOnePuzzle.new()
	puzzle.name = "CelestialWorldGateArrival"
	world.add_child(puzzle)
	world._build_island_one_low_poly_environment_finish(puzzle)
	world._add_cylinder(puzzle, "ReviewCourt", Vector3(0, 0.18, 5), 76.0, 0.36,
		world._materials.shared_style_ivory, false, 48)
	for existing in world.find_children("*", "WorldEnvironment", true, false):
		(existing as WorldEnvironment).environment = null
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).hide()
	_add_galaxy_lighting(world)
	for _frame in 12:
		await process_frame

	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.10
	camera.far = 8000.0
	world.add_child(camera)
	camera.make_current()

	# Player-height view back toward the return threshold.
	camera.global_position = puzzle.to_global(Vector3(0, 7.2, -24))
	camera.look_at(puzzle.to_global(Vector3(0, 14.0, -64)), Vector3.UP)
	await _save("01_return_gate_player_view")

	# Opening route into the Signal Observatory.
	camera.global_position = puzzle.to_global(Vector3(0, 7.2, -38))
	camera.look_at(puzzle.to_global(Vector3(0, 14.0, 16)), Vector3.UP)
	await _save("02_observatory_player_approach")

	# Oblique overview proves the route hierarchy and edge planting.
	camera.fov = 52.0
	camera.global_position = puzzle.to_global(Vector3(118, 86, 128))
	camera.look_at(puzzle.to_global(Vector3(0, 7, 8)), Vector3.UP)
	await _save("03_connected_campus_overview")

	# Completed status state: mast beacons and crown are visible together.
	(puzzle.find_child("StatusAnalyzed", true, false) as Node3D).visible = true
	(puzzle.find_child("StatusComplete", true, false) as Node3D).visible = true
	camera.fov = 60.0
	camera.global_position = puzzle.to_global(Vector3(-44, 14, -30))
	camera.look_at(puzzle.to_global(Vector3(0, 25, 9)), Vector3.UP)
	await _save("04_completed_environment_status")
	print("ISLAND_ONE_LOW_POLY_ENVIRONMENT_CAPTURE: PASS")
	quit()


func _add_galaxy_lighting(world: Node3D) -> void:
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = load("res://assets/ArtGallery/background/galaxy.jpg") as Texture2D
	var sky := Sky.new()
	sky.sky_material = panorama
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d8d2e7")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -32, 0)
	key.light_color = Color("fff0d4")
	key.light_energy = 0.92
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, 146, 176)
	fill.light_color = Color("72dce8")
	fill.light_energy = 0.24
	world.add_child(fill)


func _save(file_name: String) -> void:
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT, file_name]
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("ISLAND_ONE_LOW_POLY_ENVIRONMENT_CAPTURE: wrote %s" % path)
