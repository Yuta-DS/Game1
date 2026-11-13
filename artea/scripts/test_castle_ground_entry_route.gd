# Regression for the terrain-to-spiral handoff. The first tread sits several
# metres from the tower centre, so its entrance must be tested against the
# actual local Terrain3D slope with the packed player, not a remote height
# sample or a ray alone.
extends SceneTree

const WALK_SPEED := 10.0
const STALL_FRAMES := 50


func _fail(message: String) -> void:
	push_error("CASTLE_GROUND_ENTRY_ROUTE_TEST: %s" % message)
	quit(1)


func _colliders(player: CharacterBody3D) -> String:
	var labels: Array[String] = []
	for index in player.get_slide_collision_count():
		var hit := player.get_slide_collision(index)
		var collider := hit.get_collider()
		if collider is Node:
			labels.append("%s normal=%s" % [(collider as Node).get_path(),
				hit.get_normal()])
	return "; ".join(labels)


func _settle(player: CharacterBody3D, position: Vector3) -> bool:
	player.global_position = position
	player.velocity = Vector3.ZERO
	for _frame in 180:
		player.velocity.y -= 28.0 / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor() and absf(player.velocity.y) < 0.01:
			return true
	return false


func _walk_to(player: CharacterBody3D, destination: Vector3) -> bool:
	var best := Vector2(player.global_position.x - destination.x,
		player.global_position.z - destination.z).length()
	var stalled := 0
	for _frame in 240:
		var delta := destination - player.global_position
		delta.y = 0.0
		if delta.length() < 0.24:
			return true
		var on_floor := player.is_on_floor()
		var before := player.global_position
		player.velocity.x = delta.normalized().x * WALK_SPEED
		player.velocity.z = delta.normalized().z * WALK_SPEED
		player.velocity.y -= 28.0 / 60.0
		var intended := player.velocity
		player.move_and_slide()
		player._try_step_up(on_floor, before, intended, 1.0 / 60.0)
		await physics_frame
		var distance := Vector2(player.global_position.x - destination.x,
			player.global_position.z - destination.z).length()
		if distance < best - 0.005:
			best = distance
			stalled = 0
		else:
			stalled += 1
		if stalled >= STALL_FRAMES:
			return false
	return false


func _jump_to_route(player: CharacterBody3D, destination: Vector3) -> bool:
	player.velocity.y = 7.0
	var became_airborne := false
	var landed := false
	for _frame in 150:
		var delta := destination - player.global_position
		delta.y = 0.0
		if delta.length() > 0.05:
			player.velocity.x = delta.normalized().x * 7.0
			player.velocity.z = delta.normalized().z * 7.0
		player.velocity.y -= 28.0 / 60.0
		player.move_and_slide()
		await physics_frame
		if not player.is_on_floor():
			became_airborne = true
		elif became_airborne:
			landed = true
			break
	# Landing anywhere on the six-metre promenade is valid; the following walk
	# assertion proves the capsule can immediately continue onto the spiral.
	return landed


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 80:
		await process_frame
		await physics_frame
	var stair := hub.get_node_or_null("CastleStairs/CastleStair") as Node3D
	var player := hub.get_node_or_null("NewPlayer") as CharacterBody3D
	if stair == null or player == null:
		_fail("castle stair or packed player did not load")
		return
	# The walk surface must continue beneath both guard faces. A positive visual
	# gap here is also a physical slot where a jumping player or prop can wedge.
	var inner_surface_radius: float = stair.get_meta("stair_tread_inner_radius")
	var outer_surface_radius: float = stair.get_meta("stair_tread_outer_radius")
	var inner_guard_face: float = stair.get_meta("inner_guard_lane_face_radius")
	var outer_guard_face: float = stair.get_meta("outer_guard_lane_face_radius")
	if inner_surface_radius >= inner_guard_face \
			or outer_surface_radius <= outer_guard_face:
		_fail("stair walking surface does not overlap both barrier faces: %.2f/%.2f .. %.2f/%.2f"
			% [inner_surface_radius, inner_guard_face,
				outer_guard_face, outer_surface_radius])
		return
	var grounded_entry := stair.get_node_or_null("GroundedCastleEntry") as Node3D
	if grounded_entry == null \
			or not bool(grounded_entry.get_meta("barriers_join_spiral", false)) \
			or grounded_entry.find_children(
				"GroundEntry*Barrier", "MeshInstance3D", true, false).size() != 2:
		_fail("ground entry does not carry both barriers continuously into the terrain")
		return
	var rock_exclusion := hub.get_node_or_null(
		"Environment/Objects/CastleStairFootRockExclusion") as Node3D
	if rock_exclusion == null or not bool(rock_exclusion.get("negative")):
		_fail("stair foot is not protected from scattered rocks")
		return
	var exclusion_shape = rock_exclusion.get("shape")
	for point: Vector3 in [Vector3(5.1, 29.0, 17.0),
			Vector3(18.0, 29.0, 22.0)]:
		if not exclusion_shape.is_point_inside(point, rock_exclusion.global_transform):
			_fail("stair-foot rock exclusion misses %s" % point)
			return
	var promenade := grounded_entry.get_node_or_null("GroundEntryWalkSurface") \
		as MeshInstance3D
	var promenade_collision := grounded_entry.get_node_or_null(
		"GroundEntryWalkCollision") as MeshInstance3D
	if promenade == null or not promenade.visible \
			or not bool(promenade.get_meta("smooth_straight_route", false)) \
			or promenade_collision == null or promenade_collision.visible \
			or promenade_collision.find_children(
				"*", "StaticBody3D", true, false).size() != 1:
		_fail("ground entry is not one visible, smooth collision promenade")
		return
	for barrier in grounded_entry.find_children(
			"GroundEntry*Barrier", "MeshInstance3D", true, false):
		if barrier.find_children("*", "StaticBody3D", true, false).size() != 1:
			_fail("ground-entry barrier is not a continuous solid wall: %s"
				% barrier.name)
			return
		var inward: Vector3 = barrier.global_basis.x.normalized()
		if inward.dot(promenade.global_position - barrier.global_position) < 0.0:
			inward = -inward
		var probe := player.global_transform
		probe.origin = barrier.global_position + inward * 1.6 + Vector3.UP * 0.15
		var hit := KinematicCollision3D.new()
		if not player.test_move(probe, -inward * 3.0, hit) \
				or hit.get_collider() != barrier.get_child(0):
			_fail("player capsule can pass through the visible %s" % barrier.name)
			return
	var treads := stair.find_children("StairTread_*", "MeshInstance3D", true, false)
	treads.sort_custom(func(a, b):
		return (a as MeshInstance3D).global_position.y < (b as MeshInstance3D).global_position.y)
	if treads.size() < 12:
		_fail("spiral did not build enough treads")
		return
	var first := treads[0] as MeshInstance3D
	var second := treads[1] as MeshInstance3D
	var forward := second.global_position - first.global_position
	forward.y = 0.0
	forward = forward.normalized()
	player.set_physics_process(false)
	player.set_process_input(false)
	var access := grounded_entry.get_node_or_null("GroundAccessWalkSurface") \
		as MeshInstance3D
	var access_collision := grounded_entry.get_node_or_null(
		"GroundAccessWalkCollision") as MeshInstance3D
	var access_slope := float(grounded_entry.get_meta("ground_access_slope", INF))
	if access == null or not access.visible \
			or access_collision == null or access_collision.visible \
			or access_collision.find_children("*", "CollisionShape3D", true, false).size() != 1 \
			or access_slope > 0.20:
		_fail("grass-to-promenade approach is not a gentle, solid paved route")
		return
	var entry_start: Vector3 = grounded_entry.get_meta("surface_start")
	var entry_end: Vector3 = grounded_entry.get_meta("surface_end")
	var entry_forward := entry_end - entry_start
	entry_forward.y = 0.0
	entry_forward = entry_forward.normalized()
	var entry_right := Vector3(entry_forward.z, 0.0, -entry_forward.x)
	var promenade_width := (promenade.mesh as BoxMesh).size.x
	if absf((access.mesh as BoxMesh).size.x - promenade_width) > 0.025 \
			or absf(entry_right.dot(access.global_position - promenade.global_position)) > 0.025:
		_fail("grass-to-promenade paving does not line up with the castle path")
		return
	var foot: Vector3 = grounded_entry.get_meta("ground_access_foot")
	if not await _settle(player, foot - entry_forward * 0.35 + Vector3.UP * 3.0) \
			or not await _walk_to(player, entry_start + entry_forward * 0.5) \
			or not await _walk_to(player, entry_end):
		_fail("player cannot walk from grass onto the paved approach without jumping: %s; collisions: %s"
			% [player.global_position, _colliders(player)])
		return
	for lane_offset: float in [-0.75, 0.0, 0.75]:
		var radial := Vector3(first.global_position.x - (stair.get_meta("tower_base") as Vector2).x,
			0.0, first.global_position.z - (stair.get_meta("tower_base") as Vector2).y).normalized()
		var approach := first.global_position - forward * 4.5 + radial * lane_offset
		if not await _settle(player, approach + Vector3.UP * 5.0):
			_fail("player could not settle on terrain in lane %.2f" % lane_offset)
			return
		var first_lane_target := first.global_position + radial * lane_offset
		if not await _jump_to_route(player, first_lane_target) \
				or not await _walk_to(player,
					(treads[4] as MeshInstance3D).global_position + radial * lane_offset):
			_fail("player jump wedged at the ground-to-stair handoff in lane %.2f at %s; collisions: %s"
				% [lane_offset, player.global_position, _colliders(player)])
			return
		if not await _settle(player, approach + Vector3.UP * 5.0):
			_fail("player could not reset on terrain in lane %.2f" % lane_offset)
			return
		for tread_index in 12:
			var tread := treads[tread_index] as MeshInstance3D
			var tread_radial := Vector3(
				tread.global_position.x - (stair.get_meta("tower_base") as Vector2).x,
				0.0,
				tread.global_position.z - (stair.get_meta("tower_base") as Vector2).y).normalized()
			if not await _walk_to(player, tread.global_position + tread_radial * lane_offset):
				_fail("walking from land stuck in lane %.2f before %s at %s; collisions: %s" % [
					lane_offset, tread.name, player.global_position, _colliders(player)])
				return
	print("CASTLE_GROUND_ENTRY_ROUTE_TEST: PASS — three smooth walking lanes and three jump recoveries")
	quit()


func _init() -> void:
	call_deferred("_run")
