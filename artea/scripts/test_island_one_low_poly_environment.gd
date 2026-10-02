extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_OBJECTS := "user://test_island_one_low_poly_environment.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = TEST_OBJECTS
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 6:
		await process_frame

	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(puzzle != null)
	var environment := puzzle.get_node("LowPolyCelestialEnvironment") as Node3D
	assert(str(environment.get_meta("design_revision", "")) ==
		"island_one_celestial_campus_v44")
	assert(float(environment.get_meta("clear_route_width_m", 0.0)) >= 18.0)
	assert(bool(environment.get_meta("prototype_lines_retired", false)))

	var gateway := environment.get_node("AstralReturnGatehouse") as Node3D
	assert(gateway.find_children("*GateButtress", "MeshInstance3D", true, false).size() == 2)
	assert(gateway.find_children("*GateWindow", "MeshInstance3D", true, false).size() == 2)
	assert(gateway.find_children("*GateParapetFoundationCollision", "StaticBody3D", true, false).size() == 2)
	for foundation in gateway.find_children("*GateFoundationCollision", "StaticBody3D", true, false):
		assert(absf((foundation as Node3D).position.x) >= 21.0,
			"the forty-two-metre gateway opening remains clear")

	var campus := environment.get_node("SignalObservatoryCampus") as Node3D
	assert(campus.find_children("ProcessionalPaver_*", "MeshInstance3D", true, false).size() == 7)
	assert(campus.find_children("ThresholdMarker_*", "MeshInstance3D", true, false).size() == 6)
	assert(campus.get_node_or_null("ObservatoryCrownPrism") is MeshInstance3D)
	assert(campus.get_node_or_null("LightInstrumentBayBackdrop") is MeshInstance3D)
	assert(campus.get_node_or_null("PressureInstrumentBayWestBackdrop") is MeshInstance3D)
	assert(campus.get_node_or_null("PressureInstrumentBayEastBackdrop") is MeshInstance3D)
	assert(campus.get_node_or_null("AlignmentInstrumentBayWestBackdrop") is MeshInstance3D)
	assert(campus.get_node_or_null("AlignmentInstrumentBayEastBackdrop") is MeshInstance3D)
	assert(campus.find_children("*Gold*", "MeshInstance3D", true, false).is_empty())
	assert(campus.find_children("*Ring*", "MeshInstance3D", true, false).is_empty())

	var landscape := environment.get_node("PurposefulLandscape") as Node3D
	assert(landscape.find_children("CampusTree_*", "Node3D", true, false).size() == 6)
	assert(landscape.find_children("FacetedTrunkCollision", "StaticBody3D", true, false).size() == 6)
	assert(int(landscape.get_meta("canopy_cluster_count", 0)) == 36)

	var available := environment.find_child("StatusAvailable", true, false) as Node3D
	var analyzed := environment.find_child("StatusAnalyzed", true, false) as Node3D
	var complete := environment.find_child("StatusComplete", true, false) as Node3D
	assert(available.visible and not analyzed.visible and not complete.visible)
	puzzle.current_state.composition_analyzed = true
	puzzle._apply_state(false)
	assert(analyzed.visible and not complete.visible,
		"analysis activates the observatory mast status")
	puzzle.current_state.signal_observatory_complete = true
	puzzle._apply_state(false)
	assert(analyzed.visible and complete.visible,
		"Signal Prism completion activates the observatory crown")

	print("IslandOneLowPolyEnvironment: PASS — grounded gate, campus, landscape and status progression")
	world.queue_free()
	await process_frame
	_cleanup()
	quit()


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_OBJECTS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_OBJECTS))
