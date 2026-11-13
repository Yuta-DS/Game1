# Focused, read-only narrative catalog test.
#   godot --headless --path artea --script res://scripts/test_crown_story_catalog.gd
#
# This test never loads JourneyState and never touches a player save.
extends SceneTree


func _init() -> void:
	var Catalog = load("res://scripts/crown_story_catalog.gd")
	var story: Dictionary = Catalog.load_catalog()
	var errors: PackedStringArray = Catalog.validate(story)
	assert(errors.is_empty(), "catalog validation failed: %s" % "; ".join(errors))
	_test_complete_connected_structure(Catalog, story)
	_test_child_safe_contract(story)
	_test_validator_rejects_regressions(Catalog, story)
	print("CrownStoryCatalog: all checks passed")
	quit()


func _test_complete_connected_structure(Catalog: Script, story: Dictionary) -> void:
	assert(story["kingdom_arcs"].size() == 3, "exactly three kingdom arcs")
	assert(story["kingdom_arcs"].map(func(arc): return arc["id"]) == ["mind", "heart", "creator"],
		"kingdoms preserve the connected journey order")
	assert(story["castle_interludes"].size() == 3, "every treasure returns through the Castle")
	assert(story["finale"]["requirements"].has("treasure.star_of_wisdom"), "finale requires Wisdom")
	assert(story["finale"]["requirements"].has("treasure.harmony_jewel"), "finale requires Harmony")
	assert(story["finale"]["requirements"].has("treasure.creators_light"), "finale requires Creativity")
	var task_count := 0
	for arc in story["kingdom_arcs"]:
		assert(arc["quests"].size() == 3, "%s has a three-act substory" % arc["id"])
		for quest in arc["quests"]:
			assert(not quest["purpose"].is_empty() and not quest["story_reason"].is_empty(),
				"every quest explains learning purpose and narrative causality")
			for task in quest["tasks"]:
				task_count += 1
				assert(not task["purpose"].is_empty() and not task["story_reason"].is_empty(),
					"every task explains purpose and story reason")
	assert(task_count == 25, "catalog has 25 purposeful tasks across three substories")
	assert(Catalog.task_by_id(story, "creator.reflect.receive")["completion_evidence"]["value"] == "creators_light",
		"Creator ritual is the real final treasure evidence")
	assert(Catalog.localized_text(story["finale"]["dialogue"], "faith").contains("God"),
		"faith profile is explicitly authored")
	assert(not Catalog.localized_text(story["finale"]["dialogue"], "universal").contains("God"),
		"universal profile is explicitly authored, not token substitution")


func _test_child_safe_contract(story: Dictionary) -> void:
	assert(story["safety"]["mode"] == "curated_offline", "canonical story remains curated and offline")
	assert(story["finale"]["name_star"]["optional"], "the name star never forces disclosure")
	assert(story["finale"]["name_star"]["privacy"].contains("Local display only"),
		"child name defaults to local-only")
	var serialized := JSON.stringify(story).to_lower()
	assert(serialized.contains("diagnostic inference") and serialized.contains("never diagnose"),
		"Heart mechanics and the safety contract explicitly reject inference")
	assert(serialized.contains("not judge"), "Creator reflection explicitly rejects judgement")
	assert(serialized.contains("skip"), "skip paths are authored")


func _test_validator_rejects_regressions(Catalog: Script, story: Dictionary) -> void:
	var wrong_order: Dictionary = story.duplicate(true)
	wrong_order["kingdom_arcs"][0]["id"] = "heart"
	assert(not Catalog.validate(wrong_order).is_empty(), "wrong arc order is rejected")

	var missing_dependency: Dictionary = story.duplicate(true)
	missing_dependency["kingdom_arcs"][0]["quests"][0]["tasks"][0]["prerequisites"] = ["unknown.event"]
	assert(not Catalog.validate(missing_dependency).is_empty(), "unknown dependencies are rejected")

	var missing_audience: Dictionary = story.duplicate(true)
	missing_audience["finale"]["dialogue"].erase("universal")
	assert(not Catalog.validate(missing_audience).is_empty(), "audience text parity is required")

	var duplicate_id: Dictionary = story.duplicate(true)
	duplicate_id["kingdom_arcs"][0]["quests"][0]["tasks"][1]["id"] = "mind.listen.notice"
	assert(not Catalog.validate(duplicate_id).is_empty(), "duplicate task IDs are rejected")
