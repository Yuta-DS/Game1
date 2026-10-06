extends SceneTree

const Catalog := preload("res://scripts/heart_melody/heart_melody_chapter_catalog.gd")


func _init() -> void:
	var catalog := Catalog.read()
	assert(not catalog.is_empty(), "the Heart Melody chapter catalog loads")
	assert(Catalog.validate(catalog).is_empty(),
		"the production Heart Melody chapter catalog validates")
	assert(catalog.quest_order.size() == 4)
	assert(Catalog.all_task_ids(catalog).size() == 10)
	assert(catalog.fruits.size() == 6 and catalog.recipes.size() == 6)
	assert(Catalog.quest(catalog, Catalog.LEGACY_QUEST_ID).xp == 80,
		"the existing Feeling Garden reward remains stable")
	for legacy_id in Catalog.LEGACY_TASK_IDS:
		assert(not Catalog.task(catalog, legacy_id).is_empty(),
			"legacy task remains addressable: %s" % legacy_id)
	for fruit_id in Catalog.EXPECTED_FRUIT_IDS:
		var fruit := Catalog.fruit(catalog, fruit_id)
		assert(fruit.stack_limit == 99 and fruit.story_protected,
			"fruit is stackable and story-protected: %s" % fruit_id)
	var broken := catalog.duplicate(true)
	broken.fruits.pop_back()
	assert(not Catalog.validate(broken).is_empty(),
		"a missing fruit family is rejected")
	broken = catalog.duplicate(true)
	broken.quests[1].tasks[0].instrument = "echo_drum_garden"
	assert(not Catalog.validate(broken).is_empty(),
		"duplicate instrument challenges are rejected")
	broken = catalog.duplicate(true)
	broken.accessibility.identity_affects_rewards = true
	assert(not Catalog.validate(broken).is_empty(),
		"identity-linked rewards are rejected")
	print("HEART_MELODY_CHAPTER_CATALOG: PASS — 4 quests, 10 instrument games, 6 protected fruit families and stable legacy IDs")
	quit()
