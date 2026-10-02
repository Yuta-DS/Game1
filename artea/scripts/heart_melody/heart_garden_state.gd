class_name HeartGardenState
extends RefCounted

## Sole owner of Island One progress. Presentation never grants rewards.
signal changed
signal feedback(accepted: bool, message: String)

const SAVE_PATH := "user://heart_melody_island_one.json"
const ChapterCatalog := preload("res://scripts/heart_melody/heart_melody_chapter_catalog.gd")
const SCHEMA_VERSION := 5
const PLANT_TASK := "heart_melody.task.plant_feeling_seeds"
const RHYTHM_TASK := "heart_melody.task.restore_garden_rhythm"
const QUEST_ID := "heart_melody.quest.wake_feeling_garden"
const RIVER_QUEST_ID := "heart_melody.quest.restore_river_song"
const ORGAN_TASK := "heart_melody.task.tune_waterfall_organ"
const VINE_TASK := "heart_melody.task.release_hush_vines"
const BOAT_TASK := "heart_melody.task.call_rain_boat"
const HEART_QUEST_ID := "heart_melody.quest.build_heart_song"
const CHIME_TASK := "heart_melody.task.restore_bridge_chimes"
const WARNING_TASK := "heart_melody.task.cross_warning_bells"
const LOOM_TASK := "heart_melody.task.assemble_heart_song"
const FINAL_QUEST_ID := "heart_melody.quest.free_silent_conductor"
const ANCHOR_TASK := "heart_melody.task.join_beat_anchors"
const ORCHESTRA_TASK := "heart_melody.task.free_silent_conductor"
const CONDUCTOR_XP_ID := "heart_melody.boss.silent_conductor"
const SYMBOLS := ["leaf", "droplet", "sun"]
const PHRASE := ["leaf", "sun", "droplet"]
const ORGAN_TARGET := [1, 2, 0]
const VINE_TARGET := [0, 1, 2, 3, 4]
const BELL_TARGET := ["north", "east", "south", "west"]
const CHIME_TARGET := [1, 2, 0]
const WARNING_TARGET := ["left", "centre", "right", "centre"]
const LOOM_TARGET := ["drum", "water", "harp", "chime"]
const ANCHOR_TARGETS := [
	["leaf", "sun", "droplet"],
	["low", "high", "calm"],
	["left", "centre", "right"],
]
const ORCHESTRA_TARGET := ["echo_berry", "sun_plum", "dew_pear", "bell_apple", "moon_melon", "harmony_fig"]
const CONDUCT_TARGET := ["up", "left", "right", "down"]
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
		"chime_wind": [0, 0, 0], "bridge_chimes": [false, false, false],
		"warning_path": [], "loom_motifs": [],
		"beat_anchor_steps": [[], [], []], "beat_anchors": [false, false, false],
		"orchestra_fruits": [], "conducting_steps": [], "harmony_rewards_claimed": false,
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


func heart_song_complete() -> bool:
	return HEART_QUEST_ID in data.completed_quest_ids


func harmony_complete() -> bool:
	return FINAL_QUEST_ID in data.completed_quest_ids


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
	if harmony_complete():
		return "Heart Melody is restored. The Creator's Light gate is open."
	if heart_song_complete():
		if not task_complete(ANCHOR_TASK):
			return "Join the Rhythm, Pitch, and Direction Beat Anchors."
		return "Harvest Harmony Figs, fill the six orchestra sockets, and conduct the finale."
	if river_complete():
		if not task_complete(CHIME_TASK):
			return "Restore the three Harmony Bridge Chimes."
		if not task_complete(WARNING_TASK):
			return "Harvest three Moon Melons and cross the Warning Bell Path."
		return "Arrange the four recovered motifs at the Heart Song Loom."
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
			"river_organ", "river_harp", "bell_grove", "chime_bridge", "peace_garden",
			"heart_song_loom", "harmony_stage", "harmony_orchestra", "harmony_sanctuary"]:
		return _reply(false, "Unknown checkpoint.")
	var next := data.duplicate(true)
	next.checkpoint = id
	return _commit(next, "Checkpoint saved.")


func dismiss_identity(id: String) -> Dictionary:
	if id not in ["HM_ID_01", "HM_ID_02", "HM_ID_03", "HM_ID_04",
			"HM_ID_05", "HM_ID_06", "HM_ID_07", "HM_ID_08"]:
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


func set_chime_wind(index: int, phase: int) -> Dictionary:
	if not river_complete():
		return _reply(false, "Call the Rain Boat before restoring the bridge chimes.")
	if index < 0 or index >= 3 or phase < 0 or phase > 2:
		return _reply(false, "Choose one of the three visible wind phases.")
	if bool(data.bridge_chimes[index]):
		return _reply(true, "That chime arch is already singing.")
	var next := data.duplicate(true)
	next.chime_wind[index] = phase
	return _commit(next, "Chime %d striker aimed at wind phase %d." % [index + 1, phase + 1])


func strike_bridge_chime(index: int) -> Dictionary:
	if not river_complete() or story_fruit_count("bell_apple") < 4:
		return _reply(false, "River Song and the four Bell Apple clappers are required.")
	if index < 0 or index >= 3:
		return _reply(false, "Choose one of the three chime arches.")
	if bool(data.bridge_chimes[index]):
		return _reply(true, "That chime arch is already restored.")
	if int(data.chime_wind[index]) != CHIME_TARGET[index]:
		return _record_river_attempt("chime_%d" % index, "The striker missed the bright wind window; the completed chimes stay safe.")
	var next := data.duplicate(true)
	next.bridge_chimes[index] = true
	if false not in next.bridge_chimes:
		next.completed_task_ids.append(CHIME_TASK)
		next.checkpoint = "chime_bridge"
	return _commit(next, "Harmony Chime %d restored%s" % [index + 1, ". The Peace Garden path has grown." if false not in next.bridge_chimes else "."])


func enter_warning_channel(channel: String) -> Dictionary:
	if not task_complete(CHIME_TASK) or story_fruit_count("moon_melon") < 3:
		return _reply(false, "Restore the chimes and harvest three Moon Melons first.")
	if channel not in ["left", "centre", "right"]:
		return _reply(false, "Move into a marked quiet channel.")
	if task_complete(WARNING_TASK):
		return _reply(true, "The quiet route remains open.")
	if data.warning_path.size() >= 4:
		return _reply(false, "Four crossings are ready. Confirm, undo, or reset them.")
	var next := data.duplicate(true)
	next.warning_path.append(channel)
	return _commit(next, "%d/4 quiet gaps crossed." % next.warning_path.size())


func revise_warning_path(reset := false) -> Dictionary:
	if task_complete(WARNING_TASK):
		return _reply(true, "The safe crossing remains remembered.")
	var next := data.duplicate(true)
	if reset: next.warning_path.clear()
	elif not next.warning_path.is_empty(): next.warning_path.pop_back()
	return _commit(next, "The nearby Peace Flower keeps every completed section safe.")


func confirm_warning_path() -> Dictionary:
	if task_complete(WARNING_TASK):
		return _reply(true, "The Warning Bell Path is already calm.")
	if data.warning_path != WARNING_TARGET:
		return _record_river_attempt("warning", "Follow the ground ripples: Left • Centre • Right • Centre.")
	var next := data.duplicate(true)
	next.completed_task_ids.append(WARNING_TASK)
	next.checkpoint = "peace_garden"
	return _commit(next, "The Warning Bell Path is calm. The Heart Song Loom is awake.")


func enter_loom_motif(motif: String) -> Dictionary:
	if not task_complete(WARNING_TASK):
		return _reply(false, "Cross the Warning Bell Path before arranging the recovered song.")
	if motif not in LOOM_TARGET:
		return _reply(false, "Choose Drum, Water, Harp, or Chime.")
	if task_complete(LOOM_TASK):
		return _reply(true, "The completed Heart Song is ready to replay.")
	if data.loom_motifs.size() >= 4:
		return _reply(false, "Four motifs are ready. Confirm, undo, or reset them.")
	var next := data.duplicate(true)
	next.loom_motifs.append(motif)
	return _commit(next, "%d/4 motifs arranged." % next.loom_motifs.size())


func revise_loom(reset := false) -> Dictionary:
	if task_complete(LOOM_TASK):
		return _reply(true, "The completed Heart Song remains saved.")
	var next := data.duplicate(true)
	if reset: next.loom_motifs.clear()
	elif not next.loom_motifs.is_empty(): next.loom_motifs.pop_back()
	return _commit(next, "Adjust the four-track score when you are ready.")


func confirm_loom() -> Dictionary:
	if task_complete(LOOM_TASK):
		return _reply(true, "The Heart Song remains assembled.")
	if data.loom_motifs != LOOM_TARGET:
		return _record_river_attempt("loom", "Build outward from the first lesson: Drum • Water • Harp • Chime.")
	var next := data.duplicate(true)
	next.completed_task_ids.append(LOOM_TASK)
	next.completed_quest_ids.append(HEART_QUEST_ID)
	next.xp_receipts[HEART_QUEST_ID] = 130
	next.checkpoint = "heart_song_loom"
	return _commit(next, "Heart Song assembled — 130 quest XP! Harmony Stage is listening.")


func enter_beat_anchor_step(index: int, step: String) -> Dictionary:
	if not heart_song_complete():
		return _reply(false, "Assemble the Heart Song before joining the Beat Anchors.")
	if index < 0 or index >= ANCHOR_TARGETS.size() or step not in ANCHOR_TARGETS[index]:
		return _reply(false, "Choose one of this anchor's visible lesson symbols.")
	if bool(data.beat_anchors[index]):
		return _reply(true, "That Beat Anchor is already joined to the song.")
	var next := data.duplicate(true)
	var expected: String = str(ANCHOR_TARGETS[index][next.beat_anchor_steps[index].size()])
	if step != expected:
		next.beat_anchor_steps[index] = []
		return _commit(next, "The anchor releases a broad wave. Its short lesson has reset.", false)
	next.beat_anchor_steps[index].append(step)
	if next.beat_anchor_steps[index].size() == ANCHOR_TARGETS[index].size():
		next.beat_anchors[index] = true
		if false not in next.beat_anchors:
			next.completed_task_ids.append(ANCHOR_TASK)
			next.checkpoint = "harmony_stage"
	return _commit(next, "Beat Anchor %d joined%s" % [index + 1,
		". The Harmony Fruit Orchestra is exposed." if false not in next.beat_anchors else "."])


func reset_beat_anchor(index: int) -> Dictionary:
	if index < 0 or index >= ANCHOR_TARGETS.size():
		return _reply(false, "Choose a Beat Anchor.")
	if bool(data.beat_anchors[index]):
		return _reply(true, "Completed Beat Anchors stay safe after retries.")
	var next := data.duplicate(true)
	next.beat_anchor_steps[index] = []
	return _commit(next, "This anchor phase is ready to replay.")


func place_orchestra_fruit(fruit_id: String) -> Dictionary:
	if not task_complete(ANCHOR_TASK):
		return _reply(false, "Join all three Beat Anchors before filling the orchestra.")
	if fruit_id not in ORCHESTRA_TARGET:
		return _reply(false, "Choose one of the six musical fruit families.")
	if data.orchestra_fruits.size() >= ORCHESTRA_TARGET.size():
		return _reply(false, "All six orchestra sockets are filled. Conduct or revise the score.")
	var needed := 6 if fruit_id == "harmony_fig" else 1
	if story_fruit_count(fruit_id) < needed:
		return _reply(false, "The protected quest pouch does not yet hold the required %s." % _fruit_label(fruit_id))
	var next := data.duplicate(true)
	var expected: String = ORCHESTRA_TARGET[next.orchestra_fruits.size()]
	if fruit_id != expected:
		return _commit(next, "That layer belongs later. The filled sockets stay safe.", false)
	next.orchestra_fruits.append(fruit_id)
	if next.orchestra_fruits.size() == ORCHESTRA_TARGET.size():
		next.checkpoint = "harmony_orchestra"
	return _commit(next, "%s joins the orchestra — %d/6 layers." % [_fruit_label(fruit_id), next.orchestra_fruits.size()])


func revise_orchestra() -> Dictionary:
	if task_complete(ORCHESTRA_TASK):
		return _reply(true, "The restored orchestra remains complete for replay.")
	var next := data.duplicate(true)
	if not next.orchestra_fruits.is_empty(): next.orchestra_fruits.pop_back()
	next.conducting_steps.clear()
	return _commit(next, "The latest orchestra layer has returned to the protected pouch.")


func enter_conduct_direction(direction: String) -> Dictionary:
	if data.orchestra_fruits != ORCHESTRA_TARGET:
		return _reply(false, "Fill all six fruit sockets before conducting.")
	if direction not in CONDUCT_TARGET:
		return _reply(false, "Conduct with Up, Left, Right, or Down.")
	if task_complete(ORCHESTRA_TASK):
		return _reply(true, "The living amphitheatre can replay the completed finale.")
	if data.conducting_steps.size() >= CONDUCT_TARGET.size():
		return _reply(false, "The four gestures are ready. Confirm or reset the finale.")
	var next := data.duplicate(true)
	next.conducting_steps.append(direction)
	return _commit(next, "%d/4 conducting gestures shaped." % next.conducting_steps.size())


func reset_conducting() -> Dictionary:
	if task_complete(ORCHESTRA_TASK):
		return _reply(true, "The completed finale remains available for replay.")
	var next := data.duplicate(true)
	next.conducting_steps.clear()
	return _commit(next, "The conducting phrase is ready to replay.")


func confirm_orchestra() -> Dictionary:
	if task_complete(ORCHESTRA_TASK):
		return _reply(true, "The Silent Conductor is free and the sanctuary remains open.")
	if data.orchestra_fruits != ORCHESTRA_TARGET:
		return _reply(false, "Place the six musical fruit families in their taught order.")
	if data.conducting_steps != CONDUCT_TARGET:
		return _record_river_attempt("conductor", "Follow the stage lights: Up • Left • Right • Down.")
	var next := data.duplicate(true)
	next.completed_task_ids.append(ORCHESTRA_TASK)
	next.completed_quest_ids.append(FINAL_QUEST_ID)
	next.xp_receipts[CONDUCTOR_XP_ID] = 160
	next.xp_receipts[FINAL_QUEST_ID] = 205
	next.harmony_rewards_claimed = true
	next.checkpoint = "harmony_sanctuary"
	return _commit(next, "Silent Conductor freed — Harmony Jewel and Harmony Shield restored! 365 XP awarded.")


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
			"hush_vines", "rain_bells", "chime_wind", "bridge_chimes", "warning_path",
			"loom_motifs", "beat_anchor_steps", "beat_anchors", "orchestra_fruits",
			"conducting_steps"]:
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
	if not value is Dictionary or int(value.get("schema_version", 0)) not in [1, 2, 3, 4, SCHEMA_VERSION] \
			or value.get("world_id") != "heart_melody":
		return false
	for key in ["planters", "xp_receipts", "settings"]:
		if not value.get(key) is Dictionary: return false
	for key in ["phrase", "cleared_waves", "completed_task_ids", "completed_quest_ids", "identity_dismissed"]:
		if not value.get(key) is Array: return false
	if not value.get("rhythm_solved") is bool: return false
	if value.get("checkpoint") not in ["arrival", "planter_court", "drum_garden", "restored_garden",
			"river_organ", "river_harp", "bell_grove", "chime_bridge", "peace_garden",
			"heart_song_loom", "harmony_stage", "harmony_orchestra", "harmony_sanctuary"]: return false
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
	if int(value.get("schema_version", 1)) >= 3:
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
	if int(value.get("schema_version", 1)) >= 4:
		for key in ["chime_wind", "bridge_chimes", "warning_path", "loom_motifs"]:
			if not value.get(key) is Array: return false
		if value.chime_wind.size() != 3 or value.bridge_chimes.size() != 3 \
				or value.warning_path.size() > 4 or value.loom_motifs.size() > 4: return false
		for phase in value.chime_wind:
			if not (phase is int or phase is float) or int(phase) != phase or phase < 0 or phase > 2: return false
		for restored in value.bridge_chimes:
			if not restored is bool: return false
		for channel in value.warning_path:
			if channel not in ["left", "centre", "right"]: return false
		for motif in value.loom_motifs:
			if motif not in LOOM_TARGET: return false
	if int(value.get("schema_version", 1)) == SCHEMA_VERSION:
		for key in ["beat_anchor_steps", "beat_anchors", "orchestra_fruits", "conducting_steps"]:
			if not value.get(key) is Array: return false
		if value.beat_anchor_steps.size() != 3 or value.beat_anchors.size() != 3 \
				or value.orchestra_fruits.size() > 6 or value.conducting_steps.size() > 4: return false
		for index in 3:
			if not value.beat_anchor_steps[index] is Array \
					or value.beat_anchor_steps[index].size() > ANCHOR_TARGETS[index].size(): return false
			for step in value.beat_anchor_steps[index]:
				if step not in ANCHOR_TARGETS[index]: return false
			if not value.beat_anchors[index] is bool: return false
		for fruit_id in value.orchestra_fruits:
			if fruit_id not in ORCHESTRA_TARGET: return false
		for direction in value.conducting_steps:
			if direction not in CONDUCT_TARGET: return false
		if not value.get("harmony_rewards_claimed") is bool: return false
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
		var expected: int = 80 if id == QUEST_ID else (105 if id == RIVER_QUEST_ID else (130 if id == HEART_QUEST_ID else (205 if id == FINAL_QUEST_ID else (160 if id == CONDUCTOR_XP_ID else int(ENEMY_XP.get(id, -1))))))
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
	var heart_task_order := [CHIME_TASK, WARNING_TASK, LOOM_TASK]
	var seen_incomplete_heart_task := false
	for heart_task in heart_task_order:
		if heart_task in value.completed_task_ids:
			if seen_incomplete_heart_task or RIVER_QUEST_ID not in expected_quests: return false
			expected_tasks.append(heart_task)
		else:
			seen_incomplete_heart_task = true
	if CHIME_TASK in value.completed_task_ids:
		if false in value.bridge_chimes or value.chime_wind != CHIME_TARGET: return false
	if WARNING_TASK in value.completed_task_ids and value.warning_path != WARNING_TARGET: return false
	if LOOM_TASK in value.completed_task_ids:
		if value.loom_motifs != LOOM_TARGET or value.xp_receipts.get(HEART_QUEST_ID) != 130: return false
		expected_quests.append(HEART_QUEST_ID)
	elif value.xp_receipts.has(HEART_QUEST_ID): return false
	var final_task_order := [ANCHOR_TASK, ORCHESTRA_TASK]
	var seen_incomplete_final_task := false
	for final_task in final_task_order:
		if final_task in value.completed_task_ids:
			if seen_incomplete_final_task or HEART_QUEST_ID not in expected_quests: return false
			expected_tasks.append(final_task)
		else:
			seen_incomplete_final_task = true
	if ANCHOR_TASK in value.completed_task_ids:
		if false in value.beat_anchors: return false
		for index in 3:
			if value.beat_anchor_steps[index] != ANCHOR_TARGETS[index]: return false
	if ORCHESTRA_TASK in value.completed_task_ids:
		if value.orchestra_fruits != ORCHESTRA_TARGET or value.conducting_steps != CONDUCT_TARGET \
				or not value.harmony_rewards_claimed: return false
		if value.xp_receipts.get(CONDUCTOR_XP_ID) != 160 \
				or value.xp_receipts.get(FINAL_QUEST_ID) != 205: return false
		expected_quests.append(FINAL_QUEST_ID)
	elif value.xp_receipts.has(CONDUCTOR_XP_ID) or value.xp_receipts.has(FINAL_QUEST_ID) \
			or bool(value.harmony_rewards_claimed): return false
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
