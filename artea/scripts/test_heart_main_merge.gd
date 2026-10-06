extends SceneTree

func _init() -> void:
	run.call_deferred()

func run() -> void:
	var campaign = root.get_node("JourneyCampaign")
	var state = load("res://scripts/JourneyState.gd").new()
	state.save_path = "res://../work/merge-route-state.json"
	state.clear_journey()
	var before: Dictionary = state.treasures.duplicate(true)
	assert(campaign.kingdom_scene_path("heart") == "res://scenes/music_minigame.tscn")
	assert(not campaign.can_enter_kingdom_with("heart", state))
	assert(campaign.can_enter_kingdom_with("heart_melody", state))
	assert(campaign.kingdom_scene_path("heart_melody") == "res://scenes/heart_melody/heart_melody_world.tscn")
	assert(state.treasures == before, "route checks never award treasure")
	state.record_emotion("hope", Color.PINK)
	assert(state.has_treasure("harmony_jewel"), "main's original music activity keeps its reward")
	assert(not campaign.can_enter_kingdom_with("creator", state), "Star of Wisdom still required")
	var tracker = load("res://scripts/player_identity_tracker.gd").new()
	tracker.save_path = "res://../work/merge-route-identity.json"
	assert(tracker.record_evidence("MS_MERGE_TEST", "energy", "E"))
	assert(tracker.record_evidence("HM_MERGE_TEST", "energy", "I", "heart_melody"))
	assert(tracker.clear_world_evidence("heart_melody"))
	assert(tracker.has_evidence("MS_MERGE_TEST") and not tracker.has_evidence("HM_MERGE_TEST"))
	state.clear_journey()
	state.free()
	tracker.free()
	print("HEART MAIN MERGE: PASS")
	quit()
