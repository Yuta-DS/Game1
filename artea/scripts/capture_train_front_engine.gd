extends SceneTree

const FRONT_OUTPUT := "res://artifacts/crown_line_front_engine_redesign.png"
const THREE_QUARTER_OUTPUT := "res://artifacts/crown_line_front_engine_three_quarter.png"
const DRIVING_ROOF_OUTPUT := "res://artifacts/crown_line_driving_roof_lights.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1500, 900)
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.visible = false
	world.add_child(player)
	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for _frame in 5:
		await process_frame
	var train := railway.get_node_or_null("RainbowGalaxyTrain") as Node3D
	if train == null:
		_fail("train did not build")
		return
	var stations := railway.get_node_or_null("StoryStations") as Node3D
	if stations != null:
		stations.visible = false
	var movement_vfx := train.get_node_or_null("DirectionalRainbowMovementVFX") as Node3D
	if movement_vfx != null:
		movement_vfx.visible = false
	for layer in world.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	for visual in train.find_children("*", "MeshInstance3D", true, false):
		if String(visual.name).contains("Engine_SteamPressureOrb"):
			(visual as MeshInstance3D).visible = false

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("091a31")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("d9edff")
	environment_resource.ambient_light_energy = 0.52
	environment_resource.tonemap_exposure = 0.68
	environment.environment = environment_resource
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46.0, -30.0, 0.0)
	sun.light_color = Color("fff0c4")
	sun.light_energy = 0.88
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
	fill.light_color = Color("8ce3ff")
	fill.light_energy = 0.46
	world.add_child(fill)

	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.fov = 36.0
	camera.global_position = train.to_global(Vector3(0.0, 4.2, -42.0))
	camera.look_at(train.to_global(Vector3(0.0, 3.3, -27.3)), Vector3.UP)
	await _save(FRONT_OUTPUT)
	camera.fov = 43.0
	camera.global_position = train.to_global(Vector3(12.5, 7.2, -42.0))
	camera.look_at(train.to_global(Vector3(0.0, 3.55, -26.0)), Vector3.UP)
	await _save(THREE_QUARTER_OUTPUT)
	camera.fov = 42.0
	camera.global_position = train.to_global(Vector3(10.5, 10.0, -6.5))
	camera.look_at(train.to_global(Vector3(0.0, 7.15, -15.85)), Vector3.UP)
	await _save(DRIVING_ROOF_OUTPUT)
	print("TRAIN_FRONT_CAPTURE: PASS — %s" % DRIVING_ROOF_OUTPUT)
	quit()


func _save(path: String) -> void:
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		_fail("could not save %s" % path)


func _fail(message: String) -> void:
	push_error("TRAIN_FRONT_CAPTURE: %s" % message)
	quit(1)
