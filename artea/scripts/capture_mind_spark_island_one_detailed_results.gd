extends SceneTree

## Presentation captures for the complete Island One vertical slice.
## These views are generated from the live runtime world, including puzzle state.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const OUTPUT := "res://artifacts/mind_spark_island_one_detailed_results"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1800, 1125)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_island_one_detailed_results.json"
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	_add_presentation_lighting(world)
	for _frame in 12:
		await process_frame
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).hide()

	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(puzzle != null)
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.08
	camera.far = 8000.0
	world.add_child(camera)
	camera.make_current()

	# Complete Island One architecture and its occupied upper deck.
	camera.fov = 52.0
	camera.global_position = puzzle.to_global(Vector3(155, 118, 205))
	camera.look_at(puzzle.to_global(Vector3(-10, 2, 22)), Vector3.UP)
	await _save("01_island_one_complete")

	# Quest 1: player-scale entry into the Signal Observatory.
	camera.fov = 68.0
	camera.global_position = puzzle.to_global(Vector3(0, 6.2, 58))
	camera.look_at(puzzle.to_global(Vector3(0, 12, 42)), Vector3.UP)
	await _save("02_signal_observatory_player_approach")

	# Quest 1: the full living-light instrument room.
	camera.fov = 55.0
	camera.global_position = puzzle.to_global(Vector3(42, 28, 74))
	camera.look_at(puzzle.to_global(Vector3(0, 8, 22)), Vector3.UP)
	await _save("03_signal_observatory_instruments")

	# Wake Quest 2 without completing it so the listening orbs, classifier rail,
	# floor route, and objective display remain readable together.
	puzzle.current_state.signal_observatory_complete = true
	puzzle.current_state.signal_prism_claimed = true
	puzzle.current_state.round_complete = true
	puzzle.current_state.echo_collected = 3
	puzzle.current_state.echo_classifications = [-1, -1, -1]
	puzzle.current_state.protective_question = -1
	puzzle.current_state.echo_garden_complete = false
	puzzle._apply_state(false)
	_show_echo_labels(puzzle)
	camera.fov = 58.0
	camera.global_position = puzzle.to_global(Vector3(-19, 21, 88))
	camera.look_at(puzzle.to_global(Vector3(-61, 8, 32)), Vector3.UP)
	await _save("04_echo_garden_full_puzzle")

	# Player-facing view of the semantic classifier instruments.
	camera.fov = 62.0
	camera.global_position = puzzle.to_global(Vector3(-57, 8.5, 56))
	camera.look_at(puzzle.to_global(Vector3(-80, 9, 25)), Vector3.UP)
	await _save("05_echo_classification_dials")

	# Complete both quests to show the powered roots, beacon, Echo Seed, and gate.
	puzzle.solve_for_test()
	_show_echo_labels(puzzle)
	camera.fov = 61.0
	camera.global_position = puzzle.to_global(Vector3(-13, 11, 76))
	camera.look_at(puzzle.to_global(Vector3(-47, 9, 49)), Vector3.UP)
	await _save("06_echo_garden_completed")

	var gate := world.get_island_one_heavenly_star_gate() as Node3D
	assert(gate != null)
	camera.fov = 78.0
	camera.global_position = gate.to_global(Vector3(0, 7, -28))
	camera.look_at(gate.to_global(Vector3(0, 15, 0)), Vector3.UP)
	world._set_island_one_star_gate_open(false, false)
	await _save("07_detailed_hinged_gate_sealed")
	world._set_island_one_star_gate_open(true, true)
	await create_timer(1.05).timeout
	await _save("08_detailed_hinged_gate_opening")
	await create_timer(1.20).timeout
	await _save("09_detailed_hinged_gate_open")
	print("ISLAND_ONE_DETAILED_RESULTS_CAPTURE: PASS")
	quit()


func _show_echo_labels(puzzle: MindSparkIslandOnePuzzle) -> void:
	for label in puzzle.find_children("Echo*", "Label3D", true, false):
		(label as Label3D).show()
	var question := puzzle.find_child("ProtectiveQuestionReading", true, false) as Label3D
	if question != null:
		question.show()


func _add_presentation_lighting(world: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b9d9e6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff1d7")
	environment.ambient_light_energy = 0.45
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-52, -34, 0)
	sunlight.light_color = Color("ffe5b3")
	sunlight.light_energy = 0.82
	sunlight.shadow_enabled = true
	world.add_child(sunlight)
	var sky_fill := DirectionalLight3D.new()
	sky_fill.rotation_degrees = Vector3(28, 142, 0)
	sky_fill.light_color = Color("c8efff")
	sky_fill.light_energy = 0.28
	world.add_child(sky_fill)


func _save(file_name: String) -> void:
	for _frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT, file_name]
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("ISLAND_ONE_DETAILED_RESULTS_CAPTURE: wrote %s" % path)
