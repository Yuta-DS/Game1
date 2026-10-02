class_name HeartGardenState
extends RefCounted

## Sole owner of Island One progress. Presentation never grants rewards.
signal changed
signal feedback(accepted: bool, message: String)

const SAVE_PATH := "user://heart_melody_island_one.json"
const ChapterCatalog := preload("res://scripts/heart_melody/heart_melody_chapter_catalog.gd")
const SCHEMA_VERSION := 3
const PLANT_TASK := "heart_melody.task.plant_feeling_seeds"
const RHYTHM_TASK := "heart_melody.task.restore_garden_rhythm"
const QUEST_ID := "heart_melody.quest.wake_feeling_garden"
const RIVER_QUEST_ID := "heart_melody.quest.restore_river_song"
const ORGAN_TASK := "heart_melody.task.tune_waterfall_organ"
const VINE_TASK := "heart_melody.task.release_hush_vines"
const BOAT_TASK := "heart_melody.task.call_rain_boat"
const SYMBOLS := ["leaf", "droplet", "sun"]
const PHRASE := ["leaf", "sun", "droplet"]
const ORGAN_TARGET := [1, 2, 0]
const VINE_TARGET := [0, 1, 2, 3, 4]
const BELL_TARGET := ["north", "east", "south", "west"]
const CHOICES := ["joy", "sadness", "frustration", "fear", "peace", "hope", "sound"]
const ENEMY_XP := {"garden.moth.1": 12, "garden.moth.2": 12, "garden.slime.1": 15}
const WAVES := [["garden.moth.1"], ["garden.moth.2", "garden.slime.1"]]

var save_path := SAVE_PATH
var persistent := true
var last_error := ""
var data: Dictionary = fresh()


static func fresh() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "world_id": "heart_melody", "planters": {},
		"phrase": [], "rhythm_solved": false, "mistake_count": 0, "hint_level": 0,
		"cleared_waves": [],
		"xp_receipts": {}, "completed_task_ids": [], "completed_quest_ids": [],
		"checkpoint": "arrival", "identity_dismissed": [],
		"quest_fruit_pouch": {}, "fruit_inventory": {}, "checkpoint_storage": {},
		"fruit_receipt_ids": [], "crafted_recipe_ids": [],
		"river_organ": [0, 0, 0], "hush_vines": [0, 0, 0, 0, 0],
		"rain_bells": [], "river_attempts": {},
		"settings": {"puzzle_help": true, "combat_assist": false, "reduced_motion": false,
			"muted": false, "music_volume": 0.72, "effects_volume": 0.82}}


func _init(path := SAVE_PATH, write_enabled := true) -> void:
	save_path = path
	persistent = write_enabled


func planted_count() -> int:
	return data.planters.size()


func complete() -> bool:
	return QUEST_ID in data.completed_quest_ids


func river_complete() -> bool:
	return RIVER_QUEST_ID in data.completed_quest_ids


func task_complete(task_id: String) -> bool:
	return task_id in data.completed_task_ids


func xp() -> int:
	var total := 0
	for value in data.xp_receipts.values():
		total += int(value)
	return total


func current_wave() -> int:
	return data.cleared_waves.size()


func objective() -> String:
	if river_complete():
		return "River Song restored. The Bell Grove is ready for the Heart Song."
	if complete():
		if not task_complete(ORGAN_TASK):
			return "Harvest three Dew Pears and tune the Waterfall Organ."
		if not task_complete(VINE_TASK):
			return "Harvest five Sun Plums and tune the Hush Vine Harp."
		return "Harvest four Bell Apples and call the Rain Boat."
	if planted_count() < 3:
		return "Plant three Feeling Seeds — %d/3" % planted_count()
	if not data.rhythm_solved:
		return "Listen, then play Leaf → Sun → Droplet. There is no timer."
	return "Release the Blight in the clearing — wave %d/2. Step aside, then strike." % (current_wave() + 1)


func plant(index: int, choice: String) -> Dictionary:
	if index < 0 or index > 2 or choice not in CHOICES:
		return _reply(false, "Choose one of the garden's seed icons or a sound.")
	var next := data.duplicate(true)
	next.planters[str(index)] = choice
	if next.planters.size() == 3 and PLANT_TASK not in next.completed_task_ids:
		next.completed_task_ids.append(PLANT_TASK)
		next.checkpoint = "planter_court"
	return _commit(next, "The seed has bloomed. %d/3 planted." % next.planters.size())


func enter_note(symbol: String) -> Dictionary:
	if planted_count() < 3:
		return _reply(false, "Plant the three seeds to wake these flowers.")
	if symbol not in SYMBOLS:
		return _reply(false, "Choose Leaf, Droplet or Sun.")
	if data.rhythm_solved:
		return _reply(true, "Play freely — the garden remembers your song.")
	if data.phrase.size() >= 3:
		return _reply(false, "Your three notes are ready. Listen, undo or confirm.")
	var next := data.duplicate(true)
	next.phrase.append(symbol)
	return _commit(next, "%d/3 notes arranged." % next.phrase.size())


func revise(reset := false) -> Dictionary:
	if data.rhythm_solved:
		return _reply(true, "The restored song stays safe. You can replay it.")
	var next := data.duplicate(true)
	if reset:
		next.phrase.clear()
	elif not next.phrase.is_empty():
		next.phrase.pop_back()
	return _commit(next, "Try another arrangement whenever you are ready.")


func confirm_phrase() -> Dictionary:
	if data.rhythm_solved:
		return _reply(true, "The garden already remembers this phrase.")
	if planted_count() != 3 or data.phrase.size() != 3:
		return _reply(false, "Plant all three seeds and arrange three notes first.")
	for index in 3:
		if data.phrase[index] != PHRASE[index]:
			var next := data.duplicate(true)
			next.mistake_count = int(next.get("mistake_count", 0)) + 1
			var message := "Note %d should be the %s flower. Your arrangement is still here." % [index + 1, PHRASE[index].capitalize()]
			if next.mistake_count >= 2 and bool(next.settings.get("puzzle_help", true)):
				message += " The %s flower is glowing for the next step." % PHRASE[index].capitalize()
			return _commit(next, message, false)
	var next := data.duplicate(true)
	next.rhythm_solved = true
	next.checkpoint = "drum_garden"
	return _commit(next, "The flowers remember! Follow the path to the Blight clearing.")


func request_hint() -> Dictionary:
	if planted_count() < 3:
		return _reply(false, "Plant all three seeds before asking the flowers for their phrase.")
	if data.rhythm_solved:
		return _reply(true, "The restored phrase is Leaf, Sun, Droplet. You may replay it freely.")
	var next := data.duplicate(true)
	next.hint_level = mini(3, int(next.get("hint_level", 0)) + 1)
	var messages := [
		"The three drum flowers are waiting in the circular clearing.",
		"Watch and listen together: Leaf, then Sun, then Droplet.",
		"The next needed flower will pulse during a slow demonstration.",
	]
	return _commit(next, messages[next.hint_level - 1])


func record_defeat(enemy_id: String) -> Dictionary:
	if not data.rhythm_solved or current_wave() >= WAVES.size() or enemy_id not in WAVES[current_wave()]:
		return _reply(false, "That creature is not in the current encounter.")
	var next := data.duplicate(true)
	next.xp_receipts[enemy_id] = ENEMY_XP[enemy_id]
	return _commit(next, "The shell is released. The living creature is safe.")


func finish_wave(defeated_this_attempt: Array) -> Dictionary:
	if not data.rhythm_solved or current_wave() >= WAVES.size():
		return _reply(false, "No wave is waiting to be completed.")
	for enemy_id in WAVES[current_wave()]:
		if enemy_id not in defeated_this_attempt or not data.xp_receipts.has(enemy_id):
			return _reply(false, "Release every shell in this clearing first.")
	var next := data.duplicate(true)
	next.cleared_waves.append(current_wave())
	if next.cleared_waves.size() == WAVES.size():
		next.completed_task_ids.append(RHYTHM_TASK)
		next.completed_quest_ids.append(QUEST_ID)
		next.xp_receipts[QUEST_ID] = 80
		next.checkpoint = "restored_garden"
	return _commit(next, "Feeling Garden restored — 80 quest XP!" if next.cleared_waves.size() == 2 else "The first clearing is safe. Rest or continue when ready.")


func set_setting(key: String, value: bool) -> Dictionary:
	if key not in ["puzzle_help", "combat_assist", "reduced_motion", "muted"]:
		return _reply(false, "Unknown setting.")
	var next := data.duplicate(true)
	next.settings[key] = value
	return _commit(next, "Setting saved.")


func set_volume(key: String, value: float) -> Dictionary:
	if key not in ["music_volume", "effects_volume"]:
		return _reply(false, "Unknown volume setting.")
	var next := data.duplicate(true)
	next.settings[key] = clampf(value, 0.0, 1.0)
	return _commit(next, "Volume saved.")


func set_checkpoint(id: String) -> Dictionary:
	if id not in ["arrival", "planter_court", "drum_garden", "restored_garden",
			"river_organ", "river_harp", "bell_grove"]:
		return _reply(false, "Unknown checkpoint.")
	var next := data.duplicate(true)
	next.checkpoint = id
	return _commit(next, "Checkpoint saved.")


func dismiss_identity(id: String) -> Dictionary:
	if id not in ["HM_ID_01", "HM_ID_02", "HM_ID_03", "HM_ID_04"]:
		return _reply(false, "Unknown reflection.")
	var next := data.duplicate(true)
	if id not in next.identity_dismissed:
		next.identity_dismissed.append(id)
	return _commit(next, "Your journey continues.")


func grant_story_fruit(fruit_id: String, amount := 1, receipt_id := "") -> Dictionary:
	if not _valid_fruit_id(fruit_id) or amount <= 0:
		return _reply(false, "That musical fruit cannot be stored.")
	var next := data.duplicate(true)
	var receipt := receipt_id if not receipt_id.is_empty() else "story.%s" % fruit_id
	if receipt in next.fruit_receipt_ids:
		return _reply(true, "This story fruit is already safe in the quest pouch.")
	next.quest_fruit_pouch[fruit_id] = int(next.quest_fruit_pouch.get(fruit_id, 0)) + amount
	next.fruit_receipt_ids.append(receipt)
	return _commit(next, "%s added to the protected quest pouch." % _fruit_label(fruit_id))


func grant_crafting_fruit(fruit_id: String, amount := 1, receipt_id := "") -> Dictionary:
	if not _valid_fruit_id(fruit_id) or amount <= 0:
		return _reply(false, "That musical fruit cannot be stored.")
	var next := data.duplicate(true)
	if not receipt_id.is_empty() and receipt_id in next.fruit_receipt_ids:
		return _reply(true, "This harvest has already been collected.")
	var current := int(next.fruit_inventory.get(fruit_id, 0))
	var stored := mini(99, current + amount)
	var overflow := current + amount - stored
	next.fruit_inventory[fruit_id] = stored
	if overflow > 0:
		next.checkpoint_storage[fruit_id] = int(next.checkpoint_storage.get(fruit_id, 0)) + overflow
	if not receipt_id.is_empty():
		next.fruit_receipt_ids.append(receipt_id)
	var message := "%s stored for crafting." % _fruit_label(fruit_id)
	if overflow > 0:
		message += " %d moved to checkpoint storage." % overflow
	return _commit(next, message)


func craft_recipe(recipe_id: String) -> Dictionary:
	var chapter := ChapterCatalog.read()
	var recipe := _recipe(chapter, recipe_id)
	if recipe.is_empty():
		return _reply(false, "That Heart Melody recipe is unknown.")
	if recipe_id in data.crafted_recipe_ids:
		return _reply(true, "This recipe has already been crafted.")
	var fruit_id := str(recipe.get("fruit", ""))
	var cost := int(recipe.get("cost", 0))
	if int(data.fruit_inventory.get(fruit_id, 0)) < cost:
		return _reply(false, "Collect %d %s for this recipe." % [cost, _fruit_label(fruit_id)])
	var next := data.duplicate(true)
	next.fruit_inventory[fruit_id] = int(next.fruit_inventory.get(fruit_id, 0)) - cost
	next.crafted_recipe_ids.append(recipe_id)
	return _commit(next, "Crafted %s." % recipe_id.replace("_", " ").capitalize())


func story_fruit_count(fruit_id: String) -> int:
	return int(data.quest_fruit_pouch.get(fruit_id, 0))


func crafting_fruit_count(fruit_id: String) -> int:
	return int(data.fruit_inventory.get(fruit_id, 0))


func checkpoint_fruit_count(fruit_id: String) -> int:
	return int(data.checkpoint_storage.get(fruit_id, 0))


func set_organ_valve(index: int, value: int) -> Dictionary:
	if not complete() or story_fruit_count("dew_pear") < 3:
		return _reply(false, "Restore the garden and harvest three Dew Pears first.")
	if index < 0 or index >= 3 or value < 0 or value > 2:
		return _reply(false, "Choose one of the three visible water levels.")
	if task_complete(ORGAN_TASK):
		return _reply(true, "The Waterfall Organ chord is already restored.")
	var next := data.duplicate(true)
	next.river_organ[index] = value
	return _commit(next, "Organ channel %d set to level %d." % [index + 1, value + 1])


func confirm_organ() -> Dictionary:
	if task_complete(ORGAN_TASK):
		return _reply(true, "The Waterfall Organ chord is already restored.")
	if not complete() or story_fruit_count("dew_pear") < 3:
		return _reply(false, "Three Dew Pear resonators are needed first.")
	if data.river_organ != ORGAN_TARGET:
		return _record_river_attempt("organ", "The water heights do not yet form low, high, calm: 2 • 3 • 1.")
	var next := data.duplicate(true)
	next.completed_task_ids.append(ORGAN_TASK)
	next.checkpoint = "river_organ"
	return _commit(next, "The Waterfall Organ is in tune. The Hush Vines are listening.")


func set_vine_tension(index: int, value: int) -> Dictionary:
	if not task_complete(ORGAN_TASK) or story_fruit_count("sun_plum") < 5:
		return _reply(false, "Tune the organ and harvest five Sun Plums first.")
	if index < 0 or index >= 5 or value < 0 or value > 4:
		return _reply(false, "Choose one of the five visible vine tensions.")
	if task_complete(VINE_TASK):
		return _reply(true, "The healthy harp vines are already released.")
	var next := data.duplicate(true)
	next.hush_vines[index] = value
	return _commit(next, "Harp string %d set to tension %d." % [index + 1, value + 1])


func confirm_vines() -> Dictionary:
	if task_complete(VINE_TASK):
		return _reply(true, "The healthy harp vines are already released.")
	if not task_complete(ORGAN_TASK) or story_fruit_count("sun_plum") < 5:
		return _reply(false, "The organ and five Sun Plums must reveal the safe tensions first.")
	if data.hush_vines != VINE_TARGET:
		return _record_river_attempt("vines", "The harp needs a gentle five-step rise: 1 • 2 • 3 • 4 • 5.")
	var next := data.duplicate(true)
	next.completed_task_ids.append(VINE_TASK)
	next.checkpoint = "river_harp"
	return _commit(next, "The Hush Vines are free and the Rain Boat dock is open.")


func enter_rain_bell(direction: String) -> Dictionary:
	if not task_complete(VINE_TASK) or story_fruit_count("bell_apple") < 4:
		return _reply(false, "Release the harp and harvest four Bell Apples first.")
	if direction not in ["north", "east", "south", "west"]:
		return _reply(false, "Ring one of the four directional bell flowers.")
	if task_complete(BOAT_TASK):
		return _reply(true, "The Rain Boat already knows this call.")
	if data.rain_bells.size() >= 4:
		return _reply(false, "Four calls are ready. Confirm, undo, or reset them.")
	var next := data.duplicate(true)
	next.rain_bells.append(direction)
	return _commit(next, "%d/4 directional calls arranged." % next.rain_bells.size())


func revise_rain_bells(reset := false) -> Dictionary:
	if task_complete(BOAT_TASK):
		return _reply(true, "The Rain Boat call remains restored.")
	var next := data.duplicate(true)
	if reset:
		next.rain_bells.clear()
	elif not next.rain_bells.is_empty():
		next.rain_bells.pop_back()
	return _commit(next, "Adjust the directional call when you are ready.")


func confirm_rain_bells() -> Dictionary:
	if task_complete(BOAT_TASK):
		return _reply(true, "The Rain Boat call remains restored.")
	if not task_complete(VINE_TASK) or story_fruit_count("bell_apple") < 4:
		return _reply(false, "The released harp and four Bell Apples are needed first.")
	if data.rain_bells != BELL_TARGET:
		return _record_river_attempt("bells", "Read the ripples clockwise: North • East • South • West.")
	var next := data.duplicate(true)
	next.completed_task_ids.append(BOAT_TASK)
	next.completed_quest_ids.append(RIVER_QUEST_ID)
	next.xp_receipts[RIVER_QUEST_ID] = 105
	next.checkpoint = "bell_grove"
	return _commit(next, "River Song restored — 105 quest XP! The Rain Boat is waiting.")


func _record_river_attempt(challenge_id: String, message: String) -> Dictionary:
	var next := data.duplicate(true)
	next.river_attempts[challenge_id] = int(next.river_attempts.get(challenge_id, 0)) + 1
	return _commit(next, message, false)


func _commit(next: Dictionary, message: String, accepted := true) -> Dictionary:
	if persistent and not _write_atomic(next):
		return _reply(false, "Progress could not be saved. Your previous checkpoint is safe; try again.")
	data = next
	changed.emit()
	return _reply(accepted, message)


func _reply(accepted: bool, message: String) -> Dictionary:
	feedback.emit(accepted, message)
	return {"accepted": accepted, "message": message}


func save() -> bool:
	return not persistent or _write_atomic(data)


func _write_atomic(value: Dictionary) -> bool:
	last_error = ""
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "open"
		return false
	file.store_string(JSON.stringify(value))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		last_error = "write"
		return false
	# Only rotate a valid main file. A corrupt main must never replace a good backup.
	if _read_valid(save_path) != null:
		if DirAccess.copy_absolute(save_path, save_path + ".bak") != OK:
			last_error = "backup"
			return false
	if DirAccess.rename_absolute(temporary, save_path) != OK:
		last_error = "replace"
		return false
	return true


func load_progress() -> bool:
	var loaded: Variant = _read_valid(save_path)
	if loaded == null:
		loaded = _read_valid(save_path + ".bak")
	if loaded == null:
		return false
	var was_legacy := int(loaded.get("schema_version", 1)) < SCHEMA_VERSION
	var normalized := fresh()
	normalized.merge(loaded, true)
	normalized.schema_version = SCHEMA_VERSION
	var normalized_settings: Dictionary = fresh().settings
	normalized_settings.merge(normalized.settings, true)
	normalized.settings = normalized_settings
	for dictionary_key in ["quest_fruit_pouch", "fruit_inventory", "checkpoint_storage",
			"river_attempts"]:
		if not normalized.get(dictionary_key) is Dictionary:
			normalized[dictionary_key] = {}
	for array_key in ["fruit_receipt_ids", "crafted_recipe_ids", "river_organ",
			"hush_vines", "rain_bells"]:
		if not normalized.get(array_key) is Array:
			normalized[array_key] = []
	if was_legacy and persistent and not _write_atomic(normalized):
		return false
	data = normalized
	changed.emit()
	return true


func _read_valid(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	var parsed: Variant = parser.data
	return parsed if valid(parsed) else null


static func valid(value: Variant) -> bool:
	if not value is Dictionary or int(value.get("schema_version", 0)) not in [1, 2, SCHEMA_VERSION] \
			or value.get("world_id") != "heart_melody":
		return false
	for key in ["planters", "xp_receipts", "settings"]:
		if not value.get(key) is Dictionary: return false
	for key in ["phrase", "cleared_waves", "completed_task_ids", "completed_quest_ids", "identity_dismissed"]:
		if not value.get(key) is Array: return false
	if not value.get("rhythm_solved") is bool: return false
	if value.get("checkpoint") not in ["arrival", "planter_court", "drum_garden", "restored_garden",
			"river_organ", "river_harp", "bell_grove"]: return false
	if int(value.get("mistake_count", 0)) < 0: return false
	if int(value.get("hint_level", 0)) < 0 or int(value.get("hint_level", 0)) > 3: return false
	for key in ["puzzle_help", "combat_assist", "reduced_motion", "muted"]:
		if not value.settings.get(key) is bool: return false
	for key in ["music_volume", "effects_volume"]:
		var volume: Variant = value.settings.get(key)
		if not (volume is float or volume is int) or float(volume) < 0.0 or float(volume) > 1.0: return false
	if int(value.get("schema_version", 1)) >= 2:
		for key in ["quest_fruit_pouch", "fruit_inventory", "checkpoint_storage"]:
			if not value.get(key) is Dictionary: return false
		for key in ["fruit_receipt_ids", "crafted_recipe_ids"]:
			if not value.get(key) is Array: return false
	if int(value.get("schema_version", 1)) == SCHEMA_VERSION:
		if not value.get("river_attempts") is Dictionary: return false
		for key in ["river_organ", "hush_vines", "rain_bells"]:
			if not value.get(key) is Array: return false
		if value.river_organ.size() != 3 or value.hush_vines.size() != 5 or value.rain_bells.size() > 4:
			return false
		for organ_value in value.river_organ:
			if not (organ_value is int or organ_value is float) or int(organ_value) != organ_value \
					or organ_value < 0 or organ_value > 2: return false
		for vine_value in value.hush_vines:
			if not (vine_value is int or vine_value is float) or int(vine_value) != vine_value \
					or vine_value < 0 or vine_value > 4: return false
		for direction in value.rain_bells:
			if direction not in ["north", "east", "south", "west"]: return false
		for attempt_value in value.river_attempts.values():
			if not (attempt_value is int or attempt_value is float) or int(attempt_value) != attempt_value \
					or attempt_value < 0: return false
	if int(value.get("schema_version", 1)) >= 2:
		for fruit_id in ChapterCatalog.EXPECTED_FRUIT_IDS:
			var story_count := int(value.quest_fruit_pouch.get(fruit_id, 0))
			var inventory_count := int(value.fruit_inventory.get(fruit_id, 0))
			var storage_count := int(value.checkpoint_storage.get(fruit_id, 0))
			if story_count < 0 or inventory_count < 0 or inventory_count > 99 or storage_count < 0:
				return false
		for dictionary_key in ["quest_fruit_pouch", "fruit_inventory", "checkpoint_storage"]:
			for fruit_id in value[dictionary_key]:
				if fruit_id not in ChapterCatalog.EXPECTED_FRUIT_IDS: return false
		var receipt_set := {}
		for receipt_id in value.fruit_receipt_ids:
			if not receipt_id is String or receipt_id.is_empty() or receipt_id in receipt_set: return false
			receipt_set[receipt_id] = true
		var chapter := ChapterCatalog.read()
		var recipe_ids := {}
		for recipe_value in chapter.get("recipes", []):
			recipe_ids[str(recipe_value.get("id", ""))] = true
		for recipe_id in value.crafted_recipe_ids:
			if recipe_id not in recipe_ids: return false
	for id in value.planters:
		if id not in ["0", "1", "2"] or value.planters[id] not in CHOICES: return false
	if value.phrase.size() > 3: return false
	for note in value.phrase:
		if note not in SYMBOLS: return false
	if value.rhythm_solved and (value.planters.size() != 3 or value.phrase != PHRASE): return false
	if value.cleared_waves.size() > 2: return false
	for index in value.cleared_waves.size():
		if value.cleared_waves[index] != index: return false
	if not value.cleared_waves.is_empty() and not value.rhythm_solved: return false
	for id in value.xp_receipts:
		var expected: int = 80 if id == QUEST_ID else (105 if id == RIVER_QUEST_ID else int(ENEMY_XP.get(id, -1)))
		if expected < 0 or value.xp_receipts[id] != expected: return false
	var expected_tasks: Array = [PLANT_TASK] if value.planters.size() == 3 else []
	var expected_quests: Array = []
	if value.cleared_waves.size() == 2:
		expected_tasks.append(RHYTHM_TASK)
		expected_quests.append(QUEST_ID)
		if value.xp_receipts.get(QUEST_ID) != 80: return false
	elif value.xp_receipts.has(QUEST_ID): return false
	var river_task_order := [ORGAN_TASK, VINE_TASK, BOAT_TASK]
	var seen_incomplete_river_task := false
	for river_task in river_task_order:
		if river_task in value.completed_task_ids:
			if seen_incomplete_river_task or QUEST_ID not in expected_quests: return false
			expected_tasks.append(river_task)
		else:
			seen_incomplete_river_task = true
	if ORGAN_TASK in value.completed_task_ids and value.river_organ != ORGAN_TARGET: return false
	if VINE_TASK in value.completed_task_ids and value.hush_vines != VINE_TARGET: return false
	if BOAT_TASK in value.completed_task_ids:
		if value.rain_bells != BELL_TARGET or value.xp_receipts.get(RIVER_QUEST_ID) != 105: return false
		expected_quests.append(RIVER_QUEST_ID)
	elif value.xp_receipts.has(RIVER_QUEST_ID): return false
	for wave in value.cleared_waves:
		for id in WAVES[int(wave)]:
			if not value.xp_receipts.has(id): return false
	return value.completed_task_ids == expected_tasks and value.completed_quest_ids == expected_quests


static func _recipe(chapter: Dictionary, recipe_id: String) -> Dictionary:
	for recipe_value in chapter.get("recipes", []):
		if recipe_value is Dictionary and str(recipe_value.get("id", "")) == recipe_id:
			return recipe_value
	return {}


static func _valid_fruit_id(fruit_id: String) -> bool:
	return fruit_id in ChapterCatalog.EXPECTED_FRUIT_IDS


static func _fruit_label(fruit_id: String) -> String:
	var fruit_value := ChapterCatalog.fruit(ChapterCatalog.read(), fruit_id)
	return str(fruit_value.get("label", fruit_id.replace("_", " ").capitalize()))
