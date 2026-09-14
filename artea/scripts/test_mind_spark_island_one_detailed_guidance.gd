extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_STATE := "user://test_mind_spark_island_one_detailed_guidance.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var world := await _create_world()
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(puzzle.current_quest_id() == "quest.signal_observatory")
	assert(puzzle.current_task_id() == "signal.route_composition")
	assert(puzzle.current_target_control_id() == "colour_prism")

	for operation in [["colour_prism", 1], ["rhythm_prism", 2], ["weight_prism", 3]]:
		_press(puzzle, str(operation[0]), int(operation[1]))
	assert(puzzle.current_task_id() == "signal.analyze_evidence")
	_press(puzzle, "analysis_console", 1)
	assert(puzzle.current_task_id() == "signal.balance_pressure")
	_press(puzzle, "west_regulator", 1)
	_press(puzzle, "east_regulator", 2)
	assert(puzzle.current_task_id() == "signal.align_constellation")
	_press(puzzle, "outer_ring", 3)
	_press(puzzle, "middle_ring", 2)
	_press(puzzle, "inner_ring", 1)
	assert(puzzle.current_task_id() == "signal.form_prism")
	_press(puzzle, "confirm", 1)
	assert(puzzle.current_quest_id() == "quest.echo_forest")
	assert(puzzle.current_task_id() == "archive.install_prism")
	assert(_visible_guidance_count(puzzle, 0) == 8)
	assert(_visible_guidance_count(puzzle, 1) == 0)

	puzzle.capture_echoes_for_test()
	assert(puzzle.current_task_id() == "archive.sort_fact_possibility")
	assert(_visible_guidance_count(puzzle, 1) == 8)
	_press(puzzle, "echo_signal_1", 1)
	_press(puzzle, "echo_signal_2", 2)
	_press(puzzle, "echo_signal_3", 3)
	assert(puzzle.current_task_id() == "archive.find_protective_question")
	assert(_visible_guidance_count(puzzle, 2) == 8)
	for index in 3:
		var reading := puzzle.find_child("EchoCategoryReading_%02d" % (index + 1),
			true, false) as Label3D
		assert(reading != null and reading.text.contains(
			MindSparkIslandOnePuzzle.ECHO_CATEGORIES[index]))

	_press(puzzle, "echo_question", 1)
	assert(puzzle.current_task_id() == "archive.power_beacon")
	assert(_visible_guidance_count(puzzle, 3) == 8)
	var before_revision: Array = puzzle.get_puzzle_state().echo_classifications
	assert(puzzle.interact_control("echo_beacon").reason == "interpretation_needs_revision")
	assert(puzzle.get_puzzle_state().echo_classifications == before_revision,
		"verification preserves the player's complete classification")
	_press(puzzle, "echo_question", 2)
	assert(puzzle.interact_control("echo_beacon").reason == "completed")
	await process_frame
	assert(puzzle.current_task_id() == "archive.complete")
	assert(puzzle.current_objective().contains("Echo Seed"))
	assert(puzzle.find_children("GuidanceLight_*", "MeshInstance3D", true, false) \
		.filter(func(marker: MeshInstance3D) -> bool: return marker.visible).size() == 32)
	assert(puzzle.find_children("EchoRootPulse_*", "MeshInstance3D", true, false) \
		.filter(func(marker: MeshInstance3D) -> bool: return marker.visible).size() == 18)
	assert((puzzle.find_child("ProtectiveQuestionReading", true, false) as Label3D).text \
		.contains("ONE SMALL PREPARATION"))

	world.queue_free()
	await process_frame
	var restored := await _create_world()
	var restored_puzzle := restored.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(restored_puzzle.current_task_id() == "archive.complete")
	assert(restored_puzzle.find_children("GuidanceLight_*", "MeshInstance3D", true, false) \
		.filter(func(marker: MeshInstance3D) -> bool: return marker.visible).size() == 32)
	print("MIND_SPARK_ISLAND_ONE_DETAILED_GUIDANCE: PASS — objectives + route + readable instruments + living feedback")
	restored.queue_free()
	await process_frame
	_cleanup()
	quit()


func _create_world() -> MindSparkWorldOne:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = TEST_STATE
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 8:
		await physics_frame
	return world


func _press(puzzle: MindSparkIslandOnePuzzle, control_id: String, count: int) -> void:
	for _press_index in count:
		assert(puzzle.interact_control(control_id).accepted)


func _visible_guidance_count(puzzle: MindSparkIslandOnePuzzle, chapter: int) -> int:
	return puzzle.find_children("GuidanceLight_*", "MeshInstance3D", true, false).filter(
		func(marker: MeshInstance3D) -> bool:
			return marker.visible and int(marker.get_meta("guidance_chapter", -1)) == chapter).size()


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
