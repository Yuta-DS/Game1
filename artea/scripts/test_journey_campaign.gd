# Self-check for canonical Crown of Life campaign routing.
#   godot --headless --path artea --script res://scripts/test_journey_campaign.gd
#
# Uses an isolated JourneyState instance and never changes scenes. The contract
# is intentionally narrow: the router may inspect existing verified rewards,
# but it must never write a thought, emotion, artwork, strength, stage, story
# chapter, or treasure.
extends SceneTree

const TEST_SAVE := "user://test_journey_campaign.json"


func _init() -> void:
	var JourneyStateScript = load("res://scripts/JourneyState.gd")
	var CampaignScript = load("res://scripts/journey_campaign.gd")
	var state = JourneyStateScript.new()
	state.save_path = TEST_SAVE
	state.clear_journey()
	var campaign = CampaignScript.new()
	campaign.journey_state = state

	_test_scene_routes(campaign)
	_test_treasure_gated_order(campaign, state)
	_test_router_never_mutates_progress(campaign, state)

	state.clear_journey()
	campaign.free()
	state.free()
	print("JourneyCampaign: all checks passed")
	quit()


func _test_scene_routes(campaign: Node) -> void:
	assert(ResourceLoader.exists(campaign.CAMPAIGN_HOME_SCENE),
		"the Art Castle Galaxy is the campaign home")
	assert(ResourceLoader.exists(campaign.QUEST_JOURNAL_SCENE),
		"the connected quest journal scene exists")
	assert(ResourceLoader.exists(campaign.OPTIONAL_GUIDED_STORY_SCENE),
		"the optional guided Lens story remains available")
	var expected := {
		"mind": "res://scenes/popThoughtsMenu.tscn",
		"heart": "res://scenes/heart_melody/heart_melody_world.tscn",
		"creator": "res://scenes/drawing_tool.tscn",
	}
	for kingdom_id in expected:
		var path: String = campaign.kingdom_scene_path(kingdom_id)
		assert(path == expected[kingdom_id], "%s retains its real mini-game" % kingdom_id)
		assert(ResourceLoader.exists(path), "%s scene exists" % kingdom_id)

	var project := FileAccess.get_file_as_string("res://project.godot")
	assert(project.contains("JourneyCampaign=\"*res://scripts/journey_campaign.gd\""),
		"JourneyCampaign is registered as an autoload")
	var isles := FileAccess.get_file_as_string("res://scripts/hub_sky_isles.gd")
	assert(isles.contains("\"/root/JourneyCampaign\"") and isles.contains("\"enter_kingdom\""),
		"sky-isle portals delegate to the canonical campaign router")
	var portal := FileAccess.get_file_as_string("res://scripts/viewfinder/crown_story_portal.gd")
	assert(portal.contains("\"/root/JourneyCampaign\"") and portal.contains("\"start_campaign\""),
		"the Crown portal starts the connected campaign")
	for source_path in [
		"res://scripts/cloud_pop_finish.gd",
		"res://scripts/pop_thoughts_menu.gd",
		"res://scripts/music_minigame.gd",
		"res://scripts/drawing_tool.gd",
	]:
		var source := FileAccess.get_file_as_string(source_path)
		assert(source.contains("\"/root/JourneyCampaign\"")
			and source.contains("\"return_to_campaign\""),
			"%s returns to the Art Castle campaign" % source_path)

	var ritual_path := "res://scenes/gallery_frame_ritual.tscn"
	assert(ResourceLoader.exists(ritual_path), "the Creator ritual scene exists")
	for source_path in [
		"res://scripts/drawing_tool.gd",
		"res://scripts/creation_world/artwork_world_portal.gd",
	]:
		var creator_source := FileAccess.get_file_as_string(source_path)
		assert(creator_source.contains(ritual_path), "%s opens the canonical Creator ritual" % source_path)
		assert(not creator_source.contains("request_world(") and not creator_source.contains("request_creative_guide("),
			"%s keeps canonical Creator progression offline" % source_path)

	# The Art Castle gallery is an exploration surface, not the canonical
	# Creator's Light progression gate. Entering a displayed artwork opens the
	# interactive creation world while the drawing-tool ritual remains intact.
	var gallery_source := FileAccess.get_file_as_string("res://scripts/art_gallery.gd")
	assert(gallery_source.contains("res://scenes/creation_world.tscn")
		and gallery_source.contains("prepare_explorable_world"),
		"Art Castle artworks open their walkable interactive 3D worlds")


func _test_treasure_gated_order(campaign: Node, state: Node) -> void:
	assert(campaign.can_enter_kingdom("mind"), "Mind Spark starts the journey")
	assert(not campaign.can_enter_kingdom("heart"), "Heart Melody waits for Star of Wisdom")
	assert(not campaign.can_enter_kingdom("creator"), "Creator's Light waits for both earlier treasures")
	assert(campaign.next_kingdom_id() == "mind", "Mind Spark is the first unfinished kingdom")

	# Stage is decorative/wake state, never a shortcut through content.
	state.stage = 3
	assert(not campaign.can_enter_kingdom("heart"),
		"stage alone cannot open Heart Melody")

	state.record_thought_echo("I am learning and growing", "learning")
	state.record_thought_echo("I can take one brave step", "brave_step")
	state.mark_popped("I am learning and growing")
	assert(not state.has_treasure("star_of_wisdom"), "one echo cannot open Heart Melody")
	state.mark_popped("I can take one brave step")
	assert(state.complete_mind_spark(2), "two resolved curated echoes complete Mind Spark")
	assert(state.has_treasure("star_of_wisdom"), "thought completion earns the Star")
	assert(campaign.can_enter_kingdom("heart"), "Star of Wisdom opens Heart Melody")
	assert(not campaign.can_enter_kingdom("creator"), "Creator still waits for Harmony Jewel")
	assert(campaign.next_kingdom_id() == "heart", "Heart Melody is next")

	state.record_emotion("hope", Color(0.4, 0.8, 0.6))
	assert(not state.has_treasure("harmony_jewel"), "Island 1 feelings cannot grant the Jewel")
	assert(not campaign.can_enter_kingdom("creator"), "new Heart players remain on Island 1")
	# Explicit legacy-completion fixture for the remaining route tests.
	state.treasures["harmony_jewel"] = true
	assert(campaign.can_enter_kingdom("creator"), "both earlier treasures open Creator's Light")
	assert(campaign.next_kingdom_id() == "creator", "Creator's Light is next")

	var creation_id: String = str(state.record_creation("user://art/campaign.png", "A light bridge"))
	assert(not state.has_treasure("creators_light"),
		"saving artwork does not bypass the Creator ritual")
	assert(state.complete_creator_frame_ritual(creation_id, "star_bridge"),
		"the Gallery Frame Ritual completes the Creator kingdom")
	assert(state.has_all_treasures(), "three real activities complete the treasure set")
	assert(campaign.next_kingdom_id().is_empty(), "no kingdom remains locked after completion")


func _test_router_never_mutates_progress(campaign: Node, state: Node) -> void:
	var before := {
		"thoughts": state.thoughts.duplicate(true),
		"emotions": state.emotions.duplicate(true),
		"creations": state.creations.duplicate(true),
		"rituals": state.creation_rituals.duplicate(true),
		"strengths": state.strengths.duplicate(true),
		"treasures": state.treasures.duplicate(true),
		"chapters": state.story_chapters.duplicate(true),
		"stage": state.stage,
	}
	for kingdom_id in campaign.CAMPAIGN_ORDER:
		campaign.can_enter_kingdom(kingdom_id)
		campaign.is_kingdom_complete(kingdom_id, state)
		campaign.portal_status(kingdom_id)
		campaign.next_kingdom_id(state)
	assert(state.thoughts == before["thoughts"], "routing never writes thoughts")
	assert(state.emotions == before["emotions"], "routing never writes emotions")
	assert(state.creations == before["creations"], "routing never writes creations")
	assert(state.creation_rituals == before["rituals"], "routing never writes rituals")
	assert(state.strengths == before["strengths"], "routing never writes strengths")
	assert(state.treasures == before["treasures"], "routing never awards treasures")
	assert(state.story_chapters == before["chapters"], "routing never writes Lens chapters")
	assert(state.stage == before["stage"], "routing never changes stage")
