extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("STORY_CROWN_RAILWAY_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	var player_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	player_shape.shape = capsule
	player.add_child(player_shape)
	world.add_child(player)
	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	await process_frame
	if int(railway.call("get_station_count")) != 4:
		_fail("expected Gallery, Mind, Heart, and Creator stations")
		return
	if int(railway.call("get_segment_count")) != 3:
		_fail("four story worlds must be joined by three curved segments")
		return
	var blueprint: Dictionary = railway.call("get_engineering_blueprint")
	if blueprint.layout_side != "right/east" \
			or float(blueprint.kingdom_boundary_clearance_m) != 200.0 \
			or float(blueprint.access_bridge_width_m) != 16.0 \
			or blueprint.rail_system != "single_center_monorail" \
			or float(blueprint.center_beam_width_m) != 3.2:
		_fail("floating station engineering blueprint has incorrect side or dimensions")
		return
	if float(railway.call("get_minimum_route_height")) < 28.0:
		_fail("Crown Line railway is not fully suspended above the world plane")
		return
	var kingdom_centres := [Vector3(-3600, 0, 3940), Vector3(0, 0, 7640), Vector3(3600, 0, 3940)]
	for kingdom_index in 3:
		var station_position: Vector3 = railway.call("get_station_position", kingdom_index + 1)
		if absf(station_position.x - (kingdom_centres[kingdom_index].x + 1700.0)) > 0.01:
			_fail("%s station is not 200m beyond its east boundary" % ["Mind", "Heart", "Creator"][kingdom_index])
			return
	var endpoints: PackedVector3Array = railway.call("get_route_endpoints")
	if endpoints[0].distance_to(endpoints[1]) < 500.0:
		_fail("the route closes like a circle instead of remaining an open line")
		return
	if endpoints[1].z <= endpoints[0].z:
		_fail("Crown Line still travels behind the direction faced by the gallery")
		return
	var flags := {"star_of_wisdom": false, "harmony_jewel": false, "creators_light": false}
	if not railway.call("station_unlocked_with", 0, flags) \
			or not railway.call("station_unlocked_with", 1, flags) \
			or railway.call("station_unlocked_with", 2, flags):
		_fail("initial station locks do not match the story")
		return
	flags.star_of_wisdom = true
	if not railway.call("station_unlocked_with", 2, flags) \
			or railway.call("station_unlocked_with", 3, flags):
		_fail("Star of Wisdom must unlock only Heart Melody")
		return
	flags.harmony_jewel = true
	if not railway.call("station_unlocked_with", 3, flags):
		_fail("Harmony Jewel must unlock Creator's Light")
		return
	for required in ["CrownLineRoute", "StoryStations", "RainbowGalaxyTrain", "CrownLineHUD"]:
		if railway.get_node_or_null(required) == null:
			_fail("railway failed to build %s" % required)
			return
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	if train.position.distance_to(railway.call("get_station_position", 0)) > 0.01:
		_fail("parked train origin does not match Gallery Station coordinates")
		return
	var route := railway.get_node("CrownLineRoute") as Node3D
	for segment in route.get_children():
		var beams := segment.find_children("CenterMonorailBeam", "MeshInstance3D", false, false)
		if beams.is_empty() or not segment.find_children("RainbowRail", "MeshInstance3D", false, false).is_empty() \
				or not segment.find_children("StarSleeper", "MeshInstance3D", false, false).is_empty():
			_fail("%s is not a single centre-support monorail" % segment.name)
			return
		if segment.find_children("CenterMonorailBeamCollision", "StaticBody3D", false, false).size() != beams.size():
			_fail("%s centre beam is missing matching collision support" % segment.name)
			return
	for station_index in 4:
		var station := railway.get_node("StoryStations/Station_%02d_%s" % [station_index + 1,
			["gallery", "mind", "heart", "creator"][station_index]]) as Node3D
		for required_part in ["WalkablePlatform", "AccessRamp", "BoardingLane", "BoardTrainSign",
				"PlatformGuardLeft", "PlatformGuardRight", "FloatingDockStructure",
				"KingdomAccessSkybridge"]:
			if station.get_node_or_null(required_part) == null:
				_fail("station %d lacks designed traversal part %s" % [station_index + 1, required_part])
				return
	var first_car := railway.get_node("RainbowGalaxyTrain/Carriage_01") as Node3D
	for train_part in ["PassengerDeck", "PassengerDeckCollision", "CoachGuardLeft",
			"CoachGuardRight", "JumpBench", "JumpBenchCollision", "DriverConsole",
			"DriverConsoleCollision", "DriverControls"]:
		if first_car.get_node_or_null(train_part) == null:
			_fail("rideable train lacks %s" % train_part)
			return
	player.position = railway.call("get_station_position", 0) + Vector3(0, 0, 11)
	railway.set("ride_duration", 0.08)
	if not bool(railway.call("request_ride")):
		_fail("player cannot board the train at Gallery Station")
		return
	await create_timer(0.03).timeout
	if not bool(railway.call("is_riding")) or bool(player.get("input_enabled")):
		_fail("train ride does not attach the passenger and lock walking input")
		return
	await create_timer(0.12).timeout
	if bool(railway.call("is_riding")) or int(railway.call("get_current_station")) != 1:
		_fail("train did not complete its journey to Mind Spark")
		return
	if not bool(player.get("input_enabled")) or player.global_position.distance_to(
			railway.to_global(railway.call("get_station_position", 1))) > 30.0:
		_fail("passenger was not released safely at the destination platform")
		return
	# The visible Q interaction enters real driver mode. W/S move along the open
	# line and Q is accepted only while docked.
	player.position = railway.call("get_station_position", 1) + Vector3(0, 0, 11)
	if not bool(railway.call("board_as_driver")) or not bool(railway.call("is_driving")):
		_fail("player cannot take control from the train driver platform")
		return
	if bool(player.get("input_enabled")):
		_fail("walking input remains active while the player drives the train")
		return
	railway.call("drive_manual", -1.0, 30.0)
	if int(railway.call("get_current_station")) != 0 or int(railway.call("get_drive_segment")) != -1:
		_fail("manual reverse control did not dock at Gallery Station")
		return
	if not bool(railway.call("request_disembark")) or not bool(player.get("input_enabled")):
		_fail("driver cannot leave the train safely after docking")
		return
	var journey := root.get_node_or_null("JourneyState")
	if journey != null:
		journey.set("treasures", {
			"star_of_wisdom": true,
			"harmony_jewel": true,
			"creators_light": false,
		})
	player.position = railway.call("get_station_position", 0) + Vector3(0, 0, 11)
	if not bool(railway.call("board_as_driver")):
		_fail("driver cannot re-board for the complete kingdom route")
		return
	for expected_station in [1, 2, 3]:
		railway.call("drive_manual", 1.0, 30.0)
		if int(railway.call("get_current_station")) != expected_station:
			_fail("manual forward control did not reach station %d" % expected_station)
			return
	if not bool(railway.call("request_disembark")):
		_fail("driver cannot disembark at Creator's Light")
		return
	print("STORY_CROWN_RAILWAY_TEST: PASS — climbable stations and player-driven Crown Line connect all four worlds")
	quit()
