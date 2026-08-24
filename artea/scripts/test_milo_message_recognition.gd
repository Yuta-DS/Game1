extends SceneTree

const ReflectionEngine := preload("res://scripts/MiloReflectionEngine.gd")
const ChatbotScene := preload("res://scenes/chatbot.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var engine := ReflectionEngine.new()
	var cases := {
		"Why am I always stressed and under so much pressure?": ["stressed", "Mind Spark"],
		"I feel worried and unsure about tomorrow": ["worried", "Mind Spark"],
		"I am sad and everything feels heavy": ["sad", "Heart Melody"],
		"I am frustrated and stuck on this": ["frustrated", "Creator's Light"],
		"I feel lonely and left out": ["lonely", "Heart Melody"],
		"I did it and I feel proud": ["proud", "Creator's Light"],
	}
	for message in cases:
		var response: Dictionary = engine.reflect(message)
		assert(response.emotion == cases[message][0], "%s recognises %s" % [message, cases[message][0]])
		assert(str(response.activity).contains(cases[message][1]), "%s receives a relevant ARTÉA suggestion" % message)
		for field in ["validate", "reflect", "strength", "guidance", "activity"]:
			assert(not str(response.get(field, "")).is_empty(), "%s includes %s" % [message, field])

	var action_response: Dictionary = engine.reflect("I was frustrated, but I asked for help")
	assert(str(action_response.strength).contains("courage and connection"),
		"Milo notices a strength grounded in an action the player described")
	var unclear: Dictionary = engine.reflect("There is a lot going on")
	assert(unclear.emotion == "unclear" and str(unclear.reflect).contains("do not want to guess"),
		"Milo asks rather than inventing an emotion when meaning is unclear")

	var chat := ChatbotScene.instantiate()
	root.add_child(chat)
	await process_frame
	var input := chat.user_input as LineEdit
	var history := chat.get_node("VBoxContainer/ChatHistory") as TextEdit
	assert(input != null and input.max_length == ReflectionEngine.MAX_MESSAGE_LENGTH,
		"the live input enforces the engine's length boundary")
	input.text = "Why am I always stressed?"
	chat._submit_message(input)
	assert(input.text.is_empty(), "the private message is cleared immediately after local processing")
	for section in ["VALIDATE", "REFLECT", "IDENTITY & STRENGTH", "GENTLE GUIDANCE", "CONNECT TO ARTÉA"]:
		assert(history.text.contains(section), "the displayed reply contains %s" % section)
	assert(history.text.contains("Mind Spark Kingdom"), "the stress response connects to the relevant ARTÉA activity")
	assert(not history.text.contains("Why am I always stressed?"), "the private message is not copied into the transcript")

	chat.queue_free()
	print("MILO_MESSAGE_RECOGNITION_TEST: PASS — six emotions, grounded strength cues, uncertainty, privacy, and five-part replies")
	quit()
