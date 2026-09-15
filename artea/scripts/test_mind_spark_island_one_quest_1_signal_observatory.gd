extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_STATE := "user://test_mind_spark_island_one_quest_1.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var world := await _create_world()
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(puzzle.get_node_or_null("CompassMachine") is Node3D)
	assert(puzzle.get_node_or_null("ScienceArtGarden/CognitiveLightTree") is Node3D)
	assert(puzzle.get_node_or_null("EchoGardenQuestArchitecture") is Node3D)
	assert(not puzzle.is_signal_observatory_complete())
	assert(not puzzle.is_echo_garden_complete())
	assert(not world.is_island_one_star_gate_open())
	assert(puzzle.interact_control("echo_collector").reason == "signal_prism_required")

	var completed_ids: Array[String] = []
	puzzle.quest_completed.connect(func(quest_id: String, _reward: Dictionary) -> void:
		completed_ids.append(quest_id))
	_solve_signal_observatory(puzzle)
	assert(puzzle.is_signal_observatory_complete())
	assert(not puzzle.is_echo_garden_complete())
	assert(not puzzle.is_powered(), "Quest 1 alone must not power the inter-island gate")
	assert(world.is_island_one_star_gate_open(), "The internal garden threshold must open for Quest 2")
	assert(not world.is_quest_gate_open(0), "The exit to Island Two must remain locked")
	assert(completed_ids == ["quest.signal_observatory"])
	assert(bool(puzzle.get_puzzle_state().signal_prism_claimed))
	assert((puzzle.find_child("BearingSigilReward", true, false) as Node3D).visible)
	assert(not (puzzle.find_child("InstalledSignalPrism", true, false) as Node3D).visible,"Prism must be installed by the player")

	world.queue_free()
	await process_frame
	var restored := await _create_world()
	var restored_puzzle := restored.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(restored_puzzle.is_signal_observatory_complete())
	assert(not restored_puzzle.is_echo_garden_complete())
	assert(restored.is_island_one_star_gate_open())
	assert(not restored.is_quest_gate_open(0))
	print("MIND_SPARK_ISLAND_ONE_QUEST_1: PASS — Signal Prism opens garden; Island Two remains locked; save restored")
	restored.queue_free()
	await process_frame
	# Imported quest materials release their render RIDs asynchronously after
	# queued node deletion, including under the dummy headless renderer.
	for _frame in 4:
		await process_frame
	await create_timer(0.1).timeout
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


func _solve_signal_observatory(puzzle: MindSparkIslandOnePuzzle) -> void:
	for operation in [
		["colour_prism", 1], ["rhythm_prism", 2], ["weight_prism", 3],
		["analysis_console", 1], ["west_regulator", 1], ["east_regulator", 2],
		["outer_ring", 3], ["middle_ring", 2], ["inner_ring", 1], ["confirm", 1],
	]:
		for _press in int(operation[1]):
			assert(puzzle.interact_control(str(operation[0])).accepted)


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
