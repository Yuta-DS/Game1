extends SceneTree

const WALK_SPEED := 9.0
var _route_lowest_y := INF
var _route_highest_y := -INF


func _fail(message: String) -> void:
	push_error("CASTLE_COURTYARD_ROUTE_TEST: %s" % message)
	quit(1)


func _settle(player: CharacterBody3D, position: Vector3) -> bool:
	player.global_position = position
	player.velocity = Vector3.ZERO
	for _frame in 150:
		player.velocity.y -= 28.0 / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			return true
	return false


func _walk_to(player: CharacterBody3D, destination: Vector3,
		max_frames := 240) -> bool:
	_route_lowest_y = player.global_position.y
	_route_highest_y = player.global_position.y
	var stalled := 0
	var best := Vector2(player.global_position.x - destination.x,
		player.global_position.z - destination.z).length()
	for _frame in max_frames:
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
		_route_lowest_y = minf(_route_lowest_y, player.global_position.y)
		_route_highest_y = maxf(_route_highest_y, player.global_position.y)
		var distance := Vector2(player.global_position.x - destination.x,
			player.global_position.z - destination.z).length()
		if distance < best - 0.005:
			best = distance
			stalled = 0
		else:
			stalled += 1
		if stalled >= 45:
			return false
	return false


func _jump_forward(player: CharacterBody3D, destination: Vector3) -> bool:
	player.velocity.y = 7.0
	var airborne := false
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
			airborne = true
		elif airborne:
			return true
	return false


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 80:
		await process_frame
		await physics_frame
	var player := hub.get_node_or_null("NewPlayer") as CharacterBody3D
	var fire := hub.get_node_or_null(
		"CastleEntrance/CastleEntrance/CastleCourtyardFire") as Node3D
	if player == null or fire == null:
		_fail("packed player or courtyard fire did not load")
		return
	player.set_physics_process(false)
	player.set_process_input(false)
	var entrance := hub.get_node(
		"CastleEntrance/CastleEntrance") as Node3D
	var receiving_court := entrance.get_node_or_null(
		"CastleArrivalTerrace") as MeshInstance3D
	if receiving_court == null or not (receiving_court.mesh is BoxMesh) \
			or not receiving_court.visible \
			or (receiving_court.mesh as BoxMesh).size.x < 12.0 \
			or (receiving_court.mesh as BoxMesh).size.z < 14.8 \
			or (receiving_court.mesh as BoxMesh).size.y > 0.4 \
			or String(receiving_court.get_meta("surface_policy", "")) \
				!= "single_collision_backed_floor_no_overlay":
		_fail("arrival court is not one thin visible collision-backed floor")
		return
	for barrier_name in ["TerraceSideBarrier_L", "TerraceSideBarrier_R",
			"TerraceGateReturnBarrier_L", "TerraceGateReturnBarrier_R"]:
		var barrier := entrance.get_node_or_null(barrier_name) as StaticBody3D
		if barrier == null or barrier.get_node_or_null(
				"ContinuousBarrierShape") == null:
			_fail("solid continuous safety barrier %s is missing" % barrier_name)
			return

	const TERRACE_Y := 67.73
	const CENTRE_Z := 27.41
	# Two open walking lanes pass around the original pedestal. No added barrier
	# or paving is allowed to clip the existing gatehouse towers.
	for lane_z in [CENTRE_Z - 1.75, CENTRE_Z + 1.75]:
		var start := Vector3(-16.35, TERRACE_Y + 4.0, lane_z)
		var end := Vector3(-27.45, TERRACE_Y, lane_z)
		if not await _settle(player, start):
			_fail("player could not settle at bypass lane %.2f" % lane_z)
			return
		if not await _walk_to(player, end):
			_fail("player stuck while walking around the central fire in lane %.2f"
				% lane_z)
			return
		if _route_highest_y - _route_lowest_y > 0.12:
			_fail("lane %.2f still crosses an uneven floor seam (range %.3f m)"
				% [lane_z, _route_highest_y - _route_lowest_y])
			return
		if not await _settle(player, start):
			_fail("player could not reset for jump lane %.2f" % lane_z)
			return
		if not await _jump_forward(player, Vector3(-23.8, TERRACE_Y, lane_z)) \
				or not await _walk_to(player, end):
			_fail("player jump snagged beside the original fire pedestal in lane %.2f" % lane_z)
			return

	# Prove the retained pedestal is solid: the player stops at its visible face
	# rather than passing through the fire object.
	if not await _settle(player, Vector3(-18.0, TERRACE_Y + 4.0, CENTRE_Z)):
		_fail("player could not settle for pedestal solidity check")
		return
	var crossed_pedestal := await _walk_to(player,
		Vector3(-24.0, TERRACE_Y, CENTRE_Z), 150)
	if crossed_pedestal or player.global_position.x < -20.0:
		_fail("original fire pedestal can be passed through")
		return

	# Long sides and both outward-edge returns must stop the capsule, while the
	# bridge's central 5.6 m gateway remains open.
	if not await _settle(player, Vector3(-22.0, TERRACE_Y + 4.0, 32.8)):
		_fail("player could not settle for side balustrade check")
		return
	var crossed_side := await _walk_to(player,
		Vector3(-22.0, TERRACE_Y, 37.0), 120)
	if crossed_side or player.global_position.z > 34.2:
		_fail("player can pass through the terrace side balustrade")
		return
	if not await _settle(player, Vector3(-18.0, TERRACE_Y + 4.0, 32.5)):
		_fail("player could not settle for outward return check")
		return
	var crossed_return := await _walk_to(player,
		Vector3(-13.5, TERRACE_Y, 32.5), 120)
	if crossed_return or player.global_position.x > -15.45:
		_fail("player can pass through the outward gate return")
		return
	if not await _settle(player, Vector3(-18.0, TERRACE_Y + 4.0, CENTRE_Z)) \
			or not await _walk_to(player,
				Vector3(-14.3, TERRACE_Y, CENTRE_Z), 120):
		_fail("castle balustrade blocks the intended central bridge gateway")
		return

	# The barbican towers used to be render-only. Prove a direct line through a
	# shaft is now blocked, then prove the widened lane beside it remains usable.
	var architecture := hub.get_node_or_null("CastleArchitecture") as Node3D
	var towers := architecture.find_children("BarbicanTower*", "MeshInstance3D",
		true, false) if architecture != null else []
	if towers.size() != 2:
		_fail("paired solid barbican towers are missing")
		return
	var tower := towers[0] as MeshInstance3D
	var tower_centre := tower.global_position
	if not await _settle(player, tower_centre + Vector3(-3.2, 5.0, 0.0)):
		_fail("player could not settle for barbican solidity check")
		return
	var crossed_tower := await _walk_to(player,
		tower_centre + Vector3(3.2, 0.0, 0.0), 160)
	if crossed_tower or player.global_position.x > tower_centre.x - 1.35:
		_fail("player can still walk through a barbican tower")
		return
	var clear_lane_z := CENTRE_Z - 1.65 if tower_centre.z < CENTRE_Z \
		else CENTRE_Z + 1.65
	if not await _settle(player,
			Vector3(-22.7, TERRACE_Y + 4.0, clear_lane_z)) \
			or not await _walk_to(player,
				Vector3(-14.3, TERRACE_Y, clear_lane_z), 200):
		_fail("player cannot walk around the solid barbican tower on the floor")
		return

	print("CASTLE_COURTYARD_ROUTE_TEST: PASS — seamless lanes, solid fire and towers, guarded edges, open walk-around route")
	quit()


func _init() -> void:
	call_deferred("_run")
