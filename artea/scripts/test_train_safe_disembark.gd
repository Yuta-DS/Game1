extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("TRAIN_SAFE_DISEMBARK_TEST: " + message)
	quit(1)


func _settle(player: CharacterBody3D) -> bool:
	# A missed jump now falls STATION_RESCUE_DROP (16 m) before recovery, which
	# alone takes about 1.6 s. Settled players still return on landing.
	for frame in 300:
		await physics_frame
		if frame > 5 and player.is_on_floor():
			return true
	return false


func _run() -> void:
	var world := Node3D.new()
	world.position = Vector3(31, 7, -480)
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	shape.shape = capsule
	player.add_child(shape)
	world.add_child(player)
	var railway := Node3D.new()
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	await physics_frame
	railway.set("ride_duration", 0.05)
	for station in 4:
		player.global_position = railway.call("get_driver_interaction_position")
		if not railway.call("board_as_driver"):
			_fail("cannot board at station %d" % station)
			return
		if not railway.call("request_disembark") or not await _settle(player):
			_fail("driver falls after leaving station %d" % station)
			return
		var safe_position: Vector3 = railway.call("get_station_disembark_position", station)
		if player.global_position.distance_to(safe_position) > 2.0:
			_fail("driver did not land on the boarding walkway")
			return
		var station_nodes: Array = railway.get("_station_nodes")
		var platform := station_nodes[station].get_node("WalkablePlatform") as Node3D
		# A missed jump starts from rest. This test runs the train at
		# ride_duration 0.05, so any contact with it in the frames below would
		# hand the capsule the train's thousands of m/s on leaving and fling it
		# across the map, a timing-dependent flake unrelated to recovery.
		player.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
		for side in [-1.0, 1.0]:
			# Begin a missed jump beside either edge, then let actual player gravity
			# and station recovery run until the capsule lands on a real collider.
			player.global_position = platform.to_global(Vector3(0, 5, 0))
			player.velocity = Vector3.ZERO
			await physics_frame
			await physics_frame
			player.global_position = platform.to_global(Vector3(side * 17, 4, 25))
			player.velocity = Vector3(0, -5, 0)
			if not await _settle(player):
				_fail("missed jump falls forever at station %d" % station)
				return
			if platform.to_local(player.global_position).y < -1.5:
				_fail("missed jump was not recovered to the station")
				return
		player.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY
		player.global_position = railway.call("get_passenger_seat_position", 0)
		if not railway.call("sit_in_passenger_seat", 0):
			_fail("cannot board passenger seat")
			return
		await process_frame
		while railway.get("_passenger_in_motion"):
			await process_frame
		if not railway.call("leave_passenger_seat") or not await _settle(player):
			_fail("passenger falls after leaving station %d" % ((station + 1) % 4))
			return
	print("TRAIN_SAFE_DISEMBARK_TEST: PASS — driver/passenger exits and missed jumps at all four rotated stations")
	quit()
