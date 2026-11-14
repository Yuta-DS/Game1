# Self-check for the Lens of Seeing's story layer.
#   godot --headless --path artea --script res://scripts/test_lens_journey.gd
#
# Two properties matter more than the rest:
#   1. The Crown of Life is NOT gated on the lens. A player who never finds it
#      must still be crowned.
#   2. "Perception" is only claimed when the player actually did the act, the
#      same evidentiary rule the rest of the ceremony follows.
extends SceneTree

const JourneyStateScript := preload("res://scripts/JourneyState.gd")
const LensJourneyScript := preload("res://scripts/viewfinder/lens_journey.gd")

# Never the real journey.json. record_bridging() and save() write to disk, so a
# suite pointed at the default path would overwrite — and clear_journey() would
# erase — a real child's record just by being run.
const TEST_SAVE := "res://.godot/test_lens_journey.json"


# Every JourneyState in this file comes from here, so no test can forget.
func _fresh() -> Node:
	var js = JourneyStateScript.new()
	js.save_path = TEST_SAVE
	return js


func _init() -> void:
	_test_bridging_records_evidence()
	_test_crown_is_not_gated_on_the_lens()
	_test_clear_wipes_bridgings()
	_test_audience_mode_changes_only_the_naming()
	_test_ceremony_speaks_perception()
	_cleanup()
	print("lens journey: all checks passed")
	quit()


func _test_bridging_records_evidence() -> void:
	var js = _fresh()
	assert(js.bridgings_count() == 0, "no bridgings before any are made")
	assert(not js.strengths.has("perception"), "perception is not granted upfront")

	js.record_bridging("mind_spark", "heart_melody")
	assert(js.bridgings_count() == 1, "a bridging is counted")
	assert(js.strengths.has("perception"),
		"carrying a seeing across a gap grants perception")

	# Counted, not flagged: the ceremony cites how many times it happened.
	js.record_bridging("heart_melody", "creators_light")
	assert(js.bridgings_count() == 2, "each bridging is counted separately")
	assert(js.strengths.count("perception") == 1, "the strength is not duplicated")

	# Survives a save/load round trip like every other part of the journey.
	js.save()
	var loaded = _fresh()
	loaded.load_journey()
	assert(loaded.bridgings_count() == 2, "bridgings survive save/load")
	assert(loaded.strengths.has("perception"), "perception survives save/load")
	loaded.clear_journey()


func _test_crown_is_not_gated_on_the_lens() -> void:
	var js = _fresh()

	# The three kingdoms, and nothing else.
	js.record_thought_echo("I am learning and growing", "learning")
	js.record_thought_echo("I can take one brave step", "brave_step")
	js.mark_popped("I am learning and growing")
	js.mark_popped("I can take one brave step")
	js.complete_mind_spark(2)
	js.record_emotion("hope", Color(0.4, 0.8, 0.6))
	var creation_id: String = str(js.record_creation("user://art/a.png", "my world"))
	js.complete_creator_frame_ritual(creation_id, "dream_door")

	assert(js.has_all_treasures(), "the three kingdoms complete the treasure set")
	js.advance_to(4)
	assert(js.stage == 4,
		"a player who never found the Lens is still crowned — perception is "
		+ "offered, never a toll on the finale")
	assert(js.bridgings_count() == 0, "and they made no bridgings")
	js.clear_journey()


func _test_clear_wipes_bridgings() -> void:
	var js = _fresh()
	js.record_bridging("a", "b")
	assert(js.bridgings_count() == 1, "recorded before the wipe")

	js.clear_journey()
	assert(js.bridgings_count() == 0,
		"erasing the journey erases bridgings too — no part of the record "
		+ "survives a wipe the player asked for")
	assert(not js.strengths.has("perception"), "the strength goes with it")


func _test_audience_mode_changes_only_the_naming() -> void:
	var lens = LensJourneyScript.new()

	# Outside the tree there is no JourneyState, so it falls back to faith —
	# Artéa's default voice, never a blank line.
	var default_line: String = lens.first_look_line()
	assert(default_line.contains("Uriel"),
		"faith naming is the fallback when no journey state is reachable")

	# Both registers say the same thing about what the player is doing.
	var faith: String = LensJourneyScript.FIRST_LOOK["faith"]
	var universal: String = LensJourneyScript.FIRST_LOOK["universal"]
	assert(faith != universal, "the two registers differ")
	for line in [faith, universal]:
		assert(line.contains("What you notice"),
			"both registers carry the same lesson, only the name changes")
	assert(not universal.to_lower().contains("uriel"),
		"the universal register drops the angel name")

	for key in ["faith", "universal"]:
		assert(LensJourneyScript.ON_BRIDGE.has(key),
			"the bridging line exists in the %s register" % key)
		assert(LensJourneyScript.ON_BRIDGE[key].contains("carried it here yourself"),
			"the bridging line cites the act in the %s register" % key)

	lens.free()


func _test_ceremony_speaks_perception() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/gallery_ceremony.gd")
	assert(source.contains("\"perception\""),
		"the ceremony knows the perception strength")
	assert(source.contains("bridgings_count()"),
		"the ceremony counts real bridgings rather than assuming one")
	# The claim must cite the act, matching every other line in EVIDENCE.
	assert(source.contains("saw what was missing"),
		"the perception line names what the player actually did")


# Leave no scratch file behind in the user data directory.
func _cleanup() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
