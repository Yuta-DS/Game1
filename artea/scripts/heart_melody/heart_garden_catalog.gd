class_name HeartGardenCatalog
extends RefCounted

const PATH := "res://data/heart_melody_island_one.json"

static func read() -> Dictionary:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(PATH)) != OK: return {}
	return parser.data if parser.data is Dictionary else {}

static func validate(catalog: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if catalog.get("schema_version") != 1 or catalog.get("world_id") != "heart_melody":
		errors.append("Heart Island One needs its own schema-v1 catalog.")
	var quest: Dictionary = catalog.get("quest",{})
	if quest.get("id") != "heart_melody.quest.wake_feeling_garden" or quest.get("xp") != 80:
		errors.append("Quest identity and reward must remain stable.")
	var tasks: Array = quest.get("tasks",[])
	if tasks.size() != 2:
		errors.append("Island One contains exactly two required tasks.")
	else:
		if tasks[0].get("id") != "heart_melody.task.plant_feeling_seeds" or tasks[0].get("required_count") != 3:
			errors.append("Three seeds are required.")
		if tasks[1].get("id") != "heart_melody.task.restore_garden_rhythm" or tasks[1].get("phrase") != ["leaf","sun","droplet"]:
			errors.append("The authored flower phrase must agree with the runtime.")
	var policy: Dictionary = catalog.get("content_policy",{})
	if policy.get("delivery") != "curated_offline" or policy.get("personal_disclosure_required",true) \
		or policy.get("identity_affects_rewards",true) or policy.get("timed_reasoning",true):
		errors.append("The garden requires offline, untimed, voluntary choices.")
	var completion: Dictionary = catalog.get("completion",{})
	if completion.get("awards_world_treasure",true) or completion.get("unlocks_train",true):
		errors.append("Island One cannot award full-world completion.")
	return errors
