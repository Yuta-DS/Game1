extends SceneTree

const Catalog := preload("res://scripts/mind_spark/world_one_object_minigame_catalog.gd")
const WorldScript := preload("res://scripts/mind_spark/mind_spark_world_one.gd")
const PanelScript := preload("res://scripts/mind_spark/world_one_object_minigame_panel.gd")

const EXPECTED_IDS := [
	"world_one.checkpoint.landing", "world_one.path_projector",
	"world_one.spark_socket", "world_one.checkpoint.network", "world_one.focus_bell",
	"world_one.evidence_scanner", "world_one.memory_board", "world_one.logic_gate",
	"world_one.perspective_lens", "world_one.truth_bridge",
	"world_one.warden_anchor.1", "world_one.warden_anchor.2", "world_one.warden_anchor.3",
	"world_one.calm_rain_basin", "world_one.identity_reflection",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists("user://test_world_one_object_minigames.json"):
		DirAccess.remove_absolute("user://test_world_one_object_minigames.json")
	assert(Catalog.ids().size() == 15, "exactly 15 physical quest objects have minigames")
	var islands := {1: 0, 2: 0, 3: 0}
	var modes := {}
	for save_id in EXPECTED_IDS:
		assert(Catalog.has_challenge(save_id), "%s has a playable challenge" % save_id)
		var spec := Catalog.challenge(save_id)
		assert(str(spec.get("title", "")).length() > 4)
		assert(str(spec.get("instruction", "")).length() > 12)
		assert(str(spec.get("mode", "")) in ["align", "route", "rhythm", "catch", "dodge"])
		assert(int(spec.get("goal", 0)) >= 3, "challenge requires several player actions")
		islands[int(spec.island)] += 1
		modes[str(spec.mode)] = true
	assert(islands == {1: 5, 2: 5, 3: 5}, "five minigames belong to each island")
	assert(modes.size() == 5, "the objects use five distinct playable mechanics")
	var island_three_modes := {}
	for save_id in EXPECTED_IDS.slice(10):
		island_three_modes[str(Catalog.challenge(save_id).mode)] = true
	assert(island_three_modes.size() == 5,
		"Island 3 gives each of its five quest landmarks a distinct playable mechanic")

	var world := WorldScript.new()
	world.build_hud = false
	world.object_state_store_path = "user://test_world_one_object_minigames.json"
	get_root().add_child(world)
	await process_frame
	assert(world.get_quest_objects().size() == 15)
	for object in world.get_quest_objects():
		assert(Catalog.has_challenge(object.save_id), "live object opens a minigame")
		assert(object.has_meta("operator_approach_local"), "minigame is reachable from supported ground")
	var projector: QuestObjectBase
	for object in world.get_quest_objects():
		if object.save_id == "world_one.path_projector": projector = object
	assert(projector != null)
	var actor := Node3D.new()
	world.add_child(actor)
	var panel := PanelScript.new()
	panel.name = "QuestStationPanel"
	world.add_child(panel)
	panel.open_object(projector, actor)
	assert(panel.challenge_mode() == "route", "Q opens the object's active game mechanic")
	await _assert_responsive_controls(panel)
	var route: Array = panel.get("_spec").get("route", [])
	var hazards: Array = panel.get("_spec").get("hazards", [])
	var controller_path := _grid_path(panel.get("_grid"), route[int(panel.get("_score"))], hazards)
	assert(not controller_path.is_empty(), "controller has a safe route command")
	var controller_start: Vector2i = panel.get("_grid")
	_send_joy_button(panel, controller_path[0])
	assert((panel.get("_grid") as Vector2i) != controller_start,
		"D-pad commands drive the same route movement as keyboard input")
	panel.call("_reset_round")
	var reward: Dictionary = await _complete_through_player_input(panel)
	assert(bool(reward.accepted) and bool(projector.current_state.guide_enabled),
		"winning a minigame applies the existing quest-object reward")
	panel.free()
	var touch_modes := {}
	for object in world.get_quest_objects():
		object.interaction_enabled = true
		object.set_meta("available_sparks", object.definition.validated_total())
		var reward_panel := PanelScript.new()
		reward_panel.name = "RewardPanel_%s" % object.save_id.replace(".", "_")
		world.add_child(reward_panel)
		reward_panel.open_object(object, actor)
		var mode := reward_panel.challenge_mode()
		var mode_touch_buttons: Dictionary = reward_panel.get("_touch_buttons")
		assert((mode_touch_buttons.left as Button).text == "LEFT"
			and (mode_touch_buttons.up as Button).text == "UP"
			and (mode_touch_buttons.down as Button).text == "DOWN"
			and (mode_touch_buttons.right as Button).text == "RIGHT",
			"touch directions use portable text instead of unsupported Web glyphs")
		var uses_vertical_controls := mode in ["route", "rhythm"]
		assert((mode_touch_buttons.up as Button).visible == uses_vertical_controls
			and (mode_touch_buttons.down as Button).visible == uses_vertical_controls,
			"%s exposes only controls used by its mechanic" % mode)
		var expected_action_caption: String = str({
			"align": "LOCK", "dodge": "STRIKE", "catch": "RESTART",
			"route": "RESET", "rhythm": "RESET",
		}.get(mode, "ACTION"))
		assert((mode_touch_buttons.action as Button).text == expected_action_caption,
			"%s uses a specific action verb instead of a generic button" % mode)
		if mode == "align":
			var before_stick := float((reward_panel.get("_cursor") as Vector2).x)
			_send_joy_axis(reward_panel, JOY_AXIS_LEFT_X, -1.0)
			reward_panel.call("_process", .12)
			_send_joy_axis(reward_panel, JOY_AXIS_LEFT_X, 0.0)
			assert(float((reward_panel.get("_cursor") as Vector2).x) < before_stick,
				"left stick continuously steers align, catch and dodge mechanics")
			reward_panel.call("_reset_round")
			var first_target := float((reward_panel.get("_spec").get("targets", []) as Array)[0])
			reward_panel.set("_cursor", Vector2(first_target, .5))
			_send_joy_button(reward_panel, "action")
			assert(int(reward_panel.get("_score")) == 1,
				"controller A confirms a timing action")
			reward_panel.call("_reset_round")
		if not touch_modes.has(mode):
			_exercise_touch_controls(reward_panel)
			touch_modes[mode] = true
		var result: Dictionary = await _complete_through_player_input(reward_panel)
		assert(bool(result.get("accepted", false)), "%s minigame applies a valid gameplay action" % object.save_id)
		reward_panel.free()
	assert(touch_modes.size() == 5, "touch buttons drive every mini-game mode")
	print("WorldOneObjectMinigames: PASS — 15 objects, 5 per island, 5 active mechanics")
	world.queue_free()
	if FileAccess.file_exists("user://test_world_one_object_minigames.json"):
		DirAccess.remove_absolute("user://test_world_one_object_minigames.json")
	quit()


func _assert_responsive_controls(panel: CanvasLayer) -> void:
	panel.call("_layout_for_viewport", Vector2(320, 568))
	await process_frame
	var touch := panel.get("_touch") as GridContainer
	var touch_buttons: Dictionary = panel.get("_touch_buttons")
	assert(touch.columns == 3, "narrow phones use a three-column directional grid")
	assert(touch.get_child(0) == touch_buttons.up
		and touch.get_child(1) == touch_buttons.action
		and touch.get_child(2) == touch_buttons.down
		and touch.get_child(3) == touch_buttons.left
		and touch.get_child(5) == touch_buttons.right
		and str((touch.get_child(4) as Button).text).contains("BACK"),
		"narrow touch controls group vertical, horizontal, action and back commands")
	for button in touch_buttons.values():
		assert((button as Button).custom_minimum_size.x >= 64.0
			and (button as Button).custom_minimum_size.y >= 48.0,
			"touch targets stay comfortably above the 44 px floor")
		assert((button as Button).focus_mode == Control.FOCUS_ALL,
			"touch actions remain keyboard/controller focusable")
	var panel_control := panel.get("_panel") as PanelContainer
	assert(panel_control.position.x >= 0.0 and panel_control.position.y >= 0.0
		and panel_control.position.x + panel_control.size.x <= 320.0
		and panel_control.position.y + panel_control.size.y <= 568.0,
		"320×568 phone layout stays inside the visible viewport; pos=%s size=%s min=%s" \
			% [panel_control.position, panel_control.size, panel_control.get_combined_minimum_size()])
	panel.call("_layout_for_viewport", Vector2(844, 390))
	await process_frame
	assert(touch.columns == 6, "landscape phones keep all controls in one compact row")
	assert((panel.get("_board") as Control).custom_minimum_size.y >= 105.0,
		"short landscape layout keeps the game board playable")
	assert(panel_control.position.x >= 0.0 and panel_control.position.y >= 0.0
		and panel_control.position.x + panel_control.size.x <= 844.0
		and panel_control.position.y + panel_control.size.y <= 390.0,
		"844×390 landscape layout stays inside the visible viewport; pos=%s size=%s min=%s" \
			% [panel_control.position, panel_control.size, panel_control.get_combined_minimum_size()])

	var logical_phone := Vector2(1710.0, 3700.0)
	var physical_phone := Vector2(390.0, 844.0)
	var selected: Vector2 = panel.call("_select_minigame_physical_size",
		logical_phone, Vector2(710.0, 1536.0), physical_phone)
	assert(selected == physical_phone,
		"Web mini-games prefer the browser CSS viewport over backing-store dimensions")
	panel.call("_layout_for_viewport", logical_phone, physical_phone)
	await process_frame
	var ui_scale := float(panel.get_meta("minigame_ui_scale", 0.0))
	assert(ui_scale >= 4.0 and str(panel.get_meta("minigame_layout", "")) \
		== "physical_viewport_v2", "portrait mini-game compensates for canvas scaling")
	assert(panel_control.position.x >= 0.0 and panel_control.position.y >= 0.0
		and panel_control.position.x + panel_control.size.x <= logical_phone.x
		and panel_control.position.y + panel_control.size.y <= logical_phone.y,
		"scaled portrait mini-game remains inside the logical Web viewport")
	assert((panel.get("_title") as Label).get_theme_font_size("font_size") \
		/ ui_scale >= 23.5, "portrait mini-game title remains at least 24 physical pixels")
	for button in touch_buttons.values():
		assert((button as Button).custom_minimum_size.y / ui_scale >= 51.5,
			"portrait mini-game touch controls remain at least 52 physical pixels")
	assert((panel.get("_board") as Control).custom_minimum_size.y / ui_scale >= 149.5,
		"portrait mini-game board remains physically playable")

	var logical_landscape := Vector2(2405.0, 1112.0)
	var physical_landscape := Vector2(844.0, 390.0)
	panel.call("_layout_for_viewport", logical_landscape, physical_landscape)
	await process_frame
	ui_scale = float(panel.get_meta("minigame_ui_scale", 0.0))
	assert(touch.columns == 6, "physical landscape mini-games use one compact control row")
	assert((panel.get("_board") as Control).custom_minimum_size.y / ui_scale >= 104.5,
		"physical landscape mini-game board keeps a 105-pixel play area")
	for button in touch_buttons.values():
		assert((button as Button).custom_minimum_size.y / ui_scale >= 47.5,
			"landscape mini-game controls remain at least 48 physical pixels")
	panel.call("_layout")


func _send_joy_button(panel: CanvasLayer, command: String) -> void:
	var buttons := {
		"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT,
		"up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN,
		"action": JOY_BUTTON_A,
	}
	var event := InputEventJoypadButton.new()
	event.button_index = buttons[command]
	event.pressed = true
	panel.call("_unhandled_input", event)
	event.pressed = false
	panel.call("_unhandled_input", event)


func _send_joy_axis(panel: CanvasLayer, axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	panel.call("_unhandled_input", event)


func _complete_through_player_input(panel: CanvasLayer) -> Dictionary:
	match panel.challenge_mode():
		"align":
			for target in panel.get("_spec").get("targets", []):
				_steer_cursor(panel, float(target), float(panel.get("_spec").get("speed", .65)))
				_send_key(panel, KEY_SPACE)
		"route":
			var route: Array = panel.get("_spec").get("route", [])
			var hazards: Array = panel.get("_spec").get("hazards", [])
			while int(panel.get("_score")) < int(panel.get("_spec").goal):
				var target: Vector2i = route[int(panel.get("_score"))]
				for command in _grid_path(panel.get("_grid"), target, hazards):
					_send_command_key(panel, command)
		"rhythm":
			for command in panel.get("_spec").get("sequence", []):
				_send_command_key(panel, str(command))
		"catch", "dodge":
			_drive_falling_game(panel)
	assert(bool(panel.get("_finished")), "%s completes through player input" % panel.challenge_mode())
	return panel.completion_result()


func _drive_falling_game(panel: CanvasLayer) -> void:
	var guard := 0
	while not bool(panel.get("_finished")) and guard < 2400:
		guard += 1
		var desired := .5
		var falling: Array = panel.get("_falling")
		if not falling.is_empty():
			var nearest: Dictionary = falling[0]
			for item in falling:
				if float(item.y) > float(nearest.y): nearest = item
			if panel.challenge_mode() == "catch" and not bool(nearest.bad):
				desired = float(nearest.x)
			else:
				desired = .05 if float(nearest.x) > .5 else .95
		_set_keyboard_direction(panel, desired)
		panel._process(.05)
		if panel.challenge_mode() == "dodge" and bool(panel.get("_ready_to_strike")):
			_send_key(panel, KEY_SPACE)
	_set_keyboard_direction(panel, float(panel.get("_cursor").x))
	assert(guard < 2400, "%s completes within a playable time bound" % panel.challenge_mode())


func _steer_cursor(panel: CanvasLayer, target: float, speed: float) -> void:
	var current := float(panel.get("_cursor").x)
	if absf(target - current) <= .002:
		return
	var command := "right" if target > current else "left"
	_send_direction(panel, command, true)
	panel._process(absf(target - current) / speed)
	_send_direction(panel, command, false)


func _set_keyboard_direction(panel: CanvasLayer, target: float) -> void:
	var current := float(panel.get("_cursor").x)
	_send_direction(panel, "left", target < current - .018)
	_send_direction(panel, "right", target > current + .018)


func _send_command_key(panel: CanvasLayer, command: String) -> void:
	var keys := {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN}
	_send_key(panel, keys[command])


func _send_key(panel: CanvasLayer, keycode: Key) -> void:
	_send_key_state(panel, keycode, true)
	_send_key_state(panel, keycode, false)


func _send_direction(panel: CanvasLayer, command: String, pressed: bool) -> void:
	_send_key_state(panel, KEY_LEFT if command == "left" else KEY_RIGHT, pressed)


func _send_key_state(panel: CanvasLayer, keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
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


func _exercise_touch_controls(panel: CanvasLayer) -> void:
	var buttons := {}
	for candidate in panel.find_children("*", "Button", true, false):
		var button := candidate as Button
		if button.has_meta("minigame_command"):
			buttons[str(button.get_meta("minigame_command"))] = button
	assert(buttons.has("left") and buttons.has("right") and buttons.has("action"))
	match panel.challenge_mode():
		"align", "catch", "dodge":
			var before := float(panel.get("_cursor").x)
			(buttons.left as Button).button_down.emit()
			panel._process(.12)
			(buttons.left as Button).button_up.emit()
			assert(float(panel.get("_cursor").x) < before,
				"touch hold moves the continuous %s game" % panel.challenge_mode())
		"route", "rhythm":
			(buttons.left as Button).pressed.emit()
			(buttons.action as Button).pressed.emit()
			assert(int(panel.get("_score")) <= 1,
				"touch reset restores the %s game" % panel.challenge_mode())
