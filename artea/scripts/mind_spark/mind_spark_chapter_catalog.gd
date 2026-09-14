class_name MindSparkChapterCatalog
extends RefCounted

const DEFAULT_PATH := "res://data/mind_spark_chapter.json"
const PROFILE_FAITH := "faith"
const PROFILE_UNIVERSAL := "universal"
const REQUIRED_TASK_FIELDS := [
	"id", "order", "title", "location", "purpose", "reason", "guardian_dialogue",
	"science_consequence", "magic_consequence", "failure_free_encouragement", "reflection"
]
const REQUIRED_QUEST_IDS := [
	"quest.signal_observatory", "quest.echo_forest", "quest.cross_seam_relay",
	"quest.role_exchange_storm", "quest.constellation_synthesis"
]
const OPTIONAL_RUNTIME_ARRAY_FIELDS := [
	"district_ids", "object_bindings", "prerequisites", "hint_ladder",
	"success_effects", "save_aliases"
]

var data: Dictionary = {}
var errors := PackedStringArray()


func _init(source: Dictionary = {}) -> void:
	data = source.duplicate(true) if not source.is_empty() else load_catalog()
	errors = validate(data)


static func load_catalog(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func validate(source: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	if source.is_empty():
		result.append("chapter catalog must be a non-empty dictionary")
		return result
	if int(source.get("schema_version", 0)) != 1:
		result.append("schema_version must be 1")
	_validate_content_policy(source.get("content_policy", {}), result)
	_validate_profiles(source.get("profiles", {}), result)
	_validate_story_block(source.get("prologue", {}), "prologue", result)
	_validate_story_block(source.get("finale", {}), "finale", result)
	_validate_castle_return(source.get("castle_return", {}), result)
	var quests: Variant = source.get("quests", null)
	if not quests is Array or quests.size() != 5:
		result.append("quests must contain exactly five ordered quests")
		return result
	var ids := {}
	for quest_index in quests.size():
		var quest: Variant = quests[quest_index]
		if not quest is Dictionary:
			result.append("quests[%d] must be a dictionary" % quest_index)
			continue
		var quest_id := str(quest.get("id", ""))
		_validate_unique_id(quest_id, "quest", ids, result)
		if quest_id != REQUIRED_QUEST_IDS[quest_index]:
			result.append("quest %d must use canonical id %s" % [quest_index + 1, REQUIRED_QUEST_IDS[quest_index]])
		if int(quest.get("order", 0)) != quest_index + 1:
			result.append("quest %s has invalid order" % quest_id)
		_validate_story_block(quest, "quest %s" % quest_id, result)
		_validate_runtime_contract(quest, quest_id, result)
		var tasks: Variant = quest.get("tasks", null)
		if not tasks is Array or tasks.size() < 3 or tasks.size() > 5:
			result.append("quest %s must contain three to five tasks" % quest_id)
			continue
		for task_index in tasks.size():
			_validate_task(tasks[task_index], quest_id, task_index, ids, result)
	return result


static func _validate_runtime_contract(quest: Dictionary, quest_id: String,
		result: PackedStringArray) -> void:
	# Runtime metadata is additive so older schema-v1 catalogs remain valid. When
	# one field is authored, validate the complete binding as a coherent unit.
	var has_contract := false
	for field in ["island_id", "mechanic_id", "environment_state"] + OPTIONAL_RUNTIME_ARRAY_FIELDS:
		has_contract = has_contract or quest.has(field)
	if not has_contract:
		return
	for field in ["island_id", "mechanic_id", "environment_state"]:
		if str(quest.get(field, "")).strip_edges().is_empty():
			result.append("quest %s runtime contract needs %s" % [quest_id, field])
	for field in OPTIONAL_RUNTIME_ARRAY_FIELDS:
		var values: Variant = quest.get(field, null)
		if not values is Array:
			result.append("quest %s runtime contract needs array %s" % [quest_id, field])
			continue
		for value in values:
			if str(value).strip_edges().is_empty():
				result.append("quest %s runtime contract has an empty %s value" % [quest_id, field])
	if quest.get("district_ids", []).is_empty():
		result.append("quest %s runtime contract needs at least one district" % quest_id)
	if quest.get("object_bindings", []).is_empty():
		result.append("quest %s runtime contract needs at least one object binding" % quest_id)
	if quest.get("hint_ladder", []).size() < 2:
		result.append("quest %s runtime contract needs at least two progressive hints" % quest_id)
	if quest.get("success_effects", []).is_empty():
		result.append("quest %s runtime contract needs at least one success effect" % quest_id)


static func _validate_content_policy(policy: Variant, result: PackedStringArray) -> void:
	if not policy is Dictionary or str(policy.get("delivery", "")) != "curated_offline":
		result.append("content_policy.delivery must be curated_offline")
		return
	for forbidden_capability in ["free_text", "diagnosis", "network", "generative_ai", "scoring_inner_state"]:
		if policy.get(forbidden_capability, true) != false:
			result.append("content_policy.%s must be false" % forbidden_capability)


static func _validate_profiles(profiles: Variant, result: PackedStringArray) -> void:
	if not profiles is Dictionary:
		result.append("profiles must be a dictionary")
		return
	if str(profiles.get(PROFILE_FAITH, {}).get("guardian_name", "")) != "Everlasting Father":
		result.append("faith guardian must be Everlasting Father")
	if str(profiles.get(PROFILE_UNIVERSAL, {}).get("guardian_name", "")) != "Guardian of Wisdom":
		result.append("universal guardian must be Guardian of Wisdom")


static func _validate_story_block(block: Variant, label: String, result: PackedStringArray) -> void:
	if not block is Dictionary:
		result.append("%s must be a dictionary" % label)
		return
	for field in ["title", "location", "purpose", "reason", "guardian_dialogue"]:
		if not block.has(field):
			result.append("%s is missing %s" % [label, field])
	_validate_profile_text(block.get("guardian_dialogue", {}), "%s.guardian_dialogue" % label, result)


static func _validate_task(task: Variant, quest_id: String, task_index: int, ids: Dictionary, result: PackedStringArray) -> void:
	var label := "quest %s task %d" % [quest_id, task_index]
	if not task is Dictionary:
		result.append("%s must be a dictionary" % label)
		return
	for field in REQUIRED_TASK_FIELDS:
		if not task.has(field):
			result.append("%s is missing %s" % [label, field])
	var task_id := str(task.get("id", ""))
	_validate_unique_id(task_id, "task", ids, result)
	if int(task.get("order", 0)) != task_index + 1:
		result.append("task %s has invalid order" % task_id)
	for field in ["title", "location", "purpose", "reason", "science_consequence", "magic_consequence"]:
		if str(task.get(field, "")).strip_edges().is_empty():
			result.append("task %s has empty %s" % [task_id, field])
	_validate_profile_text(task.get("guardian_dialogue", {}), "task %s.guardian_dialogue" % task_id, result)
	_validate_profile_text(task.get("failure_free_encouragement", {}), "task %s.failure_free_encouragement" % task_id, result)
	var reflection: Variant = task.get("reflection", {})
	if not reflection is Dictionary or str(reflection.get("prompt", "")).strip_edges().is_empty():
		result.append("task %s needs a reflection prompt" % task_id)
		return
	var choices: Variant = reflection.get("choices", null)
	if not choices is Array or choices.size() < 2 or choices.size() > 5:
		result.append("task %s reflection needs two to five curated choices" % task_id)


static func _validate_profile_text(value: Variant, label: String, result: PackedStringArray) -> void:
	if not value is Dictionary:
		result.append("%s must provide faith and universal text" % label)
		return
	for profile in [PROFILE_FAITH, PROFILE_UNIVERSAL]:
		if str(value.get(profile, "")).strip_edges().is_empty():
			result.append("%s.%s must be non-empty" % [label, profile])


static func _validate_unique_id(value: String, kind: String, ids: Dictionary, result: PackedStringArray) -> void:
	if value.is_empty() or ids.has(value):
		result.append("%s needs a non-empty unique id: %s" % [kind, value])
	ids[value] = true


static func _validate_castle_return(value: Variant, result: PackedStringArray) -> void:
	if not value is Dictionary:
		result.append("castle_return must be a dictionary")
		return
	for field in ["completion_event", "destination", "next_locked_treasure", "summary_choices"]:
		if not value.has(field):
			result.append("castle_return is missing %s" % field)


func is_valid() -> bool:
	return errors.is_empty()


func guardian_name(profile: String) -> String:
	if profile != PROFILE_FAITH and profile != PROFILE_UNIVERSAL:
		return ""
	return str(data.get("profiles", {}).get(profile, {}).get("guardian_name", ""))


func quests() -> Array:
	return data.get("quests", []).duplicate(true)


func quest(quest_id: String) -> Dictionary:
	for item in data.get("quests", []):
		if item is Dictionary and str(item.get("id", "")) == quest_id:
			return item.duplicate(true)
	return {}


func quest_for_runtime_id(runtime_id: String) -> Dictionary:
	for item in data.get("quests", []):
		if not item is Dictionary:
			continue
		if str(item.get("id", "")) == runtime_id or runtime_id in item.get("save_aliases", []):
			return item.duplicate(true)
	return {}


func runtime_contract(quest_id_or_alias: String) -> Dictionary:
	var item := quest_for_runtime_id(quest_id_or_alias)
	if item.is_empty():
		return {}
	return {
		"canonical_id": str(item.get("id", "")),
		"island_id": str(item.get("island_id", "")),
		"district_ids": item.get("district_ids", []).duplicate(),
		"mechanic_id": str(item.get("mechanic_id", "")),
		"object_bindings": item.get("object_bindings", []).duplicate(),
		"prerequisites": item.get("prerequisites", []).duplicate(),
		"hint_ladder": item.get("hint_ladder", []).duplicate(),
		"success_effects": item.get("success_effects", []).duplicate(),
		"environment_state": str(item.get("environment_state", "")),
		"save_aliases": item.get("save_aliases", []).duplicate(),
	}


func localized_dialogue(block: Dictionary, profile: String) -> String:
	if profile != PROFILE_FAITH and profile != PROFILE_UNIVERSAL:
		return ""
	return str(block.get("guardian_dialogue", {}).get(profile, ""))
