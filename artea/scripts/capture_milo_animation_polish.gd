extends SceneTree

const MILO_SCENE := preload("res://scenes/milo_animations.tscn")
const FRAME_DIRECTORY := "/tmp/artea_milo_polish_frames"
const FRAME_COUNT := 96
const FRAME_RATE := 24.0


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(720, 720)
	DirAccess.make_dir_recursive_absolute(FRAME_DIRECTORY)
	var stage := Node3D.new()
	stage.name = "MiloAnimationPolishStage"
	root.add_child(stage)
	current_scene = stage
	var companion_manager := root.get_node_or_null("MiloCompanionManager")
	if companion_manager != null:
		companion_manager.process_mode = Node.PROCESS_MODE_DISABLED
	_build_environment(stage)

	var player := CharacterBody3D.new()
	player.name = "NewPlayer"
	player.add_to_group("player")
	player.position = Vector3(3.5, 0.0, 5.0)
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
	camera.position = Vector3(2.65, 1.55, 5.9)
	camera.fov = 30.0
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 1.05, 0.0), Vector3.UP)
	camera.make_current()

	var animation_player := milo.find_child("AnimationPlayer", true, false) \
		as AnimationPlayer
	for frame_index in FRAME_COUNT:
		var delta := 1.0 / FRAME_RATE
		if frame_index < 16:
			milo.call("_set_companion_state", 1) # IDLE_NEAR_PLAYER
			milo.velocity = Vector3.ZERO
			if frame_index == 7:
				milo.call("trigger_blink")
			if animation_player != null:
				animation_player.play("Idle_3", 0.0)
				animation_player.seek(float(frame_index) * delta, true)
		elif frame_index < 80:
			milo.call("_set_companion_state", 2) # FOLLOWING
			milo.velocity = Vector3(0.0, 0.0, 1.10)
			milo.position.z += milo.velocity.z * delta
			milo.call("_advance_cane_gait", delta, 1.10)
			if animation_player != null:
				milo.call("_play_animation", "Cane_Walk")
				milo.call("_update_locomotion_playback", 1.10, 1.10)
		else:
			var stop_weight := 1.0 - float(frame_index - 80) / 15.0
			milo.call("_set_companion_state", 2) # FOLLOWING while settling
			milo.velocity = Vector3(0.0, 0.0, 1.10 * maxf(stop_weight, 0.0))
			milo.position.z += milo.velocity.z * delta
			milo.call("_advance_cane_gait", delta, milo.velocity.z)
			milo.call("_update_locomotion_playback", milo.velocity.z, 1.10)
		milo.call("_update_eye_animation", delta)
		milo.call("_update_secondary_motion", delta)
		milo.call("_update_terrain_grounding", delta)
		milo.call("_update_speaking", delta)
		camera.position.z = 5.9 + milo.position.z
		camera.look_at(milo.position + Vector3(0.0, 1.05, 0.0), Vector3.UP)
		await process_frame
		await process_frame
		var frame_path := "%s/frame_%03d.png" % [FRAME_DIRECTORY, frame_index]
		var save_error := root.get_texture().get_image().save_png(frame_path)
		if save_error != OK:
			push_error("Milo animation frame failed: %s" % error_string(save_error))
			quit(1)
			return
	print("MILO_ANIMATION_POLISH_CAPTURE: PASS • %d live frames in %s" \
		% [FRAME_COUNT, FRAME_DIRECTORY])
	quit()


func _build_environment(stage: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("456f86")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9dbdca")
	environment.ambient_light_energy = 0.31
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.02
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.05
	environment_node.environment = environment
	stage.add_child(environment_node)

	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 8.0)
	floor.mesh = plane
	floor.position.y = -0.015
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("7394a3")
	floor_material.roughness = 0.90
	floor.material_override = floor_material
	stage.add_child(floor)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(10.0, 0.10, 8.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.065
	floor_body.add_child(floor_collision)
	stage.add_child(floor_body)

	_add_light(stage, Vector3(-43.0, -28.0, 0.0), Color("ffe1bb"), 0.92, true)
	_add_light(stage, Vector3(25.0, 145.0, 0.0), Color("8fd5ff"), 0.25, false)
	_add_light(stage, Vector3(-12.0, -150.0, 0.0), Color("ffc98e"), 0.18, false)


func _add_light(parent: Node3D, rotation: Vector3, color: Color,
		energy: float, casts_shadow: bool) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = rotation
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = casts_shadow
	if casts_shadow:
		light.shadow_blur = 2.4
	parent.add_child(light)
