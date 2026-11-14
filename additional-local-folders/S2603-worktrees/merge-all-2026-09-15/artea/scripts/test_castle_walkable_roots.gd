extends SceneTree

const WALK_SPEED := 8.0


func _fail(message: String) -> void:
	push_error("CASTLE_WALKABLE_ROOTS_TEST: %s" % message)
	quit(1)


func _settle(player: CharacterBody3D, position: Vector3) -> bool:
	player.global_position = position
	player.velocity = Vector3.ZERO
	for _frame in 180:
		player.velocity.y -= 28.0 / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			return true
	return false


func _walk_over(player: CharacterBody3D, destination: Vector3) -> Dictionary:
	var start_y := player.global_position.y
	var highest_y := start_y
	var best := Vector2(player.global_position.x - destination.x,
		player.global_position.z - destination.z).length()
	var stalled := 0
	for _frame in 300:
		var delta := destination - player.global_position
		delta.y = 0.0
		if delta.length() < 0.35:
			return {"reached": true, "rise": highest_y - start_y}
		var on_floor := player.is_on_floor()
		var before := player.global_position
		player.velocity.x = delta.normalized().x * WALK_SPEED
		player.velocity.z = delta.normalized().z * WALK_SPEED
		player.velocity.y -= 28.0 / 60.0
		var intended := player.velocity
		player.move_and_slide()
		player._try_step_up(on_floor, before, intended, 1.0 / 60.0)
		await physics_frame
		highest_y = maxf(highest_y, player.global_position.y)
		var distance := Vector2(player.global_position.x - destination.x,
			player.global_position.z - destination.z).length()
		if distance < best - 0.005:
			best = distance
			stalled = 0
		else:
			stalled += 1
		if stalled >= 55:
			break
	return {"reached": false, "rise": highest_y - start_y}


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 80:
		await process_frame
		await physics_frame
	var player := hub.get_node_or_null("NewPlayer") as CharacterBody3D
	var roots := hub.find_children("GroundButtressRoot_*", "MeshInstance3D", true, false)
	if player == null or roots.size() != 10:
		_fail("packed player or ten ground-root mounds did not load")
		return
	player.set_physics_process(false)
	player.set_process_input(false)

	for root_index in [0, 1, 3]:
		var root_mound := roots[root_index] as MeshInstance3D
		if root_mound.find_children("WalkableRootBody", "StaticBody3D", true, false).size() != 1:
			_fail("%s has no authoritative collision hull" % root_mound.name)
			return
		var tip := root_mound.to_global(root_mound.get_meta("root_tip") as Vector3)
		var elbow := root_mound.to_global(root_mound.get_meta("root_elbow") as Vector3)
		var outward := tip - elbow
		outward.y = 0.0
		outward = outward.normalized()
		var approach := tip + outward * 6.0 + Vector3.UP * 12.0
		if not await _settle(player, approach):
			_fail("player could not settle beside %s at %s" % [
				root_mound.name, approach])
			return
		var result := await _walk_over(player, elbow)
		if not bool(result.reached) or float(result.rise) < 0.45:
			_fail("player did not climb over %s (reached=%s rise=%.2f)" % [
				root_mound.name, result.reached, result.rise])
			return

	print("CASTLE_WALKABLE_ROOTS_TEST: PASS — three representative root mounds climbed; all ten have closed hulls")
	quit()


func _init() -> void:
	call_deferred("_run")
