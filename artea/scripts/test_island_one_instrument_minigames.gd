extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const PanelScript := preload("res://scripts/mind_spark/island_one_instrument_minigame_panel.gd")
const SAVE_PATH := "user://test_island_one_instrument_minigames.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_test_save()
	for control_id in MindSparkIslandOnePuzzle.CONTROL_ORDER:
		assert(PanelScript.has_challenge(control_id),
			"%s must open a playable instrument" % control_id)
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = SAVE_PATH
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 8:
		await physics_frame
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(puzzle != null)
	var actor := CharacterBody3D.new()
	world.add_child(actor)
	world.set("_player", actor)
	var opening_control := puzzle.get_node("PuzzleControls/PuzzleControl_colour_prism") as Node3D
	actor.global_position = opening_control.global_position
	var q := InputEventKey.new()
	q.keycode = KEY_Q
	q.pressed = true
	world._unhandled_input(q)
	var opened := world.get_node_or_null("QuestStationPanel")
	assert(opened != null and opened.get_script() == PanelScript,
		"Q opens the interactive Island One instrument, not the answer-button panel")
	opened.free()

	for operation in [
		["colour_prism", 1], ["rhythm_prism", 2], ["weight_prism", 3],
		["analysis_console", 1], ["west_regulator", 1], ["east_regulator", 2],
		["outer_ring", 3], ["middle_ring", 2], ["inner_ring", 1],
		["confirm", 1], ["echo_collector", 1],
		["echo_signal_1", 1], ["echo_signal_2", 1], ["echo_signal_3", 1],
		["echo_question", 1], ["echo_beacon", 1],
	]:
		var control_id: String = operation[0]
		for _attempt in int(operation[1]):
			actor.global_position = (puzzle.get_node(
				"PuzzleControls/PuzzleControl_%s" % control_id) as Node3D).global_position
			var panel := PanelScript.new()
			world.add_child(panel)
			panel.open_instrument(puzzle, actor, control_id)
			assert(panel.challenge_mode() in ["align", "route", "rhythm", "catch", "dodge"])
			_drive_game(panel)
			var result: Dictionary = panel.completion_result()
			assert(bool(result.get("accepted", false)),
				"%s challenge must update the real puzzle: %s" % [control_id, result])
			if control_id.begins_with("echo_signal_"):
				assert(bool(panel.get("_pending_classification")),
					"captured echo must open a playable sorting stage")
				_send_key(panel, KEY_SPACE)
				assert(panel.challenge_mode() == "route" and not bool(panel.get("_finished")))
				_drive_game(panel)
				assert(bool(panel.completion_result().get("accepted", false)),
					"echo sorting must save through the real puzzle")
			panel.free()
	assert(puzzle.is_signal_observatory_complete(),
		"playable instruments complete the Observatory quest")
	assert(puzzle.is_echo_garden_complete(),
		"playable instruments complete the Echo Garden quest")
	assert(bool(puzzle.get_puzzle_state().echo_seed_claimed),
		"the existing Echo Seed reward remains available")
	print("ISLAND_ONE_INSTRUMENT_MINIGAMES: PASS — 16 controls, two quests, active input and rewards")
	world.queue_free()
	for _frame in 4:
		await process_frame
	_remove_test_save()
	quit()


func _drive_game(panel: CanvasLayer) -> void:
	match panel.challenge_mode():
		"align":
			for target in panel.get("_spec").get("targets", []):
				var current := float((panel.get("_cursor") as Vector2).x)
				var command := "right" if float(target) > current else "left"
				panel.call("_handle_digital_command", command, true)
				panel._process(absf(float(target) - current) /
					float(panel.get("_spec").get("speed", 0.65)))
				panel.call("_handle_digital_command", command, false)
				_send_key(panel, KEY_SPACE)
		"route":
			var route: Array = panel.get("_spec").get("route", [])
			var hazards: Array = panel.get("_spec").get("hazards", [])
			while int(panel.get("_score")) < int(panel.get("_spec").goal):
				var target: Vector2i = route[int(panel.get("_score"))]
				for command in _grid_path(panel.get("_grid"), target, hazards):
					_send_direction(panel, command)
		"rhythm":
			for command in panel.get("_spec").get("sequence", []):
				_send_direction(panel, str(command))
		"catch", "dodge":
			_drive_falling_game(panel)
	assert(bool(panel.get("_finished")),
		"%s challenge must finish through game controls" % panel.challenge_mode())


func _drive_falling_game(panel: CanvasLayer) -> void:
	var guard := 0
	while not bool(panel.get("_finished")) and guard < 2400:
		guard += 1
		var desired := 0.5
		var falling: Array = panel.get("_falling")
		if not falling.is_empty():
			var nearest: Dictionary = falling[0]
			for item in falling:
				if float(item.y) > float(nearest.y):
					nearest = item
			if panel.challenge_mode() == "catch" and not bool(nearest.bad):
				desired = float(nearest.x)
			else:
				desired = 0.05 if float(nearest.x) > 0.5 else 0.95
		var current := float((panel.get("_cursor") as Vector2).x)
		panel.call("_handle_digital_command", "left", desired < current - 0.018)
		panel.call("_handle_digital_command", "right", desired > current + 0.018)
		panel._process(0.05)
		if panel.challenge_mode() == "dodge" and bool(panel.get("_ready_to_strike")):
			_send_key(panel, KEY_SPACE)
	assert(guard < 2400, "falling challenge completes within a playable time bound")


func _send_direction(panel: CanvasLayer, command: String) -> void:
	var keys := {"left": KEY_LEFT, "right": KEY_RIGHT,
		"up": KEY_UP, "down": KEY_DOWN}
	_send_key(panel, keys[command])


func _send_key(panel: CanvasLayer, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	panel._unhandled_input(event)
	event.pressed = false
	panel._unhandled_input(event)


func _grid_path(start: Vector2i, target: Vector2i, hazards: Array) -> Array[String]:
	var frontier: Array[Vector2i] = [start]
	var paths := {start: []}
	var steps := {"left": Vector2i.LEFT, "right": Vector2i.RIGHT,
		"up": Vector2i.UP, "down": Vector2i.DOWN}
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if cell == target:
			var result: Array[String] = []
			result.assign(paths[cell])
			return result
		for command in steps:
			var next: Vector2i = cell + steps[command]
			if next.x < 0 or next.x > 2 or next.y < 0 or next.y > 2:
				continue
			if next in hazards or paths.has(next):
				continue
			var next_path: Array[String] = []
			next_path.assign(paths[cell])
			next_path.append(command)
			paths[next] = next_path
			frontier.append(next)
	return []


func _remove_test_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
