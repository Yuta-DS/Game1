extends SceneTree

# Drives the Crown Line the way a player does.
#
# The previous suites only asked the railway about its route geometry, so a
# train whose cab was walled off by its own collision shell — and whose driver
# seat sat inside the engine block — still passed everything. This test starts
# from the player's position on the deck, boards through the same public calls
# the Q handler uses, and holds W and S to confirm the train actually moves.

func _fail(message: String) -> void:
	push_error("TRAIN_DRIVE_TEST: %s" % message)
	quit(1)


func _point_is_inside_solid(space: PhysicsDirectSpaceState3D, point: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not space.intersect_point(query, 8).is_empty()


func _press_train_mode(railway: Node3D, key: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	event.physical_keycode = key
	railway.call("_unhandled_input", event)


func _run() -> void:
	# Mirror art_gallery.gd: the railway lives under an offset floating world
	# while the player sits at the scene root, so every to_global() conversion
	# in the railway is exercised the same way it is in the real game.
	var gallery := Node3D.new()
	gallery.name = "ArtGallery"
	root.add_child(gallery)

	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	shape_node.shape = capsule
	player.add_child(shape_node)
	gallery.add_child(player)

	var floating_world := Node3D.new()
	floating_world.name = "ArtCastleFloatingWorld"
	floating_world.position = Vector3(0.0, 0.0, -480.0)
	gallery.add_child(floating_world)

	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	floating_world.add_child(railway)

	for _i in 10:
		await process_frame

	var space := player.get_world_3d().direct_space_state
	var train: Node3D = railway.get("_train")

	# 1. The cab and every seat must be air the player can stand in. A boarding
	#    point inside a collision box teleports the player into the geometry.
	var driver_point: Vector3 = railway.call("get_driver_interaction_position")
	var driver_seat: Vector3 = railway.call("get_driver_seat_position")
	if _point_is_inside_solid(space, driver_point):
		_fail("driver interaction point is buried inside the train collision shell")
		return
	if _point_is_inside_solid(space, driver_seat):
		_fail("driver seat is buried inside the train collision shell")
		return
	for seat_index in int(railway.call("get_passenger_seat_count")):
		var seat: Vector3 = railway.call("get_passenger_seat_position", seat_index)
		if _point_is_inside_solid(space, seat):
			_fail("passenger seat %d is buried inside the train collision shell" % seat_index)
			return

	# 2. Standing on the front of the deck offers driving; standing at the back
	#    offers a seat. This is the rule the player is told: near the cab you
	#    drive, near a seat you sit.
	var front_deck := train.to_global(Vector3(0.0, 2.4, -3.0))
	var rear_deck := train.to_global(Vector3(0.0, 2.4, 2.8))
	if String(railway.call("get_interaction_mode_for_position", front_deck)) != "drive":
		_fail("standing at the front of the deck does not offer the driver cab")
		return
	if String(railway.call("get_interaction_mode_for_position", rear_deck)) != "sit":
		_fail("standing by the benches does not offer a passenger seat")
		return

	# 3. Number 1 explicitly selects driver mode from the train deck.
	player.global_position = front_deck
	railway.call("_update_prompt")
	var controls := railway.get_node("CrownLineHUD/TrainControls") as Control
	if not controls.visible or controls.anchor_left != 1.0:
		_fail("boarding the deck must reveal controls on the right")
		return
	player.global_position = train.to_global(Vector3(0, 10, 2.8))
	railway.call("_update_prompt")
	if not controls.visible:
		_fail("controls disappeared while jumping over the train deck")
		return
	player.global_position = train.to_global(Vector3(100, 0, 0))
	railway.call("_update_prompt")
	if controls.visible:
		_fail("train controls remain visible away from the train")
		return
	player.global_position = front_deck
	_press_train_mode(railway, KEY_1)
	if not bool(railway.call("is_driving")):
		_fail("pressing 1 at the train did not take control of the train")
		return
	if not bool(player.call("is_train_seated_pose")):
		_fail("the driver character did not enter a seated driving pose")
		return
	var train_forward := -train.global_basis.z.normalized()
	var player_forward := -player.global_basis.z.normalized()
	if player_forward.dot(train_forward) < 0.99:
		_fail("the seated driver is not facing the front of the train")
		return
	# This suite drives through the public method with a fixed delta. Disable the
	# runtime Input poll so an empty test keyboard cannot apply a second, zero
	# throttle command in the same iteration and cancel the command under test.
	railway.set_process(false)
	var horn_count := int(railway.call("get_horn_request_count"))
	_press_train_mode(railway, KEY_R)
	if int(railway.call("get_horn_request_count")) != horn_count + 1:
		_fail("pressing R while driving did not sound the train horn")
		return

	# 4. Hold W: the train must accelerate and cover ground along the route.
	var start_position := train.global_position
	for _i in 120:
		railway.call("drive_manual", 1.0, 1.0 / 60.0)
		await process_frame
	var forward_travel := train.global_position.distance_to(start_position)
	if forward_travel < 5.0:
		_fail("holding W did not move the train (travelled %.2f m)" % forward_travel)
		return
	if float(railway.call("get_display_speed_kph")) <= 0.0:
		_fail("holding W did not build up any speed")
		return
	# The driver rides in the cab rather than being left behind on the platform.
	if player.global_position.distance_to(railway.call("get_driver_seat_position")) > 1.0:
		_fail("the driver did not stay in the cab while the train moved")
		return

	# 5. Hold S: the train must come back the other way along the same line.
	var reverse_start := train.global_position
	for _i in 240:
		railway.call("drive_manual", -1.0, 1.0 / 60.0)
		await process_frame
	var reversed_toward_origin := train.global_position.distance_to(start_position) \
		< reverse_start.distance_to(start_position)
	if not reversed_toward_origin:
		_fail("holding S did not drive the train back the way it came")
		return

	# 6. Brake to a dock, then Q leaves the cab and hands control back.
	var guard := 0
	while int(railway.call("get_drive_segment")) >= 0 and guard < 3000:
		railway.call("drive_manual", -1.0, 1.0 / 60.0)
		await process_frame
		guard += 1
	if int(railway.call("get_drive_segment")) >= 0:
		_fail("the train never reached a station to disembark at")
		return
	if not bool(railway.call("request_disembark")):
		_fail("Q at a dock did not release the driver")
		return
	if bool(railway.call("is_driving")):
		_fail("leaving the cab did not exit driver mode")
		return

	# 7. Number 2 explicitly selects passenger mode from the same train deck.
	player.global_position = train.to_global(Vector3(0.0, 2.4, 2.8))
	var nearest_seat := int(railway.call("get_nearest_passenger_seat_index",
		player.global_position))
	if nearest_seat < 0:
		_fail("no passenger seat is reachable from the bench deck")
		return
	_press_train_mode(railway, KEY_2)
	if not bool(railway.call("is_passenger_seated")):
		_fail("pressing 2 at the train did not register the player as a passenger")
		return
	railway.set("ride_duration", 0.05)
	await process_frame
	if player.global_position.distance_to(
			railway.call("get_passenger_seat_position", nearest_seat)) > 1.0:
		_fail("the seated passenger is not actually on the seat")
		return

	while bool(railway.get("_passenger_in_motion")):
		await process_frame
	for _stop in 4:
		var next_station := (int(railway.call("get_current_station")) + 1) % 4
		_press_train_mode(railway, KEY_2)
		while bool(railway.get("_passenger_in_motion")):
			await process_frame
		if int(railway.call("get_current_station")) != next_station:
			_fail("passenger cannot continue to every station with 2")
			return
	print("TRAIN_DRIVE_TEST: PASS — all stations, passenger continuation and right-side boarding controls")
	quit()


func _init() -> void:
	call_deferred("_run")
