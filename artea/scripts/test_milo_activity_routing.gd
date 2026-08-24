extends SceneTree

const ChatbotScene := preload("res://scenes/chatbot.tscn")


class FakeCampaign extends Node:
	var unlocked := {"mind": true, "heart": false, "creator": false}
	var entered: Array[String] = []
	var campaign_starts := 0

	func can_enter_kingdom(kingdom_id: String) -> bool:
		return bool(unlocked.get(kingdom_id, false))

	func next_kingdom_id() -> String:
		for kingdom_id in ["mind", "heart", "creator"]:
			if bool(unlocked.get(kingdom_id, false)):
				return kingdom_id
		return ""

	func enter_kingdom(kingdom_id: String) -> bool:
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
	var choices := chat.get_node("VBoxContainer/CuratedChoices") as VBoxContainer
	var history := chat.get_node("VBoxContainer/ChatHistory") as TextEdit
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

	chat._respond_with_activity(chat.ACTIVITY_GUIDES[0])
	chat._confirm_activity_travel("mind")
	assert(history.text.contains("Ready to travel") and _has_button(choices, "Yes, go with Milo"),
		"an unlocked route requires explicit confirmation")
	chat._travel_to_activity("mind")
	assert(campaign.entered == ["mind"] and travel_requests == ["mind"],
		"confirmation enters exactly the canonical Mind Spark route")

	chat._respond_with_activity(chat.ACTIVITY_GUIDES[1])
	chat._confirm_activity_travel("heart")
	assert(history.text.contains("still locked") and history.text.contains("will not skip or invent progress"),
		"a locked recommendation explains the journey gate without changing progress")
	assert(campaign.entered == ["mind"], "locked Heart Melody never enters a scene")

	chat._respond_with_activity(chat.ACTIVITY_GUIDES[3])
	chat._confirm_activity_travel("crown")
	chat._travel_to_activity("crown")
	assert(campaign.campaign_starts == 1 and travel_requests.back() == "crown",
		"Crown of Life routes through the canonical campaign home")

	chat.queue_free()
	campaign.queue_free()
	print("MILO_ACTIVITY_ROUTING_TEST: PASS — four actionable destinations, confirmation, canonical routes, and unlock protection")
	quit()


func _has_button(container: VBoxContainer, label: String) -> bool:
	for child in container.get_children():
		if child is Button and child.text == label:
			return true
	return false
