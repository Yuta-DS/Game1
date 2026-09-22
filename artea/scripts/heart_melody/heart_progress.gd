extends RefCounted
# One atomic record owns both XP receipts and progression: no cross-file reward window.
const Catalog = preload("res://scripts/heart_melody/heart_catalog.gd")
var path := "user://heart_melody_island_one.json"
var dirty := false
var data: Dictionary = fresh()
var committed: Dictionary = fresh()
var recovery_message := ""

static func fresh() -> Dictionary:
	return {"schema": 1, "campaign_version": 2, "planters": {}, "phrase": [], "solved": false,
		"waves": [], "receipts": {}, "tasks": [], "checkpoint": "arrival", "complete": false, "xp": 0}

func load_progress() -> void:
	data = fresh()
	committed = fresh()
	dirty = false
	recovery_message = ""
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parsed: Variant = normalize(read_record(candidate))
		if valid(parsed):
			data = parsed
			committed = data.duplicate(true)
			if candidate != path:
				dirty = true
				recovery_message = "Recovered your last valid save. Retry saving in Help."
			return
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		recovery_message = "The saved garden could not be read. A fresh garden is available; the damaged files remain until you save."

static func normalize(value: Variant) -> Variant:
	if value is Dictionary:
		for key in ["planters", "receipts"]:
			if value.get(key) is Dictionary:
				for id in value[key]:
					var number: Variant = value[key][id]
					if not (number is float or number is int): return null
					if not is_finite(float(number)) or float(number) != floor(float(number)): return null
					value[key][id] = int(number)
		for key in ["phrase", "waves"]:
			if value.get(key) is Array:
				for i in value[key].size():
					if not (value[key][i] is float or value[key][i] is int): return null
					if float(value[key][i]) != floor(float(value[key][i])): return null
					value[key][i] = int(value[key][i])
	return value

static func valid(value: Variant) -> bool:
	value = normalize(value)
	if not value is Dictionary: return false
	for key in ["schema", "campaign_version", "xp"]:
		if not (value.get(key) is int or value.get(key) is float): return false
	if not value.get("checkpoint") is String: return false
	if value.get("schema") != 1 or value.get("campaign_version") != 2: return false
	for key in ["planters", "receipts"]:
		if not value.get(key) is Dictionary: return false
	for key in ["phrase", "waves", "tasks"]:
		if not value.get(key) is Array: return false
	for key in ["solved", "complete"]:
		if not value.get(key) is bool: return false
	if value.get("checkpoint", "") not in ["arrival", "garden", "restored_garden"]: return false
	for id in value.planters:
		if not (value.planters[id] is float or value.planters[id] is int): return false
		if str(id) not in ["0", "1", "2"] or value.planters[id] != floor(float(value.planters[id])) or int(value.planters[id]) not in range(7): return false
	if value.waves not in [[], [1], [1, 2]]: return false
	var planted: bool = value.planters.size() == 3
	if value.solved and not planted: return false
	if not value.waves.is_empty() and not value.solved: return false
	if value.complete != value.waves.has(2): return false
	var expected_tasks: Array = []
	if planted: expected_tasks.append(Catalog.TASK_PLANT)
	if value.complete: expected_tasks.append(Catalog.TASK_RHYTHM)
	if value.tasks != expected_tasks: return false
	var expected_checkpoint := "restored_garden" if value.complete else ("garden" if value.solved else "arrival")
	if value.checkpoint != expected_checkpoint: return false
	var expected_receipts: Dictionary = {}
	if value.waves.has(1): expected_receipts["wave1_moth"] = 12
	if value.complete: expected_receipts.merge({"wave2_moth": 12, "wave2_slime": 15, "quest_one": 80})
	if value.receipts != expected_receipts: return false
	var expected_xp := 0
	var awards := {"wave1_moth": 12, "wave2_moth": 12, "wave2_slime": 15, "quest_one": 80}
	for receipt in value.receipts:
		if not awards.has(receipt) or value.receipts[receipt] != awards[receipt]: return false
		expected_xp += awards[receipt]
	if value.get("xp", -1) != expected_xp: return false
	if value.phrase.size() > 3: return false
	for note in value.phrase:
		if int(note) not in range(3): return false
	if value.get("solved", false) and value.phrase != Catalog.PHRASE: return false
	if value.get("complete", false) and (value.planters.size() != 3 or not value.get("solved", false) or not value.waves.has(2)): return false
	return true

func commit() -> bool:
	dirty = true
	if not valid(data): return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) and valid(read_record(path)):
		if DirAccess.copy_absolute(absolute, absolute + ".bak") != OK: return false
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK: return false
	dirty = false
	committed = data.duplicate(true)
	recovery_message = ""
	return true

func plant(id: int, choice: int) -> bool:
	if id not in range(3) or choice not in range(7): return false
	data.planters[str(id)] = choice
	if data.planters.size() == 3 and not data.tasks.has(Catalog.TASK_PLANT): data.tasks.append(Catalog.TASK_PLANT)
	return commit()

func edit_phrase(notes: Array) -> bool:
	if data.solved or notes.size() > 3: return false
	for note in notes:
		if not note is int or note not in range(3): return false
	data.phrase = notes.duplicate()
	return commit()

func solve() -> bool:
	if data.planters.size() != 3 or data.phrase != Catalog.PHRASE: return false
	data.solved = true
	data.checkpoint = "garden"
	return commit()

func reward(id: String, amount: int) -> void:
	if data.receipts.has(id): return
	data.receipts[id] = amount
	data.xp += amount

func clear_wave(wave: int) -> bool:
	if not data.solved or wave not in [1, 2] or (wave == 2 and not data.waves.has(1)): return false
	if not data.waves.has(wave): data.waves.append(wave)
	for enemy in Catalog.ENEMIES:
		if str(enemy.id).begins_with("wave%d" % wave): reward(enemy.id, enemy.xp)
	if wave == 2:
		data.complete = true
		data.checkpoint = "restored_garden"
		if not data.tasks.has(Catalog.TASK_RHYTHM): data.tasks.append(Catalog.TASK_RHYTHM)
		reward("quest_one", 80)
	return commit()




static func read_record(file_path: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) != OK: return null
	return parser.data
