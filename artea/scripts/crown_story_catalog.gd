class_name CrownStoryCatalog
extends RefCounted

const DEFAULT_PATH := "res://data/crown_of_life_story.json"
const REQUIRED_ARC_IDS := ["mind", "heart", "creator"]
const REQUIRED_TASK_FIELDS := [
	"id", "title", "mechanic_action", "purpose", "story_reason",
	"prerequisites", "completion_evidence", "optional", "skip_policy", "replay_policy",
]


static func load_catalog(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func validate(catalog: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if catalog.is_empty():
		errors.append("catalog must be a non-empty dictionary")
		return errors
	if int(catalog.get("schema_version", 0)) != 1:
		errors.append("schema_version must be 1")
	_validate_required_dictionary(catalog, "story", "root", errors)
	_validate_required_dictionary(catalog, "safety", "root", errors)
	_validate_segment(catalog.get("prologue", {}), "prologue", errors)
	_validate_segment(catalog.get("finale", {}), "finale", errors)

	var arcs: Variant = catalog.get("kingdom_arcs", [])
	if not arcs is Array:
		errors.append("kingdom_arcs must be an array")
		return errors
	if arcs.size() != 3:
		errors.append("kingdom_arcs must contain exactly 3 arcs")

	var all_task_ids: Array[String] = []
	var all_quest_ids: Array[String] = []
	var ordered_task_ids: Array[String] = []
	for arc_index in arcs.size():
		var arc: Variant = arcs[arc_index]
		if not arc is Dictionary:
			errors.append("kingdom_arcs[%d] must be a dictionary" % arc_index)
			continue
		_validate_arc(arc, arc_index, all_quest_ids, all_task_ids, ordered_task_ids, errors)

	_validate_unique(all_quest_ids, "quest", errors)
	_validate_unique(all_task_ids, "task", errors)
	_validate_dependencies(catalog, ordered_task_ids, errors)
	_validate_audience_parity(catalog, "root", errors)
	_validate_safety(catalog.get("safety", {}), errors)
	return errors


static func is_valid(catalog: Dictionary) -> bool:
	return validate(catalog).is_empty()


static func arc_by_id(catalog: Dictionary, arc_id: String) -> Dictionary:
	for arc in catalog.get("kingdom_arcs", []):
		if arc is Dictionary and str(arc.get("id", "")) == arc_id:
			return arc.duplicate(true)
	return {}


static func task_by_id(catalog: Dictionary, task_id: String) -> Dictionary:
	for arc in catalog.get("kingdom_arcs", []):
		if not arc is Dictionary:
			continue
		for quest in arc.get("quests", []):
			if not quest is Dictionary:
				continue
			for task in quest.get("tasks", []):
				if task is Dictionary and str(task.get("id", "")) == task_id:
					return task.duplicate(true)
	return {}


static func localized_text(authored: Dictionary, audience_mode: String) -> String:
	var mode := "faith" if audience_mode == "faith" else "universal"
	return str(authored.get(mode, ""))


static func _validate_arc(
	arc: Dictionary,
	arc_index: int,
	quest_ids: Array[String],
	task_ids: Array[String],
	ordered_task_ids: Array[String],
	errors: PackedStringArray
) -> void:
	var expected_id: String = str(REQUIRED_ARC_IDS[arc_index]) if arc_index < REQUIRED_ARC_IDS.size() else ""
	if str(arc.get("id", "")) != expected_id:
		errors.append("kingdom_arcs[%d].id must be %s" % [arc_index, expected_id])
	if int(arc.get("order", 0)) != arc_index + 1:
		errors.append("kingdom_arcs[%d].order must be %d" % [arc_index, arc_index + 1])
	for field in ["title", "theme", "purpose", "story_reason", "reward_id", "reward_title"]:
		_validate_non_empty(arc, field, "arc %s" % expected_id, errors)
	if not arc.get("entry_requirements", null) is Array:
		errors.append("arc %s.entry_requirements must be an array" % expected_id)
	var quests: Variant = arc.get("quests", [])
	if not quests is Array or quests.is_empty():
		errors.append("arc %s must contain quests" % expected_id)
		return
	for quest_index in quests.size():
		var quest: Variant = quests[quest_index]
		var context := "arc %s quest[%d]" % [expected_id, quest_index]
		if not quest is Dictionary:
			errors.append("%s must be a dictionary" % context)
			continue
		for field in ["id", "title", "purpose", "story_reason"]:
			_validate_non_empty(quest, field, context, errors)
		var quest_id := str(quest.get("id", ""))
		quest_ids.append(quest_id)
		if int(quest.get("order", 0)) != quest_index + 1:
			errors.append("%s.order must be %d" % [context, quest_index + 1])
		if not quest.get("prerequisites", null) is Array:
			errors.append("%s.prerequisites must be an array" % context)
		var tasks: Variant = quest.get("tasks", [])
		if not tasks is Array or tasks.is_empty():
			errors.append("%s must contain tasks" % context)
			continue
		for task_index in tasks.size():
			var task: Variant = tasks[task_index]
			var task_context := "%s task[%d]" % [context, task_index]
			if not task is Dictionary:
				errors.append("%s must be a dictionary" % task_context)
				continue
			for field in REQUIRED_TASK_FIELDS:
				if not task.has(field):
					errors.append("%s missing %s" % [task_context, field])
			for field in ["id", "title", "mechanic_action", "purpose", "story_reason", "skip_policy", "replay_policy"]:
				_validate_non_empty(task, field, task_context, errors)
			if int(task.get("order", 0)) != task_index + 1:
				errors.append("%s.order must be %d" % [task_context, task_index + 1])
			if not task.get("prerequisites", null) is Array:
				errors.append("%s.prerequisites must be an array" % task_context)
			if not task.get("completion_evidence", null) is Dictionary:
				errors.append("%s.completion_evidence must be a dictionary" % task_context)
			elif str(task["completion_evidence"].get("type", "")).is_empty() or str(task["completion_evidence"].get("event", "")).is_empty():
				errors.append("%s.completion_evidence needs type and event" % task_context)
			if not task.get("optional", null) is bool:
				errors.append("%s.optional must be a boolean" % task_context)
			var task_id := str(task.get("id", ""))
			task_ids.append(task_id)
			ordered_task_ids.append(task_id)


static func _validate_dependencies(catalog: Dictionary, ordered_task_ids: Array[String], errors: PackedStringArray) -> void:
	var event_ids: Array[String] = []
	var prologue: Variant = catalog.get("prologue", {})
	if prologue is Dictionary:
		event_ids.append(str(prologue.get("completion_id", "")))
	for arc in catalog.get("kingdom_arcs", []):
		if arc is Dictionary:
			event_ids.append(str(arc.get("reward_id", "")))
	var interludes: Variant = catalog.get("castle_interludes", [])
	if not interludes is Array or interludes.size() != 3:
		errors.append("castle_interludes must contain exactly 3 ordered returns")
	else:
		for index in interludes.size():
			var segment: Variant = interludes[index]
			if not segment is Dictionary:
				errors.append("castle_interludes[%d] must be a dictionary" % index)
				continue
			_validate_segment(segment, "castle_interludes[%d]" % index, errors)
			if int(segment.get("order", 0)) != index + 1:
				errors.append("castle_interludes[%d].order must be %d" % [index, index + 1])
			event_ids.append(str(segment.get("completion_id", "")))
	var allowed: Array[String] = ordered_task_ids.duplicate()
	allowed.append_array(event_ids)
	for arc in catalog.get("kingdom_arcs", []):
		if not arc is Dictionary:
			continue
		_validate_reference_array(arc.get("entry_requirements", []), allowed, "arc %s entry" % arc.get("id", ""), errors)
		for quest in arc.get("quests", []):
			if not quest is Dictionary:
				continue
			_validate_reference_array(quest.get("prerequisites", []), allowed, "quest %s" % quest.get("id", ""), errors)
			for task in quest.get("tasks", []):
				if not task is Dictionary:
					continue
				var task_id := str(task.get("id", ""))
				_validate_reference_array(task.get("prerequisites", []), allowed, "task %s" % task_id, errors)
				for dependency in task.get("prerequisites", []):
					var dependency_id := str(dependency)
					if ordered_task_ids.has(dependency_id) and ordered_task_ids.find(dependency_id) >= ordered_task_ids.find(task_id):
						errors.append("task %s dependency %s must appear earlier" % [task_id, dependency_id])
	for interlude in interludes if interludes is Array else []:
		if interlude is Dictionary:
			_validate_reference_array(interlude.get("requirements", []), allowed, "interlude %s" % interlude.get("id", ""), errors)
	var finale: Variant = catalog.get("finale", {})
	if finale is Dictionary:
		_validate_reference_array(finale.get("requirements", []), allowed, "finale", errors)


static func _validate_reference_array(value: Variant, allowed: Array[String], context: String, errors: PackedStringArray) -> void:
	if not value is Array:
		errors.append("%s prerequisites/requirements must be an array" % context)
		return
	for reference in value:
		if not allowed.has(str(reference)):
			errors.append("%s has unknown dependency %s" % [context, reference])


static func _validate_segment(segment: Variant, context: String, errors: PackedStringArray) -> void:
	if not segment is Dictionary:
		errors.append("%s must be a dictionary" % context)
		return
	for field in ["id", "completion_id", "title", "purpose", "story_reason"]:
		_validate_non_empty(segment, field, context, errors)


static func _validate_audience_parity(value: Variant, path: String, errors: PackedStringArray) -> void:
	if value is Dictionary:
		var has_faith: bool = value.has("faith")
		var has_universal: bool = value.has("universal")
		if has_faith or has_universal:
			if not has_faith or str(value.get("faith", "")).strip_edges().is_empty():
				errors.append("%s must include non-empty faith text" % path)
			if not has_universal or str(value.get("universal", "")).strip_edges().is_empty():
				errors.append("%s must include non-empty universal text" % path)
		for key in value:
			_validate_audience_parity(value[key], "%s.%s" % [path, key], errors)
	elif value is Array:
		for index in value.size():
			_validate_audience_parity(value[index], "%s[%d]" % [path, index], errors)


static func _validate_safety(safety: Variant, errors: PackedStringArray) -> void:
	if not safety is Dictionary:
		return
	if str(safety.get("mode", "")) != "curated_offline":
		errors.append("safety.mode must be curated_offline")
	var joined := " ".join(PackedStringArray(safety.get("principles", []))).to_lower()
	for required_phrase in ["never diagnose", "never require personal disclosure", "skip"]:
		if not joined.contains(required_phrase):
			errors.append("safety principles must state %s" % required_phrase)


static func _validate_required_dictionary(container: Dictionary, field: String, context: String, errors: PackedStringArray) -> void:
	if not container.get(field, null) is Dictionary:
		errors.append("%s.%s must be a dictionary" % [context, field])


static func _validate_non_empty(container: Dictionary, field: String, context: String, errors: PackedStringArray) -> void:
	if str(container.get(field, "")).strip_edges().is_empty():
		errors.append("%s.%s must be non-empty" % [context, field])


static func _validate_unique(ids: Array[String], kind: String, errors: PackedStringArray) -> void:
	var seen := {}
	for item_id in ids:
		if item_id.is_empty():
			continue
		if seen.has(item_id):
			errors.append("duplicate %s id: %s" % [kind, item_id])
		seen[item_id] = true
