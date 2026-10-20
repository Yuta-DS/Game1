extends SceneTree

const WorldOneScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const FloatingWorldScene := preload("res://scenes/art_castle_floating_world.tscn")


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
	print("MAP_ISLAND_BRIDGE_CONNECTIVITY: PASS — World One ring 2 routes/island; 1 observatory twin pair")
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
	if world.get_node_or_null("EastObservatory") != null:
		_fail("east observatory should be gone; the Creator studio stands alone")
		return false
	for base_name in ["WestObservatoryBridge"]:
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
