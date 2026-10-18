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
	if not await _check_world_one_ring():
		return
	if not await _check_observatory_twins():
		return
	if not await _check_kingdom_shelf_grids():
		return
	print("MAP_ISLAND_BRIDGE_CONNECTIVITY: PASS — World One ring 2 routes/island; " \
		+ "3 observatory twin pairs; 40 Mind shelf bridges with >=2 routes/island; " \
		+ "steepest legal shelf bridge walked by production player")
	quit()


func _check_world_one_ring() -> bool:
	var world := WorldOneScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	root.add_child(world)
	for _frame in 4:
		await physics_frame
	var route := world.get_node("WorldOneGeometry/MainStoryCircuitRoute") as Node3D
	if not bool(route.get_meta("ring_closed", false)):
		_fail("World One route is still an open chain")
		return false
	var degrees := {}
	for zone_id in world.get_zone_ids():
		degrees[zone_id] = 0
	for encoded in PackedStringArray(route.get_meta("connection_pairs", [])):
		var pair := encoded.split(">")
		degrees[pair[0]] += 1
		degrees[pair[1]] += 1
	for zone_id in degrees:
		if int(degrees[zone_id]) < 2:
			_fail("World One island %s has only %d physical route links" % [zone_id, degrees[zone_id]])
			return false
	for leg in ["A", "B", "C"]:
		var deck := route.get_node_or_null("CircuitRoute_06_%s" % leg) as MeshInstance3D
		if deck == null or route.get_node_or_null("CircuitRoute_06_%sCollision" % leg) == null:
			_fail("World One ring closure leg %s is missing walkable collision" % leg)
			return false
	var start_deck := route.get_node("CircuitRoute_06_A") as MeshInstance3D
	var finish_deck := route.get_node("CircuitRoute_06_C") as MeshInstance3D
	if not is_equal_approx(float(start_deck.get_meta("walk_surface_start_y")),
			world.get_zone_position("06_oldest_tree_sanctuary").y):
		_fail("World One closure is not coplanar with the sanctuary")
		return false
	if not is_equal_approx(float(finish_deck.get_meta("walk_surface_finish_y")),
			world.get_zone_position("01_world_gate_landing").y):
		_fail("World One closure is not coplanar with the arrival island")
		return false
	world.queue_free()
	await process_frame
	return true


func _check_observatory_twins() -> bool:
	var world := FloatingWorldScene.instantiate() as Node3D
	root.add_child(world)
	for _frame in 4:
		await physics_frame
	if world.get_node_or_null("SouthObservatory") != null:
		_fail("south observatory still stands inside the arrival island")
		return false
	for base_name in ["WestObservatoryBridge", "NorthObservatoryBridge",
			"EastObservatoryBridge"]:
		var left := world.get_node_or_null(base_name) as Node3D
		var right := world.get_node_or_null("%sTwin" % base_name) as Node3D
		if left == null or right == null:
			_fail("%s does not have its mirrored companion" % base_name)
			return false
		# The West lookout's railed bridges use the causeway's deck, whose top
		# sits 0.6 m above the islands with threshold steps at both ends.
		var walkway_name := "ContinuousWalkway" if base_name == "WestObservatoryBridge" else "Walkway"
		if left.get_node_or_null("%sCollision" % walkway_name) == null \
				or right.get_node_or_null("%sCollision" % walkway_name) == null:
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
		var left_walkway := left.get_node(walkway_name) as MeshInstance3D
		var right_walkway := right.get_node(walkway_name) as MeshInstance3D
		# Within 5 cm of the island top: the walkway sits 2 cm low on purpose so
		# it does not z-fight with the island deck it starts on.
		var expected_y := 0.0 if base_name == "WestObservatoryBridge" else -2.0
		if absf(left_walkway.position.y - expected_y) > 0.05 \
				or absf(right_walkway.position.y - expected_y) > 0.05:
			_fail("%s decks do not share the island top plane" % base_name)
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
	for kingdom_name in ["MindKingdom3000m"]:
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
