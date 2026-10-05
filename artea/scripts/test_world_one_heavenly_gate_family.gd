extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
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

	var geometry := world.get_node("WorldOneGeometry") as Node3D
	assert(int(world.get_meta("standardized_heavenly_star_gate_count", 0)) == 3)
	for gate_number in [2, 3, 4]:
		var gate := geometry.get_node(
			"SavedQuestProgressionGates/QuestGate_%d" % gate_number) as AnimatableBody3D
		assert(str(gate.get_meta("gate_visual_family", "")) == "heavenly_star_gate")
		var facade := gate.get_node("HeavenlyStarGateFamilyFacade") as Node3D
		assert(str(facade.get_meta("source_gate", "")) == "IslandOneHeavenlyStarGate")
		assert(float(facade.get_meta("clear_opening_width_m", 0.0)) >= 16.0)
		assert(facade.has_node("HeavenlyStarKeystone"))
		assert(facade.has_node("WestHeavenlyPlinth"))
		assert(facade.has_node("EastHeavenlyPlinth"))

	var island_two_gate := geometry.get_node(
		"SavedQuestProgressionGates/QuestGate_2") as AnimatableBody3D
	assert(str(island_two_gate.get_meta("custom_gate_motion", "")) ==
		"island_two_memory_hinges")
	var island_three_gate := geometry.get_node(
		"SavedQuestProgressionGates/QuestGate_4") as AnimatableBody3D
	assert(bool(island_three_gate.get_meta("physical_barrier_removed", false)))
	assert((island_three_gate.get_node("CollisionShape3D") as CollisionShape3D).disabled)

	print("WorldOneHeavenlyGateFamily: PASS — Island One walls and shared Island Two/Three gate architecture")
	world.queue_free()
	await process_frame
	quit()
