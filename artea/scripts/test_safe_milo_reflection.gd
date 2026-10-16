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
	for forbidden in ["openai_api_key", "Firebase", "user://", "ConfigFile"]:
		assert(not source.contains(forbidden), "Milo script does not contain %s" % forbidden)
		assert(not engine_source.contains(forbidden), "Milo matcher does not contain %s" % forbidden)
		assert(not scene_source.contains(forbidden), "Milo scene does not contain %s" % forbidden)
	# The Web build's cloud LLM path legitimately uses HTTPRequest/HTTPClient
	# to reach Milo's own Cloudflare Worker proxy - never a model API
	# directly, and never with an embedded key. The safety matcher and the
	# scene file itself still make zero network calls; verify chatbot.gd's
	# usage stays scoped to the one known, trusted endpoint.
	for forbidden in ["HTTPRequest", "HTTPClient"]:
		assert(not engine_source.contains(forbidden), "Milo matcher does not contain %s" % forbidden)
		assert(not scene_source.contains(forbidden), "Milo scene file declares no network node for %s" % forbidden)
	if source.contains("HTTPRequest") or source.contains("HTTPClient"):
		assert(source.contains("CLOUD_LLM_ENDPOINT"),
			"any HTTPRequest/HTTPClient usage in Milo's script is scoped to the known cloud proxy endpoint")
		for direct_api in ["api.openai.com", "generativelanguage.googleapis.com", "api.anthropic.com"]:
			assert(not source.contains(direct_api),
				"Milo's script never calls a model API directly - only its own proxy")
	for write_api in ["FileAccess.open", "store_string", "store_line", "store_var"]:
		assert(not source.contains(write_api), "Milo does not persist messages with %s" % write_api)
		assert(not engine_source.contains(write_api), "Milo matcher does not persist messages with %s" % write_api)

	var chat = CHATBOT_SCENE.instantiate()
	root.add_child(chat)
	await process_frame

	var history := chat.get_node_or_null("Panel/VBoxContainer/ChatHistory") as RichTextLabel
	var choices := chat.get_node_or_null("Panel/VBoxContainer/ChoicesScroll/CuratedChoices") as VBoxContainer
	assert(history != null, "Milo has a read-only rich-text transcript")
	assert(history.text.contains("Nothing you choose here changes your progress"), "Milo explains that choices are safe")
	assert(choices != null, "Milo builds curated reflection choices")
	assert(chat.user_input is LineEdit, "Milo focuses the local reflection field")
	assert(chat.user_input.max_length == 0, "typed reflection has no length limit")
	assert(chat.user_input.tooltip_text.contains("not saved"), "the input explains local privacy")
	assert(_has_button(choices, "Close"), "closing is always explicit")
	assert(_has_button(choices, "Need help"), "support remains available from Milo")
	assert(not chat.is_local_llm_active(), "headless/Web-safe tests use the authored fallback")

	var fake_chat := FakeLocalChat.new()
	chat.add_child(fake_chat)
	chat._attach_local_llm_chat(fake_chat)
	var message_input := chat.user_input as LineEdit
	message_input.text = "I need a calm next step"
	chat._submit_message(message_input)
	assert(fake_chat.last_message == "I need a calm next step",
		"a safe typed message is sent to the existing local LLM")
	assert(history.text.contains("local model"), "Milo shows local inference status")
	fake_chat.response_updated.emit("I see you. ")
	fake_chat.response_finished.emit("I see you. Take one gentle step when you are ready.")
	assert(history.text.contains("Local Reflection"), "the completed local response is presented by Milo")
	assert(history.text.contains("one gentle step"), "Milo displays the local model response")

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
	for child in container.get_children():
		if child is Button and child.text == text:
			return true
	return false
