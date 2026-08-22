extends SceneTree

const CHATBOT_SCENE := preload("res://scenes/chatbot.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var chat = CHATBOT_SCENE.instantiate()
	root.add_child(chat)
	await process_frame
	var requested_poses: Array[String] = []
	chat.companion_pose_requested.connect(func(pose_name: String) -> void:
		requested_poses.append(pose_name)
	)

	var history := chat.get_node("VBoxContainer/ChatHistory") as TextEdit
	var choices := chat.get_node("VBoxContainer/CuratedChoices") as VBoxContainer
	chat._show_choices()
	assert(requested_poses.back() == "welcome",
		"the companion menu uses Milo's welcoming cane pose")
	for companion_path in [
		"Check in with a feeling",
		"Reflect with Milo",
		"Discover a strength",
		"Celebrate my progress",
		"Choose an ARTÉA activity",
	]:
		assert(_has_button(choices, companion_path),
			"Wonderful Counsellor Milo exposes %s" % companion_path)

	chat._show_emotion_check_ins()
	assert(requested_poses.back() == "heart",
		"emotion check-in uses Milo's compassionate hand-on-heart pose")
	assert(history.text.contains("Emotional Companion"),
		"Milo offers an explicit emotional check-in")
	assert(_has_button(choices, "I feel worried or unsure"),
		"players name their own feeling instead of Milo inferring it")
	chat._respond_to_emotion({
		"label": "I feel worried or unsure",
		"acknowledge": "ACKNOWLEDGE",
		"strength": "COURAGE",
		"question": "REFLECTION QUESTION",
		"activity": "MIND SPARK ACTIVITY",
	})
	assert(requested_poses.back() == "encourage",
		"emotion response opens Milo's arms in encouragement")
	for evidence in ["ACKNOWLEDGE", "COURAGE", "REFLECTION QUESTION", "MIND SPARK ACTIVITY"]:
		assert(history.text.contains(evidence),
			"emotion response contains %s" % evidence)

	chat._show_strength_discoveries()
	assert(requested_poses.back() == "encourage",
		"strength discovery uses Milo's encouraging pose")
	assert(history.text.contains("Strength Discoverer"),
		"Milo offers strengths-based reflection")
	chat._respond_to_strength({
		"label": "I kept trying",
		"strength": "PERSEVERANCE",
		"reflection": "OBSERVED ACTION",
		"question": "STRENGTH QUESTION",
	})
	for evidence in ["PERSEVERANCE", "OBSERVED ACTION", "STRENGTH QUESTION"]:
		assert(history.text.contains(evidence),
			"strength response contains %s" % evidence)

	chat._stage = 3
	chat._show_progress_celebration()
	assert(requested_poses.back() == "encourage",
		"progress celebration uses Milo's celebratory pose")
	assert(history.text.contains("Creator's Light"),
		"progress celebration uses recorded journey stage")
	assert(history.text.contains("Creative courage"),
		"progress celebration names a stage-grounded strength")
	assert(history.text.contains("does not add or remove rewards"),
		"reflection never manufactures game progress")

	chat._show_activity_guides()
	assert(requested_poses.back() == "map",
		"activity selection uses Milo's map-reading pose")
	assert(history.text.contains("Journey Guide"),
		"Milo offers ARTÉA activity guidance")
	chat._respond_with_activity({
		"activity": "HEART MELODY",
		"guide": "SOUND GUIDANCE",
	})
	assert(requested_poses.back() == "guide",
		"activity guidance uses Milo's pointing pose with planted cane")
	assert(history.text.contains("HEART MELODY") and history.text.contains("SOUND GUIDANCE"),
		"activity response includes the destination and a concrete first step")

	chat._show_stage_reflections()
	assert(requested_poses.back() == "tablet",
		"reflection path uses Milo's glowing tablet pose")
	assert(history.text.contains("Reflection Partner"),
		"the original stage reflection remains available")
	assert(_has_button(choices, "Back to companion paths"),
		"every deep path has a clear return")
	assert(_has_button(choices, "Need help"),
		"real-world support remains available")
	assert(_has_button(choices, "Close"),
		"the companion can always be dismissed")

	chat.queue_free()
	print("WONDERFUL_COUNSELLOR_MILO_TEST: PASS — five safe roles drive six readable counsellor poses end to end")
	quit()


func _has_button(container: VBoxContainer, text: String) -> bool:
	for child in container.get_children():
		if child is Button and child.text == text:
			return true
	return false
