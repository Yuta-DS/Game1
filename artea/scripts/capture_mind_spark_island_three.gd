extends SceneTree

const OUTPUT_DIR := "res://artifacts/mind_spark_island_three"


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
	world.object_state_store_path = "user://capture_island_three_objects.json"
	stage.add_child(world)
	# Keep the production world construction intact but exclude the first two
	# islands from this dedicated render. This makes the comparison capture
	# deterministic and avoids spending GPU time on geometry behind the camera.
	for zone_name in [
		"01WorldGateLanding", "02LivingNetworkForest",
		"03ConstellationCourt", "03FearGate", "03ProofGate",
		"04HopePathRidge",
	]:
		var zone := world.find_child(zone_name, true, false) as Node3D
		if zone != null:
			zone.visible = false
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a9c8d2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9e4dd")
	environment.ambient_light_energy = 0.56
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.78
	environment.glow_enabled = true
	environment.glow_intensity = 0.18
	environment_node.environment = environment
	stage.add_child(environment_node)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, -38, 0)
	key.light_color = Color("ffe6bd")
	key.light_energy = 1.05
	key.shadow_enabled = false
	stage.add_child(key)
	var camera := Camera3D.new()
	camera.near = 0.3
	camera.far = 3000.0
	camera.fov = 52
	camera.environment = environment
	stage.add_child(camera)
	camera.make_current()
	var experience := world.get_island_three_experience()
	experience.restore_state({"storm_preview_read": false, "rain_started": false,
		"recalled_lights": [], "constellation_links": [], "star_choice": ""}, 8, false)
	camera.position = Vector3(535, 235, 355)
	camera.look_at(Vector3(535, 26, -20), Vector3.UP)
	await _save("01_island_three_storm_overview")
	camera.position = Vector3(374, 30, -58)
	camera.look_at(Vector3(374, 27, -25), Vector3.UP)
	await _save("02_player_approach_storm_reader")
	world.set_return_gate_enabled(false)
	camera.position = Vector3(620, 40, -96)
	camera.look_at(Vector3(733, 35, -27), Vector3.UP)
	await _save("05_heavenly_return_gate_closed")
	world.set_world_state("gentle_rain")
	experience.restore_state({"storm_preview_read": true, "rain_started": true,
		"recalled_lights": MindSparkIslandThreeExperience.LIGHT_IDS.duplicate(),
		"constellation_links": ["notice>evidence", "evidence>perspective", "perspective>choice"],
		"star_choice": "carry_beside"}, 10, true)
	camera.position = Vector3(540, 205, 245)
	camera.look_at(Vector3(620, 28, -65), Vector3.UP)
	await _save("03_restored_sanctuary_overview")
	camera.position = Vector3(610, 28, -6)
	camera.look_at(Vector3(655, 28, -75), Vector3.UP)
	await _save("04_player_approach_oldest_tree")
	world.set_return_gate_enabled(true)
	for _frame in 90:
		await process_frame
	camera.position = Vector3(620, 40, -96)
	camera.look_at(Vector3(733, 35, -27), Vector3.UP)
	await _save("06_heavenly_return_gate_open")
	print("MIND_SPARK_ISLAND_THREE_CAPTURE: PASS")
	quit()


func _save(file_name: String) -> void:
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	assert(root.get_texture().get_image().save_png(path) == OK, "could not save " + path)
	print("MIND_SPARK_ISLAND_THREE_CAPTURE: wrote " + path)
