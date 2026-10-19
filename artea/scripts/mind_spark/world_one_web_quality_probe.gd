extends Node

## Opt-in production gameplay verifier. Enable with `?world_one_quality=1`.
##
## The probe drives every quest mini-game through the same keyboard and touch
## handlers used by players, verifies a partial and full save round-trip, then
## restores the live objects and identity tracker. No real player progress is
## kept or overwritten.

const Catalog := preload("res://scripts/mind_spark/world_one_object_minigame_catalog.gd")
const PanelScript := preload("res://scripts/mind_spark/world_one_object_minigame_panel.gd")
const StateStore := preload("res://scripts/mind_spark/quest_objects/quest_object_state_store.gd")

const EXPECTED_IDS := [
	"world_one.checkpoint.landing", "world_one.path_projector",
	"world_one.spark_socket", "world_one.checkpoint.network", "world_one.focus_bell",
	"world_one.evidence_scanner", "world_one.memory_board", "world_one.logic_gate",
	"world_one.perspective_lens", "world_one.truth_bridge",
	"world_one.warden_anchor.1", "world_one.warden_anchor.2", "world_one.warden_anchor.3",
	"world_one.calm_rain_basin", "world_one.identity_reflection",
]
const PARTIAL_OBJECT_COUNT := 7

var _world: MindSparkWorldOne
var _object_store_path := ""
var _identity_store_path := ""
var _object_snapshots: Array[Dictionary] = []
var _identity_snapshot: Dictionary = {}
var _identity_tracker: Node


func configure(world: MindSparkWorldOne) -> void:
	_world = world
	call_deferred("_begin")


func _begin() -> void:
	if _world == null or not is_instance_valid(_world):
		queue_free()
		return
	var nonce := "%d_%d" % [Time.get_ticks_msec(), randi()]
	_object_store_path = "user://world_one_web_quality_objects_%s.json" % nonce
	_identity_store_path = "user://world_one_web_quality_identity_%s.json" % nonce
	var store := StateStore.new(_object_store_path)
	store.clear()
	_snapshot_identity_tracker()
	var ordered_objects := _prepare_objects(store)
	var report := {
		"expected_objects": EXPECTED_IDS.size(),
		"fresh_completed": _count_completed(ordered_objects),
		"fresh_saved": _count_saved(store, EXPECTED_IDS),
		"partial_target": PARTIAL_OBJECT_COUNT,
		"partial_saved": 0,
		"accepted_rewards": 0,
		"saved_objects": 0,
		"durable_completed": 0,
		"modes": 0,
		"touch_modes": 0,
		"controller_modes": 0,
		"controller_close": false,
		"state_restored": false,
		"identity_restored": false,
		"errors": [],
	}
	if ordered_objects.size() != EXPECTED_IDS.size():
		(report.errors as Array).append("expected 15 live quest objects, found %d" % ordered_objects.size())
	var actor := Node3D.new()
	actor.name = "WorldOneWebQualityActor"
	_world.add_child(actor)
	var modes := {}
	var touch_modes := {}
	var controller_modes := {}
	var controller_close_mapped := false
	var accepted_ids: Array[String] = []
	for index in ordered_objects.size():
		var object := ordered_objects[index] as QuestObjectBase
		var panel := PanelScript.new()
		panel.name = "WorldOneWebQualityPanel"
		_world.add_child(panel)
		panel.open_object(object, actor)
		# Keep the panel on the real station reward path while isolating the story
		# controller. Quest and identity writes go only to temporary stores.
		panel.set("world", null)
		var mode := str(panel.call("challenge_mode"))
		modes[mode] = true
		if not touch_modes.has(mode):
			if _exercise_touch_controls(panel):
				touch_modes[mode] = true
			else:
				(report.errors as Array).append("%s touch controls failed" % mode)
		if not controller_modes.has(mode):
			if _exercise_controller_controls(panel):
				controller_modes[mode] = true
			else:
				(report.errors as Array).append("%s controller controls failed" % mode)
		controller_close_mapped = controller_close_mapped or \
			str(panel.call("_joypad_button_command", JOY_BUTTON_B)) == "close"
		panel.call("_reset_round")
		var completion := await _complete_through_player_input(panel)
		var result: Dictionary = completion.get("result", {})
		if bool(completion.get("finished", false)) and bool(result.get("accepted", false)):
			accepted_ids.append(object.save_id)
		else:
			(report.errors as Array).append("%s did not complete through player input" % object.save_id)
		panel.free()
		if index + 1 == PARTIAL_OBJECT_COUNT:
			report.partial_saved = _count_saved(store, EXPECTED_IDS)
	report.accepted_rewards = accepted_ids.size()
	report.saved_objects = _count_saved(store, EXPECTED_IDS)
	report.durable_completed = _count_completed(ordered_objects)
	report.modes = modes.size()
	report.touch_modes = touch_modes.size()
	report.controller_modes = controller_modes.size()
	report.controller_close = controller_close_mapped
	for object in ordered_objects:
		var loaded := store.load_object(object.save_id)
		if not _states_equal(loaded, object.current_state):
			(report.errors as Array).append("%s save round-trip mismatch" % object.save_id)
	actor.free()
	_restore_objects()
	report.state_restored = _objects_match_snapshots()
	report.identity_restored = _restore_identity_tracker()
	store.clear()
	if not _identity_store_path.is_empty() and FileAccess.file_exists(_identity_store_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_identity_store_path))
	report.ok = (report.errors as Array).is_empty() \
		and int(report.fresh_completed) == 0 \
		and int(report.fresh_saved) == 0 \
		and int(report.partial_saved) == PARTIAL_OBJECT_COUNT \
		and int(report.accepted_rewards) == EXPECTED_IDS.size() \
		and int(report.saved_objects) == EXPECTED_IDS.size() \
		and int(report.durable_completed) == 10 \
		and int(report.modes) == 5 and int(report.touch_modes) == 5 \
		and int(report.controller_modes) == 5 and bool(report.controller_close) \
		and bool(report.state_restored) and bool(report.identity_restored)
	_world.set_meta("web_quality_results", report.duplicate(true))
	_world.set_meta("web_quality_probe_completed", true)
	if OS.has_feature("web"):
		# Keep the result on the page as well as in the console. Browser tooling
		# can reconnect after the heavy World One build and still read the exact
		# result without repeating the 445 MB production download.
		JavaScriptBridge.eval(
			"window.__ARTEA_WORLD_ONE_QUALITY__ = %s;" % JSON.stringify(report), true)
	print("WORLD_ONE_WEB_QUALITY: %s" % JSON.stringify(report))
	queue_free()


func _prepare_objects(store: RefCounted) -> Array[QuestObjectBase]:
	var by_id := {}
	for object in _world.get_quest_objects():
		by_id[object.save_id] = object
	var ordered: Array[QuestObjectBase] = []
	for save_id in EXPECTED_IDS:
		var object := by_id.get(save_id) as QuestObjectBase
		if object == null:
			continue
		_object_snapshots.append({
			"object": object,
			"state": object.current_state.duplicate(true),
			"interaction_enabled": object.interaction_enabled,
			"persist_state": object.persist_state,
			"state_store_path": object.state_store_path,
			"state_store": object.state_store,
			"completion_emitted": object.get("_completion_emitted"),
			"signals_blocked": object.is_blocking_signals(),
			"had_available_sparks": object.has_meta("available_sparks"),
			"available_sparks": object.get_meta("available_sparks", 0),
		})
		object.set_block_signals(true)
		object.interaction_enabled = true
		object.persist_state = true
		object.state_store_path = _object_store_path
		object.state_store = store
		object.current_state = object.call("_default_state")
		object.set("_completion_emitted", false)
		object.set_meta("available_sparks", object.definition.validated_total())
		object.call("_apply_visual_state", false)
		ordered.append(object)
	return ordered


func _restore_objects() -> void:
	for snapshot in _object_snapshots:
		var object := snapshot.object as QuestObjectBase
		if object == null or not is_instance_valid(object):
			continue
		object.current_state = (snapshot.state as Dictionary).duplicate(true)
		object.interaction_enabled = bool(snapshot.interaction_enabled)
		object.persist_state = bool(snapshot.persist_state)
		object.state_store_path = str(snapshot.state_store_path)
		object.state_store = snapshot.state_store
		object.set("_completion_emitted", bool(snapshot.completion_emitted))
		if bool(snapshot.had_available_sparks):
			object.set_meta("available_sparks", snapshot.available_sparks)
		else:
			object.remove_meta("available_sparks")
		object.call("_apply_visual_state", false)
		object.set_block_signals(bool(snapshot.signals_blocked))


func _objects_match_snapshots() -> bool:
	for snapshot in _object_snapshots:
		var object := snapshot.object as QuestObjectBase
		if object == null or not is_instance_valid(object):
			return false
		if not _states_equal(object.current_state, snapshot.state):
			return false
		if object.interaction_enabled != bool(snapshot.interaction_enabled) \
				or object.persist_state != bool(snapshot.persist_state) \
				or object.state_store_path != str(snapshot.state_store_path) \
				or object.state_store != snapshot.state_store \
				or bool(object.get("_completion_emitted")) != bool(snapshot.completion_emitted) \
				or object.is_blocking_signals() != bool(snapshot.signals_blocked):
			return false
		if bool(snapshot.had_available_sparks):
			if not object.has_meta("available_sparks") \
					or object.get_meta("available_sparks") != snapshot.available_sparks:
				return false
		elif object.has_meta("available_sparks"):
			return false
	return true


func _snapshot_identity_tracker() -> void:
	_identity_tracker = get_node_or_null("/root/PlayerIdentityTracker")
	if _identity_tracker == null:
		return
	_identity_snapshot = {
		"save_path": str(_identity_tracker.get("save_path")),
		"evidence": (_identity_tracker.get("evidence") as Dictionary).duplicate(true),
		"counts": (_identity_tracker.get("identity_axis_counts") as Dictionary).duplicate(true),
		"ids": PackedStringArray(_identity_tracker.get("identity_evidence_ids")),
		"history": (_identity_tracker.get("identity_answer_history") as Array).duplicate(true),
		"result_code": str(_identity_tracker.get("identity_result_code")),
		"locked": bool(_identity_tracker.get("identity_locked")),
		"reveal_seen": bool(_identity_tracker.get("identity_reveal_seen")),
		"signals_blocked": _identity_tracker.is_blocking_signals(),
	}
	_identity_tracker.set_block_signals(true)
	_identity_tracker.set("save_path", _identity_store_path)
	_identity_tracker.call("clear_evidence")


func _restore_identity_tracker() -> bool:
	if _identity_tracker == null or _identity_snapshot.is_empty():
		return false
	_identity_tracker.set("save_path", _identity_snapshot.save_path)
	_identity_tracker.set("evidence", (_identity_snapshot.evidence as Dictionary).duplicate(true))
	_identity_tracker.set("identity_axis_counts", (_identity_snapshot.counts as Dictionary).duplicate(true))
	_identity_tracker.set("identity_evidence_ids", PackedStringArray(_identity_snapshot.ids))
	var restored_history: Array[Dictionary] = []
	for item in _identity_snapshot.history:
		restored_history.append((item as Dictionary).duplicate(true))
	_identity_tracker.set("identity_answer_history", restored_history)
	_identity_tracker.set("identity_result_code", _identity_snapshot.result_code)
	_identity_tracker.set("identity_locked", _identity_snapshot.locked)
	_identity_tracker.set("identity_reveal_seen", _identity_snapshot.reveal_seen)
	_identity_tracker.set_block_signals(bool(_identity_snapshot.signals_blocked))
	return _states_equal(_identity_tracker.get("evidence"), _identity_snapshot.evidence) \
		and _states_equal(_identity_tracker.get("identity_axis_counts"), _identity_snapshot.counts) \
		and PackedStringArray(_identity_tracker.get("identity_evidence_ids")) == PackedStringArray(_identity_snapshot.ids) \
		and JSON.parse_string(JSON.stringify(_identity_tracker.get("identity_answer_history"))) \
			== JSON.parse_string(JSON.stringify(_identity_snapshot.history)) \
		and str(_identity_tracker.get("identity_result_code")) == str(_identity_snapshot.result_code) \
		and bool(_identity_tracker.get("identity_locked")) == bool(_identity_snapshot.locked) \
		and bool(_identity_tracker.get("identity_reveal_seen")) == bool(_identity_snapshot.reveal_seen) \
		and str(_identity_tracker.get("save_path")) == str(_identity_snapshot.save_path) \
		and _identity_tracker.is_blocking_signals() == bool(_identity_snapshot.signals_blocked)


func _count_saved(store: RefCounted, ids: Array) -> int:
	var total := 0
	for save_id in ids:
		if not store.call("load_object", save_id).is_empty():
			total += 1
	return total


func _count_completed(objects: Array) -> int:
	var total := 0
	for object in objects:
		if bool(object.current_state.get("completed", false)):
			total += 1
	return total


func _states_equal(first: Dictionary, second: Dictionary) -> bool:
	# JSON object key order is not stable after a storage round-trip. Parse both
	# serializations back to values so equality compares fields and values.
	return JSON.parse_string(JSON.stringify(first)) == JSON.parse_string(JSON.stringify(second))


func _complete_through_player_input(panel: CanvasLayer) -> Dictionary:
	match panel.call("challenge_mode"):
		"align":
			for target in panel.get("_spec").get("targets", []):
				_steer_cursor(panel, float(target), float(panel.get("_spec").get("speed", .65)))
				_send_key(panel, KEY_SPACE)
		"route":
			var route: Array = panel.get("_spec").get("route", [])
			var hazards: Array = panel.get("_spec").get("hazards", [])
			var guard := 0
			while int(panel.get("_score")) < int(panel.get("_spec").goal) and guard < 100:
				guard += 1
				var target: Vector2i = route[int(panel.get("_score"))]
				for command in _grid_path(panel.get("_grid"), target, hazards):
					_send_command_key(panel, command)
		"rhythm":
			for command in panel.get("_spec").get("sequence", []):
				_send_command_key(panel, str(command))
		"catch", "dodge":
			_drive_falling_game(panel)
	return {"finished": bool(panel.get("_finished")), "result": panel.call("completion_result")}


func _drive_falling_game(panel: CanvasLayer) -> void:
	var guard := 0
	while not bool(panel.get("_finished")) and guard < 2400:
		guard += 1
		var desired := .5
		var falling: Array = panel.get("_falling")
		if not falling.is_empty():
			var nearest: Dictionary = falling[0]
			for item in falling:
				if float(item.y) > float(nearest.y):
					nearest = item
			if panel.call("challenge_mode") == "catch" and not bool(nearest.bad):
				desired = float(nearest.x)
			else:
				desired = .05 if float(nearest.x) > .5 else .95
		_set_keyboard_direction(panel, desired)
		panel.call("_process", .05)
		if panel.call("challenge_mode") == "dodge" and bool(panel.get("_ready_to_strike")):
			_send_key(panel, KEY_SPACE)
	_set_keyboard_direction(panel, float((panel.get("_cursor") as Vector2).x))


func _steer_cursor(panel: CanvasLayer, target: float, speed: float) -> void:
	var current := float((panel.get("_cursor") as Vector2).x)
	if absf(target - current) <= .002:
		return
	var command := "right" if target > current else "left"
	_send_direction(panel, command, true)
	panel.call("_process", absf(target - current) / speed)
	_send_direction(panel, command, false)


func _set_keyboard_direction(panel: CanvasLayer, target: float) -> void:
	var current := float((panel.get("_cursor") as Vector2).x)
	_send_direction(panel, "left", target < current - .018)
	_send_direction(panel, "right", target > current + .018)


func _send_command_key(panel: CanvasLayer, command: String) -> void:
	var keys := {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN}
	if keys.has(command):
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
	panel.call("_unhandled_input", event)


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


func _exercise_touch_controls(panel: CanvasLayer) -> bool:
	var buttons := {}
	for candidate in panel.find_children("*", "Button", true, false):
		var button := candidate as Button
		if button.has_meta("minigame_command"):
			buttons[str(button.get_meta("minigame_command"))] = button
	if not buttons.has("left") or not buttons.has("right") or not buttons.has("action"):
		return false
	match panel.call("challenge_mode"):
		"align", "catch", "dodge":
			var before := float((panel.get("_cursor") as Vector2).x)
			(buttons.left as Button).button_down.emit()
			panel.call("_process", .12)
			(buttons.left as Button).button_up.emit()
			return float((panel.get("_cursor") as Vector2).x) < before
		"route", "rhythm":
			(buttons.left as Button).pressed.emit()
			(buttons.action as Button).pressed.emit()
			return int(panel.get("_score")) <= 1
	return false


func _exercise_controller_controls(panel: CanvasLayer) -> bool:
	match panel.call("challenge_mode"):
		"align":
			var before := float((panel.get("_cursor") as Vector2).x)
			_send_joy_axis(panel, JOY_AXIS_LEFT_X, -1.0)
			panel.call("_process", .12)
			_send_joy_axis(panel, JOY_AXIS_LEFT_X, 0.0)
			var moved := float((panel.get("_cursor") as Vector2).x) < before
			var targets: Array = panel.get("_spec").get("targets", [])
			if targets.is_empty():
				return false
			panel.set("_cursor", Vector2(float(targets[0]), .5))
			_send_joy_button(panel, "action")
			return moved and int(panel.get("_score")) == 1
		"catch", "dodge":
			var before := float((panel.get("_cursor") as Vector2).x)
			_send_joy_axis(panel, JOY_AXIS_LEFT_X, -1.0)
			panel.call("_process", .12)
			_send_joy_axis(panel, JOY_AXIS_LEFT_X, 0.0)
			return float((panel.get("_cursor") as Vector2).x) < before
		"route":
			var route: Array = panel.get("_spec").get("route", [])
			var hazards: Array = panel.get("_spec").get("hazards", [])
			if route.is_empty() or int(panel.get("_score")) >= route.size():
				return false
			var path := _grid_path(panel.get("_grid"), route[int(panel.get("_score"))], hazards)
			if path.is_empty():
				return false
			var before: Vector2i = panel.get("_grid")
			_send_joy_button(panel, path[0])
			return (panel.get("_grid") as Vector2i) != before
		"rhythm":
			var sequence: Array = panel.get("_spec").get("sequence", [])
			if sequence.is_empty():
				return false
			_send_joy_button(panel, str(sequence[0]))
			return int(panel.get("_score")) == 1
	return false


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
