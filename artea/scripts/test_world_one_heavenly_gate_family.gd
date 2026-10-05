extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := CharacterBody3D.new()
	player.name = "GateInteractionTestPlayer"
	player.add_to_group("Player")
	root.add_child(player)
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 8:
		await physics_frame

	var island_one_gate := world.get_island_one_heavenly_star_gate()
	assert(island_one_gate != null)
	var perimeter := island_one_gate.get_node(
		"HeavenlyThresholdCourt/CollisionBackedGatePerimeter") as Node3D
	assert(float(perimeter.get_meta("clear_opening_width_m", 0.0)) >= 11.8)
	for side in ["West", "East"]:
		assert(perimeter.get_node("%sIvoryDefenceWallCollision" % side) is StaticBody3D)
		assert(perimeter.get_node("%sWingFoundationCollision" % side) is StaticBody3D)
		assert(perimeter.get_node("%sGateTowerConnectorWallCollision" % side) is StaticBody3D)
		assert(perimeter.get_node("%sGateTowerConnectorFoundationCollision" % side) is StaticBody3D)
		assert(perimeter.get_node("%sConnectedBoundaryOuterWallCollision" % side) is StaticBody3D)
		assert(perimeter.get_node_or_null("%sBoundaryReturnWallCollision" % side) == null)
	assert(bool(perimeter.get_meta("covers_gate_flanks", false)))
	assert(bool(perimeter.get_meta("continuous_ground_to_coping", false)))
	assert(bool(perimeter.get_meta("full_frontage_enclosure", false)))
	assert(bool(perimeter.get_meta("side_passages_removed", false)))
	assert(bool(perimeter.get_meta("connected_to_both_gate_towers", false)))
	assert(bool(perimeter.get_meta("height_matches_gate_tower_capitals", false)))
	assert(bool(perimeter.get_meta("styled_to_match_gate_barrier", false)))
	assert(str(perimeter.get_meta("wall_visual_family", "")) == "island_one_two_civic_railing")
	assert(perimeter.has_node("WestBoundaryScrollwork_01BrassMedallion"))
	assert(perimeter.has_node("EastBoundaryPier_01WarmLantern"))
	assert(bool(perimeter.get_meta("outer_end_returns_removed", false)))
	assert(float(perimeter.get_meta("wall_coping_height_m", 0.0)) >= 13.7)
	assert(float(perimeter.get_meta("connected_boundary_span_m", 0.0)) >= 132.0)

	var geometry := world.get_node("WorldOneGeometry") as Node3D
	assert(int(world.get_meta("standardized_heavenly_star_gate_count", 0)) == 2)
	for gate_number in [2, 3]:
		var gate := geometry.get_node(
			"SavedQuestProgressionGates/QuestGate_%d" % gate_number) as AnimatableBody3D
		assert(str(gate.get_meta("gate_visual_family", "")) == "heavenly_star_gate")
		var facade := gate.get_node("HeavenlyStarGateFamilyFacade") as Node3D
		assert(str(facade.get_meta("source_gate", "")) == "IslandOneHeavenlyStarGate")
		assert(float(facade.get_meta("clear_opening_width_m", 0.0)) >= 16.0)
		assert(facade.has_node("HeavenlyStarKeystone"))
		assert(facade.has_node("WestHeavenlyPlinth"))
		assert(facade.has_node("EastHeavenlyPlinth"))
		assert(facade.has_node("SharedHeavenlyStarHalo/AstrolabeEmeraldWisdomCrystal"))
		var shared_leaves := facade.get_node("SharedHeavenlyGateLeaves") as Node3D
		assert(shared_leaves.get_node("WestCelestialLeaf/LeafCollision") is CollisionShape3D)
		assert(shared_leaves.get_node("EastCelestialLeaf/LeafCollision") is CollisionShape3D)
		assert(str(gate.get_meta("custom_gate_motion", "")) == "heavenly_star_hinges")

	var island_two_gate := geometry.get_node(
		"SavedQuestProgressionGates/QuestGate_2") as AnimatableBody3D
	var island_two_walls := island_two_gate.get_node(
		"HeavenlyStarGateFamilyFacade/SharedStyledSideWalls") as Node3D
	assert(bool(island_two_walls.get_meta("connected_to_gate_towers", false)))
	assert(float(island_two_walls.get_meta("wall_coping_height_m", 0.0)) >= 13.7)
	assert(island_two_walls.get_node("WestStyledWallMassCollision") is StaticBody3D)
	assert(island_two_walls.get_node("EastStyledWallMassCollision") is StaticBody3D)
	assert(island_two_walls.has_node("WestGateTwoScrollwork_01BrassMedallion"))
	assert(island_two_walls.has_node("EastGateTwoWallPier_01WarmLantern"))
	assert(bool(island_two_walls.get_meta("solid_outer_end_returns_removed", false)))
	assert(not (island_two_gate.get_node("IslandTwoMemoryGate") as Node3D).visible)
	var island_three_gate := geometry.get_node(
		"SavedQuestProgressionGates/QuestGate_4") as AnimatableBody3D
	assert(bool(island_three_gate.get_meta("physical_barrier_removed", false)))
	assert((island_three_gate.get_node("CollisionShape3D") as CollisionShape3D).disabled)
	assert(not island_three_gate.visible)
	assert(not island_three_gate.has_node("HeavenlyStarGateFamilyFacade"))
	assert(not island_three_gate.has_node("IslandGateControl_4"))
	assert(int(world.get_meta("nearby_q_gate_control_count", 0)) == 3)
	var button := island_two_gate.get_node("IslandGateControl_2") as Node3D
	assert(str(button.get_meta("interaction_key", "")) == "Q")
	world.set_quest_gate_open(1, true)
	assert(world.operate_gate_button_for_test(button))
	assert(not world.is_quest_gate_open(1))
	player.global_position = button.global_position
	var q_event := InputEventKey.new()
	q_event.keycode = KEY_Q
	q_event.pressed = true
	world._unhandled_input(q_event)
	assert(world.is_quest_gate_open(1))

	print("WorldOneHeavenlyGateFamily: PASS — complete Island One wall, matching Island Two gates, open Island Three route and nearby Q controls")
	world.queue_free()
	player.queue_free()
	await process_frame
	quit()
