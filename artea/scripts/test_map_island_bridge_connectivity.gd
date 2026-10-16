extends SceneTree

const WorldOneScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const PlayerScene := preload("res://scenes/player_3d.tscn")
const FloatingWorldScene := preload("res://scenes/art_castle_floating_world.tscn")
const RegionsScript := preload("res://scripts/art_castle_kingdom_regions.gd")
const WALK_SPEED := 15.0


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MAP_ISLAND_BRIDGE_CONNECTIVITY: %s" % message)
	quit(1)


func _run() -> void:
	if not await _check_world_one_three_island_route():
		return
	if not await _check_observatory_twins():
		return
	if not await _check_kingdom_shelf_grids():
		return
	print("MAP_ISLAND_BRIDGE_CONNECTIVITY: PASS — Island One tree bridge restored; " \
		+ "2 observatory twin pairs; retired South and West lookouts absent; " \
		+ "120 shelf bridges with >=2 routes/island; " \
		+ "steepest legal shelf bridge walked by production player")
	quit()


func _check_world_one_three_island_route() -> bool:
	var world := WorldOneScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	root.add_child(world)
	for _frame in 4:
		await physics_frame
	var route := world.get_node("WorldOneGeometry/MainStoryCircuitRoute") as Node3D
	if bool(route.get_meta("ring_closed", true)):
		_fail("World One still has the obsolete sixth external bridge")
		return false
	if int(route.get_meta("physical_island_count", 0)) != 3 \
			or int(route.get_meta("external_bridge_count", 0)) != 2:
		_fail("World One does not expose three physical islands and both sky bridges")
		return false
	if PackedStringArray(route.get_meta("internal_promenade_pairs", [])).size() != 3:
		_fail("World One does not retain the three required paired-district promenades")
		return false
	for link_index in range(1, 6):
		if link_index == 1:
			if route.get_node_or_null("CircuitRoute_01_A") != null \
					or world.get_island_one_heavenly_star_gate() == null:
				_fail("World One route 01 must use its fused foundation and Heavenly Star Gate")
				return false
			continue
		var expected_kind := "internal_promenade" if link_index % 2 == 1 else "external_sky_bridge"
		for leg in ["A", "B"]:
			var deck := route.get_node_or_null("CircuitRoute_%02d_%s" % [link_index, leg]) as MeshInstance3D
			if deck == null or route.get_node_or_null("CircuitRoute_%02d_%sCollision" % [link_index, leg]) == null:
				_fail("World One route %d%s lacks walkable collision" % [link_index, leg])
				return false
			if str(deck.get_meta("route_kind", "")) != expected_kind:
				_fail("World One route %d%s has the wrong structural role" % [link_index, leg])
				return false
	world.queue_free()
	await process_frame
	return true


func _check_observatory_twins() -> bool:
	var world := FloatingWorldScene.instantiate() as Node3D
	root.add_child(world)
	for _frame in 4:
		await physics_frame
	for base_name in ["NorthObservatoryBridge", "EastObservatoryBridge"]:
		var left := world.get_node_or_null(base_name) as Node3D
		var right := world.get_node_or_null("%sTwin" % base_name) as Node3D
		if left == null or right == null:
			_fail("%s does not have its mirrored companion" % base_name)
			return false
		if left.get_node_or_null("WalkwayCollision") == null \
				or right.get_node_or_null("WalkwayCollision") == null:
			_fail("%s twin pair lacks walkable collision" % base_name)
			return false
		var left_start: Vector3 = left.get_meta("connection_start")
		var right_start: Vector3 = right.get_meta("connection_start")
		var left_finish: Vector3 = left.get_meta("connection_finish")
		var right_finish: Vector3 = right.get_meta("connection_finish")
		if not is_equal_approx(left_start.distance_to(right_start), 36.0) \
				or not is_equal_approx(left_finish.distance_to(right_finish), 36.0):
			_fail("%s endpoints are not exact 18 m mirrors" % base_name)
			return false
		var left_walkway := left.get_node("Walkway") as MeshInstance3D
		var right_walkway := right.get_node("Walkway") as MeshInstance3D
		# Within 5 cm of the island top: the walkway sits 2 cm low on purpose so
		# it does not z-fight with the island deck it starts on.
		if absf(left_walkway.position.y + 2.0) > 0.05 \
				or absf(right_walkway.position.y + 2.0) > 0.05:
			_fail("%s decks do not share the island top plane" % base_name)
			return false
	if world.get_node_or_null("WestObservatory") != null \
			or world.get_node_or_null("WestObservatoryBridge") != null \
			or world.get_node_or_null("WestObservatoryBridgeTwin") != null:
		_fail("retired West Observatory geometry still participates in the island map")
		return false
	if world.get_node_or_null("SouthObservatory") != null \
			or world.get_node_or_null("SouthObservatoryBridge") != null \
			or world.get_node_or_null("SouthObservatoryBridgeTwin") != null:
		_fail("retired South watchtower geometry still participates in the island map")
		return false
	world.queue_free()
	await process_frame
	return true


func _check_kingdom_shelf_grids() -> bool:
	var stage := Node3D.new()
	root.add_child(stage)
	var regions := Node3D.new()
	regions.set_script(RegionsScript)
	stage.add_child(regions)
	for _frame in 5:
		await physics_frame
	var steepest: Node3D
	var steepest_slope := -1.0
	for kingdom_name in ["MindKingdom3000m", "HeartKingdom3000m", "CreatorKingdom3000m"]:
		var grid := regions.get_node("%s/OptimizedLandmass/InterIslandBridgeGrid" % kingdom_name) as Node3D
		if int(grid.get_meta("bridge_count", 0)) != 40:
			_fail("%s does not have all 40 adjacent-shelf bridges" % kingdom_name)
			return false
		var degrees := {}
		for row in 5:
			for column in 5:
				degrees[Vector2i(column, row)] = 0
		for bridge in grid.get_children():
			var bridge_node := bridge as Node3D
			var chunk_a: Vector2i = bridge_node.get_meta("chunk_a")
			var chunk_b: Vector2i = bridge_node.get_meta("chunk_b")
			degrees[chunk_a] += 1
			degrees[chunk_b] += 1
			var slope := float(bridge_node.get_meta("slope_degrees"))
			if slope > 18.001:
				_fail("%s exceeds the 18-degree walk limit at %.3f degrees" % [bridge_node.name, slope])
				return false
			if slope > steepest_slope:
				steepest_slope = slope
				steepest = bridge_node
			for segment_name in ["StartLanding", "SlopeSpan", "FinishLanding"]:
				var deck := bridge_node.get_node_or_null(segment_name) as MeshInstance3D
				if deck == null or bridge_node.get_node_or_null("%sCollision" % segment_name) == null:
					_fail("%s %s lacks deck or collision" % [bridge_node.name, segment_name])
					return false
			var left_rail := bridge_node.get_node_or_null("LeftSafetyRail") as MeshInstance3D
			var right_rail := bridge_node.get_node_or_null("RightSafetyRail") as MeshInstance3D
			if left_rail == null or right_rail == null \
					or bridge_node.get_node_or_null("LeftSafetyRailCollision") == null \
					or bridge_node.get_node_or_null("RightSafetyRailCollision") == null:
				_fail("%s lacks its continuous mirrored guard pair" % bridge_node.name)
				return false
			var rail_midpoint := left_rail.position.lerp(right_rail.position, 0.5)
			var bridge_midpoint := (bridge_node.get_meta("walk_start") as Vector3).lerp(
				bridge_node.get_meta("walk_finish") as Vector3, 0.5)
			if not Vector2(rail_midpoint.x, rail_midpoint.z).is_equal_approx(
					Vector2(bridge_midpoint.x, bridge_midpoint.z)) \
					or not is_equal_approx(left_rail.position.y, right_rail.position.y):
				_fail("%s guards are not exact mirrors" % bridge_node.name)
				return false
		for chunk in degrees:
			if int(degrees[chunk]) < 2:
				_fail("%s shelf %s has only %d bridges" % [kingdom_name, chunk, degrees[chunk]])
				return false
	if steepest == null or not await _walk_bridge_with_production_player(stage, steepest):
		return false
	stage.queue_free()
	await process_frame
	return true


func _walk_bridge_with_production_player(stage: Node3D, bridge: Node3D) -> bool:
	var player := PlayerScene.instantiate() as CharacterBody3D
	stage.add_child(player)
	for _frame in 3:
		await physics_frame
	player.set_physics_process(false)
	var start: Vector3 = bridge.get_meta("walk_start")
	var finish: Vector3 = bridge.get_meta("walk_finish")
	var capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	var stand_height := capsule.height * 0.5 + 0.2
	player.global_position = start + Vector3.UP * stand_height
	player.velocity = Vector3.ZERO
	for _frame in 180:
		player.velocity.y -= 28.0 / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			break
	if not player.is_on_floor():
		_fail("production player cannot stand on steepest shelf bridge %s" % bridge.name)
		return false
	var best_distance := INF
	var stalled := 0
	for _frame in 900:
		var delta := finish - player.global_position
		delta.y = 0.0
		if delta.length() < 1.5:
			player.queue_free()
			return true
		player.velocity.x = delta.normalized().x * WALK_SPEED
		player.velocity.z = delta.normalized().z * WALK_SPEED
		player.velocity.y -= 28.0 / 60.0
		player.move_and_slide()
		await physics_frame
		var remaining := Vector2(delta.x, delta.z).length()
		if remaining < best_distance - 0.01:
			best_distance = remaining
			stalled = 0
		else:
			stalled += 1
		if stalled > 90:
			_fail("production player jammed on steepest shelf bridge %s at %s"
				% [bridge.name, player.global_position])
			return false
	_fail("production player timed out on steepest shelf bridge %s" % bridge.name)
	return false
