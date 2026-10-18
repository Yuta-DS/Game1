extends SceneTree

## Every station's track overpass: the player stands at each point up both
## ramps and across the deck, so either platform leads off without crossing
## the train.


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("STATION_OVERPASS_TEST: %s" % message)
	quit(1)


## Feet height (relative to the player origin) after settling at `point`.
func _settle(player: CharacterBody3D, point: Vector3) -> float:
	player.global_position = point + Vector3.UP * 1.5
	player.velocity = Vector3.ZERO
	for _i in 30:
		await physics_frame
	return player.global_position.y if player.is_on_floor() else -INF


func _run() -> void:
	var world := (load("res://scenes/art_castle_floating_world.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(world)
	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	await process_frame
	await process_frame
	var player := world.get_node("Player3D") as CharacterBody3D
	player.call("set_input_enabled", false)
	var stations := railway.find_children("Station_*", "Node3D", false, false)
	if stations.size() != 4:
		stations = railway.get_node("StoryStations").get_children()
	for station in stations:
		var lane := station.get_node_or_null("BoardingLane") as Node3D
		if lane == null or lane.get_node_or_null("TrackOverpass") == null:
			_fail("%s has no track overpass" % station.name)
			return
		# Origin height above the floor, measured on the platform itself.
		var platform_y := await _settle(player, lane.to_global(Vector3(9.45, 1.1, 20.0)))
		if platform_y == -INF:
			_fail("%s: player not standing on the platform" % station.name)
			return
		var origin_offset := platform_y - lane.to_global(Vector3(9.45, 1.1, 20.0)).y
		var points := []
		for side in [-1.0, 1.0]:
			for t in [0.1, 0.5, 0.9]:
				points.append(Vector3(side * 9.45, lerpf(1.1, 16.0, t), lerpf(24.0, 72.0, t)))
		for x in [-9.0, 0.0, 9.0]:
			points.append(Vector3(x, 16.0, 74.0))
		for local_point in points:
			var expected: float = lane.to_global(local_point).y + origin_offset
			var y := await _settle(player, lane.to_global(local_point))
			if absf(y - expected) > 0.5:
				_fail("%s: no walkable overpass at %s (stood at %.2f, expected %.2f)"
					% [station.name, local_point, y, expected])
				return
		# Walk off the deck and down each ramp onto its platform. Station stair
		# rails once crossed an angled far platform and blocked this exit.
		for side in [-1.0, 1.0]:
			await _settle(player, lane.to_global(Vector3(0.0, 16.0, 74.0)))
			for leg in [Vector3(side * 9.45, 16.0, 74.0), Vector3(side * 9.45, 16.0, 70.0),
					Vector3(side * 9.45, 1.1, 8.0)]:
				await _walk(player, lane.to_global(leg))
			var reached := lane.to_local(player.global_position)
			if Vector2(reached.x, reached.z).distance_to(Vector2(side * 9.45, 8.0)) > 1.0:
				_fail("%s: walking down the %s overpass ramp stopped at %s"
					% [station.name, "left" if side < 0 else "right", reached])
				return
	print("STATION_OVERPASS_TEST: PASS - 4 stations, both ramps and deck walkable, both exits open")
	quit(0)


## Drives the real CharacterBody3D towards `target` across the ground.
func _walk(player: CharacterBody3D, target: Vector3) -> void:
	for _step in 600:
		var to_target := target - player.global_position
		to_target.y = 0.0
		if to_target.length() < 0.5:
			return
		player.velocity = to_target.normalized() * 6.0 + Vector3.DOWN * 4.0
		player.move_and_slide()
		await physics_frame
