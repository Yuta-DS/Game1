extends SceneTree

const ChatbotScene := preload("res://scenes/chatbot.tscn")


class FakeCampaign extends Node:
	var unlocked := {"mind": true, "heart": false, "creator": false}
	var entered: Array[String] = []
	var campaign_starts := 0
	var last_ignore_lock := false

	func can_enter_kingdom(kingdom_id: String) -> bool:
		return bool(unlocked.get(kingdom_id, false))

	func next_kingdom_id() -> String:
		for kingdom_id in ["mind", "heart", "creator"]:
			if bool(unlocked.get(kingdom_id, false)):
				return kingdom_id
		return ""

	func enter_kingdom(kingdom_id: String, _scene_tree: SceneTree = null,
			ignore_lock := false) -> bool:
		last_ignore_lock = ignore_lock
		entered.append(kingdom_id)
		return true

	func start_campaign() -> bool:
		campaign_starts += 1
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var real_campaign := root.get_node_or_null("JourneyCampaign")
	assert(real_campaign != null, "the production JourneyCampaign router is available")
	for kingdom_id in ["mind", "heart", "creator"]:
		var scene_path := str(real_campaign.call("kingdom_scene_path", kingdom_id))
		assert(not scene_path.is_empty() and ResourceLoader.exists(scene_path),
			"%s resolves to a real canonical activity scene" % kingdom_id)

	var campaign := FakeCampaign.new()
	root.add_child(campaign)
	var chat := ChatbotScene.instantiate()
	chat.campaign_router = campaign
	root.add_child(chat)
	await process_frame
	var choices := chat.get_node("Panel/VBoxContainer/ChoicesScroll/CuratedChoices") as VBoxContainer
	var history := chat.get_node("Panel/VBoxContainer/ChatHistory") as RichTextLabel
	var travel_requests: Array[String] = []
	chat.activity_travel_requested.connect(func(activity_id: String) -> void:
		travel_requests.append(activity_id)
	)

	for guide in chat.ACTIVITY_GUIDES:
		chat._respond_with_activity(guide)
		var destination_id := str(guide.activity_id)
		var destination_name := str(chat.ACTIVITY_DESTINATIONS[destination_id])
		assert(_has_button(choices, "Go with Milo to %s" % destination_name),
			"%s recommendation exposes an actionable travel control" % destination_name)

	assert(not chat.ACTIVITY_DESTINATIONS.has("crown") and chat.ACTIVITY_GUIDES.size() == 3,
		"Milo offers only the three minigame worlds, not the Crown of Life")
	for check_in in chat.EMOTION_CHECK_INS:
		assert(chat.ACTIVITY_DESTINATIONS.has(str(check_in.activity_id)),
			"%s routes to a minigame world" % str(check_in.label))

	chat._respond_with_activity(chat.ACTIVITY_GUIDES[0])
	(choices.get_node("MiloTravel_mind") as Button).pressed.emit()
	assert(campaign.entered == ["mind"] and travel_requests == ["mind"],
		"choosing an unlocked world goes straight there without a confirmation step")

	chat._respond_with_activity(chat.ACTIVITY_GUIDES[1])
	chat._confirm_activity_travel("heart")
	assert(history.text.contains("still locked") and history.text.contains("will not skip or invent progress"),
		"a locked recommendation explains the journey gate without changing progress")
	assert(campaign.entered == ["mind"], "locked Heart Melody never enters a scene")

	# The strength finder's suggestion opens its world even while locked.
	chat._show_strength_discoveries()
	for _question in chat.STRENGTH_QUESTIONS:
		chat._answer_strength_question("kindness")
	assert(history.text.contains("Try the Heart Melody world"),
		"the strength reveal suggests the world that matches the strength")
	assert(not history.text.contains("top of the castle") \
			and not history.text.contains("Other worlds also await") \
			and not history.text.contains("Try this") \
			and not _has_button(choices, "Try other worlds"),
		"away from the hub castle Milo never mentions the top of the castle")
	(choices.get_node("MiloTravel_heart") as Button).pressed.emit()
	assert(campaign.entered == ["mind", "heart"] and campaign.last_ignore_lock,
		"a strength suggestion goes straight into its world, even while locked")
	assert(campaign.campaign_starts == 0, "Milo never routes to the Crown of Life")

	chat.queue_free()
	campaign.queue_free()
	print("MILO_ACTIVITY_ROUTING_TEST: PASS — three minigame destinations, direct travel, canonical routes, and unlock protection")
	quit()


func _has_button(container: VBoxContainer, label: String) -> bool:
	for child in container.get_children():
		if child is Button and child.text == label:
			return true
	return false
