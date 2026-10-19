extends SceneTree

## Quality-control capture of the redesigned Island One sanctum gate in the
## authored world. This is not the inter-island world portal.

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const OUTPUT := "res://artifacts/mind_spark_island_one_sanctum_gate_v28"


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
	var gate := world.get_island_one_heavenly_star_gate()
	assert(gate != null)
	world._set_island_one_star_gate_open(false, false)
	var camera := Camera3D.new()
	camera.fov = 54.0
	camera.near = 0.08
	camera.far = 5000.0
	world.add_child(camera)
	camera.make_current()
	var focus := gate.to_global(Vector3(0, 14.0, 0))
	camera.global_position = gate.to_global(Vector3(-24.0, 18.0, -43.0))
	camera.look_at(focus, Vector3.UP)
	await _save("01_sealed_architecture")
	camera.fov = 66.0
	camera.global_position = gate.to_global(Vector3(0, 7.0, -28.0))
	camera.look_at(gate.to_global(Vector3(0, 12.0, 0)), Vector3.UP)
	await _save("02_player_approach")
	world._set_island_one_star_gate_open(true, false)
	await _save("03_open_threshold")
	print("ISLAND_ONE_SANCTUM_GATE_V28_CAPTURE: PASS")
	quit()


func _save(file_name: String) -> void:
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT, file_name]
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("ISLAND_ONE_SANCTUM_GATE_V28_CAPTURE: wrote %s" % path)
