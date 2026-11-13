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
	var entry_gate := zone.get_node_or_null("EntryWorldGate") as MindSparkWorldGate
	assert(entry_gate != null,
		"The functional Art Castle return gate must remain present")
	var arch := arrival.get_node(
		"GateArchitectureKit/03_ThresholdStructureKit/WorldGateCelestialArch") as Node3D
	assert(entry_gate.position.is_equal_approx(
		world.ISLAND_ONE_RETURN_GATE_AT + Vector3.UP),
		"the return ring must stand on the centre of its authored threshold")
	var court_radius := 73.0
	var ring_outer_radius := 6.30
	var ring_distance_from_court_center := Vector2(
		entry_gate.position.x, entry_gate.position.z - 8.0).length()
	assert(ring_distance_from_court_center + ring_outer_radius < court_radius,
		"the complete return ring must stand inside the circular arrival court")
	assert(Vector2(entry_gate.global_position.x, entry_gate.global_position.z).distance_to(
		Vector2(arch.global_position.x, arch.global_position.z)) < 0.05,
		"the return ring and arch must have the same ground position")
	assert(absf(wrapf(entry_gate.global_rotation.y - arch.global_rotation.y,
		-PI, PI)) < 0.01, "the portal and its arch must face the same approach")
	for pier in arch.find_children("IvoryPortalPier", "MeshInstance3D", true, false):
		assert(Vector2((pier as Node3D).global_position.x,
			(pier as Node3D).global_position.z).distance_to(
			Vector2(entry_gate.global_position.x, entry_gate.global_position.z)) > 17.0,
			"a structural arch pier must not overlap the return ring")
	var gate_to_arrival := (world.STANDALONE_PLAYER_ARRIVAL - entry_gate.position)
	gate_to_arrival.y = 0.0
	var gate_facing := entry_gate.basis.z
	gate_facing.y = 0.0
	assert(gate_facing.normalized().dot(gate_to_arrival.normalized()) > 0.999,
		"The Island One teleport ring must face the real player approach")
	assert(bool(entry_gate.get_meta("faces_player_approach", false)),
		"The teleport alignment must remain an explicit authored decision")
	assert(zone.get_node_or_null("ArrivalRootBridge") == null \
		and zone.get_node_or_null("ArrivalRootBridgeCollision") == null,
		"The obsolete static bridge must no longer occupy the gate centre")
	var star_gate := world.get_island_one_heavenly_star_gate()
	assert(star_gate != null,
		"The fused promenade must be controlled by the Heavenly Star Gate")
	var perimeter := star_gate.get_node(
		"HeavenlyThresholdCourt/CollisionBackedGatePerimeter") as Node3D
	assert(perimeter.get_meta("barrier_design_revision", "") \
		== "arched_ivory_brass_balustrade")
	assert(perimeter.get_node_or_null("WestConnectedBoundaryOuterWallCollision") \
		is StaticBody3D and perimeter.get_node_or_null(
		"EastConnectedBoundaryOuterWallCollision") is StaticBody3D,
		"the redesigned railing must retain physical side barriers")
	assert(perimeter.find_child("WestBoundaryScrollwork_01GiltCrownArch_04", true, false) \
		is MeshInstance3D and perimeter.find_child(
		"WestBoundaryScrollwork_01WestScroll", true, false) == null,
		"the gate approach should use an arched balustrade without A-shaped braces")

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
