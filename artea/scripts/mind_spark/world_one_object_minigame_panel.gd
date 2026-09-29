extends CanvasLayer

const Catalog := preload("res://scripts/mind_spark/world_one_object_minigame_catalog.gd")
const GardenRules := preload("res://scripts/mind_spark/unfinished_light_rules.gd")

class ArcadeBoard extends Control:
	var host: CanvasLayer

	func _draw() -> void:
		if host == null:
			return
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color("102f38"), true)
		draw_rect(rect.grow(-3), Color("315b5c"), false, 3.0)
		match host._mode:
			"align": _draw_align()
			"route": _draw_route()
			"rhythm": _draw_rhythm()
			"catch": _draw_fall(false)
			"dodge": _draw_fall(true)

	func _draw_align() -> void:
		var y := size.y * .55
		draw_line(Vector2(35, y), Vector2(size.x - 35, y), Color("66878b"), 8, true)
		var targets: Array = host._spec.get("targets", [])
		for i in targets.size():
			var x := lerpf(40.0, size.x - 40.0, float(targets[i]))
			var colour: Color = Color("6b735f") if i >= host._score else host._accent
			draw_arc(Vector2(x, y), 18, 0, TAU, 30, colour, 5, true)
		var marker_x := lerpf(40.0, size.x - 40.0, host._cursor.x)
		draw_line(Vector2(marker_x, y - 60), Vector2(marker_x, y + 60), host._accent, 6, true)
		draw_circle(Vector2(marker_x, y), 9, Color("fff4dc"))

	func _draw_route() -> void:
		var cell := minf(size.x, size.y) / 4.1
		var origin := (size - Vector2(cell * 3, cell * 3)) * .5
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
		var sequence: Array = host._spec.get("sequence", [])
		var names := {"left": "←", "right": "→", "up": "↑", "down": "↓"}
		var width := size.x / maxf(1.0, sequence.size())
		for i in sequence.size():
			var center := Vector2(width * (i + .5), size.y * .53)
			var colour: Color = host._accent if i < host._score else Color("66878b")
			if i == host._score: draw_circle(center, 43, host._accent.darkened(.45))
			draw_string(ThemeDB.fallback_font, center + Vector2(-16, 13), names[str(sequence[i])], HORIZONTAL_ALIGNMENT_LEFT, -1, 38, colour)

	func _draw_fall(dodging: bool) -> void:
		for item in host._falling:
			var pos := Vector2(float(item.x) * size.x, float(item.y) * size.y)
			var harmful := bool(item.bad)
			var colour: Color = Color("fa6f77") if harmful else host._accent
			if dodging:
				draw_line(pos - Vector2(34, 0), pos + Vector2(34, 0), colour, 8, true)
			else:
				draw_circle(pos, 11, colour)
				draw_arc(pos, 17, 0, TAU, 20, colour.lightened(.3), 2, true)
		var paddle := Vector2(host._cursor.x * size.x, size.y - 28)
		if dodging:
			draw_circle(paddle, 14, Color("fff4dc"))
			draw_arc(paddle, 20, 0, TAU, 24, host._accent, 4, true)
		else:
			draw_arc(paddle, 27, 0, PI, 24, host._accent, 8, true)
		if dodging and host._ready_to_strike:
			draw_string(ThemeDB.fallback_font, Vector2(size.x*.31, 45), "SHIELD OPEN • STRIKE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("fff4dc"))


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
var _board: ArcadeBoard
var _status: Label
var _progress: Label
var _panel: PanelContainer
var _player_physics := false
var _mouse_mode := Input.MOUSE_MODE_CAPTURED
var _rng := RandomNumberGenerator.new()
var _accent := Color("72e6c5")


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
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e9dfc6")
	style.border_color = _accent
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	_panel.add_child(body)
	var title := Label.new()
	title.text = str(_spec.title)
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("183c42"))
	body.add_child(title)
	var instruction := Label.new()
	instruction.text = str(_spec.instruction)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_font_size_override("font_size", 17)
	instruction.add_theme_color_override("font_color", Color("315b5c"))
	body.add_child(instruction)
	_board = ArcadeBoard.new()
	_board.host = self
	_board.custom_minimum_size = Vector2(590, 330)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_board)
	_progress = Label.new()
	_progress.add_theme_font_size_override("font_size", 18)
	_progress.add_theme_color_override("font_color", Color("183c42"))
	body.add_child(_progress)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 16)
	_status.add_theme_color_override("font_color", Color("704e35"))
	body.add_child(_status)
	var touch := HBoxContainer.new()
	touch.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(touch)
	_add_touch_button(touch, "◀", "left")
	_add_touch_button(touch, "▲", "up")
	_add_touch_button(touch, "ACTION" if _mode in ["align", "dodge"] else "RESET", "action")
	_add_touch_button(touch, "▼", "down")
	_add_touch_button(touch, "▶", "right")
	var close := Button.new()
	close.text = "Return to World One · Esc"
	close.custom_minimum_size.y = 42
	close.pressed.connect(queue_free)
	body.add_child(close)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_update_labels({
		"align": "Move with Left/Right or A/D. Press Space inside each ring.",
		"route": "Move through the grid with arrow keys or WASD. Space resets the route.",
		"rhythm": "Repeat the glowing arrow sequence. Space resets the rhythm.",
		"catch": "Move the receiver with Left/Right or A/D. Catch light; avoid static.",
		"dodge": "Move with Left/Right or A/D. Press Space when the shield opens.",
	}.get(_mode, "Use arrow keys or WASD."))


func _add_touch_button(row: HBoxContainer, caption: String, command: String) -> void:
	var button := Button.new()
	button.text = caption
	button.set_meta("minigame_command", command)
	button.custom_minimum_size = Vector2(82, 44)
	if command in ["left", "right"] and _mode in ["align", "catch", "dodge"]:
		button.button_down.connect(func(): _set_direction_held(command, true))
		button.button_up.connect(func(): _set_direction_held(command, false))
	else:
		button.pressed.connect(func(): _command(command))
	row.add_child(button)


func _layout() -> void:
	var viewport := Vector2(get_window().size)
	var stretch := get_viewport().get_stretch_transform().get_scale()
	if stretch.x > 0 and stretch.y > 0:
		scale = Vector2.ONE / stretch
	var width := minf(650, viewport.x - 24)
	var height := minf(610, viewport.y - 24)
	if _board != null:
		_board.custom_minimum_size = Vector2(width - 40, maxf(190, height - 270))
	_panel.position = (viewport - Vector2(width, height)) * .5
	_panel.size = Vector2(width, height)
	_panel.set_deferred("size", Vector2(width, height))


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
				_update_labels("Static touched the receiver. Re-centre and continue.")
		else:
			if touched:
				_mistakes += 1
				_score = maxi(0, _score - 1)
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
		if command == "close" and event.pressed:
			queue_free()
		elif command in ["left", "right"]:
			_set_direction_held(command, event.pressed)
			if event.pressed and _mode in ["route", "rhythm"]: _command(command)
		elif event.pressed and not command.is_empty():
			_command(command)
		get_viewport().set_input_as_handled()


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
		_score = 0
		_update_labels("That tone broke the pattern. Listen from the beginning.")


func _win() -> void:
	if _finished:
		return
	_finished = true
	_left_held = false
	_right_held = false
	_last_result = _apply_station_reward()
	_update_labels("Challenge complete • " + str(_last_result.get("reason", "practice_complete")).replace("_", " ").capitalize() + "\nPress Space to replay, or Esc to return.")
	if _board != null: _board.queue_redraw()


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
