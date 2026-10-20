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
	var pavilion := gallery_station.get_node_or_null("BioMagitechPavilion") as Node3D
	if pavilion == null or pavilion.find_children("CrystalPlanter_*", "Node3D", true, false).size() != 4:
		_fail("Gallery Station bio-magitech pavilion or its four safe-edge planters is missing")
		return
	var access_stairs := gallery_station.get_node_or_null("AccessRamp") as Node3D
	if access_stairs == null:
		_fail("station has no stair transition from the floating skybridge")
		return
	var previous_step_x := -INF
	var previous_step_top := -INF
	for step_index in 16:
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
	var access_deck := gallery_station.get_node_or_null(
		"KingdomAccessSkybridge/FloatingAccessDeck") as MeshInstance3D
	if access_deck == null or not (access_deck.mesh is BoxMesh):
		_fail("Gallery Station access bridge has no box-shaped walkable deck")
		return
	var access_bridge := gallery_station.get_node("KingdomAccessSkybridge") as Node3D
	var first_ceremonial_step := access_bridge.get_node_or_null(
		"CeremonialStep_L_00") as MeshInstance3D
	var last_ceremonial_step := access_bridge.get_node_or_null(
		"CeremonialStep_L_47") as MeshInstance3D
	if first_ceremonial_step == null or last_ceremonial_step == null:
		_fail("Gallery Station skybridge is missing its ceremonial stair treads")
		return
	# Each station can approach along a different horizontal heading. Check the
	# ceremonial flight follows its actual deck instead of being compressed onto
	# one world axis beneath the pavilion.
	var bridge_run := Vector2(access_deck.basis.z.x, access_deck.basis.z.z).normalized()
	var tread_progress := Vector2(
		last_ceremonial_step.position.x - first_ceremonial_step.position.x,
		last_ceremonial_step.position.z - first_ceremonial_step.position.z)
	var deck_horizontal_run := Vector2(
		access_deck.basis.z.x, access_deck.basis.z.z).length() \
		* (access_deck.mesh as BoxMesh).size.z
	if tread_progress.length() < deck_horizontal_run * 0.85 \
			or absf(tread_progress.normalized().dot(bridge_run)) < 0.98:
		_fail("ceremonial stairs are piled beneath the station instead of following the skybridge " \
			+ "(first %s, last %s, progress %s, bridge run %s)" \
			% [first_ceremonial_step.position, last_ceremonial_step.position,
				tread_progress, bridge_run])
		return
	var central_ramp := access_bridge.get_node_or_null("CentralLumenRamp") as MeshInstance3D
	if central_ramp == null or not (central_ramp.mesh is BoxMesh) \
			or (central_ramp.mesh as BoxMesh).size.x < 5.0:
		_fail("skybridge has no player-width clear central lane")
		return
	var first_step := access_stairs.get_node("DockStep_01") as MeshInstance3D
	var first_step_outer_edge := first_step.position.x \
		- (first_step.mesh as BoxMesh).size.x * 0.5
	var deck_dock_edge := access_deck.position.x \
		+ (access_deck.mesh as BoxMesh).size.z * 0.5 * access_deck.basis.z.x
	if absf(first_step_outer_edge - deck_dock_edge) > 0.25:
		_fail("gray platform gap remains between the skybridge and first dock stair")
		return
	# Walk the complete transition using ordinary right movement and no jump.
	# Fix the active camera heading so right maps exactly toward the platform.
	var test_camera := Camera3D.new()
	gallery.add_child(test_camera)
	test_camera.global_transform = Transform3D(Basis.IDENTITY,
		gallery_station.to_global(Vector3(-37.0, 8.0, 16.0)))
	test_camera.make_current()
	# Gallery camera logic may reclaim viewport focus; pin the player's own
	# camera reference so the scripted direction remains deterministic.
	player.set("_camera", test_camera)
	player.global_position = gallery_station.to_global(Vector3(-36.8, 3.0, 0.0))
	player.velocity = Vector3.ZERO
	if not await _settle(player):
		_fail("player cannot stand at the bottom of the station ramp")
		return
	Input.action_press("move_right")
	for _frame in 300:
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
	# Traverse the long stair shown in the reported screenshots. Its collision is
	# the continuous access deck; decorative treads, gardens, posts and rails must
	# remain outside the central lane for the complete island-to-station climb.
	var access_deck_size := (access_deck.mesh as BoxMesh).size
	player.global_position = access_deck.to_global(
		Vector3(0.0, access_deck_size.y * 0.5 + 2.5, -access_deck_size.z * 0.5 + 2.0))
	player.velocity = Vector3.ZERO
	if not await _settle(player):
		_fail("player cannot stand at the island end of the long station stair")
		return
	Input.action_press("move_right")
	Input.action_press("run")
	for _frame in 600:
		await physics_frame
	Input.action_release("run")
	Input.action_release("move_right")
	var player_after_long_stair := gallery_station.to_local(player.global_position)
	if player_after_long_stair.x < -42.0 or player_after_long_stair.y < -4.0:
		_fail("player cannot walk through the pictured long station stair " \
			+ "(reached %s)" % player_after_long_stair)
		return
	# Mind Spark remains around its original west-side location. Its one centred
	# entrance now faces the main park island and consumes only the clear gap
	# between the circular platform and island rim.
	var mind_station := railway.get_node("StoryStations/Station_02_mind") as Node3D
	var mind_stairs := mind_station.get_node("AccessRamp") as Node3D
	var mind_first_step := mind_stairs.get_node("DockStep_01") as MeshInstance3D
	var mind_last_step := mind_stairs.get_node("DockStep_16") as MeshInstance3D
	var mind_access_deck := mind_station.get_node(
		"KingdomAccessSkybridge/FloatingAccessDeck") as MeshInstance3D
	var mind_deck_size := mind_access_deck.mesh as BoxMesh
	var mind_deck_min_x := mind_access_deck.position.x \
		- absf(mind_access_deck.basis.z.x) * mind_deck_size.size.z * 0.5
	if mind_first_step.position.x < 30.0 or mind_last_step.position.x < 6.0 \
			or mind_deck_min_x < 36.0:
		_fail("Mind Spark station stair is not centred toward the main park island")
		return
	var mind_right_guard_opening := mind_station.get_node_or_null("PlatformGuardRightFront")
	if mind_right_guard_opening == null:
		_fail("Mind Spark station east guardrail has no centred stair entrance opening")
		return
	var west_observatory_tower := world.get_node_or_null(
		"WestObservatory/MiniObservatory/ObservatoryTower") as MeshInstance3D
	if west_observatory_tower == null:
		_fail("West Observatory tower is missing")
		return
	var station_to_tower := Vector2(mind_station.global_position.x \
		- west_observatory_tower.global_position.x,
		mind_station.global_position.z - west_observatory_tower.global_position.z).length()
	if station_to_tower < 150.0:
		_fail("West Observatory big block still overlaps the Mind Spark train station")
		return
	var mind_landing: Vector3 = railway.call("get_station_landing", 1)
	const MIND_ISLAND_CENTER := Vector3(-600.0, 0.0, 1640.0)
	const MIND_ISLAND_RADIUS := 175.0
	var island_west_rim_x := MIND_ISLAND_CENTER.x - MIND_ISLAND_RADIUS
	var platform_east_rim_x := mind_station.position.x + 38.0
	var clear_gap := island_west_rim_x - platform_east_rim_x
	if absf(mind_landing.z - MIND_ISLAND_CENTER.z) > 0.01 \
			or mind_landing.x < island_west_rim_x \
			or mind_landing.x - island_west_rim_x > 10.0:
		_fail("Mind Spark station landing is not centred just inside the main park island")
		return
	if clear_gap < 70.0 or clear_gap > 85.0:
		_fail("Mind Spark station-to-island gap is not one ceremonial-stair length (%.1fm)" % clear_gap)
		return
	# Walk straight from the park ground through the entire station stair and onto
	# the train platform with normal controls and no jump or direction change.
	player.global_position = mind_access_deck.to_global(
		Vector3(0.0, mind_deck_size.size.y * 0.5 + 2.5,
			-mind_deck_size.size.z * 0.5 + 2.0))
	player.velocity = Vector3.ZERO
	if not await _settle(player):
		_fail("player cannot stand on the Mind Spark park-island stair landing")
		return
	test_camera.global_rotation.y = 0.0
	Input.action_press("move_left")
	Input.action_press("run")
	var reached_mind_platform := false
	for _frame in 600:
		await physics_frame
		if mind_station.to_local(player.global_position).x <= 12.0:
			reached_mind_platform = true
			break
	Input.action_release("run")
	Input.action_release("move_left")
	var player_at_mind_station := mind_station.to_local(player.global_position)
	if not reached_mind_platform or player_at_mind_station.y < -4.0:
		var mind_collision_names: Array[String] = []
		for collision_index in player.get_slide_collision_count():
			var collider := player.get_slide_collision(collision_index).get_collider() as Node
			mind_collision_names.append(str(collider.get_path()) if collider != null else "unknown")
		_fail("player cannot walk from the Mind Spark park island through the station entrance " \
			+ "(reached %s, collisions %s)" % [player_at_mind_station, mind_collision_names])
		return
	var stair_guard := access_stairs.get_node_or_null("StairGuardLeft") as MeshInstance3D
	if stair_guard == null or not (stair_guard.mesh is BoxMesh) \
			or (stair_guard.mesh as BoxMesh).size.y > 0.5:
		_fail("station stairs still use a view-blocking solid guard wall")
		return
	# The station landing is a safe player point 2 m above the island. Verify
	# the downhill top corner of the access deck itself meets the ground datum;
	# using the player point as its centre previously left a ~2.9 m visible gap.
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
