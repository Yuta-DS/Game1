extends SceneTree

const PlayerScene := preload("res://scenes/entities/NewPlayer.tscn")
const ChatScene := preload("res://scenes/chatbot.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := PlayerScene.instantiate()
	root.add_child(player)
	await process_frame
	var camera := player.get_node_or_null("CameraController")
	assert(camera != null, "player camera exists")
	player.interacting = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	camera._input(click)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"camera releases the cursor before processing modal UI clicks")

	var chat := ChatScene.instantiate()
	root.add_child(chat)
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	chat._process(0.0)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"Milo chat continuously releases Web pointer lock")
	var buttons := chat.find_children("*", "Button", true, false)
	assert(not buttons.is_empty(), "Milo chat presents selectable options")
	for button in buttons:
		assert((button as Button).focus_mode == Control.FOCUS_ALL,
			"Milo options support mouse and keyboard focus")

	chat.queue_free()
	player.queue_free()
	await process_frame
	print("MILO_CHAT_CURSOR_TEST: PASS — chat releases pointer lock and all options remain focusable")
	quit()
