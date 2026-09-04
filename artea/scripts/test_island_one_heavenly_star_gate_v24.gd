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
	assert(world.is_island_one_star_gate_open())
	assert(str(gate.get_meta("gate_state", "")) == "opening")
	await create_timer(2.1).timeout
	assert(str(gate.get_meta("gate_state", "")) == "open")
	assert(west.position.x < west_closed.x and east.position.x > east_closed.x,
		"both physical leaves retract outward into their pylons")
	assert((gate.get_node("HeavenlyGatePowerCore") as MeshInstance3D).material_override \
		== world.get("_materials").gold)
	print("IslandOneHeavenlyStarGateV24: PASS — coupled constellation → powered physical gate")

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
