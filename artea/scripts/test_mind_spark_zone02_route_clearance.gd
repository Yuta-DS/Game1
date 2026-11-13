extends SceneTree

## Regression for District 01 -> 02. They share one physical island, so the
## route must use the fused saddle and an opening gate—not an extra bridge.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const PlayerScene := preload("res://scenes/player_3d.tscn")
const TEST_STATE := "user://test_zone02_star_gate_clearance.json"


func _fail(message: String) -> void:
	push_error("MindSparkZone02RouteClearance: " + message)
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


func _walk(player: CharacterBody3D, destination: Vector3) -> bool:
	for _frame in 600:
		var offset := destination - player.global_position
		offset.y = 0.0
		if offset.length() < 1.5:
			return player.is_on_floor()
		var heading := offset.normalized()
		player.velocity = Vector3(heading.x * 8.0,
			player.velocity.y - 28.0 / 60.0, heading.z * 8.0)
		player.move_and_slide()
		await physics_frame
	return false


func _collider_labels(player: CharacterBody3D) -> String:
	var labels := PackedStringArray()
	for index in player.get_slide_collision_count():
		var slide := player.get_slide_collision(index)
		var collider := slide.get_collider() as Node
		if collider != null:
			var label := str(collider.get_path())
			if collider is CollisionObject3D:
				var body := collider as CollisionObject3D
				var owner_id := body.shape_find_owner(slide.get_collider_shape_index())
				var shape_owner := body.shape_owner_get_owner(owner_id) as Node
				if shape_owner != null:
					label += "/" + shape_owner.name
					if shape_owner.has_meta("source_mesh"):
						label += " from " + str(shape_owner.get_meta("source_mesh"))
			labels.append(label)
	return ", ".join(labels)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = TEST_STATE
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 8:
		await physics_frame

	var route := world.get_node("WorldOneGeometry/MainStoryCircuitRoute") as Node3D
	assert(route.get_node_or_null("CircuitRoute_01_A") == null)
	assert(route.get_node_or_null("CircuitRoute_01_B") == null)
	var fusion := world.get_node(
		"WorldOneGeometry/ThreeFusedSuperIslands/FusedSuperIsland_01_02") as Node3D
	var saddle := fusion.get_node("SharedIvorySaddleCollision") as StaticBody3D
	assert(saddle != null and saddle.get_child(0) is CollisionShape3D)
	var gate := world.get_island_one_heavenly_star_gate()
	assert(gate != null and not world.is_island_one_star_gate_open())
	assert(world.get_island_one_puzzle().solve_for_test().reason == "completed")
	await create_timer(2.1).timeout
	assert(world.is_island_one_star_gate_open())
	var west := gate.get_node("WestGoldenStarLeaf") as AnimatableBody3D
	var east := gate.get_node("EastGoldenStarLeaf") as AnimatableBody3D
	assert(absf(absf(west.position.x) - 5.70) < 0.001 and absf(absf(east.position.x) - 5.70) < 0.001,
		"the opened leaves retain fixed outer hinge axes")
	assert(is_equal_approx(west.rotation.y, deg_to_rad(-96.0)) \
		and is_equal_approx(east.rotation.y, deg_to_rad(96.0)),
		"the opened leaves swing inward and clear the central promenade")
	print("MindSparkZone02RouteClearance: PASS — fused saddle + opened star gate, no duplicate bridge")
	world.queue_free()
	await process_frame
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
	quit()
