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
	for control_id in ["west_regulator", "east_regulator", "outer_ring", "middle_ring", "inner_ring", "confirm"]:
		var control := controls.get_node("PuzzleControl_%s" % control_id) as Node3D
		var visual := control.get_node("HeavenlyQuestInstrument") as Node3D
		assert(visual != null and visual.find_children("*", "MeshInstance3D", true, false).size() >= 2,
			"%s uses its shaped Blender instrument" % control_id)
		assert(control.get_meta("design_revision") == "heavenly_kit_02")
	var gate := world.get_island_one_heavenly_star_gate()
	var gate_visual := gate.get_node("HeavenlyStarGateProductionVisual") as Node3D
	assert(not gate_visual.visible,
		"obsolete imported shaft must stay hidden behind the finished gate")
	assert(int(gate_visual.get_meta("editable_source_modules", 0)) == 365)
	assert(int(gate_visual.get_meta("triangles", 0)) == 57292)
	assert(gate.find_children("MSHG_*", "MeshInstance3D", true, false).size() == 10)
	assert((gate.get_node("WestGoldenStarLeaf") as Node3D).find_child(
		"MSHG_GateLeafLeft", true, false) is MeshInstance3D)
	assert((gate.get_node("EastGoldenStarLeaf") as Node3D).find_child(
		"MSHG_GateLeafRight", true, false) is MeshInstance3D)
	var threshold_court := gate.get_node("HeavenlyThresholdCourt") as Node3D
	var classical_portal := threshold_court.get_node("ClassicalHeavenlyHingedPortal") as Node3D
	assert(classical_portal.find_children("HeavenlyArchOrder_*", "MeshInstance3D", true, false).size() == 64)
	assert(classical_portal.find_children("*ClassicalPilaster", "MeshInstance3D", true, false).size() == 2)
	assert(classical_portal.find_children("*TympanumScroll", "Node3D", true, false).size() == 2)
	assert(classical_portal.find_children("TympanumSunRay_*", "MeshInstance3D", true, false).size() == 9)
	assert(threshold_court.find_child("HeavenlyGateLintelBand", true, false) == null)
	assert(threshold_court.find_child("HeavenlyGateThresholdBand", true, false) is MeshInstance3D)
	assert(threshold_court.find_children("*HingeDriveHousing", "Node3D", true, false).size() == 2)
	assert(threshold_court.find_children("*HingeDrivePowerBay", "Node3D", true, false).size() == 2)
	assert(threshold_court.find_children("*HingeMotorCore", "MeshInstance3D", true, false).size() == 2)
	assert(threshold_court.find_children("*HingeDriveRotor", "Node3D", true, false).size() == 2)
	assert(threshold_court.find_children("HingeTorqueLight_*", "MeshInstance3D", true, false).size() == 6)
	assert(threshold_court.find_children("HingeAngleGauge_*", "MeshInstance3D", true, false).size() == 14)
	assert(threshold_court.find_children("HingeCelestialNameplate", "MeshInstance3D", true, false).size() == 2)
	assert(threshold_court.find_children("*AetherBlossom_*", "MeshInstance3D", true, false).size() == 10)
	for leaf_name in ["WestGoldenStarLeaf", "EastGoldenStarLeaf"]:
		var leaf := gate.get_node(leaf_name) as Node3D
		assert(leaf.find_child("IvoryLeafSpine", true, false) is MeshInstance3D)
		assert(leaf.find_child("CelestialEnamelPanel", true, false) is MeshInstance3D)
		assert(leaf.find_child("LowerEnamelKickPanel", true, false) is MeshInstance3D)
		assert(leaf.find_child("LowerBrassFootRail", true, false) is MeshInstance3D)
		assert(leaf.find_children("GiltWingRib_*", "MeshInstance3D", true, false).size() == 2)
		assert(leaf.find_children("CelestialGrilleBar_*", "MeshInstance3D", true, false).size() == 5)
		assert(leaf.find_children("GrilleSpearPearl_*", "MeshInstance3D", true, false).size() == 5)
		assert(leaf.find_children("*FiligreeScroll", "Node3D", true, false).size() == 2)
		assert(leaf.find_children("DoorHingeBarrel_*", "MeshInstance3D", true, false).size() == 3)
		assert(leaf.find_children("DoorHingeCollarTop_*", "MeshInstance3D", true, false).size() == 3)
		assert(leaf.find_children("DoorHingeCollarBottom_*", "MeshInstance3D", true, false).size() == 3)
		assert(leaf.find_child("LeafAstrolabeMedallion", true, false) is MeshInstance3D)
		assert(leaf.find_children("FrameRivet_*", "MeshInstance3D", true, false).size() == 16)
		assert(leaf.find_children("AetherCircuit_*", "MeshInstance3D", true, false).size() == 2)
		assert(leaf.find_child("DoorStateCrystal", true, false) is MeshInstance3D)
		assert(leaf.find_child("*CelestialInterlock", true, false) is Node3D)
	var crest := gate.get_node("HeavenlyStarHalo") as Node3D
	var retired_star := crest.find_child("MSHG_PowerStar", true, false) as MeshInstance3D
	assert(retired_star != null and not retired_star.visible,
		"the superseded pastel power star remains hidden for asset compatibility")
	assert(crest.get_node_or_null("AstrolabeOuterBrassRing") is MeshInstance3D)
	assert(crest.get_node_or_null("AstrolabeEmeraldWisdomCrystal") is MeshInstance3D)
	assert(crest.find_children("AstrolabeGearTooth_*", "MeshInstance3D", true, false).size() == 12)
	assert(crest.find_children("AstrolabeEmeraldJewel_*", "MeshInstance3D", true, false).size() == 3)
	var crown_architecture := gate.get_node("HeavenlyCrownArchitecture") as Node3D
	assert(crown_architecture != null)
	assert(crown_architecture.find_children("*IvoryCrownSweep*", "MeshInstance3D", true, false).size() == 4)
	assert(crown_architecture.find_children("CrownAetherWing_*", "MeshInstance3D", true, false).size() == 2)
	assert(crown_architecture.find_children("*CrownPearl_*", "MeshInstance3D", true, false).size() == 6)
	for indicator_name in ["NOTICE", "UNDERSTAND", "CHOOSE"]:
		var indicator := puzzle.find_child(
			"SanctumIndicatorFace_%s" % indicator_name, true, false) as MeshInstance3D
		assert(indicator != null and indicator.material_override == world.get("_materials").green_glow,
			"all three sanctum indicators use one readable emerald state")

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
	assert(puzzle.is_signal_observatory_complete() and not puzzle.is_powered())
	assert(puzzle.solve_echo_for_test().reason == "completed")
	assert(puzzle.is_powered())
	assert(world.is_island_one_star_gate_open())
	await create_timer(2.1).timeout
	var west := gate.get_node("WestGoldenStarLeaf") as AnimatableBody3D
	var east := gate.get_node("EastGoldenStarLeaf") as AnimatableBody3D
	assert(is_equal_approx(west.rotation.y, deg_to_rad(-96.0)) \
		and is_equal_approx(east.rotation.y, deg_to_rad(96.0)),
		"production leaves finish inside their reserved inward swing envelopes")
	assert(absf(absf(west.position.x) - 5.70) < 0.001 and absf(absf(east.position.x) - 5.70) < 0.001,
		"the two outer hinge axes stay anchored to the portal piers")
	assert((west.find_child("DoorStateCrystal", true, false) as MeshInstance3D).material_override \
		== world.get("_materials").green_glow,
		"the open gate reports its safe traversal state in emerald")
	var west_rotor := threshold_court.find_child("WestHingeDriveRotor", true, false) as Node3D
	assert(absf(west_rotor.rotation.z) > TAU,
		"the rigid drive assembly turns while pulling its leaf carriage")
	print("IslandOneProductionAssetsV26: PASS — detailed controls → coupled puzzle → detailed gate opens")

	world.queue_free()
	await process_frame
	_cleanup()
	quit()


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
