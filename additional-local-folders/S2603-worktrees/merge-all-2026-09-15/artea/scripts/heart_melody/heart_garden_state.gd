class_name HeartGardenState
extends RefCounted

## Sole owner of Island One progress. Presentation never grants rewards.
signal changed
signal feedback(accepted: bool, message: String)

const SAVE_PATH := "user://heart_melody_island_one.json"
const PLANT_TASK := "heart_melody.task.plant_feeling_seeds"
const RHYTHM_TASK := "heart_melody.task.restore_garden_rhythm"
const QUEST_ID := "heart_melody.quest.wake_feeling_garden"
const SYMBOLS := ["leaf", "droplet", "sun"]
const PHRASE := ["leaf", "sun", "droplet"]
const CHOICES := ["joy", "sadness", "frustration", "fear", "peace", "hope", "sound"]
const ENEMY_XP := {"garden.moth.1": 12, "garden.moth.2": 12, "garden.slime.1": 15}
const WAVES := [["garden.moth.1"], ["garden.moth.2", "garden.slime.1"]]

var save_path := SAVE_PATH
var persistent := true
var last_error := ""
var data: Dictionary = fresh()


static func fresh() -> Dictionary:
	return {"schema_version": 1, "world_id": "heart_melody", "planters": {},
		"phrase": [], "rhythm_solved": false, "cleared_waves": [],
		"xp_receipts": {}, "completed_task_ids": [], "completed_quest_ids": [],
		"checkpoint": "arrival", "identity_dismissed": [],
		"settings": {"combat_assist": false, "reduced_motion": false, "muted": false}}


func _init(path := SAVE_PATH, write_enabled := true) -> void:
	save_path = path
	persistent = write_enabled


func planted_count() -> int:
	return data.planters.size()


func complete() -> bool:
	return QUEST_ID in data.completed_quest_ids


func xp() -> int:
	var total := 0
	for value in data.xp_receipts.values():
		total += int(value)
	return total


func current_wave() -> int:
	return data.cleared_waves.size()


func objective() -> String:
	if complete():
		return "Feeling Garden restored. Explore, replay the song, or return to the Castle."
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
			return _reply(false, "Note %d was the %s flower. Listen again or undo a note." % [index + 1, PHRASE[index].capitalize()])
	var next := data.duplicate(true)
	next.rhythm_solved = true
	next.checkpoint = "drum_garden"
	return _commit(next, "The flowers remember! Follow the path to the Blight clearing.")


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
	if not data.settings.has(key):
		return _reply(false, "Unknown setting.")
	var next := data.duplicate(true)
	next.settings[key] = value
	return _commit(next, "Setting saved.")


func dismiss_identity(id: String) -> Dictionary:
	if id not in ["HM_ID_01", "HM_ID_02", "HM_ID_03", "HM_ID_04"]:
		return _reply(false, "Unknown reflection.")
	var next := data.duplicate(true)
	if id not in next.identity_dismissed:
		next.identity_dismissed.append(id)
	return _commit(next, "Your journey continues.")


func _commit(next: Dictionary, message: String) -> Dictionary:
	if persistent and not _write_atomic(next):
		return _reply(false, "Progress could not be saved. Your previous checkpoint is safe; try again.")
	data = next
	changed.emit()
	return _reply(true, message)


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
	data = loaded
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
	if not value is Dictionary or value.get("schema_version") != 1 or value.get("world_id") != "heart_melody":
		return false
	for key in ["planters", "xp_receipts", "settings"]:
		if not value.get(key) is Dictionary: return false
	for key in ["phrase", "cleared_waves", "completed_task_ids", "completed_quest_ids", "identity_dismissed"]:
		if not value.get(key) is Array: return false
	if not value.get("rhythm_solved") is bool: return false
	if value.get("checkpoint") not in ["arrival", "drum_garden", "restored_garden"]: return false
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
		var expected: int = 80 if id == QUEST_ID else int(ENEMY_XP.get(id, -1))
		if expected < 0 or value.xp_receipts[id] != expected: return false
	var expected_tasks: Array = [PLANT_TASK] if value.planters.size() == 3 else []
	var expected_quests: Array = []
	if value.cleared_waves.size() == 2:
		expected_tasks.append(RHYTHM_TASK)
		expected_quests.append(QUEST_ID)
		if value.xp_receipts.get(QUEST_ID) != 80: return false
	elif value.xp_receipts.has(QUEST_ID): return false
	for wave in value.cleared_waves:
		for id in WAVES[int(wave)]:
			if not value.xp_receipts.has(id): return false
	return value.completed_task_ids == expected_tasks and value.completed_quest_ids == expected_quests
