# While Milo's chat is open the gallery camera must ignore the mouse: moving
# the cursor does not orbit, the wheel does not zoom, and clicks do not
# recapture the pointer. Once the chat closes, normal control returns.
#   godot --headless --path artea --script res://scripts/test_camera_follow_ui_block.gd
extends SceneTree

const CameraFollow := preload("res://scripts/CameraFollow.gd")
const CHATBOT_SCENE := preload("res://scenes/chatbot.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var camera: Camera3D = CameraFollow.new()
	camera.capture_mouse = false
	root.add_child(camera)
	await process_frame

	var chat = CHATBOT_SCENE.instantiate()
	root.add_child(chat)
	await process_frame

	var yaw_before: float = camera._yaw
	var distance_before: float = camera.follow_distance
	camera._input(_motion(Vector2(120, 40)))
	camera._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	assert(is_equal_approx(camera._yaw, yaw_before),
		"moving the cursor over the chat does not turn the camera")
	assert(is_equal_approx(camera.follow_distance, distance_before),
		"scrolling while the chat is open does not zoom the world")

	chat.queue_free()
	await process_frame
	camera._input(_motion(Vector2(120, 40)))
	camera._input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	assert(not is_equal_approx(camera._yaw, yaw_before),
		"the camera orbits again once the chat closes")
	assert(camera.follow_distance < distance_before,
		"the wheel zooms again once the chat closes")

	camera.queue_free()
	print("CAMERA_FOLLOW_UI_BLOCK_TEST: PASS — chat owns the mouse while open, camera control returns on close")
	quit()


func _motion(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	return event


func _wheel(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event
