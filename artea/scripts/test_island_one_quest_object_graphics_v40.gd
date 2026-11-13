extends SceneTree

## Verifies that every Island One quest interaction has a distinct physical
## graphic and readable live state, while preserving the production quest flow.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_STATE := "user://test_island_one_quest_object_graphics_v40.json"
const CONTROL_IDS := [
	"colour_prism", "rhythm_prism", "weight_prism", "analysis_console",
	"west_regulator", "east_regulator", "outer_ring", "middle_ring", "inner_ring", "confirm",
	"echo_collector", "echo_signal_1", "echo_signal_2", "echo_signal_3",
	"echo_question", "echo_beacon",
]


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
	assert(puzzle.find_children("EchoRootConduit_*", "Node3D", true, false).is_empty(),
		"Garden quest routes must not draw permanent lines across the court")
	assert(puzzle.find_children("EchoRootPulse_*", "MeshInstance3D", true, false).size() == 18,
		"Garden progress still has six three-step pulses")
	var controls := puzzle.get_node("PuzzleControls") as Node3D
	var roles := {}
	for control_id: String in CONTROL_IDS:
		var control := controls.get_node("PuzzleControl_%s" % control_id) as Node3D
		var crown := control.get_node("QuestIdentityCrown") as Node3D
		var state_core := crown.get_node("QuestStateCore") as MeshInstance3D
		var purpose_label := control.get_node("QuestPurposeLabel") as Label3D
		assert(control.has_node("HeavenlyQuestInstrument") or control.has_node("WeightPrismBenchmark"),
			"%s has a shaped Blender instrument" % control_id)
		assert(state_core != null and state_core.has_meta("feedback_states"),
			"%s has a visible state jewel" % control_id)
		assert(not purpose_label.text.is_empty() and not str(
			purpose_label.get_meta("interaction_verb", "")).is_empty(),
			"%s has a readable name and physical interaction verb" % control_id)
		assert(purpose_label.font_size >= 42 and purpose_label.pixel_size >= 0.008
			and purpose_label.outline_size >= 14,
			"%s names must remain legible from the player approach" % control_id)
		assert(purpose_label.visibility_range_end == 28.0
			and purpose_label.visibility_range_end_margin == 3.0,
			"%s labels must remain near-field guidance instead of horizon clutter" % control_id)
		assert(bool(purpose_label.get_meta("player_camera_readable", false)),
			"%s records the production-camera readability contract" % control_id)
		var role := str(crown.get_meta("graphic_role", ""))
		assert(not role.is_empty() and not roles.has(role),
			"%s has a unique visual-semantic role" % control_id)
		roles[role] = true
	assert(roles.size() == CONTROL_IDS.size())

	var colour_core := controls.get_node(
		"PuzzleControl_colour_prism/QuestIdentityCrown/QuestStateCore") as MeshInstance3D
	assert(str(colour_core.get_meta("visual_state", "")) == "current")
	assert(puzzle.interact_control("colour_prism").accepted)
	await process_frame
	assert(str(colour_core.get_meta("visual_state", "")) == "complete")

	for operation in [
		["rhythm_prism", 2], ["weight_prism", 3], ["analysis_console", 1],
		["west_regulator", 1], ["east_regulator", 2],
		["outer_ring", 3], ["middle_ring", 2], ["inner_ring", 1], ["confirm", 1],
	]:
		for _press in int(operation[1]):
			assert(puzzle.interact_control(str(operation[0])).accepted)
	assert(puzzle.is_signal_observatory_complete() and not puzzle.is_powered())
	assert(puzzle.solve_echo_for_test().reason == "completed")
	await process_frame
	for control_id: String in CONTROL_IDS:
		var state_core := controls.get_node(
			"PuzzleControl_%s/QuestIdentityCrown/QuestStateCore" % control_id) as MeshInstance3D
		assert(str(state_core.get_meta("visual_state", "")) == "powered")

	print("IslandOneQuestObjectGraphicsV40: PASS — 16 distinct graphics + live state feedback")
	world.queue_free()
	await process_frame
	_cleanup()
	quit()


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
