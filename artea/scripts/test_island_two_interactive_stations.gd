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
	var scanner_marker := scanner.get_node("ProductionStationMarker") as Node3D
	assert(str(scanner_marker.get_meta("presentation_state")) == "inactive",
		"a fresh Island Two station begins with a restrained inactive beacon")
	scanner.interaction_enabled = false
	assert(not scanner.interact(&"capture", 0).accepted)
	scanner.interaction_enabled = true
	assert(not scanner.interact(&"capture", 0).accepted)
	var actor := CharacterBody3D.new()
	world.add_child(actor)
	actor.global_position = scanner.global_position
	actor.set_physics_process(true)
	var panel := preload("res://scripts/mind_spark/island_two_station_panel.gd").new()
	world.add_child(panel)
	panel.open_object(scanner, actor, 18)
	assert(not actor.is_physics_processing())
	var control: Button = null
	for button in panel.find_children("*", "Button", true, false):
		if str(button.get_meta("focus_action", "")) == "adjust0":
			control = button as Button
			break
	assert(control != null)
	actor.global_position += Vector3(100, 0, 0)
	control.pressed.emit()
	await process_frame
	assert(scanner.current_state.get("adjustments", [0, 0, 0]) == [0, 0, 0],
		"the panel must reject input beyond interaction range")
	actor.global_position = scanner.global_position
	control = null
	for button in panel.find_children("*", "Button", true, false):
		if str(button.get_meta("focus_action", "")) == "adjust0":
			control = button as Button
			break
	assert(control != null)
	control.pressed.emit()
	await process_frame
	await process_frame
	assert(scanner.current_state.get("adjustments", []) == [1, 0, 0],
		"the same control must work when the player returns")
	assert(str(scanner_marker.get_meta("presentation_state")) == "active",
		"using a station activates its long-range beacon")
	panel.queue_free()
	await process_frame
	assert(actor.is_physics_processing())
	assert(scanner.interact(&"adjust", 0).accepted)
	assert(scanner.interact(&"capture", 0).accepted)
	assert(scanner.interact(&"adjust", 1).accepted)
	assert(scanner.interact(&"capture", 1).accepted)
	for adjustment in 3:
		assert(scanner.interact(&"adjust", 2).accepted)
	assert(scanner.interact(&"capture", 2).accepted)
	await process_frame
	assert(bool(scanner.current_state.get("completed", false)))
	assert(str(scanner_marker.get_meta("presentation_state")) == "completed",
		"completion changes the station beacon and crown state")
	for id in ["world_one.evidence_scanner", "world_one.memory_board",
			"world_one.logic_gate", "world_one.perspective_lens",
			"world_one.truth_bridge"]:
		var station: QuestObjectBase = null
		for candidate in world.get_quest_objects():
			if candidate.save_id == id:
				station = candidate
				break
		assert(station != null and station.has_node("ProductionStationMarker"))
	world.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("ISLAND_TWO_INTERACTIVE: PASS — live station controls, proximity, pause restoration, and five visible markers")
	quit()
