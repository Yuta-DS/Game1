extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 8:
		await process_frame
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(puzzle != null)
	var sanctum := puzzle.find_child("ThoughtConstellationTarget", true, false) as Node3D
	assert(sanctum != null)
	assert(str(sanctum.get_meta("design_revision")) == "v31_science_art_harmony_sanctum")
	assert(float(sanctum.get_meta("clear_opening_width_m")) >= 20.0)
	assert(sanctum.find_children("SanctumIvoryVoussoir_*", "MeshInstance3D", true, false).size() == 20)
	assert(sanctum.find_children("SanctumAetherReveal_*", "MeshInstance3D", true, false).size() == 20)
	assert(sanctum.find_children("SanctumGovernorSpoke_*", "MeshInstance3D", true, false).size() == 12)
	assert(sanctum.find_children("SanctumPylonCapital_*", "MeshInstance3D", true, false).is_empty(),
		"the overlapping arch-spring capital rings remain removed")
	assert(sanctum.find_children("ConstellationActual_*", "Node3D", true, false).size() == 3)
	assert(sanctum.find_children("WisdomFanlightPane_*", "MeshInstance3D", true, false).size() == 6)
	assert(sanctum.find_children("SanctumDialTick_*", "MeshInstance3D", true, false).size() == 24)
	assert(sanctum.find_child("HarmonyReadingDisplay", true, false) is Label3D)
	assert(sanctum.get_node_or_null("WisdomCrownMainBeam") != null)
	assert(sanctum.find_child("ConstellationCrownHalo", true, false) == null)
	var notice := sanctum.find_child("ConstellationActual_NOTICE", true, false) as Node3D
	if puzzle.is_powered() and not bool(puzzle.current_state.replay_active):
		assert(puzzle.interact_control("confirm").reason == "replay_started")
	puzzle.current_state.colour_prism = 0
	puzzle.current_state.rhythm_prism = 1
	puzzle.current_state.weight_prism = 2
	puzzle.current_state.composition_analyzed = true
	puzzle.current_state.west_regulator = 1
	puzzle.current_state.east_regulator = 2
	puzzle.current_state.outer_ring = 0
	puzzle.call("_apply_state", false)
	var before := notice.rotation.z
	assert(puzzle.interact_control("outer_ring").accepted)
	await create_timer(0.5).timeout
	assert(not is_equal_approx(notice.rotation.z, before))
	var result := puzzle.solve_for_test()
	assert(result.reason == "completed")
	assert(puzzle.is_powered())
	print("ISLAND_ONE_THOUGHT_SANCTUM_V29: PASS — clean puzzle gateway, live indicators, clear threshold")
	world.queue_free()
	await process_frame
	quit()
