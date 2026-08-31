extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_STATE := "user://test_island_one_science_art_harmony_v31.json"


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
		await process_frame
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	var garden := puzzle.get_node("ScienceArtGarden") as Node3D
	var tree := garden.get_node("CognitiveLightTree") as Node3D
	assert(tree.find_children("PhyllotaxisLightLeaf_*", "MeshInstance3D", true, false).size() == 55)
	assert(tree.find_children("TreeSignalFibre_*", "MeshInstance3D", true, false).size() == 36)
	assert(tree.get_node("ElevatedTreeCrownLight").position.y >= 43.0)
	assert(garden.find_children("GoldenAnglePavementPip_*", "MeshInstance3D", true, false).size() == 34)
	for removed_station in ["ColourOppositionStation", "RhythmicGroupingStation", "VisualWeightStation"]:
		assert(garden.get_node_or_null(removed_station) == null,
			"duplicate prototype observation pedestals remain removed")
	var atelier := puzzle.get_node("LivingLightAtelierArchitecture") as Node3D
	assert(str(atelier.get_meta("design_revision")) == "v36_crescent_root_light_atelier")
	assert(atelier.find_children("AtelierFoundationSector_*", "MeshInstance3D", true, false).size() == 24)
	assert(atelier.find_children("AtelierFloorSector_*", "MeshInstance3D", true, false).size() == 24)
	assert(atelier.find_children("*IvoryMedallion", "MeshInstance3D", true, false).size() == 3)
	assert(atelier.get_node_or_null("AtelierRootLightWell") is Node3D)
	assert(puzzle.get_node("HighHeavenlyArrivalLight").position.y >= 42.0)
	assert(puzzle.get_node("HighPuzzleCompositionLight").position.y >= 36.0)
	for prism_id in ["colour", "rhythm", "weight"]:
		var prism_control := puzzle.get_node("PuzzleControls/PuzzleControl_%s_prism" % prism_id) as Node3D
		assert(str(prism_control.get_meta("design_revision")) == "v33_production_living_light_instrument")
		assert(int(prism_control.get_meta("editable_component_count", 0)) >= 96)
		assert(prism_control.find_children("FoundationBolt_*", "MeshInstance3D", true, false).size() == 12)
		assert(prism_control.find_children("CarouselGearTooth_*", "MeshInstance3D", true, false).size() == 24)
		assert(prism_control.find_children("SeedSocketLamp_*", "MeshInstance3D", true, false).size() == 3)
		assert(prism_control.find_children("IrisBlade_*", "MeshInstance3D", true, false).size() == 6)
	assert(puzzle.find_children("LightBeamPulse_*", "MeshInstance3D", true, false).size() == 18)
	assert(puzzle.find_child("ColourScienceInstrument", true, false) != null)
	assert(puzzle.find_child("RhythmScienceInstrument", true, false) != null)
	assert(puzzle.find_child("WeightScienceInstrument", true, false) != null)
	var analysis_control := puzzle.get_node("PuzzleControls/PuzzleControl_analysis_console") as Node3D
	assert(str(analysis_control.get_meta("production_asset")) == "Blender Aether Analysis Console")
	var console := analysis_control.get_node("AetherAnalysisConsoleModel") as Node3D
	assert(console.find_child("AnalysisRotor", true, false) is Node3D)
	assert(console.find_child("AnalysisHeartLens", true, false) is MeshInstance3D)
	for lamp_index in 3:
		assert(console.find_child("EvidenceLamp_%d" % (lamp_index + 1), true, false) is MeshInstance3D)

	var solutions := [
		{"seeds": [1, 2, 3], "regulators": [1, 2], "moves": [3, 2, 1], "targets": [1, 0, 5], "name": "CALM CONTRAST"},
		{"seeds": [2, 3, 1], "regulators": [2, 1], "moves": [1, 3, 2], "targets": [5, 5, 0], "name": "CURIOUS COUNTERPOINT"},
		{"seeds": [3, 1, 2], "regulators": [2, 2], "moves": [2, 1, 3], "targets": [4, 5, 5], "name": "COURAGEOUS ASYMMETRY"},
	]
	for solution_index in solutions.size():
		if solution_index > 0:
			assert(puzzle.interact_control("confirm").reason == "replay_started")
		var solution: Dictionary = solutions[solution_index]
		var prism_ids := ["colour_prism", "rhythm_prism", "weight_prism"]
		for prism_index in 3:
			for _press in int(solution.seeds[prism_index]):
				assert(puzzle.interact_control(prism_ids[prism_index]).accepted)
		assert(puzzle.call("_light_lab_ready"))
		assert(puzzle.interact_control("analysis_console").accepted)
		assert(bool(puzzle.get_puzzle_state().composition_analyzed))
		assert(bool(puzzle.get_puzzle_state().reasoning_bonus))
		assert(puzzle.find_children("LightBeam_*", "MeshInstance3D", true, false) \
			.filter(func(beam: MeshInstance3D) -> bool: return beam.visible).size() == 6)
		for _press in int(solution.regulators[0]):
			assert(puzzle.interact_control("west_regulator").accepted)
		for _press in int(solution.regulators[1]):
			assert(puzzle.interact_control("east_regulator").accepted)
		for _press in int(solution.moves[0]):
			assert(puzzle.interact_control("outer_ring").accepted)
		for _press in int(solution.moves[1]):
			assert(puzzle.interact_control("middle_ring").accepted)
		for _press in int(solution.moves[2]):
			assert(puzzle.interact_control("inner_ring").accepted)
		var state := puzzle.get_puzzle_state()
		assert([state.outer_ring, state.middle_ring, state.inner_ring] == solution.targets)
		assert(puzzle.interact_control("confirm").reason == "completed")
		assert(str(puzzle.get_thought_journey().harmony) == solution.name)
	print("ISLAND_ONE_SCIENCE_ART_HARMONY_V31: PASS — golden-angle garden + three creative solutions")
	world.queue_free()
	await process_frame
	_cleanup()
	quit()


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
