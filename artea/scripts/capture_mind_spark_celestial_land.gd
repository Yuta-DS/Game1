extends SceneTree

const OUTPUT := "res://artifacts/mind_spark_celestial_land"


func _init() -> void:
	call_deferred("_run")


func _shot(camera: Camera3D, at: Vector3, focus: Vector3, size: float, filename: String) -> void:
	camera.size = size
	camera.position = at
	camera.look_at(focus)
	for _frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUTPUT + "/" + filename + ".png")
	assert(error == OK)
	print("CELESTIAL_CAPTURE: " + filename)


func _run() -> void:
	root.size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_celestial_land.json"
	stage.add_child(world)
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).hide()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("d6ddd9")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("f2e7d3")
	environment.ambient_light_energy = 0.3
	var env_node := WorldEnvironment.new()
	env_node.environment = environment
	stage.add_child(env_node)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -32, 0)
	key.light_color = Color("fff2d8")
	key.light_energy = 0.5
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(22, 142, 0)
	fill.light_color = Color("c6dfdf")
	fill.light_energy = 0.2
	stage.add_child(fill)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.5
	camera.far = 8000
	stage.add_child(camera)
	camera.make_current()
	# These are the real runtime land/props/routes, not a concept compositing.
	await _shot(camera, Vector3(0, 2400, 1000), Vector3(0, 0, 30), 1570, "01_six_island_map")
	var landing := world.get_zone_position("01_world_gate_landing")
	await _shot(camera, landing + Vector3(240, 170, 400), landing + Vector3(0, -55, 0), 410, "02_landing_island")
	var forest := world.get_zone_position("02_living_network_forest")
	await _shot(camera, forest + Vector3(340, 190, 540), forest + Vector3(0, -65, 0), 580, "03_living_network_island")
	quit()
