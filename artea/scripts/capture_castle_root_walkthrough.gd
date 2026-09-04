extends SceneTree

const WALK_SPEED := 8.0


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


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 90:
		await process_frame
		await physics_frame
	for canvas_candidate in hub.find_children("*", "CanvasLayer", true, false):
		(canvas_candidate as CanvasLayer).visible = false

	var player := hub.get_node("NewPlayer") as CharacterBody3D
	var root_mound := hub.find_child(
		"GroundButtressRoot_01", true, false) as MeshInstance3D
	player.set_physics_process(false)
	player.set_process_input(false)
	var tip := root_mound.to_global(root_mound.get_meta("root_tip") as Vector3)
	var elbow := root_mound.to_global(root_mound.get_meta("root_elbow") as Vector3)
	var outward := tip - elbow
	outward.y = 0.0
	outward = outward.normalized()
	var tangent := Vector3(-outward.z, 0.0, outward.x)
	var approach := tip + outward * 6.0 + Vector3.UP * 12.0
	if not await _settle(player, approach):
		push_error("CASTLE_ROOT_WALKTHROUGH: player could not settle at start")
		quit(1)
		return

	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.05
	camera.far = 1200.0
	hub.add_child(camera)
	var route_midpoint := player.global_position.lerp(elbow, 0.48)
	camera.global_position = route_midpoint + tangent * 26.0 \
		+ outward * 2.5 + Vector3.UP * 12.0
	camera.look_at(route_midpoint + Vector3.UP * 2.0, Vector3.UP)
	camera.make_current()
	for _frame in 45:
		await process_frame
		await physics_frame

	var start_y := player.global_position.y
	var highest_y := start_y
	var reached := false
	var stalled := 0
	var best := Vector2(player.global_position.x - elbow.x,
		player.global_position.z - elbow.z).length()
	for _frame in 300:
		var delta := elbow - player.global_position
		delta.y = 0.0
		if delta.length() < 0.35:
			reached = true
			break
		var on_floor := player.is_on_floor()
		var before := player.global_position
		player.velocity.x = delta.normalized().x * WALK_SPEED
		player.velocity.z = delta.normalized().z * WALK_SPEED
		player.velocity.y -= 28.0 / 60.0
		var intended := player.velocity
		player.move_and_slide()
		player._try_step_up(on_floor, before, intended, 1.0 / 60.0)
		await physics_frame
		await process_frame
		highest_y = maxf(highest_y, player.global_position.y)
		var distance := Vector2(player.global_position.x - elbow.x,
			player.global_position.z - elbow.z).length()
		if distance < best - 0.005:
			best = distance
			stalled = 0
		else:
			stalled += 1
		if stalled >= 55:
			break

	for _frame in 75:
		await process_frame
		await physics_frame
	var rise := highest_y - start_y
	if not reached or rise < 0.45:
		push_error("CASTLE_ROOT_WALKTHROUGH: traversal failed reached=%s rise=%.2f"
			% [reached, rise])
		quit(1)
		return
	print("CASTLE_ROOT_WALKTHROUGH: PASS — player climbed over root; rise=%.2f m"
		% rise)
	quit()


func _init() -> void:
	call_deferred("_capture")
