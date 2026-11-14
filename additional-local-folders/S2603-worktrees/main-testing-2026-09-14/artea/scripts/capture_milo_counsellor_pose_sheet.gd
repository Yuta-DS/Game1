extends SceneTree

const OUTPUT_PATH := "res://artifacts/milo_counsellor_pose_sheet.png"
const MILO_SCENE := preload("res://scenes/milo_animations.tscn")
const POSES := [
	{"name": "WELCOME", "pose": "welcome", "time": 0.48},
	{"name": "GUIDE", "pose": "guide", "time": 0.72},
	{"name": "MAP", "pose": "map", "time": 0.62},
	{"name": "REFLECT", "pose": "tablet", "time": 0.72},
	{"name": "ENCOURAGE", "pose": "encourage", "time": 0.58},
	{"name": "HEART", "pose": "heart", "time": 0.68},
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1800, 660)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
		OUTPUT_PATH.get_base_dir()))
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("527b91")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a8c3d1")
	environment.ambient_light_energy = 0.28
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.96
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.10
	environment.adjustment_saturation = 1.06
	environment_node.environment = environment
	stage.add_child(environment_node)
	_add_floor(stage)
	_add_light(stage, Vector3(-42.0, -28.0, 0.0), Color("ffe8c8"), 0.82, true)
	_add_light(stage, Vector3(20.0, 142.0, 0.0), Color("8bc9ee"), 0.20, false)
	_add_light(stage, Vector3(-18.0, -158.0, 0.0), Color("ffd4a6"), 0.16, false)

	var player := CharacterBody3D.new()
	player.name = "NewPlayer"
	player.position = Vector3(0.0, 0.0, 10.0)
	stage.add_child(player)

	for index in POSES.size():
		var pose: Dictionary = POSES[index]
		var milo := MILO_SCENE.instantiate() as CharacterBody3D
		milo.set_physics_process(false)
		milo.set("initial_greeting_pause", 999.0)
		stage.add_child(milo)
		await process_frame
		# The scene's ready callback enables its normal town physics; disable it
		# again while the animation sheet waits for the hand-transition tween.
		milo.set_physics_process(false)
		milo.position = Vector3((float(index) - 2.5) * 1.42, 0.02, 0.0)
		milo.rotation = Vector3.ZERO
		var name_label := milo.get_node_or_null("MayorMiloName") as Label3D
		if name_label != null:
			name_label.visible = false
		var journey_aura := milo.find_child("JourneyAura", true, false) as Node3D
		if journey_aura != null:
			journey_aura.visible = false
		milo.call("_on_companion_pose_requested", str(pose.pose))
		await create_timer(0.42).timeout
		var animation_player := milo.find_child("AnimationPlayer", true, false) \
			as AnimationPlayer
		if animation_player != null:
			# The live interaction keeps a soft 0.22 s blend. The sheet samples the
			# settled result so each intended gesture is legible in one frame.
			animation_player.play(animation_player.current_animation, 0.0)
			animation_player.seek(float(pose.time), true)
		# Keep the exact evaluated pose while later instances are assembled.
		milo.process_mode = Node.PROCESS_MODE_DISABLED
		_add_pose_label(stage, milo.position + Vector3(0.0, 2.33, 0.0),
			str(pose.name))

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.12
	camera.position = Vector3(0.0, 1.46, 8.0)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 1.10, 0.0), Vector3.UP)
	camera.make_current()

	for _frame in 18:
		await process_frame
	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Milo counsellor pose capture failed: %s" % error_string(error))
		quit(1)
		return
	print("MILO_COUNSELLOR_POSE_SHEET: PASS • %s" % OUTPUT_PATH)
	quit()


func _add_floor(parent: Node3D) -> void:
	var floor := MeshInstance3D.new()
	floor.name = "MiloStudioFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 10.0)
	floor.mesh = plane
	floor.position = Vector3(0.0, -0.015, 0.0)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("7899aa")
	floor_material.roughness = 0.88
	floor.material_override = floor_material
	parent.add_child(floor)


func _add_light(parent: Node3D, rotation: Vector3, color: Color,
		energy: float, casts_shadow: bool) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = rotation
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = casts_shadow
	if casts_shadow:
		light.shadow_blur = 2.2
	parent.add_child(light)


func _add_pose_label(parent: Node3D, position: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = 36
	label.outline_size = 10
	label.modulate = Color("ffd66e")
	label.outline_modulate = Color("183447")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
