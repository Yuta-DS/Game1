extends CanvasLayer

const Catalog := preload("res://scripts/mind_spark/world_one_object_minigame_catalog.gd")
const GardenRules := preload("res://scripts/mind_spark/unfinished_light_rules.gd")

class ArcadeBoard extends Control:
	var host: CanvasLayer

	func _draw() -> void:
		if host == null:
			return
		var ui_scale := maxf(host._ui_scale, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_scale)
		var rect := Rect2(Vector2.ZERO, size / ui_scale)
		draw_rect(rect, Color("102f38"), true)
		draw_rect(rect.grow(-3), Color("315b5c"), false, 3.0)
		match host._mode:
			"align": _draw_align()
			"route": _draw_route()
			"rhythm": _draw_rhythm()
			"catch": _draw_fall(false)
			"dodge": _draw_fall(true)

	func _draw_align() -> void:
		var canvas := size / maxf(host._ui_scale, 1.0)
		var y := canvas.y * .55
		draw_line(Vector2(35, y), Vector2(canvas.x - 35, y), Color("66878b"), 8, true)
		var targets: Array = host._spec.get("targets", [])
		for i in targets.size():
			var x := lerpf(40.0, canvas.x - 40.0, float(targets[i]))
			var colour: Color = Color("6b735f") if i >= host._score else host._accent
			draw_arc(Vector2(x, y), 18, 0, TAU, 30, colour, 5, true)
		var marker_x := lerpf(40.0, canvas.x - 40.0, host._cursor.x)
		draw_line(Vector2(marker_x, y - 60), Vector2(marker_x, y + 60), host._accent, 6, true)
		draw_circle(Vector2(marker_x, y), 9, Color("fff4dc"))

	func _draw_route() -> void:
		var canvas := size / maxf(host._ui_scale, 1.0)
		var cell := minf(canvas.x, canvas.y) / 4.1
		var origin := (canvas - Vector2(cell * 3, cell * 3)) * .5
		var route: Array = host._spec.get("route", [])
		var hazards: Array = host._spec.get("hazards", [])
		for y in 3:
			for x in 3:
				var grid := Vector2i(x, y)
				var box := Rect2(origin + Vector2(x, y) * cell, Vector2.ONE * (cell - 6))
				var colour := Color("173f47")
				if grid in hazards: colour = Color("563744")
				if grid in route:
					var route_index := route.find(grid)
					colour = host._accent.darkened(.25) if route_index >= host._score else Color("466358")
				draw_rect(box, colour, true)
				draw_rect(box, Color("79999b"), false, 2)
				if grid in route:
					draw_string(ThemeDB.fallback_font, box.position + Vector2(cell*.36, cell*.62), str(route.find(grid)+1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("fff4dc"))
		var player_box := Rect2(origin + Vector2(host._grid) * cell + Vector2.ONE * 10, Vector2.ONE * (cell - 26))
		draw_circle(player_box.get_center(), player_box.size.x * .28, Color("fff4dc"))
		draw_arc(player_box.get_center(), player_box.size.x * .36, 0, TAU, 24, host._accent, 4, true)

	func _draw_rhythm() -> void:
		var canvas := size / maxf(host._ui_scale, 1.0)
		var sequence: Array = host._spec.get("sequence", [])
		# Direction letters remain legible in the compact Web font. The former
		# Unicode arrows degraded into missing-glyph squares on the live build.
		var names := {"left": "L", "right": "R", "up": "U", "down": "D"}
		var width := canvas.x / maxf(1.0, sequence.size())
		for i in sequence.size():
			var center := Vector2(width * (i + .5), canvas.y * .53)
			var colour: Color = host._accent if i < host._score else Color("66878b")
			if i == host._score: draw_circle(center, 43, host._accent.darkened(.45))
			draw_string(ThemeDB.fallback_font, center + Vector2(-16, 13), names[str(sequence[i])], HORIZONTAL_ALIGNMENT_LEFT, -1, 38, colour)

	func _draw_fall(dodging: bool) -> void:
		var canvas := size / maxf(host._ui_scale, 1.0)
		for item in host._falling:
			var pos := Vector2(float(item.x) * canvas.x, float(item.y) * canvas.y)
			var harmful := bool(item.bad)
			var colour: Color = Color("fa6f77") if harmful else host._accent
			if dodging:
				draw_line(pos - Vector2(34, 0), pos + Vector2(34, 0), colour, 8, true)
			else:
				draw_circle(pos, 11, colour)
				draw_arc(pos, 17, 0, TAU, 20, colour.lightened(.3), 2, true)
		var paddle := Vector2(host._cursor.x * canvas.x, canvas.y - 28)
		if dodging:
			draw_circle(paddle, 14, Color("fff4dc"))
			draw_arc(paddle, 20, 0, TAU, 24, host._accent, 4, true)
		else:
			draw_arc(paddle, 27, 0, PI, 24, host._accent, 8, true)
		if dodging and host._ready_to_strike:
			draw_string(ThemeDB.fallback_font, Vector2(canvas.x*.31, 45), "SHIELD OPEN • STRIKE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("fff4dc"))


var station: QuestObjectBase
var player: Node3D
var world: Node
var _spec: Dictionary = {}
var _mode := ""
var _score := 0
var _mistakes := 0
var _cursor := Vector2(.5, .5)
var _grid := Vector2i(1, 2)
var _falling: Array[Dictionary] = []
var _spawn_count := 0
var _spawn_clock := 0.0
var _elapsed := 0.0
var _ready_to_strike := false
var _finished := false
var _last_result: Dictionary = {}
var _left_held := false
var _right_held := false
var _joy_x_command := ""
var _joy_y_command := ""
var _board: ArcadeBoard
var _status: Label
var _progress: Label
var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _body: VBoxContainer
var _title: Label
var _instruction: Label
var _touch: GridContainer
var _touch_buttons: Dictionary = {}
var _close: Button
var _player_physics := false
var _mouse_mode := Input.MOUSE_MODE_CAPTURED
var _rng := RandomNumberGenerator.new()
var _accent := Color("72e6c5")
var _ui_scale := 1.0


func open_object(object: QuestObjectBase, actor: Node3D) -> void:
	station = object
	player = actor
	world = object
	while world != null and not world.has_method("_handle_object_result"):
		world = world.get_parent()
	_spec = Catalog.challenge(object.save_id)
	assert(not _spec.is_empty(), "Every World One quest object requires a minigame")
	_mode = str(_spec.mode)
	_accent = _spec.accent
	_rng.seed = hash(object.save_id)
	_reset_round()
	_build_ui()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _reset_round() -> void:
	_score = 0
	_mistakes = 0
	_cursor = Vector2(.5, .5)
	_grid = Vector2i(1, 2)
	_falling.clear()
	_spawn_count = 0
	_spawn_clock = 0.0
	_elapsed = 0.0
	_ready_to_strike = false
	_finished = false
	_last_result = {}
	_left_held = false
	_right_held = false
	_joy_x_command = ""
	_joy_y_command = ""
	if _mode == "route":
		var route: Array = _spec.get("route", [])
		if not route.is_empty() and _grid == route[0]:
			_score = 1


func _build_ui() -> void:
	if is_instance_valid(player):
		_player_physics = player.is_physics_processing()
		player.set_physics_process(false)
	_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	layer = 90
	var shade := ColorRect.new()
	shade.color = Color(0.01, .025, .04, .84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = PanelContainer.new()
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color("e9dfc6")
	_panel_style.border_color = _accent
	_panel_style.set_border_width_all(4)
	_panel_style.set_corner_radius_all(14)
	_panel_style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", _panel_style)
	add_child(_panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 9)
	_panel.add_child(_body)
	_title = Label.new()
	_title.text = str(_spec.title)
	_title.add_theme_font_size_override("font_size", 27)
	_title.add_theme_color_override("font_color", Color("183c42"))
	_body.add_child(_title)
	_instruction = Label.new()
	_instruction.text = str(_spec.instruction)
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction.add_theme_font_size_override("font_size", 17)
	_instruction.add_theme_color_override("font_color", Color("315b5c"))
	_body.add_child(_instruction)
	_board = ArcadeBoard.new()
	_board.host = self
	_board.custom_minimum_size = Vector2(590, 330)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_board)
	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 18)
	_progress.add_theme_color_override("font_color", Color("183c42"))
	_body.add_child(_progress)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", Color("704e35"))
	_body.add_child(_status)
	_touch = GridContainer.new()
	_touch.columns = 5
	_touch.add_theme_constant_override("h_separation", 8)
	_touch.add_theme_constant_override("v_separation", 6)
	_body.add_child(_touch)
	_add_touch_button("left", "LEFT")
	_add_touch_button("up", "UP")
	_add_touch_button("action", _action_caption())
	_add_touch_button("down", "DOWN")
	_add_touch_button("right", "RIGHT")
	_close = Button.new()
	_close.text = "Return to World One · Esc / B"
	_close.custom_minimum_size.y = 52
	_close.focus_mode = Control.FOCUS_ALL
	_close.pressed.connect(queue_free)
	_body.add_child(_close)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_update_labels({
		"align": "Move with Left/Right, A/D, D-pad or left stick. Press Space/A inside each ring.",
		"route": "Move with arrows, WASD, D-pad or left stick. Space/A resets the route.",
		"rhythm": "Repeat the arrows with WASD, D-pad or left stick. Space/A resets.",
		"catch": "Move with Left/Right, A/D, D-pad or left stick. Catch light; avoid static.",
		"dodge": "Move with Left/Right, A/D, D-pad or left stick. Press Space/A when open.",
	}.get(_mode, "Use arrow keys or WASD."))


func _action_caption() -> String:
	match _mode:
		"align": return "LOCK"
		"dodge": return "STRIKE"
		"catch": return "RESTART"
		"route", "rhythm": return "RESET"
	return "ACTION"


func _add_touch_button(command: String, caption: String) -> void:
	var button := Button.new()
	button.text = caption
	button.set_meta("minigame_command", command)
	button.tooltip_text = "%s control" % command.capitalize()
	button.custom_minimum_size = Vector2(82, 52)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	if command in ["left", "right"] and _mode in ["align", "catch", "dodge"]:
		button.button_down.connect(func(): _set_direction_held(command, true))
		button.button_up.connect(func(): _set_direction_held(command, false))
	else:
		button.pressed.connect(func(): _command(command))
	_touch.add_child(button)
	_touch_buttons[command] = button


func _layout() -> void:
	var viewport := get_viewport().get_visible_rect().size
	if viewport.x <= 0.0 or viewport.y <= 0.0:
		viewport = Vector2(get_window().size)
	_layout_for_viewport(viewport, _minigame_physical_size(viewport))


func _layout_for_viewport(viewport: Vector2,
		physical_size: Vector2 = Vector2.ZERO) -> void:
	if physical_size.is_zero_approx():
		physical_size = viewport
	_ui_scale = _minigame_interface_scale(viewport, physical_size)
	scale = Vector2.ONE
	var physical_width := minf(680.0, maxf(280.0, physical_size.x - 24.0))
	var physical_height := minf(650.0, maxf(300.0, physical_size.y - 24.0))
	var narrow := physical_width < 520.0
	var short := physical_height < 520.0
	var width := physical_width * _ui_scale
	var height := physical_height * _ui_scale
	var margin_px := 10.0 if short else (14.0 if narrow else 20.0)
	var margin := margin_px * _ui_scale
	_panel_style.set_border_width_all(maxi(2, roundi(4.0 * _ui_scale)))
	_panel_style.set_corner_radius_all(roundi(14.0 * _ui_scale))
	_panel_style.set_content_margin_all(margin)
	_body.add_theme_constant_override("separation",
		roundi((5.0 if short else 9.0) * _ui_scale))
	_title.add_theme_font_size_override("font_size",
		roundi((21.0 if short else (24.0 if narrow else 27.0)) * _ui_scale))
	_instruction.add_theme_font_size_override("font_size",
		roundi((13.0 if short else (15.0 if narrow else 17.0)) * _ui_scale))
	_progress.add_theme_font_size_override("font_size",
		roundi((15.0 if short else 18.0) * _ui_scale))
	_status.add_theme_font_size_override("font_size",
		roundi((13.0 if short else 16.0) * _ui_scale))
	_configure_touch_layout(narrow, short)
	var columns := _touch.columns
	var button_width_px := floorf((physical_width - margin_px * 2.0 \
		- float(columns - 1) * 8.0) / float(columns))
	button_width_px = clampf(button_width_px, 56.0 if short else 64.0, 104.0)
	_touch.add_theme_constant_override("h_separation", roundi(8.0 * _ui_scale))
	_touch.add_theme_constant_override("v_separation", roundi(6.0 * _ui_scale))
	for button in _touch_buttons.values():
		if not (button as Button).visible:
			continue
		(button as Button).custom_minimum_size = Vector2(button_width_px,
			48.0 if short else 52.0) * _ui_scale
		(button as Button).add_theme_font_size_override("font_size",
			roundi(18.0 * _ui_scale))
	_close.custom_minimum_size = Vector2(button_width_px if narrow or short else 0.0,
		48.0 if short else 52.0) * _ui_scale
	_close.add_theme_font_size_override("font_size", roundi(16.0 * _ui_scale))
	if _board != null:
		var board_height_px := physical_height \
			- (260.0 if short else (384.0 if narrow else 280.0))
		_board.custom_minimum_size = Vector2(physical_width - margin_px * 2.0,
			clampf(board_height_px, 105.0 if short else 150.0, 350.0)) * _ui_scale
	_panel.position = (viewport - Vector2(width, height)) * .5
	_panel.size = Vector2(width, height)
	_panel.set_deferred("size", Vector2(width, height))
	set_meta("minigame_layout", "physical_viewport_v2")
	set_meta("minigame_ui_scale", _ui_scale)
	set_meta("minigame_physical_size", physical_size)


func _minigame_physical_size(viewport_size: Vector2) -> Vector2:
	var display_size := Vector2(DisplayServer.window_get_size())
	var css_size := Vector2.ZERO
	if OS.has_feature("web"):
		var encoded := str(JavaScriptBridge.eval(
			"JSON.stringify([window.innerWidth || 0, window.innerHeight || 0])", true))
		if encoded.begins_with("["):
			var decoded: Variant = JSON.parse_string(encoded)
			if decoded is Array and decoded.size() >= 2:
				css_size = Vector2(float(decoded[0]), float(decoded[1]))
	return _select_minigame_physical_size(viewport_size, display_size, css_size)


func _select_minigame_physical_size(viewport_size: Vector2,
		display_size: Vector2, css_size: Vector2 = Vector2.ZERO) -> Vector2:
	if css_size.x >= 240.0 and css_size.y >= 240.0:
		return css_size
	if display_size.x >= 240.0 and display_size.y >= 240.0:
		return display_size
	return viewport_size


func _minigame_interface_scale(viewport_size: Vector2,
		physical_size: Vector2) -> float:
	if physical_size.x <= 0.0 or physical_size.y <= 0.0:
		return 1.0
	return maxf(1.0, maxf(viewport_size.x / physical_size.x,
		viewport_size.y / physical_size.y))


func _configure_touch_layout(narrow: bool, short: bool) -> void:
	if _touch == null:
		return
	var uses_vertical := _mode in ["route", "rhythm"]
	(_touch_buttons.up as Button).visible = uses_vertical
	(_touch_buttons.down as Button).visible = uses_vertical
	var order: Array[Control]
	if not uses_vertical:
		if narrow or short:
			if _close.get_parent() != _touch:
				_close.reparent(_touch)
			_close.text = "BACK · B"
			_touch.columns = 4
			order = [_touch_buttons.left, _touch_buttons.action,
				_touch_buttons.right, _close]
		else:
			if _close.get_parent() != _body:
				_close.reparent(_body)
			_body.move_child(_close, _touch.get_index() + 1)
			_close.text = "Return to World One · Esc / B"
			_touch.columns = 3
			order = [_touch_buttons.left, _touch_buttons.action, _touch_buttons.right]
	elif narrow:
		_touch.columns = 3
		if _close.get_parent() != _touch:
			_close.reparent(_touch)
		_close.text = "BACK · B"
		order = [_touch_buttons.up, _touch_buttons.action, _touch_buttons.down,
			_touch_buttons.left, _close, _touch_buttons.right]
	elif short:
		_touch.columns = 6
		if _close.get_parent() != _touch:
			_close.reparent(_touch)
		_close.text = "BACK · B"
		order = [_touch_buttons.left, _touch_buttons.up, _touch_buttons.action,
			_touch_buttons.down, _touch_buttons.right, _close]
	else:
		_touch.columns = 5
		if _close.get_parent() != _body:
			_close.reparent(_body)
		_body.move_child(_close, _touch.get_index() + 1)
		_close.text = "Return to World One · Esc / B"
		order = [_touch_buttons.left, _touch_buttons.up, _touch_buttons.action,
			_touch_buttons.down, _touch_buttons.right]
	for index in order.size():
		_touch.move_child(order[index], index)


func _process(delta: float) -> void:
	if _finished or _board == null:
		return
	_elapsed += delta
	if _mode == "align":
		var direction := float(int(_right_held) - int(_left_held))
		_cursor.x = clampf(_cursor.x + direction * delta * float(_spec.get("speed", .65)), .02, .98)
	elif _mode in ["catch", "dodge"]:
		var direction := float(int(_right_held) - int(_left_held))
		_cursor.x = clampf(_cursor.x + direction * delta * 1.15, .04, .96)
		_spawn_clock -= delta
		if _spawn_clock <= 0 and not _ready_to_strike:
			_spawn_clock = .68 if _mode == "catch" else .58
			_spawn_falling()
		_update_falling(delta)
		if _mode == "dodge" and _score >= int(_spec.goal):
			_ready_to_strike = true
			_falling.clear()
			_update_labels("Shield open. Press Space to strike the crystal.")
	_board.queue_redraw()


func _spawn_falling() -> void:
	# Advance independently of score. Avoiding a harmful drop changes neither
	# score nor mistakes, so deriving this index from those values repeated the
	# same harmful drop forever and made catch games impossible to finish.
	var index := _spawn_count
	_spawn_count += 1
	var x := .12 + fmod(float(index * 37 + int(_spec.get("pattern", 0)) * 19), 77.0) / 100.0
	var bad := _mode == "dodge" or (_mode == "catch" and index % 3 == 2)
	_falling.append({"x": x, "y": -.04, "bad": bad})


func _update_falling(delta: float) -> void:
	var fall_speed := float(_spec.get("speed", .6))
	for index in range(_falling.size() - 1, -1, -1):
		var item: Dictionary = _falling[index]
		item.y = float(item.y) + delta * fall_speed
		_falling[index] = item
		if float(item.y) < .88:
			continue
		var touched := absf(float(item.x) - _cursor.x) < .105
		if _mode == "catch":
			if touched and not bool(item.bad):
				_score += 1
				_update_labels("Spark captured. Keep tracking the signal.")
			elif touched and bool(item.bad):
				_mistakes += 1
				_score = maxi(0, _score - 1)
				_rumble_feedback(.45, .75, .12)
				_update_labels("Static touched the receiver. Re-centre and continue.")
		else:
			if touched:
				_mistakes += 1
				_score = maxi(0, _score - 1)
				_rumble_feedback(.45, .75, .12)
				_update_labels("The storm line clipped you. Read the next lane.")
			else:
				_score += 1
		_falling.remove_at(index)
		if _mode == "catch" and _score >= int(_spec.goal):
			_win()
			return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var command := _key_command(event.keycode)
		_handle_digital_command(command, event.pressed)
		if not command.is_empty():
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		var command := _joypad_button_command(event.button_index)
		_handle_digital_command(command, event.pressed)
		if not command.is_empty():
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		if _handle_joypad_motion(event):
			get_viewport().set_input_as_handled()


func _handle_digital_command(command: String, pressed: bool) -> void:
	if command == "close" and pressed:
		queue_free()
	elif command in ["left", "right"]:
		_set_direction_held(command, pressed)
		if pressed and _mode in ["route", "rhythm"]:
			_command(command)
	elif pressed and not command.is_empty():
		_command(command)


func _joypad_button_command(button_index: JoyButton) -> String:
	match button_index:
		JOY_BUTTON_DPAD_LEFT: return "left"
		JOY_BUTTON_DPAD_RIGHT: return "right"
		JOY_BUTTON_DPAD_UP: return "up"
		JOY_BUTTON_DPAD_DOWN: return "down"
		JOY_BUTTON_A: return "action"
		JOY_BUTTON_B: return "close"
	return ""


func _handle_joypad_motion(event: InputEventJoypadMotion) -> bool:
	const PRESS_THRESHOLD := 0.46
	const RELEASE_THRESHOLD := 0.24
	if event.axis == JOY_AXIS_LEFT_X:
		var next := _axis_command(event.axis_value, "left", "right",
			_joy_x_command, PRESS_THRESHOLD, RELEASE_THRESHOLD)
		if next == _joy_x_command:
			return not next.is_empty()
		_set_direction_held("left", next == "left")
		_set_direction_held("right", next == "right")
		_joy_x_command = next
		if not next.is_empty() and _mode in ["route", "rhythm"]:
			_command(next)
		return true
	if event.axis == JOY_AXIS_LEFT_Y:
		var next := _axis_command(event.axis_value, "up", "down",
			_joy_y_command, PRESS_THRESHOLD, RELEASE_THRESHOLD)
		if next == _joy_y_command:
			return not next.is_empty()
		_joy_y_command = next
		if not next.is_empty() and _mode in ["route", "rhythm"]:
			_command(next)
		return true
	return false


func _axis_command(value: float, negative: String, positive: String,
		current: String, press_threshold: float, release_threshold: float) -> String:
	if current.is_empty():
		if value <= -press_threshold: return negative
		if value >= press_threshold: return positive
		return ""
	if absf(value) <= release_threshold:
		return ""
	if value <= -press_threshold:
		return negative
	if value >= press_threshold:
		return positive
	return current


func _set_direction_held(command: String, held: bool) -> void:
	if command == "left":
		_left_held = held
	elif command == "right":
		_right_held = held


func _key_command(keycode: Key) -> String:
	if keycode in [KEY_LEFT, KEY_A]: return "left"
	if keycode in [KEY_RIGHT, KEY_D]: return "right"
	if keycode in [KEY_UP, KEY_W]: return "up"
	if keycode in [KEY_DOWN, KEY_S]: return "down"
	if keycode in [KEY_SPACE, KEY_ENTER]: return "action"
	if keycode == KEY_ESCAPE: return "close"
	return ""


func _command(command: String) -> void:
	if _finished:
		if command == "action":
			_reset_round()
			_update_labels("Practice replay started.")
		return
	if command == "action" and _mode in ["route", "rhythm", "catch"]:
		_reset_round()
		_update_labels("Challenge reset. Try the pattern again.")
		if _board != null: _board.queue_redraw()
		return
	match _mode:
		"align":
			if command == "action": _lock_alignment()
		"route": _move_route(command)
		"rhythm": _play_rhythm(command)
		"dodge":
			if command == "action" and _ready_to_strike: _win()
	if _board != null: _board.queue_redraw()


func _lock_alignment() -> void:
	var targets: Array = _spec.get("targets", [])
	if _score >= targets.size():
		return
	if absf(_cursor.x - float(targets[_score])) <= .075:
		_score += 1
		_update_labels("Signal locked. Find the next ring.")
		if _score >= int(_spec.goal): _win()
	else:
		_mistakes += 1
		_rumble_feedback(.35, .65, .1)
		_update_labels("The pulse missed the ring. Adjust and try again.")


func _move_route(command: String) -> void:
	var step := {"left": Vector2i.LEFT, "right": Vector2i.RIGHT,
		"up": Vector2i.UP, "down": Vector2i.DOWN}.get(command, Vector2i.ZERO) as Vector2i
	if step == Vector2i.ZERO:
		return
	_grid = Vector2i(clampi(_grid.x + step.x, 0, 2), clampi(_grid.y + step.y, 0, 2))
	var hazards: Array = _spec.get("hazards", [])
	if _grid in hazards:
		_mistakes += 1
		_rumble_feedback(.4, .7, .12)
		_grid = Vector2i(1, 2)
		_score = 0
		_update_labels("Storm cell. The route gently resets.")
		return
	var route: Array = _spec.get("route", [])
	if _score < route.size() and _grid == route[_score]:
		_score += 1
		_update_labels("Star %d connected." % _score)
		if _score >= int(_spec.goal): _win()


func _play_rhythm(command: String) -> void:
	if command not in ["left", "right", "up", "down"]:
		return
	var sequence: Array = _spec.get("sequence", [])
	if command == str(sequence[_score]):
		_score += 1
		_update_labels("Tone %d is clear." % _score)
		if _score >= int(_spec.goal): _win()
	else:
		_mistakes += 1
		_rumble_feedback(.35, .65, .1)
		_score = 0
		_update_labels("That tone broke the pattern. Listen from the beginning.")


func _win() -> void:
	if _finished:
		return
	_finished = true
	_left_held = false
	_right_held = false
	_rumble_feedback(.25, .8, .18)
	_last_result = _apply_station_reward()
	_update_labels("Challenge complete • " + str(_last_result.get("reason", "practice_complete")).replace("_", " ").capitalize() + "\nPress Space to replay, or Esc to return.")
	if _board != null: _board.queue_redraw()


func _rumble_feedback(weak: float, strong: float, duration: float) -> void:
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, weak, strong, duration)


func _apply_station_reward() -> Dictionary:
	var result := {"accepted": true, "reason": "practice_complete"}
	if station == null or not station.interaction_enabled:
		return {"accepted": false, "reason": "Finish the current objective to power this station"}
	if bool(station.get_meta("unfinished_light", false)) and station.save_id in GardenRules.IDS:
		result = _apply_unfinished_light_reward()
		if world != null and world.has_method("_handle_object_result"):
			world.call("_handle_object_result", station, result)
		return result
	match station.save_id:
		"world_one.checkpoint.landing", "world_one.checkpoint.network":
			result = station.interact(&"save")
		"world_one.path_projector":
			if not bool(station.current_state.get("guide_enabled", false)): result = station.interact(&"toggle")
		"world_one.spark_socket":
			result = station.interact(&"place_spark")
		"world_one.focus_bell":
			if not bool(station.current_state.get("hint_enabled", false)): result = station.interact(&"help")
		"world_one.evidence_scanner":
			while not bool(station.current_state.get("completed", false)):
				station.interact(&"scan")
				var index := int(station.current_state.get("evidence_index", 0))
				result = station.interact(station.EVIDENCE_ANSWERS[index])
		"world_one.memory_board":
			var node_ids := ["notice", "name", "choose"]
			for step in range((station.current_state.get("sequence", []) as Array).size(), node_ids.size()):
				if not bool(station.current_state.get("completed", false)): result = station.interact(&"node", node_ids[step])
		"world_one.logic_gate":
			for step in range(int(station.current_state.get("progress", 0)), station.definition.validated_total()):
				if not bool(station.current_state.get("completed", false)): result = station.interact(&"place_evidence")
		"world_one.perspective_lens":
			for step in range(int(station.current_state.get("progress", 0)), station.definition.validated_total()):
				if not bool(station.current_state.get("completed", false)): result = station.interact(&"turn")
		"world_one.truth_bridge": result = station.interact(&"true")
		"world_one.warden_anchor.1", "world_one.warden_anchor.2", "world_one.warden_anchor.3":
			station.interact(&"dodge")
			result = station.interact(&"strike")
		"world_one.calm_rain_basin": result = station.interact(&"hold")
		"world_one.identity_reflection":
			result = station.interact(&"answer_a" if _grid.x <= 1 else &"answer_b",
				"outward" if _grid.x <= 1 else "inward")
	if world != null and world.has_method("_handle_object_result"):
		world.call("_handle_object_result", station, result)
	return result


func _apply_unfinished_light_reward() -> Dictionary:
	var result := {"accepted": true, "reason": "practice_complete"}
	if bool(station.current_state.get("completed", false)):
		return result
	station.interact(&"reset")
	match station.save_id:
		"world_one.evidence_scanner":
			for channel in 3:
				station.interact(&"channel", channel)
				for turn in GardenRules.SCANNER_TARGETS[channel]:
					station.interact(&"adjust", channel)
				result = station.interact(&"capture", channel)
		"world_one.memory_board":
			station.interact(&"swap", 0)
			station.interact(&"swap", 1)
			result = station.interact(&"replay")
		"world_one.logic_gate":
			station.interact(&"trial", 0)
			station.interact(&"trial", 1)
			station.interact(&"model", 1)
			result = station.interact(&"test")
		"world_one.perspective_lens":
			for view in 3:
				station.interact(&"view", view)
				result = station.interact(&"interpret", view)
		"world_one.truth_bridge":
			station.interact(&"approach", 1)
			station.interact(&"tune", 0)
			station.interact(&"tune", 1)
			result = station.interact(&"project")
	return result


func _update_labels(message: String) -> void:
	if _progress != null:
		_progress.text = "PROGRESS  %d / %d    •    MISSES  %d" % [_score, int(_spec.get("goal", 1)), _mistakes]
	if _status != null:
		_status.text = message


func challenge_mode() -> String:
	return _mode


func complete_for_test() -> Dictionary:
	_finished = true
	_last_result = _apply_station_reward()
	return _last_result


func completion_result() -> Dictionary:
	return _last_result.duplicate(true)


func _exit_tree() -> void:
	Input.mouse_mode = _mouse_mode
	if is_instance_valid(player):
		player.set_physics_process(_player_physics)
