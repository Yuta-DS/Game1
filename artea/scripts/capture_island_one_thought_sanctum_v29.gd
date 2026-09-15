extends SceneTree

## Player-scale quality views of the Thought Sanctum puzzle gateway. This is
## deliberately separate from the golden gate between Island One and Island Two.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const OUTPUT := "res://artifacts/mind_spark_island_one_thought_sanctum_v30"


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
	assert(puzzle != null)
	var sanctum := puzzle.find_child("ThoughtConstellationTarget", true, false) as Node3D
	assert(sanctum != null)
	for label in sanctum.find_children("*", "Label3D", true, false):
		(label as Label3D).show()
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.08
	camera.far = 5000.0
	world.add_child(camera)
	camera.make_current()
	# The selector-gallery approach: the complete gateway and its clear opening.
	camera.global_position = puzzle.to_global(Vector3(0, 6.2, 58.0))
	camera.look_at(puzzle.to_global(Vector3(0, 12.0, 42.0)), Vector3.UP)
	await _save("01_player_approach")
	# A three-quarter architectural view exposes the pylon load path and contained
	# governors without reverting to an overhead map shot.
	camera.fov = 55.0
	camera.global_position = puzzle.to_global(Vector3(-25.0, 11.0, 52.0))
	camera.look_at(puzzle.to_global(Vector3(0, 14.0, 42.0)), Vector3.UP)
	await _save("02_architecture_detail")
	# Stand inside the opening and look back at the crown console to prove the
	# threshold is physically readable at player scale.
	camera.fov = 66.0
	camera.global_position = puzzle.to_global(Vector3(0, 8.0, 49.0))
	camera.look_at(puzzle.to_global(Vector3(0, 19.2, 42.0)), Vector3.UP)
	await _save("03_threshold_and_indicators")
	print("ISLAND_ONE_THOUGHT_SANCTUM_V29_CAPTURE: PASS")
	quit()


func _save(file_name: String) -> void:
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT, file_name]
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("ISLAND_ONE_THOUGHT_SANCTUM_V29_CAPTURE: wrote %s" % path)
