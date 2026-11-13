extends SceneTree

const WorldOneScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const FloatingWorldScene := preload("res://scenes/art_castle_floating_world.tscn")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MAP_ISLAND_BRIDGE_CONNECTIVITY: %s" % message)
	quit(1)


func _run() -> void:
	if not await _check_world_one_three_island_route():
		return
	if not await _check_retired_observatory_spans():
		return
	if not await _check_kingdom_shelf_grids():
		return
	print("MAP_ISLAND_BRIDGE_CONNECTIVITY: PASS — Island One tree bridge restored; " \
		+ "North/East lookout spans absent; main Creator route and South/West lookout cleanup retained; " \
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


func _check_retired_observatory_spans() -> bool:
	var world := FloatingWorldScene.instantiate() as Node3D
	root.add_child(world)
	for _frame in 4:
		await physics_frame
	if world.get_node_or_null("NorthObservatoryBridge") != null \
			or world.get_node_or_null("NorthObservatoryBridgeTwin") != null:
		_fail("retired Heart Melody lookout spans still cross the void")
		return false
	var former_span := PhysicsRayQueryParameters3D.create(
		world.to_global(Vector3(-165.0, 20.0, 2443.0)),
		world.to_global(Vector3(-165.0, -20.0, 2443.0)))
	if not world.get_world_3d().direct_space_state.intersect_ray(former_span).is_empty():
		_fail("former Heart Melody lookout span still has collision in the void")
		return false
	if world.get_node_or_null("EastObservatoryBridge") != null \
			or world.get_node_or_null("EastObservatoryBridgeTwin") != null:
		_fail("retired Creator lookout spans still cross the void")
		return false
	for lane_z in [1622.0, 1658.0]:
		var east_span := PhysicsRayQueryParameters3D.create(
			world.to_global(Vector3(825.0, 10.0, lane_z)),
			world.to_global(Vector3(825.0, -20.0, lane_z)))
		if not world.get_world_3d().direct_space_state.intersect_ray(east_span).is_empty():
			_fail("former Creator lookout lane still has collision at z=%.1f" % lane_z)
			return false
	var creator_bridge := world.get_node_or_null("CreatorBridge") as Node3D
	if creator_bridge == null or creator_bridge.get_node_or_null("WalkwayCollision") == null:
		_fail("main Creator bridge was removed with the lookout spans")
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
