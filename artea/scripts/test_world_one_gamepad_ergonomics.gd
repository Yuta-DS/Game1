extends SceneTree

## Verifies the production InputMap exposes a complete, conventional gamepad
## path for World One. These mappings are consumed by Player3D, world gates,
## dialogue, combat, and the shared UI without device-specific glue code.

const BUTTON_A := 0
const BUTTON_B := 1
const BUTTON_X := 2
const BUTTON_Y := 3
const BUTTON_LEFT_STICK := 7
const BUTTON_LEFT_SHOULDER := 9
const DPAD_UP := 11
const DPAD_DOWN := 12
const DPAD_LEFT := 13
const DPAD_RIGHT := 14
const AXIS_LEFT_X := 0
const AXIS_LEFT_Y := 1
const PlayerScene := preload("res://scenes/player_3d.tscn")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("WORLD_ONE_GAMEPAD_ERGONOMICS_TEST: %s" % message)
	quit(1)


func _has_button(action: StringName, button: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton \
				and (event as InputEventJoypadButton).button_index == button:
			return true
	return false


func _has_axis(action: StringName, axis: int, direction: float) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			if motion.axis == axis and signf(motion.axis_value) == signf(direction):
				return true
	return false


func _axis_event(axis: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	return event


func _button_event(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	event.pressure = 1.0
	return event


func _run() -> void:
	var movement := {
		"move_left": [AXIS_LEFT_X, -1.0, DPAD_LEFT],
		"move_right": [AXIS_LEFT_X, 1.0, DPAD_RIGHT],
		"move_forward": [AXIS_LEFT_Y, -1.0, DPAD_UP],
		"move_backward": [AXIS_LEFT_Y, 1.0, DPAD_DOWN],
	}
	for action: StringName in movement:
		var expected: Array = movement[action]
		if not _has_axis(action, int(expected[0]), float(expected[1])):
			_fail("%s is missing its left-stick direction" % action)
			return
		if not _has_button(action, int(expected[2])):
			_fail("%s is missing its D-pad direction" % action)
			return

	var buttons := {
		"jump": BUTTON_A,
		"attack": BUTTON_X,
		"block": BUTTON_LEFT_SHOULDER,
		"interact": BUTTON_Y,
		"talk_to_milo": BUTTON_Y,
		"run": BUTTON_LEFT_STICK,
		"ui_accept": BUTTON_A,
		"ui_cancel": BUTTON_B,
	}
	for action: StringName in buttons:
		if not _has_button(action, int(buttons[action])):
			_fail("%s is missing controller button %d" % [action, int(buttons[action])])
			return

	# Exercise Godot's real InputMap matcher. Headless runs have no connected
	# joypad, so Input intentionally discards device state; event_is_action still
	# proves that production controller events resolve to the actions Player3D,
	# gates, combat, and UI consume.
	var matches := {
		"move_right": _axis_event(AXIS_LEFT_X, 0.82),
		"move_forward": _axis_event(AXIS_LEFT_Y, -0.64),
		"jump": _button_event(BUTTON_A),
		"ui_accept": _button_event(BUTTON_A),
		"interact": _button_event(BUTTON_Y),
		"talk_to_milo": _button_event(BUTTON_Y),
		"ui_cancel": _button_event(BUTTON_B),
		"attack": _button_event(BUTTON_X),
		"block": _button_event(BUTTON_LEFT_SHOULDER),
		"run": _button_event(BUTTON_LEFT_STICK),
	}
	for action: StringName in matches:
		if not InputMap.event_is_action(matches[action] as InputEvent, action):
			_fail("Godot does not match the controller event to %s" % action)
			return

	var player := PlayerScene.instantiate() as CharacterBody3D
	player.set("force_touch_controls", true)
	root.add_child(player)
	await process_frame
	var touch := player.get_node_or_null("TouchControlHUD/TouchControls") as Control
	if touch == null or touch.get_child_count() != 8:
		_fail("the playable character does not build eight touch controls")
		return
	player.call("_layout_touch_controls", Vector2(320.0, 568.0))
	for child in touch.get_children():
		var button := child as Button
		if button == null or button.size.x < 52.0 or button.size.y < 52.0:
			_fail("touch target %s is smaller than 52×52" % child.name)
			return
		if button.position.x < 0.0 or button.position.y < 0.0 \
				or button.position.x + button.size.x > 320.0 \
				or button.position.y + button.size.y > 568.0:
			_fail("touch target %s leaves the 320×568 viewport" % child.name)
			return
	var right := touch.get_node("Right") as Button
	var jump := touch.get_node("Jump") as Button
	if right.get_global_rect().intersects(jump.get_global_rect()):
		_fail("movement and action controls overlap on a narrow phone")
		return

	var touch_right := touch.get_node("Right") as Button
	touch_right.button_down.emit()
	if not Input.is_action_pressed("move_right"):
		_fail("holding the touch D-pad does not press player movement")
		return
	touch_right.button_up.emit()
	if Input.is_action_pressed("move_right"):
		_fail("releasing the touch D-pad leaves movement stuck")
		return
	var touch_talk := touch.get_node("Interact") as Button
	touch_talk.button_down.emit()
	if not Input.is_action_pressed("interact") or not Input.is_action_pressed("talk_to_milo"):
		_fail("the touch TALK control does not reach both interaction systems")
		return
	touch_talk.button_up.emit()
	if Input.is_action_pressed("interact") or Input.is_action_pressed("talk_to_milo"):
		_fail("releasing the touch TALK control leaves interaction stuck")
		return

	Input.action_press("run")
	if not is_equal_approx(float(player.call("get_input_speed_multiplier")), 1.55):
		_fail("the mapped run action does not accelerate the character")
		return
	Input.action_release("run")
	player.call("_set_blocking", true)
	if not is_equal_approx(float(player.call("get_input_speed_multiplier")), 0.38):
		_fail("shield movement does not override the run multiplier")
		return
	player.call("_set_blocking", false)

	var joy := _button_event(BUTTON_A)
	player.call("_input", joy)
	var hint := player.get_node("CombatHelpHUD/CombatHelpPanel/CombatHelpLabel") as Label
	if player.call("get_input_hint_mode") != "controller" \
			or not hint.text.contains("A") or not hint.text.contains("JUMP"):
		_fail("the live HUD does not switch to controller labels")
		return
	var screen_touch := InputEventScreenTouch.new()
	screen_touch.pressed = true
	player.call("_input", screen_touch)
	if player.call("get_input_hint_mode") != "touch" or not hint.text.contains("TALK"):
		_fail("the live HUD does not switch to touch labels")
		return
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_W
	player.call("_input", key)
	if player.call("get_input_hint_mode") != "keyboard" or not hint.text.contains("WASD"):
		_fail("the live HUD does not restore keyboard labels")
		return
	player.queue_free()
	await process_frame

	print("WORLD_ONE_GAMEPAD_ERGONOMICS_TEST: PASS — gamepad mappings, real run speed, adaptive HUD hints, and eight non-overlapping phone controls work")
	quit(0)
