# Dynamic safety regression for the castle crown perimeter and stair opening.
# Every closed rooftop edge is hit at sprint speed, then the player must escape
# inward without falling, tunnelling, or remaining pinned against the wall.
extends SceneTree

const RUN_SPEED := 14.0
const GRAVITY_PER_FRAME := 28.0 / 60.0
const CROWN_SURFACE_OFFSET := 0.17


func _fail(message: String) -> void:
	push_error("CASTLE_ROOFTOP_BARRIER_TEST: %s" % message)
	quit(1)


func _settle(player: CharacterBody3D, position: Vector3) -> bool:
	player.global_position = position
	player.velocity = Vector3.ZERO
	for _frame in 150:
		player.velocity.y -= GRAVITY_PER_FRAME
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			return true
	return false


func _run_direction(player: CharacterBody3D, direction: Vector3,
		frames: int) -> void:
	for _frame in frames:
		var was_on_floor := player.is_on_floor()
		var before := player.global_position
		player.velocity.x = direction.x * RUN_SPEED
		player.velocity.z = direction.z * RUN_SPEED
		player.velocity.y -= GRAVITY_PER_FRAME
		var intended := player.velocity
		player.move_and_slide()
		player._try_step_up(was_on_floor, before, intended, 1.0 / 60.0)
		await physics_frame


func _walk_to(player: CharacterBody3D, destination: Vector3) -> bool:
	var best := Vector2(player.global_position.x - destination.x,
		player.global_position.z - destination.z).length()
	var stalled := 0
	for _frame in 120:
		var delta := destination - player.global_position
		delta.y = 0.0
		if delta.length() < 0.28:
			return true
		var was_on_floor := player.is_on_floor()
		var before := player.global_position
		player.velocity.x = delta.normalized().x * RUN_SPEED
		player.velocity.z = delta.normalized().z * RUN_SPEED
		player.velocity.y -= GRAVITY_PER_FRAME
		var intended := player.velocity
		player.move_and_slide()
		player._try_step_up(was_on_floor, before, intended, 1.0 / 60.0)
		await physics_frame
		var distance := Vector2(player.global_position.x - destination.x,
			player.global_position.z - destination.z).length()
		if distance < best - 0.005:
			best = distance
			stalled = 0
		else:
			stalled += 1
		if stalled > 45:
			return false
	return false


func _impact_and_escape(player: CharacterBody3D, base: Vector2,
		crown_y: float, wall: MeshInstance3D) -> bool:
	var outward := Vector3(wall.global_position.x - base.x, 0.0,
		wall.global_position.z - base.y).normalized()
	var start := Vector3(wall.global_position.x, crown_y + 2.2,
		wall.global_position.z) - outward * 1.65
	if not await _settle(player, start):
		return false
	await _run_direction(player, outward, 28)
	var impact_radius := Vector2(player.global_position.x - base.x,
		player.global_position.z - base.y).length()
	if player.global_position.y < crown_y - 1.0 or impact_radius > 8.72:
		print("BARRIER_DIAGNOSTIC impact wall=%s crown_y=%.3f y=%.3f radius=%.3f" % [
			wall.name, crown_y, player.global_position.y, impact_radius])
		return false
	var before_escape := player.global_position
	var escaped := await _walk_to(player, before_escape - outward * 1.35)
	if not escaped or player.global_position.y < crown_y - 1.0:
		print("BARRIER_DIAGNOSTIC escape wall=%s crown_y=%.3f y=%.3f moved=%.3f" % [
			wall.name, crown_y, player.global_position.y,
			Vector2(player.global_position.x - before_escape.x,
				player.global_position.z - before_escape.z).length()])
	return escaped and player.global_position.y >= crown_y - 1.0


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
	var base: Vector2 = stair.get_meta("tower_base")
	var crown_y := float(stair.get_meta("tower_top_y")) + CROWN_SURFACE_OFFSET

	var closed_edges: Array[MeshInstance3D] = []
	for child in stair.get_children():
		if not (child is MeshInstance3D):
			continue
		var mesh_child := child as MeshInstance3D
		var child_name := String(mesh_child.name)
		if child_name.begins_with("CrownParapet_") \
				or bool(mesh_child.get_meta(
					"continuous_rooftop_fall_barrier", false)):
			if not mesh_child.find_children(
					"*", "StaticBody3D", true, false).is_empty():
				closed_edges.append(mesh_child)
	if closed_edges.size() < 8:
		_fail("rooftop perimeter is incomplete: only %d solid edge sections" \
			% closed_edges.size())
		return

	var arrival_guard := stair.get_node_or_null(
		"CrownStairArrivalGuard_Outer") as MeshInstance3D
	var arrival_visual := stair.get_node_or_null(
		"BlenderCrownStairArrivalGuard_Outer") as Node3D
	if arrival_guard == null or arrival_visual == null \
			or arrival_guard.find_children(
				"*", "StaticBody3D", true, false).is_empty() \
			or not bool(arrival_guard.get_meta(
				"continuous_from_stair_to_rooftop", false)) \
			or not arrival_visual.find_children(
				"*", "StaticBody3D", true, false).is_empty():
		_fail("right-side stair arrival guard is missing or uses unsafe detail collision")
		return
	closed_edges.append(arrival_guard)

	player.set_physics_process(false)
	player.set_process_input(false)
	var stairwell_centre := float(stair.get_meta("crown_stairwell_centre_angle"))
	var stairwell_half := float(stair.get_meta("crown_stairwell_half_angle"))
	var impact_count := 0
	for wall in closed_edges:
		var wall_angle := atan2(wall.global_position.z - base.y,
			wall.global_position.x - base.x)
		# Perimeter masonry behind the intentional open stairwell is not a
		# walkable approach surface. Its safety is owned by the two straight edge
		# walls, curved inner return, and the tested outer arrival guard.
		if wall != arrival_guard and absf(angle_difference(
				wall_angle, stairwell_centre)) < stairwell_half + 0.10:
			continue
		if not await _impact_and_escape(player, base, crown_y, wall):
			_fail("player crossed, fell from, or stuck against %s at %s" % [
				wall.name, player.global_position])
			return
		impact_count += 1

	if impact_count < 5:
		_fail("too few walkable rooftop edge sections received sprint impacts")
		return
	print("CASTLE_ROOFTOP_BARRIER_TEST: PASS — %d walkable rooftop sections resisted sprint impacts and released the player cleanly" % impact_count)
	quit(0)


func _init() -> void:
	call_deferred("_run")
