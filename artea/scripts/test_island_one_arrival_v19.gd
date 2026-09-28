extends "res://scripts/test_mind_spark_zone02_route_clearance.gd"


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://test_island_one_v19.json"
	root.add_child(world)
	var player := PlayerScene.instantiate() as CharacterBody3D
	root.add_child(player)
	for _frame in 8:
		await physics_frame
	player.set_physics_process(false)

	var zone := world.get_node("WorldOneGeometry/01WorldGateLanding") as Node3D
	var arrival := zone.get_node("CelestialWorldGateArrival") as Node3D
	assert(arrival != null)
	assert(arrival.get_meta("above_ground_revision", "") == "v21_reusable_gate_kit")
	assert(arrival.get_meta("island_focus", "") == "01_world_gate_landing")
	assert(is_equal_approx(float(arrival.get_meta("clear_processional_width_m", 0.0)), 40.0))
	var pavilion := arrival.get_node(
		"GateArchitectureKit/02_AetherConservatoryKit") as Node3D
	assert(pavilion != null)
	assert(pavilion.find_children("CanopyGlassTriangle_*", "MeshInstance3D", true, false).size() == 144)
	assert(pavilion.find_children("*IvoryColumn_*", "MeshInstance3D", true, false).size() == 10)
	assert(arrival.get_node_or_null(
		"GateArchitectureKit/04_BeaconTowerKit/WestAetherLanternTower") != null)
	assert(arrival.get_node_or_null(
		"GateArchitectureKit/04_BeaconTowerKit/EastAetherLanternTower") != null)
	assert(arrival.find_children("*ArrivalGarden_*", "Node3D", true, false).size() == 4)
	assert(not arrival.find_children("*", "StaticBody3D", true, false).is_empty(),
		"Island One architecture needs solid, collision-backed structures")
	assert(zone.get_node_or_null("EntryWorldGate") is MindSparkWorldGate,
		"The functional Art Castle return gate must remain present")
	assert(zone.get_node_or_null("ArrivalRootBridge") == null \
		and zone.get_node_or_null("ArrivalRootBridgeCollision") == null,
		"The obsolete static bridge must no longer occupy the gate centre")
	assert(world.get_island_one_heavenly_star_gate() != null,
		"The fused promenade must be controlled by the Heavenly Star Gate")

	# Drive the production capsule along the covered outer approach to the
	# compass court. The compass machine occupies the middle of the plaza, so a
	# straight line through it is not a valid traversal path.
	var centre := world.to_global(world.get_zone_position("01_world_gate_landing"))
	var capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	var stand_height := capsule.height * 0.5 + 0.25
	var start := centre + Vector3(30, stand_height + 3.0, 84)
	if not await _settle(player, start):
		_fail("production player cannot stand on the Island One arrival axis")
		return
	var destination := centre + Vector3(30, stand_height + 1.0, 25)
	if not await _walk(player, destination):
		_fail("player is blocked in the Island One conservatory at %s; collisions: %s"
			% [player.global_position, _collider_labels(player)])
		return
	print("ISLAND_ONE_ARRIVAL: PASS — reusable gate kit, 144 glass panels, twin towers and outer player approach")
	quit()
