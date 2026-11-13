extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 8:
		await process_frame
	await physics_frame
	var floating_world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var player := gallery.get_node("Player3D") as CharacterBody3D
	var world := floating_world.get_node("MindSparkWorldOne") as MindSparkWorldOne
	var gate_route_points := [
		Vector3(0, 8, 505), Vector3(0, 8, 760), Vector3(0, 8, 960),
		Vector3(0, 8, 1200), Vector3(0, 8, 1420), Vector3(-120, 8, 1535),
		Vector3(-215, 8, 1640), Vector3(-325, 8, 1640), Vector3(-430, 8, 1640),
		Vector3(-692, 8, 1544),
	]
	var space := floating_world.get_world_3d().direct_space_state
	for local_point in gate_route_points:
		var point := floating_world.to_global(local_point)
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 20, point + Vector3.DOWN * 30)
		query.collision_mask = 1
		if space.intersect_ray(query).is_empty():
			_fail("gallery-to-gate route has solid ground at %s" % local_point)
			return
	var source_gate := floating_world.get_node("MindSparkWorldGate") as MindSparkWorldGate
	if not source_gate.teleport_player(player):
		_fail("the Art Castle source gate refused the player")
		return
	if player.global_position.distance_to(floating_world.to_global(source_gate.destination_world_local)) >= 0.25:
		_fail("the source gate did not land at Zone 01")
		return
	for zone_id in world.get_zone_ids():
		var zone := world.get_node("WorldOneGeometry/%s" % zone_id.to_pascal_case()) as Node3D
		if not zone.get_node("WalkableZoneFloorCollision") is StaticBody3D:
			_fail("%s does not retain a physical floor" % zone_id)
			return
	var route := world.get_node("WorldOneGeometry/MainStoryCircuitRoute") as Node3D
	if _story_route_collision_count(route) != 8:
		_fail("four retained links need eight collision-backed legs; route 01 uses its fused foundation")
		return
	var return_gate := world.get_node("WorldOneGeometry/01WorldGateLanding/EntryWorldGate") as MindSparkWorldGate
	if not return_gate.teleport_player(player):
		_fail("the Zone 01 abort gate refused the player")
		return
	if player.global_position.distance_to(floating_world.to_global(Vector3(-650, 7, 1575))) >= 0.25:
		_fail("the abort gate did not use the safe forecourt return landing")
		return
	print("MindSparkGalaxyTraversal: PASS — solid forecourt reaches gate; three-island route enters and returns")
	quit()


func _story_route_collision_count(route: Node3D) -> int:
	var count := 0
	for link_index in range(1, 6):
		for leg in ["A", "B"]:
			if route.get_node_or_null("CircuitRoute_%02d_%sCollision" % [link_index, leg]) is StaticBody3D:
				count += 1
	return count


func _fail(message: String) -> void:
	push_error("MIND_SPARK_GALAXY_TRAVERSAL: %s" % message)
	quit(1)
