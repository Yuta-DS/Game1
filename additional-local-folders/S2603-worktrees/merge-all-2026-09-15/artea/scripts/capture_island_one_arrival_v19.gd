extends "res://scripts/capture_mind_spark_islands_v11.gd"

const OUTPUT := "res://artifacts/island_one_arrival_v19"


func _save_view(name: String) -> void:
	for _frame in 12:
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	assert(root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK)
	print("ISLAND_ONE_V19_CAPTURE: " + name)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1800, 1400)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_island_one_v19.json"
	root.add_child(world)
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).hide()
	_lighting(world)
	var centre := world.get_zone_position("01_world_gate_landing")
	var camera := _camera(world, 300.0,
		centre + Vector3(210, 155, 250), centre + Vector3(0, -35, 5))
	camera.near = 0.1
	camera.far = 8000.0
	await _save_view("01_island_one_complete")
	camera.size = 132.0
	camera.position = centre + Vector3(105, 55, -145)
	camera.look_at(centre + Vector3(0, 15, -10))
	await _save_view("02_glass_station_and_twin_towers")
	camera.size = 112.0
	camera.position = centre + Vector3(72, 42, 130)
	camera.look_at(centre + Vector3(0, 14, -20))
	await _save_view("03_processional_arrival_axis")
	quit()
