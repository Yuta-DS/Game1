extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CROWN_LINE_WEB_PERFORMANCE_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)
	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	await process_frame
	await physics_frame
	await physics_frame
	var summary: Dictionary = railway.call("get_station_performance_summary")
	print("CROWN_LINE_WEB_PERFORMANCE_METRICS: %s" % JSON.stringify(summary))
	if not bool(summary.web_profile_active):
		_fail("test must run with ARTEA_FORCE_WEB_STATION_LOD=1")
		return
	if int(summary.profiled_station_count) != 4:
		_fail("all four stations must use the Web performance profile")
		return
	if int(summary.total_station_geometry) <= 0 \
			or int(summary.range_limited_geometry) != int(summary.total_station_geometry):
		_fail("every station geometry instance must be distance-capped on Web")
		return
	if int(summary.shadowless_geometry) != int(summary.total_station_geometry):
		_fail("station geometry still submits static shadow passes on Web")
		return
	if int(summary.source_station_meshes) < 2000 \
			or int(summary.batched_station_meshes) > 96 \
			or int(summary.preserved_palette_meshes) != 104 \
			or int(summary.total_station_geometry) > 224:
		_fail("station render geometry was not consolidated into the Web draw-call budget")
		return
	if float(summary.visibility_range_m) > 600.0 \
			or int(summary.max_simultaneous_station_complexes) != 1:
		_fail("Web may render more than one complete station complex at a time")
		return
	var stations := railway.get_node("StoryStations") as Node3D
	for station_candidate in stations.get_children():
		var station := station_candidate as Node3D
		if String(station.get_meta("web_performance_profile", "")) \
				!= "single_nearby_station_shadowless" \
				or station.process_mode != Node.PROCESS_MODE_INHERIT:
			_fail("%s is not static and Web-profiled" % station.name)
			return
		for collision_path in [
				"WalkablePlatform/LeftStructuralDeckCollision",
				"WalkablePlatform/RightStructuralDeckCollision",
				"WalkablePlatform/LeftRaisedBoardingBaseCollision",
				"WalkablePlatform/RightRaisedBoardingBaseCollision",
				"BoardingLane/DriverBoardingBridgeLeftCollision",
				"BoardingLane/PassengerBoardingBridgeRightCollision",
				"AccessRamp/WalkableStairRampCollision"]:
			if station.get_node_or_null(collision_path) == null:
				_fail("%s lost Web gameplay collision %s during batching" % [
					station.name, collision_path])
				return
		# Node existence alone missed disabled station physics on Web. Probe the
		# actual long bridge surface, away from any overlapping island floor.
		var ramp := station.get_node("AccessRamp/WalkableStairRampCollision") as StaticBody3D
		var ramp_shape := ramp.get_child(0) as CollisionShape3D
		var faces := (ramp_shape.shape as ConcavePolygonShape3D).get_faces()
		var surface := ramp_shape.to_global((faces[0] + faces[1] + faces[2]) / 3.0)
		var query := PhysicsRayQueryParameters3D.create(surface + Vector3.UP * 2.0,
			surface - Vector3.UP * 2.0, 1)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider != ramp:
			_fail("%s stair collision is not active in Web physics" % station.name)
			return
	print(("CROWN_LINE_WEB_PERFORMANCE_TEST: PASS — %d source meshes reduced to " \
		+ "%d batches plus %d palette meshes; %d total instances are range-capped") \
		% [int(summary.source_station_meshes), int(summary.batched_station_meshes),
			int(summary.preserved_palette_meshes),
			int(summary.total_station_geometry)])
	quit()
