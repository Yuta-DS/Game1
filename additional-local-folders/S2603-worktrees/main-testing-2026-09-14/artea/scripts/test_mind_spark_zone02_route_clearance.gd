extends SceneTree

## Regression for the Zone 01 -> Zone 02 approach shown in the gameplay
## screenshot. The route used to continue beneath the Living Network island,
## leaving its thick floor slab at player-head height.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const PlayerScene := preload("res://scenes/player_3d.tscn")
const WALK_SPEED := 7.0
const MAX_WALK_FRAMES := 900
const STALL_FRAMES := 75


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MIND_SPARK_ZONE02_ROUTE_CLEARANCE: %s" % message)
	quit(1)


func _collider_labels(player: CharacterBody3D) -> String:
	var labels: Array[String] = []
	for index in player.get_slide_collision_count():
		var collision := player.get_slide_collision(index)
		var collider := collision.get_collider()
		if collider is Node:
			labels.append("%s normal=%s" % [(collider as Node).get_path(), collision.get_normal()])
	return "; ".join(labels)


func _settle(player: CharacterBody3D, position: Vector3) -> bool:
	player.global_position = position
	player.velocity = Vector3.ZERO
	for _frame in 240:
		player.velocity.y -= 28.0 / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			return true
	return false


func _walk(player: CharacterBody3D, destination: Vector3) -> bool:
	var best_distance := INF
	var stalled := 0
	for _frame in MAX_WALK_FRAMES:
		var delta := destination - player.global_position
		delta.y = 0.0
		var distance := delta.length()
		if distance < 1.25:
			return true
		player.velocity.x = delta.normalized().x * WALK_SPEED
		player.velocity.z = delta.normalized().z * WALK_SPEED
		player.velocity.y -= 28.0 / 60.0
		player.move_and_slide()
		await physics_frame
		var remaining := Vector2(
			player.global_position.x - destination.x,
			player.global_position.z - destination.z).length()
		if remaining < best_distance - 0.015:
			best_distance = remaining
			stalled = 0
		else:
			stalled += 1
		if stalled >= STALL_FRAMES:
			return false
	return false


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	stage.add_child(world)
	var player := PlayerScene.instantiate() as CharacterBody3D
	stage.add_child(player)
	for _frame in 8:
		await physics_frame
	player.set_physics_process(false)

	var route := world.get_node("WorldOneGeometry/MainStoryCircuitRoute") as Node3D
	var approach := route.get_node("CircuitRoute_01_B") as MeshInstance3D
	var approach_mesh := approach.mesh as BoxMesh
	var zone_position := world.get_zone_position("02_living_network_forest")
	var zone_radius := world.get_zone_radius("02_living_network_forest")
	var deck_surface_y := float(approach.get_meta("walk_surface_finish_y"))
	if not is_equal_approx(deck_surface_y, zone_position.y):
		_fail("landing is not exactly coplanar with Living Network (deck %.4f, island %.4f)"
			% [deck_surface_y, zone_position.y])
		return
	var left_rail := route.get_node("CircuitRoute_01_BLeftRail") as MeshInstance3D
	var right_rail := route.get_node("CircuitRoute_01_BRightRail") as MeshInstance3D
	var landing_center := approach.position
	var left_offset := left_rail.position - landing_center
	var right_offset := right_rail.position - landing_center
	if not is_equal_approx(left_offset.length(), right_offset.length()) \
			or not left_offset.is_equal_approx(-right_offset + Vector3.UP * 4.0):
		_fail("landing rails are not exact mirrors (left %s, right %s)"
			% [left_offset, right_offset])
		return
	var approach_start := approach.to_global(Vector3(0, 0, -approach_mesh.size.z * 0.5))
	var zone_global := world.to_global(zone_position)
	var start_distance := Vector2(approach_start.x, approach_start.z).distance_to(
		Vector2(zone_global.x, zone_global.z))
	if start_distance < zone_radius - 2.0:
		_fail("final approach begins %.1f m inside the %.1f m Living Network island"
			% [zone_radius - start_distance, zone_radius])
		return

	# Spawn on the outer end of the final deck and drive the real production
	# capsule across the deck/island threshold without jumping.
	var capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	var stand_height := capsule.height * 0.5 + 0.18
	var spawn := approach.to_global(Vector3(
		0, approach_mesh.size.y * 0.5 + stand_height,
		-approach_mesh.size.z * 0.5 + 2.0))
	if not await _settle(player, spawn):
		_fail("production player cannot stand on the Zone 02 approach")
		return
	var approach_direction := Vector3(
		zone_global.x - spawn.x, 0.0, zone_global.z - spawn.z).normalized()
	# Stop 20 m inside the island rim. QuestGate_1 intentionally blocks the
	# court farther in until progression opens it; this regression isolates the
	# accidental floor-slab obstruction without bypassing that authored gate.
	var destination := zone_global - approach_direction * (zone_radius - 20.0) \
		+ Vector3(0, stand_height + 0.4, 0)
	if not await _walk(player, destination):
		_fail("player is blocked entering Living Network at %s; collisions: %s"
			% [player.global_position, _collider_labels(player)])
		return

	print("MIND_SPARK_ZONE02_ROUTE_CLEARANCE: PASS — player walked from the route onto Living Network ground with no slab obstruction")
	quit()
