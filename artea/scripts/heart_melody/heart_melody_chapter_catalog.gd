class_name HeartMelodyChapterCatalog
extends RefCounted

const PATH := "res://data/heart_melody_chapter.json"
const LEGACY_QUEST_ID := "heart_melody.quest.wake_feeling_garden"
const LEGACY_TASK_IDS := [
	"heart_melody.task.plant_feeling_seeds",
	"heart_melody.task.restore_garden_rhythm",
]
const EXPECTED_QUEST_IDS := [
	LEGACY_QUEST_ID,
	"heart_melody.quest.restore_river_song",
	"heart_melody.quest.build_heart_song",
	"heart_melody.quest.free_silent_conductor",
]
const EXPECTED_FRUIT_IDS := [
	"echo_berry", "sun_plum", "dew_pear", "bell_apple", "moon_melon", "harmony_fig",
]


static func read(path := PATH) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return parser.data if parser.data is Dictionary else {}


static func validate(catalog: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if int(catalog.get("schema_version", 0)) != 2:
		errors.append("Heart Melody chapter catalog must use schema version 2.")
	if str(catalog.get("world_id", "")) != "heart_melody":
		errors.append("Heart Melody chapter catalog has the wrong world ID.")
	_validate_regions(catalog, errors)
	_validate_quests(catalog, errors)
	_validate_fruits_and_recipes(catalog, errors)
	_validate_safety(catalog, errors)
	return errors


static func quest(catalog: Dictionary, quest_id: String) -> Dictionary:
	for value in catalog.get("quests", []):
		if value is Dictionary and str(value.get("id", "")) == quest_id:
			return value
	return {}


static func task(catalog: Dictionary, task_id: String) -> Dictionary:
	for quest_value in catalog.get("quests", []):
		if not quest_value is Dictionary:
			continue
		for task_value in quest_value.get("tasks", []):
			if task_value is Dictionary and str(task_value.get("id", "")) == task_id:
				return task_value
	return {}


static func fruit(catalog: Dictionary, fruit_id: String) -> Dictionary:
	for value in catalog.get("fruits", []):
		if value is Dictionary and str(value.get("id", "")) == fruit_id:
			return value
	return {}


static func all_task_ids(catalog: Dictionary) -> PackedStringArray:
	var ids := PackedStringArray()
	for quest_value in catalog.get("quests", []):
		if not quest_value is Dictionary:
			continue
		for task_value in quest_value.get("tasks", []):
			if task_value is Dictionary:
				ids.append(str(task_value.get("id", "")))
	return ids


static func _validate_regions(catalog: Dictionary, errors: PackedStringArray) -> void:
	var regions: Array = catalog.get("regions", [])
	var zones := PackedStringArray()
	if regions.size() != 3:
		errors.append("Heart Melody needs exactly three production regions.")
	for region_value in regions:
		if not region_value is Dictionary:
			errors.append("Every Heart Melody region must be an object.")
			continue
		for zone in region_value.get("zones", []):
			zones.append(str(zone))
	if zones.size() != 6:
		errors.append("Heart Melody needs exactly six gameplay zones.")
	var unique_zones := {}
	for zone in zones:
		unique_zones[zone] = true
	if unique_zones.size() != zones.size():
		errors.append("Heart Melody zone IDs must be unique.")


static func _validate_quests(catalog: Dictionary, errors: PackedStringArray) -> void:
	var quest_order: Array = catalog.get("quest_order", [])
	var quests: Array = catalog.get("quests", [])
	if quest_order != EXPECTED_QUEST_IDS:
		errors.append("Heart Melody quest order or stable IDs changed.")
	if quests.size() != 4:
		errors.append("Heart Melody needs exactly four story quests.")
	var seen_quests := {}
	var seen_tasks := {}
	var instrument_ids := {}
	for quest_value in quests:
		if not quest_value is Dictionary:
			errors.append("Every Heart Melody quest must be an object.")
			continue
		var quest_id := str(quest_value.get("id", ""))
		if quest_id in seen_quests:
			errors.append("Duplicate Heart Melody quest ID: %s" % quest_id)
		seen_quests[quest_id] = true
		for prerequisite in quest_value.get("prerequisites", []):
			if str(prerequisite) not in EXPECTED_QUEST_IDS:
				errors.append("Quest %s has an unknown prerequisite." % quest_id)
		for task_value in quest_value.get("tasks", []):
			if not task_value is Dictionary:
				errors.append("Every Heart Melody task must be an object.")
				continue
			var task_id := str(task_value.get("id", ""))
			var instrument_id := str(task_value.get("instrument", ""))
			if task_id.is_empty() or task_id in seen_tasks:
				errors.append("Heart Melody task IDs must be present and unique.")
			seen_tasks[task_id] = true
			if instrument_id.is_empty() or instrument_id in instrument_ids:
				errors.append("Every story task needs one unique instrument challenge.")
			instrument_ids[instrument_id] = true
			if str(task_value.get("mode", "")).is_empty():
				errors.append("Task %s needs an instrument mode." % task_id)
			for prerequisite in task_value.get("prerequisites", []):
				if str(prerequisite) not in seen_tasks:
					errors.append("Task %s depends on an unavailable earlier task." % task_id)
	if seen_tasks.size() != 10:
		errors.append("Heart Melody needs exactly ten story instrument tasks.")
	for legacy_id in LEGACY_TASK_IDS:
		if legacy_id not in seen_tasks:
			errors.append("Legacy Heart Garden task ID is missing: %s" % legacy_id)


static func _validate_fruits_and_recipes(catalog: Dictionary,
		errors: PackedStringArray) -> void:
	var fruits: Array = catalog.get("fruits", [])
	var fruit_ids := {}
	if fruits.size() != 6:
		errors.append("Heart Melody needs exactly six musical fruit families.")
	for fruit_value in fruits:
		if not fruit_value is Dictionary:
			errors.append("Every musical fruit must be an object.")
			continue
		var fruit_id := str(fruit_value.get("id", ""))
		if fruit_id not in EXPECTED_FRUIT_IDS or fruit_id in fruit_ids:
			errors.append("Musical fruit IDs must match the authored set and be unique.")
		fruit_ids[fruit_id] = true
		if int(fruit_value.get("stack_limit", 0)) != 99:
			errors.append("Musical fruit must stack to 99.")
		if not bool(fruit_value.get("story_protected", false)):
			errors.append("Story fruit must remain protected from crafting consumption.")
	for expected_id in EXPECTED_FRUIT_IDS:
		if expected_id not in fruit_ids:
			errors.append("Missing musical fruit: %s" % expected_id)
	var recipes: Array = catalog.get("recipes", [])
	var recipe_ids := {}
	if recipes.size() != 6:
		errors.append("Heart Melody needs exactly six initial fruit recipes.")
	for recipe_value in recipes:
		if not recipe_value is Dictionary:
			errors.append("Every fruit recipe must be an object.")
			continue
		var recipe_id := str(recipe_value.get("id", ""))
		if recipe_id.is_empty() or recipe_id in recipe_ids:
			errors.append("Fruit recipe IDs must be present and unique.")
		recipe_ids[recipe_id] = true
		if str(recipe_value.get("fruit", "")) not in fruit_ids:
			errors.append("Recipe %s uses an unknown fruit." % recipe_id)
		if int(recipe_value.get("cost", 0)) <= 0:
			errors.append("Recipe %s needs a positive fruit cost." % recipe_id)
	for task_id in all_task_ids(catalog):
		var task_value := task(catalog, task_id)
		var required_fruit := str(task_value.get("required_fruit", ""))
		if not required_fruit.is_empty() and required_fruit not in fruit_ids:
			errors.append("Task %s requires an unknown fruit." % task_id)


static func _validate_safety(catalog: Dictionary, errors: PackedStringArray) -> void:
	var evidence: Array = catalog.get("identity_evidence_ids", [])
	if evidence.size() != 8:
		errors.append("Heart Melody needs eight optional identity evidence moments.")
	for index in 8:
		if evidence.size() <= index or str(evidence[index]) != "HM_ID_%02d" % (index + 1):
			errors.append("Heart Melody identity evidence IDs changed.")
			break
	var accessibility: Dictionary = catalog.get("accessibility", {})
	if not bool(accessibility.get("audio_has_visual_equivalent", false)):
		errors.append("Every musical cue needs a visual equivalent.")
	if bool(accessibility.get("identity_affects_rewards", true)):
		errors.append("Identity evidence cannot alter Heart Melody rewards.")
	if bool(accessibility.get("assistance_affects_rewards", true)):
		errors.append("Assistance cannot alter Heart Melody rewards.")
