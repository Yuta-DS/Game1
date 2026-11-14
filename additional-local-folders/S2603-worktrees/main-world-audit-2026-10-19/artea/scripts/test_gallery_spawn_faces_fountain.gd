extends SceneTree

# Every gallery load should start looking out at the arrival fountain. A mouse
# jump in the first frames (cursor capture, or motion during the loading
# screen) used to swing the fresh view, often straight down at the floor.


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("GALLERY_SPAWN_FACES_FOUNTAIN_TEST: %s" % message)
	quit(1)


func _mouse_jump(relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = relative
	Input.parse_input_event(motion)


func _run() -> void:
	change_scene_to_file("res://scenes/art_gallery_3d_inprogress.tscn")
	await process_frame
	await process_frame
	_mouse_jump(Vector2(120, 260))
	for i in 30:
		await process_frame
	var camera := root.get_viewport().get_camera_3d()
	var fountain := current_scene.find_child("LatonaFountain", true, false) as Node3D
	var to_fountain := fountain.global_position - camera.global_position
	var forward := -camera.global_basis.z
	var yaw_error := rad_to_deg(absf(Vector2(forward.x, forward.z).angle_to(Vector2(to_fountain.x, to_fountain.z))))
	var pitch := rad_to_deg(asin(forward.y))
	if yaw_error > 2.0:
		_fail("view is %.1f degrees away from the fountain" % yaw_error)
		return
	if pitch < -60.0:
		_fail("view is tilted at the floor (%.1f degrees)" % pitch)
		return
	# Once settled, the mouse still turns the view.
	var before := forward
	_mouse_jump(Vector2(200, 0))
	for i in 5:
		await process_frame
	if (-camera.global_basis.z).is_equal_approx(before):
		_fail("mouse no longer turns the camera after the view settles")
		return
	print("GALLERY_SPAWN_FACES_FOUNTAIN_TEST: PASS")
	quit()
