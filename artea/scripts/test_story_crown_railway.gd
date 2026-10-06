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
	if int(railway.call("get_segment_count")) != 4 or not bool(railway.call("is_closed_loop")):
		_fail("four story worlds must be joined by a four-segment closed loop")
		return
	var blueprint: Dictionary = railway.call("get_engineering_blueprint")
	if blueprint.layout_side != "right/east" \
			or float(blueprint.kingdom_boundary_clearance_m) != 200.0 \
			or float(blueprint.access_bridge_width_m) != 16.0 \
			or blueprint.rail_system != "single_center_monorail" \
			or float(blueprint.center_beam_width_m) != 3.2 \
			or not bool(blueprint.closed_loop):
		_fail("floating station engineering blueprint has incorrect side or dimensions")
		return
	if absf(float(railway.call("get_minimum_route_height")) - 35.0) > 0.05:
		_fail("Crown Line route is not a constant-height level loop")
		return
	var total_route_length := float(railway.call("get_total_route_length"))
	var minimum_turn_radius := float(railway.call("get_minimum_turn_radius"))
	print("CROWN_LINE_ROUTE_METRICS: %.1fm total, %.1fm minimum turn radius" % [
		total_route_length, minimum_turn_radius])
	for metric_segment in 4:
		print("CROWN_LINE_SEGMENT_%d_RADIUS: %.1fm" % [metric_segment,
			float(railway.call("get_segment_minimum_turn_radius", metric_segment))])
	if minimum_turn_radius < 40.0:
		_fail("Crown Line contains a turn too tight for the complete train")
		return
	if total_route_length < 15000.0 or total_route_length > 26000.0:
		_fail("Crown Line is too short for sightseeing or unnecessarily long")
		return
	var full_lap_seconds := float(railway.call("get_full_lap_drive_seconds"))
	if full_lap_seconds < 45.0 or full_lap_seconds > 70.0:
		_fail("full-speed sightseeing lap is too brief or too long")
		return
	var authored_curves: Array = railway.get("_curves")
	for segment_index in authored_curves.size():
		var authored_curve: Curve3D = authored_curves[segment_index]
		if authored_curve.point_count != 4:
			_fail("segment %d lacks explicit straight docking sections" % segment_index)
			return
		var departure_start := authored_curve.get_point_position(0)
		var departure_end := authored_curve.get_point_position(1)
		var arrival_start := authored_curve.get_point_position(2)
		var arrival_end := authored_curve.get_point_position(3)
		if absf(departure_start.distance_to(departure_end) - 150.0) > 0.1 \
				or absf(arrival_start.distance_to(arrival_end) - 150.0) > 0.1:
			_fail("segment %d does not stay straight for a full train length at each dock" % segment_index)
			return
		var departure_mid := authored_curve.sample_baked(75.0)
		if departure_mid.distance_to(departure_start.lerp(departure_end, 0.5)) > 0.25:
			_fail("segment %d begins curving before it clears the station" % segment_index)
			return
		var incoming_curve: Curve3D = authored_curves[posmod(segment_index - 1,
			authored_curves.size())]
		var incoming_length := incoming_curve.get_baked_length()
		var incoming_direction := (incoming_curve.sample_baked(incoming_length) -
			incoming_curve.sample_baked(incoming_length - 10.0)).normalized()
		var outgoing_direction := (authored_curve.sample_baked(10.0) -
			authored_curve.sample_baked(0.0)).normalized()
		if incoming_direction.dot(outgoing_direction) < 0.999:
			_fail("station %d rail is not one straight line through the platform" % segment_index)
			return
	var gallery_forward: Vector3 = railway.call("get_route_forward_direction_at_station", 0)
	var original_gallery_forward := Vector3(160.0, 0.0, 260.0).normalized()
	if gallery_forward.dot(original_gallery_forward) < 0.995:
		_fail("Gallery railway no longer follows its original departure direction")
		return
	var mind_station: Vector3 = railway.call("get_station_position", 1)
	if mind_station.distance_to(Vector3(-883, 35, 1640)) > 0.01:
		_fail("Mind station is not at the original west-side park location")
		return
	var mind_landing: Vector3 = railway.call("get_station_landing", 1)
	if mind_landing.distance_to(Vector3(-767, 2, 1640)) > 0.01:
		_fail("Mind station stair does not finish safely on the main park island")
		return
	var kingdom_centres := [Vector3(0, 0, 7640), Vector3(3600, 0, 3940)]
	for kingdom_index in 2:
		var station_position: Vector3 = railway.call("get_station_position", kingdom_index + 2)
		if absf(station_position.x - (kingdom_centres[kingdom_index].x + 1700.0)) > 0.01:
			_fail("%s station is not 200m beyond its east boundary" % ["Heart", "Creator"][kingdom_index])
			return
	var flags := {"star_of_wisdom": false, "harmony_jewel": false, "creators_light": false}
	for station_index in 4:
		if not railway.call("station_unlocked_with", station_index, flags):
			_fail("every station must be reachable without treasures")
			return
	for required in ["CrownLineRoute", "StoryStations", "RainbowGalaxyTrain", "CrownLineHUD"]:
		if railway.get_node_or_null(required) == null:
			_fail("railway failed to build %s" % required)
			return
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	if int(railway.call("get_start_station_index")) != 0 \
			or String(railway.call("get_start_station_id")) != "gallery":
		_fail("opening castle-side Gallery dock is not the explicit start station")
		return
	if train.position.distance_to(railway.call("get_station_position", 0)) > 0.01:
		_fail("parked train origin does not match Gallery Station coordinates")
		return
	var detailed_train := train.get_node_or_null("BlenderCrownLineTrain") as Node3D
	if detailed_train == null:
		_fail("detailed Blender Crown Line train was not instantiated")
		return
	if int(detailed_train.get_meta("editable_part_count", 0)) < 13000:
		_fail("Blender train does not expose its minimum 13,000-piece construction inventory")
		return
	var runtime_mesh_count := detailed_train.find_children(
		"*", "MeshInstance3D", true, false).size()
	if runtime_mesh_count < 40 or runtime_mesh_count > 160:
		_fail("runtime train is not using the optimized textured surface plus mechanisms")
		return
	if detailed_train.find_child("CrownLineRuntimeTexturedSurface", true, false) == null:
		_fail("runtime train is missing its consolidated full-body textured surface")
		return
	if int(railway.call("get_registered_mechanism_count")) < 40:
		_fail("analog speed, wheel and crystal reactor mechanisms were not registered")
		return
	var features: Dictionary = railway.call("get_train_feature_summary")
	if not bool(features.driveable) or not bool(features.walkable) \
			or not bool(features.jumpable) or not bool(features.sittable) \
			or int(features.passenger_seats) < 6 or not bool(features.analog_speed_mechanism):
		_fail("train feature inventory is missing driving, traversal, seating or analog speed")
		return
	var route := railway.get_node("CrownLineRoute") as Node3D
	for segment in route.get_children():
		var beams := segment.find_children("CenterMonorailBeam", "MeshInstance3D", false, false)
		var ribbons := segment.find_children("CrownLineEnergyRibbon", "MeshInstance3D", false, false)
		if beams.size() != 1 or ribbons.size() != 1 \
				or not bool(segment.get_meta("continuous_track", false)) \
				or int(segment.get_meta("visual_mesh_pieces", 0)) != 1 \
				or float(segment.get_meta("sample_spacing_m", 100.0)) > 10.1 \
				or not segment.find_children("RainbowRail", "MeshInstance3D", false, false).is_empty() \
				or not segment.find_children("StarSleeper", "MeshInstance3D", false, false).is_empty():
			_fail("%s is not one continuous curved centre-support monorail" % segment.name)
			return
		if segment.find_children("CenterMonorailBeamCollision", "StaticBody3D", false, false).size() != 1:
			_fail("%s continuous centre beam is missing its matching collision surface" % segment.name)
			return
		if not ((beams[0] as MeshInstance3D).mesh is ArrayMesh) \
				or (beams[0] as MeshInstance3D).mesh.get_faces().size() < 100:
			_fail("%s centre beam was reduced to disconnected primitive boxes" % segment.name)
			return
		var beam := beams[0] as MeshInstance3D
		var colours := beam.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray
		var unique_colours := {}
		for colour in colours:
			unique_colours[(colour as Color).to_html(false)] = true
		if not beam.material_override is ShaderMaterial or unique_colours.size() < 7:
			_fail("%s centre beam does not carry the full rainbow palette" % segment.name)
			return
		if (ribbons[0] as MeshInstance3D).material_override != railway.get("_gold_material"):
			_fail("%s energy ribbon is not using the gold railway accent" % segment.name)
			return
	var incoming_mind_segment := route.get_node("StorySegment_1_gallery_to_mind") as Node3D
	var outgoing_mind_segment := route.get_node("StorySegment_2_mind_to_heart") as Node3D
	for mind_segment in [incoming_mind_segment, outgoing_mind_segment]:
		if not bool(mind_segment.get_meta("mind_spark_rail_upgrade", false)) \
				or mind_segment.find_children("MindSpark*CircuitGuideLeft", "MeshInstance3D", false, false).size() != 1 \
				or mind_segment.find_children("MindSpark*CircuitGuideRight", "MeshInstance3D", false, false).size() != 1:
			_fail("Mind Spark approach railway lacks its continuous cyan circuit guides")
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
		var platform_design := station.get_node("WalkablePlatform") as Node3D
		if String(platform_design.get_meta("design", "")) != "twin_train_fit_platform" \
				or absf(float(platform_design.get_meta("platform_length_m", 0.0)) - 57.0) > 0.01 \
				or absf(float(platform_design.get_meta("central_train_clearance_m", 0.0)) - 12.0) > 0.01:
			_fail("station %d does not use the new train-fit twin-platform architecture" % (station_index + 1))
			return
		for platform_part in ["LeftStructuralDeck", "RightStructuralDeck",
				"LeftRaisedBoardingBase", "RightRaisedBoardingBase",
				"CentralMonorailServiceChannel", "LeftChannelLight", "RightChannelLight"]:
			if platform_design.get_node_or_null(platform_part) == null:
				_fail("station %d new platform lacks %s" % [station_index + 1, platform_part])
				return
		if platform_design.find_children("*RainbowFascia_*", "MeshInstance3D", false, false).size() != 14:
			_fail("station %d platform does not carry fourteen separated rainbow fascia panels" % (station_index + 1))
			return
		var roof_foundations := station.get_node_or_null("OldRoofSupportFoundations") as Node3D
		if roof_foundations == null \
				or roof_foundations.find_children("RoofPlinth_*", "MeshInstance3D", false, false).size() != 6:
			_fail("station %d restored roof columns lack six structural platform plinths" % (station_index + 1))
			return
		var boarding_layout := station.get_node("BoardingLane") as Node3D
		if not bool(boarding_layout.get_meta("aligned_to_train_route", false)) \
				or absf(float(boarding_layout.get_meta("train_clear_width_m", 0.0)) - 12.0) > 0.01:
			_fail("station %d boarding layout is not sized and aligned to the train" % (station_index + 1))
			return
		for boarding_part in ["DriverWalkwayLeft", "DriverWalkwayRight",
				"PassengerWalkwayLeft", "PassengerWalkwayRight",
				"DriverBoardingBridgeLeft", "DriverBoardingBridgeRight",
				"PassengerBoardingBridgeLeft", "PassengerBoardingBridgeRight",
				"EntranceToTrainWalkway", "DriverZoneSign", "PassengerZoneSign"]:
			if boarding_layout.get_node_or_null(boarding_part) == null:
				_fail("station %d lacks train-fit boarding part %s" % [station_index + 1, boarding_part])
				return
		var route_forward: Vector3 = railway.call("get_route_forward_direction_at_station", station_index)
		if (-boarding_layout.basis.z).normalized().dot(route_forward) < 0.999:
			_fail("station %d walkways do not follow the parked train direction" % (station_index + 1))
			return
		for guard_name in ["PlatformGuardLeft", "PlatformGuardRight"]:
			var guard := station.get_node(guard_name) as Node3D
			if String(guard.get_meta("barrier_plan", "")) != "train_fit_no_overlap":
				_fail("station %d %s lacks the purposeful no-overlap barrier plan" % [
					station_index + 1, guard_name])
				return
			if float(guard.get_meta("train_side_clearance_m", 0.0)) < 0.6:
				_fail("station %d %s barrier is too close to the train machinery" % [
					station_index + 1, guard_name])
				return
			if int(guard.get_meta("shared_connection_post_count", 0)) < 18:
				_fail("station %d %s barrier spans are not connected by shared posts" % [
					station_index + 1, guard_name])
				return
			for barrier_name in ["EngineMachineryBarrier", "CoachSeparationBarrier",
					"RearTrackBarrier", "FrontPlatformEndStop", "RearPlatformEndStop"]:
				var barrier := guard.get_node_or_null(barrier_name) as Node3D
				if barrier == null or String(barrier.get_meta("purpose", "")).is_empty():
					_fail("station %d %s has no defined safety purpose" % [
						station_index + 1, barrier_name])
					return
				if int(barrier.get_meta("connected_span_count", 0)) < 1:
					_fail("station %d %s is not divided into connected rail spans" % [
						station_index + 1, barrier_name])
					return
			var driver_clear: Vector2 = guard.get_meta("driver_gate_clear_z")
			var passenger_clear: Vector2 = guard.get_meta("passenger_gate_clear_z")
			if driver_clear.x >= 0.0 or driver_clear.y <= 0.0 \
					or passenger_clear.x >= 15.0 or passenger_clear.y <= 15.0:
				_fail("station %d barriers close a driver or passenger boarding gate" % (station_index + 1))
				return
		if station.get_node_or_null("DestinationWheel") != null \
				or not station.find_children("WheelSpoke", "MeshInstance3D", true, false).is_empty():
			_fail("station %d still contains the redundant destination disc or floor spokes" % (station_index + 1))
			return
		if station_index == 1:
			var mind_upgrade := station.get_node_or_null("MindSparkStationUpgrade") as Node3D
			if mind_upgrade == null \
					or mind_upgrade.get_node_or_null("CircularBoardingPromenade") == null \
					or mind_upgrade.get_node_or_null("MindCrystalTreeCanopy") == null \
					or mind_upgrade.get_node_or_null("MindSparkFloatingGround") == null \
					or mind_upgrade.get_node_or_null("CircuitMonolithGarden") == null \
					or not bool(mind_upgrade.get_meta("walk_around_train", false)) \
					or not bool(mind_upgrade.get_meta("cab_q_interaction", false)):
				_fail("Mind Spark lacks its circular walk-around technology station upgrade")
				return
			var floating_ground := mind_upgrade.get_node("MindSparkFloatingGround") as Node3D
			for ground_part in ["WalkableCircuitFloor", "SegmentedOuterStoneRim",
					"CentralCircuitDisc", "TriangulatedSuspendedIsland",
					"AetherCrystalReactor"]:
				if floating_ground.get_node_or_null(ground_part) == null:
					_fail("Mind Spark floating train ground lacks %s" % ground_part)
					return
			var crystal_reactor := floating_ground.get_node("AetherCrystalReactor") as Node3D
			for reactor_part in ["CentralHangingCrystal", "LuminousCrystalCore",
					"CrystalCrown", "TechnologyGyroRingA", "TechnologyGyroRingB",
					"TechnologyGyroRingC", "VioletAetherOrbit", "NatureEnergyCrown",
					"OrbitingAetherMotes", "AetherPulseLight"]:
				if crystal_reactor.get_node_or_null(reactor_part) == null:
					_fail("Mind Spark crystal power reactor lacks %s" % reactor_part)
					return
			if crystal_reactor.get_node_or_null("NatureEnergyCrown/NatureLifeRing") == null:
				_fail("Mind Spark crystal lacks its nature life-energy ring")
				return
			if crystal_reactor.find_children("CircuitSpoke_*", "MeshInstance3D", false, false).size() != 8 \
					or crystal_reactor.find_children("CrystalFacetRib_*", "MeshInstance3D", false, false).size() != 8 \
					or crystal_reactor.find_children("PowerLeaf_*", "MeshInstance3D", true, false).size() != 8 \
					or crystal_reactor.find_children("AetherMote_*", "MeshInstance3D", true, false).size() != 18:
				_fail("Mind Spark crystal lacks its technology, nature, or magic effects")
				return
			if floating_ground.find_children("RadialCircuit_*", "MeshInstance3D", false, false).size() != 16 \
					or floating_ground.find_children("RimPowerCrystal_*", "Node3D", false, false).size() != 4:
				_fail("Mind Spark ground lacks its complete circuit or crystal layout")
				return
			for rim_reactor in floating_ground.find_children(
					"RimPowerCrystal_*", "Node3D", false, false):
				for rim_part in ["RimHangingCrystal", "RimLuminousCore",
						"RimTechnologyRingUpper", "RimTechnologyRingLower",
						"RimMagicOrbit", "RimNatureCrown", "RimAetherMotes",
						"RimPulseLight"]:
					if rim_reactor.get_node_or_null(rim_part) == null:
						_fail("rim crystal reactor lacks %s" % rim_part)
						return
				if rim_reactor.find_children("RimFacetRib_*", "MeshInstance3D", false, false).size() != 6 \
						or rim_reactor.find_children("RimPowerLeaf_*", "MeshInstance3D", true, false).size() != 4 \
						or rim_reactor.find_children("RimAetherMote_*", "MeshInstance3D", true, false).size() != 6:
					_fail("rim crystal reactor lacks detailed power effects")
					return
			if (station.get_node("FloatingDockStructure") as Node3D).visible:
				_fail("Mind Spark generic foundation remains visible through its faceted island")
				return
			if mind_upgrade.find_children("CircuitMonolith_*", "MeshInstance3D", true, false).size() != 4 \
					or mind_upgrade.find_children("RestoredSolarGlassPetal_*", "MeshInstance3D", true, false).size() != 12 \
					or mind_upgrade.get_node_or_null("RestoredBranchingSupportColumns") == null:
				_fail("Mind Spark station lacks its restored split-wing roof and wayfinding pylons")
				return
			for restored_petal in mind_upgrade.find_children(
					"RestoredSolarGlassPetal_*", "MeshInstance3D", true, false):
				if absf((restored_petal as MeshInstance3D).global_position.x -
						mind_upgrade.global_position.x) < 14.0:
					_fail("restored Mind Spark canopy blocks the open train slot")
					return
			if station.get_node_or_null("BioMagitechPavilion") != null:
				_fail("generic station pavilion was not replaced at Mind Spark only")
				return
			continue
		if station.get_node_or_null("MindSparkStationUpgrade") != null:
			_fail("Mind Spark artwork leaked into another kingdom station")
			return
		var pavilion := station.get_node_or_null("BioMagitechPavilion") as Node3D
		if pavilion == null:
			_fail("station %d lacks its established bio-magitech pavilion" % (station_index + 1))
			return
		var canopy := pavilion.get_node_or_null("LivingCrystalCanopy") as Node3D
		if canopy == null or canopy.find_children("SolarGlassPetal_*", "MeshInstance3D", true, false).size() != 12:
			_fail("station %d does not have its original twelve-leaf roof" % (station_index + 1))
			return
		if pavilion.get_node_or_null("BranchingSupportColumns") == null \
				or pavilion.get_node_or_null("CanopyEnergyRing") == null:
			_fail("station %d is missing its bio-magitech structural system" % (station_index + 1))
			return
		if pavilion.get_node_or_null("ResonanceBoardingArchRear") != null \
				or pavilion.get_node_or_null("ResonanceBoardingArchFront") != null \
				or pavilion.get_node_or_null("CrystalEnergySpine") != null:
			_fail("station %d still contains the obstructive portals or centre mast" % (station_index + 1))
			return
		# All roof petals and columns must stay outside the 15 m central train slot.
		for petal_candidate in canopy.find_children("SolarGlassPetal_*", "MeshInstance3D", true, false):
			if absf((petal_candidate as MeshInstance3D).position.x) < 14.0:
				_fail("station %d canopy obstructs the central monorail slot" % (station_index + 1))
				return
	var first_car := railway.get_node("RainbowGalaxyTrain/Carriage_01") as Node3D
	if not train is AnimatableBody3D or not (train as AnimatableBody3D).sync_to_physics:
		_fail("complete train is not one synchronized moving platform")
		return
	var platform := train as AnimatableBody3D
	if platform.collision_layer != 1 or platform.collision_mask != 1 \
			or String(platform.get_meta("mass_model", "")) != "infinite_mass_moving_platform" \
			or platform.find_children("*", "CollisionShape3D", false, false).size() < 30:
		_fail("train platform lacks complete solid collision or infinite-mass metadata")
		return
	# The single centre bench is now two side benches with a walkable aisle
	# between them, so the coach can be crossed on foot instead of climbed over.
	for train_part in ["PassengerDeck", "CoachRoofWalkway", "CoachGuardLeft_Front",
			"CoachGuardRight_Rear", "BoardingStepLeft", "BoardingStepRight", "JumpBenchLeft",
			"JumpBenchRight", "DriverConsole", "DriverControls"]:
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
	# Q resolves by local train section: cab enters driver mode, benches seat the
	# passenger. W/S move in both directions around the closed line.
	# The ranges must stay local to one train section, but they also have to be
	# reachable: a 2 m radius could only ever be satisfied by standing exactly on
	# the interaction point, which the deck geometry made impossible, so the cab
	# was untriggerable in play while this assertion still passed.
	var driver_range := float(railway.call("get_driver_interaction_range"))
	var seat_range := float(railway.call("get_seat_interaction_range"))
	if driver_range < 8.0 or driver_range > 14.0 or seat_range < 6.0 or seat_range > 10.0:
		_fail("Q interaction range is not a reachable, train-section-local radius")
		return
	var flexible_range := float(railway.call("get_flexible_boarding_range"))
	if flexible_range < 10.0 or flexible_range > 18.0:
		_fail("1/2 boarding range is not forgiving while remaining train-local")
		return
	var outside_shell := train.to_global(Vector3(6.4 + flexible_range - 0.05, 2.0, 0.0))
	if float(railway.call("get_distance_to_train_footprint", outside_shell)) > flexible_range:
		_fail("flexible boarding does not measure from the train shell")
		return
	var driver_position: Vector3 = railway.call("get_driver_interaction_position")
	if String(railway.call("get_interaction_mode_for_position",
			driver_position + train.global_basis.x.normalized() * (driver_range - 0.05))) != "drive" \
			or String(railway.call("get_interaction_mode_for_position",
			driver_position + train.global_basis.x.normalized() * (driver_range + 0.05))) != "none":
		_fail("driver Q interaction does not respect its own range boundary")
		return
	player.global_position = driver_position
	# Press the project's "interact" action rather than a raw Q keycode: the
	# binding is authored as a physical keycode, so a keycode-only event is not
	# what the running game actually delivers.
	var board_event := InputEventAction.new()
	board_event.action = "interact"
	board_event.pressed = true
	railway.call("_unhandled_input", board_event)
	if not bool(railway.call("is_driving")):
		_fail("the visible Q interaction does not put the player on the train driver platform")
		return
	if player.global_position.distance_to(railway.call("get_driver_seat_position")) > 0.05:
		_fail("cab-door Q interaction does not move the player into the actual driver seat")
		return
	if bool(player.get("input_enabled")):
		_fail("walking input remains active while the player drives the train")
		return
	railway.call("drive_manual", -1.0, 0.5)
	if float(railway.call("get_display_speed_kph")) <= 0.0:
		_fail("driver speed display does not respond to actual train acceleration")
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
			"star_of_wisdom": false,
			"harmony_jewel": false,
			"creators_light": false,
		})
	player.global_position = railway.call("get_driver_interaction_position")
	if not bool(railway.call("board_as_driver")):
		_fail("driver cannot re-board for the complete kingdom route")
		return
	for expected_station in [1, 2, 3, 0]:
		railway.call("drive_manual", 1.0, 30.0)
		if int(railway.call("get_current_station")) != expected_station:
			_fail("manual forward control did not reach loop station %d" % expected_station)
			return
	for expected_station in [3, 2, 1, 0]:
		railway.call("drive_manual", -1.0, 30.0)
		if int(railway.call("get_current_station")) != expected_station:
			_fail("reverse control did not reach station %d" % expected_station)
			return
	if not bool(railway.call("request_disembark")):
		_fail("driver cannot disembark after returning to Gallery on the closed loop")
		return
	player.global_position = train.to_global(Vector3(-2.4, 3.0, 2.8))
	var first_seat_position: Vector3 = railway.call("get_passenger_seat_position", 0)
	# Probe outward from the outermost bench, away from the train, so the only
	# seat in reach is this one and the boundary being measured is its own.
	if String(railway.call("get_interaction_mode_for_position",
			first_seat_position - train.global_basis.x.normalized() * (seat_range - 0.05))) != "sit" \
			or String(railway.call("get_interaction_mode_for_position",
			first_seat_position - train.global_basis.x.normalized() * (seat_range + 0.05))) != "none":
		_fail("passenger Q interaction does not respect its own range boundary")
		return
	if String(railway.call("get_interaction_mode_for_position", player.global_position)) != "sit":
		_fail("passenger section proximity does not resolve to sitting")
		return
	if int(railway.call("get_passenger_seat_count")) != 6:
		_fail("train does not expose all six passenger seats")
		return
	if not bool(railway.call("sit_in_passenger_seat", 0)) \
			or not bool(railway.call("is_passenger_seated")) \
			or bool(player.get("input_enabled")):
		_fail("player cannot use the passenger bench seat")
		return
	await create_timer(0.12).timeout
	if int(railway.call("get_current_station")) != 1:
		_fail("seated passenger did not ride automatically to the next station")
		return
	if not bool(railway.call("leave_passenger_seat")) or not bool(player.get("input_enabled")):
		_fail("player cannot stand safely from the passenger bench")
		return
	print("STORY_CROWN_RAILWAY_TEST: PASS — climbable stations and player-driven Crown Line connect all four worlds")
	quit()
