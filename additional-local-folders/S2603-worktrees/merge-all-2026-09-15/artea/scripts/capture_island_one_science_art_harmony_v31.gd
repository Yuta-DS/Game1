extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const OUTPUT := "res://artifacts/mind_spark_island_one_science_art_harmony_v31"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 1000)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 10:
		await process_frame
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).hide()
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.08
	camera.far = 5000.0
	world.add_child(camera)
	camera.make_current()

	# Player path view: the elevated tree crowns the observation garden while the
	# puzzle remains visible beyond it instead of becoming a detached landmark.
	camera.global_position = puzzle.to_global(Vector3(-22.0, 7.2, 62.0))
	camera.look_at(puzzle.to_global(Vector3(-49.0, 19.0, 27.0)), Vector3.UP)
	await _save("01_player_science_garden")

	# Close observation view proves the trunk fibres, phyllotaxis canopy and the
	# three experiment instruments are readable at gameplay scale.
	camera.fov = 55.0
	camera.global_position = puzzle.to_global(Vector3(-25.0, 9.0, 5.0))
	camera.look_at(puzzle.to_global(Vector3(-52.0, 20.0, 24.0)), Vector3.UP)
	await _save("02_cognitive_light_tree_detail")

	# Operable puzzle view with its dynamic science-art reading and eight-bearing
	# dials. Only the relevant teaching label is shown.
	var harmony := puzzle.find_child("HarmonyReadingDisplay", true, false) as Label3D
	if harmony != null:
		harmony.show()
	puzzle.current_state.west_regulator = 2
	puzzle.current_state.east_regulator = 1
	puzzle.call("_apply_state", false)
	camera.fov = 64.0
	camera.global_position = puzzle.to_global(Vector3(0, 7.0, 59.0))
	camera.look_at(puzzle.to_global(Vector3(0, 15.0, 42.0)), Vector3.UP)
	await _save("03_creative_harmony_puzzle")
	print("ISLAND_ONE_SCIENCE_ART_HARMONY_V31_CAPTURE: PASS")
	quit()


func _save(file_name: String) -> void:
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT, file_name]
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("ISLAND_ONE_SCIENCE_ART_HARMONY_V31_CAPTURE: wrote %s" % path)
