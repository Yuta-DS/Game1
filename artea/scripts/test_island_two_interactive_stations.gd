extends SceneTree
const STORE := "user://test_island_two_interactive.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STORE
	world.get_node("QuestController").enabled = false
	root.add_child(world)
	for frame in 8:
		await process_frame
	var scanner := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER)
	scanner.interaction_enabled = false
	assert(not scanner.interact(&"scan").accepted)
	scanner.interaction_enabled = true
	assert(not scanner.interact(&"fact").accepted)
	assert(scanner.interact(&"scan").accepted)
	assert(not scanner.interact(&"fear").accepted)
	assert(not scanner.current_state.completed)
	assert(scanner.interact(&"fact").accepted)
	scanner.configure(scanner.definition, scanner.save_id, STORE)
	assert(scanner.current_state.evidence_index == 1)
	assert(not scanner.current_state.scanned)
	var actor := CharacterBody3D.new()
	world.add_child(actor)
	actor.global_position = scanner.global_position
	actor.set_physics_process(true)
	var panel := preload("res://scripts/mind_spark/island_two_station_panel.gd").new()
	panel.name = "QuestStationPanel"
	world.add_child(panel)
	panel.open_object(scanner, actor, 18)
	assert(not actor.is_physics_processing())
	var buttons := panel.find_children("*", "Button", true, false)
	assert(buttons.size() == 2)
	(buttons[0] as Button).pressed.emit()
	assert(scanner.current_state.scanned)
	buttons = panel.find_children("*", "Button", true, false)
	assert(buttons.size() == 3)
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280,720)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts/island_two_interactive")
		assert(root.get_texture().get_image().save_png("res://artifacts/island_two_interactive/evidence.png") == OK)
	actor.global_position += Vector3(100,0,0)
	(buttons[1] as Button).pressed.emit()
	assert(scanner.current_state.evidence_index == 1)
	actor.global_position = scanner.global_position
	buttons = panel.find_children("*", "Button", true, false)
	(buttons[1] as Button).pressed.emit()
	assert(scanner.current_state.evidence_index == 2)
	panel.queue_free()
	await process_frame
	assert(actor.is_physics_processing())
	assert(scanner.interact(&"scan").accepted)
	assert(scanner.interact(&"fact").completed)
	assert(scanner.interact(&"fear").reason == "already_complete")
	var board := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.MEMORY_CONSTELLATION)
	board.interaction_enabled = true
	assert(not board.interact().accepted)
	assert(board.interact(&"node", "notice").accepted)
	board.configure(board.definition, board.save_id, STORE)
	assert(board.current_state.sequence == ["notice"])
	assert(board.interact(&"undo").accepted)
	assert(board.current_state.sequence.is_empty())
	assert(board.interact(&"node", "choose").reason == "wrong_link_reset")
	for value in ["notice", "name", "choose"]:
		assert(board.interact(&"node", value).accepted)
	assert(board.current_state.completed)
	var truth := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
	truth.interaction_enabled = true
	assert(not truth.interact().accepted and truth.interact().reason == "choose_supported_statement")
	assert(not truth.interact(&"fear").accepted and not truth.current_state.completed)
	assert(not truth.interact(&"fantasy").accepted and not truth.current_state.completed)
	var truth_result := truth.interact(&"true")
	assert(truth_result.completed and truth.current_state.result.materialised_path)
	world.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("ISLAND_TWO_INTERACTIVE: PASS — locked stations, evidence reasoning, wrong choices, UI buttons, proximity, partial reload, undo and reward preservation")
	quit()
