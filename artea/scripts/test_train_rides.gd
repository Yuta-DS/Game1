# Exercises the train system directly: builds the rails, islands and rider on a
# bare root (no hub scene), then drives a full ride out and back.
#
# This is the test the ride bugs needed — the previous suite only ever counted
# stations, so a passenger that lagged behind the carriage, or was set down
# through a bobbing island's deck, still passed.
extends SceneTree

func _transit_xform() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * 0.5), Vector3(0.0, -33.0, 1.3))


func _fail(message: String) -> void:
	push_error("TRAIN_RIDE_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var isles := Node3D.new()
	isles.name = "GalaxyIsles"
	isles.transform = _transit_xform()
	isles.set_script(load("res://scripts/hub_sky_isles.gd"))
	world.add_child(isles)

	var rail := Node3D.new()
	rail.name = "SkyRail"
	rail.transform = _transit_xform()
	rail.set_script(load("res://scripts/hub_skyrail.gd"))
	world.add_child(rail)

	# A stand-in for the player. The rider only needs a CharacterBody3D it can
	# suspend and reposition.
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.add_to_group("player")
	world.add_child(player)

	var rider := Node3D.new()
	rider.name = "TrainRider"
	rider.set_script(load("res://scripts/hub_train_rider.gd"))
	world.add_child(rider)

	for _i in 60:
		await process_frame

	# 1. Two-way boarding: three lines, out and back.
	var stations: Dictionary = rider.get("_stations")
	if stations.size() != 6:
		_fail("expected 6 stations (3 lines x 2 directions), got %d" % stations.size())
		return

	# 2. Every station has a visible pad the player can walk to.
	for station_id in stations:
		var markers: Dictionary = rider.get("_station_markers")
		if not markers.has(station_id):
			_fail("station %s has no boarding pad" % station_id)
			return

	# 3. Island pads track their island. The islands bob, so a pad frozen at its
	#    build position drifts away from the deck it is supposed to sit on.
	var back_key := "mindspark:back"
	var markers: Dictionary = rider.get("_station_markers")
	var pad := markers[back_key] as Node3D
	var before := pad.global_position
	for _i in 40:
		await process_frame
	var after := pad.global_position
	if before.is_equal_approx(after):
		_fail("island boarding pad is frozen; it should follow the bobbing island")
		return

	# 4. A full ride out: the player must end up on the destination island, not
	#    at the origin and not at the world origin.
	var start_pos := player.global_position
	rider.call("board", "mindspark", true)
	for _i in 20:
		await process_frame
	if not bool(rider.get("_riding")):
		_fail("boarding did not start a ride")
		return
	# Mid-ride the passenger must be somewhere on the rail, not left behind.
	if player.global_position.distance_to(start_pos) < 1.0:
		_fail("player did not move once the ride started")
		return

	# Let the ride finish (RIDE_SECONDS is 10).
	var guard := 0
	while bool(rider.get("_riding")) and guard < 2000:
		await process_frame
		guard += 1
	if bool(rider.get("_riding")):
		_fail("ride never completed")
		return

	# 5. Arrival lands on the island pad, and physics is handed back.
	var isle_pad: Vector3 = (markers[back_key] as Node3D).global_position
	var landed := player.global_position
	if landed.distance_to(isle_pad) > 4.0:
		_fail("player did not arrive on the island pad: %s vs pad %s"
			% [landed, isle_pad])
		return
	if not player.is_physics_processing():
		_fail("player physics was not restored after the ride")
		return

	# 6. The return trip works, and lands back at the castle dock.
	rider.call("board", "mindspark", false)
	guard = 0
	while bool(rider.get("_riding")) and guard < 2000:
		await process_frame
		guard += 1
	if bool(rider.get("_riding")):
		_fail("return ride never completed")
		return
	var castle_pad: Vector3 = (markers["mindspark:out"] as Node3D).global_position
	if player.global_position.distance_to(castle_pad) > 4.0:
		_fail("return ride did not land at the castle dock: %s vs %s"
			% [player.global_position, castle_pad])
		return

	print("TRAIN_RIDE_TEST: PASS — 6 stations, pads track islands, round trip lands on both pads")
	quit()


func _init() -> void:
	call_deferred("_run")
