extends SceneTree

const OUTPUT_DIR := "res://artifacts/mind_kingdom_integrated"
const SHOTS := [
	{"name": "01_full_world", "eye": Vector3(-3600, 3550, 3940), "look": Vector3(-3600, 0, 3940), "ortho": true, "size": 3300.0},
	{"name": "02_landing_and_server_forest", "eye": Vector3(-1950, 180, 4200), "look": Vector3(-2780, 30, 3300), "ortho": false, "fov": 57.0},
	{"name": "03_living_network_forest", "eye": Vector3(-2600, 120, 2900), "look": Vector3(-2820, 30, 3120), "ortho": false, "fov": 52.0},
	{"name": "04_constellation_and_evidence", "eye": Vector3(-3100, 165, 2700), "look": Vector3(-3550, 45, 3200), "ortho": false, "fov": 55.0},
	{"name": "05_truth_ridge_to_storm", "eye": Vector3(-3400, 210, 4200), "look": Vector3(-4150, 85, 4560), "ortho": false, "fov": 56.0},
	{"name": "06_warden_arena", "eye": Vector3(-4120, 155, 5090), "look": Vector3(-4400, 108, 4820), "ortho": false, "fov": 45.0},
	{"name": "07_oldest_tree_sanctuary", "eye": Vector3(-4350, 190, 4050), "look": Vector3(-4850, 130, 4400), "ortho": false, "fov": 50.0},
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var regions := Node3D.new()
	regions.name = "KingdomRegions3000m"
	regions.set_script(load("res://scripts/art_castle_kingdom_regions.gd"))
	stage.add_child(regions)
	await process_frame
	for kingdom_name in ["HeartKingdom3000m", "CreatorKingdom3000m"]:
		var kingdom := regions.get_node_or_null(kingdom_name) as Node3D
		if kingdom != null:
			kingdom.visible = false
	var world_one := regions.get_node_or_null("MindKingdom3000m/MindSparkWorldOne") as MindSparkWorldOne
	if world_one != null:
		world_one.set_world_state("waking")
		world_one.activate_enemy_wave("network")
		var warden := world_one.get_warden() as MindSparkWardenBoss
		if warden != null:
			warden.start_battle()
	for label in regions.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071126")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("91acd1")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -32, 0)
	sun.light_color = Color("fff0d2")
	sun.light_energy = 1.05
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.near = 0.5
	camera.far = 8000.0
	stage.add_child(camera)
	camera.make_current()
	for _frame in 7:
		await process_frame
	for shot in SHOTS:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL if bool(shot.ortho) else Camera3D.PROJECTION_PERSPECTIVE
		if bool(shot.ortho): camera.size = float(shot.size)
		else: camera.fov = float(shot.fov)
		camera.global_position = shot.eye
		camera.look_at(shot.look, Vector3(0, 0, -1) if bool(shot.ortho) else Vector3.UP)
		for _frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		var output_path := "%s/%s.png" % [OUTPUT_DIR, shot.name]
		var error := root.get_texture().get_image().save_png(output_path)
		if error != OK:
			push_error("MIND_KINGDOM_INTEGRATED_CAPTURE: %s" % error_string(error))
			quit(1)
			return
		print("MIND_KINGDOM_INTEGRATED_CAPTURE: wrote %s" % output_path)
	print("MIND_KINGDOM_INTEGRATED_CAPTURE: PASS")
	quit()
