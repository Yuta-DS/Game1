extends SceneTree

const OUTPUT_PATH := "res://artifacts/crown_line_rainbow_engine_smoke.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var world := Node3D.new()
	world.name = "RainbowSmokeCaptureWorld"
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	world.add_child(player)
	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for _frame in 8:
		await process_frame

	var train := railway.get_node_or_null("RainbowGalaxyTrain") as Node3D
	var detailed := train.get_node_or_null("BlenderCrownLineTrain") as Node3D \
		if train != null else null
	var smoke := detailed.find_child(
		"RainbowSteamChimneySmoke", true, false) as GPUParticles3D \
		if detailed != null else null
	if train == null or smoke == null:
		_fail("rainbow engine smoke did not instantiate")
		return
	for layer in world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	var stations := railway.get_node_or_null("StoryStations") as Node3D
	if stations != null:
		stations.visible = false

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("102038")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("c9eaff")
	environment_resource.ambient_light_energy = .62
	environment_resource.tonemap_exposure = .72
	environment.environment = environment_resource
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("fff0ca")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	world.add_child(sun)

	var camera := Camera3D.new()
	camera.fov = 52.0
	world.add_child(camera)
	camera.make_current()
	var smoke_origin := smoke.global_position
	camera.global_position = smoke_origin \
		+ train.global_basis * Vector3(17.0, 2.5, -15.0)
	camera.look_at(smoke_origin + Vector3.UP * 4.2, Vector3.UP)

	# Fill the chimney plume before taking the proof image. This is the same live
	# particle system used by gameplay; only its normal speed-scaled amount is set
	# to full so all seven colours are readable in one still frame.
	railway.set_process(false)
	smoke.emitting = true
	smoke.amount_ratio = 1.0
	smoke.speed_scale = 1.18
	smoke.restart()
	for _frame in 165:
		await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.save_png(OUTPUT_PATH) != OK:
		_fail("could not save the rainbow smoke screenshot")
		return
	print("RAINBOW_TRAIN_SMOKE_CAPTURE: %s" % OUTPUT_PATH)
	quit()


func _fail(message: String) -> void:
	push_error("RAINBOW_TRAIN_SMOKE_CAPTURE: %s" % message)
	quit(1)
