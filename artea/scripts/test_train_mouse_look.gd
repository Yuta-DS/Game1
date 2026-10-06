extends SceneTree
## Deliver real viewport events in the gallery, not direct camera callbacks.

var checks := 0
var failures: Array[String] = []
var clicks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("TRAIN_MOUSE_LOOK: " + message)

func _frames() -> void:
	for i in 3:
		await process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)

func _motion(delta: Vector2, at := Vector2(480, 240)) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = delta
	root.push_input(event, true)

func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _run() -> void:
	root.size = Vector2i(960, 600)
	var gallery := load("res://scenes/art_gallery_3d_inprogress.tscn").instantiate() as Node3D
	var camera := gallery.get_node("Camera3D") as Camera3D
	camera.set("capture_mouse", false)
	root.add_child(gallery)
	await _frames()
	var player := gallery.get_node("Player3D") as CharacterBody3D
	var railway := gallery.get_node("ArtCastleFloatingWorld/StoryCrownRailway")
	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	player.global_position = railway.call("get_driver_interaction_position")
	_key(KEY_R)
	await _frames()
	_check(camera.call("is_ride_view_active"), "R boards through the normal input pipeline")
	_key(KEY_3)
	await _frames()
	_check(camera.call("get_view_mode") == "first", "3 selects first person through viewport input")
	var yaw: float = camera.get("_yaw")
	var pitch: float = camera.get("_pitch")
	_motion(Vector2(100, -50))
	await _frames()
	_check(absf(angle_difference(yaw, camera.get("_yaw")) + .5) < .001, "Mouse right looks right without dragging")
	_check(absf(float(camera.get("_pitch")) - pitch - .25) < .001, "Mouse up looks up without dragging")
	_check(camera.global_position.distance_to(player.call("get_first_person_eye_position", Vector3.ZERO)) < .001,
		"Mouse look keeps the lens at the character eyes")
	_check(is_equal_approx(camera.fov, 95.0), "Mouse look preserves FOV")
	var look_offset := angle_difference(train.global_rotation.y, camera.get("_yaw"))
	for i in 100:
		railway.call("drive_manual", 1.0, 1.0 / 60.0)
		await process_frame
	await _frames()
	_check(absf(angle_difference(look_offset, angle_difference(train.global_rotation.y, camera.get("_yaw")))) < .001,
		"Mouse look offset follows the moving train")
	_motion(Vector2(100000, -100000))
	await _frames()
	_check(absf(float(camera.get("_yaw"))) <= PI, "Full-circle yaw stays wrapped")
	_check(is_equal_approx(float(camera.get("_pitch")), deg_to_rad(89)), "Upward look is safely clamped")
	_motion(Vector2(-100000, 100000))
	await _frames()
	_check(is_equal_approx(float(camera.get("_pitch")), deg_to_rad(-89)), "Downward look is safely clamped")
	_check(camera.global_basis.is_finite(), "Extreme motion preserves a valid camera basis")
	_key(KEY_4)
	_key(KEY_3)
	_key(KEY_ESCAPE)
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape releases the native pointer")
	yaw = camera.get("_yaw")
	pitch = camera.get("_pitch")
	_motion(Vector2(90, 30))
	await _frames()
	_check(is_equal_approx(float(camera.get("_yaw")), yaw) and is_equal_approx(float(camera.get("_pitch")), pitch),
		"Escape releases the cursor without moving the view")
	var layer := CanvasLayer.new()
	layer.layer = 200
	gallery.add_child(layer)
	var button := Button.new()
	button.position = Vector2(20, 20)
	button.size = Vector2(160, 60)
	button.text = "Menu action"
	button.pressed.connect(func() -> void: clicks += 1)
	layer.add_child(button)
	camera.set("capture_mouse", true)
	await _frames()
	_motion(Vector2.ZERO, Vector2(60, 50))
	_click(Vector2(60, 50))
	await _frames()
	_check(clicks == 1, "Released cursor can click a menu button")
	yaw = camera.get("_yaw")
	_motion(Vector2(30, 0))
	await _frames()
	_check(is_equal_approx(float(camera.get("_yaw")), yaw), "UI clicks do not recapture mouse look")
	_click(Vector2(480, 240))
	if DisplayServer.get_name() != "headless":
		_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Game click captures the native pointer")
	yaw = camera.get("_yaw")
	_motion(Vector2(30, 0))
	await _frames()
	_check(absf(angle_difference(yaw, camera.get("_yaw")) + .15) < .001, "Clicking game space resumes look")
	_key(KEY_ESCAPE)
	_key(KEY_3)
	yaw = camera.get("_yaw")
	_motion(Vector2(-30, 0))
	await _frames()
	_check(absf(angle_difference(yaw, camera.get("_yaw")) - .15) < .001, "3 explicitly resumes first-person look")
	_key(KEY_4)
	yaw = camera.get("_yaw")
	_motion(Vector2(30, 0))
	await _frames()
	_check(absf(angle_difference(yaw, camera.get("_yaw")) + .15) < .001, "Third-person mouse orbit remains available")
	var other_camera := Camera3D.new()
	gallery.add_child(other_camera)
	other_camera.make_current()
	yaw = camera.get("_yaw")
	_motion(Vector2(90, 0))
	await _frames()
	_check(is_equal_approx(float(camera.get("_yaw")), yaw), "Inactive cameras ignore mouse look")
	camera.make_current()
	camera.call("enter_inspect", train)
	yaw = camera.get("_yaw")
	_motion(Vector2(90, 0))
	await _frames()
	_check(is_equal_approx(float(camera.get("_yaw")), yaw), "Artwork inspection remains fixed")
	camera.call("exit_inspect")
	_motion(Vector2(30, 0))
	await _frames()
	_check(absf(angle_difference(yaw, camera.get("_yaw")) + .15) < .001, "Leaving inspection restores mouse look")
	print("TRAIN_MOUSE_LOOK: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gallery.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
