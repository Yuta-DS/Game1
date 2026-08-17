extends SceneTree

const OUTPUT_DIR := "res://artifacts/mind_spark_island_foundations"
const ZONE_SHOTS := [
	{"id": "01_world_gate_landing", "name": "01_world_gate_landing", "orbit": 0.28},
	{"id": "02_living_network_forest", "name": "02_living_network_forest", "orbit": -0.36},
	{"id": "03_constellation_court", "name": "03_constellation_court", "orbit": 0.52},
	{"id": "04_hope_path_ridge", "name": "04_hope_path_ridge", "orbit": -0.62},
	{"id": "05_thought_storm_arena", "name": "05_thought_storm_arena", "orbit": 0.82},
	{"id": "06_oldest_tree_sanctuary", "name": "06_oldest_tree_sanctuary", "orbit": -0.18},
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	print("MIND_SPARK_ISLAND_FOUNDATIONS: start")
	root.size = Vector2i(1400, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var stage := Node3D.new()
	stage.name = "MindSparkIslandFoundationProofStage"
	root.add_child(stage)
	current_scene = stage

	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_mind_spark_foundation_proof.json"
	stage.add_child(world)
	world.set_world_state("waking")
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("061126")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7299c6")
	environment.ambient_light_energy = 0.54
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.54
	environment_node.environment = environment
	stage.add_child(environment_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -34, 0)
	key.light_color = Color("fff0d2")
	key.light_energy = 1.35
	key.shadow_enabled = true
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-24, 146, 0)
	rim.light_color = Color("3adff5")
	rim.light_energy = 0.72
	stage.add_child(rim)
	var under_fill := DirectionalLight3D.new()
	under_fill.rotation_degrees = Vector3(34, -22, 180)
	under_fill.light_color = Color("4fdcf2")
	under_fill.light_energy = 0.62
	stage.add_child(under_fill)

	var camera := Camera3D.new()
	camera.near = 0.5
	camera.far = 7000.0
	stage.add_child(camera)
	camera.make_current()
	for _frame in 10:
		await process_frame

	# One cartographic proof frame shows that all six gameplay islands were
	# rebuilt while the bridge topology and relative sizes remain unchanged.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1520.0
	camera.position = Vector3(0, 2450, 40)
	camera.look_at(Vector3(0, 35, 40), Vector3(0, 0, -1))
	await _save_frame(camera, "00_all_six_islands_overview")
	await _save_frame(camera, "27_organized_100_tree_world_overview")

	# Dedicated grove frames prove that the tree population is deliberately
	# composed around gameplay spaces rather than scattered randomly.
	var forest_position := world.get_zone_position("02_living_network_forest")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 49.0
	camera.position = forest_position + Vector3(-250, 172, 282)
	camera.look_at(forest_position + Vector3(0, 24, 0), Vector3.UP)
	await _save_frame(camera, "28_living_network_organized_grove")
	var organized_sanctuary_position := world.get_zone_position("06_oldest_tree_sanctuary")
	camera.fov = 48.0
	camera.position = organized_sanctuary_position + Vector3(-250, 164, 292)
	camera.look_at(organized_sanctuary_position + Vector3(0, 35, 18), Vector3.UP)
	await _save_frame(camera, "29_oldest_tree_guardian_ring")

	# One close three-quarter view per island proves the top surface, segmented
	# rim, suspended crystals and tapered underside rather than only a map view.
	for shot in ZONE_SHOTS:
		var zone_position := world.get_zone_position(str(shot.id))
		var radius := world.get_zone_radius(str(shot.id))
		var angle := float(shot.orbit)
		var horizontal := radius * 1.55
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 47.0
		camera.position = zone_position + Vector3(sin(angle) * horizontal,
			radius * 0.78, cos(angle) * horizontal)
		camera.look_at(zone_position + Vector3(0, -radius * 0.08, 0), Vector3.UP)
		await _save_frame(camera, str(shot.name))

	# A lower profile makes the six different underbody depths and crystal
	# layouts readable in one final proof image.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 54.0
	camera.position = Vector3(-1120, 86, 1030)
	camera.look_at(Vector3(-20, 2, -20), Vector3.UP)
	await _save_frame(camera, "07_route_and_floating_undersides")
	var storm_position := world.get_zone_position("05_thought_storm_arena")
	camera.fov = 44.0
	camera.position = storm_position + Vector3(-245, 8, 292)
	camera.look_at(storm_position + Vector3(0, -28, 0), Vector3.UP)
	await _save_frame(camera, "08_storm_island_underbody_detail")
	var sanctuary_position := world.get_zone_position("06_oldest_tree_sanctuary")
	camera.fov = 42.0
	camera.position = sanctuary_position + Vector3(-104, 62, 128)
	camera.look_at(sanctuary_position + Vector3(0, 39, 18), Vector3.UP)
	await _save_frame(camera, "14_oldest_tree_root_outlayer_detail")
	await _save_frame(camera, "17_tree_root_energy_transfer_phase_a")
	for _frame in 120:
		await process_frame
	await _save_frame(camera, "18_tree_root_energy_transfer_phase_b")
	camera.fov = 46.0
	camera.position = sanctuary_position + Vector3(0, 172, 18)
	camera.look_at(sanctuary_position + Vector3(0, 62, 18), Vector3(0, 0, -1))
	await _save_frame(camera, "19_bio_data_tree_canopy_top")
	camera.fov = 38.0
	camera.position = sanctuary_position + Vector3(-46, 30, 70)
	camera.look_at(sanctuary_position + Vector3(0, 34, 18), Vector3.UP)
	await _save_frame(camera, "20_bio_data_tree_trunk_fiber_detail")
	camera.fov = 34.0
	camera.position = sanctuary_position + Vector3(-74, 72, 92)
	camera.look_at(sanctuary_position + Vector3(0, 64, 18), Vector3.UP)
	await _save_frame(camera, "21_bio_data_tree_cap_leaf_node_detail")
	camera.fov = 31.0
	camera.position = sanctuary_position + Vector3(-34, 95, 66)
	camera.look_at(sanctuary_position + Vector3(0, 90, 18), Vector3.UP)
	await _save_frame(camera, "22_bio_data_tree_crown_crystal_detail")
	camera.fov = 31.0
	camera.position = sanctuary_position + Vector3(52, 57, 72)
	camera.look_at(sanctuary_position + Vector3(12, 61, 18), Vector3.UP)
	await _save_frame(camera, "23_bio_data_tree_leaf_hanging_node_detail")
	# Isolate the living tree from the sanctuary foundation for art-direction
	# review. This changes visibility only inside the proof process, never the
	# actual game scene or the island base implementation.
	var geometry := world.get_node("WorldOneGeometry") as Node3D
	var sanctuary_zone := geometry.get_node("06OldestTreeSanctuary") as Node3D
	var hidden_tree_proof_zones: Array[Node3D] = []
	for zone_child in geometry.get_children():
		if zone_child != sanctuary_zone and zone_child is Node3D \
				and (zone_child as Node3D).visible:
			hidden_tree_proof_zones.append(zone_child as Node3D)
			(zone_child as Node3D).visible = false
	var hidden_sanctuary_parts: Array[Node3D] = []
	for sanctuary_child in sanctuary_zone.get_children():
		if sanctuary_child.name != &"MindSparkBioDataTree" \
				and sanctuary_child is Node3D and (sanctuary_child as Node3D).visible:
			hidden_sanctuary_parts.append(sanctuary_child as Node3D)
			(sanctuary_child as Node3D).visible = false
	camera.fov = 36.0
	camera.position = sanctuary_position + Vector3(-112, 62, 154)
	camera.look_at(sanctuary_position + Vector3(0, 51, 18), Vector3.UP)
	await _save_frame(camera, "24_bio_data_tree_full_growth_isolated")
	camera.fov = 29.0
	camera.position = sanctuary_position + Vector3(-27, 11, 43)
	camera.look_at(sanctuary_position + Vector3(0, 2.7, 18), Vector3.UP)
	await _save_frame(camera, "26_bio_data_tree_base_socket_detail")
	camera.fov = 38.0
	camera.position = sanctuary_position + Vector3(-72, 105, 112)
	camera.look_at(sanctuary_position + Vector3(0, 70, 18), Vector3.UP)
	await _save_frame(camera, "25_bio_data_tree_branch_leaf_crown_isolated")
	for hidden_part in hidden_sanctuary_parts:
		hidden_part.visible = true
	for hidden_zone in hidden_tree_proof_zones:
		hidden_zone.visible = true
	for child in geometry.get_children():
		if child != geometry.get_node("05ThoughtStormArena"):
			(child as Node3D).visible = false
	var storm_zone := geometry.get_node("05ThoughtStormArena") as Node3D
	for child in storm_zone.get_children():
		if child.name not in [&"WalkableZoneFloor", &"ModularFloatingFoundation"]:
			(child as Node3D).visible = false
	camera.fov = 38.0
	camera.position = storm_position + Vector3(-220, -46, 300)
	camera.look_at(storm_position + Vector3(0, -34, 0), Vector3.UP)
	await _save_frame(camera, "09_isolated_magitech_levitation_layout")
	camera.fov = 34.0
	camera.position = storm_position + Vector3(-120, 175, 205)
	camera.look_at(storm_position + Vector3(0, 0, 0), Vector3.UP)
	await _save_frame(camera, "10_isolated_deck_texture_detail")
	await _save_frame(camera, "12_surface_network_animation_phase_a")
	for _frame in 180:
		await process_frame
	await _save_frame(camera, "13_surface_network_animation_phase_b")
	camera.fov = 28.0
	camera.position = storm_position + Vector3(116, -38, 168)
	camera.look_at(storm_position + Vector3(0, -40, 0), Vector3.UP)
	await _save_frame(camera, "11_crystal_and_underbody_texture_detail")
	environment.glow_intensity = 0.30
	var foundation := storm_zone.get_node("ModularFloatingFoundation") as Node3D
	var levitation := foundation.get_node("MagitechLevitationSystem") as Node3D
	var focus_crystal := levitation.get_node("TrimCrystalAssembly_01") as Node3D
	var hidden_foundation_children: Array[Node3D] = []
	for child in foundation.get_children():
		if child != levitation and child is Node3D and (child as Node3D).visible:
			hidden_foundation_children.append(child as Node3D)
			(child as Node3D).visible = false
	var hidden_levitation_children: Array[Node3D] = []
	for child in levitation.get_children():
		if child != focus_crystal and child is Node3D and (child as Node3D).visible:
			hidden_levitation_children.append(child as Node3D)
			(child as Node3D).visible = false
	for halo_name in [&"CyanFluxHalo", &"MagicPhaseHalo"]:
		var halo := focus_crystal.get_node_or_null(NodePath(str(halo_name))) as Node3D
		if halo != null:
			halo.visible = false
	camera.fov = 34.0
	camera.position = storm_position + Vector3(146, -12, 158)
	camera.look_at(storm_position + Vector3(90, -27, 94), Vector3.UP)
	await _save_frame(camera, "15_crystal_facet_outlayer_detail")
	for halo_name in [&"CyanFluxHalo", &"MagicPhaseHalo"]:
		var halo := focus_crystal.get_node_or_null(NodePath(str(halo_name))) as Node3D
		if halo != null:
			halo.visible = true
	for child in hidden_foundation_children:
		child.visible = true
	for child in hidden_levitation_children:
		child.visible = true
	camera.fov = 40.0
	camera.position = storm_position + Vector3(-180, -24, 238)
	camera.look_at(storm_position + Vector3(0, -40, 0), Vector3.UP)
	await _save_frame(camera, "16_underbody_root_circuit_outlayer")
	print("MIND_SPARK_ISLAND_FOUNDATIONS: PASS — 30 proof renders written")
	quit()


func _save_frame(_camera: Camera3D, file_name: String) -> void:
	for _frame in 5:
		await process_frame
	var path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	var viewport_texture := root.get_texture()
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("Mind Spark island proof render has no viewport image; use the macOS display renderer")
		quit(1)
		return
	var error := image.save_png(path)
	if error != OK:
		push_error("Mind Spark island proof render failed: %s" % error_string(error))
		quit(1)
		return
	print("MIND_SPARK_ISLAND_FOUNDATIONS: wrote %s" % path)
