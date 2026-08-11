# Focused production check for the child/school-safe Milo surface.
# Run headless:
#   godot --headless --path artea --script res://scripts/test_safe_milo_reflection.gd
extends SceneTree

const CHATBOT_SCENE := preload("res://scenes/chatbot.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var source := FileAccess.get_file_as_string("res://scenes/chatbot.gd")
	var scene_source := FileAccess.get_file_as_string("res://scenes/chatbot.tscn")

	assert(source.contains("CURATED_REFLECTIONS"), "Milo has an authored local reflection catalogue")
	for forbidden in ["HTTPRequest", "NobodyWhoChat", "NobodyWhoModel", "openai_api_key", ".say("]:
		assert(not source.contains(forbidden), "Milo script does not contain %s" % forbidden)
		assert(not scene_source.contains(forbidden), "Milo scene does not contain %s" % forbidden)

	assert(not scene_source.contains("UserInput"), "the scene exposes no free-text input")
	assert(not scene_source.contains("SendButton"), "the scene exposes no send control")

	var chat = CHATBOT_SCENE.instantiate()
	root.add_child(chat)
	await process_frame

	var history := chat.get_node_or_null("VBoxContainer/ChatHistory") as TextEdit
	var choices := chat.get_node_or_null("VBoxContainer/CuratedChoices") as VBoxContainer
	assert(history != null and not history.editable, "Milo transcript is read-only")
	assert(history.text.contains("Choose one, or skip"), "Milo explains the safe, skippable choice")
	assert(choices != null, "Milo builds curated reflection choices")
	assert(chat.user_input is Button, "legacy Milo interaction focuses a curated button, not text input")
	assert(_has_button(choices, "Skip this reflection"), "skipping is explicit")
	assert(_has_button(choices, "Close"), "closing is always explicit")
	assert(_has_button(choices, "Need help"), "support remains available from Milo")

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
