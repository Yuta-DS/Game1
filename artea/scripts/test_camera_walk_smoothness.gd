extends SceneTree

# Walking must not shake or turn the follow camera; only the mouse turns it.
# The camera used to look_at() the player from its eased position: it crept and
# snapped back every physics tick, and from a top-down pitch (camera nearly
# straight above the player) the lag alone swung its heading 5+ degrees a frame.
# Measured as reversals and the largest per-frame change in the camera's yaw,
# at the default pitch and near top-down.

const SCENES := [
	"res://scenes/art_gallery_3d_inprogress.tscn",
	"res://scenes/art_castle_floating_world.tscn",
]


var _max_step := 0.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 0
	for path in SCENES:
		# Default over-the-shoulder pitch, then the near top-down view, where the
		# camera sits almost directly above the player.
		for pitch in [-15.0, -85.0]:
			var reversals := await _measure(path, pitch)
			print("CAMERA_WALK: %s pitch %d yaw reversals=%d largest yaw step=%.2f deg" % [
				path.get_file(), pitch, reversals, rad_to_deg(_max_step)])
			if reversals > 3 or rad_to_deg(_max_step) > 0.5:
				push_error("CAMERA_WALK_SMOOTHNESS_TEST: view shakes while walking in %s at pitch %d" % [path, pitch])
				quit(1)
				return
	print("CAMERA_WALK_SMOOTHNESS_TEST: PASS")
	quit()


func _measure(path: String, pitch_degrees: float) -> int:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	var camera := root.get_viewport().get_camera_3d()
	camera.set("_pitch", deg_to_rad(pitch_degrees))
	for _i in 90:
		await physics_frame
	Input.action_press("move_right")
	# Let the walk reach full speed before sampling.
	for _i in 40:
		await physics_frame
	var last_yaw := camera.global_rotation.y
	var last_step := 0.0
	var reversals := 0
	_max_step = 0.0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1500:
		await process_frame
		var yaw := camera.global_rotation.y
		var step := angle_difference(last_yaw, yaw)
		last_yaw = yaw
		_max_step = maxf(_max_step, absf(step))
		if absf(step) < 1e-6:
			continue
		if last_step != 0.0 and signf(step) != signf(last_step):
			reversals += 1
		last_step = step
	Input.action_release("move_right")
	scene.queue_free()
	await process_frame
	return reversals
