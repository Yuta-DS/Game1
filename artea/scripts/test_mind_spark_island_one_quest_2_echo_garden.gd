extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_STATE := "user://test_mind_spark_island_one_quest_2.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var world := await _create_world()
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(not puzzle.station_action("echo_signal_1", "capture").accepted)
	var initial := puzzle.get_puzzle_state()
	assert(puzzle.interact_control("colour_prism").accepted)
	assert(puzzle.station_action("colour_prism", "undo").accepted)
	assert(puzzle.get_puzzle_state().colour_prism == initial.colour_prism)
	_solve_signal_observatory(puzzle)
	assert(world.is_island_one_star_gate_open())
	assert(world.is_quest_gate_open(0),
		"Island One to Island Two bridge remains physically unobstructed")
	assert(not puzzle.station_action("colour_prism", "undo").accepted)

	var completed_ids: Array[String] = []
	puzzle.quest_completed.connect(func(quest_id: String, _reward: Dictionary) -> void:
		completed_ids.append(quest_id))
	assert(puzzle.interact_control("echo_collector").accepted)
	assert(not puzzle.interact_control("echo_collector").accepted)
	assert(puzzle.get_puzzle_state().echo_collected == 0)
	assert(not puzzle.station_action("echo_signal_3", "capture").accepted)
	assert(not puzzle.station_action("echo_signal_3", "classify", 2).accepted)
	assert(puzzle.station_action("echo_signal_3", "tune", 2).accepted)
	world.queue_free()
	await process_frame
	world = await _create_world()
	puzzle = world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(puzzle.get_puzzle_state().prism_installed)
	assert(puzzle.get_puzzle_state().echo_phases[2] == 2)
	assert(puzzle.station_action("echo_signal_3", "tune", -2).accepted)
	assert(puzzle.get_puzzle_state().echo_phases[2] == 0)
	assert(puzzle.station_action("echo_signal_3", "tune", -3).accepted)
	assert(puzzle.get_puzzle_state().echo_phases[2] == 5)
	if "--capture" in OS.get_cmdline_user_args():
		var preview_actor := Node3D.new()
		world.add_child(preview_actor)
		preview_actor.global_position = puzzle.get_node("PuzzleControls/PuzzleControl_echo_signal_3").global_position
		var preview := preload("res://scripts/mind_spark/quest_station_panel.gd").new()
		world.add_child(preview)
		preview.open(puzzle, preview_actor, "echo_signal_3")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts/interactive_quest")
		root.get_texture().get_image().save_png("res://artifacts/interactive_quest/tuning.png")
		preview.queue_free()
		await process_frame
		preview_actor.queue_free()
	puzzle.quest_completed.connect(func(quest_id: String, _reward: Dictionary) -> void:
		completed_ids.append(quest_id))
	# Visit stations out of order; capture requires an actual aligned receiver.
	for index in [2, 0, 1]:
		var id := "echo_signal_%d" % (index + 1)
		for _turn in 8:
			if int(puzzle.get_puzzle_state().echo_phases[index]) == puzzle.ECHO_PHASE_TARGETS[index]:
				break
			assert(puzzle.station_action(id, "tune", 3).accepted)
		assert(puzzle.station_action(id, "capture").accepted)
		assert(not puzzle.station_action(id, "capture").accepted)
	assert(puzzle.get_puzzle_state().echo_collected == 3)
	var actor := Node3D.new()
	world.add_child(actor)
	actor.position = Vector3(90000,90000,90000)
	assert(not puzzle.station_action("echo_signal_1", "classify", 0, actor).accepted)
	actor.global_position = puzzle.get_node("PuzzleControls/PuzzleControl_echo_signal_1").global_position
	actor.set_physics_process(true)
	var modal := preload("res://scripts/mind_spark/quest_station_panel.gd").new()
	world.add_child(modal)
	modal.open(puzzle, actor, "echo_signal_1")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts/interactive_quest")
		root.get_texture().get_image().save_png("res://artifacts/interactive_quest/choices.png")
	assert(not actor.is_physics_processing())
	var buttons := modal.find_children("*", "Button", true, false)
	assert(buttons.size() == 4)
	(buttons[2] as Button).pressed.emit()
	assert(puzzle.get_puzzle_state().echo_classifications[0] == 2)
	modal.queue_free()
	await process_frame
	assert(actor.is_physics_processing())
	assert(puzzle.station_action("echo_signal_1", "classify", 2).accepted)
	# Cycle from Unsure back to Fact using the legacy interaction API below.
	for control_id in ["echo_signal_1", "echo_signal_2", "echo_signal_3", "echo_question"]:
		assert(puzzle.interact_control(control_id).accepted)
	var revision := puzzle.interact_control("echo_beacon")
	assert(revision.reason == "interpretation_needs_revision")
	assert(int(puzzle.get_puzzle_state().echo_attempts) == 1)

	# Keep Echo I as Fact; revise Echo II to Possibility, Echo III to Unsure,
	# and turn the catastrophic warning into one small preparatory question.
	assert(puzzle.interact_control("echo_signal_2").accepted)
	for _press in 2:
		assert(puzzle.interact_control("echo_signal_3").accepted)
	for _press in 2:
		assert(puzzle.interact_control("echo_question").accepted)
	var completed := puzzle.interact_control("echo_beacon")
	assert(completed.reason == "completed")
	assert(puzzle.is_echo_garden_complete())
	assert(puzzle.is_powered())
	assert(completed_ids == ["quest.echo_forest"])
	assert(world.is_island_one_star_gate_open())
	assert((puzzle.find_child("EchoSeedReward", true, false) as Node3D).visible)
	assert((puzzle.find_child("CautionBeaconLight", true, false) as Light3D).light_energy > 3.0)

	world.queue_free()
	await process_frame
	var restored := await _create_world()
	var restored_puzzle := restored.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(restored_puzzle.is_signal_observatory_complete())
	assert(restored_puzzle.is_echo_garden_complete())
	assert(restored.is_island_one_star_gate_open())
	print("MIND_SPARK_ISLAND_ONE_QUEST_2: PASS — collect → classify → reframe → Echo Seed → gate opens")
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
