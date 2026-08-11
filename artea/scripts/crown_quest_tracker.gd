class_name CrownQuestTracker
extends RefCounted

const CatalogScript = preload("res://scripts/crown_story_catalog.gd")
const SNAPSHOT_VERSION := 1

var catalog: Dictionary = {}
var catalog_errors := PackedStringArray()
var completed_tasks: Dictionary = {}
var completed_milestones: Dictionary = {}


func _init(source_catalog: Dictionary = {}) -> void:
	catalog = source_catalog.duplicate(true) if not source_catalog.is_empty() else CatalogScript.load_catalog()
	catalog_errors = CatalogScript.validate(catalog)


func is_catalog_valid() -> bool:
	return catalog_errors.is_empty()


# Accepts only authored evidence or story milestone IDs. The payload is matched
# against any extra keys in completion_evidence (for example treasure value).
# It is never retained, keeping progress free of personal content.
func submit_evidence(event_id: String, payload: Dictionary = {}) -> Dictionary:
	if not is_catalog_valid():
		return _result(false, "invalid_catalog")
	if event_id.is_empty():
		return _result(false, "unknown_event")

	var milestone := _milestone_by_completion_id(event_id)
	if not milestone.is_empty():
		return _complete_milestone(event_id, milestone)

	var authored_matches: Array[Dictionary] = []
	for task in _all_tasks():
		var evidence: Dictionary = task.get("completion_evidence", {})
		if str(evidence.get("event", "")) == event_id and _payload_matches(evidence, payload):
			authored_matches.append(task)
	if authored_matches.is_empty():
		return _result(false, "unknown_event")

	for task in authored_matches:
		var task_id := str(task["id"])
		if completed_tasks.has(task_id):
			return _result(true, "already_complete", [task_id])
		if _requirements_met(task.get("prerequisites", [])):
			completed_tasks[task_id] = true
			_award_authored_reward(task_id)
			return _result(true, "completed", [task_id])
	return _result(false, "prerequisites_not_met")


func is_task_complete(task_id: String) -> bool:
	return completed_tasks.has(task_id)


func is_quest_ready(quest_id: String) -> bool:
	var quest := _quest_by_id(quest_id)
	return not quest.is_empty() and _requirements_met(quest.get("prerequisites", []))


func is_quest_complete(quest_id: String) -> bool:
	var quest := _quest_by_id(quest_id)
	if quest.is_empty():
		return false
	for task in quest.get("tasks", []):
		if not task is Dictionary or not is_task_complete(str(task.get("id", ""))):
			return false
	return true


func is_arc_ready(arc_id: String) -> bool:
	var arc := CatalogScript.arc_by_id(catalog, arc_id)
	return not arc.is_empty() and _requirements_met(arc.get("entry_requirements", []))


func is_arc_complete(arc_id: String) -> bool:
	var arc := CatalogScript.arc_by_id(catalog, arc_id)
	return not arc.is_empty() and completed_milestones.has(str(arc.get("reward_id", "")))


func is_finale_ready() -> bool:
	var finale: Variant = catalog.get("finale", {})
	return finale is Dictionary and _requirements_met(finale.get("requirements", []))


func is_finale_complete() -> bool:
	var finale: Dictionary = catalog.get("finale", {})
	return completed_milestones.has(str(finale.get("completion_id", "")))


# Returns authored objective data only. It contains no player response.
func current_objective() -> Dictionary:
	if not is_catalog_valid():
		return {"kind": "error", "reason": "invalid_catalog"}
	var prologue: Dictionary = catalog.get("prologue", {})
	if not completed_milestones.has(str(prologue.get("completion_id", ""))):
		return _segment_objective("prologue", prologue)

	var interludes: Array = catalog.get("castle_interludes", [])
	for arc_index in catalog.get("kingdom_arcs", []).size():
		var arc: Dictionary = catalog["kingdom_arcs"][arc_index]
		if is_arc_ready(str(arc["id"])) and not is_arc_complete(str(arc["id"])):
			for quest in arc.get("quests", []):
				if not quest is Dictionary or not is_quest_ready(str(quest.get("id", ""))):
					continue
				for task in quest.get("tasks", []):
					if task is Dictionary and not is_task_complete(str(task.get("id", ""))) and _requirements_met(task.get("prerequisites", [])):
						var objective: Dictionary = task.duplicate(true)
						objective["kind"] = "task"
						objective["arc_id"] = arc["id"]
						objective["quest_id"] = quest["id"]
						return objective
		if arc_index < interludes.size():
			var interlude: Variant = interludes[arc_index]
			if interlude is Dictionary:
				var completion_id := str(interlude.get("completion_id", ""))
				if not completed_milestones.has(completion_id) and _requirements_met(interlude.get("requirements", [])):
					return _segment_objective("interlude", interlude)

	var finale: Dictionary = catalog.get("finale", {})
	if is_finale_ready() and not is_finale_complete():
		return _segment_objective("finale", finale)
	if is_finale_complete():
		return {"kind": "complete", "id": str(finale.get("completion_id", "")), "title": "Journey complete"}
	return {"kind": "locked", "reason": "no_satisfied_objective"}


func localized_objective(audience_mode: String) -> Dictionary:
	var objective := current_objective()
	var presentation := {
		"kind": objective.get("kind", "locked"),
		"id": objective.get("id", ""),
		"title": objective.get("title", ""),
		"purpose": objective.get("purpose", ""),
		"story_reason": objective.get("story_reason", ""),
	}
	if objective.has("mechanic_action"):
		presentation["mechanic_action"] = objective["mechanic_action"]
	if objective.get("dialogue", null) is Dictionary:
		var dialogue: Dictionary = objective["dialogue"]
		presentation["speaker"] = dialogue.get("speaker", "")
		presentation["dialogue"] = CatalogScript.localized_text(dialogue, audience_mode)
	return presentation


# Snapshot values are IDs and booleans only. There is deliberately no file I/O.
func export_snapshot() -> Dictionary:
	var task_ids := PackedStringArray(completed_tasks.keys())
	var milestone_ids := PackedStringArray(completed_milestones.keys())
	task_ids.sort()
	milestone_ids.sort()
	return {
		"version": SNAPSHOT_VERSION,
		"story_id": str(catalog.get("story", {}).get("id", "")),
		"completed_task_ids": Array(task_ids),
		"completed_milestone_ids": Array(milestone_ids),
	}


func import_snapshot(snapshot: Dictionary) -> bool:
	if not is_catalog_valid() or int(snapshot.get("version", 0)) != SNAPSHOT_VERSION:
		return false
	if str(snapshot.get("story_id", "")) != str(catalog.get("story", {}).get("id", "")):
		return false
	var task_ids: Variant = snapshot.get("completed_task_ids", null)
	var milestone_ids: Variant = snapshot.get("completed_milestone_ids", null)
	if not task_ids is Array or not milestone_ids is Array:
		return false
	var candidate_tasks := {}
	var candidate_milestones := {}
	var known_task_ids := PackedStringArray()
	for task in _all_tasks():
		known_task_ids.append(str(task["id"]))
	var known_milestone_ids := _known_milestone_ids()
	for value in task_ids:
		if not value is String or not known_task_ids.has(value) or candidate_tasks.has(value):
			return false
		candidate_tasks[value] = true
	for value in milestone_ids:
		if not value is String or not known_milestone_ids.has(value) or candidate_milestones.has(value):
			return false
		candidate_milestones[value] = true

	# Validate in authored order using temporary state. A snapshot cannot claim a
	# downstream completion without every prerequisite milestone/task.
	var previous_tasks := completed_tasks
	var previous_milestones := completed_milestones
	completed_tasks = {}
	completed_milestones = {}
	var valid := _rebuild_snapshot(candidate_tasks, candidate_milestones)
	if not valid:
		completed_tasks = previous_tasks
		completed_milestones = previous_milestones
	return valid


func reset() -> void:
	completed_tasks.clear()
	completed_milestones.clear()


func _rebuild_snapshot(candidate_tasks: Dictionary, candidate_milestones: Dictionary) -> bool:
	var prologue_id := str(catalog.get("prologue", {}).get("completion_id", ""))
	if candidate_milestones.has(prologue_id):
		completed_milestones[prologue_id] = true
	for arc_index in catalog.get("kingdom_arcs", []).size():
		var arc: Dictionary = catalog["kingdom_arcs"][arc_index]
		for quest in arc.get("quests", []):
			for task in quest.get("tasks", []):
				var task_id := str(task.get("id", ""))
				if candidate_tasks.has(task_id):
					if not _requirements_met(task.get("prerequisites", [])):
						return false
					completed_tasks[task_id] = true
		var reward_id := str(arc.get("reward_id", ""))
		var reward_task_complete := _arc_reward_task_complete(arc)
		# Runtime awards these atomically. Reject snapshots that separate the
		# receive task from its treasure and could otherwise create a stuck path.
		if candidate_milestones.has(reward_id) != reward_task_complete:
			return false
		if reward_task_complete:
			completed_milestones[reward_id] = true
		var interlude: Dictionary = catalog.get("castle_interludes", [])[arc_index]
		var interlude_id := str(interlude.get("completion_id", ""))
		if candidate_milestones.has(interlude_id):
			if not _requirements_met(interlude.get("requirements", [])):
				return false
			completed_milestones[interlude_id] = true
	var finale: Dictionary = catalog.get("finale", {})
	var finale_id := str(finale.get("completion_id", ""))
	if candidate_milestones.has(finale_id):
		if not is_finale_ready():
			return false
		completed_milestones[finale_id] = true
	return completed_tasks.size() == candidate_tasks.size() and completed_milestones.size() == candidate_milestones.size()


func _complete_milestone(completion_id: String, segment: Dictionary) -> Dictionary:
	if completed_milestones.has(completion_id):
		return _result(true, "already_complete", [], [completion_id])
	if not _requirements_met(segment.get("requirements", segment.get("entry_requirements", []))):
		return _result(false, "prerequisites_not_met")
	completed_milestones[completion_id] = true
	return _result(true, "completed", [], [completion_id])


func _award_authored_reward(task_id: String) -> void:
	for arc in catalog.get("kingdom_arcs", []):
		if arc is Dictionary and _arc_reward_task_id(arc) == task_id:
			completed_milestones[str(arc.get("reward_id", ""))] = true


func _arc_reward_task_id(arc: Dictionary) -> String:
	var reward_id := str(arc.get("reward_id", "")).trim_prefix("treasure.")
	for quest in arc.get("quests", []):
		for task in quest.get("tasks", []):
			if task is Dictionary:
				var evidence: Dictionary = task.get("completion_evidence", {})
				if str(evidence.get("event", "")) == "treasure_awarded" and str(evidence.get("value", "")) == reward_id:
					return str(task.get("id", ""))
	return ""


func _arc_reward_task_complete(arc: Dictionary) -> bool:
	return completed_tasks.has(_arc_reward_task_id(arc))


func _payload_matches(evidence: Dictionary, payload: Dictionary) -> bool:
	for key in evidence:
		if key in ["type", "event"]:
			continue
		if not payload.has(key) or payload[key] != evidence[key]:
			return false
	return true


func _requirements_met(requirements: Variant) -> bool:
	if not requirements is Array:
		return false
	for requirement in requirements:
		var requirement_id := str(requirement)
		if not completed_tasks.has(requirement_id) and not completed_milestones.has(requirement_id):
			return false
	return true


func _milestone_by_completion_id(completion_id: String) -> Dictionary:
	var prologue: Dictionary = catalog.get("prologue", {})
	if str(prologue.get("completion_id", "")) == completion_id:
		return prologue
	for interlude in catalog.get("castle_interludes", []):
		if interlude is Dictionary and str(interlude.get("completion_id", "")) == completion_id:
			return interlude
	var finale: Dictionary = catalog.get("finale", {})
	return finale if str(finale.get("completion_id", "")) == completion_id else {}


func _known_milestone_ids() -> PackedStringArray:
	var ids := PackedStringArray([str(catalog.get("prologue", {}).get("completion_id", ""))])
	for arc in catalog.get("kingdom_arcs", []):
		if arc is Dictionary:
			ids.append(str(arc.get("reward_id", "")))
	for interlude in catalog.get("castle_interludes", []):
		if interlude is Dictionary:
			ids.append(str(interlude.get("completion_id", "")))
	ids.append(str(catalog.get("finale", {}).get("completion_id", "")))
	return ids


func _all_tasks() -> Array[Dictionary]:
	var tasks: Array[Dictionary] = []
	for arc in catalog.get("kingdom_arcs", []):
		if not arc is Dictionary:
			continue
		for quest in arc.get("quests", []):
			if not quest is Dictionary:
				continue
			for task in quest.get("tasks", []):
				if task is Dictionary:
					tasks.append(task)
	return tasks


func _quest_by_id(quest_id: String) -> Dictionary:
	for arc in catalog.get("kingdom_arcs", []):
		if not arc is Dictionary:
			continue
		for quest in arc.get("quests", []):
			if quest is Dictionary and str(quest.get("id", "")) == quest_id:
				return quest
	return {}


func _segment_objective(kind: String, segment: Dictionary) -> Dictionary:
	var objective: Dictionary = segment.duplicate(true)
	objective["kind"] = kind
	return objective


func _result(accepted: bool, reason: String, task_ids: Array = [], milestone_ids: Array = []) -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"completed_task_ids": task_ids.duplicate(),
		"completed_milestone_ids": milestone_ids.duplicate(),
	}
