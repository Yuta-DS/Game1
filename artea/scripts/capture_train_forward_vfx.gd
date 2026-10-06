extends SceneTree

const OUTPUT_PATH := "res://artifacts/crown_line_forward_movement_vfx.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var world := Node3D.new()
	world.name = "ForwardTrainVFXCaptureWorld"
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

	var train := railway.get_node_or_null("RainbowGalaxyTrain") as AnimatableBody3D
	var movement_vfx := train.get_node_or_null(
		"DirectionalRainbowMovementVFX") as Node3D if train != null else null
	if train == null or movement_vfx == null:
		_fail("live forward movement VFX did not instantiate")
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
	environment_resource.background_color = Color("0d1930")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("c8eaff")
	environment_resource.ambient_light_energy = .60
	environment_resource.tonemap_exposure = .70
	environment.environment = environment_resource
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	sun.light_color = Color("fff1ce")
	sun.light_energy = .95
	sun.shadow_enabled = true
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 53.0
	world.add_child(camera)
	camera.make_current()

	# The production train is synchronized to physics. The focused capture moves
	# the exact runtime body directly so a complete forward wake can be composed
	# in a deterministic still without changing gameplay controls or physics.
	railway.set_process(false)
	train.sync_to_physics = false
	var forward := -train.global_basis.z.normalized()
	var side := forward.cross(Vector3.UP).normalized()
	if side.length_squared() < .01:
		side = Vector3.RIGHT
	for frame_index in 72:
		var motion_delta := forward * lerpf(.20, .72,
			clampf(float(frame_index) / 42.0, 0.0, 1.0))
		train.global_position += motion_delta
		railway.call("_update_directional_movement_vfx", 1.0 / 60.0, motion_delta)
		camera.global_position = train.global_position + side * 30.0 \
			- forward * 29.0 + Vector3.UP * 9.0
		camera.look_at(train.global_position - forward * 12.0 + Vector3.UP * 3.4,
			Vector3.UP)
		await process_frame
	for _frame in 5:
		await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.save_png(OUTPUT_PATH) != OK:
		_fail("could not save the forward movement VFX screenshot")
		return
	print("FORWARD_TRAIN_VFX_CAPTURE: %s" % OUTPUT_PATH)
	quit()


func _fail(message: String) -> void:
	push_error("FORWARD_TRAIN_VFX_CAPTURE: %s" % message)
	quit(1)
