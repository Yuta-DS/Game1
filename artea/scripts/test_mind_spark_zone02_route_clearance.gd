extends SceneTree

## Regression for District 01 -> 02. They share one physical island, so the
## route must use the fused saddle and an opening gate—not an extra bridge.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_STATE := "user://test_zone02_star_gate_clearance.json"


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
