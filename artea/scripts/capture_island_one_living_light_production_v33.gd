extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const OUTPUT := "res://artifacts/mind_spark_island_one_atelier_architecture_v38"
const TEST_STATE := "user://capture_island_one_living_light_production_v33.json"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	_cleanup()
	root.size = Vector2i(1280, 800)
	root.msaa_3d = Viewport.MSAA_2X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = TEST_STATE
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 1:
		await process_frame
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).hide()
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	puzzle.current_state.colour_prism = 0
	puzzle.current_state.rhythm_prism = 1
	puzzle.current_state.weight_prism = 2
	puzzle.call("_apply_state", false)
	puzzle.interact_control("analysis_console")
	# The capture is an architectural plate, so freeze gameplay simulation after
	# the solved visual state is applied. This keeps the large authored world from
	# recalculating puzzle feedback while each camera frame is rendered.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	camera.fov = 52.0
	camera.near = 0.06
	camera.far = 5000.0
	world.add_child(camera)
	camera.make_current()

	camera.fov = 59.0
	await _view(camera, puzzle, Vector3(-72.0, 10.0, 51.0), Vector3(-51.0, 11.5, 24.0),
		"00_living_light_atelier_player_approach")
	camera.fov = 52.0
	await _view(camera, puzzle, Vector3(-32.5, 6.4, 10.5), Vector3(-39.5, 5.0, 16.0),
		"01_colour_prism_production")
	await _view(camera, puzzle, Vector3(-30.5, 6.4, 35.5), Vector3(-37.5, 5.0, 30.0),
		"02_rhythm_prism_production")
	await _view(camera, puzzle, Vector3(-58.0, 6.4, 18.0), Vector3(-66.0, 5.0, 24.0),
		"03_weight_prism_production")
	camera.fov = 60.0
	await _view(camera, puzzle, Vector3(-72.0, 11.0, 54.0), Vector3(-48.0, 19.0, 22.0),
		"04_living_light_routes_active")
	camera.fov = 54.0
	await _view(camera, puzzle, Vector3(-43.0, 5.2, 14.0), Vector3(-52.0, 3.4, 24.0),
		"05_shared_root_light_well")
	camera.fov = 48.0
	await _view(camera, puzzle, Vector3(-48.0, 5.8, 3.0), Vector3(-57.0, 6.0, 11.0),
		"06_aether_analysis_console")
	print("ISLAND_ONE_LIVING_LIGHT_PRODUCTION_V33_CAPTURE: PASS")
	_cleanup()
	quit()


func _view(camera: Camera3D, puzzle: Node3D, at: Vector3, target: Vector3,
		file_name: String) -> void:
	camera.global_position = puzzle.to_global(at)
	camera.look_at(puzzle.to_global(target), Vector3.UP)
	await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png("%s/%s.png" % [OUTPUT, file_name]) == OK)


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
