extends SceneTree

var railway: Node3D
var player: CharacterBody3D
var train: Node3D
var capture := false
var camera: Camera3D
var phases: Dictionary = {}
var failed := false

func _initialize() -> void:
	capture = "--capture-driver" in OS.get_cmdline_user_args()
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1440, 960)
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)
	player = CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	var visuals := Node3D.new()
	visuals.name = "FoxVisuals"
	player.add_child(visuals)
	var fox := load("res://assets3D/characters/fox.glb").instantiate() as Node3D
	fox.name = "Fox"
	fox.scale = Vector3.ONE * 3.0
	fox.position.y = -0.980317
	visuals.add_child(fox)
	world.add_child(player)
	railway = Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	# A visible test window must not consume the user's typing as R/T/Q events.
	railway.set_process_unhandled_input(false)
	player.set_process_unhandled_input(false)
	for i in 5:
		await process_frame
	train = railway.get_node("RainbowGalaxyTrain") as Node3D
	var audio_manager := root.get_node("WorldSpatialAudio")
	audio_manager.call("_register_train", train)
	var cab_audio := train.get_node("TrainControls3D") as AudioStreamPlayer3D
	var train_audio := train.get_node("TrainEvents3D") as AudioStreamPlayer3D
	if capture:
		_setup_capture(world)
	var idle_speed: float = player.animation_player.speed_scale
	player.global_position = railway.call("get_driver_interaction_position")
	_check(railway.call("select_train_mode", "drive"), "R/drive must enter the front cab")
	_check(cab_audio.get_meta("last_train_event", &"") == &"board",
		"entering the cab must play the local boarding sound")
	_check(player.global_position.distance_to(railway.call("get_driver_seat_position")) < 0.02,
		"driver must be at the seat")
	_check(player.call("get_train_driver_animation_state")["rig_bound"], "actual fox skeleton must bind")
	var sword := player.find_child("Sword", true, false) as Node3D
	_check(sword != null and not sword.visible, "driver must stow the sword to use both hands")
	var start := train.global_position
	await _step(1.0, 42)
	_check(train.global_position.distance_to(start) < 0.01, "startup must keep brakes applied")
	await _save("power_on")
	await _step(1.0, 180)
	_check(train.global_position.distance_to(start) > 5.0, "throttle must move the train after setup")
	for phase in ["take_controls", "power_on", "check_pressure", "select_direction", "release_brake", "accelerating"]:
		_check(phases.has(phase), "missing action phase: " + phase)
	_check(cab_audio.get_meta("last_train_event", &"") == &"throttle",
		"startup must audibly reach the throttle action")
	var pose: Dictionary = player.call("get_train_driver_animation_state")
	print("DRIVER_HAND_ERROR_M ", pose["hand_error_m"])
	_check(float(pose["hand_error_m"]) < 0.08, "hands must reach real handle grips")
	var rig := player.find_child("Skeleton3D", true, false) as Skeleton3D
	var hip := train.to_local(rig.to_global(rig.get_bone_global_pose(rig.find_bone("Bone.002")).origin))
	_check(hip.y > 3.20 and hip.y < 3.50 and hip.z > -16.3 and hip.z < -14.2,
		"seated hips must meet the authored cushion, not sink into its base")
	await _save("throttle")
	var brake_hand: Vector3 = pose["left_target"]
	_check(railway.call("request_horn"), "H must sound horn")
	await _step(1.0, 22)
	pose = player.call("get_train_driver_animation_state")
	_check((pose["left_target"] as Vector3).distance_to(brake_hand) > 0.05,
		"horn action must move the hand to its own handle")
	await _save("horn")
	await _step(-1.0, 1)
	var state: Dictionary = railway.call("get_driver_system_state")
	_check(state["phase"] == "braking" and int(state["reverser"]) == 1,
		"reverse request at speed must brake before moving the reverser")
	_check(train_audio.get_meta("last_train_event", &"") == &"brake",
		"direction changes at speed must play the spatial brake sound")
	await _save("braking")
	for i in 240:
		var speed: float = railway.call("get_display_speed_kph")
		var before: Dictionary = railway.call("get_driver_system_state")
		await _step(-1.0, 1)
		state = railway.call("get_driver_system_state")
		if int(state["reverser"]) != int(before["reverser"]):
			_check(speed <= 0.05, "reverser changed while moving")
		if int(state["reverser"]) == -1 and float(railway.call("get_display_speed_kph")) > 2.0:
			break
	_check(int(state["reverser"]) == -1, "S must eventually select reverse")
	_check(not bool(railway.call("request_disembark")), "cannot leave moving train")
	await _step(0.0, 60)
	_check(float(railway.call("get_display_speed_kph")) < 0.05, "release must apply service brake")
	var guard := 0
	while int(railway.call("get_drive_segment")) >= 0 and guard < 3000:
		await _step(-1.0, 1)
		guard += 1
	_check(railway.call("request_disembark"), "Q must exit at station")
	_check(train_audio.get_meta("last_train_event", &"") == &"door",
		"leaving the cab must play the train door sound")
	_check(player.input_enabled and player.call("get_vehicle_pose") == "", "exit restores walking")
	_check(not player.call("get_train_driver_animation_state")["rig_bound"], "exit releases bone posing")
	_check(is_equal_approx(player.animation_player.speed_scale, idle_speed), "exit restores animation speed")
	_check(sword.visible, "exit restores the stowed weapon")
	player.global_position = railway.call("get_driver_interaction_position")
	_check(railway.call("select_train_mode", "drive"), "driver can re-board")
	await _step(1.0, 10)
	_check(railway.call("request_disembark"), "startup can be cancelled while docked")
	_check(not railway.call("get_driver_system_state")["active"], "exit shuts down cab actions")
	# Also exercise ordinary held-input processing without the external drive API.
	player.global_position = railway.call("get_driver_interaction_position")
	_check(railway.call("select_train_mode", "drive"), "R re-entry resets cab preparation")
	Input.action_press("move_forward")
	for i in 180:
		await physics_frame
	print("HELD_W_FINAL ", railway.call("get_driver_system_state"), " SPEED ", railway.call("get_display_speed_kph"), " STATION ", railway.call("get_current_station"))
	Input.action_release("move_forward")
	_check(float(railway.call("get_display_speed_kph")) > 0.0, "normal held W must complete startup and accelerate")
	if not failed:
		print("TRAIN_DRIVER_ACTIONS: PASS — real fox rig, startup interlock, handle contact, horn, brake, stop-before-reverse and exit")
	quit(1 if failed else 0)

func _step(command: float, frames: int) -> void:
	for i in frames:
		railway.call("drive_manual", command, 1.0 / 60.0)
		var state: Dictionary = railway.call("get_driver_system_state")
		phases[state["phase"]] = true
		await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error("TRAIN_DRIVER_ACTIONS: " + message)

func _setup_capture(world: Node3D) -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	for layer in world.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	for particles in train.find_children("*", "GPUParticles3D", true, false):
		particles.visible = false
	railway.get_node("StoryStations").visible = false
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("0b182a")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d9edff")
	settings.ambient_light_energy = 0.7
	env.environment = settings
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -20, 0)
	sun.light_energy = 0.8
	world.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 80
	train.add_child(camera)
	camera.make_current()

func _save(action: String) -> void:
	if not capture:
		return
	camera.position = Vector3(-2.15, 5.2, -15.65)
	camera.look_at(train.to_global(Vector3(0.0, 4.5, -15.3)), Vector3.UP)
	camera.make_current()
	await RenderingServer.frame_post_draw
	var path := "res://artifacts/train_driver_%s.png" % action
	_check(root.get_texture().get_image().save_png(path) == OK, "capture " + action)
