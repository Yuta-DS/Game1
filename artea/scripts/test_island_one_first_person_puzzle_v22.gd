extends SceneTree

## Exercises Island One exactly through the production proximity interaction
## seam. This deliberately does not call solve_for_test(): the player proxy has
## to stand at every physical station and operate every required step.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_STATE := "user://test_island_one_first_person_v22.json"
const PLAYER_STANDOFF := Vector3(0.0, 1.0, -4.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = TEST_STATE
	var quest := world.get_node("QuestController") as MindSparkWorldOneQuest
	quest.enabled = false
	root.add_child(world)
	for _frame in 5:
		await process_frame

	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(puzzle != null, "Island One exposes its production puzzle controller")
	assert(int(puzzle.get_meta("cached_visual_animation_node_count", 0)) >= 8
			and int(puzzle.get_meta("per_frame_scene_tree_searches", -1)) == 0,
		"Island One caches its visual animation nodes instead of rescanning the authored hierarchy every frame")
	var player_proxy := Node3D.new()
	player_proxy.name = "FirstPersonPlayerProxy"
	world.add_child(player_proxy)
	player_proxy.global_position = puzzle.global_position + Vector3(0, 5, -90)
	assert(not puzzle.interact_nearest(player_proxy).accepted,
		"the puzzle rejects remote interaction outside the player's reach")

	var solved_events: Array[Dictionary] = []
	puzzle.puzzle_solved.connect(func(result: Dictionary) -> void: solved_events.append(result))
	await _operate(puzzle, player_proxy, "colour_prism", 1)
	await _operate(puzzle, player_proxy, "rhythm_prism", 2)
	await _operate(puzzle, player_proxy, "weight_prism", 3)
	await _operate(puzzle, player_proxy, "analysis_console", 1)
	assert(bool(puzzle.get_puzzle_state().composition_analyzed),
		"the player studies the completed experiment before adjusting its pressure")
	await _operate(puzzle, player_proxy, "west_regulator", 1)
	await _operate(puzzle, player_proxy, "east_regulator", 2)
	assert(int(puzzle.get_puzzle_state().west_regulator) == 1)
	assert(int(puzzle.get_puzzle_state().east_regulator) == 2)
	assert(str(puzzle.prompt_for_player(player_proxy).status).contains("PRESSURE STABLE"),
		"the nearby station names the creative composition, not only machine pressure")

	await _operate(puzzle, player_proxy, "outer_ring", 3)
	await _operate(puzzle, player_proxy, "middle_ring", 2)
	await _operate(puzzle, player_proxy, "inner_ring", 1)
	var result := await _operate(puzzle, player_proxy, "confirm", 1)
	assert(result.reason == "completed", "the physical route lever forms the Signal Prism")
	assert(puzzle.is_signal_observatory_complete() and not puzzle.is_powered())
	puzzle.capture_echoes_for_test()
	await _operate(puzzle, player_proxy, "echo_signal_1", 1)
	await _operate(puzzle, player_proxy, "echo_signal_2", 2)
	await _operate(puzzle, player_proxy, "echo_signal_3", 3)
	await _operate(puzzle, player_proxy, "echo_question", 3)
	result = await _operate(puzzle, player_proxy, "echo_beacon", 1)
	assert(result.reason == "completed", "the physical caution beacon completes the Echo Garden")
	assert(puzzle.is_powered(), "both Island One quests power the Island Two star gate")
	assert(solved_events.size() == 1 and str(solved_events[0].relic_id) == "echo_seed")
	assert(puzzle.get_node("SolvedRouteProjection").visible)
	assert(puzzle.get_node("BridgePowerSocketGlow").visible)
	assert(puzzle.get_node("BearingSigilReward").visible)
	assert(bool(world.get_meta("island_one_bearing_sigil", false)))
	var journey := puzzle.get_thought_journey()
	assert(str(journey.thought) == "What if I get it wrong?")
	assert(str(journey.category) == "WORRY")
	assert(str(journey.effect) == "I CAN PAUSE AND OBSERVE",
		"the authored thought is observed without treating it as identity")
	assert(str(journey.response) == "I CAN CHOOSE A HOPEFUL RESPONSE",
		"completion records the chosen grounded response")
	assert(str(journey.harmony) == "CALM CONTRAST")
	assert(str(journey.art_science) == "COMPLEMENTARY BALANCE")
	assert(journey.light_seed_composition == ["THOUGHT", "FEELING", "CHOICE"])
	assert(str(solved_events[0].emotional_reward_id) == "protective_wisdom")
	print("IslandOneFirstPersonV22: meaningful proximity journey passed (Notice → Understand → Choose → Connect)")

	world.queue_free()
	await process_frame
	_cleanup()
	quit()


func _operate(puzzle: MindSparkIslandOnePuzzle, player: Node3D,
		control_id: String, count: int) -> Dictionary:
	var control := puzzle.get_node("PuzzleControls/PuzzleControl_%s" % control_id) as Node3D
	player.global_position = control.global_position + PLAYER_STANDOFF
	var nearest := puzzle.nearest_control(player)
	assert(nearest == control, "player reaches the intended %s station" % control_id)
	var result: Dictionary = {}
	for _press in count:
		result = puzzle.interact_nearest(player)
		assert(result.accepted, "%s accepts a nearby player operation" % control_id)
		await process_frame
	return result


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
