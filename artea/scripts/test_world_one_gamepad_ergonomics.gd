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

	print("WORLD_ONE_GAMEPAD_ERGONOMICS_TEST: PASS — left stick, D-pad, face buttons, shoulder block, run, interaction, and UI navigation are mapped")
	quit(0)
