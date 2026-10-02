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
		"island_one_celestial_campus_v45")
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
	var court := campus.get_node("CentralObservatoryCourt") as Node3D
	assert(float(court.get_meta("clear_movement_diameter_m", 0.0)) >= 40.0)
	assert(float(court.get_meta("station_clearance_m", 0.0)) >= 8.0)
	assert(court.find_children("CyanCompassWedge_*", "MeshInstance3D", true, false).size() == 8)
	var gardens := campus.get_node("OpenInstrumentGardens") as Node3D
	assert(int(gardens.get_meta("garden_count", 0)) == 5)
	assert(bool(gardens.get_meta("backdrop_walls_removed", false)))
	assert(gardens.get_child_count() == 5)
	assert(gardens.find_children("GardenPost_*Collision", "StaticBody3D", true, false).size() == 10)
	assert(gardens.find_children("CharcoalPlanterFoundationCollision", "StaticBody3D", true, false).size() == 5)
	assert(campus.find_children("*Backdrop*", "MeshInstance3D", true, false).is_empty())
	assert(campus.find_children("*Gold*", "MeshInstance3D", true, false).is_empty())
	assert(campus.find_children("*Ring*", "MeshInstance3D", true, false).is_empty())


	var instrument := puzzle.find_child("ThoughtConstellationTarget", true, false) as Node3D
	var dial_array := instrument.get_node("StateDialArray") as Node3D
	assert(int(dial_array.get_meta("dial_count", 0)) == 3)
	assert(float(dial_array.get_meta("beam_clearance_m", 0.0)) > 0.0)
	var notice_pod := dial_array.get_node("NOTICEInstrumentPod") as Node3D
	var understand_pod := dial_array.get_node("UNDERSTANDInstrumentPod") as Node3D
	var choose_pod := dial_array.get_node("CHOOSEInstrumentPod") as Node3D
	assert(is_equal_approx(understand_pod.position.x - notice_pod.position.x,
		choose_pod.position.x - understand_pod.position.x))
	assert(is_equal_approx(notice_pod.position.y, understand_pod.position.y)
		and is_equal_approx(understand_pod.position.y, choose_pod.position.y))
	for pod in [notice_pod, understand_pod, choose_pod]:
		assert(pod.get_node_or_null("IvoryOuterCase") is MeshInstance3D)
		assert(pod.get_node_or_null("MutedCyanFace") is MeshInstance3D)
		assert(pod.get_node_or_null("CharcoalInnerBezel") is MeshInstance3D)
		assert(pod.get_node_or_null("IntegratedNameplate") is MeshInstance3D)
		assert(pod.get_node_or_null("PodMountSpine") is MeshInstance3D)
		assert(pod.find_children("DialTick_*", "MeshInstance3D", true, false).size() == 8)
	assert(instrument.find_children("ConstellationActual_*", "Node3D", true, false).size() == 3)
	assert(instrument.find_children("ConstellationTarget_*", "Node3D", true, false).size() == 3)
	assert(instrument.find_children("ConstellationGiltBezel_*", "MeshInstance3D", true, false).is_empty())
	assert(instrument.get_node_or_null("CrownDormantCrystal") is MeshInstance3D)
	var completion_crystal := instrument.get_node("CrownCompletionCrystal") as MeshInstance3D
	assert(not completion_crystal.visible)
	var targets := puzzle._active_ring_targets()
	puzzle.current_state.outer_ring = targets[0]
	puzzle.current_state.middle_ring = targets[1]
	puzzle.current_state.inner_ring = targets[2]
	puzzle._apply_state(false)
	assert(completion_crystal.visible, "matching all three dials activates the crown crystal")

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
