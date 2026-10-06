extends SceneTree

# Manual driving must be able to leave every station on the Crown Line.
#
# _advance_manual_drive() detected arrival with is_equal_approx() against 0.0
# and 1.0. Godot's is_equal_approx uses an absolute floor of CMP_EPSILON (1e-5)
# when comparing against zero, and the first frames out of a station move the
# curve parameter by far less than that -- the train is accelerating from rest
# and the segment curves are hundreds of metres long, so the first non-zero
# progress was ~5e-6.
#
# That reads as "already at progress 0", so the train docked back at the station
# it was trying to leave, zeroed its speed, and did it again the next frame.
# Held W, stuck at the platform forever. Auto-drive was unaffected because it
# does not go through this function.
#
# Whether a given station trapped the train depended on the length of the curve
# it was leaving, which is why it stalled at some stations and not others.

const TARGET := "res://scenes/art_gallery_3d_inprogress.tscn"
## Sim seconds allowed per station hop before calling it stuck.
const HOP_TIMEOUT_FRAMES := 1800


func _initialize() -> void:
	Engine.max_fps = 60
	var scene := (load(TARGET) as PackedScene).instantiate()
	root.add_child(scene)
	for _i in 40:
		await process_frame

	var railway := scene.find_child("StoryCrownRailway", true, false) as Node3D
	if railway == null:
		_fail("no StoryCrownRailway")
		return
	var player := scene.get_node_or_null("Player3D") as Node3D
	if player == null:
		_fail("no Player3D")
		return

	player.global_position = railway.call("get_driver_interaction_position")
	for _i in 4:
		await process_frame
	_key(KEY_1, true)
	await process_frame
	_key(KEY_1, false)
	for _i in 4:
		await process_frame
	if not bool(railway.get("_manual_driving")):
		_fail("pressing 1 at the driver's door did not enter driver mode")
		return

	var station_count := int(railway.call("get_station_count"))
	var visited: Array[int] = [int(railway.get("_current_station"))]

	# Hold W, exactly as a player does, and require a new station each hop.
	_key(KEY_W, true)
	for _hop in station_count:
		var from: int = railway.get("_current_station")
		var arrived := false
		for _frame in HOP_TIMEOUT_FRAMES:
			await process_frame
			if int(railway.get("_current_station")) != from:
				arrived = true
				break
		if not arrived:
			_key(KEY_W, false)
			_fail("held W at station %d for %d frames and the train never left it (progress=%.7f, speed=%.2f)"
				% [from, HOP_TIMEOUT_FRAMES, railway.call("get_drive_progress"),
					railway.get("_display_speed_kph")])
			return
		visited.append(int(railway.get("_current_station")))
	_key(KEY_W, false)

	var distinct: Array[int] = []
	for station in visited:
		if not distinct.has(station):
			distinct.append(station)
	if distinct.size() < station_count:
		_fail("manual driving only reached %d of %d stations: %s"
			% [distinct.size(), station_count, str(visited)])
		return

	print("TRAIN_MANUAL_DEPARTURE: PASS — held W drove the full %d-station loop (%s)"
		% [station_count, str(visited)])
	quit()


func _fail(message: String) -> void:
	push_error("TRAIN_MANUAL_DEPARTURE: %s" % message)
	quit(1)


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
