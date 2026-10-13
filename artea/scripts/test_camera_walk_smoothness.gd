extends SceneTree

# Walking sideways in a CameraFollow scene must turn the view smoothly. The
# follow camera used to ease its position every render frame while aiming at a
# player that only moves on physics ticks, so with more render frames than
# ticks the view crept one way and snapped back each tick: a constant shake.
# Measured as reversals in the per-frame change of the camera's yaw.

const SCENES := [
	"res://scenes/art_gallery_3d_inprogress.tscn",
	"res://scenes/art_castle_floating_world.tscn",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 0
	for path in SCENES:
		var reversals := await _measure(path)
		print("CAMERA_WALK: %s yaw reversals=%d" % [path.get_file(), reversals])
		if reversals > 3:
			push_error("CAMERA_WALK_SMOOTHNESS_TEST: view shakes while walking in %s" % path)
			quit(1)
			return
	print("CAMERA_WALK_SMOOTHNESS_TEST: PASS")
	quit()


func _measure(path: String) -> int:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	var camera := root.get_viewport().get_camera_3d()
	for _i in 90:
		await physics_frame
	Input.action_press("move_right")
	# Let the walk reach full speed before sampling.
	for _i in 40:
		await physics_frame
	var last_yaw := camera.global_rotation.y
	var last_step := 0.0
	var reversals := 0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1500:
		await process_frame
		var yaw := camera.global_rotation.y
		var step := angle_difference(last_yaw, yaw)
		last_yaw = yaw
		if absf(step) < 1e-6:
			continue
		if last_step != 0.0 and signf(step) != signf(last_step):
			reversals += 1
		last_step = step
	Input.action_release("move_right")
	scene.queue_free()
	await process_frame
	return reversals
