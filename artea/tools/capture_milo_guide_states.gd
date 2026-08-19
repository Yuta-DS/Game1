extends SceneTree

const GuideScene := preload("res://scenes/characters/milo_guide.tscn")
const OUTPUT := "res://artifacts/milo_guide_states.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1440, 760)
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071f33")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8dced")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, -28, 0)
	key.light_color = Color("ffe0b8")
	key.light_energy = 0.82
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22, 140, 0)
	fill.light_color = Color("65c5e6")
	fill.light_energy = 0.30
	stage.add_child(fill)

	var floor_mesh := MeshInstance3D.new()
	var floor := PlaneMesh.new()
	floor.size = Vector2(16, 8)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("173c4d")
	floor_material.roughness = 0.92
	floor.material = floor_material
	floor_mesh.mesh = floor
	stage.add_child(floor_mesh)

	var player := CharacterBody3D.new()
	player.name = "NewPlayer"
	player.position = Vector3(0, 0, 30)
	stage.add_child(player)

	var states := [
		{"label": "IDLE GUIDE", "value": 0},
		{"label": "WALK TO POINT", "value": 1},
		{"label": "GREETING", "value": 2},
		{"label": "SHORT REMINDER", "value": 4},
		{"label": "CELEBRATE ONCE", "value": 5},
	]
	for index in states.size():
		var milo := GuideScene.instantiate() as CharacterBody3D
		milo.name = "MiloGuideState%d" % index
		milo.position = Vector3(-4.4 + index * 2.2, 0, 0)
		milo.set("gravity_enabled", false)
		milo.set("automatic_reminders_enabled", false)
		stage.add_child(milo)
		milo.set_physics_process(false)
		milo.set_process(false)
		milo.call("set_state", int(states[index]["value"]))
		var name_label := milo.get_node_or_null("MayorMiloName") as Label3D
		if name_label != null:
			name_label.visible = false
		var label := Label3D.new()
		label.position = Vector3(0, 2.35, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.text = str(states[index]["label"])
		label.font_size = 34
		label.modulate = Color("ffd66e")
		label.outline_modulate = Color("061523")
		label.outline_size = 10
		milo.add_child(label)

	var title := Label3D.new()
	title.position = Vector3(0, 3.15, 0)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.no_depth_test = true
	title.text = "MAYOR MILO — NON-COMBAT GUIDE STATES"
	title.font_size = 48
	title.modulate = Color("f7e8c6")
	title.outline_modulate = Color("061523")
	title.outline_size = 12
	stage.add_child(title)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 3.0, 11.5)
	camera.fov = 31
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.25, 0))
	camera.make_current()

	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var error := root.get_texture().get_image().save_png(OUTPUT)
	if error != OK:
		push_error("MILO_GUIDE_CAPTURE: %s" % error_string(error))
		quit(error)
		return
	print("MILO_GUIDE_CAPTURE: wrote %s" % OUTPUT)
	quit()
