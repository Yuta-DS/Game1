extends SceneTree

const ConversationContext := preload("res://scripts/MiloConversationContext.gd")
const WisdomEngine := preload("res://scripts/MiloWisdomEngine.gd")
const ReflectionEngine := preload("res://scripts/MiloReflectionEngine.gd")
const ChatbotScene := preload("res://scenes/chatbot.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var context := ConversationContext.new()
	assert(str(context.personality.identity).contains("art mentor"),
		"Milo's permanent personality includes his Artéa art-mentor role")
	context.update_scene("CreatorLight", 3, "universal", "painting", false)
	context.observe_player_message(
		"Please explain my composition in more detail; I feel stuck.",
		"frustrated", "visual_language")
	var first_snapshot := context.snapshot()
	assert(first_snapshot.scene_state.scene == "CreatorLight" \
		and first_snapshot.scene_state.activity == "painting",
		"scene state records the current Artéa location and activity")
	assert(first_snapshot.relationship_memory.response_preference == "detailed" \
		and first_snapshot.relationship_memory.last_expressed_state == "frustrated",
		"relationship memory uses only explicit message signals")

	var reflection := ReflectionEngine.new().reflect("I feel stuck with this painting")
	var natural_first := context.naturalize_reflection(reflection,
		"I feel stuck with this painting")
	context.record_exchange("I feel stuck with this painting", natural_first, "guide")
	var natural_second := context.naturalize_reflection(reflection,
		"I am still stuck with the colours")
	assert(natural_first.get_slice(".", 0) != natural_second.get_slice(".", 0),
		"phrase history prevents an immediately repeated conversational opening")
	assert(not natural_first.contains("VALIDATE") and not natural_first.contains("REFLECT\n"),
		"Web-safe authored reflections read as conversation rather than a template")

	for index in range(6):
		context.record_exchange("player turn %d" % index, "Milo answer %d" % index,
			"reflect")
	var bounded := context.snapshot()
	assert(bounded.recent_turns.size() == ConversationContext.MAX_RECENT_TURNS,
		"recent dialogue is bounded to four shortened turns")
	assert(bounded.relationship_memory.rapport_stage == "familiar",
		"rapport grows from completed exchanges without claiming hidden trust")

	var wisdom := WisdomEngine.new()
	var art := wisdom.respond("How can I improve the colour and composition of my painting?",
		"universal", context.snapshot())
	assert(art.category == "visual_language" and str(art.text).contains("ART ·"),
		"Milo routes visual-art questions into grounded art knowledge")
	assert(str(art.text).contains("observable") or str(art.text).contains("Visual language"),
		"art guidance separates visible evidence from interpretation")
	var mixed := wisdom.respond(
		"What can art, science, and philosophy say about colour perception?",
		"universal", context.snapshot())
	for label in ["ART ·", "SCIENCE ·", "PHILOSOPHY ·", "IN DIALOGUE ·"]:
		assert(str(mixed.text).contains(label),
			"mixed art question preserves the %s boundary" % label)
	var packet := wisdom.build_local_model_packet("Help with my painting", art,
		context.snapshot())
	for required in ["SESSION CONTEXT", "CreatorLight", "Recent shortened turns",
			"Do not reuse these recent openings"]:
		assert(packet.contains(required),
			"local model receives bounded context field: %s" % required)

	var context_source := FileAccess.get_file_as_string(
		"res://scripts/MiloConversationContext.gd")
	for forbidden in ["FileAccess.WRITE", "store_string(", "HTTPRequest", "HTTPClient"]:
		assert(not context_source.contains(forbidden),
			"conversation context remains session-only: %s" % forbidden)

	var live_context := ConversationContext.new()
	var chat = ChatbotScene.instantiate()
	root.add_child(chat)
	await process_frame
	chat.configure_conversation_context(live_context, "ArtStudio", "painting")
	var input := chat.user_input as LineEdit
	var history := chat.get_node("VBoxContainer/ChatHistory") as TextEdit
	input.text = "How can I improve the composition of my painting?"
	chat._submit_message(input)
	assert(history.text.contains("ART ·") and history.text.to_lower().contains("composition"),
		"live Web-safe Milo chat displays grounded art guidance; got: %s" % history.text)
	assert(int(live_context.relationship_memory.interaction_count) == 1,
		"the shared session context remembers the completed live exchange")
	chat.queue_free()

	print("MILO_CONVERSATION_CONTEXT_TEST: PASS — personality, scene, bounded memory, anti-repetition, natural authored speech, and art knowledge")
	quit()
