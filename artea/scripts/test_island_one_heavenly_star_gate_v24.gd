extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_STATE := "user://test_island_one_heavenly_star_gate_v24.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = TEST_STATE
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 8:
		await physics_frame

	var route := world.get_node("WorldOneGeometry/MainStoryCircuitRoute") as Node3D
	assert(route.get_node_or_null("CircuitRoute_01_A") == null)
	assert(route.get_node_or_null("CircuitRoute_01_B") == null,
		"the fused Island One foundation must not receive a redundant bridge")
	var fusion := world.get_node(
		"WorldOneGeometry/ThreeFusedSuperIslands/FusedSuperIsland_01_02") as Node3D
	assert(fusion.get_node_or_null("SharedIvorySaddleCollision") is StaticBody3D,
		"the existing fused-island saddle remains the traversal surface")

	var gate := world.get_island_one_heavenly_star_gate()
	assert(gate != null and not world.is_island_one_star_gate_open())
	assert(str(gate.get_meta("purpose", "")).contains("Thought Constellation"))
	var west := gate.get_node("WestGoldenStarLeaf") as AnimatableBody3D
	var east := gate.get_node("EastGoldenStarLeaf") as AnimatableBody3D
	assert(west.get_node_or_null("GateLeafCollision") is CollisionShape3D)
	assert(east.get_node_or_null("GateLeafCollision") is CollisionShape3D)
	var west_closed := west.position
	var east_closed := east.position
	assert(str(gate.get_node("HeavenlyThresholdCourt").get_meta("mass_clearance_rule", "")).contains(
		"reserved inward swing envelope"))
	var perimeter := gate.get_node(
		"HeavenlyThresholdCourt/CollisionBackedGatePerimeter") as Node3D
	assert(float(perimeter.get_meta("clear_opening_width_m", 0.0)) >= 11.8,
		"the Island One gate walls preserve the full principal passage")
	for side in ["West", "East"]:
		assert(perimeter.get_node_or_null("%sIvoryDefenceWallCollision" % side) is StaticBody3D,
			"both perimeter wings must carry primitive collision")
		assert(perimeter.get_node_or_null("%sWingFoundationCollision" % side) is StaticBody3D,
			"both wall foundations must stop the player")

	# Exercise the eight-bearing composition. The +1/+2/−2 couplings require
	# observation and planning; this six-move route discovers Calm Contrast.
	var puzzle := world.get_island_one_puzzle()
	for operation in [["colour_prism", 1], ["rhythm_prism", 2], ["weight_prism", 3]]:
		for _press in int(operation[1]):
			assert(puzzle.interact_control(str(operation[0])).accepted)
	assert(puzzle.interact_control("analysis_console").reason == "composition_analyzed")
	assert(puzzle.interact_control("west_regulator").accepted)
	assert(puzzle.interact_control("east_regulator").accepted)
	assert(puzzle.interact_control("east_regulator").accepted)
	assert(puzzle.interact_control("outer_ring").accepted)
	assert(puzzle.get_puzzle_state().middle_ring == 2)
	assert(puzzle.interact_control("outer_ring").accepted)
	assert(puzzle.interact_control("outer_ring").accepted)
	assert(puzzle.interact_control("middle_ring").accepted)
	assert(puzzle.interact_control("middle_ring").accepted)
	assert(puzzle.interact_control("inner_ring").accepted)
	var aligned := puzzle.get_puzzle_state()
	assert([aligned.outer_ring, aligned.middle_ring, aligned.inner_ring] == [1, 0, 5])
	assert(aligned.constellation_turns == 6)
	assert(puzzle.interact_control("confirm").reason == "completed")
	assert(not world.is_island_one_star_gate_open(),
		"the Signal Prism unlocks Quest 2 without opening the inter-island gate")
	assert(puzzle.solve_echo_for_test().reason == "completed")
	assert(world.is_island_one_star_gate_open())
	assert(str(gate.get_meta("gate_state", "")) == "opening")
	await create_timer(2.1).timeout
	assert(str(gate.get_meta("gate_state", "")) == "open")
	assert(west.position.distance_to(west_closed) < 0.001 and east.position.distance_to(east_closed) < 0.001,
		"the two outer hinge pins remain fixed throughout the opening stroke")
	assert(is_equal_approx(west.rotation.y, deg_to_rad(-96.0)) \
		and is_equal_approx(east.rotation.y, deg_to_rad(96.0)),
		"both leaves swing inward and away from the arriving player")
	var halo := gate.get_node("HeavenlyStarHalo") as Node3D
	assert(halo.position.is_equal_approx(Vector3(0, 25.0, -2.15)),
		"the astrolabe rotates around its crown bearing instead of orbiting the gate origin")
	assert((gate.get_node("HeavenlyGatePowerCore") as MeshInstance3D).material_override \
		== world.get("_materials").gold)
	print("IslandOneHeavenlyStarGateV24: PASS — Signal Observatory + Echo Garden → powered hinged gate")

	world.queue_free()
	await process_frame
	var restored := WorldScene.instantiate() as MindSparkWorldOne
	restored.build_hud = false
	restored.object_state_store_path = TEST_STATE
	(restored.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(restored)
	for _frame in 8:
		await physics_frame
	assert(restored.is_island_one_star_gate_open(),
		"a solved save restores the star gate open without replaying the ceremony")
	restored.queue_free()
	await process_frame
	_cleanup()
	quit()


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
