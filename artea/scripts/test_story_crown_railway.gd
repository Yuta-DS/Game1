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
			or blueprint.rail_system != "centre_support_with_dual_wheel_rails" \
			or float(blueprint.center_beam_width_m) != 3.2 \
			or absf(float(blueprint.wheel_rail_gauge_m) - 8.0) > 0.01 \
			or absf(float(blueprint.wheel_rail_top_below_train_origin_m) - 0.85) > 0.01 \
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
		var wheel_rails := segment.find_children("CrownWheelRail*", "MeshInstance3D", false, false)
		if beams.size() != 1 or ribbons.size() != 1 \
				or wheel_rails.size() != 2 \
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
		if segment.find_children("CrownWheelRail*Collision", "StaticBody3D", false, false).size() != 2 \
				or absf(float(segment.get_meta("wheel_rail_half_gauge_m", 0.0)) - 4.0) > 0.01 \
				or absf(float(segment.get_meta(
					"wheel_rail_top_below_train_origin_m", 0.0)) - 0.85) > 0.01:
			_fail("%s wheel rails do not align with the train's measured ±4 m treads" % segment.name)
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
		if String(station.get_meta("canonical_station_blueprint", "")) \
				!= "rainbow_civic_station_v1" \
				or String(station.get_meta("canonical_station_source", "")) \
					!= "gallery_station" \
				or not bool(station.get_meta("complete_station_template", false)):
			_fail("station %d was not built from the current complete station blueprint" \
				% (station_index + 1))
			return
		if station.get_node_or_null("MindSparkStationUpgrade") != null:
			_fail("station %d still contains a divergent legacy station design" \
				% (station_index + 1))
			return
		for required_part in ["WalkablePlatform", "BoardingLane", "BoardTrainSign",
				"PlatformGuardLeft", "PlatformGuardRight", "FloatingDockStructure"]:
			if station.get_node_or_null(required_part) == null:
				_fail("station %d lacks designed traversal part %s" % [station_index + 1, required_part])
				return
		if station_index == 1:
			if station.get_node_or_null("KingdomAccessSkybridge") != null \
					or station.get_node_or_null("MindSparkStationAccessStairs") == null \
					or station.get_node_or_null("MindSparkLongAccessBridgeRemoved") == null \
					or not bool(station.get_meta("long_access_bridge_removed", false)) \
					or not bool(station.get_meta("grounded_station_stair_added", false)):
				_fail("Mind Spark station did not replace its longest bridge with a grounded stair")
				return
		else:
			for access_part in ["AccessRamp", "KingdomAccessSkybridge"]:
				if station.get_node_or_null(access_part) == null:
					_fail("station %d lacks designed access part %s" % [
						station_index + 1, access_part])
					return
		var platform_design := station.get_node("WalkablePlatform") as Node3D
		if not bool(station.get_meta("old_station_roof_restored", false)) \
				or String(station.get_meta("old_station_restoration_scope", "")) \
					!= "roof_only":
			_fail("station %d did not retain only its established roof architecture" % (station_index + 1))
			return
		if String(platform_design.get_meta("design", "")) != "twin_train_fit_platform" \
				or absf(float(platform_design.get_meta("platform_length_m", 0.0)) - 57.0) > 0.01 \
				or absf(float(platform_design.get_meta("central_train_clearance_m", 0.0)) - 12.0) > 0.01 \
				or String(platform_design.get_meta("foundation_design_language", "")) \
					!= "piltover_arcane_engineering" \
				or absf(float(platform_design.get_meta("gold_accent_ratio", 0.0)) - 0.10) > 0.001:
			_fail("station %d does not use the new train-fit twin-platform architecture" % (station_index + 1))
			return
		for platform_part in ["LeftStructuralDeck", "RightStructuralDeck",
				"LeftRaisedBoardingBase", "RightRaisedBoardingBase",
				"CentralMonorailServiceChannel", "LeftChannelLight", "RightChannelLight"]:
			if platform_design.get_node_or_null(platform_part) == null:
				_fail("station %d new platform lacks %s" % [station_index + 1, platform_part])
				return
		for side_name in ["Left", "Right"]:
			if platform_design.get_node_or_null("%sLowerFoundationApron" % side_name) != null:
				_fail("station %d still contains the pale line below the platform" % (station_index + 1))
				return
			if platform_design.get_node_or_null("%sHextechFasciaConduit" % side_name) != null:
				_fail("station %d still has a glowing fascia line crossing the bridge view" % (station_index + 1))
				return
			var structural_deck := platform_design.get_node(
				"%sStructuralDeck" % side_name) as MeshInstance3D
			var structural_material := structural_deck.material_override as StandardMaterial3D
			if structural_material == null \
					or structural_material.albedo_color.get_luminance() > 0.30:
				_fail("station %d %s foundation is not a recessed dark structural field" % [
					station_index + 1, side_name])
				return
		if platform_design.find_children("*PiltoverInsetPanel_*", "MeshInstance3D", false, false).size() != 16 \
				or not platform_design.find_children("*RainbowFascia_*", "MeshInstance3D", false, false).is_empty() \
				or String(platform_design.get_meta("ground_layout", "")) != "single_surface_mirrored" \
				or int(platform_design.get_meta("visual_surface_layers_per_side", 0)) != 1 \
				or int(platform_design.get_meta("rainbow_fascia_colour_count", 0)) != 7 \
				or not bool(platform_design.get_meta("gold_frame_layout", false)):
			_fail("station %d platform fascia is not clean and mirrored" % (station_index + 1))
			return
		var fascia_colours := {}
		for fascia_panel in platform_design.find_children(
				"*PiltoverInsetPanel_*", "MeshInstance3D", false, false):
			var fascia_material := (fascia_panel as MeshInstance3D).material_override as StandardMaterial3D
			if fascia_material != null:
				fascia_colours[fascia_material.albedo_color.to_html()] = true
		if fascia_colours.size() != 7:
			_fail("station %d fascia does not cycle through all seven rainbow colors" % (station_index + 1))
			return
		var roof_foundations := station.get_node_or_null("OldRoofSupportFoundations") as Node3D
		if roof_foundations == null \
				or roof_foundations.find_children("RoofPlinth_*", "MeshInstance3D", false, false).size() != 4 \
				or roof_foundations.find_children("RoofFoundationDropPier_*", "MeshInstance3D", false, false).size() != 4 \
				or not bool(roof_foundations.get_meta("centre_supports_removed", false)) \
				or not bool(roof_foundations.get_meta("roof_load_path_continuous", false)):
			_fail("station %d roof does not use four stair-clear outer foundations" % (station_index + 1))
			return
		if not roof_foundations.find_children(
				"RoofFoundationOutrigger_*", "MeshInstance3D", false, false).is_empty():
			_fail("station %d still contains the loose roof-foundation blocks" % (station_index + 1))
			return
		for roof_foundation in roof_foundations.find_children(
				"RoofPlinth_*", "MeshInstance3D", false, false):
			if absf((roof_foundation as MeshInstance3D).position.z) < 11.74:
				_fail("station %d roof foundation overlaps the central stair or walkway" % (station_index + 1))
				return
		var floating_structure := station.get_node("FloatingDockStructure") as Node3D
		if String(floating_structure.get_meta("design_language", "")) \
				!= "piltover_arcane_engineering" \
				or absf(float(floating_structure.get_meta("gold_accent_ratio", 0.0)) - 0.10) > 0.001 \
				or not bool(floating_structure.get_meta("roof_load_path_continuous", false)) \
				or String(floating_structure.get_meta("top_ground_style", "")) \
					!= "rainbow_civic_crown_gold_grid" \
				or int(floating_structure.get_meta("rainbow_ground_sector_count", 0)) != 14 \
				or not bool(floating_structure.get_meta("gold_ground_frame", false)):
			_fail("station %d floating foundation does not use the Piltover structural palette" % (station_index + 1))
			return
		for hull_part in ["PiltoverIvoryHullCrown", "PiltoverTealUndercroft",
				"TenPercentGoldCrownTrim", "HextechHullEnergyBelt",
				"RainbowCivicFloorCore", "RainbowCivicFloorInnerGoldRing"]:
			if floating_structure.get_node_or_null(hull_part) == null:
				_fail("station %d floating foundation lacks %s" % [station_index + 1, hull_part])
				return
		if floating_structure.find_children("PiltoverHullRib_*", "MeshInstance3D", false, false).size() != 12 \
				or floating_structure.find_children("GoldHullKeystone_*", "MeshInstance3D", false, false).size() != 4 \
				or floating_structure.find_children("RainbowCivicFloorSector_*", "MeshInstance3D", false, false).size() != 14 \
				or floating_structure.find_children("CivicGoldRadialFrame_*", "MeshInstance3D", false, false).size() != 14:
			_fail("station %d floating foundation lacks its complete rib and keystone system" % (station_index + 1))
			return
		var civic_floor_colours := {}
		for civic_sector in floating_structure.find_children(
				"RainbowCivicFloorSector_*", "MeshInstance3D", false, false):
			civic_floor_colours[int(civic_sector.get_meta("rainbow_material_index", -1))] = true
			if not bool(civic_sector.get_meta("gold_seam_framed", false)):
				_fail("station %d civic floor sector is not framed by the gold radial grid" % (station_index + 1))
				return
		if civic_floor_colours.size() != 7:
			_fail("station %d civic floor does not repeat the full seven-color palette" % (station_index + 1))
			return
		if not floating_structure.find_children("PiltoverFoundationBrace_*", "MeshInstance3D", false, false).is_empty():
			_fail("station %d still has diagonal braces crossing the bridge view" % (station_index + 1))
			return
		if not floating_structure.find_children("AetherAnchor_*", "MeshInstance3D", false, false).is_empty():
			_fail("station %d still has glowing anchors crossing the bridge view" % (station_index + 1))
			return
		if floating_structure.get_node_or_null("SuspendedHextechCore") != null:
			_fail("station %d still has a suspended core spike crossing the bridge view" % (station_index + 1))
			return
		var boarding_layout := station.get_node("BoardingLane") as Node3D
		if not bool(boarding_layout.get_meta("aligned_to_train_route", false)) \
				or absf(float(boarding_layout.get_meta("train_clear_width_m", 0.0)) - 12.0) > 0.01 \
				or String(platform_design.get_meta("walking_surface_style", "")) \
					!= "arcane_pixel_deco_floor_gold_edge" \
				or String(boarding_layout.get_meta("walking_surface_style", "")) \
					!= "arcane_pixel_deco_floor_gold_edge":
			_fail("station %d boarding layout is not sized and aligned to the train" % (station_index + 1))
			return
		for boarding_part in ["SynchronizedPlatformGroundLeft", "SynchronizedPlatformGroundRight",
				"DriverBoardingBridgeLeft", "DriverBoardingBridgeRight",
				"PassengerBoardingBridgeFrontLeft", "PassengerBoardingBridgeFrontRight",
				"PassengerBoardingBridgeLeft", "PassengerBoardingBridgeRight",
				"EntranceToTrainWalkway", "DriverZoneSign",
				"PassengerFrontZoneSign", "PassengerRearZoneSign"]:
			if boarding_layout.get_node_or_null(boarding_part) == null:
				_fail("station %d lacks train-fit boarding part %s" % [station_index + 1, boarding_part])
				return
		if not bool(boarding_layout.get_meta("driver_route_continuous", false)) \
				or absf(float(boarding_layout.get_meta("driver_walkway_front_z", 0.0)) + 28.0) > 0.01 \
				or absf(float(boarding_layout.get_meta("driver_boarding_gate_z", 99.0)) + 15.85) > 0.01 \
				or absf(float(boarding_layout.get_meta("driver_gate_width_m", 0.0)) - 7.05) > 0.01 \
				or int(boarding_layout.get_meta("boarding_gap_count", 0)) != 3 \
				or int(boarding_layout.get_meta("passenger_gate_count", 0)) != 2 \
				or not bool(boarding_layout.get_meta("platform_ground_synced", false)):
			_fail("station %d driver route does not extend from the engine nose to the cab gate" % (station_index + 1))
			return
		var driver_ground_range: Vector2 = boarding_layout.get_meta("driver_ground_range_z")
		var passenger_ground_range: Vector2 = boarding_layout.get_meta("passenger_ground_range_z")
		if absf(driver_ground_range.x + 28.0) > 0.01 \
				or absf(driver_ground_range.y + 12.1) > 0.01 \
				or absf(passenger_ground_range.x + 12.1) > 0.01 \
				or absf(passenger_ground_range.y - 24.0) > 0.01:
			_fail("station %d ground colour zones are not synchronized to the train" % (station_index + 1))
			return
		if not bool(boarding_layout.get_meta("mirrored_ground_layout", false)) \
				or bool(boarding_layout.get_meta("overlapping_surface_layers", true)):
			_fail("station %d platform ground still contains overlapping colour layers" % (station_index + 1))
			return
		for removed_layer_pattern in ["DriverWalkway*", "PassengerWalkway*",
				"*EntranceLanding*", "DriverPathGuide*"]:
			if not boarding_layout.find_children(
					removed_layer_pattern, "MeshInstance3D", false, false).is_empty():
				_fail("station %d still contains redundant ground layer %s" % [
					station_index + 1, removed_layer_pattern])
				return
		var platform_ground := boarding_layout.get_node(
			"SynchronizedPlatformGroundLeft") as MeshInstance3D
		var pixel_floor_material := platform_ground.material_override as StandardMaterial3D
		if pixel_floor_material == null or pixel_floor_material.albedo_texture == null \
				or pixel_floor_material.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST:
			_fail("station %d platform ground lacks its nearest-filtered pixel-art material" % (station_index + 1))
			return
		if String(pixel_floor_material.get_meta("palette_style", "")) \
				!= "rainbow_inlay_gold_frame" \
				or not bool(pixel_floor_material.get_meta("gold_frame", false)) \
				or int(pixel_floor_material.get_meta("rainbow_colour_count", 0)) != 7:
			_fail("station %d platform ground lacks its seven-color inlay and gold frame" % (station_index + 1))
			return
		for ground_side_name in ["SynchronizedPlatformGroundLeft",
				"SynchronizedPlatformGroundRight"]:
			var ground_side := boarding_layout.get_node(ground_side_name) as MeshInstance3D
			var ground_mesh := ground_side.mesh as BoxMesh
			if ground_mesh == null or absf(ground_mesh.size.z - 52.0) > 0.01 \
					or ground_side.material_override != platform_ground.material_override:
				_fail("station %d %s is not a single continuous mirrored surface" % [
					station_index + 1, ground_side_name])
				return
		for synchronized_part_name in ["SynchronizedPlatformGroundLeft",
				"DriverBoardingBridgeLeft", "PassengerBoardingBridgeFrontLeft",
				"PassengerBoardingBridgeLeft", "EntranceToTrainWalkway"]:
			var synchronized_part := boarding_layout.get_node(
				synchronized_part_name) as MeshInstance3D
			if synchronized_part.material_override != platform_ground.material_override:
				_fail("station %d %s does not share the station walking-surface material" % [
					station_index + 1, synchronized_part_name])
				return
		var entrance_walkway := boarding_layout.get_node("EntranceToTrainWalkway") as MeshInstance3D
		var entrance_mesh := entrance_walkway.mesh as BoxMesh
		if entrance_mesh == null \
				or absf(entrance_walkway.position.y + entrance_mesh.size.y * 0.5 - 1.1) > 0.01:
			_fail("station %d entrance walkway is not flush with the platform ground" % (station_index + 1))
			return
		for raised_base_name in ["LeftRaisedBoardingBase", "RightRaisedBoardingBase"]:
			var raised_base := platform_design.get_node(raised_base_name) as MeshInstance3D
			var raised_base_mesh := raised_base.mesh as BoxMesh
			if raised_base_mesh == null or raised_base_mesh.size.z < 51.9:
				_fail("station %d %s does not structurally support the full driver walkway" % [
					station_index + 1, raised_base_name])
				return
		var route_forward: Vector3 = railway.call("get_route_forward_direction_at_station", station_index)
		if (-boarding_layout.basis.z).normalized().dot(route_forward) < 0.999:
			_fail("station %d walkways do not follow the parked train direction" % (station_index + 1))
			return
		for guard_name in ["PlatformGuardLeft", "PlatformGuardRight"]:
			var guard := station.get_node(guard_name) as Node3D
			if String(guard.get_meta("barrier_plan", "")) != "rainbow_glass_gold_frame" \
					or int(guard.get_meta("rainbow_colour_count", 0)) != 7 \
					or not bool(guard.get_meta("gold_frame_layout", false)):
				_fail("station %d %s lacks the rainbow-glass gold-frame barrier plan" % [
					station_index + 1, guard_name])
				return
			var guard_colours := {}
			for rainbow_window in guard.find_children(
					"GlassWindow_*", "MeshInstance3D", true, false):
				guard_colours[int(rainbow_window.get_meta("rainbow_material_index", -1))] = true
				if not bool(rainbow_window.get_meta("gold_frame_layout", false)):
					_fail("station %d %s has a rainbow pane outside the gold frame system" % [
						station_index + 1, guard_name])
					return
			if guard_colours.size() != 7:
				_fail("station %d %s does not use all seven barrier colors" % [
					station_index + 1, guard_name])
				return
			if float(guard.get_meta("train_side_clearance_m", 0.0)) < 0.6:
				_fail("station %d %s barrier is too close to the train machinery" % [
					station_index + 1, guard_name])
				return
			if absf(float(guard.get_meta("platform_front_z", 0.0)) + 28.0) > 0.01:
				_fail("station %d %s does not protect the extended driving walkway" % [
					station_index + 1, guard_name])
				return
			if int(guard.get_meta("shared_connection_post_count", 0)) < 14:
				_fail("station %d %s glass panels are not connected by shared posts" % [
					station_index + 1, guard_name])
				return
			for barrier_name in ["EngineMachineryBarrier", "CoachSeparationBarrier",
					"BetweenPassengerCoachesBarrier",
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
				if String(barrier.get_meta("style", "")) != "rainbow_glass_small_gold_frame" \
						or not bool(barrier.get_meta("gold_frame_layout", false)) \
						or barrier.find_children("GlassWindow_*", "MeshInstance3D", false, false).is_empty() \
						or not barrier.find_children("LowerRail_*", "MeshInstance3D", false, false).is_empty() \
						or not barrier.find_children("UpperRail_*", "MeshInstance3D", false, false).is_empty():
					_fail("station %d %s still uses chaotic rails instead of framed glass" % [
						station_index + 1, barrier_name])
					return
			var driver_clear: Vector2 = guard.get_meta("driver_gate_clear_z")
			var passenger_front_clear: Vector2 = guard.get_meta("passenger_front_gate_clear_z")
			var passenger_rear_clear: Vector2 = guard.get_meta("passenger_rear_gate_clear_z")
			if driver_clear.x >= -15.85 or driver_clear.y <= -15.85 \
					or passenger_front_clear.x >= -8.35 or passenger_front_clear.y <= -8.35 \
					or passenger_rear_clear.x >= 9.75 or passenger_rear_clear.y <= 9.75 \
					or int(guard.get_meta("boarding_gap_count", 0)) != 3:
				_fail("station %d does not leave one driver and two passenger gaps" % (station_index + 1))
				return
			for gap_value in [driver_clear, passenger_front_clear, passenger_rear_clear]:
				if absf((gap_value as Vector2).y - (gap_value as Vector2).x \
						- (7.05 if gap_value == driver_clear else 4.4)) > 0.01:
					_fail("station %d boarding gap edges do not match the train doorway" % (station_index + 1))
					return
			if guard.has_meta("entrance_gate_clear_z"):
				var entrance_clear: Vector2 = guard.get_meta("entrance_gate_clear_z")
				if entrance_clear.y - entrance_clear.x < 7.99 \
						and entrance_clear.x > -15.99 and entrance_clear.y < 23.99:
					_fail("station %d platform glass opening %.2f..%.2f is narrower than the diagonal stair" % [
						station_index + 1, entrance_clear.x, entrance_clear.y])
					return
		if station_index == 1:
			continue
		var skybridge := station.get_node("KingdomAccessSkybridge") as Node3D
		if skybridge.get_node_or_null("AccessEnergyConduit") != null:
			_fail("station %d still contains the diagonal cyan skybridge crossing" % (station_index + 1))
			return
		var station_ground := boarding_layout.get_node(
			"SynchronizedPlatformGroundLeft") as MeshInstance3D
		if String(skybridge.get_meta("walking_surface_style", "")) \
				!= "arcane_pixel_deco_floor_gold_edge":
			_fail("station %d skybridge does not share the platform ground style" % (station_index + 1))
			return
		var expected_bridge_surfaces := ["FloatingAccessDeck", "CentralLumenRamp",
			"CeremonialStep_L_00", "CeremonialStep_R_47"]
		for bridge_surface_name in expected_bridge_surfaces:
			var bridge_surface := skybridge.get_node(bridge_surface_name) as MeshInstance3D
			if bridge_surface.material_override != station_ground.material_override:
				_fail("station %d bridge surface %s does not match the platform ground" % [
					station_index + 1, bridge_surface_name])
				return
		for sky_guard_name in ["SkybridgeGuardLeft", "SkybridgeGuardRight"]:
			var sky_guard := skybridge.get_node_or_null(sky_guard_name) as Node3D
			var expected_barrier_plan := "rainbow_glass_gold_frame"
			if sky_guard == null \
					or String(sky_guard.get_meta("barrier_plan", "")) != expected_barrier_plan \
					or sky_guard.find_children("GlassWindow_*", "MeshInstance3D", true, false).is_empty() \
					or not sky_guard.find_children("SkybridgeRailPost", "MeshInstance3D", true, false).is_empty():
				_fail("station %d skybridge still uses the chaotic rail barrier" % (station_index + 1))
				return
		var access_ramp := station.get_node("AccessRamp") as Node3D
		if access_ramp.get_node_or_null("CrystalEnergyConduit") != null:
			_fail("station %d still contains the diagonal cyan foundation crossing" % (station_index + 1))
			return
		if String(access_ramp.get_meta("walking_surface_style", "")) \
				!= "arcane_pixel_deco_floor_gold_edge":
			_fail("station %d access stairs do not share the platform ground style" % (station_index + 1))
			return
		for stair_surface_name in ["CentralAccessRamp", "DockStep_01",
				"DockStepRight_01"]:
			var stair_surface := access_ramp.get_node(stair_surface_name) as MeshInstance3D
			if stair_surface.material_override != station_ground.material_override:
				_fail("station %d stair surface %s does not match the platform ground" % [
					station_index + 1, stair_surface_name])
				return
		for stair_guard_name in ["StairGuardLeft", "StairGuardRight"]:
			var stair_guard := access_ramp.get_node_or_null(stair_guard_name) as Node3D
			if stair_guard == null \
					or String(stair_guard.get_meta("barrier_plan", "")) != "rainbow_glass_gold_frame" \
					or not bool(stair_guard.get_meta("connected_to_shared_barrier_edges", false)) \
					or stair_guard.find_children("GlassWindow_*", "MeshInstance3D", true, false).is_empty():
				_fail("station %d stair barrier is not connected edge-to-edge" % (station_index + 1))
				return
			var shared_finish: Vector3 = stair_guard.get_meta("shared_finish")
			shared_finish = access_ramp.transform * shared_finish
			var gateway_a: Vector3 = station.get_meta("shared_barrier_gateway_a")
			var gateway_b: Vector3 = station.get_meta("shared_barrier_gateway_b")
			if minf(shared_finish.distance_to(gateway_a),
					shared_finish.distance_to(gateway_b)) > 0.01:
				_fail("station %d stair glass does not finish on a platform barrier edge" % (station_index + 1))
				return
		if not access_ramp.find_children("StairRailPost", "MeshInstance3D", true, false).is_empty() \
				or not access_ramp.find_children("InnerRampGuard*", "MeshInstance3D", true, false).is_empty():
			_fail("station %d still contains bare rails crossing the glass junction" % (station_index + 1))
			return
		if station.get_node_or_null("DestinationWheel") != null \
				or not station.find_children("WheelSpoke", "MeshInstance3D", true, false).is_empty():
			_fail("station %d still contains the redundant destination disc or floor spokes" % (station_index + 1))
			return
		var pavilion := station.get_node_or_null("BioMagitechPavilion") as Node3D
		if pavilion == null:
			_fail("station %d lacks its established bio-magitech pavilion" % (station_index + 1))
			return
		if not pavilion.find_children(
				"PlatformCircuit_*", "MeshInstance3D", false, false).is_empty():
			_fail("station %d still has a loose cyan circuit crossing the bridge view" % (station_index + 1))
			return
		var canopy := pavilion.get_node_or_null("LivingCrystalCanopy") as Node3D
		if canopy == null or canopy.find_children("SolarGlassPetal_*", "MeshInstance3D", true, false).size() != 12:
			_fail("station %d does not have its original twelve-leaf roof" % (station_index + 1))
			return
		var roof_colours := {}
		for roof_petal in canopy.find_children(
				"SolarGlassPetal_*", "MeshInstance3D", true, false):
			roof_colours[int(roof_petal.get_meta("rainbow_material_index", -1))] = true
			if not bool(roof_petal.get_meta("gold_edge_frame", false)):
				_fail("station %d rainbow roof petal is missing its gold edge frame" % (station_index + 1))
				return
		if roof_colours.size() != 7:
			_fail("station %d roof does not use all seven rainbow colors" % (station_index + 1))
			return
		if not canopy.visible \
				or not bool(canopy.get_meta("restored_old_station_roof", false)):
			_fail("station %d original roof is not visible" % (station_index + 1))
			return
		var roof_supports := pavilion.get_node_or_null("BranchingSupportColumns") as Node3D
		if roof_supports == null \
				or roof_supports.find_children(
					"LivingColumn_*", "MeshInstance3D", false, false).size() != 4 \
				or roof_supports.find_children(
					"RoofBearingBeam_*", "MeshInstance3D", false, false).size() != 4 \
				or not bool(roof_supports.get_meta("centre_supports_removed", false)) \
				or not bool(roof_supports.get_meta("canopy_bearing_connected", false)):
			_fail("station %d is missing its bio-magitech structural system" % (station_index + 1))
			return
		if pavilion.get_node_or_null("CanopyEnergyRing") != null:
			_fail("station %d still has the ring at the roof junction" % (station_index + 1))
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
	var second_car := railway.get_node("RainbowGalaxyTrain/Carriage_02") as Node3D
	var engine := railway.get_node("RainbowGalaxyTrain/MiloEngine") as Node3D
	if not train is AnimatableBody3D or (train as AnimatableBody3D).sync_to_physics:
		_fail("complete train is not one script-driven moving platform")
		return
	var platform := train as AnimatableBody3D
	if platform.collision_layer != 1 or platform.collision_mask != 1 \
			or String(platform.get_meta("mass_model", "")) != "infinite_mass_moving_platform" \
			or platform.find_children("*", "CollisionShape3D", false, false).size() < 30:
		_fail("train platform lacks complete solid collision or infinite-mass metadata")
		return
	# The single centre bench is now two side benches with a walkable aisle
	# between them, so the coach can be crossed on foot instead of climbed over.
	for train_part in ["PassengerDeck", "CoachRoofWalkway",
			"CoachGuardLeft_Front", "CoachGuardRight_Front", "CoachGuardRight_Rear",
			"DriverCabStepLeft", "DriverCabStepRight", "JumpBenchLeft",
			"JumpBenchRight", "DriverConsole", "DriverControls"]:
		if first_car.get_node_or_null(train_part) == null:
			_fail("rideable train lacks %s" % train_part)
			return
	for engine_part in ["EngineFrontMachineryCollision", "EngineCabRearBulkheadLeft",
			"EngineCabRearBulkheadRight",
			"EngineCabWalkableFloor", "EngineCabWalkableRoof"]:
		if engine.get_node_or_null(engine_part) == null:
			_fail("engine cab lacks aligned walk-in collision part %s" % engine_part)
			return
	if engine.get_node_or_null("EngineBody") != null:
		_fail("the old solid engine collision still blocks the driver doorway")
		return
	var passenger_entrances := train.get_node("PassengerBoardingEntrances") as Node3D
	for entrance_part in ["EngineCoachConnectorFloor",
			"PassengerFrontEntranceStepLeft", "PassengerFrontEntranceStepRight",
			"PassengerRearEntranceStepLeft", "PassengerRearEntranceStepRight"]:
		if passenger_entrances.get_node_or_null(entrance_part) == null:
			_fail("train lacks aligned passenger connector part %s" % entrance_part)
			return
	var first_step := passenger_entrances.get_node(
		"PassengerFrontEntranceStepLeft") as MeshInstance3D
	var second_step := passenger_entrances.get_node(
		"PassengerRearEntranceStepLeft") as MeshInstance3D
	var driver_step := first_car.get_node("DriverCabStepLeft") as MeshInstance3D
	if absf(first_step.position.z + 8.35) > 0.01 \
			or absf(second_step.position.z - 9.75) > 0.01 \
			or absf(first_car.position.z + driver_step.position.z + 15.85) > 0.01:
		_fail("train walk-in steps do not align with the three station gaps")
		return
	if driver_step.material_override != first_step.material_override:
		_fail("driver and passenger train steps do not share the station ground material")
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
			"star_of_wisdom": true,
			"harmony_jewel": true,
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
