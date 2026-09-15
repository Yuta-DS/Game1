extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var island_one := "--island-one" in OS.get_cmdline_user_args()
	var capture_id := "island_one" if island_one else "island_two"
	root.size = Vector2i(1600, 1000)
	root.msaa_3d = Viewport.MSAA_4X
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_%s_overview.json" % capture_id
	world.get_node("QuestController").enabled = false
	root.add_child(world)
	if not island_one:
		world.set_island_two_story_state("truth_materialised")
		world.set_quest_gate_open(1, true)
	if ResourceLoader.exists("res://scenes/art_castle_floating_world.tscn"):
		var containing := load("res://scenes/art_castle_floating_world.tscn").instantiate() as Node3D
		for name in ["WorldEnvironment", "Sun", "FillLight"]:
			var node := containing.get_node(name)
			containing.remove_child(node)
			node.owner = null
			root.add_child(node)
		containing.free()
	else:
		var environment_node := WorldEnvironment.new()
		var environment := Environment.new()
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color("82b8d2")
		sky_material.sky_horizon_color = Color("e8d8bf")
		sky_material.ground_bottom_color = Color("6f8c95")
		sky_material.ground_horizon_color = Color("ead9bf")
		sky_material.sun_angle_max = 18.0
		var sky := Sky.new()
		sky.sky_material = sky_material
		environment.background_mode = Environment.BG_SKY
		environment.sky = sky
		environment.background_energy_multiplier = 0.78
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("b7d3cf")
		environment.ambient_light_energy = 0.58
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		environment.tonemap_exposure = 0.82
		environment_node.environment = environment
		root.add_child(environment_node)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-48, -32, 0)
		sun.light_color = Color("ffe5b4")
		sun.light_energy = 0.90
		sun.shadow_enabled = true
		root.add_child(sun)
	for pattern in ["Inlay_v11_*", "SharedCelestialPaving", "MSI1_Runtime_*", "WalkableZoneFloor"]:
		if "--hide=" + pattern in OS.get_cmdline_user_args():
			for mesh in world.find_children(pattern,"Node3D",true,false):
				mesh.visible = false
	# Presentation-only suppression of floating text for this overview.
	for label in world.find_children("*", "Label3D", true, false):
		label.visible = false
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 350
	camera.far = 6000
	camera.near = 5.0
	root.add_child(camera)
	var center := world.get_zone_position("03_constellation_court").lerp(world.get_zone_position("04_hope_path_ridge"), .5)
	if island_one:
		center = world.get_zone_position("01_world_gate_landing").lerp(world.get_zone_position("02_living_network_forest"), .5)
	camera.position = center + Vector3(120, 330, 520)
	camera.look_at(center + Vector3(0, 2, 0))
	camera.make_current()
	await create_timer(1.2).timeout
	RenderingServer.force_draw(false)
	var output := "res://artifacts/%s_overview" % capture_id
	if "--diagnostic" in OS.get_cmdline_user_args():
		output += "_diagnostic"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	assert(root.get_texture().get_image().save_png(output + "/overview.png") == OK)
	if not island_one:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.near = .1
		camera.fov = 52
		var evidence := world.get_zone_position("03_constellation_court")
		camera.position = evidence + Vector3(135, 92, 185)
		camera.look_at(evidence + Vector3(0, 12, 0))
		await create_timer(1.0).timeout
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(output + "/evidence_observatory.png") == OK)
		var hope := world.get_zone_position("04_hope_path_ridge")
		camera.position = hope + Vector3(-120, 78, 170)
		camera.look_at(hope + Vector3(0, 8, 12))
		await create_timer(1.0).timeout
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(output + "/hope_gallery.png") == OK)
		var zones: Dictionary = world.get("_zone_nodes")
		var arrival := (zones["03_constellation_court"] as Node3D).get_node("FearGate") as Node3D
		camera.fov = 58
		camera.position = arrival.global_position + arrival.global_basis.z.normalized() * 68.0 + Vector3.UP * 14.0
		camera.look_at(arrival.global_position + Vector3(0, 20, 0))
		await create_timer(1.0).timeout
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(output + "/arrival_portico.png") == OK)
		var memory_gate := world.get_node(
			"WorldOneGeometry/SavedQuestProgressionGates/QuestGate_2") as Node3D
		var departure := world.get_node("WorldOneGeometry/SavedQuestProgressionGates/QuestGate_3") as Node3D
		camera.position = departure.to_global(Vector3(0, 10, -36))
		camera.look_at(departure.global_position + Vector3.UP * 9)
		world.set_quest_gate_open(2, false)
		await create_timer(2.5).timeout
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(output + "/departure_gate.png") == OK)
		camera.fov = 60
		# Stand inside the operator apron rather than behind the promenade pylon;
		# this is the unobstructed player read of the moving leaves.
		camera.position = memory_gate.global_position + memory_gate.global_basis.z * 30.0 + Vector3.UP * 8.0
		camera.look_at(memory_gate.global_position + Vector3.UP * 9.0)
		world.set_quest_gate_open(1, false)
		await create_timer(2.5).timeout
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(output + "/memory_gate_closed.png") == OK)
		world.set_quest_gate_open(1, true)
		await create_timer(2.5).timeout
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(output + "/memory_gate.png") == OK)
		var projector := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
		projector.interaction_enabled = true
		assert(projector.interact(&"approach", 0).accepted)
		var actor := Node3D.new()
		world.add_child(actor)
		actor.global_position = projector.to_global(Vector3(0, .2, 16))
		camera.near = 0.1
		camera.global_position = projector.to_global(Vector3(0, 8, 16))
		camera.look_at(projector.to_global(Vector3(0, 4, 0)))
		var panel := preload("res://scripts/mind_spark/island_two_station_panel.gd").new()
		world.add_child(panel)
		panel.open_object(projector, actor, 18)
		await create_timer(.5).timeout
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(output + "/garden_puzzle_controls.png") == OK)
		panel.queue_free()
		await process_frame
		for adjustment in [0, 0, 1]: assert(projector.interact(&"tune", adjustment).accepted)
		assert(projector.interact(&"project").completed)
		var garden := world.get_node("GardenOfUnfinishedLight/ConservatoryOfPossibleTomorrow") as Node3D
		camera.position = garden.global_position + Vector3(58, 40, 80)
		camera.look_at(garden.global_position + Vector3.UP * 13)
		await create_timer(1.5).timeout
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(output + "/restored_conservatory.png") == OK)
	if island_one:
		var hero := world.find_child("EchoGardenHeroBenchmark", true, false) as Node3D
		if hero != null:
			camera.size = 190
			camera.position = hero.global_position + Vector3(70, 110, 180)
			camera.look_at(hero.global_position + Vector3(0, 20, 0))
			for frame in 15:
				await process_frame
			RenderingServer.force_draw(false)
			assert(root.get_texture().get_image().save_png(output + "/echo_garden_detail.png") == OK)
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.near = .1
			camera.fov = 65
			camera.position = hero.global_position + Vector3(50, 5, 100)
			camera.look_at(hero.global_position + Vector3(0, 20, 0))
			await create_timer(1.2).timeout
			RenderingServer.force_draw(false)
			assert(root.get_texture().get_image().save_png(output + "/garden_player_height.png") == OK)
	if not island_one:
		var shared := world.get_node("WorldOneGeometry/IslandTwoPerimeterRepairs/ReferencePost_2_12") as Node3D
		var anchor: Vector3 = world.call("_perimeter_post_anchor", shared)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.near = .1
		camera.fov = 55
		camera.global_position = anchor + Vector3(32, 16, 38)
		camera.look_at(anchor)
		await create_timer(.7).timeout
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(output + "/shared_lantern_pier.png") == OK)
	world.queue_free()
	await process_frame
	var store := "user://capture_%s_overview.json" % capture_id
	if FileAccess.file_exists(store):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store))
	print("%s_OVERVIEW: captured current local world; labels hidden" % capture_id.to_upper())
	quit()
