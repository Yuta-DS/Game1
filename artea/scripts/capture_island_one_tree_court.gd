extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const OUTPUT := "res://artifacts/island_one_tree_court"
const STATE := "user://capture_island_one_tree_court.json"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STATE
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 8:
		await process_frame
	_add_lighting(world)
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.08
	camera.far = 5000.0
	world.add_child(camera)
	camera.make_current()
	var tree := world.find_child("EchoGardenHeroBenchmark", true, false) as Node3D
	assert(tree != null)
	await _save(camera, tree.global_position + Vector3(82, 75, 75),
		tree.global_position + Vector3.UP * 8.0, "01_full_court.png")
	await _save(camera, tree.global_position + Vector3(55, 7, 48),
		tree.global_position + Vector3.UP * 7.0, "02_player_approach.png")
	print("ISLAND_ONE_TREE_COURT_CAPTURE: PASS")
	world.queue_free()
	await process_frame
	if FileAccess.file_exists(STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE))
	quit()


func _save(camera: Camera3D, from: Vector3, target: Vector3, file_name: String) -> void:
	camera.global_position = from
	camera.look_at(target, Vector3.UP)
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	assert(image.save_png("%s/%s" % [OUTPUT, file_name]) == OK)


func _add_lighting(world: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9fb9c5")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d6e2db")
	environment.ambient_light_energy = 0.65
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -28, 0)
	key.light_color = Color("ffe3b4")
	key.light_energy = 1.25
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(22, 145, 0)
	fill.light_color = Color("88c9d2")
	fill.light_energy = 0.55
	world.add_child(fill)
