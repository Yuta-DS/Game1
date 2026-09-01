extends SceneTree
## Real gallery, fox, camera and viewport events: board, travel, choose, repeat.

var checks := 0
var failures: Array[String] = []
var railway: Node3D
var player: CharacterBody3D
var camera: Camera3D
var ui: CanvasLayer

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("PASSENGER_JOURNEY: " + message)

func _frames(count := 4) -> void:
	for i in count:
		await process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)

func _motion(delta: Vector2, at := Vector2(30, 30)) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = delta
	root.push_input(event, true)

func _click(button_name: String) -> void:
	var button := ui.find_child(button_name, true, false) as Button
	var at := button.get_global_rect().get_center()
	_motion(Vector2.ZERO, at)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _arrival(expected: int, seat: int) -> void:
	var deadline := Time.get_ticks_msec() + 12000
	while not railway.call("is_passenger_waiting_at_station") and Time.get_ticks_msec() < deadline:
		await process_frame
	await _frames()
	_check(railway.call("is_passenger_waiting_at_station"), "Arrival waits for an explicit choice")
	_check(int(railway.get("_current_station")) == expected, "Arrived at station %d" % expected)
	_check(not railway.call("is_passenger_train_moving"), "Train is stopped for the choice")
	_check(player.global_position.distance_to(railway.call("get_passenger_seat_position", seat)) < .02,
		"Passenger stays attached to the selected cushion on arrival")
	_check(player.call("get_vehicle_pose") == "passenger" and not player.get("input_enabled"),
		"Passenger stays seated, without walking input")
	_check(ui.get_node("ArrivalChoice").visible, "Arrival choices are actually visible")
	_check(camera.get("_passenger_prompt_active"), "Arrival releases and locks camera input for UI")
	_check(not ui.get_node("JourneyStatus").visible, "Travel status hides at a stop")
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	var events := train.get_node("TrainEvents3D") as AudioStreamPlayer3D
	_check(events.get_meta("last_train_event", &"") == &"arrival",
		"Arrival chime plays from the train at every station")
	var exit_point: Vector3 = railway.call("get_passenger_disembark_position")
	var floor_query := PhysicsRayQueryParameters3D.create(exit_point, exit_point + Vector3.DOWN * 4)
	floor_query.exclude = [player.get_rid()]
	var floor_hit := player.get_world_3d().direct_space_state.intersect_ray(floor_query)
	_check(not floor_hit.is_empty(), "Station %d exit has a physical platform" % expected)
	if not floor_hit.is_empty():
		_check("RaisedBoardingBase" in str(floor_hit.collider.name), "Exit stands on the raised boarding platform")

func _board(seat: int) -> void:
	player.global_position = railway.call("get_passenger_seat_position", seat)
	_key(KEY_T)
	_check(railway.call("is_passenger_seated"), "T seats the actual player")
	_check(int(railway.get("_passenger_seat_index")) == seat, "T chooses the nearest bench in the correct coach")
	_check(player.call("get_vehicle_pose") == "passenger", "T applies the passenger pose")
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	var controls := train.get_node("TrainControls3D") as AudioStreamPlayer3D
	var events := train.get_node("TrainEvents3D") as AudioStreamPlayer3D
	_check(controls.get_meta("last_train_event", &"") == &"seat",
		"T plays the local seat-settle sound")
	_check(events.get_meta("last_train_event", &"") == &"door",
		"Automatic departure closes the train door")

func _run() -> void:
	root.size = Vector2i(1100, 720)
	Engine.max_fps = 60
	var journey := root.get_node("JourneyState")
	var original_flags: Dictionary = journey.get("treasures").duplicate(true)
	journey.set("treasures", {"star_of_wisdom": true, "harmony_jewel": true, "creators_light": true})
	var gallery := load("res://scenes/art_gallery_3d_inprogress.tscn").instantiate() as Node3D
	camera = gallery.get_node("Camera3D")
	camera.set("capture_mouse", false)
	root.add_child(gallery)
	await _frames(6)
	player = gallery.get_node("Player3D")
	railway = gallery.get_node("ArtCastleFloatingWorld/StoryCrownRailway")
	railway.set("ride_duration", .6)
	ui = railway.get_node("PassengerJourneyUI")
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	_check(not ui.get_node("ArrivalChoice").visible and not ui.get_node("JourneyStatus").visible,
		"Passenger UI is hidden before boarding")
	_check(not railway.call("continue_passenger_journey"), "Cannot start travel while not seated")
	camera.set("_yaw", train.global_rotation.y + PI * .4)
	_board(1)
	camera.set("capture_mouse", true)
	camera.call("_resume_mouse_look")
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Native travel captures the mouse before the station releases it")
	_check(railway.call("is_passenger_train_moving"), "Boarding starts automatic travel immediately")
	_check(ui.get_node("JourneyStatus").visible, "Automatic travel shows the next stop")
	_check(not railway.call("leave_passenger_seat"), "Public exit refuses to drop a moving passenger")
	_check(not railway.call("continue_passenger_journey"), "Duplicate departures are rejected")
	_key(KEY_R)
	_key(KEY_Q)
	_key(KEY_T)
	_check(not railway.call("is_driving") and railway.call("is_passenger_seated"), "R/Q/T cannot interrupt transit")
	_key(KEY_3)
	_check(camera.call("get_view_mode") == "first", "Passenger can use first person in transit")
	_key(KEY_4)
	await _frames(5)
	_check(player.global_position.distance_to(railway.call("get_passenger_seat_position", 1)) < .02,
		"Moving passenger stays on the cushion without lag")
	_check(player.call("get_animation_state") == "passenger", "Actual fox animation is seated")
	await _arrival(1, 1)
	var stopped := train.global_transform
	await create_timer(.8).timeout
	_check(train.global_transform.is_equal_approx(stopped), "Train never auto-departs while a decision is pending")
	var yaw: float = camera.get("_yaw")
	var distance: float = camera.get("follow_distance")
	_motion(Vector2(100, -20))
	for code in [KEY_3, KEY_4, KEY_R, KEY_T, KEY_Q, KEY_ESCAPE]:
		_key(code)
	_check(is_equal_approx(yaw, camera.get("_yaw")), "Choosing a station cannot spin the camera")
	_check(camera.call("get_view_mode") == "third", "View keys are blocked behind arrival UI")
	_check(railway.call("is_passenger_waiting_at_station"), "Other keys do not dismiss or bypass the choice")
	_check(is_equal_approx(distance, camera.get("follow_distance")), "Prompt preserves camera framing")
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Native cursor is available for station buttons")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://artifacts/train_passenger_arrival.png") == OK,
			"Saved actual gallery arrival screenshot")
	root.size = Vector2i(360, 640)
	await _frames()
	var panel := ui.get("_panel") as Control
	_check(root.get_visible_rect().encloses(panel.get_global_rect()), "Arrival card fits a narrow viewport")
	root.size = Vector2i(1100, 720)
	await _frames()
	_click("NextStation")
	_check(railway.call("is_passenger_train_moving"), "Clicking Next station starts exactly one new leg")
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Continuing recaptures the native mouse")
	_check(not railway.call("continue_passenger_journey"), "Second continue cannot start another tween")
	yaw = camera.get("_yaw")
	_motion(Vector2(30, 0))
	_check(absf(angle_difference(yaw, camera.get("_yaw")) + .15) < .001, "Mouse look resumes on continuation")
	await _arrival(2, 1)
	var platform_exit: Vector3 = railway.call("get_passenger_disembark_position")
	_click("GetOffHere")
	_check(not railway.call("is_passenger_seated"), "Get off here exits passenger mode")
	_check((train.get_node("TrainEvents3D") as AudioStreamPlayer3D).get_meta(
		"last_train_event", &"") == &"door", "Getting off plays the train door sound")
	_check(player.get("input_enabled") and player.call("get_vehicle_pose") == "", "Exit restores walking and standing")
	_check(not camera.call("is_ride_view_active") and not camera.get("_passenger_prompt_active"), "Exit restores normal camera controls")
	_check(not ui.get_node("ArrivalChoice").visible, "Exit closes the choice")
	_check(player.global_position.distance_to(platform_exit) < .01, "Exit places the player on the destination platform, not in the train")
	var ray := PhysicsRayQueryParameters3D.create(platform_exit + Vector3.UP, platform_exit + Vector3.DOWN * 5)
	ray.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	_check(not hit.is_empty(), "Destination exit has solid floor below it")
	for i in 45:
		await physics_frame
	_check(player.is_on_floor(), "Exited player settles on a walkable floor")
	_check(not railway.call("continue_passenger_journey"), "Stale choice cannot move train after exit")
	# Rear coach, then wrap Creator -> Gallery and stop again without changing seats.
	_board(4)
	await _arrival(3, 4)
	_key(KEY_TAB)
	_check((ui.find_child("NextStation", true, false) as Button).has_focus(), "Tab reaches the continue button")
	_key(KEY_ENTER)
	_check(railway.call("is_passenger_train_moving"), "Enter activates a focused station choice")
	await _arrival(0, 4)
	_click("GetOffHere")
	# Locks are not bypassed by autopilot, even when boarding at the locked leg.
	journey.set("treasures", {})
	_board(1)
	await _arrival(1, 1)
	var next_button := ui.find_child("NextStation", true, false) as Button
	_check(next_button.disabled, "Locked next station disables continue")
	_check("Star of Wisdom" in (ui.get("_next") as Label).text, "Lock explains how to unlock the destination")
	_click("NextStation")
	_check(not railway.call("continue_passenger_journey"), "Locked route rejects both UI and API departure")
	_click("GetOffHere")
	camera.call("_release_mouse_look")
	_board(4)
	_check(railway.call("is_passenger_waiting_at_station") and not railway.call("is_passenger_train_moving"),
		"Boarding at a blocked stop offers an exit immediately")
	_click("GetOffHere")
	_check(camera.get("_mouse_look_released"), "Closing a prompt preserves a deliberately released cursor")
	# On-foot R still enters manual mode, and does not summon passenger UI.
	player.global_position = railway.call("get_driver_interaction_position")
	_key(KEY_R)
	_check(railway.call("is_driving"), "R still boards the driver independently")
	_check(not ui.get_node("ArrivalChoice").visible, "Manual mode has no passenger choice")
	_check(railway.call("request_disembark"), "Manual station exit still works")
	journey.set("treasures", original_flags)
	# Removing the train while a passenger is waiting restores player/camera.
	journey.set("treasures", {})
	_board(1)
	_check(railway.call("is_passenger_waiting_at_station"), "Cleanup scenario has a live modal")
	railway.queue_free()
	await _frames()
	_check(player.get("input_enabled") and player.call("get_vehicle_pose") == "", "Railway removal releases the player")
	_check(not camera.get("_passenger_prompt_active"), "Railway removal releases modal camera lock")
	journey.set("treasures", original_flags)
	print("PASSENGER_JOURNEY: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gallery.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
