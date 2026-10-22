# Phone/tablet controls: the joystick moves the player through the move_*
# actions, a right-side drag turns the camera, a finger's emulated mouse motion
# no longer turns it, the camera swings behind a player who turns round, and
# a tap on the minimap opens the full map (it used to toggle open and shut
# again in the same tap) and hides the touch HUD.
#   godot --headless --path artea --script res://scripts/test_touch_controls.gd
extends SceneTree

const CameraFollow := preload("res://scripts/CameraFollow.gd")
const TouchControls := preload("res://scripts/touch_controls.gd")
const Minimap := preload("res://scripts/art_castle_minimap.gd")
const AutoFollow := preload("res://scripts/camera_auto_follow.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var camera: Camera3D = CameraFollow.new()
	camera.capture_mouse = false
	root.add_child(camera)
	await process_frame

	# A finger's emulated mouse motion must not orbit; a real mouse still does.
	var yaw_before: float = camera._yaw
	var finger := _motion(Vector2(120, 0))
	finger.device = InputEvent.DEVICE_ID_EMULATION
	camera._input(finger)
	assert(is_equal_approx(camera._yaw, yaw_before), "emulated touch motion does not turn the camera")
	camera._input(_motion(Vector2(120, 0)))
	assert(not is_equal_approx(camera._yaw, yaw_before), "real mouse motion still turns the camera")

	var hud: CanvasLayer = TouchControls.new()
	root.add_child(hud)
	await process_frame
	assert(not hud.is_active(), "headless has no touchscreen, so the HUD stays off")
	hud.build()
	await process_frame
	assert(hud.visible, "the HUD shows while a touch_look camera is in the world")

	var screen: Vector2 = root.get_visible_rect().size
	var left := Vector2(screen.x * 0.15, screen.y * 0.6)
	hud._unhandled_input(_touch(0, left, true))
	hud._unhandled_input(_drag(0, left + Vector2(400, 0), Vector2(400, 0)))
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	assert(move.x > 0.9 and absf(move.y) < 0.01, "dragging the joystick right moves right")
	hud._unhandled_input(_touch(0, left, false))
	move = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	assert(move == Vector2.ZERO, "lifting the finger stops the player")

	yaw_before = camera._yaw
	var right := Vector2(screen.x * 0.6, screen.y * 0.4)
	hud._unhandled_input(_touch(1, right, true))
	hud._unhandled_input(_drag(1, right + Vector2(80, 0), Vector2(80, 0)))
	hud._unhandled_input(_touch(1, right, false))
	assert(not is_equal_approx(camera._yaw, yaw_before), "a right-side drag turns the camera")
	assert(Input.get_vector("move_left", "move_right", "move_forward", "move_backward") == Vector2.ZERO,
		"looking does not move the player")

	# Turning round swings the camera behind the player, while the direction
	# movement uses holds still so holding S cannot spin forever.
	var follow = AutoFollow.new()
	Input.action_press("move_backward")
	var yaw := follow.step(0.016, 0.0, Vector3(0, 0, 5)) # running at the camera
	for i in 300:
		yaw = follow.step(0.016, yaw, Vector3(0, 0, 5))
	assert(absf(absf(yaw) - PI) < 0.05, "turning around swings the view 180 degrees")
	assert(is_zero_approx(follow.control_yaw), "movement keeps its frame while S is held")
	follow.looked()
	var held := yaw
	yaw = follow.step(0.5, yaw, Vector3(0, 0, -5))
	assert(is_equal_approx(yaw, held), "a manual look pauses the swing")
	Input.action_release("move_backward")
	follow.step(0.016, yaw, Vector3.ZERO)
	assert(is_equal_approx(follow.control_yaw, yaw), "releasing the stick re-reads the view")

	var map: Control = Minimap.new()
	root.add_child(map)
	await process_frame
	# One tap = a ScreenTouch followed by the mouse click emulated from it.
	map._on_gui_input(_touch(0, Vector2(100, 100), true))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.device = InputEvent.DEVICE_ID_EMULATION
	map._on_gui_input(click)
	assert(map.is_full_map_open(), "one tap opens the full map and leaves it open")
	await process_frame
	assert(not hud.visible, "the touch HUD hides behind the full map")
	map._on_gui_input(click)
	assert(not map.is_full_map_open(), "tapping the full map closes it")
	await process_frame
	assert(hud.visible, "the touch HUD returns once the map closes")

	# PC (headless is one) keeps the desktop behaviour: captured cursor,
	# desktop-sized minimap and Milo panel.
	assert(TouchControls.captured_mode() == Input.MOUSE_MODE_CAPTURED, "a PC still captures the cursor")
	assert(Minimap.hud_scale(root) == 1.0, "a PC keeps the desktop minimap size")
	var chat: Control = load("res://scenes/chatbot.tscn").instantiate()
	root.add_child(chat)
	await process_frame
	assert(chat.scale == Vector2.ONE, "a PC keeps the desktop Milo panel")
	# The touch fit must keep the enlarged panel on screen.
	chat._fit_to_touch_screen()
	await process_frame
	var panel_rect: Rect2 = (chat.get_node("Panel") as Control).get_global_rect()
	assert(root.get_visible_rect().grow(1.0).encloses(panel_rect), "the touch-sized Milo panel fits the screen")
	chat.queue_free()

	# The journal's touch zoom still covers exactly the whole screen.
	var journal: Control = load("res://scenes/crown_quest_journal.tscn").instantiate()
	root.add_child(journal)
	await process_frame
	assert(journal.scale == Vector2.ONE, "a PC keeps the desktop journal")
	journal._zoom_for_touch()
	await process_frame
	assert(journal.get_global_rect().size.is_equal_approx(root.get_visible_rect().size),
		"the zoomed journal fills the screen")
	journal.queue_free()

	print("TOUCH_CONTROLS_TEST: PASS — joystick moves, drag looks, taps no longer spin the view, map opens on one tap")
	quit()


func _motion(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = relative
	return event


func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _drag(index: int, position: Vector2, relative: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = relative
	return event
