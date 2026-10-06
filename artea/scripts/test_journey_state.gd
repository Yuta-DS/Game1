# Self-check for JourneyState. Run headless:
#   godot --headless --script res://scripts/test_journey_state.gd
#
# Uses a fresh JourneyState instance rather than the autoload, AND redirects
# save_path, so the player's real journey.json is never touched by the test.
#
# A fresh instance alone was not enough: save(), the record_* methods and
# clear_journey() all write to the default path regardless of who called them,
# so running this suite used to overwrite and then delete a real child's
# record.
extends SceneTree

const TEST_SAVE := "user://test_journey_state.json"


func _init() -> void:
	var JourneyStateScript = load("res://scripts/JourneyState.gd")
	var js = JourneyStateScript.new()
	js.save_path = TEST_SAVE

	# --- recording and counting ---
	js.record_thought_echo("I am learning and growing.", "learning")
	js.record_thought_echo("I can take one brave step.", "brave_step")
	assert(js.thoughts.size() == 2, "both thoughts recorded")
	assert(js.popped_count() == 0, "nothing popped yet")

	js.mark_popped("I can take one brave step.")
	assert(js.popped_count() == 1, "one popped")
	assert(not js.strengths.has("courage"), "one popped echo does not complete Mind Spark")
	assert(not js.has_treasure("star_of_wisdom"), "one popped echo cannot award Star of Wisdom")
	assert(not js.complete_mind_spark(2), "Mind Spark rejects an unresolved selected echo")
	js.mark_popped("I am learning and growing.")
	assert(js.complete_mind_spark(2), "two selected and resolved echoes complete Mind Spark")
	assert(js.strengths.has("courage"), "Mind completion grants courage")
	assert(js.has_treasure("star_of_wisdom"), "Mind completion awards Star of Wisdom")
	assert(not js.has_all_treasures(), "one world cannot unlock the finale")

	# An unfinished older encounter must not block a later bounded Two Lenses
	# completion whose two explicit round IDs have both been resolved.
	var bounded = JourneyStateScript.new()
	bounded.save_path = "user://test_journey_state_bounded.json"
	bounded.record_thought_echo("An older unfinished echo", "legacy_unfinished")
	bounded.record_thought_echo("Something might go wrong, and I can take one step.", "round.small_step")
	bounded.mark_popped("Something might go wrong, and I can take one step.")
	bounded.record_thought_echo("I might not be able to do this, and I can ask for help.", "round.safe_connection")
	bounded.mark_popped("I might not be able to do this, and I can ask for help.")
	assert(bounded.complete_mind_spark(2, ["round.small_step", "round.safe_connection"]),
		"explicit completed round IDs are sufficient despite unrelated unfinished history")
	bounded.clear_journey()
	js.advance_to(4)
	assert(js.stage == 0, "Crown stage is locked until all three treasures")

	# Popping the same thought twice must not double-count.
	js.mark_popped("I can take one brave step.")
	assert(js.popped_count() == 2, "no double count")

	# Heaviest = longest written thought.
	assert(js.heaviest_thought() == "I am learning and growing.", "heaviest is longest")

	# --- stage only moves forward ---
	js.advance_to(3)
	js.advance_to(1)
	assert(js.stage == 3, "stage never demotes")

	# --- round trip through disk ---
	js.record_emotion("sad", Color(0.2, 0.4, 0.9))
	var creation_id: String = str(js.record_creation("user://art/a.png", "storm"))
	assert(js.has_treasure("harmony_jewel"), "Heart Melody awards Harmony Jewel")
	assert(not js.has_treasure("creators_light"),
		"saving artwork alone does not skip the Gallery Frame Ritual")
	assert(js.complete_creator_frame_ritual(creation_id, "star_bridge"),
		"framing the artwork awards Creator's Light")
	assert(js.has_treasure("creators_light"), "Creator ritual awards Creator's Light")
	assert(js.has_all_treasures(), "three worlds complete the treasure set")
	assert(js.treasure_count() == 3, "treasure count is exact")
	js.advance_to(4)
	assert(js.stage == 4, "Crown stage unlocks after all three treasures")
	js.set_audience_mode("universal")
	js.save()

	var loaded = JourneyStateScript.new()
	loaded.save_path = TEST_SAVE
	loaded.load_journey()
	assert(loaded.stage == 4, "final stage survives save/load")
	assert(loaded.thoughts.size() == 2, "thoughts survive save/load")
	assert(loaded.popped_count() == 2, "popped flags survive save/load")
	assert(loaded.emotions.size() == 1, "emotions survive save/load")
	assert(loaded.creations.size() == 1, "creations survive save/load")
	assert(loaded.creation_rituals.size() == 1, "ritual completion survives save/load")
	assert(loaded.strengths.has("creativity"), "strengths survive save/load")
	assert(loaded.has_all_treasures(), "treasures survive save/load")
	assert(loaded.audience_mode == "universal", "audience mode survives save/load")

	# --- the player can erase everything ---
	loaded.clear_journey()
	assert(loaded.stage == 0, "clear resets stage")
	assert(loaded.thoughts.is_empty(), "clear wipes thoughts")
	assert(loaded.treasure_count() == 0, "clear removes all treasures")
	assert(not FileAccess.file_exists(TEST_SAVE), "save file removed")

	print("JourneyState: all checks passed")
	quit()
