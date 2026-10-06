extends SceneTree

const ChatScene := preload("res://scenes/chatbot.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var chat := ChatScene.instantiate()
	root.add_child(chat)
	await process_frame
	var logical_phone := Vector2(1710.0, 3700.0)
	var physical_phone := Vector2(390.0, 844.0)
	var selected: Vector2 = chat.call("_select_chat_physical_size", logical_phone,
		Vector2(710.0, 1536.0), physical_phone)
	if selected != physical_phone:
		_fail("chat sizing does not prefer the browser CSS viewport")
		return
	chat.call("_layout_for_viewport", logical_phone, physical_phone)
	chat.call("_show_choices")
	await process_frame
	if str(chat.get_meta("chat_layout", "")) != "phone_readable_v1":
		_fail("portrait Web viewport does not select the readable chat layout")
		return
	var scale_value := float(chat.get_meta("chat_ui_scale", 0.0))
	var history := chat.get_node("MiloReplyCard/ChatHistory") as TextEdit
	var name_label := chat.get_node("MiloReplyCard/MiloName") as Label
	var card := chat.get_node("MiloReplyCard") as Control
	var banner := chat.get_node("InputBanner") as Control
	var field := chat.get_node("InputContent/CuratedChoices/LocalMessageRow/MiloMessageInput") as LineEdit
	var send := chat.get_node("InputContent/CuratedChoices/LocalMessageRow/MiloMessageSend") as Button
	if scale_value < 4.0 or history.get_theme_font_size("font_size") / scale_value < 15.5:
		_fail("portrait Milo reply is smaller than 16 CSS pixels")
		return
	if history.offset_top < name_label.offset_bottom:
		_fail("portrait Milo reply overlaps the speaker heading")
		return
	if field.custom_minimum_size.y / scale_value < 47.9 \
			or send.custom_minimum_size.y / scale_value < 47.9:
		_fail("portrait message controls are smaller than 48 CSS pixels")
		return
	if card.offset_bottom > banner.offset_top:
		_fail("portrait reply card overlaps the input banner")
		return

	var logical_landscape := Vector2(2405.0, 1112.0)
	var physical_landscape := Vector2(844.0, 390.0)
	chat.call("_layout_for_viewport", logical_landscape, physical_landscape)
	if not is_equal_approx(card.anchor_right, 0.47) \
			or not is_equal_approx(banner.anchor_left, 0.49):
		_fail("landscape chat does not use its side-by-side layout")
		return
	chat.queue_free()
	print("MOBILE_MILO_CHAT_LAYOUT_TEST: PASS — Milo reply text and message controls remain readable in portrait and landscape Web layouts")
	quit(0)


func _fail(message: String) -> void:
	push_error("MobileMiloChatLayout: " + message)
	quit(1)
