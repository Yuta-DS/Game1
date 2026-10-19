extends SceneTree

## Records the production Island One quest queue from a player-height camera.
## Every state change uses the same public interaction seam as normal gameplay.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const OUTPUT_STATE := "user://capture_heavenly_quest_video.json"

const OUTPUT := "res://artifacts/heavenly_quest_video"
var _events: Array[Dictionary] = []
var _world: MindSparkWorldOne
var _puzzle: MindSparkIslandOnePuzzle
var _camera: Camera3D
var _caption: Label
var _player_proxy: Node3D


func _init() -> void:
	call_deferred("_record")


func _record() -> void:
	if FileAccess.file_exists(OUTPUT_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUTPUT_STATE))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_4X
	_world = WorldScene.instantiate() as MindSparkWorldOne
	_world.build_hud = false
	_world.object_state_store_path = OUTPUT_STATE
	(_world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(_world)
	_add_lighting()
	_add_caption()
	for _frame in 12:
		await process_frame
	_puzzle = _world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(_puzzle != null)
	_player_proxy = Node3D.new()
	_player_proxy.name = "RecordedPlayerProxy"
	_world.add_child(_player_proxy)
	_camera = Camera3D.new()
	_camera.fov = 58.0
	_camera.near = 0.08
	_camera.far = 8000.0
	_world.add_child(_camera)
	_camera.make_current()

	assert(not _puzzle.interact_control("echo_beacon").accepted)
	assert(not _world.is_island_one_star_gate_open())
	_caption.text = "MIND SPARK • AUTOMATED QUEST TEST\nNative game • player-height viewpoints • cuts between stations"
	_camera.global_position = _puzzle.to_global(Vector3(0, 6.2, 58))
	_camera.look_at(_puzzle.to_global(Vector3(0, 10, 35)), Vector3.UP)
	await create_timer(2.2).timeout

	_caption.text = "QUEST 1 • SIGNAL OBSERVATORY\nCompose light, analyse it, regulate pressure, then align the constellation"
	await _operate_queue([
		["colour_prism", 1, "Colour prism • one step"],
		["rhythm_prism", 2, "Rhythm prism • two steps"],
		["weight_prism", 3, "Weight prism • three steps"],
		["analysis_console", 1, "Analysis console • composition observed"],
		["west_regulator", 1, "West regulator • pressure one"],
		["east_regulator", 2, "East regulator • pressure two"],
		["outer_ring", 3, "Outer constellation ring • aligned"],
		["middle_ring", 2, "Middle constellation ring • aligned"],
		["inner_ring", 1, "Inner constellation ring • aligned"],
		["confirm", 1, "Signal Prism formed • Quest 2 unlocked"],
	])
	assert(_puzzle.is_signal_observatory_complete() and not _puzzle.is_powered())
	await create_timer(1.2).timeout

	_caption.text = "QUEST 2 • ECHO GARDEN\nCollect three echoes, classify their signals, then choose a protective question"
	await _operate_queue([
		["echo_collector", 3, "Echo collector • three thought signals gathered"],
		["echo_signal_1", 1, "Echo one • pattern identified"],
		["echo_signal_2", 2, "Echo two • pattern identified"],
		["echo_signal_3", 3, "Echo three • pattern identified"],
		["echo_question", 3, "Protective question • helpful preparation selected"],
		["echo_beacon", 0, "Verification beacon • both quests must be complete"],
	])
	assert(not _puzzle.is_powered())

	var gate := _world.get_island_one_heavenly_star_gate() as Node3D
	_camera.fov = 78.0
	_camera.global_position = gate.to_global(Vector3(0, 4.2, -28))
	_camera.look_at(gate.to_global(Vector3(0, 14, 0)), Vector3.UP)
	_caption.text = "FINAL QUEUED ACTION • ACTIVATE THE ECHO BEACON\nThe gate remains sealed until both quests are complete"
	await create_timer(1.8).timeout
	var beacon_result := _puzzle.interact_nearest(_player_proxy)
	assert(beacon_result.accepted and beacon_result.reason == "completed")
	assert(_puzzle.is_powered() and _world.is_island_one_star_gate_open())
	_caption.text = "QUEUE COMPLETE • HEAVENLY GATE POWERED\nBoth leaves swing inward; the route to the next area is clear"
	await create_timer(3.3).timeout
	_capture_frame("17_gate_open")
	assert(str(gate.get_meta("gate_state", "")) == "open")
	_caption.text = "RECORDED RESULT\nNotice → Understand → Choose → Connect"
	await create_timer(2.0).timeout
	var report := FileAccess.open(OUTPUT + "/test_record.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"result": "PASS", "recording": "native automated interactions; camera cuts; not browser",
		"signal_quest_complete": _puzzle.is_signal_observatory_complete(),
		"echo_quest_complete": _puzzle.is_echo_garden_complete(),
		"gate_open": _world.is_island_one_star_gate_open(), "events": _events}, "\t"))
	report.close()
	print("HEAVENLY_QUEST_VIDEO: PASS — both quests, real proximity inputs, gate locked then open")
	if FileAccess.file_exists(OUTPUT_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUTPUT_STATE))
	quit()


func _operate_queue(operations: Array) -> void:
	for operation in operations:
		var control_id := str(operation[0])
		var count := int(operation[1])
		var description := str(operation[2])
		var control := _puzzle.get_node("PuzzleControls/PuzzleControl_%s" % control_id) as Node3D
		_player_proxy.global_position = control.to_global(Vector3(-4, 1, 0))
		assert(_puzzle.nearest_control(_player_proxy) == control)
		_camera.global_position = control.to_global(Vector3(-7.5, 3.2, -.3))
		_camera.look_at(control.to_global(Vector3(0, 2.9, 0)), Vector3.UP)
		_caption.text = description + "\n" + str(_puzzle.prompt_for_player(_player_proxy).get("prompt", ""))
		await create_timer(0.55).timeout
		for _press in count:
			var result := _puzzle.interact_nearest(_player_proxy)
			assert(result.accepted, "%s rejected a production interaction" % control_id)
			_events.append({"control": control_id, "accepted": result.accepted,
				"reason": result.get("reason", ""), "frame": Engine.get_process_frames()})
			_caption.text = description + "\n" + str(_puzzle.prompt_for_player(_player_proxy).get("status", ""))
			await create_timer(0.55).timeout
		await create_timer(0.85).timeout
		_capture_frame(control_id)


func _add_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	root.add_child(layer)
	var backing := ColorRect.new()
	backing.position = Vector2(24, 24)
	backing.size = Vector2(1232, 112)
	backing.color = Color(0.035, 0.055, 0.09, 0.84)
	layer.add_child(backing)
	_caption = Label.new()
	_caption.position = Vector2(46, 40)
	_caption.size = Vector2(1180, 94)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 20)
	_caption.add_theme_color_override("font_color", Color("fff0bd"))
	_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_caption.add_theme_constant_override("shadow_offset_x", 2)
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_caption)


func _capture_frame(frame_name: String) -> void:
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png(OUTPUT + "/" + frame_name + ".png") == OK)


func _add_lighting() -> void:
	# Use the real containing scene's lighting, not a special studio rig.
	var containing := (load("res://scenes/art_castle_floating_world.tscn") as PackedScene).instantiate()
	for light_name in ["WorldEnvironment", "Sun", "FillLight"]:
		var light := containing.get_node(light_name)
		containing.remove_child(light)
		light.owner = null
		root.add_child(light)
	containing.free()

