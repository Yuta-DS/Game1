extends SceneTree

const SCENE := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const STORE := "user://test_heavenly_quest_kit.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var world := SCENE.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STORE
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for frame in 8:
		await physics_frame
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	var controls := puzzle.get_node("PuzzleControls")
	var player := Node3D.new()
	world.add_child(player)
	assert(not puzzle.interact_control("echo_question").accepted)
	assert(not puzzle.interact_control("echo_beacon").accepted)
	var sequence := [
		["colour_prism", 1], ["rhythm_prism", 2], ["weight_prism", 3], ["analysis_console", 1],
		["west_regulator", 1], ["east_regulator", 2], ["outer_ring", 3],
		["middle_ring", 2], ["inner_ring", 1], ["confirm", 1],
	]
	for operation in sequence:
		var control := controls.get_node("PuzzleControl_%s" % operation[0]) as Node3D
		player.global_position = control.to_global(Vector3(-4, 1, 0))
		assert(puzzle.nearest_control(player) == control)
		for press in int(operation[1]):
			assert(puzzle.interact_nearest(player).accepted)
		await create_timer(.4).timeout
		_check_visuals(puzzle)
	assert(puzzle.is_signal_observatory_complete())
	puzzle.capture_echoes_for_test()
	assert(not puzzle.is_powered())
	for i in 3:
		for press in int(puzzle.ECHO_TARGETS[i]) + 1:
			assert(puzzle.interact_control("echo_signal_%d" % (i + 1)).accepted)
	for press in int(puzzle.PROTECTIVE_QUESTION_TARGET) + 1:
		assert(puzzle.interact_control("echo_question").accepted)
	await create_timer(.4).timeout
	_check_visuals(puzzle)
	assert(puzzle.interact_control("echo_beacon").accepted)
	await create_timer(.4).timeout
	assert(puzzle.is_powered())
	assert(world.is_island_one_star_gate_open())
	_check_visuals(puzzle)
	var saved := puzzle.get_puzzle_state()
	# Reset visual adapters only, then restore authoritative persisted values.
	for art in puzzle.find_children("HeavenlyQuestInstrument", "Node3D", true, false):
		art.call("apply_puzzle_state", puzzle.call("_default_state"), false)
	puzzle.call("_apply_state", false)
	_check_visuals(puzzle)
	assert(puzzle.get_puzzle_state() == saved, "Art restoration cannot award or alter gameplay")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(world, puzzle)
	print("HEAVENLY_QUEST_KIT: PASS — 15 adapters, proximity inputs, coupled poses, cards, charges, restoration, quest-to-gate")
	world.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	quit()


func _check_visuals(puzzle: MindSparkIslandOnePuzzle) -> void:
	var state := puzzle.get_puzzle_state()
	var art_nodes := puzzle.find_children("HeavenlyQuestInstrument", "Node3D", true, false)
	assert(art_nodes.size() == 15)
	for art in art_nodes:
		var id := str(art.get("control_id"))
		var control := art.get_parent()
		assert(control.has_node("InstrumentPlinthCollision"))
		assert(not control.has_node("ProductionControlVisual"))
		var value := int(art.get("displayed_value"))
		if state.has(id):
			assert(value == int(state[id]), id + " saved choice")
		if id == "colour_prism":
			assert(is_equal_approx((art.find_child("Mechanism", true, false) as Node3D).rotation.z,
				-float(maxi(value, 0)) * TAU / 3.0))
		if id == "rhythm_prism":
			assert(is_equal_approx((art.find_child("Mechanism", true, false) as Node3D).rotation.z,
				float(value - 1) * .38 if value >= 0 else 0.0))
		if id.ends_with("regulator"):
			assert(is_equal_approx((art.find_child("Valve", true, false) as Node3D).rotation.z,
				-float(value) * PI / 2.0))
		if id == "confirm":
			assert(is_equal_approx((art.find_child("Mechanism", true, false) as Node3D).rotation.x,
				-.48 if value == 1 else 0.0))
		if id in ["outer_ring", "middle_ring", "inner_ring"]:
			var wheel := art.find_child("Mechanism", true, false) as Node3D
			assert(is_equal_approx(wheel.rotation.z, -float(state[id]) * TAU / 8.0), id + " coupled wheel pose")
		if id.begins_with("echo_signal_") or id == "echo_question":
			var expected := int(state.protective_question) if id == "echo_question" else int(
				state.echo_classifications[int(id.right(1)) - 1])
			assert(value == expected)
			for i in (4 if id == "echo_question" else 3):
				var card := art.find_child("Card%d" % i, true, false) as Node3D
				assert(is_equal_approx(card.position.z, .45 + (.22 if i == value else 0.0)),
					id + " selected card projects toward player")
		if id == "echo_collector":
			for i in 3:
				assert((art.find_child("Charge%d" % i, true, false) as Node3D).visible == (i < int(state.echo_collected)))
	for prism_name in ["colour", "rhythm", "weight"]:
		var port := puzzle.get_node("PuzzleControls/PuzzleControl_%s_prism/EnergyOutputAnchor" % prism_name) as Node3D
		var pulse := puzzle.find_child("LightBeamPulse_%s_0_A" % prism_name, true, false) as Node3D
		assert((pulse.get_meta("path_start") as Vector3).is_equal_approx(puzzle.to_local(port.global_position)),
			"Light routes terminate on authored ports")


func _capture(world: Node3D, puzzle: MindSparkIslandOnePuzzle) -> void:
	root.size = Vector2i(1000, 850)
	var containing := (load("res://scenes/art_castle_floating_world.tscn") as PackedScene).instantiate()
	for light_name in ["WorldEnvironment", "Sun", "FillLight"]:
		var light := containing.get_node(light_name)
		containing.remove_child(light)
		light.owner = null
		root.add_child(light)
	containing.free()
	var camera := Camera3D.new()
	camera.fov = 48
	world.add_child(camera)
	camera.make_current()
	for id in puzzle.CONTROL_ORDER:
		var control := puzzle.get_node("PuzzleControls/PuzzleControl_%s" % id) as Node3D
		camera.global_position = control.to_global(Vector3(-9, 3.2, -.4))
		camera.look_at(control.to_global(Vector3(0, 2.8, 0)))
		await process_frame
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(
			"res://assets3D/mind_spark/quest_kit/%s/previews/in_game_kit.png" % id) == OK)
