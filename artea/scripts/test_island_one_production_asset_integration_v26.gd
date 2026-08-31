extends SceneTree

## Verifies the Blender production assets through the live first-person puzzle
## seam, including visual hierarchy, coupled logic and physical gate clearance.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_STATE := "user://test_island_one_production_assets_v26.json"
const CONTROL_STANDOFF := Vector3(0, 1, -4)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = TEST_STATE
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 8:
		await physics_frame

	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	var controls := puzzle.get_node("PuzzleControls") as Node3D
	var expected_modules := {
		"west_regulator": 131,
		"east_regulator": 131,
		"outer_ring": 122,
		"middle_ring": 122,
		"inner_ring": 122,
		"confirm": 124,
	}
	for control_id in expected_modules:
		var control := controls.get_node("PuzzleControl_%s" % control_id) as Node3D
		var visual := control.get_node("ProductionControlVisual") as Node3D
		assert(visual != null and visual.find_children("MSPC_*", "MeshInstance3D", true, false).size() == 5,
			"%s uses its five-system production GLB" % control_id)
		assert(int(visual.get_meta("editable_source_modules", 0)) == expected_modules[control_id])
		assert(bool(visual.get_meta("all_faces_triangulated", false)))

	var gate := world.get_island_one_heavenly_star_gate()
	var gate_visual := gate.get_node("HeavenlyStarGateProductionVisual") as Node3D
	assert(int(gate_visual.get_meta("editable_source_modules", 0)) == 365)
	assert(int(gate_visual.get_meta("triangles", 0)) == 57292)
	assert(gate.find_children("MSHG_*", "MeshInstance3D", true, false).size() == 10)
	assert((gate.get_node("WestGoldenStarLeaf") as Node3D).find_child(
		"MSHG_GateLeafLeft", true, false) is MeshInstance3D)
	assert((gate.get_node("EastGoldenStarLeaf") as Node3D).find_child(
		"MSHG_GateLeafRight", true, false) is MeshInstance3D)
	assert((gate.get_node("HeavenlyStarHalo") as Node3D).find_child(
		"MSHG_PowerStar", true, false) is MeshInstance3D)

	var player := Node3D.new()
	player.name = "ProductionIntegrationPlayer"
	world.add_child(player)
	for operation in [
		["colour_prism", 1], ["rhythm_prism", 2], ["weight_prism", 3],
		["analysis_console", 1],
		["west_regulator", 1], ["east_regulator", 2],
		["outer_ring", 3], ["middle_ring", 2], ["inner_ring", 1],
		["confirm", 1],
	]:
		var control_id := str(operation[0])
		var control := controls.get_node("PuzzleControl_%s" % control_id) as Node3D
		player.global_position = control.global_position + CONTROL_STANDOFF
		assert(puzzle.nearest_control(player) == control)
		for _press in int(operation[1]):
			var result := puzzle.interact_nearest(player)
			assert(result.accepted, "%s remains operable with the production visual" % control_id)
			await process_frame
	assert(puzzle.is_powered())
	assert(world.is_island_one_star_gate_open())
	await create_timer(2.1).timeout
	var west := gate.get_node("WestGoldenStarLeaf") as AnimatableBody3D
	var east := gate.get_node("EastGoldenStarLeaf") as AnimatableBody3D
	assert(west.position.x < -15.0 and east.position.x > 15.0,
		"authored production leaves clear the existing promenade")
	print("IslandOneProductionAssetsV26: PASS — detailed controls → coupled puzzle → detailed gate opens")

	world.queue_free()
	await process_frame
	_cleanup()
	quit()


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
