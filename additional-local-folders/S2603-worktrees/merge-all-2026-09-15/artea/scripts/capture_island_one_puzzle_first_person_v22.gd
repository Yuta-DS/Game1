extends SceneTree

## Deterministic first-person capture of the real Island One puzzle path.
## Every operation goes through interact_nearest() at the authored station.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const OUTPUT := "res://artifacts/mind_spark_island_one_heavenly_puzzle_v27"
const FRAMES := OUTPUT + "/frames"
const CAPTURE_STATE := "user://capture_island_one_heavenly_puzzle_v27.json"
const FPS := 12
const SIZE := Vector2i(1280, 720)
const EYE_OFFSET := Vector3(0.0, 7.0, -15.5)

var _world: MindSparkWorldOne
var _puzzle: MindSparkIslandOnePuzzle
var _player: Node3D
var _camera: Camera3D
var _phase_label: Label
var _prompt_label: Label
var _status_label: Label
var _frame_index := 0
var _last_feedback := "Walk to the first pressure station."


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_prepare_output()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = SIZE
	root.msaa_3d = Viewport.MSAA_4X

	_world = WorldScene.instantiate() as MindSparkWorldOne
	_world.build_hud = false
	_world.object_state_store_path = CAPTURE_STATE
	var quest := _world.get_node("QuestController") as MindSparkWorldOneQuest
	quest.enabled = false
	root.add_child(_world)
	for _wait in 6:
		await process_frame
	_puzzle = _world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	assert(_puzzle != null)

	# Keep the authored world, but remove distant labels that compete with the
	# player HUD. Puzzle geometry, moving governors and bridge power stay live.
	for label in _world.find_children("*", "Label3D", true, false):
		if label.name not in ["AuthoredThoughtText", "ThoughtJourneyDisplay"]:
			(label as Label3D).hide()
	_add_lighting()
	_player = Node3D.new()
	_player.name = "FirstPersonPlayer"
	_world.add_child(_player)
	_camera = Camera3D.new()
	_camera.name = "PlayerEyeCamera"
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 67.0
	_camera.near = 0.08
	_camera.far = 5000.0
	_world.add_child(_camera)
	_camera.make_current()
	_build_player_hud()

	var start := _puzzle.global_position + Vector3(0, 7.0, -74.0)
	var start_look := _puzzle.global_position + Vector3(0, 5.0, 8.0)
	var locked_gate := _world.get_island_one_heavenly_star_gate()
	var locked_view := locked_gate.to_global(Vector3(0, 7.0, -28.0))
	var locked_focus := locked_gate.to_global(Vector3(0, 14.0, 0))
	_camera.global_position = locked_view
	_camera.look_at(locked_focus, Vector3.UP)
	_phase_label.text = "ISLAND ONE  •  THE SEALED HEAVENLY STAR GATE"
	_prompt_label.text = "THE FOUNDATION CONTINUES • THE GOLDEN THRESHOLD DOES NOT"
	_status_label.text = "Its three orbit sockets echo the unsolved Thought Constellation behind you."
	await _hold(10)
	await _move_camera(locked_view, start, locked_focus, start_look, 14)
	_player.global_position = start - Vector3.UP * 3.5
	_phase_label.text = "ISLAND ONE  •  THE THOUGHT COMPASS"
	_prompt_label.text = "A THOUGHT IS VISITING: “WHAT IF I GET IT WRONG?”"
	_status_label.text = "The goal is not to destroy it. Notice, understand, and choose what comes next."
	await _hold(10)

	await _visit_station("west_regulator", 1, "STEP 1 / 4  •  NOTICE",
		"Hold the thought signal steady without pushing it away.")
	await _visit_station("east_regulator", 2, "STEP 1 / 4  •  NOTICE",
		"Make space around the thought. It is visiting; it is not your identity.")
	await _visit_station("outer_ring", 3, "STEP 2 / 4  •  READ THE LINKED RINGS",
		"Turn Notice twice. Understand moves with it, so watch both symbols.")
	await _visit_station("middle_ring", 2, "STEP 3 / 4  •  PLAN ONE MOVE AHEAD",
		"Turn Understand once. Choose also advances toward its southern star.")
	await _visit_station("inner_ring", 1, "STEP 4 / 4  •  COMPLETE THE CONSTELLATION",
		"Turn Choose once. Notice reverses into its eastern target: all three now align.")
	await _visit_station("confirm", 1, "CONNECT  •  SEND UNDERSTANDING FORWARD",
		"Pull the lever. The difficult thought is transformed, not erased.")

	var solved_from := _camera.global_position
	var solved_look_from := _puzzle.global_position + Vector3(34, 7, 47)
	var gate := _world.get_island_one_heavenly_star_gate()
	var gate_approach := gate.to_global(Vector3(0, 7.0, -26.0))
	var gate_focus := gate.to_global(Vector3(0, 13.0, 0))
	_phase_label.text = "AWARENESS BEARING SECURED  •  STAR CURRENT FLOWING"
	_prompt_label.text = "HEAVENLY STAR GATE POWERING"
	_status_label.text = "The islands were always connected. The solved constellation now retracts the physical golden barrier."
	await _move_camera(solved_from, gate_approach, solved_look_from, gate_focus, 14)
	await _hold(14)
	var beyond_gate := gate.to_global(Vector3(0, 7.0, 26.0))
	_prompt_label.text = "GOLDEN LEAVES OPEN  •  ISLAND TWO AVAILABLE"
	_status_label.text = "Walk through the opened threshold on the original fused-island promenade."
	await _move_camera(_camera.global_position, beyond_gate, gate_focus,
		gate.to_global(Vector3(0, 7.0, 45.0)), 14)
	await _hold(10)

	assert(_puzzle.is_powered())
	assert(_puzzle.get_node("SolvedRouteProjection").visible)
	assert(_world.is_island_one_star_gate_open())
	print("ISLAND_ONE_FIRST_PERSON_VIDEO: %d frames written at %d fps" % [_frame_index, FPS])
	if FileAccess.file_exists(CAPTURE_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAPTURE_STATE))
	quit()


func _visit_station(control_id: String, press_count: int, phase: String, guidance: String) -> void:
	var control := _puzzle.get_node("PuzzleControls/PuzzleControl_%s" % control_id) as Node3D
	var destination := control.global_position + EYE_OFFSET
	var target := control.global_position + Vector3(0, 4.0, -0.8)
	var from := _camera.global_position
	var from_target := _camera.global_position - _camera.global_basis.z * 18.0
	_phase_label.text = phase
	_prompt_label.text = guidance.to_upper()
	_status_label.text = "Walking to %s..." % str(control.get_meta("purpose", control_id))
	await _move_camera(from, destination, from_target, target, 10)
	_player.global_position = control.global_position + Vector3(0, 1.0, -4.0)
	var nearby := _puzzle.prompt_for_player(_player)
	assert(str(nearby.get("control_id", "")) == control_id)
	_prompt_label.text = str(nearby.prompt)
	_status_label.text = str(nearby.status)
	await _hold(3)
	for press_index in press_count:
		var result := _puzzle.interact_nearest(_player)
		assert(result.accepted)
		_last_feedback = str(result.reason).replace("_", " ").to_upper()
		var prompt := _puzzle.prompt_for_player(_player)
		_status_label.text = "%s  •  INPUT %d / %d" % [
			str(prompt.get("status", _last_feedback)), press_index + 1, press_count]
		await _hold(2 if control_id == "confirm" else 4)
	if control_id != "confirm":
		await _hold(3)


func _move_camera(from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3,
		frame_count: int) -> void:
	for index in frame_count:
		var raw := float(index + 1) / float(frame_count)
		var eased := raw * raw * (3.0 - 2.0 * raw)
		# The upgraded controls are taller and wider than the prototypes. Travel
		# along a raised arc so the first-person camera never cuts through a console,
		# compass ring or canopy while walking between stations.
		var travel_arc := Vector3.UP * sin(raw * PI) * minf(12.0, from.distance_to(to) * 0.20)
		_camera.global_position = from.lerp(to, eased) + travel_arc
		_camera.look_at(look_from.lerp(look_to, eased), Vector3.UP)
		_player.global_position = _camera.global_position - Vector3.UP * 3.5
		await _capture_frame()


func _hold(frame_count: int) -> void:
	for _index in frame_count:
		await _capture_frame()


func _capture_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/frame_%04d.jpg" % [FRAMES, _frame_index]
	assert(image.save_jpg(path, 0.91) == OK, "could not write %s" % path)
	_frame_index += 1
	# Keep capture time synchronized with game time so the star pulse and the
	# physical leaf-retraction tween appear in the encoded clip.
	await create_timer(1.0 / float(FPS)).timeout


func _prepare_output() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAMES))
	var directory := DirAccess.open(FRAMES)
	if directory != null:
		for file_name in directory.get_files():
			if file_name.begins_with("frame_") and file_name.ends_with(".jpg"):
				directory.remove(file_name)
	if FileAccess.file_exists(CAPTURE_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAPTURE_STATE))


func _add_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07182b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9fc7d0")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -28, 0)
	key.light_color = Color("ffe3b4")
	key.light_energy = 0.92
	key.shadow_enabled = true
	_world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(22, 145, 0)
	fill.light_color = Color("88c9d2")
	fill.light_energy = 0.34
	_world.add_child(fill)


func _build_player_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 60
	root.add_child(canvas)
	var top := ColorRect.new()
	top.position = Vector2(28, 24)
	top.size = Vector2(570, 48)
	top.color = Color(0.018, 0.055, 0.095, 0.91)
	canvas.add_child(top)
	_phase_label = Label.new()
	_phase_label.position = Vector2(18, 8)
	_phase_label.size = Vector2(535, 34)
	_phase_label.add_theme_font_size_override("font_size", 21)
	_phase_label.add_theme_color_override("font_color", Color("f5dca5"))
	top.add_child(_phase_label)

	var panel := ColorRect.new()
	panel.position = Vector2(220, 602)
	panel.size = Vector2(840, 94)
	panel.color = Color(0.018, 0.055, 0.095, 0.93)
	canvas.add_child(panel)
	_prompt_label = Label.new()
	_prompt_label.position = Vector2(18, 9)
	_prompt_label.size = Vector2(804, 34)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", Color("fff1bf"))
	panel.add_child(_prompt_label)
	_status_label = Label.new()
	_status_label.position = Vector2(18, 48)
	_status_label.size = Vector2(804, 30)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 17)
	_status_label.add_theme_color_override("font_color", Color("9fe8e3"))
	panel.add_child(_status_label)

	var crosshair_h := ColorRect.new()
	crosshair_h.position = Vector2(628, 358)
	crosshair_h.size = Vector2(24, 2)
	crosshair_h.color = Color("f7d991")
	canvas.add_child(crosshair_h)
	var crosshair_v := ColorRect.new()
	crosshair_v.position = Vector2(639, 347)
	crosshair_v.size = Vector2(2, 24)
	crosshair_v.color = Color("f7d991")
	canvas.add_child(crosshair_v)

	var perspective := Label.new()
	perspective.text = "FIRST-PERSON GAMEPLAY CAPTURE  •  AUTOMATED REAL-CONTROL TEST"
	perspective.position = Vector2(742, 28)
	perspective.size = Vector2(510, 30)
	perspective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	perspective.add_theme_font_size_override("font_size", 13)
	perspective.add_theme_color_override("font_color", Color("d4e6e5"))
	canvas.add_child(perspective)
