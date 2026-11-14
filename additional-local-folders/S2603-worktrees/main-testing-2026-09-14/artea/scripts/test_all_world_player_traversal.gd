extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("ALL_WORLD_PLAYER_TRAVERSAL_TEST: %s" % message)
	quit(1)


func _settle(player: CharacterBody3D) -> bool:
	player.velocity = Vector3.ZERO
	for _frame in 120:
		await physics_frame
		if player.is_on_floor():
			return true
	return false


func _exercise_direction(player: CharacterBody3D, action_name: String) -> Vector2:
	var start := player.global_position
	Input.action_press(action_name)
	for _frame in 24:
		await physics_frame
	Input.action_release(action_name)
	for _brake in 12:
		await physics_frame
	return Vector2(player.global_position.x - start.x, player.global_position.z - start.z)


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 5:
		await physics_frame
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	var world := gallery.get_node_or_null("ArtCastleFloatingWorld") as Node3D
	var regions := world.get_node_or_null("KingdomRegions3000m") as Node3D if world != null else null
	if player == null or regions == null:
		_fail("gallery player or the three kingdom regions did not load")
		return
	for action_name in ["move_forward", "move_backward", "move_left", "move_right", "jump", "attack", "block"]:
		if not InputMap.has_action(action_name):
			_fail("missing player action: %s" % action_name)
			return
	if float(player.get("jump_height")) < 1.2 or float(player.get("speed")) < 10.0:
		_fail("movement or jump settings are too weak for world obstacles")
		return
	if float(player.get("coyote_time")) <= 0.0 or float(player.get("jump_buffer_time")) <= 0.0 \
			or not bool(player.get("floor_block_on_wall")):
		_fail("controller lacks forgiving jump timing or vertical-wall blocking")
		return
	var camera := gallery.get_node_or_null("Camera3D") as Camera3D
	if camera == null or float(camera.get("collision_margin")) <= 0.0:
		_fail("third-person camera has no world-geometry collision protection")
		return
	var calculated := {
		"forward": player.call("get_camera_relative_move_direction", Vector2(0, -1)),
		"backward": player.call("get_camera_relative_move_direction", Vector2(0, 1)),
		"left": player.call("get_camera_relative_move_direction", Vector2(-1, 0)),
		"right": player.call("get_camera_relative_move_direction", Vector2(1, 0)),
	}
	if (calculated.forward as Vector3).dot(calculated.backward as Vector3) > -0.999 \
			or (calculated.left as Vector3).dot(calculated.right as Vector3) > -0.999 \
			or absf((calculated.forward as Vector3).dot(calculated.right as Vector3)) > 0.001:
		_fail("camera-relative movement axes are not opposite and perpendicular")
		return

	var routes := {
		"mind": regions.call("get_story_route", "mind"),
		"heart": regions.call("get_story_route", "heart"),
		"creator": regions.call("get_story_route", "creator"),
	}
	for kingdom_id in routes:
		var route: Array = routes[kingdom_id]
		var checkpoint: Dictionary = route[0]
		player.global_position = world.to_global(checkpoint.position + Vector3(0, 5, 0))
		if not await _settle(player):
			_fail("%s arrival platform does not support the player" % kingdom_id)
			return
		var movements := {}
		for action_name in ["move_forward", "move_backward", "move_left", "move_right"]:
			player.global_position = world.to_global(checkpoint.position + Vector3(0, 5, 0))
			if not await _settle(player):
				_fail("%s platform did not re-ground for %s test" % [kingdom_id, action_name])
				return
			movements[action_name] = await _exercise_direction(player, action_name)
			if (movements[action_name] as Vector2).length() < 0.8:
				_fail("%s does not move the player in %s world" % [action_name, kingdom_id])
				return
		player.global_position = world.to_global(checkpoint.position + Vector3(0, 5, 0))
		if not await _settle(player):
			_fail("%s platform did not re-ground for jump test" % kingdom_id)
			return
		var floor_y := player.global_position.y
		Input.action_press("jump")
		await physics_frame
		Input.action_release("jump")
		var peak_y := player.global_position.y
		for _jump_frame in 22:
			await physics_frame
			peak_y = maxf(peak_y, player.global_position.y)
		if peak_y - floor_y < 0.9:
			_fail("player cannot jump over low objects in %s world" % kingdom_id)
			return
		player.call("set_input_enabled", false)
		var locked_position := player.global_position
		Input.action_press("move_forward")
		for _locked_frame in 12:
			await physics_frame
		Input.action_release("move_forward")
		if Vector2(locked_position.x, locked_position.z).distance_to(
				Vector2(player.global_position.x, player.global_position.z)) > 0.05:
			_fail("input lock still allows movement in %s world" % kingdom_id)
			return
		player.call("set_input_enabled", true)
		var expected_respawn: Vector3 = regions.call("get_safe_respawn", world.to_local(player.global_position))
		player.global_position.y = -130.0
		player.velocity = Vector3(12, -30, 8)
		for _respawn_frame in 4:
			await process_frame
		var expected_global := world.to_global(expected_respawn)
		if Vector2(player.global_position.x, player.global_position.z).distance_to(
				Vector2(expected_global.x, expected_global.z)) > 0.1 \
				or absf(player.velocity.x) > 0.01 or absf(player.velocity.z) > 0.01 \
				or player.velocity.y < -2.0:
			_fail("fall recovery did not return the player safely within %s world" % kingdom_id)
			return

	print("ALL_WORLD_PLAYER_TRAVERSAL_TEST: PASS — 4-way movement, braking, grounding, jumping, camera safety, walls, input locks, and fall recovery work in all worlds")
	quit()
