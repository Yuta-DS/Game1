extends SceneTree

const JournalScene := preload("res://scenes/crown_quest_journal.tscn")
const Catalog := preload("res://scripts/crown_story_catalog.gd")
const Tracker := preload("res://scripts/crown_quest_tracker.gd")


class FakeJourneyState extends Node:
	var audience_mode := "faith"
	var treasures := {
		"star_of_wisdom": false,
		"harmony_jewel": false,
		"creators_light": false,
	}
	var thoughts := [{"text": "PRIVATE_SENTINEL_THOUGHT"}]
	var emotions := [{"name": "PRIVATE_SENTINEL_EMOTION"}]
	var creations := [{"title": "PRIVATE_SENTINEL_ART"}]

	func has_treasure(treasure_id: String) -> bool:
		return bool(treasures.get(treasure_id, false))


class FakeCampaign extends RefCounted:
	var return_count := 0

	func return_to_campaign() -> bool:
		return_count += 1
		return true


func _init() -> void:
	var catalog := Catalog.load_catalog()
	assert(Catalog.validate(catalog).is_empty(), "Journal test requires the valid authored catalog.")
	await _test_tracker_free_safe_fallback(catalog)
	await _test_tracker_and_audience_presentation(catalog)
	_test_source_has_no_persistence()
	_test_castle_entry_wiring()
	print("CrownQuestJournal: all checks passed")
	quit(0)


func _test_tracker_free_safe_fallback(catalog: Dictionary) -> void:
	var state := FakeJourneyState.new()
	state.treasures["star_of_wisdom"] = true
	var before := state.treasures.duplicate(true)
	var campaign := FakeCampaign.new()
	var journal = JournalScene.instantiate()
	journal.configure(catalog, null, state, campaign, "universal")
	root.add_child(journal)
	await process_frame
	assert(journal.kingdom_card_count() == 3, "Journal shows exactly three ordered kingdom cards.")
	assert(journal.arc_status("mind") == "completed", "Canonical Star of Wisdom marks Mind complete.")
	assert(journal.arc_status("heart") == "current", "The next treasure-free kingdom is current.")
	assert(journal.arc_status("creator") == "locked", "Later kingdom remains visibly locked.")
	var visible: String = journal.visible_text()
	assert(visible.contains("Mind Spark Kingdom") and visible.contains("Heart Melody Kingdom") and visible.contains("Creator's Light Kingdom"), "All three authored kingdoms are visible.")
	assert(visible.contains("PURPOSE") and visible.contains("REASON"), "Quest and task purpose/reason are explicit.")
	assert(visible.contains("NOT TRACKED"), "Without a tracker, task completion is never invented.")
	assert(not visible.contains("PRIVATE_SENTINEL"), "Personal thoughts, emotions, and artwork never enter journal text.")
	assert(state.treasures == before, "Rendering never mutates canonical journey state.")
	assert(journal._on_back_pressed(), "Back delegates to the injected campaign.")
	assert(campaign.return_count == 1, "Back requests exactly one safe castle return.")
	journal.queue_free()
	await process_frame


func _test_tracker_and_audience_presentation(catalog: Dictionary) -> void:
	var state := FakeJourneyState.new()
	var tracker := Tracker.new(catalog)
	assert(tracker.submit_evidence("story.prologue.complete")["accepted"], "Prologue can begin tracked presentation.")
	var journal = JournalScene.instantiate()
	journal.configure(catalog, tracker, state, FakeCampaign.new(), "faith")
	root.add_child(journal)
	await process_frame
	assert(journal.arc_status("mind") == "current", "Tracker identifies the first active kingdom.")
	assert(journal.guardian_text("mind").contains("Truth is a lantern"), "Faith mode presents authored faith dialogue.")
	journal.configure(catalog, tracker, state, FakeCampaign.new(), "universal")
	await process_frame
	assert(journal.guardian_text("mind").contains("Wisdom is a lantern"), "Universal mode presents its authored counterpart.")
	assert(not journal.guardian_text("mind").contains("God"), "Universal text does not leak faith-only wording.")
	assert(journal.visible_text().contains("[CURRENT]"), "Task status has a readable non-colour label.")
	journal.queue_free()
	await process_frame


func _test_source_has_no_persistence() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/crown_quest_journal.gd")
	for forbidden in ["save_journey", "record_thought", "record_emotion", "record_creation", "FileAccess.open("]:
		assert(not source.contains(forbidden), "Journal must not persist or collect child data: %s" % forbidden)
	assert(source.contains("focus_mode = Control.FOCUS_ALL"), "Back control supports keyboard/controller focus.")
	assert(not source.contains("Tween") and not source.contains("AnimationPlayer"), "Design remains static and reduced-motion-safe.")


func _test_castle_entry_wiring() -> void:
	var gallery_source := FileAccess.get_file_as_string("res://scripts/art_gallery.gd")
	var campaign_source := FileAccess.get_file_as_string("res://scripts/journey_campaign.gd")
	assert(gallery_source.contains("CrownJourneyJournalButton"),
		"Art Castle exposes a visible journal button.")
	assert(gallery_source.contains("event.keycode == KEY_J"),
		"Art Castle exposes the documented keyboard shortcut.")
	assert(campaign_source.contains("func open_quest_journal"),
		"Canonical campaign router owns journal navigation.")
