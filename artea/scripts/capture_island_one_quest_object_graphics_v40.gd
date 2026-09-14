extends SceneTree

## Produces one player-height inspection plate for every Island One quest object.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const OUTPUT := "res://artifacts/mind_spark_island_one_quest_object_graphics_v40"
const TEST_STATE := "user://capture_island_one_quest_object_graphics_v40.json"
const CONTROL_IDS := [
	"colour_prism", "rhythm_prism", "weight_prism", "analysis_console",
	"west_regulator", "east_regulator", "outer_ring", "middle_ring", "inner_ring", "confirm",
	"echo_collector", "echo_signal_1", "echo_signal_2", "echo_signal_3",
	"echo_question", "echo_beacon",
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	_cleanup()
	root.size = Vector2i(900, 900)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = TEST_STATE
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 8:
		await process_frame
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	var camera := Camera3D.new()
	camera.fov = 48.0
	camera.near = 0.06
	camera.far = 5000.0
	world.add_child(camera)
	camera.make_current()
	for index in CONTROL_IDS.size():
		var control_id: String = CONTROL_IDS[index]
		var control := puzzle.get_node("PuzzleControls/PuzzleControl_%s" % control_id) as Node3D
		var local_at := puzzle.to_local(control.global_position)
		var cluster_center := Vector3(-52, local_at.y, 24) if local_at.x < -30.0 \
			else Vector3(0, local_at.y, 20)
		var outward := Vector3(local_at.x - cluster_center.x, 0,
			local_at.z - cluster_center.z).normalized()
		if outward.length_squared() < 0.1:
			outward = Vector3(0, 0, -1)
		camera.global_position = puzzle.to_global(local_at + outward * 20.0 + Vector3.UP * 8.0)
		camera.look_at(puzzle.to_global(local_at + Vector3.UP * 6.8), Vector3.UP)
		await process_frame
		RenderingServer.force_draw(false)
		var image := root.get_texture().get_image()
		assert(image != null)
		assert(image.save_png("%s/%02d_%s.png" % [OUTPUT, index + 1, control_id]) == OK)
	print("ISLAND_ONE_QUEST_OBJECT_GRAPHICS_V40_CAPTURE: PASS — 16 inspection plates")
	world.queue_free()
	await process_frame
	_cleanup()
	quit()


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_STATE))
