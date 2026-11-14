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
	camera.global_position = Vector3(-100,105,125)
	camera.look_at(Vector3(4,0,0))
	root.size = Vector2i(1440,900)
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/heart_garden")
	root.get_texture().get_image().save_png("res://artifacts/heart_garden/overview.png")
	camera.global_position = Vector3(12,8,30)
	camera.look_at(Vector3(12,1,4))
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/heart_garden/drums.png")
	print("HEART_GARDEN_CAPTURE: overview and player-height drums saved")
	quit()
