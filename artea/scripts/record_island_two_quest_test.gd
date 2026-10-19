extends "res://scripts/capture_heavenly_quest_video.gd"
## Isolated station test: prerequisite locks are exercised by the story regression.
const RECORD_STATE := "user://record_island_two_quest_test.json"
const RECORD_DIR := "res://artifacts/island_two_quest_video"
var _station_panel: CanvasLayer

func _record() -> void:
	if FileAccess.file_exists(RECORD_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORD_STATE))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RECORD_DIR))
	root.size = Vector2i(1280,720)
	root.msaa_3d = Viewport.MSAA_4X
	_world = WorldScene.instantiate()
	_world.build_hud = false
	_world.object_state_store_path = RECORD_STATE
	_world.get_node("QuestController").enabled = false
	root.add_child(_world)
	_add_lighting()
	var layer := CanvasLayer.new()
	layer.layer = 90
	root.add_child(layer)
	_caption = Label.new()
	_caption.position = Vector2(24,12)
	_caption.size = Vector2(1232,60)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size",18)
	_caption.add_theme_constant_override("outline_size",8)
	layer.add_child(_caption)
	_player_proxy = Node3D.new()
	_world.add_child(_player_proxy)
	_camera = Camera3D.new()
	_camera.near = .08
	_camera.far = 8000
	_camera.fov = 58
	_world.add_child(_camera)
	_camera.make_current()
	for frame in 12:
		await process_frame
	var scanner := _world.get_object_by_kind(QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER)
	var board := _world.get_object_by_kind(QuestObjectDefinition.ObjectKind.MEMORY_CONSTELLATION)
	scanner.interaction_enabled = true
	board.interaction_enabled = true
	_at_station(scanner)
	_caption.text = "ISLAND TWO • AUTOMATED LOCAL QUEST TEST\nPlayer-height camera • cuts between stations • isolated test save"
	await create_timer(3).timeout
	_shot("01_scanner_player_view")
	_open_station(scanner)
	await _press("Scan evidence", "Reveal the first evidence plate")
	await _press("FEAR", "Test a wrong answer — progress must remain locked")
	assert(int(scanner.current_state.get("evidence_index",0)) == 0)
	_shot("02_wrong_answer_feedback")
	await _press("FACT", "Correct the interpretation using the practice log")
	await _press("Scan evidence", "Read the prediction on plate two")
	await _press("FEAR", "One attempt cannot establish that every future attempt will fail")
	await _press("Scan evidence", "Read the observed action on plate three")
	await _press("FACT", "Three evidence plates secured")
	assert(scanner.current_state.completed)
	await _close_station()
	_at_station(board)
	_caption.text = "MEMORY CONSTELLATION\nConnect observation → interpretation → useful action"
	await create_timer(3).timeout
	_shot("03_memory_player_view")
	_open_station(board)
	await _press("CHOOSE", "Try the wrong first link — the pattern resets gently")
	assert(board.current_state.sequence.is_empty())
	await _press("NOTICE", "Start with what actually happened")
	await _press("Undo", "Undo removes only the last link; evidence stays earned")
	assert(board.current_state.sequence.is_empty() and scanner.current_state.completed)
	await _press("NOTICE", "Observation: one attempt did not work")
	await _press("NAME", "Interpretation: notice the prediction about always failing")
	_shot("04_memory_connections")
	await _press("CHOOSE", "Action: pause and try one smaller step")
	assert(board.current_state.completed)
	_shot("05_memory_complete")
	await _close_station()
	_caption.text = "STATION TEST PASSED\nEvidence secured + memory restored • full story gates tested separately"
	await create_timer(4).timeout
	_shot("06_restored_board")
	var report := FileAccess.open(RECORD_DIR + "/test_record.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"result":"PASS","scope":"Native Compatibility automated station test; GUI button signals; camera cuts; not browser or continuous walking", "evidence_completed":scanner.current_state.completed,"memory_completed":board.current_state.completed,"events":_events},"\t"))
	report.close()
	_world.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RECORD_STATE))
	print("ISLAND_TWO_QUEST_VIDEO: PASS — incorrect answer, correction, evidence capture, wrong memory link, undo, completion")
	quit()

func _at_station(station: QuestObjectBase) -> void:
	_camera.global_position = station.to_global(Vector3(0,1.7,3.4))
	_camera.look_at(station.to_global(Vector3(0,.95,0)))
	_player_proxy.global_position = station.to_global(Vector3(0,.2,2))

func _open_station(station: QuestObjectBase) -> void:
	_station_panel = preload("res://scripts/mind_spark/island_two_station_panel.gd").new()
	_station_panel.name = "QuestStationPanel"
	_world.add_child(_station_panel)
	_station_panel.open_object(station,_player_proxy,18.0)

func _press(prefix: String, description: String) -> void:
	_caption.text = "AUTOMATED ISLAND TWO TEST\n" + description
	await create_timer(1.1).timeout
	var selected: Button
	for button in _station_panel.find_children("*","Button",true,false):
		if button.text.begins_with(prefix):
			selected = button
			break
	assert(selected != null, "Missing visible button: " + prefix)
	selected.pressed.emit()
	_events.append({"button":prefix,"description":description,"frame":Engine.get_process_frames()})
	await create_timer(1.3).timeout

func _close_station() -> void:
	_station_panel.queue_free()
	await process_frame

func _shot(label: String) -> void:
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(RECORD_DIR + "/" + label + ".png") == OK)
