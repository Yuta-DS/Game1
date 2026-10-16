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
const BUTTON_RIGHT_SHOULDER := 10
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
		"charged_attack": BUTTON_RIGHT_SHOULDER,
		"dodge": BUTTON_B,
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
		"charged_attack": _button_event(BUTTON_RIGHT_SHOULDER),
		"dodge": _button_event(BUTTON_B),
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
	if not bool(player.call("_web_touch_interface_likely", true, 1, 1366.0)):
		_fail("a coarse-pointer tablet does not request touch controls")
		return
	if not bool(player.call("_web_touch_interface_likely", false, 1, 390.0)):
		_fail("a narrow hybrid touch device does not request touch controls")
		return
	if bool(player.call("_web_touch_interface_likely", false, 1, 1256.0)):
		_fail("a wide fine-pointer browser incorrectly starts with the phone HUD")
		return
	if bool(player.call("_web_touch_interface_likely", false, 0, 390.0)):
		_fail("a browser without touch hardware incorrectly requests touch controls")
		return
	var gentle_stick := player.call("get_camera_relative_move_direction",
		Vector2(0.35, 0.0)) as Vector3
	if not is_equal_approx(gentle_stick.length(), 0.35):
		_fail("a partial analog tilt does not preserve gradual walking speed")
		return
	var full_diagonal := player.call("get_camera_relative_move_direction",
		Vector2.ONE.normalized()) as Vector3
	if not is_equal_approx(full_diagonal.length(), 1.0):
		_fail("full keyboard/D-pad diagonal movement loses unit speed")
		return
	var touch := player.get_node_or_null("TouchControlHUD/TouchControls") as Control
	if touch == null or touch.get_child_count() != 10:
		_fail("the playable character does not build ten complete touch controls")
		return
	for expected_label in {"Up": "UP", "Left": "LEFT", "Down": "DOWN", "Right": "RIGHT"}:
		if (touch.get_node(expected_label) as Button).text != expected_label.to_upper():
			_fail("touch direction %s does not use its portable ASCII label" % expected_label)
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
			_fail("touch target %s leaves the 320×568 viewport: position=%s size=%s scale=%.3f" \
				% [child.name, str(button.position), str(button.size),
				float(player.get_meta("touch_control_ui_scale", 0.0))])
			return
	var right := touch.get_node("Right") as Button
	var jump := touch.get_node("Jump") as Button
	if right.get_global_rect().intersects(jump.get_global_rect()):
		_fail("movement and action controls overlap on a narrow phone")
		return

	# Production uses canvas_items against a 1710×1112 design surface. A phone
	# therefore exposes a much larger logical viewport than its CSS-pixel size;
	# verify the real layout compensates instead of shrinking 52 logical pixels
	# into a roughly 12-pixel control.
	var logical_phone := Vector2(1710.0, 3700.0)
	var physical_phone := Vector2(390.0, 844.0)
	var selected_phone_size: Vector2 = player.call("_select_touch_physical_size",
		logical_phone, Vector2(710.0, 1536.0), physical_phone)
	if selected_phone_size != physical_phone:
		_fail("Web touch sizing does not prefer the stable CSS viewport")
		return
	player.call("_layout_touch_controls", logical_phone, physical_phone)
	var touch_scale := float(player.get_meta("touch_control_ui_scale", 0.0))
	if touch_scale < 4.0 or str(player.get_meta("touch_control_layout", "")) \
			!= "screen_pixel_safe_v2":
		_fail("portrait Web layout does not compensate for canvas_items scaling")
		return
	for child in touch.get_children():
		var scaled_button := child as Button
		if scaled_button == null \
				or scaled_button.size.x / touch_scale < 58.0 \
				or scaled_button.size.y / touch_scale < 58.0:
			_fail("portrait touch target %s is smaller than 58 physical pixels" % child.name)
			return
		if scaled_button.position.x < 0.0 or scaled_button.position.y < 0.0 \
				or scaled_button.position.x + scaled_button.size.x > logical_phone.x \
				or scaled_button.position.y + scaled_button.size.y > logical_phone.y:
			_fail("scaled portrait touch target %s leaves the logical viewport" % child.name)
			return
	right = touch.get_node("Right") as Button
	jump = touch.get_node("Jump") as Button
	var vitals := player.get_node_or_null("CombatHelpHUD/CombatVitals") as Control
	var up := touch.get_node("Up") as Button
	if vitals == null or vitals.get_global_rect().intersects(up.get_global_rect()) \
			or vitals.get_global_rect().intersects((touch.get_node("Left") as Button).get_global_rect()) \
			or vitals.get_global_rect().intersects((touch.get_node("Down") as Button).get_global_rect()) \
			or vitals.get_global_rect().intersects(right.get_global_rect()) \
			or str(vitals.get_meta("touch_layout", "")) != "above_direction_controls":
		_fail("health/focus bars overlap the portrait movement controls")
		return
	if right.get_global_rect().intersects(jump.get_global_rect()):
		_fail("screen-pixel-safe movement and action controls overlap")
		return
	var logical_landscape := Vector2(2405.0, 1112.0)
	var physical_landscape := Vector2(844.0, 390.0)
	player.call("_layout_touch_controls", logical_landscape, physical_landscape)
	touch_scale = float(player.get_meta("touch_control_ui_scale", 0.0))
	for child in touch.get_children():
		var landscape_button := child as Button
		if landscape_button == null \
				or landscape_button.size.x / touch_scale < 64.0 \
				or landscape_button.get_theme_font_size("font_size") / touch_scale < 15.5:
			_fail("landscape touch target %s is not readable at physical size" % child.name)
			return
		if landscape_button.position.x < 0.0 or landscape_button.position.y < 0.0 \
				or landscape_button.position.x + landscape_button.size.x > logical_landscape.x \
				or landscape_button.position.y + landscape_button.size.y > logical_landscape.y:
			_fail("landscape touch target %s leaves the viewport" % child.name)
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
	touch_right.button_down.emit()
	player.call("set_input_enabled", false)
	if touch.visible or Input.is_action_pressed("move_right"):
		_fail("dialogue/input lock does not hide the gameplay HUD and release held touch input")
		return
	player.call("set_input_enabled", true)
	if not touch.visible:
		_fail("touch gameplay HUD does not return when character input resumes")
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
	var detected_player := PlayerScene.instantiate() as CharacterBody3D
	root.add_child(detected_player)
	await process_frame
	# The native headless DisplayServer reports touch support, so remove its
	# eagerly built fixture and exercise the ambiguous-Web recovery path in
	# isolation. The policy function above covers the real wide-browser choice.
	var detected_layer := detected_player.get_node_or_null("TouchControlHUD")
	if detected_layer != null:
		detected_layer.free()
	detected_player.set("_touch_hud", null)
	detected_player.set("_touch_buttons", {})
	detected_player.call("_input", screen_touch)
	if detected_player.get_node_or_null("TouchControlHUD/TouchControls") == null:
		_fail("a first real touch does not reveal controls after ambiguous detection")
		return
	detected_player.queue_free()
	await process_frame

	print("WORLD_ONE_GAMEPAD_ERGONOMICS_TEST: PASS — gamepad mappings, analog walking, combat actions, adaptive HUD hints, and ten non-overlapping phone controls work")
	quit(0)
