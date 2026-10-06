extends SceneTree

## Records the production Island One quest queue from a player-height camera.
## Every state change uses the same public interaction seam as normal gameplay.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const OUTPUT_STATE := "user://record_mind_spark_island_one_quest_queue.json"

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
	for world_label in _world.find_children("*", "Label3D", true, false):
		(world_label as Label3D).hide()
	_puzzle = _world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(_puzzle != null)
	_player_proxy = Node3D.new()
	_player_proxy.name = "RecordedPlayerProxy"
	_world.add_child(_player_proxy)
	_camera = Camera3D.new()
	_camera.fov = 72.0
	_camera.near = 0.08
	_camera.far = 8000.0
	_world.add_child(_camera)
	_camera.make_current()

	_caption.text = "ISLAND ONE QUEST QUEUE\nQuest 1 must complete before Quest 2 can power the gate"
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
		["echo_question", 3, "Protective question • hopeful response selected"],
	])
	assert(not _puzzle.is_powered())

	var gate := _world.get_island_one_heavenly_star_gate() as Node3D
	_camera.fov = 78.0
	_camera.global_position = gate.to_global(Vector3(0, 7, -28))
	_camera.look_at(gate.to_global(Vector3(0, 14, 0)), Vector3.UP)
	_caption.text = "FINAL QUEUED ACTION • ACTIVATE THE ECHO BEACON\nThe gate remains sealed until both quests are complete"
	await create_timer(1.8).timeout
	var beacon_result := _puzzle.interact_control("echo_beacon")
	assert(beacon_result.accepted and beacon_result.reason == "completed")
	assert(_puzzle.is_powered() and _world.is_island_one_star_gate_open())
	_caption.text = "QUEUE COMPLETE • HEAVENLY GATE POWERED\nBoth leaves swing inward; the route to the next area is clear"
	await create_timer(3.3).timeout
	assert(str(gate.get_meta("gate_state", "")) == "open")
	_caption.text = "RECORDED RESULT\nNotice → Understand → Choose → Connect"
	await create_timer(2.0).timeout
	print("MIND_SPARK_ISLAND_ONE_QUEST_QUEUE_RECORD: PASS")
	if FileAccess.file_exists(OUTPUT_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUTPUT_STATE))
	quit()


func _operate_queue(operations: Array) -> void:
	for operation in operations:
		var control_id := str(operation[0])
		var count := int(operation[1])
		var description := str(operation[2])
		var control := _puzzle.get_node("PuzzleControls/PuzzleControl_%s" % control_id) as Node3D
		_player_proxy.global_position = control.global_position + Vector3(0, 1.0, -4.0)
		_camera.global_position = control.global_position + Vector3(0, 2.0, -6.4)
		_camera.look_at(control.global_position + Vector3.UP * 0.9, Vector3.UP)
		_caption.text = description
		await create_timer(0.55).timeout
		for _press in count:
			var result := _puzzle.interact_nearest(_player_proxy)
			assert(result.accepted, "%s rejected a production interaction" % control_id)
			await create_timer(0.28).timeout
		await create_timer(0.35).timeout


func _add_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	root.add_child(layer)
	var backing := ColorRect.new()
	backing.position = Vector2(24, 24)
	backing.size = Vector2(760, 96)
	backing.color = Color(0.035, 0.055, 0.09, 0.84)
	layer.add_child(backing)
	_caption = Label.new()
	_caption.position = Vector2(46, 40)
	_caption.size = Vector2(720, 72)
	_caption.add_theme_font_size_override("font_size", 24)
	_caption.add_theme_color_override("font_color", Color("fff0bd"))
	_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_caption.add_theme_constant_override("shadow_offset_x", 2)
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(_caption)


func _add_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b9d9e6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("fff1d7")
	environment.ambient_light_energy = 0.45
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-52, -34, 0)
	sunlight.light_color = Color("ffe5b3")
	sunlight.light_energy = 0.82
	sunlight.shadow_enabled = true
	_world.add_child(sunlight)
