class_name MindSparkCheckpointStore
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://mind_spark_checkpoint.json"
const ALLOWED_PHASES := ["active", "between_encounters", "completion_ready"]
const ALLOWED_CONTROLLERS := ["player_1", "player_2", "solo_player", "solo_companion"]
const ALLOWED_LENSES := ["alarm", "hope"]

var save_path := DEFAULT_PATH


func _init(custom_path := DEFAULT_PATH) -> void:
	save_path = custom_path


func snapshot(director) -> Dictionary:
	if director == null or str(director.phase) not in ALLOWED_PHASES:
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"phase": str(director.phase),
		"encounter_index": int(director.current_encounter_index),
		"step_index": int(director.current_step_index),
		"completed_encounter_ids": director.completed_encounter_ids.keys(),
		"alarm_controller": str(director.alarm_controller),
		"hope_controller": str(director.hope_controller),
		"solo_mode": bool(director.solo_mode),
		"solo_human_lens": str(director.solo_human_lens),
		"receipt_ids": (director.get("_receipts") as Dictionary).keys(),
	}


func validate_snapshot(data: Variant, director) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary or director == null:
		return PackedStringArray(["checkpoint must be a dictionary with a director"])
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		errors.append("unsupported schema version")
	var phase := str(data.get("phase", ""))
	if phase not in ALLOWED_PHASES:
		errors.append("checkpoint phase cannot fabricate completion or skip")
	var encounters: Array = director.catalog.get("encounters", [])
	var encounter_index := int(data.get("encounter_index", -1))
	if encounter_index < 0 or encounter_index >= encounters.size():
		errors.append("encounter index is out of bounds")
	else:
		var step_count: int = encounters[encounter_index].get("steps", []).size()
		var step_index := int(data.get("step_index", -1))
		var maximum := step_count if phase in ["between_encounters", "completion_ready"] else step_count - 1
		if step_index < 0 or step_index > maximum:
			errors.append("step index is out of bounds")
	for field in ["alarm_controller", "hope_controller"]:
		if str(data.get(field, "")) not in ALLOWED_CONTROLLERS:
			errors.append("%s is invalid" % field)
	if str(data.get("solo_human_lens", "")) not in ALLOWED_LENSES:
		errors.append("solo human lens is invalid")
	var known_ids := {}
	for encounter in encounters:
		known_ids[str(encounter.get("id", ""))] = true
	_validate_string_ids(data.get("completed_encounter_ids", null), known_ids, "completed encounter", errors)
	_validate_string_ids(data.get("receipt_ids", null), {}, "receipt", errors, false)
	if not data.get("solo_mode", null) is bool:
		errors.append("solo_mode must be a bool")
	return errors


func save(director) -> bool:
	var data := snapshot(director)
	if data.is_empty() or not validate_snapshot(data, director).is_empty():
		return false
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true


func load_into(director) -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not validate_snapshot(parsed, director).is_empty():
		return false
	var data := parsed as Dictionary
	director.phase = str(data["phase"])
	director.current_encounter_index = int(data["encounter_index"])
	director.current_step_index = int(data["step_index"])
	director.completed_encounter_ids.clear()
	for encounter_id in data["completed_encounter_ids"]:
		director.completed_encounter_ids[str(encounter_id)] = true
	director.alarm_controller = str(data["alarm_controller"])
	director.hope_controller = str(data["hope_controller"])
	director.solo_mode = bool(data["solo_mode"])
	director.solo_human_lens = str(data["solo_human_lens"])
	var receipts := {}
	for receipt_id in data["receipt_ids"]:
		receipts[str(receipt_id)] = true
	director.set("_receipts", receipts)
	return true


func clear() -> bool:
	if not FileAccess.file_exists(save_path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path)) == OK


func _validate_string_ids(value: Variant, known: Dictionary, label: String,
		errors: PackedStringArray, require_known := true) -> void:
	if not value is Array:
		errors.append("%s ids must be an array" % label)
		return
	var seen := {}
	for item in value:
		var id := str(item)
		if id.is_empty() or seen.has(id) or (require_known and not known.has(id)):
			errors.append("invalid %s id" % label)
		seen[id] = true
