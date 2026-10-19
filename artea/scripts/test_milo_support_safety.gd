extends SceneTree

const ReflectionEngine := preload("res://scripts/MiloReflectionEngine.gd")
const ChatbotScene := preload("res://scenes/chatbot.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var engine := ReflectionEngine.new()
	for urgent_message in [
		"I want to hurt myself",
		"I want to die",
		"I am not safe",
		"Someone is hurting me",
	]:
		var urgent: Dictionary = engine.reflect(urgent_message)
		assert(bool(urgent.get("urgent", false)), "%s opens urgent support" % urgent_message)
		assert(urgent.emotion == "urgent_support", "urgent text bypasses ordinary emotion matching")
		assert(str(urgent.guidance).contains("trusted adult") and str(urgent.activity).contains("000"),
			"urgent response gives a trusted-person step and Australian emergency route")

	var ordinary: Dictionary = engine.reflect("I am frustrated with this puzzle")
	assert(not bool(ordinary.get("urgent", false)), "ordinary frustration is not falsely escalated")

	var chat := ChatbotScene.instantiate()
	root.add_child(chat)
	await process_frame
	chat._show_support()
	var support_card := chat.get_node_or_null("MiloSupportCard")
	assert(support_card != null and support_card.call("is_card_visible"),
		"Need help opens a real support card without a removed autoload")
	assert(_visible_text(support_card).contains("1800 55 1800"),
		"support card includes Kids Helpline for young Australian players")
	assert(_visible_text(support_card).contains("13 11 14") and _visible_text(support_card).contains("000"),
		"support card includes verified Lifeline and emergency contacts")

	var input := chat.user_input as LineEdit
	chat._show_choices()
	input = chat.user_input as LineEdit
	input.text = "I want to hurt myself"
	chat._submit_message(input)
	var history := chat.get_node("Panel/VBoxContainer/ChatHistory") as RichTextLabel
	assert(input.text.is_empty(), "urgent private wording is cleared immediately")
	assert(not history.text.contains("I want to hurt myself"), "urgent private wording is never echoed")
	assert(history.text.contains("Get real-world help now") and history.text.contains("trusted adult"),
		"urgent wording replaces normal reflection with direct real-world support")
	assert(support_card.call("is_card_visible"), "urgent wording opens the support card automatically")

	chat.queue_free()
	print("MILO_SUPPORT_SAFETY_TEST: PASS — urgent interception, trusted-adult guidance, verified contacts, working card, and no message echo")
	quit()


func _visible_text(node: Node) -> String:
	var result := ""
	if node is Label:
		result += (node as Label).text + "\n"
	for child in node.get_children():
		result += _visible_text(child)
	return result
