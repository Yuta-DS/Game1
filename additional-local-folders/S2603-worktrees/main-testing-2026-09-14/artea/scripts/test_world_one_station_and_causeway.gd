extends SceneTree

## Verifies the two navigation changes on the relocated World One:
##   1. The optional station spur sits clear of and above the Zone 05 arena, and
##      its access stairs can be climbed with ordinary walking, no jump.
##   2. A continuous causeway physically connects the Mind Spark district to the
##      World One landing, so the new land is reachable on foot.


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("WORLD_ONE_STATION_CAUSEWAY: %s" % message)
	for action in ["move_forward", "move_backward", "move_left", "move_right", "jump"]:
		Input.action_release(action)
	quit(1)


func _settle(player: CharacterBody3D) -> bool:
	for _frame in 180:
		await physics_frame
		if player.is_on_floor():
			return true
	return false


func _run() -> void:
	var world_scene := load("res://scenes/art_castle_floating_world.tscn") as PackedScene
	if world_scene == null:
		_fail("art castle floating world scene did not load")
		return
	var world := world_scene.instantiate() as Node3D
	root.add_child(world)
	for _frame in 8:
		await physics_frame

	var player := world.get_node_or_null("Player3D") as CharacterBody3D
	var world_one := world.get_node_or_null("MindSparkWorldOne") as MindSparkWorldOne
	if player == null or world_one == null:
		_fail("player or World One did not mount")
		return

	# --- Station spur placement -------------------------------------------
	world_one.set_station_spur_available(true)
	var spur := world_one.get_node_or_null(
		"WorldOneGeometry/OptionalCompletedWorldStationSpur") as Node3D
	if spur == null:
		_fail("optional station spur is missing")
		return
	var station_center: Vector3 = spur.get_meta("station_center")
	var arena_center: Vector3 = world_one.get_zone_position("05_thought_storm_arena")
	var arena_radius := world_one.get_zone_radius("05_thought_storm_arena")
	var island_radius := float(spur.get_meta("station_island_radius"))
	var flat_gap := Vector2(station_center.x - arena_center.x,
		station_center.z - arena_center.z).length()
	if flat_gap <= arena_radius + island_radius:
		_fail("station island still overlaps the Zone 05 arena floor (gap %.1f m)" % flat_gap)
		return
	if station_center.y <= arena_center.y:
		_fail("station is not raised above the arena it branches from")
		return

	# --- Stair risers stay inside walking step height ----------------------
	var stairs := spur.get_node_or_null("StationAccessStairs") as Node3D
	if stairs == null:
		_fail("station access stairs are missing")
		return
	var max_riser := float(stairs.get_meta("max_riser"))
	if max_riser > MindSparkWorldOne.STATION_STAIR_MAX_RISER + 0.001:
		_fail("stair riser %.2f m exceeds the walkable limit" % max_riser)
		return
	var step_count := int(stairs.get_meta("step_count"))
	for index in step_count:
		var tread := stairs.get_node_or_null("StationStep_%02d" % (index + 1)) as MeshInstance3D
		if tread == null or not (tread.mesh is BoxMesh):
			_fail("stair tread %d has no visible step" % (index + 1))
			return
	if stairs.get_node_or_null("StationStairRampCollision") == null:
		_fail("stairs have no continuous walkable ramp collision")
		return

	# --- Walk the stairs with no jump input --------------------------------
	# Derive the run from the treads themselves: step 01 is the lowest tread and
	# the final step is the highest, which is unambiguous regardless of rotation.
	var first_tread := stairs.get_node("StationStep_01") as MeshInstance3D
	var last_tread := stairs.get_node("StationStep_%02d" % step_count) as MeshInstance3D
	var bottom_local := first_tread.position
	var top_local := last_tread.position
	if top_local.y <= bottom_local.y:
		_fail("station stairs do not ascend from the first tread to the last")
		return
	var climb_direction := (top_local - bottom_local).normalized()

	var test_camera := Camera3D.new()
	world.add_child(test_camera)
	# Face the camera down the climb so "forward" maps onto the stair run.
	var camera_origin := spur.to_global(bottom_local - climb_direction * 30.0 + Vector3.UP * 10.0)
	test_camera.global_transform = Transform3D(Basis.IDENTITY, camera_origin)
	test_camera.look_at(spur.to_global(top_local), Vector3.UP)
	test_camera.make_current()
	player.set("_camera", test_camera)

	player.global_position = spur.to_global(bottom_local + Vector3.UP * 2.0)
	player.velocity = Vector3.ZERO
	if not await _settle(player):
		_fail("player cannot stand at the foot of the station stairs")
		return
	var start_y := player.global_position.y
	var total_rise := top_local.y - bottom_local.y
	var reached_top := false
	Input.action_press("move_forward")
	# Long stair run: give the walk enough frames to actually reach the landing
	# rather than asserting on a partial climb.
	for _frame in 2400:
		await physics_frame
		if player.global_position.y - start_y >= total_rise - 1.0:
			reached_top = true
			break
	Input.action_release("move_forward")
	var climbed := player.global_position.y - start_y
	if not reached_top:
		_fail("player stalled after climbing %.1f m of the %.1f m stair run without jumping"
			% [climbed, total_rise])
		return

	# --- Causeway continuity ----------------------------------------------
	var causeway := world.get_node_or_null("MindSparkWorldOneCauseway") as Node3D
	if causeway == null:
		_fail("causeway to World One was not built")
		return
	# Sibling decks share a base name, so Godot renames the duplicates to
	# generated ids. Identify them by their deck-shaped mesh instead of by name.
	var segment_count := int(causeway.get_meta("segment_count"))
	var deck_count := 0
	for child in causeway.get_children():
		if not (child is MeshInstance3D):
			continue
		var mesh := (child as MeshInstance3D).mesh
		var deck_width := float(world.get("CAUSEWAY_WIDTH"))
		if mesh is BoxMesh and absf((mesh as BoxMesh).size.x - deck_width) < 0.01 \
				and (mesh as BoxMesh).size.z > 100.0:
			deck_count += 1
	if deck_count != segment_count:
		_fail("causeway has %d decks for %d segments" % [deck_count, segment_count])
		return
	for index in range(1, segment_count):
		if causeway.get_node_or_null("CausewaySupportIsland_%02d" % index) == null:
			_fail("causeway support island %d is missing" % index)
			return

	# Ray-sample along the causeway centre line: every sample must hit floor, so
	# there is no gap the player can fall through.
	var space := world.get_world_3d().direct_space_state
	var span := float(causeway.get_meta("span_metres"))
	var walk_start: Vector3 = world.to_global(causeway.get_meta("walk_start"))
	var walk_finish: Vector3 = world.to_global(causeway.get_meta("walk_finish"))
	var samples := maxi(24, int(span / 40.0))
	for index in samples + 1:
		var point: Vector3 = walk_start.lerp(walk_finish, float(index) / float(samples))
		var ray := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * 12.0, point + Vector3.DOWN * 14.0)
		ray.collision_mask = 1
		if space.intersect_ray(ray).is_empty():
			_fail("causeway has an unwalkable gap at %s" % point)
			return

	# The player can physically stand on the causeway deck.
	player.global_position = walk_start + Vector3.UP * 4.0
	player.velocity = Vector3.ZERO
	if not await _settle(player):
		_fail("causeway deck does not physically support the player")
		return

	print("WORLD_ONE_STATION_CAUSEWAY: PASS — station clear of arena at %.0f m gap, "
		% flat_gap
		+ "stairs climbed %.1f m with no jump (riser %.2f m), causeway %.0f m continuous"
		% [climbed, max_riser, span])
	quit()
