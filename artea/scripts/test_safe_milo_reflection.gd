# Focused production check for the child/school-safe Milo surface.
# Run headless:
#   godot --headless --path artea --script res://scripts/test_safe_milo_reflection.gd
extends SceneTree

const CHATBOT_SCENE := preload("res://scenes/chatbot.tscn")


class FakeLocalChat extends Node:
	signal response_updated(new_token: String)
	signal response_finished(response: String)
	var last_message := ""

	func say(message: String) -> void:
		last_message = message

	func stop_generation() -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string("res://scenes/chatbot.gd")
	var engine_source := FileAccess.get_file_as_string("res://scripts/MiloReflectionEngine.gd")
	var scene_source := FileAccess.get_file_as_string("res://scenes/chatbot.tscn")

	assert(source.contains("CURATED_REFLECTIONS"), "Milo has an authored local reflection catalogue")
	assert(source.contains("gemma-2-2b-it-Q4_K_M.gguf"), "Milo targets the bundled local Gemma model")
	assert(source.contains("milo_prompt.txt"), "Milo uses the existing local system prompt")
	assert(source.contains("ClassDB.instantiate"), "NobodyWho is loaded dynamically for Web compatibility")
	assert(not scene_source.contains("NobodyWhoChat") and not scene_source.contains("NobodyWhoModel"),
		"the Web-loadable chat scene has no native-only NobodyWho node types")
	for forbidden in ["HTTPRequest", "openai_api_key", "Firebase", "HTTPClient", "user://", "ConfigFile"]:
		assert(not source.contains(forbidden), "Milo script does not contain %s" % forbidden)
		assert(not engine_source.contains(forbidden), "Milo matcher does not contain %s" % forbidden)
		assert(not scene_source.contains(forbidden), "Milo scene does not contain %s" % forbidden)
	for write_api in ["FileAccess.open", "store_string", "store_line", "store_var"]:
		assert(not source.contains(write_api), "Milo does not persist messages with %s" % write_api)
		assert(not engine_source.contains(write_api), "Milo matcher does not persist messages with %s" % write_api)

	var chat = CHATBOT_SCENE.instantiate()
	root.add_child(chat)
	await process_frame

	var history := chat.get_node_or_null("VBoxContainer/ChatHistory") as TextEdit
	var choices := chat.get_node_or_null("VBoxContainer/CuratedChoices") as VBoxContainer
	var banner := chat.get_node("Banner") as TextureRect
	var message_row := choices.get_node("LocalMessageRow") as HBoxContainer
	var message_input := message_row.get_node("MiloMessageInput") as LineEdit
	var message_send := message_row.get_node("MiloMessageSend") as Button
	assert(history != null and not history.editable, "Milo transcript is read-only")
	assert(history.text.contains("What would you like to talk about"),
		"Milo opens the direct chat conversation")
	assert(choices != null, "Milo builds the direct chat input surface")
	assert(chat.user_input is LineEdit, "Milo focuses the bounded local reflection field")
	assert(chat.user_input.max_length == 280, "typed reflection is strictly bounded")
	assert(chat.user_input.tooltip_text.contains("not saved"), "the input explains local privacy")
	assert(_has_button(choices, "Ask Milo"), "the chat input keeps a send control")
	assert(banner.get_global_rect().encloses(history.get_global_rect()) \
		and banner.get_global_rect().encloses(message_row.get_global_rect()),
		"Milo's reply and input stay inside the parchment banner")
	assert(absf(history.get_global_rect().position.x \
		- message_row.get_global_rect().position.x) < 1.0 \
		and absf(history.get_global_rect().end.x \
		- message_row.get_global_rect().end.x) < 1.0,
		"Milo's reply and input use one aligned content column")
	assert(is_equal_approx(message_input.size.y, message_send.size.y),
		"the Milo input and send control share one height")
	for removed_option in ["Skip this reflection", "Close", "Need help"]:
		assert(not _has_button(choices, removed_option),
			"chat-only Milo removes the %s option" % removed_option)
	assert(not chat.is_local_llm_active(), "headless/Web-safe tests use the authored fallback")

	var fake_chat := FakeLocalChat.new()
	chat.add_child(fake_chat)
	chat._attach_local_llm_chat(fake_chat)
	message_input = chat.user_input as LineEdit
	message_input.text = "I need a calm next step"
	chat._submit_message(message_input)
	assert(fake_chat.last_message.contains("PLAYER MESSAGE") \
		and fake_chat.last_message.contains("I need a calm next step") \
		and fake_chat.last_message.contains("GROUNDED MILO NOTES"),
		"a safe typed message is sent to the local LLM inside a grounded context packet")
	assert(history.text.contains("local model"), "Milo shows local inference status")
	fake_chat.response_updated.emit("I see you. ")
	fake_chat.response_finished.emit("I see you. Take one gentle step when you are ready.")
	assert(history.text.contains("Local Reflection"), "the completed local response is presented by Milo")
	assert(history.text.contains("one gentle step"), "Milo displays the local model response")
	var visible_chat_buttons := choices.find_children("*", "Button", true, false)
	assert(visible_chat_buttons.size() == 1 \
		and (visible_chat_buttons[0] as Button).text == "Ask Milo",
		"Milo's completed reply returns to the chat-only input surface")

	chat._choose_reflection({
		"label": "Skip this reflection",
		"faith": "That is okay. Skipping this moment does not change your journey.",
		"universal": "That is okay. Skipping this moment does not change your journey.",
	})
	assert(history.text.contains("does not change your journey"), "a reflection choice does not claim a reward")
	assert(_has_button(choices, "Continue my adventure"), "a non-rewarding continue route remains")

	chat._mode = "universal"
	chat._choose_reflection({
		"label": "Register check",
		"faith": "FAITH_REGISTER_ONLY",
		"universal": "UNIVERSAL_REGISTER_ONLY",
	})
	assert(history.text.contains("UNIVERSAL_REGISTER_ONLY"), "Milo uses the selected universal register")
	assert(not history.text.contains("FAITH_REGISTER_ONLY"), "Milo does not mix registers in universal mode")

	chat.queue_free()
	print("safe Milo reflection: all checks passed")
	quit()


func _has_button(container: VBoxContainer, text: String) -> bool:
	for child in container.find_children("*", "Button", true, false):
		if (child as Button).text == text:
			return true
	return false
