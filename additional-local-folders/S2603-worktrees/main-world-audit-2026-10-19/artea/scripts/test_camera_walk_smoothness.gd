extends SceneTree

# Walking must not shake, spin or slosh the follow camera. On foot it is held
# rigidly on the player like the town's spring-arm camera: only the mouse turns
# the view, and the player stays put on screen. It used to ease toward the
# player and look_at() them from that lagging spot, which crept and snapped back
# every physics tick and, from top-down, swung the heading 5+ degrees a frame.

const SCENES := [
	"res://scenes/art_gallery_3d_inprogress.tscn",
	"res://scenes/art_castle_floating_world.tscn",
]
# Default over-the-shoulder pitch, then near top-down.
const PITCHES := [-15.0, -85.0]
const MAX_HEADING_STEP_DEGREES := 0.5
# How far the player may shift in the camera's view per frame. A rigid follow
# keeps this near zero; easing moved it by the player's whole stride per tick.
const MAX_PLAYER_VIEW_SHIFT := 0.02


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.max_fps = 0
	for path in SCENES:
		for pitch in PITCHES:
			var result: Vector2 = await _measure(path, pitch)
			print("CAMERA_WALK: %s pitch %d largest heading step=%.2f deg, player view shift=%.3f m" % [
				path.get_file(), pitch, result.x, result.y])
			if result.x > MAX_HEADING_STEP_DEGREES or result.y > MAX_PLAYER_VIEW_SHIFT:
				push_error("CAMERA_WALK_SMOOTHNESS_TEST: camera shakes or lags while walking in %s at pitch %d" % [path, pitch])
				quit(1)
				return
	print("CAMERA_WALK_SMOOTHNESS_TEST: PASS")
	quit()


# Returns (largest per-frame heading change in degrees, largest per-frame shift
# of the player in camera space in metres) while strafing.
func _measure(path: String, pitch_degrees: float) -> Vector2:
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	var camera := root.get_viewport().get_camera_3d()
	var player := scene.get_node("Player3D") as Node3D
	camera.set("_pitch", deg_to_rad(pitch_degrees))
	for _i in 90:
		await physics_frame
	Input.action_press("move_right")
	# Let the walk reach full speed before sampling.
	for _i in 40:
		await physics_frame
	var last_heading := _heading(camera)
	var last_view := camera.global_transform.affine_inverse() * player.global_position
	var largest_step := 0.0
	var largest_shift := 0.0
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1500:
		# physics_frame fires before anything moves this tick, so the state is
		# what the last frame drew. process_frame fires before the camera's
		# _process and would catch the player moved but not yet followed.
		await physics_frame
		var heading := _heading(camera)
		var view := camera.global_transform.affine_inverse() * player.global_position
		largest_step = maxf(largest_step, absf(angle_difference(last_heading, heading)))
		largest_shift = maxf(largest_shift, view.distance_to(last_view))
		last_heading = heading
		last_view = view
	Input.action_release("move_right")
	scene.queue_free()
	await process_frame
	return Vector2(rad_to_deg(largest_step), largest_shift)


# Which way the view faces across the ground. Euler yaw is unreliable near a
# top-down pitch; the forward-plus-up direction stays well defined there.
func _heading(camera: Camera3D) -> float:
	var b := camera.global_basis
	var v := b.y - b.z
	return atan2(v.x, v.z)
