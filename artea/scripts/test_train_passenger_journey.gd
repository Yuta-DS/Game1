extends SceneTree
## Exercises the current passenger flow in the real gallery scene.

var _journey: Node
var _original_treasures: Dictionary


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("PASSENGER_JOURNEY: " + message)
	if _journey != null:
		_journey.set("treasures", _original_treasures)
	quit(1)


func _press_mode(railway: Node3D, key: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	event.physical_keycode = key
	railway.call("_unhandled_input", event)


func _wait_for_stop(railway: Node3D) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while bool(railway.call("is_passenger_train_moving")) \
			and Time.get_ticks_msec() < deadline:
		await process_frame
	return not bool(railway.call("is_passenger_train_moving"))


func _run() -> void:
	_journey = root.get_node("JourneyState")
	_original_treasures = (_journey.get("treasures") as Dictionary).duplicate(true)
	_journey.set("treasures", {})
	var gallery := load("res://scenes/art_gallery_3d_inprogress.tscn").instantiate() as Node3D
	root.add_child(gallery)
	for _frame in 8:
		await process_frame
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	var railway := gallery.get_node_or_null("ArtCastleFloatingWorld/StoryCrownRailway") as Node3D
	if player == null or railway == null:
		_fail("real gallery passenger route is missing")
		return
	if railway.get_node_or_null("PassengerJourneyUI") != null:
		_fail("obsolete passenger choice UI returned")
		return
	railway.set("ride_duration", 0.08)
	var seat := 1
	player.global_position = railway.call("get_passenger_seat_position", seat)
	_press_mode(railway, KEY_2)
	if not bool(railway.call("is_passenger_seated")):
		_fail("2 did not seat the player in the real gallery")
		return
	for _frame in 3:
		await process_frame
	if not await _wait_for_stop(railway) or int(railway.call("get_current_station")) != 1:
		_fail("passenger did not reach the first station")
		return
	if player.global_position.distance_to(railway.call("get_passenger_seat_position", seat)) > 0.1:
		_fail("player did not stay on the train seat")
		return
	_press_mode(railway, KEY_2)
	await process_frame
	if int(railway.call("get_current_station")) != 1 \
			or bool(railway.call("is_passenger_train_moving")):
		_fail("passenger bypassed the locked Heart station")
		return
	_journey.set("treasures", {"star_of_wisdom": true})
	_press_mode(railway, KEY_2)
	await process_frame
	if not await _wait_for_stop(railway) or int(railway.call("get_current_station")) != 2:
		_fail("2 did not continue to the newly unlocked Heart station")
		return
	if not bool(railway.call("leave_passenger_seat")) \
			or bool(railway.call("is_passenger_seated")) \
			or not bool(player.get("input_enabled")):
		_fail("exiting at a station did not restore walking")
		return
	_journey.set("treasures", _original_treasures)
	print("PASSENGER_JOURNEY: PASS — real gallery boarding, locked stop, continuation, and exit")
	quit(0)
