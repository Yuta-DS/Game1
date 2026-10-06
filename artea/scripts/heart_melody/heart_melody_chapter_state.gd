extends RefCounted

const Catalog = preload("res://scripts/heart_melody/heart_melody_chapter_catalog.gd")
const Fruit = preload("res://scripts/heart_melody/heart_melody_fruit_catalog.gd")
const SETTINGS := {"assistance": false, "subtitles": true, "reduced_motion": false,
	"reduced_flashes": false, "muted": false, "text_scale": 1.0, "demo_speed": 1.0}

static func fresh() -> Dictionary:
	return {"version": Catalog.VERSION, "tasks": [], "quest_pouch": {}, "materials": {},
		"storage": {}, "harvest_receipts": [], "reward_receipts": [], "recipes": {},
		"checkpoint": "arrival", "settings": SETTINGS.duplicate(true), "challenges": {},
		"anchors": [], "song": [], "revision": 0}

static func legacy_tasks(record: Dictionary) -> Array:
	var tasks: Array = []
	if record.get("planters", {}) is Dictionary and record.get("planters", {}).size() == 3:
		tasks.append(Catalog.TASKS[0])
	if not record.get("complete", false): return tasks
	if tasks.is_empty(): return tasks
	tasks.append(Catalog.TASKS[1])
	var river: Variant = record.get("river", {})
	if not river is Dictionary: return tasks
	if river.get("valves", []).size() != 3: return tasks
	tasks.append(Catalog.TASKS[2])
	if river.get("bulbs", []).size() != 3: return tasks
	tasks.append(Catalog.TASKS[3])
	if not river.get("boat", false): return tasks
	tasks.append(Catalog.TASKS[4])
	if river.get("chimes", []).size() != 3: return tasks
	tasks.append(Catalog.TASKS[5])
	if river.get("warning", false): tasks.append(Catalog.TASKS[6])
	return tasks

static func migrate(record: Dictionary) -> Dictionary:
	var chapter := fresh()
	chapter.tasks = legacy_tasks(record)
	chapter.checkpoint = record.get("checkpoint", "arrival")
	# Existing earned receipts remain in the legacy record; migration awards nothing.
	return chapter

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func quantities(value: Variant, allowed: Array, maximum: int) -> bool:
	if not value is Dictionary: return false
	for id in value:
		if id not in allowed or not integer(value[id], 0, maximum): return false
	return true

static func valid(value: Variant, record: Dictionary) -> bool:
	if not value is Dictionary or value.get("version") != Catalog.VERSION: return false
	if not integer(value.get("revision"), 0, 2147483647): return false
	var tasks: Variant = value.get("tasks")
	if not tasks is Array or tasks.size() > Catalog.TASKS.size(): return false
	if tasks != Catalog.TASKS.slice(0, tasks.size()): return false
	var legacy := legacy_tasks(record)
	if tasks.slice(0, mini(7, tasks.size())) != legacy: return false
	if value.get("checkpoint") not in Catalog.CHECKPOINTS: return false
	if not quantities(value.get("quest_pouch"), Fruit.IDS, 2147483647): return false
	if not quantities(value.get("materials"), Fruit.IDS, Fruit.STACK_LIMIT): return false
	if not quantities(value.get("storage"), Fruit.IDS, 2147483647): return false
	if not quantities(value.get("recipes"), Fruit.RECIPES.keys(), 99): return false
	var harvests: Variant = value.get("harvest_receipts")
	if not harvests is Array: return false
	var seen: Array = []
	for receipt in harvests:
		if not receipt is String or receipt in seen: return false
		var fruit_id: String = receipt.trim_prefix("heart_melody.harvest.")
		if fruit_id not in Fruit.IDS or receipt != Fruit.story_location(fruit_id): return false
		seen.append(receipt)
	for fruit_id in value.quest_pouch:
		if Fruit.story_location(fruit_id) not in harvests: return false
		if value.quest_pouch[fruit_id] > Fruit.FRUITS[fruit_id].story_count: return false
	var receipts: Variant = value.get("reward_receipts")
	if not receipts is Array: return false
	seen.clear()
	for receipt in receipts:
		if receipt not in Catalog.REWARDS or receipt in seen: return false
		if Catalog.REWARDS[receipt] not in tasks: return false
		seen.append(receipt)
	var settings: Variant = value.get("settings")
	if not settings is Dictionary or settings.size() != SETTINGS.size(): return false
	for key in SETTINGS:
		if key in ["text_scale", "demo_speed"]:
			if not (settings.get(key) is int or settings.get(key) is float): return false
			if not is_finite(float(settings[key])): return false
		elif not settings.get(key) is bool: return false
	if settings.text_scale < 1.0 or settings.text_scale > 2.0: return false
	if settings.demo_speed not in [0.5, 0.75, 1.0]: return false
	var anchors: Variant = value.get("anchors")
	if not anchors is Array or anchors.size() > 3: return false
	seen.clear()
	for anchor in anchors:
		if anchor not in ["rhythm", "pitch", "direction"] or anchor in seen: return false
		seen.append(anchor)
	if not anchors.is_empty() and Catalog.TASKS[7] not in tasks: return false
	if Catalog.TASKS[8] in tasks and anchors.size() != 3: return false
	var song: Variant = value.get("song")
	if not song is Array or song.size() not in [0, 4]: return false
	seen.clear()
	for motif in song:
		if motif not in ["drums", "water", "harp", "chimes"] or motif in seen: return false
		seen.append(motif)
	if Catalog.TASKS[7] in tasks and song.size() != 4: return false
	var challenges: Variant = value.get("challenges")
	if not challenges is Dictionary: return false
	for task_id in challenges:
		if task_id not in Catalog.TASKS or not Catalog.available(task_id, tasks): return false
		var challenge: Variant = challenges[task_id]
		if not challenge is Dictionary: return false
		if not integer(challenge.get("failures"), 0, 9999) or not integer(challenge.get("hint"), 0, 3): return false
		if not challenge.get("input") is Array or challenge.input.size() > 16: return false
		for note in challenge.input:
			if not integer(note, 0, 5): return false
	return true
