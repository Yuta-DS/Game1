class_name QuestObjectStateStore
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_PATH := "user://mind_spark_quest_objects.json"

var save_path := DEFAULT_PATH


func _init(custom_path := DEFAULT_PATH) -> void:
	save_path = custom_path


func load_object(save_id: String) -> Dictionary:
	if save_id.is_empty() or not FileAccess.file_exists(save_path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != SCHEMA_VERSION:
		return {}
	var objects: Variant = parsed.get("objects", {})
	if not objects is Dictionary or not objects.has(save_id):
		return {}
	var state: Variant = objects[save_id]
	return state.duplicate(true) if state is Dictionary else {}


func save_object(save_id: String, state: Dictionary) -> bool:
	if save_id.strip_edges().is_empty():
		return false
	var document := {"schema_version": SCHEMA_VERSION, "objects": {}}
	if FileAccess.file_exists(save_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if parsed is Dictionary and int(parsed.get("schema_version", 0)) == SCHEMA_VERSION \
				and parsed.get("objects", null) is Dictionary:
			document = parsed
	(document["objects"] as Dictionary)[save_id] = state.duplicate(true)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(document))
	file.close()
	return true


func clear() -> bool:
	if not FileAccess.file_exists(save_path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path)) == OK

