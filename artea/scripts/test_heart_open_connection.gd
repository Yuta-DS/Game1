extends "res://scripts/test_river_song.gd"

func _run() -> void:
	create_timer(90).timeout.connect(func(): _release(); push_error("Open connection timed out"); quit(1))
	world = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
	world.test_mode = true
	world.progress.path = "user://open_connection_test.json"
	var fresh = Progress.new()
	fresh.path = world.progress.path
	fresh.commit()
	world.position = Vector3(400, 45, -250)
	world.rotation.y = PI
	root.add_child(world)
	current_scene = world
	for frame in 8: await physics_frame
	world.player.global_position = world.to_global(Vector3(7, 2, 8))
	world._intro()
	check(world.message.text.contains("Plant all three seeds") and world.message.text.contains("both Blight waves") and world.message.text.contains("Retry saving"), "opening explains route, requirements and save recovery")
	world._close()
	check(not world.bridge.visible, "fresh garden crossing is locked")
	for index in 3: world.progress.plant(index, 6)
	world.progress.edit_phrase([0, 2, 1])
	world.progress.solve()
	world.progress.clear_wave(1)
	var save_path: String = world.progress.path
	world.progress.path = "res://missing_connection_directory/save.json"
	check(not world.progress.clear_wave(2), "failed restoration save reported")
	world._apply_restoration()
	check(world.progress.data.complete and not world.bridge.visible, "unsaved completion keeps crossing locked")
	world.progress.path = save_path
	world._help()
	for button in world.options.get_children():
		if button is Button and button.text == "Retry saving": button.pressed.emit()
	check(world.message.text.contains("is open"), "successful retry announces open route")
	world._close()
	for frame in 3: await physics_frame
	check(world.bridge.visible and world.progress.committed.complete, "retry opens saved connection")
	for shape in world.bridge_barrier.get_children():
		if shape is CollisionShape3D: check(shape.disabled, "root barrier removed")
	check(await _walk(Vector3(126, 1, 8)), "restored garden connects to organ without jump")
	check(world.player.is_on_floor(), "organ approach has solid ground")
	check(await _walk(Vector3(7, 1, 8)), "walk from organ back to Feeling Garden")
	world.progress.load_progress()
	world._apply_restoration()
	check(world.bridge.visible and world._river_directions().contains("is open"), "reload preserves open route and directions")
	print("OPEN GARDEN RIVER CONNECTION: all checks passed" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
