extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_OBJECTS := "user://test_island_one_compass_v20_objects.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var solved_events: Array[Dictionary] = []
	var world := _new_world()
	root.add_child(world)
	for _frame in 4:
		await process_frame
	var compass := world.get_island_one_puzzle()
	assert(compass != null, "Island One owns a functional Aether Compass controller")
	var authored_parts := compass.find_children("*", "Node", true, false).size()
	assert(authored_parts >= 500, "Island One retains a dense editable authored hierarchy")
	print("IslandOneCompassV20: %d live authored nodes after safe batching" % authored_parts)
	compass.puzzle_solved.connect(func(result: Dictionary) -> void: solved_events.append(result))
	assert(compass.get_node_or_null("CompassMachine/OuterCompassRing") != null)
	assert(compass.get_node_or_null("CompassMachine/MiddleCompassRing") != null)
	assert(compass.get_node_or_null("CompassMachine/InnerCompassRing") != null)
	assert(compass.get_node_or_null("WestPressureGauge/PressureNeedle") != null)
	assert(compass.get_node_or_null("EastPressureGauge/PressureNeedle") != null)
	assert(compass.find_children("PuzzleControl_*", "Node3D", true, false).size() == 16,
		"sixteen readable stations cover the Signal Observatory and Echo Garden")
	assert(compass.find_children("*Rune_*", "MeshInstance3D", true, false).size() == 84,
		"the three rings retain 84 individually editable bearing plaques")
	assert(compass.find_children("CanopyGlassTriangle_*", "MeshInstance3D", true, false).size() == 144,
		"the celestial canopy retains all independent triangular panes")
	assert(compass.find_children("CompassGiltSpoke_*", "MeshInstance3D", true, false).is_empty(),
		"the arrival court no longer uses thin radial brass lines")
	assert(compass.find_children("CompassHeartMeridian*", "MeshInstance3D", true, false).is_empty(),
		"the thought focus no longer stacks decorative rings")
	assert(compass.find_children("AwarenessOrbit", "MeshInstance3D", true, false).is_empty())
	assert(compass.find_children("ThoughtFrame*", "MeshInstance3D", true, false).size() == 3)
	assert(compass.find_children("PuzzlePowerConduit*", "MeshInstance3D", true, false).is_empty(),
		"regulator power stays in short floor markers instead of long crossing pipes")
	assert(compass.find_children("RegulatorFloorLink_*", "MeshInstance3D", true, false).size() == 12)
	assert(compass.find_children("MainFloorLink_*", "MeshInstance3D", true, false).size() == 10)
	assert(not compass.interact_control("outer_ring").accepted,
		"rings cannot be guessed before the physical light laboratory is composed")
	assert(compass.interact_control("colour_prism").accepted)
	assert(compass.interact_control("rhythm_prism").accepted)
	assert(compass.interact_control("rhythm_prism").accepted)
	assert(compass.interact_control("weight_prism").accepted)
	assert(compass.interact_control("weight_prism").accepted)
	assert(compass.interact_control("weight_prism").accepted)
	assert(compass.interact_control("analysis_console").reason == "composition_analyzed")
	assert(compass.interact_control("west_regulator").accepted)
	assert(compass.interact_control("east_regulator").accepted)
	assert(compass.interact_control("east_regulator").accepted)
	assert(compass.interact_control("confirm").reason == "alignment_incomplete",
		"an incomplete route gives non-punitive partial alignment feedback")
	assert(compass.solve_for_test().reason == "completed")
	assert(compass.is_powered() and solved_events.size() == 1)
	assert(str(solved_events[0].relic_id) == "echo_seed")
	assert(bool(world.get_meta("island_one_bearing_sigil", false)))
	assert(compass.get_node("SolvedRouteProjection").visible)
	assert(compass.get_node("BridgePowerSocketGlow").visible)
	assert(compass.get_node("BearingSigilReward").visible)
	assert(compass.interact_control("confirm").reason == "replay_started")
	assert(compass.is_powered() and compass.get_node("BridgePowerSocketGlow").visible,
		"replay never removes the earned relic or bridge power")
	world.queue_free()
	await process_frame

	var restored := _new_world()
	root.add_child(restored)
	for _frame in 4:
		await process_frame
	var restored_compass := restored.get_island_one_puzzle()
	assert(restored_compass.is_powered(), "save/reload preserves the Bearing Sigil and route power")
	assert(bool(restored_compass.get_puzzle_state().bearing_sigil_claimed))
	assert(restored_compass.get_node("BridgePowerSocketGlow").visible)
	print("IslandOneCompassV20: all checks passed")
	restored.queue_free()
	await process_frame
	_cleanup()
	quit()


func _new_world() -> MindSparkWorldOne:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = TEST_OBJECTS
	var quest := world.get_node("QuestController") as MindSparkWorldOneQuest
	quest.enabled = false
	return world


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_OBJECTS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_OBJECTS))
