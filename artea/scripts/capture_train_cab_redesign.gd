extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1440, 1000)
	Engine.max_fps = 30
	var world := Node3D.new()
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	var visuals := Node3D.new()
	visuals.name = "FoxVisuals"
	player.add_child(visuals)
	var fox := load("res://assets3D/characters/fox.glb").instantiate() as Node3D
	fox.name = "Fox"
	fox.scale = Vector3.ONE * 3
	fox.position.y = -.980317
	visuals.add_child(fox)
	world.add_child(player)
	var railway := Node3D.new()
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for frame in 6:
		await process_frame
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	railway.get_node("StoryStations").visible = false
	for layer: CanvasLayer in world.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	for label: Label3D in world.find_children("*", "Label3D", true, false):
		label.visible = false
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("15283f")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e6f1ff")
	environment.environment.ambient_light_energy = .7
	environment.environment.tonemap_exposure = .78
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_color = Color("fff1d5")
	sun.light_energy = .8
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 135, 0)
	fill.light_energy = .45
	world.add_child(fill)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.fov = 46
	var chair_only := "--chair-only" in OS.get_cmdline_user_args()
	await _capture(camera, train, Vector3(-1.5, 4.8, -18.15), Vector3(0, 3.85, -14.9), "train_captain_seat_redesigned")
	if chair_only:
		camera.fov = 53
		await _capture(camera, train, Vector3(2.2, 4.65, -16.6), Vector3(0, 3.85, -14.95), "train_captain_seat_redesigned_detail")
		camera.fov = 46
	player.global_position = railway.call("get_driver_interaction_position")
	railway.call("board_as_driver")
	for frame in 140:
		railway.call("drive_manual", 0.0, 1.0 / 30)
		await process_frame
	await _capture(camera, train, Vector3(-1.5, 4.8, -18.15), Vector3(0, 3.85, -14.9), "train_captain_seat_redesigned_occupied")
	if chair_only:
		print("CAPTAIN_CHAIR_CAPTURE: PASS — front/detail/occupied chair in the actual train")
		quit()
		return
	await _capture(camera, train, Vector3(11.5, 10, -28.5), Vector3(0, 5.5, -17.0), "train_curved_gold_cab")
	await _capture(camera, train, Vector3(8.5, 19, -12.5), Vector3(0, 8.1, -15.85), "train_flat_driver_snowflake")
	camera.fov = 53
	await _capture(camera, train, Vector3(22, 41, 3), Vector3(0, 8, 3), "train_flat_snowflakes_all")
	print("CAB_REDESIGN_CAPTURE: PASS — five native images, empty and occupied seat, cab and all roof sections")
	quit()

func _capture(camera: Camera3D, train: Node3D, eye: Vector3, target: Vector3, label: String) -> void:
	camera.global_position = train.to_global(eye)
	camera.look_at(train.to_global(target))
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://artifacts/%s.png" % label) != OK:
		push_error("Capture failed: " + label)
		quit(1)
