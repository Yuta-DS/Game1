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
	for lane_offset: float in [-0.75, 0.0, 0.75]:
		var radial := Vector3(first.global_position.x - (stair.get_meta("tower_base") as Vector2).x,
			0.0, first.global_position.z - (stair.get_meta("tower_base") as Vector2).y).normalized()
		var approach := first.global_position - forward * 4.5 + radial * lane_offset
		if not await _settle(player, approach + Vector3.UP * 5.0):
			_fail("player could not settle on terrain in lane %.2f" % lane_offset)
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
	print("CASTLE_GROUND_ENTRY_ROUTE_TEST: PASS")
	quit()


func _init() -> void:
	call_deferred("_run")
