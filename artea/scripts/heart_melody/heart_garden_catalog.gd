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
	var layout: Dictionary = catalog.get("layout",{})
	var footprint: Array = layout.get("footprint_metres",[])
	if footprint.size() != 2 or int(footprint[0]) != 640 or int(footprint[1]) != 290:
		errors.append("Island One must retain its approved 640 by 290 metre garden footprint.")
	if float(layout.get("main_route_width", 0.0)) < 6.0 \
		or float(layout.get("side_route_width", 0.0)) < 4.0 \
		or float(layout.get("bridge_width", 0.0)) < 6.0:
		errors.append("Island One routes must retain player-safe production widths.")
	if int(layout.get("quiet_meadow",{}).get("sector_count",0)) + int(layout.get("feeling_garden",{}).get("sector_count",0)) != 12:
		errors.append("Island One must contain twelve cullable terrain sectors.")
	var support: Array = catalog.get("support_objects",[])
	if support.size() != 9:
		errors.append("Island One needs its nine approved support-object roles.")
	for object in support:
		if not object is Dictionary or bool(object.get("required",true)):
			errors.append("Support objects must remain optional.")
	var moments: Array = catalog.get("identity_moments",[])
	if moments.size() != 4:
		errors.append("Island One needs four optional identity moments.")
	return errors
