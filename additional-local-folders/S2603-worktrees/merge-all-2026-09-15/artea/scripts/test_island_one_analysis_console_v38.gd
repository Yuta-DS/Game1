extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_STATE := "user://test_island_one_analysis_console_v38.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = TEST_STATE
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 6:
		await process_frame
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	var console := puzzle.get_node(
		"PuzzleControls/PuzzleControl_analysis_console/AetherAnalysisConsoleModel") as Node3D
	assert(console != null)
	assert(console.find_child("AnalysisRotor", true, false) != null)

	# A repeated seed produces evidence, but not a valid reasoned composition.
	for prism_id in ["colour_prism", "rhythm_prism", "weight_prism"]:
		assert(puzzle.interact_control(prism_id).accepted)
	var repeated_result := puzzle.interact_control("analysis_console")
	assert(repeated_result.accepted)
	assert(repeated_result.reason == "analysis_feedback")
	assert(not bool(puzzle.get_puzzle_state().composition_analyzed))
	assert(puzzle.interact_control("west_regulator").reason == "analysis_first")
	assert(int(puzzle.get_puzzle_state().west_regulator) == 0)

	# Revising the experiment to Thought / Feeling / Choice earns the reasoning
	# bonus, while the console supplies no regulator or constellation answer.
	assert(puzzle.interact_control("rhythm_prism").accepted)
	assert(puzzle.interact_control("weight_prism").accepted)
	assert(puzzle.interact_control("weight_prism").accepted)
	var valid_result := puzzle.interact_control("analysis_console")
	assert(valid_result.reason == "composition_analyzed")
	var analyzed_state := puzzle.get_puzzle_state()
	assert(bool(analyzed_state.composition_analyzed))
	assert(bool(analyzed_state.reasoning_bonus))
	assert(int(analyzed_state.analysis_observations) == 2)
	assert(int(analyzed_state.west_regulator) == 0)
	assert(int(analyzed_state.outer_ring) == 0)

	# Later experimental changes invalidate the analysis, preventing stale advice.
	assert(puzzle.interact_control("colour_prism").accepted)
	assert(not bool(puzzle.get_puzzle_state().composition_analyzed))
	assert(not bool(puzzle.get_puzzle_state().reasoning_bonus))
	print("ISLAND_ONE_ANALYSIS_CONSOLE_V38: PASS — analyze → compare → revise without auto-solving")
	world.queue_free()
	await process_frame
	_cleanup()
	quit()


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
