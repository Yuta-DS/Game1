extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node3D = load("res://scenes/heart_melody/heart_garden_preview.tscn").instantiate()
	scene.get_node("HeartMelodyWorld").persist_progress = false
	scene.get_node("HeartMelodyWorld").save_path = "user://heart_capture_unused.json"
	root.add_child(scene)
	await process_frame
	var world = scene.get_node("HeartMelodyWorld")
	world.hud.visible = false
	scene.get_node("Player3D/CombatHelpHUD").visible = false
	var camera: Camera3D = scene.get_node("Camera3D")
	camera.set_process(false)
	camera.set_process_input(false)
	root.size = Vector2i(1440,900)
	DirAccess.make_dir_recursive_absolute("res://artifacts/heart_garden")
	await _shot(camera, "overview_silent", Vector3(8, 145, 165), Vector3(8, 0, 0))
	await _shot(camera, "arrival_gate", Vector3(-83, 7, 15), Vector3(-94, 4, 0))
	await _shot(camera, "quiet_meadow", Vector3(-56, 32, 52), Vector3(-43, 0, 2))
	await _shot(camera, "planter_court", Vector3(-25, 24, 47), Vector3(-23, 0, 0))
	await _shot(camera, "drum_lawn", Vector3(31, 19, 40), Vector3(29, 0.6, 0))
	await _shot(camera, "clearing_one", Vector3(58, 14, 5), Vector3(58, 0.6, -20))
	await _shot(camera, "clearing_two", Vector3(74, 16, 42), Vector3(74, 0.6, 18))
	for planter_index in 3: world.state.plant(planter_index, ["joy", "peace", "hope"][planter_index])
	for symbol in world.state.PHRASE: world.state.enter_note(symbol)
	world.state.confirm_phrase()
	world.state.record_defeat("garden.moth.1")
	world.state.finish_wave(["garden.moth.1"])
	world.state.record_defeat("garden.moth.2")
	world.state.record_defeat("garden.slime.1")
	world.state.finish_wave(["garden.moth.2", "garden.slime.1"])
	world._restore()
	await create_timer(1.2).timeout
	await _shot(camera, "overview_restored", Vector3(8, 145, 165), Vector3(8, 0, 0))
	await _shot(camera, "restored_crossing", Vector3(106, 12, 25), Vector3(108, 1, 0))
	world.hud.visible = true
	await _shot(camera, "desktop_hud", Vector3(28, 10, 23), Vector3(34, 1, 0), false)
	root.size = Vector2i(480,800)
	world._layout_ui()
	await _shot(camera, "mobile_hud", Vector3(28, 10, 23), Vector3(34, 1, 0), false)
	print("HEART_GARDEN_CAPTURE: ten runtime acceptance views saved")
	quit()


func _shot(camera: Camera3D, label: String, position: Vector3, target: Vector3, hide_hud := true) -> void:
	var world = camera.get_parent().get_node("HeartMelodyWorld")
	world.hud.visible = not hide_hud
	camera.global_position = position
	camera.look_at(target)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/heart_garden/%s.png" % label)
