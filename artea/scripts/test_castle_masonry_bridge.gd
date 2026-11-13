extends "res://scripts/test_castle_rooftop_barrier_safety.gd"


func _fail(message: String) -> void:
	push_error("CASTLE_MASONRY_BRIDGE_TEST: %s" % message)
	quit(1)


func _visible_intersection(stone: MeshInstance3D, faces: PackedVector3Array,
		from: Vector3, to: Vector3) -> Vector3:
	var local_from := stone.to_local(from)
	var local_to := stone.to_local(to)
	var closest := INF
	var result := Vector3(INF, INF, INF)
	for index in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(local_from, local_to,
			faces[index], faces[index + 1], faces[index + 2])
		if hit != null and local_from.distance_to(hit) < closest:
			closest = local_from.distance_to(hit)
			result = stone.to_global(hit)
	return result


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 80:
		await process_frame
		await physics_frame
	var bridge := hub.find_child("CastleMasonryCauseway", true, false) as Node3D
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process_input(false)
	if bridge == null or hub.find_child("CastleTimberCauseway", true, false) != null:
		_fail("masonry bridge did not replace the wooden assembly")
		return
	var stone := bridge.find_child("MasonryBridge", true, false) as MeshInstance3D
	if stone == null or stone.mesh.get_surface_count() != 2:
		_fail("Blender masonry asset is missing its stone/coping surfaces")
		return
	var space := bridge.get_world_3d().direct_space_state
	var faces := stone.mesh.get_faces()
	# Compare rendered triangles with the actual collider, including all four
	# flared end walls. A movement-only test cannot catch mis-rotated visuals.
	for wall_candidate in hub.find_children("CausewaySafetyWall_*", "MeshInstance3D", true, false):
		var wall := wall_candidate as MeshInstance3D
		var size := (wall.mesh as BoxMesh).size
		for fraction: float in [-0.4, 0.0, 0.4]:
			var centre := wall.to_global(Vector3(0, 0, size.z * fraction))
			var from := centre + wall.global_basis.x * 0.5
			var to := centre - wall.global_basis.x * 0.5
			var query := PhysicsRayQueryParameters3D.create(from, to)
			# Compare this wall only; its outside meets the crown's rounded post.
			# Movement checks below still use every collider in the real world.
			var excluded: Array[RID] = []
			for candidate in hub.find_children("*", "CollisionObject3D", true, false):
				if not wall.is_ancestor_of(candidate):
					excluded.append((candidate as CollisionObject3D).get_rid())
			query.exclude = excluded
			var physical := space.intersect_ray(query)
			var visual := _visible_intersection(stone, faces, from, to)
			if physical.is_empty() or not visual.is_finite() \
					or visual.distance_to(physical.position) > 0.035:
				_fail("visual/solid wall misalignment at %s fraction %.1f visual=%s physics=%s centre=%s" % [
					wall.name, fraction, visual, physical, centre])
				return
	# Sample paver centres, not the intentionally recessed 12 mm mortar joints.
	for lateral: float in [-1.2, 0.4, 1.2]:
		var target := bridge.to_global(Vector3(lateral, 0.22, 0.1))
		var visual := _visible_intersection(stone, faces, target + Vector3.UP, target - Vector3.UP)
		if not visual.is_finite() or absf(visual.y - target.y) > 0.003:
			_fail("rendered paver differs from the support datum: visual=%s target=%s" % [visual, target])
			return
	# Test every lane in both directions, including roof and court transitions.
	for lateral: float in [-1.5, 0.0, 1.5]:
		for direction: float in [-1.0, 1.0]:
			if not await _settle(player, bridge.to_global(Vector3(lateral, 2.0, -direction * 4.2))):
				_fail("player could not stand on masonry bridge")
				return
			for station in 12:
				var z := direction * lerpf(-4.2, 4.2, float(station) / 11.0)
				var target := bridge.to_global(Vector3(lateral, 0.22, z))
				if not await _walk_to(player, target):
					_fail("player stuck on masonry bridge lane %.1f at %s" % [lateral, target])
					return
				var query := PhysicsRayQueryParameters3D.create(target + Vector3.UP, target - Vector3.UP)
				query.exclude = [player.get_rid()]
				var hit := space.intersect_ray(query)
				if hit.is_empty() or absf(hit.position.y - target.y) > 0.05 \
						or absf(player.global_position.y - hit.position.y) > 0.07:
					_fail("masonry surface/support/feet mismatch at %s player=%s hit=%s" % [target,player.global_position,hit])
					return
	# Both core parapets must stop a sprint and release the player back inward.
	for lateral: float in [-1.0, 1.0]:
		for z: float in [-2.5, 0.0, 2.5]:
			var start := bridge.to_global(Vector3(lateral * 1.3, 2.0, z))
			if not await _settle(player, start):
				_fail("guard test could not reach deck")
				return
			var outward := bridge.global_basis * Vector3(lateral, 0, 0)
			await _run_direction(player, outward, 24)
			if absf(bridge.to_local(player.global_position).x) > 2.45 \
					or player.global_position.y < bridge.global_position.y + 0.17:
				_fail("player passed through masonry parapet")
				return
			if not await _walk_to(player, start):
				_fail("player stuck after striking masonry parapet")
				return
	print("CASTLE_MASONRY_BRIDGE_TEST: PASS — 3 lanes both ways; 72 floor/feet probes; 6 sprint impacts and escapes")
	quit(0)
