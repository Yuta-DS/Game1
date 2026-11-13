extends SceneTree

const OUTPUT_DIR := "res://artifacts/mind_spark_three_island_world"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage

	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_three_island_world.json"
	stage.add_child(world)
	world.set_world_state("waking")
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071426")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8fa7bf")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.34
	environment_node.environment = environment
	stage.add_child(environment_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -36, 0)
	key.light_color = Color("fff0d0")
	key.light_energy = 1.55
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(24, 145, 180)
	fill.light_color = Color("56c8d6")
	fill.light_energy = 0.62
	stage.add_child(fill)
	var underlight := DirectionalLight3D.new()
	underlight.rotation_degrees = Vector3(42, -18, 180)
	underlight.light_color = Color("d7b575")
	underlight.light_energy = 0.44
	stage.add_child(underlight)

	var camera := Camera3D.new()
	camera.near = 0.5
	camera.far = 6000.0
	stage.add_child(camera)
	camera.make_current()
	for _frame in 12:
		await process_frame

	# Hero overview: all three fused silhouettes, both sky bridges, and the
	# shared machinery/keels remain readable in one frame.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 48.0
	camera.position = Vector3(-80, 760, 1270)
	camera.look_at(Vector3(-45, -35, 10), Vector3.UP)
	await _save("01_three_fused_islands_hero")

	# A more top-down production-map frame proves the paired districts and the
	# exact two-bridge progression path.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 820.0
	camera.position = Vector3(-40, 2100, 410)
	camera.look_at(Vector3(-40, 0, 0), Vector3(0, 0, -1))
	await _save("02_three_island_gameplay_map")

	# Lower profile focuses on the large lift engines and triangulated shared
	# keels, making their structural purpose visible instead of decorative.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 45.0
	camera.position = Vector3(-120, 150, 1330)
	camera.look_at(Vector3(-40, -30, 0), Vector3.UP)
	await _save("03_shared_foundation_machinery")
	print("MIND_SPARK_THREE_ISLAND_CAPTURE: PASS")
	quit()


func _save(file_name: String) -> void:
	for _frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	var error := root.get_texture().get_image().save_png(path)
	assert(error == OK, "could not save %s" % path)
	print("MIND_SPARK_THREE_ISLAND_CAPTURE: wrote %s" % path)
