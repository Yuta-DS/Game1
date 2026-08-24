# Gameplay regression for the upper spiral flight shown in the stuck-player
# report. Static ray checks can prove that the crown has headroom while still
# missing a side collision that catches the real player capsule between treads.
extends SceneTree

# Use the packed player's maximum sprint speed. A route that only works under
# gentle test motion can still snag during normal play.
const WALK_SPEED := 10.0
const MAX_FRAMES_PER_TREAD := 180
const STALL_FRAMES := 45


func _fail(message: String) -> void:
	push_error("CASTLE_SPIRAL_ROUTE_TEST: %s" % message)
	quit(1)


func _collider_label(player: CharacterBody3D) -> String:
	var labels: Array[String] = []
	for index in player.get_slide_collision_count():
		var hit := player.get_slide_collision(index)
		var collider := hit.get_collider()
		if collider is Node:
			labels.append("%s normal=%s" % [
				(collider as Node).get_path(), hit.get_normal()])
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
	var best_distance := Vector2(player.global_position.x - destination.x,
		player.global_position.z - destination.z).length()
	var stalled := 0
	for _frame in MAX_FRAMES_PER_TREAD:
		var planar_delta := destination - player.global_position
		planar_delta.y = 0.0
		if planar_delta.length() < 0.24:
			return true
		var was_on_floor := player.is_on_floor()
		var before := player.global_position
		player.velocity.x = planar_delta.normalized().x * WALK_SPEED
		player.velocity.z = planar_delta.normalized().z * WALK_SPEED
		player.velocity.y -= 28.0 / 60.0
		var intended := player.velocity
		player.move_and_slide()
		player._try_step_up(was_on_floor, before, intended, 1.0 / 60.0)
		await physics_frame
		var distance := Vector2(player.global_position.x - destination.x,
			player.global_position.z - destination.z).length()
		if distance < best_distance - 0.005:
			best_distance = distance
			stalled = 0
		else:
			stalled += 1
		if stalled >= STALL_FRAMES:
			return false
	return false


func _test_lane(player: CharacterBody3D, stair: Node3D, treads: Array,
		lane_offset: float) -> bool:
	var first_index := treads.size() - 24
	var first_tread := treads[first_index] as MeshInstance3D
	var centre := Vector3(stair.get_meta("tower_base").x,
		first_tread.global_position.y, stair.get_meta("tower_base").y)
	var first_radial := (first_tread.global_position - centre).normalized()
	if not await _settle(player,
			first_tread.global_position + first_radial * lane_offset + Vector3.UP * 3.0):
		_fail("player did not settle in lane %.2f at %s; collisions: %s" % [
			lane_offset, player.global_position, _collider_label(player)])
		return false

	for index in range(first_index + 1, treads.size()):
		var tread := treads[index] as MeshInstance3D
		centre.y = tread.global_position.y
		var radial := (tread.global_position - centre).normalized()
		if not await _walk_to(player, tread.global_position + radial * lane_offset):
			_fail("player stuck in lane %.2f approaching %s at %s; collisions: %s" % [
				lane_offset, tread.name, player.global_position, _collider_label(player)])
			return false

	# Continue in the spiral's forward tangent direction onto the crown floor,
	# then turn inward. This is the exact last-tread handoff used in play.
	var final_tread := treads.back() as MeshInstance3D
	centre.y = final_tread.global_position.y
	var radial := (final_tread.global_position - centre).normalized()
	var tangent := Vector3(-radial.z, 0.0, radial.x)
	var crown_entry := final_tread.global_position + radial * lane_offset + tangent * 1.2
	if not await _walk_to(player, crown_entry):
		_fail("player stuck leaving final tread in lane %.2f at %s; collisions: %s" % [
			lane_offset, player.global_position, _collider_label(player)])
		return false
	var crown_interior := centre + radial * 3.8
	if not await _walk_to(player, crown_interior):
		_fail("player stuck entering crown from lane %.2f at %s; collisions: %s" % [
			lane_offset, player.global_position, _collider_label(player)])
		return false
	return true


func _test_crown_floor(player: CharacterBody3D, stair: Node3D) -> bool:
	var base: Vector2 = stair.get_meta("tower_base")
	var surface_y: float = float(stair.get_meta("tower_top_y")) + 0.17
	var centre := Vector3(base.x, surface_y, base.y)
	if not await _walk_to(player, centre):
		_fail("player stuck walking to the centre of the crown; collisions: %s"
			% _collider_label(player))
		return false
	for point_index in 8:
		var angle := TAU * float(point_index) / 8.0
		var point := centre + Vector3(cos(angle) * 3.6, 0.0, sin(angle) * 3.6)
		if not await _walk_to(player, point):
			_fail("player stuck crossing crown floor point %d at %s; collisions: %s" % [
				point_index, player.global_position, _collider_label(player)])
			return false
		if player.global_position.y < surface_y - 0.35:
			_fail("player fell through crown floor at point %d" % point_index)
			return false
	return true


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 60:
		await process_frame
		await physics_frame

	var stair := hub.get_node_or_null("CastleStairs/CastleStair") as Node3D
	var player := hub.get_node_or_null("NewPlayer") as CharacterBody3D
	if stair == null or player == null:
		_fail("castle stair or packed player did not load")
		return

	var treads := stair.find_children("StairTread_*", "MeshInstance3D", true, false)
	treads.sort_custom(func(a, b):
		return (a as MeshInstance3D).global_position.y < (b as MeshInstance3D).global_position.y)
	if treads.size() < 24:
		_fail("spiral did not build enough treads: %d" % treads.size())
		return
	var walk_surface := stair.get_node_or_null("AscentWalkSurface") as MeshInstance3D
	if walk_surface == null or walk_surface.find_children(
			"*", "StaticBody3D", true, false).is_empty():
		_fail("continuous spiral walk surface has no collision")
		return
	var probe_tread := treads[treads.size() - 24] as MeshInstance3D
	var probe := PhysicsRayQueryParameters3D.create(
		probe_tread.global_position + Vector3.UP * 2.0,
		probe_tread.global_position - Vector3.UP * 2.0)
	probe.collide_with_areas = false
	var probe_hit := (stair.get_world_3d() as World3D).direct_space_state.intersect_ray(probe)
	if not probe_hit.has("collider") \
			or not walk_surface.is_ancestor_of(probe_hit["collider"] as Node):
		_fail("continuous spiral walk surface is not under upper tread (hit %s)"
			% (probe_hit["collider"] if probe_hit.has("collider") else "nothing"))
		return

	player.set_physics_process(false)
	player.set_process_input(false)
	for lane_offset: float in [-0.85, 0.0, 0.85]:
		if not await _test_lane(player, stair, treads, lane_offset):
			return
	if not await _test_crown_floor(player, stair):
		return

	print("CASTLE_SPIRAL_ROUTE_TEST: PASS — three stair lanes and full crown circuit")
	quit(0)


func _init() -> void:
	call_deferred("_run")
