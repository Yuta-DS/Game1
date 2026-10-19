extends SceneTree

## Acceptance test for the textured, final low-poly Island One quest-object kit.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_STATE := "user://test_island_one_quest_object_final_v41.json"
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
	var controls := puzzle.get_node("PuzzleControls") as Node3D
	for control_id: String in CONTROL_IDS:
		var control := controls.get_node("PuzzleControl_%s" % control_id) as Node3D
		var crown := control.get_node("QuestIdentityCrown") as Node3D
		var art := control.get_node_or_null("HeavenlyQuestInstrument") as Node3D
		if art == null:
			art = control.get_node("WeightPrismBenchmark") as Node3D
		assert(str(art.get_meta("design_revision", "")) == "unified_low_poly_instrument_v43")
		assert(bool(art.get_meta("tree_style_matched", false)))
		for styled_mesh in art.find_children("*", "MeshInstance3D", true, false):
			assert((styled_mesh as MeshInstance3D).material_override != null,
				"%s uses the shared Island 1 palette" % control_id)
		if control_id == "weight_prism":
			# Dedicated physical-balance regression covers the replacing GLB.
			assert(crown.get_parent().has_node("WeightPrismBenchmark"))
			continue
		assert(crown.get_meta("design_revision") == "heavenly_kit_02")
		assert(crown.get_meta("preserve_authored_nodes", false))
		var textured_surfaces := 0
		for instance in art.find_children("*", "MeshInstance3D", true, false):
			var mesh := (instance as MeshInstance3D).mesh
			for surface in mesh.get_surface_count():
				var material := mesh.surface_get_material(surface) as BaseMaterial3D
				assert(material != null and material.albedo_texture != null,
					"%s uses benchmark texture finish" % control_id)
				textured_surfaces += 1
		assert(textured_surfaces >= 2)
		assert(crown.get_node("QuestStateCore") is MeshInstance3D)
	assert(puzzle.interact_control("echo_question").accepted == false,
		"Artwork must not bypass the locked quest sequence")
	print("IslandOneQuestObjectFinalV41: PASS — 16 textured low-poly production assets")
	world.queue_free()
	await process_frame
	_cleanup()
	quit()


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
