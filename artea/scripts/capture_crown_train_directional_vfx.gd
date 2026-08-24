extends SceneTree

const OUTPUT := "res://artifacts/crown_train_directional_rainbow_vfx.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
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
		_fail("live Crown Train did not build")
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
	environment_resource.background_color = Color("101c38")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("b8ddff")
	environment_resource.ambient_light_energy = 0.52
	environment_resource.tonemap_exposure = 0.72
	environment.environment = environment_resource
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-44.0, -34.0, 0.0)
	sun.light_color = Color("fff0c2")
	sun.light_energy = 0.92
	sun.shadow_enabled = true
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 58.0
	world.add_child(camera)
	camera.make_current()

	# Move the real runtime train along its first authored curve long enough to
	# fill the world-space particle trail, following it with the capture camera.
	for frame in 100:
		var progress := 0.10 + float(frame) / 100.0 * 0.055
		railway.call("_set_train_progress", 0, progress)
		camera.global_position = train.to_global(Vector3(54.0, 17.0, 42.0))
		camera.look_at(train.global_position + train.global_basis.z * 14.0 + Vector3.UP * 4.2,
			Vector3.UP)
		await process_frame
	# Hold the last measured direction while the renderer submits this proof
	# frame; another idle process frame would correctly switch emission off.
	var measured: Dictionary = railway.call("get_directional_vfx_state")
	var capture_direction: Vector3 = measured.movement_direction
	railway.call("_update_directional_movement_vfx", 1.0 / 60.0,
		capture_direction * 6.0)
	railway.set_process(false)
	var state: Dictionary = railway.call("get_directional_vfx_state")
	if not bool(state.emitting):
		_fail("rainbow VFX was not emitting during capture")
		return
	await RenderingServer.frame_post_draw
	var texture := root.get_texture()
	if texture == null:
		_fail("renderer returned no viewport texture")
		return
	var image := texture.get_image()
	if image == null or image.save_png(OUTPUT) != OK:
		_fail("could not save directional VFX proof")
		return
	print("CROWN_TRAIN_DIRECTIONAL_VFX_CAPTURE: PASS — %s" % OUTPUT)
	quit()


func _fail(message: String) -> void:
	push_error("CROWN_TRAIN_DIRECTIONAL_VFX_CAPTURE: %s" % message)
	quit(1)
