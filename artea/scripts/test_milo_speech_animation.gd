extends SceneTree

const MiloNPCScene := preload("res://scenes/milo_animations.tscn")
const ChatbotScene := preload("res://scenes/chatbot.tscn")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MILO_SPEECH_ANIMATION_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var player := CharacterBody3D.new()
	player.name = "NewPlayer"
	player.add_to_group("player")
	root.add_child(player)

	var milo := MiloNPCScene.instantiate() as CharacterBody3D
	root.add_child(milo)
	milo.set("gravity_enabled", false)
	milo.call("set_companion_player", player, false)
	await process_frame

	var closed := milo.find_child("Mouth", true, false) as MeshInstance3D
	var small := milo.find_child("MouthOpenSmall", true, false) as MeshInstance3D
	var wide := milo.find_child("MouthOpenWide", true, false) as MeshInstance3D
	var socket := milo.find_child("MouthSocket", true, false) as MeshInstance3D
	var tongue_small := milo.find_child("TongueSmall", true, false) as MeshInstance3D
	var tongue_wide := milo.find_child("TongueWide", true, false) as MeshInstance3D
	if closed == null or small == null or wide == null or socket == null \
			or tongue_small == null or tongue_wide == null:
		_fail("the socket, three mouth states, and coordinated tongues must all exist")
		return
	if not closed.visible or small.visible or wide.visible \
			or tongue_small.visible or tongue_wide.visible:
		_fail("Milo must begin with only his closed mouth visible")
		return
	var greeting_voice := milo.get_node_or_null("MiloGreetingVoice") \
		as AudioStreamPlayer3D
	var interaction_prompt := milo.get_node_or_null("InteractionPrompt") as Label3D
	var mayor_name := milo.get_node_or_null("MayorMiloName") as Label3D
	var interaction_shape := milo.get_node_or_null("Area3D/CollisionShape3D") \
		as CollisionShape3D
	print("MILO_CHAT_RANGE_TRACE: shape=%s radius=%s" % [interaction_shape.shape,
		interaction_shape.shape.radius if interaction_shape != null \
		and interaction_shape.shape is SphereShape3D else "n/a"])
	if interaction_prompt == null or interaction_prompt.text != "Press T to chat with Milo":
		_fail("Milo must visibly explain how to open chat")
		return
	if not InputMap.has_action("talk_to_milo"):
		_fail("Milo must use a dedicated talk action instead of the camera Q key")
		return
	var talk_events := InputMap.action_get_events("talk_to_milo")
	if talk_events.size() != 1 or not talk_events[0] is InputEventKey \
			or (talk_events[0] as InputEventKey).physical_keycode != KEY_T:
		_fail("Milo's dedicated talk action must use T")
		return
	if interaction_shape == null or not interaction_shape.shape is SphereShape3D \
			or (interaction_shape.shape as SphereShape3D).radius < 4.0:
		_fail("Milo's chat range must cover his companion follow distance")
		return
	if greeting_voice == null or greeting_voice.stream == null \
			or greeting_voice.stream.get_length() < 5.0:
		_fail("Milo's generated spatial greeting voice is missing or truncated")
		return
	if greeting_voice.stream.resource_path != "res://assets/audio/milo/milo_voice.ogg":
		_fail("Milo must use the approved milo_voice.ogg greeting")
		return
	milo.call("_on_area_3d_player_entered", player)
	milo.call("_process", 0.016)
	if interaction_prompt.visible:
		_fail("Milo's legacy standalone prompt must stay hidden to avoid duplicate guidance")
		return
	if mayor_name == null or not mayor_name.text.contains("Press T to chat"):
		_fail("Milo's proven nameplate must also show the nearby T instruction")
		return
	milo.call("_play_recorded_greeting")
	if not milo.call("is_speaking") or milo.call("get_mouth_shape") != "small":
		_fail("the original Milo recording must drive his speaking and mouth timeline")
		return
	if not greeting_voice.playing:
		_fail("the consented original Milo voice must play instead of device TTS")
		return
	milo.call("_on_area_3d_player_exited", player)
	player.global_position = Vector3(20.0, 0.0, 0.0)
	milo.call("_process", 0.016)
	if interaction_prompt.visible:
		_fail("Milo's T prompt must hide outside chat range")
		return
	if mayor_name.text != "Mayor Milo":
		_fail("Milo's nameplate must reset outside chat range")
		return
	milo.call("_stop_speaking")

	milo.call("_on_companion_speech_requested", "I hear you. Let us explore this together.")
	if not milo.call("is_speaking") or milo.call("get_mouth_shape") != "small":
		_fail("dynamic Rex/local-LLM text must start platform speech and mouth animation")
		return
	milo.call("_stop_speaking")
	if milo.call("is_speaking") or milo.call("get_mouth_shape") != "closed" \
			or not closed.visible or small.visible or wide.visible \
			or tongue_small.visible or tongue_wide.visible:
		_fail("stopping a line must restore exactly the closed mouth")
		return

	var chat := ChatbotScene.instantiate()
	root.add_child(chat)
	await process_frame
	milo.set("chatbot_ui", chat)
	var spoken_lines: Array[String] = []
	chat.companion_speech_requested.connect(func(text: String) -> void:
		spoken_lines.append(text)
		milo.call("_on_companion_speech_requested", text)
	)
	chat.call("_show_emotion_check_ins")
	if spoken_lines.is_empty() or not spoken_lines.back().contains("Emotional Companion"):
		_fail("each presented Milo response must publish its complete text as speech")
		return
	if not milo.call("is_speaking") or milo.call("get_companion_state_name") != "TALKING":
		_fail("dynamic chat must read the complete reply through Milo's speech path")
		return
	chat.call("replay_current_speech")
	if spoken_lines.size() != 2 or spoken_lines[0] != spoken_lines[1]:
		_fail("opening an already-rendered response must replay that same speech line")
		return

	chat.call("_show_chat_response", "Local Reflection",
		"Colour can guide the eye. Warm gold often feels nearer.")
	var history := chat.get_node("MiloReplyCard/ChatHistory") as TextEdit
	var role := chat.get_node("MiloReplyCard/MiloRole") as Label
	if history.text != "Colour can guide the eye." or not role.text.contains("1 OF 2"):
		_fail("the reply card must show only the LLM sentence Milo is currently reading")
		return
	milo.call("_present_spoken_sentence", 1)
	if history.text != "Warm gold often feels nearer." or not role.text.contains("2 OF 2"):
		_fail("the reading guide must advance with Milo's spoken sentence")
		return
	milo.call("_stop_speaking")
	if not history.text.contains("Colour can guide the eye. Warm gold often feels nearer.") \
			or role.text != "ART SCHOLAR  ·  READY":
		_fail("the complete LLM reply must return after Milo finishes reading")
		return

	chat.queue_free()
	milo.set("chatbot_ui", null)
	milo.call("_stop_speaking")
	milo.queue_free()
	player.queue_free()
	await process_frame
	var source := FileAccess.get_file_as_string("res://scripts/milo_animations.gd")
	if not source.contains("use_device_tts_for_dynamic_replies := true"):
		_fail("dynamic reply speech must remain enabled by default")
		return
	print("MILO_SPEECH_ANIMATION_TEST: PASS — original Milo greeting, spoken dynamic replies, T access, and rigged mouth shapes")
	quit()
