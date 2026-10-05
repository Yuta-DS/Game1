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
		assert(perimeter.get_node("%sConnectedBoundaryOuterWallCollision" % side) is StaticBody3D)
		assert(perimeter.get_node("%sGardenPassageTowerJambCollision" % side) is StaticBody3D)
		assert(perimeter.get_node("%sGardenPassageBoundaryJambCollision" % side) is StaticBody3D)
		assert(perimeter.get_node("%sGardenPassageLintelCollision" % side) is StaticBody3D)
	assert(bool(perimeter.get_meta("covers_gate_flanks", false)))
	assert(bool(perimeter.get_meta("continuous_ground_to_coping", false)))
	assert(float(perimeter.get_meta("covered_garden_passage_width_m", 0.0)) >= 6.0)

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
