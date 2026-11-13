extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1200, 760)
	Engine.max_fps = 30
	var world := Node3D.new()
	root.add_child(world)
	var railway := Node3D.new()
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for frame in 5:
		await process_frame
	railway.set_process(false)
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	railway.get_node("StoryStations").visible = false
	for layer: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	for label: Label3D in world.find_children("*", "Label3D", true, false):
		label.visible = false
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("091a31")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d9edff")
	environment.environment.ambient_light_energy = .6
	environment.environment.tonemap_exposure = .75
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = .9
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.fov = 36
	camera.global_position = train.to_global(Vector3(17, 5.6, -24.4))
	camera.look_at(train.to_global(Vector3(5.5, 3.35, -21.9)))
	var transmission: RefCounted = railway.get("_gear_transmission")
	DirAccess.make_dir_recursive_absolute("res://artifacts/train_gear_frames")
	for frame in 120:
		# Forward, stationary, reverse, stationary; use the runtime controller.
		if frame < 48:
			transmission.advance(.04)
		elif frame >= 60 and frame < 108:
			transmission.advance(-.04)
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		if picture.save_png("res://artifacts/train_gear_frames/frame_%03d.png" % frame) != OK:
			quit(1)
			return
		if frame == 0:
			picture.save_png("res://artifacts/train_gears_fixed.png")
	print("TRAIN_GEAR_CAPTURE: PASS — 120 native frames: forward, stop, reverse, stop")
	quit()

