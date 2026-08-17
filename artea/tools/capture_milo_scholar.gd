extends SceneTree

const MiloScene := preload("res://scenes/characters/milo_scholar.tscn")
const OUTPUT := "res://artifacts/milo_scholar_preview.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(900, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("6f9fbd")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9e5eb")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -32, 0)
	key.light_color = Color("fff2df")
	key.light_energy = 0.62
	key.shadow_enabled = false
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 145, 0)
	rim.light_color = Color("d8edf5")
	rim.light_energy = 0.12
	stage.add_child(rim)

	var floor_mesh := MeshInstance3D.new()
	var floor := PlaneMesh.new()
	floor.size = Vector2(12, 12)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("8cabb9")
	floor_material.roughness = 0.9
	floor.material = floor_material
	floor_mesh.mesh = floor
	stage.add_child(floor_mesh)

	var milo := MiloScene.instantiate() as Node3D
	milo.rotation_degrees.y = 0
	stage.add_child(milo)
	await process_frame
	var animation_player := milo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player != null and animation_player.has_animation("Idle_3"):
		animation_player.play("Idle_3")
		animation_player.seek(0.35, true)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.20, 6.5)
	camera.fov = 27
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.25, 0))
	camera.make_current()

	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var error := root.get_texture().get_image().save_png(OUTPUT)
	if error != OK:
		push_error("MILO_CAPTURE: failed: %s" % error_string(error))
		quit(error)
		return
	print("MILO_CAPTURE: wrote %s" % OUTPUT)
	quit()
