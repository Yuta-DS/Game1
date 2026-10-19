extends SceneTree

# Guards how smoothly the train and its camera move while being driven.
#
# Judder is invisible to the other suites: a train that snaps its heading five
# degrees in one frame still reaches every station and still passes every
# position assertion. This measures the frame-to-frame motion directly, because
# that discontinuity is exactly what a driver feels as a jolt.
#
# Baselines come from the measured behaviour after the tangent and camera
# smoothing fixes, with headroom so ordinary retuning does not trip them:
#   train heading   worst frame-to-frame jump  4.52 deg -> 0.22 deg
#   camera heading  worst single-frame turn    7.37 deg -> 0.0015 deg

const MAX_TRAIN_TURN_JUMP_DEGREES := 1.5
const MAX_CAMERA_TURN_DEGREES := 2.0
const MAX_CAMERA_STEP_JUMP_METRES := 0.6


func _fail(message: String) -> void:
	push_error("TRAIN_SMOOTHNESS_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)

	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	shape_node.shape = capsule
	player.add_child(shape_node)
	world.add_child(player)

	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)

	for _i in 8:
		await process_frame

	var train: Node3D = railway.get("_train")
	if train == null:
		_fail("the train was not built")
		return

	var camera := Camera3D.new()
	camera.set_script(load("res://scripts/CameraFollow.gd"))
	camera.set("capture_mouse", false)
	camera.set("player_path", NodePath("../Player3D"))
	camera.add_to_group("follow_camera")
	world.add_child(camera)
	camera.make_current()
	for _i in 6:
		await process_frame

	player.global_position = railway.call("get_driver_interaction_position")
	if not bool(railway.call("board_as_driver")):
		_fail("could not board as driver")
		return

	# Advance train and camera with the same 60 Hz step. Automatic processing
	# would otherwise brake between manual steps using unrelated host delta.
	railway.set_process(false)
	camera.set_process(false)
	var worst_train_turn_jump := 0.0
	var worst_camera_turn := 0.0
	var worst_camera_step_jump := 0.0
	var previous_train_turn := 0.0
	var previous_camera_step := 0.0
	var previous_position := train.global_position
	var previous_forward := -train.global_transform.basis.z
	var previous_camera := camera.global_position
	var previous_camera_forward := -camera.global_transform.basis.z

	for _frame in 400:
		railway.call("drive_manual", 1.0, 1.0 / 60.0)
		camera.call("_process", 1.0 / 60.0)

		var step := train.global_position.distance_to(previous_position)
		# Ignore the acceleration ramp and the docking teleport: neither is the
		# steady-state motion this test is about.
		var progress := float(railway.get("_drive_progress"))
		if step > 0.001 and step < 40.0 and progress > 0.001 and progress < 0.995:
			var forward := -train.global_transform.basis.z
			var turn := rad_to_deg(previous_forward.angle_to(forward))
			worst_train_turn_jump = maxf(worst_train_turn_jump,
				absf(turn - previous_train_turn))
			previous_train_turn = turn

			var camera_forward := -camera.global_transform.basis.z
			worst_camera_turn = maxf(worst_camera_turn,
				rad_to_deg(previous_camera_forward.angle_to(camera_forward)))

			var camera_step := camera.global_position.distance_to(previous_camera)
			worst_camera_step_jump = maxf(worst_camera_step_jump,
				absf(camera_step - previous_camera_step))
			previous_camera_step = camera_step

		previous_position = train.global_position
		previous_forward = -train.global_transform.basis.z
		previous_camera = camera.global_position
		previous_camera_forward = -camera.global_transform.basis.z

	if worst_train_turn_jump > MAX_TRAIN_TURN_JUMP_DEGREES:
		_fail("the train's heading snaps between frames (%.2f deg, limit %.2f) — the curve tangent is being sampled over too short a span for the speed"
			% [worst_train_turn_jump, MAX_TRAIN_TURN_JUMP_DEGREES])
		return
	if worst_camera_turn > MAX_CAMERA_TURN_DEGREES:
		_fail("the driving camera swings between frames (%.2f deg, limit %.2f) — it is lagging the train and over-correcting"
			% [worst_camera_turn, MAX_CAMERA_TURN_DEGREES])
		return
	if worst_camera_step_jump > MAX_CAMERA_STEP_JUMP_METRES:
		_fail("the driving camera's travel per frame jumps (%.2f m, limit %.2f)"
			% [worst_camera_step_jump, MAX_CAMERA_STEP_JUMP_METRES])
		return

	print("TRAIN_SMOOTHNESS_TEST: PASS — train turn jump %.3f deg, camera turn %.4f deg, camera step jump %.3f m"
		% [worst_train_turn_jump, worst_camera_turn, worst_camera_step_jump])
	quit()


func _init() -> void:
	call_deferred("_run")
