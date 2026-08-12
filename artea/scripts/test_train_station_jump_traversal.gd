extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("TRAIN_STATION_JUMP_TEST: %s" % message)
	for action in ["move_forward", "move_backward", "move_left", "move_right", "jump"]:
		Input.action_release(action)
	quit(1)


func _settle(player: CharacterBody3D) -> bool:
	for _frame in 150:
		await physics_frame
		if player.is_on_floor():
			return true
	return false


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 6:
		await physics_frame
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	var world := gallery.get_node_or_null("ArtCastleFloatingWorld") as Node3D
	var railway := world.get_node_or_null("StoryCrownRailway") as Node3D if world != null else null
	if player == null or railway == null:
		_fail("gallery player or Crown Line did not load")
		return
	var station_position: Vector3 = railway.call("get_station_position", 0)
	var gallery_station := railway.get_node("StoryStations/Station_01_gallery") as Node3D
	var access_stairs := gallery_station.get_node_or_null("AccessRamp") as Node3D
	if access_stairs == null:
		_fail("station has no stair transition from the floating skybridge")
		return
	var previous_step_x := -INF
	var previous_step_top := -INF
	for step_index in 12:
		var step := access_stairs.get_node_or_null("DockStep_%02d" % (step_index + 1)) as MeshInstance3D
		if step == null or not (step.mesh is BoxMesh):
			_fail("dock stair %d is missing its visible tread" % (step_index + 1))
			return
		if access_stairs.get_node_or_null("DockStep_%02dCollision" % (step_index + 1)) != null:
			_fail("dock stair %d still has a cumulative wall collision" % (step_index + 1))
			return
		if (step.mesh as BoxMesh).size.y > 0.16:
			_fail("dock stair %d is still a tall ground block" % (step_index + 1))
			return
		if step.position.x <= previous_step_x:
			_fail("dock stairs do not progress continuously toward the platform")
			return
		var step_top := step.position.y + (step.mesh as BoxMesh).size.y * 0.5
		if previous_step_top > -INF and step_top - previous_step_top > 0.20:
			_fail("dock stair %d riser is too tall for continuous walking" % (step_index + 1))
			return
		previous_step_x = step.position.x
		previous_step_top = step_top
	var ramp_collision := access_stairs.get_node_or_null("WalkableStairRampCollision") as StaticBody3D
	if ramp_collision == null:
		_fail("station stairs have no continuous walkable ramp collision")
		return
	# Walk the complete transition using ordinary right movement and no jump.
	# Fix the active camera heading so right maps exactly toward the platform.
	var test_camera := Camera3D.new()
	gallery.add_child(test_camera)
	test_camera.global_transform = Transform3D(Basis.IDENTITY,
		gallery_station.to_global(Vector3(-31.0, 8.0, 16.0)))
	test_camera.make_current()
	# Gallery camera logic may reclaim viewport focus; pin the player's own
	# camera reference so the scripted direction remains deterministic.
	player.set("_camera", test_camera)
	player.global_position = gallery_station.to_global(Vector3(-30.5, 3.0, 0.0))
	player.velocity = Vector3.ZERO
	if not await _settle(player):
		_fail("player cannot stand at the bottom of the station ramp")
		return
	Input.action_press("move_right")
	for _frame in 240:
		await physics_frame
	Input.action_release("move_right")
	var player_at_ramp_top := gallery_station.to_local(player.global_position)
	if player_at_ramp_top.x < -6.5 or player_at_ramp_top.y < 0.7:
		var collision_names: Array[String] = []
		for collision_index in player.get_slide_collision_count():
			var collider := player.get_slide_collision(collision_index).get_collider() as Node
			if collider is StaticBody3D:
				var collision_shape := collider.get_child(0) as CollisionShape3D
				var box_size := (collision_shape.shape as BoxShape3D).size \
					if collision_shape != null and collision_shape.shape is BoxShape3D else Vector3.ZERO
				collision_names.append("%s local=%s size=%s" \
					% [collider.get_path(), (collider as StaticBody3D).position, box_size])
			else:
				collision_names.append(str(collider.get_path()) if collider != null else "unknown")
		_fail("player cannot walk from ground to platform without jumping " \
			+ "(reached %s, velocity %s, input %.1f, collisions %s)" \
			% [player_at_ramp_top, player.velocity, Input.get_action_strength("move_right"),
				collision_names])
		return
	var stair_guard := access_stairs.get_node_or_null("StairGuardLeft") as MeshInstance3D
	if stair_guard == null or not (stair_guard.mesh is BoxMesh) \
			or (stair_guard.mesh as BoxMesh).size.y > 0.5:
		_fail("station stairs still use a view-blocking solid guard wall")
		return
	# The station landing is a safe player point 2 m above the island. Verify
	# the downhill top corner of the access deck itself meets the ground datum;
	# using the player point as its centre previously left a ~2.9 m visible gap.
	var access_deck := gallery_station.get_node_or_null(
		"KingdomAccessSkybridge/FloatingAccessDeck") as MeshInstance3D
	if access_deck == null or not (access_deck.mesh is BoxMesh):
		_fail("Gallery Station access bridge has no box-shaped walkable deck")
		return
	var deck_size := (access_deck.mesh as BoxMesh).size
	var deck_landing_top := access_deck.to_global(
		Vector3(0.0, deck_size.y * 0.5, -deck_size.z * 0.5))
	var island_surface_y := railway.to_global(
		railway.call("get_station_landing", 0) - Vector3.UP * 2.0).y
	if absf(deck_landing_top.y - island_surface_y) > 0.05:
		_fail("Gallery Station access deck still floats %.2fm above the island ground"
			% (deck_landing_top.y - island_surface_y))
		return
	# Physical station platform supports running and a full jump cycle.
	player.global_position = railway.to_global(station_position + Vector3(0, 6, 12))
	player.velocity = Vector3.ZERO
	if not await _settle(player):
		_fail("Gallery Station platform does not physically support the player")
		return
	var platform_y := player.global_position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var platform_peak := player.global_position.y
	for _frame in 45:
		await physics_frame
		platform_peak = maxf(platform_peak, player.global_position.y)
	if platform_peak - platform_y < 0.9:
		_fail("player cannot jump over station-floor features")
		return

	# Physical passenger deck supports standing and jumping over its low bench.
	player.global_position = railway.call("get_train_deck_position") + Vector3(0, 3, -2.5)
	player.velocity = Vector3.ZERO
	if not await _settle(player):
		_fail("train passenger deck is not physically walkable")
		return
	var deck_y := player.global_position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var deck_peak := player.global_position.y
	for _frame in 45:
		await physics_frame
		deck_peak = maxf(deck_peak, player.global_position.y)
	if deck_peak - deck_y < 0.9:
		_fail("player cannot jump on the train passenger deck")
		return

	print("TRAIN_STATION_JUMP_TEST: PASS — station floor, boarding route, train deck, and jump clearance are physical")
	quit()
