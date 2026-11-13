extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var web_only := OS.get_cmdline_user_args().has("--web-water")
	var stills_only := OS.get_cmdline_user_args().has("--stills")
	var stage: Node3D
	var ocean: Node3D
	if web_only:
		stage = Node3D.new()
		root.add_child(stage)
		ocean = (load("res://scripts/Water.tscn") as PackedScene).instantiate()
		stage.add_child(ocean)
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/web_water.gdshader")
		ocean.get_node("MeshInstance3D").material_override = material
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(.7,.84,.91)
		stage.add_child(environment)
	else:
		stage = (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
		root.add_child(stage)
		ocean = stage.get_node("Environment/Water")
	for frame in 120:
		await process_frame
	for layer in stage.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	ocean.set_process(false)
	var camera := Camera3D.new()
	camera.far = 1200
	camera.fov = 64
	stage.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/ocean_seismic")
	if not web_only:
		camera.position = Vector3(63, 13, 256)
		camera.look_at(Vector3(31, 1, 202))
		ocean.set("wave_time", 69.0)
		ocean.call("_process", 0.0)
		await _save("harbour_random_waves")
	# A low sea-level view makes the size/spacing of moving wave crests visible.
	camera.position = Vector3(30, 2.3, 274)
	camera.look_at(Vector3(-25, .5, 242))
	for frame in (1 if web_only or stills_only else 192):
		ocean.set("wave_time", 66.0 + float(frame) / 24.0)
		ocean.call("_process", 0.0)
		await _save("web_wave_surface" if web_only else "wave_%03d" % frame)
	print("OCEAN_WAVE_CAPTURE: PASS — " + ("Web shader in Compatibility renderer" if web_only else "in-game wave animation and harbour view"))
	quit()

func _save(name: String) -> void:
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://artifacts/ocean_seismic/%s.png" % name) != OK:
		push_error("Could not save wave capture: " + name)
		quit(1)
