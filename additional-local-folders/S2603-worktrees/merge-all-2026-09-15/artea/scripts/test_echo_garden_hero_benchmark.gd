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
	var old := world.find_child("MSI1_Runtime_Nature", true, false) as MeshInstance3D
	assert(old != null and not old.visible)
	assert(old.get_meta("preserve_authored_nodes", false))
	assert(world.find_child("CognitiveLightTree", true, false) != null)
	assert(world.find_child("SharedIvorySaddleCollision", true, false) != null)
	assert(world.find_children("HeavenlySapling", "Node3D", true, false).size() == 40)
	var saplings := world.find_children("HeavenlySapling", "Node3D", true, false)
	var variants := {}
	for sapling in saplings:
		var tree := sapling.get_parent() as Node3D
		variants[tree.get_meta("garden_variant")] = true
		assert(tree.find_child("ContainedPlantingCollision",true,false) != null)
		var canopy := float(tree.get_meta("garden_canopy_radius"))
		for other_sapling in saplings:
			var other := other_sapling.get_parent() as Node3D
			if other == tree:
				continue
			assert(Vector2(tree.global_position.x-other.global_position.x,tree.global_position.z-other.global_position.z).length() >= canopy + float(other.get_meta("garden_canopy_radius")) + 2.99,"Tree canopy envelopes remain separate")
		for control in world.get_island_one_puzzle().get_node("PuzzleControls").get_children():
			if control is Node3D:
				assert(Vector2(tree.global_position.x-control.global_position.x,tree.global_position.z-control.global_position.z).length() >= canopy + 11.99,"Planting stays outside station operating envelope")
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
		var from := Transform3D(Basis.IDENTITY,part.to_global(Vector3(0,-3.0,-3)))
		assert(walker.test_move(from,part.global_basis * Vector3(0,0,6)),"Player capsule cannot cross exposed perimeter")
	walker.queue_free()
	var puzzle := world.get_island_one_puzzle()
	assert(not puzzle.interact_control("echo_beacon").accepted)
	assert(not world.is_island_one_star_gate_open())
	world.queue_free()
	await process_frame
	var store := "user://test_echo_garden_hero_benchmark.json"
	if FileAccess.file_exists(store):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store))
	print("ECHO_GARDEN_HERO: PASS — six meshes, original layer hidden, teaching tree retained, bridge collision and quest lock preserved")
	quit()
