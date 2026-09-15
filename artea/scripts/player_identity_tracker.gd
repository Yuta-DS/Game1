extends Node

## Private, non-scoring identity evidence. Only the first explicit answer for
## an evidence ID is kept. Skip/private choices deliberately write nothing.

signal evidence_recorded(evidence_id: String, axis: String, choice: String)
signal identity_previewed(code: String, friendly_name: String)
signal identity_finalized(code: String, friendly_name: String)
signal reveal_state_changed(seen: bool)

const SAVE_PATH := "user://player_identity_evidence.json"
const AXES := ["energy", "information", "decisions", "structure"]
const AXIS_SIDES := {
	"energy": ["E", "I"], "information": ["S", "N"],
	"decisions": ["T", "F"], "structure": ["J", "P"],
}
const FRIENDLY_NAMES := {
	"ENFJ": "The Guiding Light", "INFJ": "The Quiet Visionary",
	"ENFP": "The Joyful Creator", "INFP": "The Gentle Peacemaker",
	"ENTJ": "The Bold Architect", "INTJ": "The Wise Strategist",
	"ENTP": "The Bright Spark", "INTP": "The Deep Thinker",
	"ESFJ": "The Warm Guardian", "ISFJ": "The Faithful Shield",
	"ESFP": "The Radiant Star", "ISFP": "The Silent Artist",
	"ESTJ": "The Steadfast Builder", "ISTJ": "The Loyal Keeper",
	"ESTP": "The Fearless Explorer", "ISTP": "The Calm Craftsman",
}

var save_path := SAVE_PATH
var evidence: Dictionary = {}
var identity_axis_counts := {"E": 0, "I": 0, "S": 0, "N": 0, "T": 0, "F": 0, "J": 0, "P": 0}
var identity_evidence_ids := PackedStringArray()
var identity_answer_history: Array[Dictionary] = []
var identity_result_code := ""
var identity_locked := false
var identity_reveal_seen := false


func _ready() -> void:
	load_evidence()


func record_evidence(evidence_id: String, axis: String, choice: String,
		world_id := "mind_spark", context: Dictionary = {}) -> bool:
	if world_id not in ["mind_spark", "heart_melody", "creators_light"]:
		return false
	if evidence_id.strip_edges().is_empty() or axis not in AXES or choice.strip_edges().is_empty():
		return false
	if evidence.has(evidence_id):
		return true
	if identity_locked:
		return false
	var side := _normalized_side(axis, choice)
	if side.is_empty():
		return false
	var record := {"axis": axis, "choice": choice, "side": side, "world_id": world_id}
	for field in ["canonical_quest_id", "save_alias", "task_id", "source"]:
		var value := str(context.get(field, "")).strip_edges()
		if not value.is_empty():
			record[field] = value
	evidence[evidence_id] = record
	identity_axis_counts[side] = int(identity_axis_counts.get(side, 0)) + 1
	identity_evidence_ids.append(evidence_id)
	var history_record := record.duplicate(true)
	history_record["evidence_id"] = evidence_id
	identity_answer_history.append(history_record)
	if not save():
		evidence.erase(evidence_id)
		identity_axis_counts[side] = maxi(0, int(identity_axis_counts[side]) - 1)
		identity_evidence_ids.erase(evidence_id)
		identity_answer_history.pop_back()
		return false
	evidence_recorded.emit(evidence_id, axis, choice)
	return true


func has_evidence(evidence_id: String) -> bool:
	return evidence.has(evidence_id)


func evidence_for_world(world_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in identity_answer_history:
		if str(item.get("world_id", "")) == world_id:
			result.append(item.duplicate(true))
	return result


func evidence_for_quest(canonical_quest_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in identity_answer_history:
		if str(item.get("canonical_quest_id", "")) == canonical_quest_id:
			result.append(item.duplicate(true))
	return result


func has_complete_axis_evidence() -> bool:
	for axis in AXES:
		var sides: Array = AXIS_SIDES[axis]
		if int(identity_axis_counts[sides[0]]) + int(identity_axis_counts[sides[1]]) <= 0:
			return false
	return true


func load_evidence() -> void:
	evidence.clear()
	_reset_summary()
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary and parsed.get("evidence", null) is Dictionary:
		evidence = (parsed["evidence"] as Dictionary).duplicate(true)
		var loaded_counts: Variant = parsed.get("identity_axis_counts", {})
		if loaded_counts is Dictionary:
			for side in identity_axis_counts:
				identity_axis_counts[side] = int(loaded_counts.get(side, 0))
		var loaded_ids: Variant = parsed.get("identity_evidence_ids", [])
		if loaded_ids is Array:
			identity_evidence_ids = PackedStringArray(loaded_ids)
		var loaded_history: Variant = parsed.get("identity_answer_history", [])
		if loaded_history is Array:
			for item in loaded_history:
				if item is Dictionary: identity_answer_history.append(item.duplicate(true))
		identity_result_code = str(parsed.get("identity_result_code", ""))
		identity_locked = bool(parsed.get("identity_locked", false))
		identity_reveal_seen = bool(parsed.get("identity_reveal_seen", false))
		if identity_evidence_ids.is_empty() and not evidence.is_empty():
			_rebuild_summary_from_evidence()


func save() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"schema_version": 3,
		"evidence": evidence,
		"identity_axis_counts": identity_axis_counts,
		"identity_evidence_ids": Array(identity_evidence_ids),
		"identity_answer_history": identity_answer_history,
		"identity_result_code": identity_result_code,
		"identity_locked": identity_locked,
		"identity_reveal_seen": identity_reveal_seen,
	}))
	file.close()
	return true


func clear_evidence() -> void:
	evidence.clear()
	_reset_summary()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func preview_identity() -> String:
	if not identity_result_code.is_empty():
		return identity_result_code
	if not has_complete_axis_evidence():
		return ""
	var code := _preferred_side("E", "I") + _preferred_side("S", "N") \
		+ _preferred_side("T", "F") + _preferred_side("J", "P")
	identity_previewed.emit(code, friendly_identity_name(code))
	return code


func finalize_identity() -> String:
	if identity_locked and not identity_result_code.is_empty():
		return identity_result_code
	var preview := preview_identity()
	if preview.is_empty():
		return ""
	identity_result_code = preview
	identity_locked = true
	save()
	identity_finalized.emit(identity_result_code, friendly_identity_name(identity_result_code))
	return identity_result_code


func friendly_identity_name(code := "") -> String:
	var resolved := identity_result_code if code.is_empty() else code
	return str(FRIENDLY_NAMES.get(resolved, ""))


func mark_reveal_seen() -> void:
	identity_reveal_seen = true
	save()
	reveal_state_changed.emit(true)


func _normalized_side(axis: String, choice: String) -> String:
	if not AXIS_SIDES.has(axis):
		return ""
	var value := choice.strip_edges().to_upper()
	if value in AXIS_SIDES[axis]:
		return value
	var legacy := {"OUTWARD": "E", "INWARD": "I", "DETAIL": "S", "PATTERN": "N",
		"REASON": "T", "CARE": "F", "PLAN": "J", "EXPLORE": "P"}
	var mapped := str(legacy.get(value, ""))
	return mapped if mapped in AXIS_SIDES[axis] else ""


func _preferred_side(first: String, second: String) -> String:
	# Ties intentionally resolve to the first side only at the Art Castle finale;
	# no result is created or shown during Mind Spark.
	return first if int(identity_axis_counts[first]) >= int(identity_axis_counts[second]) else second


func _reset_summary() -> void:
	identity_axis_counts = {"E": 0, "I": 0, "S": 0, "N": 0, "T": 0, "F": 0, "J": 0, "P": 0}
	identity_evidence_ids = PackedStringArray()
	identity_answer_history.clear()
	identity_result_code = ""
	identity_locked = false
	identity_reveal_seen = false


func _rebuild_summary_from_evidence() -> void:
	for evidence_id in evidence:
		var item: Dictionary = evidence[evidence_id]
		var side := _normalized_side(str(item.get("axis", "")), str(item.get("choice", "")))
		if side.is_empty():
			continue
		identity_axis_counts[side] = int(identity_axis_counts[side]) + 1
		identity_evidence_ids.append(str(evidence_id))
		var history_record := item.duplicate(true)
		history_record["evidence_id"] = str(evidence_id)
		history_record["side"] = side
		history_record["world_id"] = str(item.get("world_id", "mind_spark"))
		identity_answer_history.append(history_record)
