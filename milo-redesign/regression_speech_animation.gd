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

	var milo := _redesign_instance(MiloNPCScene)
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
	if greeting_voice == null or greeting_voice.stream == null \
			or greeting_voice.stream.get_length() < 5.0:
		_fail("Milo's generated spatial greeting voice is missing or truncated")
		return
	if greeting_voice.stream.resource_path != "res://assets/audio/milo/milo_voice.ogg":
		_fail("Milo must use the approved milo_voice.ogg greeting")
		return
	milo.call("_play_recorded_greeting")
	if not greeting_voice.playing or not milo.call("is_speaking") \
			or milo.call("get_mouth_shape") != "small":
		_fail("the recorded greeting must drive Milo's speaking and mouth timeline")
		return
	greeting_voice.stop()
	milo.call("_stop_speaking")

	milo.call("_on_companion_speech_requested", "I hear you. Let us explore this together.")
	if not milo.call("is_speaking") or milo.call("get_mouth_shape") != "small":
		_fail("a companion line must immediately begin the talking timeline")
		return
	milo.call("_update_speaking", 0.12)
	if milo.call("get_mouth_shape") != "wide" or not wide.visible \
			or not tongue_wide.visible or tongue_small.visible:
		_fail("the talking timeline must reach Milo's readable wide-open mouth")
		return
	milo.call("_update_speaking", 0.11)
	if milo.call("get_mouth_shape") != "small" or not small.visible \
			or not tongue_small.visible or tongue_wide.visible:
		_fail("the talking timeline must alternate between open mouth shapes")
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
		_fail("chatbot speech must drive the live companion into TALKING state")
		return
	chat.call("replay_current_speech")
	if spoken_lines.size() != 2 or spoken_lines[0] != spoken_lines[1]:
		_fail("opening an already-rendered response must replay that same speech line")
		return

	chat.queue_free()
	milo.call("_stop_speaking")
	milo.queue_free()
	player.queue_free()
	await process_frame
	print("MILO_SPEECH_ANIMATION_TEST: PASS — chatbot lines drive three rigged mouth shapes and close cleanly")
	quit()


func _redesign_instance(source: PackedScene) -> CharacterBody3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file("/Users/davidsovann/S2603/milo-redesign/milo_redesign.glb", state) == OK)
	var model := doc.generate_scene(state)
	var milo := source.instantiate() as CharacterBody3D
	var skin := milo.get_node("Model")
	var original := skin.get_node("Model")
	skin.remove_child(original)
	original.free()
	model.name = "Model"
	skin.add_child(model)
	return milo
