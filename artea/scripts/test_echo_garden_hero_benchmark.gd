extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://test_echo_garden_hero_benchmark.json"
	world.get_node("QuestController").enabled = false
	root.add_child(world)
	for frame in 8:
		await process_frame
	var hero := world.find_child("EchoGardenHeroBenchmark", true, false) as Node3D
	assert(hero != null)
	assert(hero.position.is_equal_approx(Vector3(95, 0, -42.5)))
	assert(hero.find_children("*", "MeshInstance3D", true, false).size() == 6)
	var broad_ground_cover := hero.find_child("SageFoliage", true, false) as MeshInstance3D
	assert(broad_ground_cover != null and not broad_ground_cover.visible,
		"the indivisible broad shrub batch must not cover quest approach cameras")
	assert(broad_ground_cover.get_meta("retired_by", "") ==
		"quest_approach_sightline_cleanup")
	for retained_layer in ["PearlFoliage", "WarmBark", "GardenSoil", "IvoryStone"]:
		assert((hero.find_child(retained_layer, true, false) as MeshInstance3D).visible,
			"sightline cleanup preserves the hero garden layer: %s" % retained_layer)
	var learning_walk := world.find_child("CompassToEchoTreeLearningPromenade", true, false) as Node3D
	assert(learning_walk != null)
	assert(float(learning_walk.get_meta("clear_width_m", 0.0)) >= 12.0
		and bool(learning_walk.get_meta("collision_free_paving", false)),
		"the compass and teaching tree share one broad, snag-free processional walk")
	var promenade_mesh := learning_walk.get_node("LearningPromenadeLeaves") as MeshInstance3D
	assert(promenade_mesh != null and promenade_mesh.mesh != null
		and int(promenade_mesh.get_meta("authored_leaf_count", 0)) == 11,
		"eleven authored paving leaves render through one consolidated mesh")
	assert(learning_walk.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"decorative promenade insets must not duplicate the fused deck collision")
	var crescent := world.find_child("EchoTreeListeningCrescent", true, false) as Node3D
	assert(crescent != null)
	assert(crescent.get_child_count() == 3)
	for bench in crescent.get_children():
		assert(bench.name.begins_with("ListeningPavilion_"))
		assert(bench.get_node_or_null("ListeningBenchCollision/CollisionShape3D") != null)
		assert(bench.get_node_or_null("ListeningBenchCollision/PavilionPierCollision_01") != null)
		assert(bench.get_node_or_null("ListeningBenchCollision/PavilionPierCollision_02") != null)
		assert(bench.get_node_or_null("IvoryPavilionLintel") != null)
		assert(bench.get_node_or_null("SageListeningCanopy") != null)
		assert(bench.get_node_or_null("IvoryCanopyCrown") != null)
		assert(bool(bench.get_meta("open_sightline", false)))
		var foot := bench.get_node("StoneFoot_00") as Node3D
		assert(absf(foot.to_global(Vector3.DOWN * 0.46).y -
			world.get_zone_position("02_living_network_forest").y) < 0.15,
			"Listening seat supports must meet the walking deck")
		assert(Vector2(bench.position.x, bench.position.z).length() > 30.5,
			"Listening seats stay outside the tree's central walking ring")
		for control in world.get_island_one_puzzle().get_node("PuzzleControls").get_children():
			if control is Node3D:
				assert(bench.global_position.distance_to(control.global_position) > 15.0,
					"Listening seats do not obstruct quest operators")
	var old := world.find_child("MSI1_Runtime_Nature", true, false) as MeshInstance3D
	assert(old != null and not old.visible)
	assert(old.get_meta("preserve_authored_nodes", false))
	assert(world.find_child("CognitiveLightTree", true, false) != null)
	assert(world.find_child("SharedIvorySaddleCollision", true, false) != null)
	var saplings: Array[Node] = []
	for candidate in world.find_children("HeavenlySapling", "Node3D", true, false):
		if str(candidate.get_parent().get_meta("zone_id", "")) in [
			"01_world_gate_landing", "02_living_network_forest"]:
			saplings.append(candidate)
	assert(saplings.size() == 40)
	var variants := {}
	var planting_conflicts: Array[String] = []
	for sapling in saplings:
		var tree := sapling.get_parent() as Node3D
		variants[tree.get_meta("garden_variant")] = true
		assert(tree.find_child("ContainedPlantingCollision",true,false) != null)
		var canopy := float(tree.get_meta("garden_canopy_radius"))
		for other_sapling in saplings:
			var other := other_sapling.get_parent() as Node3D
			if other == tree:
				continue
			assert(Vector2(tree.global_position.x-other.global_position.x,tree.global_position.z-other.global_position.z).length() >= canopy + float(other.get_meta("garden_canopy_radius")) + 2.99,
				"Tree canopy envelopes remain separate: %s %s / %s %s" % [tree.name, tree.global_position, other.name, other.global_position])
		for control in world.get_island_one_puzzle().get_node("PuzzleControls").get_children():
			if control is Node3D:
				if Vector2(tree.global_position.x-control.global_position.x,tree.global_position.z-control.global_position.z).length() < canopy + 11.99:
					planting_conflicts.append("%s at %s crowds %s at %s" % [tree.name, tree.global_position, control.name, control.global_position])
	assert(planting_conflicts.is_empty(), "Planting clearance: " + "; ".join(planting_conflicts))
	assert(variants.size() == 3)
	var repairs := world.find_child("IslandOnePerimeterRepairs", true, false)
	assert(repairs.find_children("ReferenceScrollwork_*","Node3D",true,false).size()>24)
	for zone_name in ["01WorldGateLanding","02LivingNetworkForest"]:
		var zone := world.find_child(zone_name,true,false)
		if zone != null:
			for old_rail in zone.find_children("Railing_v11_*","MeshInstance3D",true,false):
				assert(not old_rail.visible,"Do not stack reference rails over the legacy mesh")
	await physics_frame
	await physics_frame
	var walker := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .8
	capsule.height = 3.2
	shape.shape = capsule
	walker.add_child(shape)
	root.add_child(walker)
	var bodies := repairs.find_children("*", "StaticBody3D", true, false)
	assert(bodies.size() > 100)
	for body in bodies:
		var part := body as StaticBody3D
		var query := PhysicsRayQueryParameters3D.create(
			part.to_global(Vector3(0, 0, -2)), part.to_global(Vector3(0, 0, 2)))
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		assert(not hit.is_empty(), "Exposed edge repair has real collision")
		assert(hit.collider == part,"Ray hits intended perimeter collider")
		var from := Transform3D(Basis.IDENTITY,part.to_global(Vector3(0,-3.0,-6)))
		assert(walker.test_move(from,part.global_basis * Vector3(0,0,12)),
			"Player capsule cannot cross exposed perimeter: %s at %s" % [part.name, part.global_position])
	for bench in crescent.get_children():
		var body := bench.get_node("ListeningBenchCollision") as StaticBody3D
		var from := Transform3D(Basis.IDENTITY, bench.to_global(Vector3(0, 1.0, 4.0)))
		assert(walker.test_move(from, bench.global_basis * Vector3(0, 0, -8.0)),
			"Player capsule must meet the visible tree seat")
	walker.queue_free()
	var puzzle := world.get_island_one_puzzle()
	assert(not puzzle.interact_control("echo_beacon").accepted)
	assert(not world.is_island_one_star_gate_open())
	world.queue_free()
	await process_frame
	var store := "user://test_echo_garden_hero_benchmark.json"
	if FileAccess.file_exists(store):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store))
	print("ECHO_GARDEN_HERO: PASS — broad shrub occlusion retired; hero trees, listening court, bridge collision and quest lock preserved")
	quit()
