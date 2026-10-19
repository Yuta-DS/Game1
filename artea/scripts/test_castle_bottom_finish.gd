extends "res://scripts/test_castle_stair_keep_details.gd"

func _fail(message: String) -> void:
	push_error("CASTLE_BOTTOM_FINISH_TEST: " + message)
	quit(1)

func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for frame in 90:
		await process_frame
		await physics_frame
	var stair := hub.get_node("CastleStairs/CastleStair") as Node3D
	var entry := stair.get_node("GroundedCastleEntry") as Node3D
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process_input(false)
	var start: Vector3 = entry.get_meta("surface_start")
	var end: Vector3 = entry.get_meta("surface_end")
	var forward := (end - start).normalized()
	forward.y = 0
	forward = forward.normalized()
	var radial := Vector3(forward.z, 0, -forward.x)
	var floor_mesh := entry.get_node("GroundEntryWalkSurface") as MeshInstance3D
	if not floor_mesh.material_override is ShaderMaterial or not floor_mesh.get_meta("floor_edges_seated_in_masonry", false):
		_fail("entrance floor is not one flush patterned surface")
		return
	if not (floor_mesh.material_override as ShaderMaterial).get_shader_parameter("paving"):
		_fail("entrance paving pattern is not enabled")
		return
	if absf((floor_mesh.mesh as BoxMesh).size.x - Stair.ENTRY_FLOOR_WIDTH) > 0.001 \
			or Stair.ENTRY_FLOOR_INNER > Stair.INNER_BARRIER_LANE_FACE_RADIUS \
			or Stair.ENTRY_FLOOR_OUTER < Stair.OUTER_BARRIER_INNER_RADIUS:
		_fail("visible floor still leaves slots beside the walls")
		return
	var space := stair.get_world_3d().direct_space_state
	# Compare physics to the rendered slab's actual top plane, not its metadata
	# or box centre. This guards against the original feet-below-floor defect.
	var floor_top := floor_mesh.global_transform * Vector3(0, (floor_mesh.mesh as BoxMesh).size.y * 0.5, 0)
	var floor_normal := floor_mesh.global_basis.y.normalized()
	var floor_body := entry.get_node("GroundEntryWalkCollision")
	for t: float in [0.12, 0.50, 0.87]:
		for lane: float in [-0.75, 0.0, 0.75]:
			var point := start.lerp(end, t) + radial * lane
			var visible_y := floor_top.y - (floor_normal.x * (point.x - floor_top.x) \
				+ floor_normal.z * (point.z - floor_top.z)) / floor_normal.y
			var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, visible_y + 0.5, point.z),
				Vector3(point.x, visible_y - 0.5, point.z))
			query.exclude = [player.get_rid()]
			var floor_hit := space.intersect_ray(query)
			if not floor_hit.has("collider") or not floor_body.is_ancestor_of(floor_hit["collider"]) \
					or absf((floor_hit["position"] as Vector3).y - visible_y) > 0.015:
				_fail("rendered floor and supporting collision do not agree")
				return
	var impacts := 0
	for side: String in ["Inner", "Outer"]:
		var wall := entry.get_node("GroundEntry%sBarrier" % side) as MeshInstance3D
		if wall.find_children("*", "CollisionShape3D", true, false).size() != 1 or wall.mesh.get_surface_count() != 2:
			_fail("wall/coping must share one closed collider")
			return
		var direction := radial * (-1 if side == "Inner" else 1)
		for t: float in [0.12, 0.50, 0.87]:
			var centre := start.lerp(end, t)
			var ray := PhysicsRayQueryParameters3D.create(centre + Vector3.UP * 0.65,
				centre + Vector3.UP * 0.65 + direction * 3.0)
			ray.exclude = [player.get_rid()]
			var hit := space.intersect_ray(ray)
			if not hit.has("collider") or not wall.is_ancestor_of(hit["collider"]):
				_fail("wall is not solid at approach sample %s/%s" % [side, t])
				return
			if not await _settle(player, centre + Vector3.UP * 2.0):
				_fail("player cannot stand on entrance floor")
				return
			var floor_y := player.global_position.y
			await _run_direction(player, direction, 32)
			var offset := (player.global_position - centre).dot(direction)
			if offset > 1.45 or absf(player.global_position.y - floor_y) > 0.35:
				_fail("player crossed or sank through entrance wall: %s/%s at %s" % [side, t, player.global_position])
				return
			if not await _walk_to(player, player.global_position - direction * 0.85):
				_fail("player stuck after entrance wall contact")
				return
			impacts += 1
	var capitals := entry.find_children("GroundEntryPierCapital_*", "MeshInstance3D", true, false)
	if capitals.size() != 2 or absf(capitals[0].global_position.y - capitals[1].global_position.y) > 0.001:
		_fail("entrance capitals are not aligned")
		return
	for name: String in ["GroundEntryStoneNewel_Left", "GroundEntryStoneNewel_Right", "GroundEntryRedRoof_Left", "GroundEntryRedRoof_Right"]:
		var part := entry.get_node(name) as MeshInstance3D
		if part.find_children("*", "CollisionShape3D", true, false).is_empty():
			_fail("entrance post/roof lacks collision")
			return
		var bounds := part.global_transform * part.mesh.get_aabb()
		var ray := PhysicsRayQueryParameters3D.create(Vector3(bounds.get_center().x, bounds.end.y + 1.0, bounds.get_center().z),
			Vector3(bounds.get_center().x, bounds.position.y - 0.2, bounds.get_center().z))
		ray.exclude = [player.get_rid()]
		if space.intersect_ray(ray).is_empty():
			_fail("ray passed through entrance post/roof")
			return
	if not stair.find_children("FoundationButtress_*", "MeshInstance3D", false, false).is_empty():
		_fail("old exposed tower footing blocks remain")
		return
	for name: String in ["GroundedKeepPlinth", "GroundedFoundationToeCourse", "TerrainFittedEntryFoundation"]:
		var part := stair.get_node(name) as MeshInstance3D
		if part.find_children("*", "CollisionShape3D", true, false).is_empty():
			_fail("finished foundation is not solid")
			return
	# Real controller input: jump from the approach, land, then continue to its
	# upper joint. The floor is not moved or replaced with an invisible platform.
	var destination := start.lerp(end, 0.80)
	if not await _settle(player, start.lerp(end, 0.30) + Vector3.UP * 2):
		_fail("could not set up entrance jump")
		return
	Input.action_press("jump")
	var airborne := false
	var landed := false
	for frame in 100:
		var direction := destination - player.global_position
		direction.y = 0
		_drive_frame(player, direction.normalized() if direction.length() > 0.18 else Vector3.ZERO)
		await physics_frame
		Input.action_release("jump")
		airborne = airborne or not player.is_on_floor()
		if airborne and frame > 5 and player.is_on_floor():
			landed = true
			break
	if not landed or not await _walk_to(player, end):
		_fail("entrance jump/landing or onward walking failed")
		return
	print("CASTLE_BOTTOM_FINISH_TEST: PASS — fitted floor edges, nine render/physics floor probes, aligned solid posts/roofs, six real-input wall impacts/escapes, entrance jump/landing, closed solid foundation")
	quit(0)
