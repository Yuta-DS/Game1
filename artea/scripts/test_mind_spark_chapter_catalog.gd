# Focused story-catalog contract test.
# godot --headless --rendering-driver opengl3 --path artea --script res://scripts/test_mind_spark_chapter_catalog.gd
extends SceneTree

const CatalogScript = preload("res://scripts/mind_spark/mind_spark_chapter_catalog.gd")


func _init() -> void:
	_test_complete_authored_chapter()
	_test_schema_rejects_unsafe_or_incomplete_content()
	print("MindSparkChapterCatalog: all checks passed")
	quit()


func _test_complete_authored_chapter() -> void:
	var catalog = CatalogScript.new()
	assert(catalog.is_valid(), "authored chapter must satisfy schema: %s" % catalog.errors)
	assert(catalog.guardian_name(CatalogScript.PROFILE_FAITH) == "Everlasting Father")
	assert(catalog.guardian_name(CatalogScript.PROFILE_UNIVERSAL) == "Guardian of Wisdom")
	assert(catalog.guardian_name("unknown").is_empty(), "unknown profiles do not leak a default spiritual framing")
	var quests: Array = catalog.quests()
	assert(quests.size() == 5, "Mind Spark must have exactly five ordered quests")
	var expected_islands := ["island_one", "island_one", "island_two", "island_two", "island_three"]
	var task_count := 0
	for quest_index in quests.size():
		var quest: Dictionary = quests[quest_index]
		assert(quest["order"] == quest_index + 1)
		assert(quest["island_id"] == expected_islands[quest_index])
		assert(quest["district_ids"].size() >= 1)
		assert(quest["object_bindings"].size() >= 1)
		assert(quest["hint_ladder"].size() >= 2)
		assert(quest["success_effects"].size() >= 1)
		var contract: Dictionary = catalog.runtime_contract(quest["save_aliases"][0])
		assert(contract["canonical_id"] == quest["id"], "legacy save aliases resolve to canonical quests")
		assert(contract["environment_state"] == quest["environment_state"])
		assert(quest["tasks"].size() >= 3 and quest["tasks"].size() <= 5)
		assert(not catalog.localized_dialogue(quest, CatalogScript.PROFILE_FAITH).is_empty())
		assert(not catalog.localized_dialogue(quest, CatalogScript.PROFILE_UNIVERSAL).is_empty())
		for task_index in quest["tasks"].size():
			var task: Dictionary = quest["tasks"][task_index]
			task_count += 1
			assert(task["order"] == task_index + 1)
			assert(not task["science_consequence"].is_empty())
			assert(not task["magic_consequence"].is_empty())
			assert(task["reflection"]["choices"].size() >= 2, "reflections are curated choices")
			assert(task["failure_free_encouragement"].has("faith"))
			assert(task["failure_free_encouragement"].has("universal"))
	assert(task_count == 20, "five quests provide a detailed twenty-task chapter")
	assert(catalog.quest("quest.constellation_synthesis")["tasks"][-1]["id"] == "constellation.return_castle")
	assert(catalog.data["castle_return"]["completion_event"] == "star_of_wisdom_awarded")
	assert(catalog.data["castle_return"]["next_locked_treasure"] == "harmony_jewel")
	var policy: Dictionary = catalog.data["content_policy"]
	for forbidden_capability in ["free_text", "diagnosis", "network", "generative_ai", "scoring_inner_state"]:
		assert(policy[forbidden_capability] == false, "%s must remain disabled" % forbidden_capability)


func _test_schema_rejects_unsafe_or_incomplete_content() -> void:
	var invalid: Dictionary = CatalogScript.load_catalog().duplicate(true)
	invalid["content_policy"]["network"] = true
	invalid["profiles"]["universal"]["guardian_name"] = "Everlasting Father"
	invalid["quests"][0]["tasks"][0].erase("reflection")
	invalid["quests"].pop_back()
	var errors: PackedStringArray = CatalogScript.validate(invalid)
	assert(_contains_error(errors, "network"))
	assert(_contains_error(errors, "Guardian of Wisdom"))
	assert(_contains_error(errors, "exactly five"))


func _contains_error(errors: PackedStringArray, fragment: String) -> bool:
	for message in errors:
		if message.contains(fragment):
			return true
	return false
