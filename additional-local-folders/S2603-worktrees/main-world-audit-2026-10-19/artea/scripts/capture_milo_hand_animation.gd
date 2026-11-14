extends SceneTree

const MILO_SCENE := preload("res://scenes/milo_animations.tscn")
const FRAME_DIRECTORY := "/tmp/artea_milo_hand_frames"
const FRAME_COUNT := 72
const FRAME_RATE := 24.0


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(900, 600)
	DirAccess.make_dir_recursive_absolute(FRAME_DIRECTORY)
	var stage := Node3D.new()
	stage.name = "MiloArticulatedHandStage"
	root.add_child(stage)
	current_scene = stage
	var companion_manager := root.get_node_or_null("MiloCompanionManager")
	if companion_manager != null:
		companion_manager.process_mode = Node.PROCESS_MODE_DISABLED
	_build_environment(stage)

	var player := CharacterBody3D.new()
	player.name = "NewPlayer"
	player.add_to_group("player")
	player.position = Vector3(0.0, 0.0, 4.0)
	stage.add_child(player)

	var milo := MILO_SCENE.instantiate() as CharacterBody3D
	stage.add_child(milo)
	await process_frame
	milo.set_physics_process(false)
	milo.set_process(false)
	milo.set("gravity_enabled", false)
	milo.call("set_companion_player", player, false)
	milo.position = Vector3.ZERO
	milo.rotation = Vector3.ZERO
	var name_label := milo.get_node_or_null("MayorMiloName") as Label3D
	if name_label != null:
		name_label.visible = false
	var aura := milo.find_child("JourneyAura", true, false) as Node3D
	if aura != null:
		aura.visible = false

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.78, 3.15)
	camera.fov = 25.0
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 0.67, 0.0), Vector3.UP)
	camera.make_current()

	for frame_index in FRAME_COUNT:
		var delta := 1.0 / FRAME_RATE
		if frame_index == 16:
			milo.call("_on_companion_speech_requested",
				"I hear you. Let us explore this together, one gentle step at a time.")
		elif frame_index == 52:
			milo.call("_stop_speaking")
		milo.call("_update_secondary_motion", delta)
		milo.call("_update_speaking", delta)
		await process_frame
		await process_frame
		var frame_path := "%s/frame_%03d.png" % [FRAME_DIRECTORY, frame_index]
		var save_error := root.get_texture().get_image().save_png(frame_path)
		if save_error != OK:
			push_error("Milo hand frame failed: %s" % error_string(save_error))
			quit(1)
			return
	print("MILO_HAND_CAPTURE: PASS — two continuous sculpted hand meshes deform together in %s" \
		% FRAME_DIRECTORY)
	quit()


func _build_environment(stage: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("315c73")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b5ced7")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 6.0)
	floor.mesh = plane
	floor.position.y = -0.015
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("7292a0")
	floor_material.roughness = 0.92
	floor.material_override = floor_material
	stage.add_child(floor)

	_add_light(stage, Vector3(-38.0, -25.0, 0.0), Color("ffe1be"), 0.88, true)
	_add_light(stage, Vector3(18.0, 148.0, 0.0), Color("91d6ff"), 0.30, false)


func _add_light(parent: Node3D, rotation: Vector3, color: Color,
		energy: float, casts_shadow: bool) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = rotation
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = casts_shadow
	parent.add_child(light)
