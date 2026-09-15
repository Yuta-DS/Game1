extends SceneTree

# Gameplay regression for the exact CrownDeck -> gateway -> bridge -> terrace
# route. Static AABB/raycast checks missed a concave-trimesh seam that let the
# real player capsule sink into the crown slab and wedge against its rim.

const ROUTE_Z := 27.4105
const WALK_SPEED := 4.0
const MAX_FRAMES := 720
const STALL_FRAMES := 45


func _fail(message: String) -> void:
	push_error("CASTLE_PLAYER_ROUTE_TEST: %s" % message)
	quit(1)


func _collider_label(player: CharacterBody3D) -> String:
	var labels: Array[String] = []
	for index in player.get_slide_collision_count():
		var hit := player.get_slide_collision(index)
		var collider := hit.get_collider()
		if collider is Node:
			labels.append("%s normal=%s" % [(collider as Node).get_path(), hit.get_normal()])
	return "; ".join(labels)


func _has_static_collision(node: Node) -> bool:
	return node != null \
		and not node.find_children("*", "StaticBody3D", true, false).is_empty() \
		and not node.find_children("*", "CollisionShape3D", true, false).is_empty()


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


func _walk(player: CharacterBody3D, destination: Vector3) -> bool:
	var best_distance := player.global_position.distance_to(destination)
	var stalled := 0
	for _frame in MAX_FRAMES:
		var planar_delta := destination - player.global_position
		planar_delta.y = 0.0
		if planar_delta.length() < 0.35:
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
		if distance < best_distance - 0.01:
			best_distance = distance
			stalled = 0
		else:
			stalled += 1
		if stalled >= STALL_FRAMES:
			return false
	return false


func _walk_forward_distance(player: CharacterBody3D, x_direction: float,
		required_distance: float) -> bool:
	var start_x := player.global_position.x
	var best_progress := 0.0
	var stalled := 0
	for _frame in 240:
		var was_on_floor := player.is_on_floor()
		var before := player.global_position
		player.velocity.x = x_direction * WALK_SPEED
		player.velocity.z = 0.0
		player.velocity.y -= 28.0 / 60.0
		var intended := player.velocity
		player.move_and_slide()
		player._try_step_up(was_on_floor, before, intended, 1.0 / 60.0)
		await physics_frame
		var progress := (player.global_position.x - start_x) * x_direction
		if progress >= required_distance:
			return true
		if progress > best_progress + 0.01:
			best_progress = progress
			stalled = 0
		else:
			stalled += 1
		if stalled >= STALL_FRAMES:
			return false
	return false


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 60:
		await process_frame

	var stair := hub.get_node_or_null("CastleStairs/CastleStair") as Node3D
	var entrance := hub.get_node_or_null("CastleEntrance/CastleEntrance") as Node3D
	var player := hub.get_node_or_null("NewPlayer") as CharacterBody3D
	if stair == null or entrance == null or player == null:
		_fail("castle stair, entrance, or packed player did not load")
		return

	# All architecture that supports the player is collision-backed. Decorative
	# lenses, gears, conduits and overhead frames intentionally remain visual-only
	# so they cannot introduce invisible blockers into the same route.
	var required_walkables: Array[Node] = [
		stair.get_node_or_null("CrownDeck"),
		stair.get_node_or_null("CrownGatewayApron"),
		stair.get_node_or_null("LumenBridgeLaunch"),
		stair.get_node_or_null("LumenBridgeRoadbed"),
		stair.get_node_or_null("CastleDoorLanding"),
		entrance.get_node_or_null("CastleArrivalTerrace"),
		entrance.get_node_or_null("CastleUpperCourt"),
		entrance.get_node_or_null("RoyalCastleStair/RoyalTread_00"),
		entrance.get_node_or_null("RoyalCastleStair/RoyalDoorLanding"),
	]
	for walkable in required_walkables:
		if not _has_static_collision(walkable):
			_fail("walkable castle architecture is missing StaticBody3D collision: %s"
				% (walkable.name if walkable != null else "<missing node>"))
			return
	var grand_treads := entrance.find_children(
		"GrandStairTread_*", "MeshInstance3D", true, false)
	if grand_treads.size() != 7:
		_fail("final court stair does not contain seven named collision treads")
		return
	for tread in grand_treads:
		if not _has_static_collision(tread):
			_fail("final court stair tread has no StaticBody3D collision: %s" % tread.name)
			return

	var apron := stair.get_node_or_null("CrownGatewayApron") as MeshInstance3D
	if apron == null or not (apron.mesh is BoxMesh):
		_fail("box-shaped CrownGatewayApron is missing")
		return
	var apron_size := (apron.mesh as BoxMesh).size
	if apron_size.x < 5.2 or apron_size.z < 5.0:
		_fail("gateway apron is too small for a stable player crossing: %s" % apron_size)
		return
	if apron.find_children("*", "StaticBody3D", true, false).is_empty():
		_fail("gateway apron has no collision")
		return

	player.set_physics_process(false)
	player.set_process_input(false)
	# Do not force-clear the gameplay interaction flag here. That masked the
	# live freeze where a dormant hidden chatbot retained movement ownership.
	# A freshly loaded world must already provide an unlocked player.
	if player.interacting:
		_fail("packed player begins the castle route with a stale interaction lock")
		return
	var launch := stair.get_node("LumenBridgeLaunch") as MeshInstance3D
	var landing := stair.get_node("CastleDoorLanding") as MeshInstance3D
	var crown_point := Vector3(launch.global_position.x + 5.0, 72.0, ROUTE_Z)
	var terrace_point := Vector3(landing.global_position.x - 2.2, 72.0, ROUTE_Z)
	# Stop in front of the redesigned solid oak door, not inside its leaf.
	var castle_threshold_point := Vector3(-39.0, 82.0, ROUTE_Z)

	if not await _settle(player, crown_point):
		_fail("player did not stand on crown interior; at %s, collisions: %s" % [
			player.global_position, _collider_label(player)])
		return
	if not await _walk(player, terrace_point) or player.global_position.x > -19.5:
		_fail("player stuck crown-to-terrace at %s; collisions: %s" % [
			player.global_position, _collider_label(player)])
		return
	# The approved layout deliberately places a solid fire stand on the axis.
	# Walk the open right-hand aisle; never expect movement through its pedestal.
	for waypoint: Vector3 in [Vector3(-20.5, 68, ROUTE_Z + 2.2),
			Vector3(-26.5, 68, ROUTE_Z + 2.2), Vector3(-28.0, 69, ROUTE_Z)]:
		if not await _walk(player, waypoint):
			_fail("right-hand courtyard aisle is blocked at %s" % player.global_position)
			return
	if not await _walk(player, castle_threshold_point) or player.global_position.x > -38.7:
		_fail("player stuck terrace-to-castle-threshold at %s; collisions: %s" % [
			player.global_position, _collider_label(player)])
		return

	if not await _settle(player, castle_threshold_point):
		_fail("player did not stand on the raised castle threshold")
		return
	# Return by the other side of the fire to prove both circulation lanes.
	for waypoint: Vector3 in [Vector3(-27.0, 68, ROUTE_Z - 2.2),
			Vector3(-20.5, 68, ROUTE_Z - 2.2)]:
		if not await _walk(player, waypoint):
			_fail("left-hand courtyard aisle is blocked at %s" % player.global_position)
			return
	if not await _walk(player, terrace_point) or player.global_position.x < -20.5:
		_fail("player stuck castle-threshold-to-terrace at %s; collisions: %s" % [
			player.global_position, _collider_label(player)])
		return
	if not await _walk(player, crown_point) or player.global_position.x < -5.8:
		_fail("player stuck terrace-to-crown at %s; collisions: %s" % [
			player.global_position, _collider_label(player)])
		return

	# The terrace is much wider than the bridge. Exercise the way a person
	# actually approaches it: from both outer sides, diagonally into a safe
	# bridge lane. A square balustrade end cap used to catch the capsule here
	# even though the centreline route above passed.
	for lane_sign in [-1.0, 1.0]:
		var signed_lane: float = lane_sign
		# Stay in the authored inner walk-around lane. The paired solid barbican
		# towers frame the shoulders at +/-4.2 m; aiming at +/-4.0 m correctly hits
		# stone rather than exercising the open bridge route.
		var wide_terrace := Vector3(terrace_point.x, 72.0,
			ROUTE_Z + signed_lane * 1.65)
		var bridge_lane := Vector3(landing.global_position.x + 1.0, 72.0,
			ROUTE_Z + signed_lane * 1.5)
		var crown_lane := Vector3(launch.global_position.x + 1.0, 72.0,
			ROUTE_Z + signed_lane * 1.5)
		if not await _settle(player, wide_terrace):
			_fail("player did not stand on wide terrace approach lane %.1f"
				% signed_lane)
			return
		if not await _walk(player, bridge_lane) \
				or not await _walk(player, crown_lane):
			_fail("player stuck entering bridge diagonally from terrace lane %.1f at %s; collisions: %s"
				% [signed_lane, player.global_position, _collider_label(player)])
			return
		if not await _walk(player, bridge_lane) \
				or not await _walk(player, wide_terrace):
			_fail("player stuck leaving bridge toward terrace lane %.1f at %s; collisions: %s"
				% [signed_lane, player.global_position, _collider_label(player)])
			return

		# Pure-forward input from the apparent deck edge used to hit a square
		# wall end with a longitudinal normal and make zero progress. The flared
		# mouth must now slide the capsule gently inward while it advances.
		var edge_approach := Vector3(landing.global_position.x - 0.2, 72.0,
			ROUTE_Z + signed_lane * 2.2)
		if not await _settle(player, edge_approach):
			_fail("player did not stand on bridge edge approach lane %.1f"
				% signed_lane)
			return
		if not await _walk_forward_distance(player, 1.0, 1.15):
			_fail("player stuck on square terrace safety-wall end in lane %.1f at %s; collisions: %s"
				% [signed_lane, player.global_position, _collider_label(player)])
			return

	print("CASTLE_PLAYER_ROUTE_TEST: PASS — packed player crossed crown gateway, full bridge, terrace, final ascent, castle threshold, and both diagonal bridge mouths")
	quit()


func _init() -> void:
	call_deferred("_run")
