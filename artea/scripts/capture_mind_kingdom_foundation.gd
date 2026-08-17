extends SceneTree

# Inspection capture of the authored 3 km Mind Kingdom foundation. The
# standalone MindSparkWorldOne prototype is hidden deliberately so placement
# decisions are based only on the Galaxy land, courts, paths, and station.

const OUTPUT_DIR := "res://artifacts/mind_kingdom_foundation"
const SHOTS := [
	{"name": "01_authored_land_birdseye", "eye": Vector3(-3600, 3550, 3940), "look": Vector3(-3600, 0, 3940), "ortho": true, "size": 3300.0},
	{"name": "02_station_to_forest", "eye": Vector3(-1880, 170, 4140), "look": Vector3(-2700, 18, 3300), "ortho": false, "fov": 58.0},
	{"name": "03_forest_to_constellation", "eye": Vector3(-2600, 145, 2860), "look": Vector3(-3400, 25, 3100), "ortho": false, "fov": 56.0},
	{"name": "04_three_gate_ridge", "eye": Vector3(-3300, 190, 3720), "look": Vector3(-3950, 48, 3930), "ortho": false, "fov": 57.0},
	{"name": "05_storm_and_oldest_tree", "eye": Vector3(-3500, 260, 5050), "look": Vector3(-4550, 90, 4620), "ortho": false, "fov": 55.0},
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
	var prototype := regions.get_node_or_null("MindKingdom3000m/MindSparkWorldOne") as Node3D
	if prototype != null:
		prototype.visible = false
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("081126")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("91acd1")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -32, 0)
	sun.light_color = Color("fff0d2")
	sun.light_energy = 1.0
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.near = 0.5
	camera.far = 8000.0
	stage.add_child(camera)
	camera.make_current()
	for _frame in 5:
		await process_frame
	for shot in SHOTS:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL if bool(shot.ortho) else Camera3D.PROJECTION_PERSPECTIVE
		if bool(shot.ortho):
			camera.size = float(shot.size)
		else:
			camera.fov = float(shot.fov)
		camera.global_position = shot.eye
		camera.look_at(shot.look, Vector3(0, 0, -1) if bool(shot.ortho) else Vector3.UP)
		for _frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var output_path := "%s/%s.png" % [OUTPUT_DIR, shot.name]
		var error := root.get_texture().get_image().save_png(output_path)
		if error != OK:
			push_error("MIND_KINGDOM_FOUNDATION_CAPTURE: %s" % error_string(error))
			quit(1)
			return
		print("MIND_KINGDOM_FOUNDATION_CAPTURE: wrote %s" % output_path)
	print("MIND_KINGDOM_FOUNDATION_CAPTURE: PASS")
	quit()
