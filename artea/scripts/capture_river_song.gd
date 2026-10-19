extends SceneTree
func _init() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var progress = load("res://scripts/heart_melody/heart_progress.gd").new()
	progress.path = "user://river_visual.json"
	for index in 3: progress.plant(index, 6)
	progress.edit_phrase([0, 2, 1])
	progress.solve()
	progress.clear_wave(1)
	progress.clear_wave(2)
	for stage in ["valves", "bulbs"]:
		for index in 3: progress.river_step(stage, index)
	progress.river_step("boat")
	for index in 3: progress.river_step("chimes", index)
	progress.river_step("warning")
	progress.river_step("grove")
	progress.river_step("peace")
	var world = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
	world.test_mode = true
	world.progress.path = progress.path
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	world.player.set_physics_process(false)
	world.get_node("HeartHUD").hide()
	for shot in [["overview", Vector3(225, 170, 205), Vector3(205, 0, 8)], ["organ", Vector3(149, 28, 48), Vector3(149, 3, -4)], ["grove", Vector3(300, 45, 62), Vector3(308, 0, 8)]]:
		world.camera.global_position = shot[1]
		world.camera.look_at(shot[2])
		for frame in 5: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../work/river-" + shot[0] + ".png")
	print("RIVER CAPTURE: complete")
	quit()
