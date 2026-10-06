extends Node3D

const MODEL = preload("res://milo_fullres.glb")
const CLIPS = ["Idle", "Walking_A", "Greet", "Guide", "Speak", "Cane_Hold", "Hand_Mechanics"]
var model: Node3D
var player: AnimationPlayer
var camera: Camera3D
var status: Label
var yaw := 0.32
var zoom := 4.2
var selected := "Idle"
var moving := false
var walk_clock := 0.0
var hand_closeup := false
var skeleton: Skeleton3D

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	model = MODEL.instantiate()
	add_child(model)
	player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	for clip in CLIPS:
		if player.has_animation(clip):
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("071522")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b5c7dc")
	environment.environment.ambient_light_energy = 0.22
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 0.22
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 6.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 140, 0)
	fill.light_energy = 0.14
	add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("142330")
	floor_material.roughness = 0.9
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 35
	_update_camera()
	var ui := CanvasLayer.new()
	add_child(ui)
	var panel := VBoxContainer.new()
	panel.position = Vector2(24, 20)
	ui.add_child(panel)
	var title := Label.new()
	title.text = "MILO  /  LOCAL RIG REVIEW"
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)
	var note := Label.new()
	note.text = "Head seated into shoulders • No visible neck line • Layered moustache • 7 clips • Local candidate"
	note.add_theme_font_size_override("font_size", 15)
	panel.add_child(note)
	var buttons := HBoxContainer.new()
	panel.add_child(buttons)
	for clip in CLIPS:
		var button := Button.new()
		button.text = clip.replace("_", " ")
		button.pressed.connect(_play.bind(clip))
		buttons.add_child(button)
	var controls := HBoxContainer.new()
	panel.add_child(controls)
	var slow := Button.new()
	slow.text = "0.5× / 1×"
	slow.pressed.connect(func(): player.speed_scale = 1.0 if player.speed_scale < 1.0 else 0.5)
	controls.add_child(slow)
	var pause := Button.new()
	pause.text = "Pause / resume"
	pause.pressed.connect(func():
		if player.is_playing(): player.pause()
		else: player.play())
	controls.add_child(pause)
	var hands := Button.new()
	hands.text = "Hand close-up / full body"
	hands.pressed.connect(func():
		hand_closeup = not hand_closeup
		zoom = 0.95 if hand_closeup else 4.2
		_update_camera())
	controls.add_child(hands)
	var travel := CheckButton.new()
	travel.text = "Walk with ground travel"
	travel.toggled.connect(func(value): moving = value; walk_clock = 0.0; model.position = Vector3.ZERO)
	controls.add_child(travel)
	status = Label.new()
	panel.add_child(status)
	var hint := Label.new()
	hint.text = "Drag to orbit • Scroll to zoom • Source artwork is in the parent reference folder"
	ui.add_child(hint)
	hint.position = Vector2(24, 816)
	_play("Idle")
	if "--capture-preview" in OS.get_cmdline_user_args():
		_capture_preview.call_deferred()

func _capture_preview() -> void:
	await get_tree().process_frame
	for clip in CLIPS:
		_play(clip)
		player.advance(0.2)
		assert(player.current_animation == clip)
	_play("Idle")
	# Do not capture a residual crossfade from the last hand-test clip.
	player.play("Idle", 0.0)
	player.seek(0.3, true)
	player.advance(0)
	player.pause()
	for i in 12: await get_tree().process_frame
	assert(skeleton.get_bone_global_pose(skeleton.find_bone("hand.L")).origin.y < 0.7, "Idle capture retained a raised-hand pose")
	get_viewport().get_texture().get_image().save_png("res://../godot_preview.png")
	hand_closeup = true
	zoom = 0.95
	for clip in ["Greet", "Cane_Hold", "Hand_Mechanics"]:
		_play(clip)
		# Capture a settled pose, not the first frame of the interactive crossfade.
		player.play(clip, 0.0)
		player.seek(3.0 if clip == "Hand_Mechanics" else 1.5, true)
		player.advance(0)
		player.pause()
		for i in 12: await get_tree().process_frame
		if clip == "Greet":
			assert(skeleton.get_bone_global_pose(skeleton.find_bone("hand.L")).origin.y > 0.8)
		get_viewport().get_texture().get_image().save_png("res://../godot_hand_" + clip + ".png")
	print("MILO_PREVIEW_RENDER_PASS")
	get_tree().quit()

func _play(clip: String) -> void:
	selected = clip
	player.play(clip, 0.18)
	_set_cane(model, clip == "Cane_Hold")
	model.position = Vector3.ZERO
	walk_clock = 0.0
	status.text = "Playing: " + clip + ("  |  in-place gait: 0.12 m/s nominal" if clip == "Walking_A" else "")

func _set_cane(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D and str(node.name).begins_with("Cane_"):
		node.visible = enabled
	for child in node.get_children():
		_set_cane(child, enabled)

func _process(delta: float) -> void:
	if hand_closeup: _update_camera()
	if moving and selected == "Walking_A" and player.is_playing():
		walk_clock += delta * player.speed_scale
		model.position.z = fmod(walk_clock * 0.12, 1.2) - 0.6

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw -= event.relative.x * 0.008
		_update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom = maxf(0.35 if hand_closeup else 1.6, zoom - (0.05 if hand_closeup else 0.2))
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom = minf(1.4 if hand_closeup else 6.0, zoom + (0.05 if hand_closeup else 0.2))
		_update_camera()

func _update_camera() -> void:
	if hand_closeup and skeleton:
		var bone := skeleton.find_bone("hand.R" if selected == "Cane_Hold" else "hand.L")
		var pose := skeleton.global_transform * skeleton.get_bone_global_pose(bone)
		var target := pose * Vector3(0, 0.14, 0)
		# Inspect each hand from its outside, not through the sleeve.
		var view_yaw := yaw - (0.64 if selected == "Cane_Hold" else 0.0)
		camera.position = target + Vector3(sin(view_yaw) * zoom, 0.09, cos(view_yaw) * zoom)
		camera.look_at(target)
		return
	camera.position = Vector3(sin(yaw) * zoom, 1.5, cos(yaw) * zoom)
	camera.look_at(Vector3(0, 0.93, 0))
