extends SceneTree

## Player-perspective proof of the complete Science-Art Harmony puzzle loop.
## Run with Godot's Movie Maker so every interaction is recorded deterministically.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const TEST_STATE := "user://capture_island_one_puzzle_test_video_v31.json"

var _camera: Camera3D
var _puzzle: MindSparkIslandOnePuzzle
var _title: Label
var _status: Label


func _init() -> void:
	call_deferred("_record")


func _record() -> void:
	_cleanup()
	root.size = Vector2i(1600, 900)
	root.msaa_3d = Viewport.MSAA_4X
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = TEST_STATE
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 12:
		await process_frame
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).hide()
	_puzzle = world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	var harmony_label := _puzzle.find_child("HarmonyReadingDisplay", true, false) as Label3D
	if harmony_label != null:
		harmony_label.show()
	_camera = Camera3D.new()
	_camera.fov = 68.0
	_camera.near = 0.08
	_camera.far = 5000.0
	world.add_child(_camera)
	_camera.make_current()
	_build_overlay(world)

	_title.text = "MIND SPARK • CREATIVE HARMONY TEST"
	_status.text = "OBSERVE THE THOUGHT MACHINE • THREE HARMONIES CAN SOLVE IT"
	_set_view(Vector3(0, 7.0, 69.0), Vector3(0, 13.0, 42.0))
	await create_timer(2.4).timeout

	await _operate_station("colour_prism", 1,
		"1 • ROUTE THE THOUGHT SEED", "COLOUR LENS • CYAN LIGHT EXTERNALIZES THE THOUGHT")
	await _operate_station("rhythm_prism", 2,
		"2 • ROUTE THE FEELING SEED", "RHYTHM LENS • LAVENDER LIGHT MAKES THE SIGNAL OBSERVABLE")
	await _operate_station("weight_prism", 3,
		"3 • ROUTE THE CHOICE SEED", "VISUAL-WEIGHT LENS • EACH SEED MAY BE USED ONLY ONCE")
	_title.text = "LIVING LIGHT COMPOSITION VALID"
	_status.text = "THOUGHT → TREE • FEELING → CONSTELLATION • CHOICE → COMPASS HEART"
	await _move_camera(Vector3(-20.0, 9.0, 55.0), Vector3(-48.0, 20.0, 24.0), 0.9)
	await create_timer(2.6).timeout
	await _operate_station("west_regulator", 1,
		"4 • NOTICE THE SIGNAL", "WARM PRESSURE: 1 • HOLD THE THOUGHT WITHOUT OBEYING IT")
	await _operate_station("east_regulator", 2,
		"5 • CREATE SPACE", "COOL PRESSURE: 2 • CALM CONTRAST DISCOVERED")
	await _operate_station("outer_ring", 3,
		"6 • COMPOSE NOTICE", "EACH PRESS MOVES NOTICE +1 AND UNDERSTAND +2")
	await _operate_station("middle_ring", 2,
		"7 • COMPOSE UNDERSTANDING", "EACH PRESS MOVES UNDERSTAND +1 AND CHOOSE +2")
	await _operate_station("inner_ring", 1,
		"8 • REBALANCE THE WHOLE", "CHOOSE +1 • NOTICE −2 • ALL THREE NOW ALIGN")

	await _move_to_station("confirm")
	_title.text = "9 • TEST THE COMPOSITION"
	_status.text = "NOTICE • UNDERSTAND • CHOOSE"
	await create_timer(1.0).timeout
	var completion := _puzzle.interact_control("confirm")
	assert(completion.reason == "completed")
	_status.text = "CALM CONTRAST ACCEPTED • STAR-GATE POWERED • WISDOM SIGIL SECURED"
	await create_timer(2.2).timeout

	_title.text = "PUZZLE TEST PASSED"
	_status.text = "COMPLEMENTARY BALANCE • COGNITIVE DEFUSION • HOPEFUL RESPONSE"
	await _move_camera(Vector3(0, 7.0, 61.0), Vector3(0, 15.0, 42.0), 1.0)
	await create_timer(3.0).timeout
	_cleanup()
	print("ISLAND_ONE_PUZZLE_TEST_VIDEO_V31: PASS")
	quit()


func _operate_station(control_id: String, presses: int, heading: String, explanation: String) -> void:
	await _move_to_station(control_id)
	_title.text = heading
	_status.text = explanation
	await create_timer(0.8).timeout
	for press_index in presses:
		var result := _puzzle.interact_control(control_id)
		assert(result.accepted)
		_status.text = "%s   •   INPUT %d / %d" % [explanation, press_index + 1, presses]
		await create_timer(0.82).timeout
	await create_timer(0.55).timeout


func _move_to_station(control_id: String) -> void:
	var control := _puzzle.get_node("PuzzleControls/PuzzleControl_%s" % control_id) as Node3D
	var local_at := _puzzle.to_local(control.global_position)
	var visual_target := Vector3(0, 11.0, 19.0) if local_at.z < 0.0 else Vector3(0, 15.5, 42.0)
	var outward := Vector3(local_at.x - visual_target.x, 0.0, local_at.z - visual_target.z).normalized()
	var camera_at := local_at + outward * 5.2 + Vector3.UP * 3.8
	var look_at := local_at.lerp(visual_target, 0.54) + Vector3.UP * 2.0
	await _move_camera(camera_at, look_at, 0.72)


func _move_camera(local_at: Vector3, local_look: Vector3, duration: float) -> void:
	var target_position := _puzzle.to_global(local_at)
	var start_position := _camera.global_position
	var start_basis := _camera.global_basis
	var dummy := Node3D.new()
	_puzzle.add_child(dummy)
	dummy.global_position = target_position
	dummy.look_at(_puzzle.to_global(local_look), Vector3.UP)
	var target_basis := dummy.global_basis
	dummy.queue_free()
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(weight: float) -> void:
		_camera.global_position = start_position.lerp(target_position, weight), 0.0, 1.0, duration)
	tween.tween_method(func(weight: float) -> void:
		_camera.global_basis = start_basis.slerp(target_basis, weight), 0.0, 1.0, duration)
	await tween.finished


func _set_view(local_at: Vector3, local_look: Vector3) -> void:
	_camera.global_position = _puzzle.to_global(local_at)
	_camera.look_at(_puzzle.to_global(local_look), Vector3.UP)


func _build_overlay(parent: Node) -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	parent.add_child(canvas)
	var shade := ColorRect.new()
	shade.position = Vector2(38, 32)
	shade.size = Vector2(980, 108)
	shade.color = Color(0.025, 0.055, 0.070, 0.82)
	canvas.add_child(shade)
	_title = Label.new()
	_title.position = Vector2(62, 46)
	_title.size = Vector2(1200, 42)
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color("ffe4a0"))
	canvas.add_child(_title)
	_status = Label.new()
	_status.position = Vector2(62, 91)
	_status.size = Vector2(1450, 34)
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Color("c9fff6"))
	canvas.add_child(_status)


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
