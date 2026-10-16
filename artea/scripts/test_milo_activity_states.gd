extends SceneTree

const MiloNPCScene := preload("res://scenes/milo_animations.tscn")
const ChatbotScene := preload("res://scenes/chatbot.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := CharacterBody3D.new()
	player.name = "NewPlayer"
	root.add_child(player)
	var milo := MiloNPCScene.instantiate() as CharacterBody3D
	root.add_child(milo)
	milo.set("gravity_enabled", false)
	milo.call("set_companion_player", player, false)
	var chat := ChatbotScene.instantiate()
	root.add_child(chat)
	await process_frame
	chat.companion_activity_state_requested.connect(
		milo._on_companion_activity_state_requested)
	chat.companion_pose_requested.connect(milo._on_companion_pose_requested)
	chat.companion_speech_requested.connect(milo._on_companion_speech_requested)

	chat._show_emotion_check_ins()
	assert(milo.get_companion_activity_name() == "LISTENING",
		"emotion check-in gives Milo an explicit listening activity")
	assert(milo.get_companion_state_name() == "TALKING",
		"presenting listening guidance temporarily owns the talking state")
	milo._stop_speaking()
	assert(milo.get_companion_state_name() == "LISTENING",
		"Milo returns to listening when the line finishes")

	chat._show_stage_reflections()
	milo._stop_speaking()
	assert(milo.get_companion_activity_name() == "REFLECTING",
		"stage reflection gives Milo a distinct reflecting activity")
	chat._show_activity_guides()
	milo._stop_speaking()
	assert(milo.get_companion_activity_name() == "GUIDING",
		"activity selection gives Milo a distinct guiding activity")
	chat._show_strength_discoveries()
	for _question in chat.STRENGTH_QUESTIONS:
		chat._answer_strength_question("perseverance")
	milo._stop_speaking()
	assert(milo.get_companion_activity_name() == "ENCOURAGING",
		"strength response gives Milo a distinct encouraging activity")
	chat._show_progress_celebration()
	milo._stop_speaking()
	assert(milo.get_companion_activity_name() == "CELEBRATING",
		"recorded progress gives Milo a distinct celebration activity")

	for state_name in ["GREETING", "LISTENING", "REFLECTING", "GUIDING", "ENCOURAGING", "CELEBRATING", "SUPPORTING"]:
		milo._on_companion_activity_state_requested(state_name)
		assert(milo.get_companion_activity_name() == state_name,
			"Milo exposes the complete %s activity state" % state_name)
	var before: String = str(milo.get_companion_activity_name())
	milo._on_companion_activity_state_requested("NOT_A_REAL_STATE")
	assert(milo.get_companion_activity_name() == before,
		"unknown activity requests cannot corrupt Milo's state")

	chat.queue_free()
	milo.queue_free()
	player.queue_free()
	print("MILO_ACTIVITY_STATES_TEST: PASS — greeting, listening, reflecting, guiding, encouraging, celebration, support, and talking return")
	quit()
