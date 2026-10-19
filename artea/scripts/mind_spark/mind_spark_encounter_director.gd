class_name MindSparkEncounterDirector
extends RefCounted

signal phase_changed(phase_id: String)
signal encounter_started(encounter_id: String, index: int)
signal evidence_emitted(event_id: String, payload: Dictionary)
signal action_rejected(action_id: String, reason: String)
signal step_started(encounter_id: String, step_id: String, index: int)
signal step_feedback(action_id: String, accepted: bool, reason: String)
signal step_revised(encounter_id: String, step_id: String, reason: String)
signal step_completed(encounter_id: String, step_id: String, index: int)
signal chapter_completed(treasure_id: String)
signal environment_state_requested(state_id: String, payload: Dictionary)
signal roles_swapped(alarm_controller: String, hope_controller: String)
signal companion_ping_completed(action_id: String, accepted: bool, reason: String)
signal completion_requested(treasure_id: String)

const DEFAULT_CATALOG_PATH := "res://data/mind_spark_encounters.json"
const LENS_ALARM := "alarm"
const LENS_HOPE := "hope"
const PHASE_READY := "ready"
const PHASE_ACTIVE := "active"
const PHASE_BETWEEN := "between_encounters"
const PHASE_COMPLETION_READY := "completion_ready"
const PHASE_COMPLETE := "complete"
const PHASE_SKIPPED := "skipped"
const QUEST_ENVIRONMENT_STATES := {
	"quest.signal_observatory": "signal_prism_formed",
	"quest.echo_forest": "echo_seed_secured",
	"quest.cross_seam_relay": "archive_open",
	"quest.role_exchange_storm": "guardian_freed",
	"quest.constellation_synthesis": "star_of_wisdom_awarded",
}

var catalog: Dictionary = {}
var catalog_errors := PackedStringArray()
var phase := PHASE_READY
var current_encounter_index := 0
var current_step_index := 0
var completed_encounter_ids: Dictionary = {}
var alarm_controller := "player_1"
var hope_controller := "player_2"
var solo_mode := false
var solo_human_lens := LENS_ALARM
var completion_was_requested := false
var _receipts: Dictionary = {}
var _companion_ping_in_progress := false


func _init(source_catalog: Dictionary = {}) -> void:
	catalog = source_catalog.duplicate(true) if not source_catalog.is_empty() else load_catalog()
	catalog_errors = validate_catalog(catalog)


static func load_catalog(path: String = DEFAULT_CATALOG_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func validate_catalog(source: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if source.is_empty():
		return PackedStringArray(["catalog must be a non-empty dictionary"])
	if int(source.get("schema_version", 0)) != 1:
		errors.append("schema_version must be 1")
	if str(source.get("reward_request", "")) != "star_of_wisdom":
		errors.append("reward_request must be star_of_wisdom")
	if str(source.get("safety", {}).get("mode", "")) != "curated_offline":
		errors.append("safety.mode must be curated_offline")
	if str(source.get("safety", {}).get("skip_policy", "")) != "end_without_evidence_or_reward":
		errors.append("skip policy must forbid evidence and rewards")
	var encounters: Variant = source.get("encounters", null)
	if not encounters is Array or encounters.size() != 5:
		errors.append("encounters must contain exactly five quests")
		return errors
	var ids := {}
	var action_ids := {}
	var expected_ids := ["quest.signal_observatory", "quest.echo_forest", "quest.cross_seam_relay", "quest.role_exchange_storm", "quest.constellation_synthesis"]
	for index in encounters.size():
		var encounter: Variant = encounters[index]
		if not encounter is Dictionary:
			errors.append("encounters[%d] must be a dictionary" % index)
			continue
		var encounter_id := str(encounter.get("id", ""))
		if encounter_id != expected_ids[index] or ids.has(encounter_id):
			errors.append("encounter %d has an invalid or duplicate id" % index)
		ids[encounter_id] = true
		if int(encounter.get("order", 0)) != index + 1:
			errors.append("%s has invalid order" % encounter_id)
		for required_field in ["title", "purpose", "alarm_information", "hope_information", "shared_consequence"]:
			if str(encounter.get(required_field, "")).strip_edges().is_empty():
				errors.append("%s needs %s" % [encounter_id, required_field])
		var steps: Variant = encounter.get("steps", null)
		if not steps is Array or steps.size() < 4:
			errors.append("%s needs at least four ordered steps" % encounter_id)
			continue
		var has_alarm := false
		var has_hope := false
		var has_swap := false
		for step in steps:
			if not step is Dictionary:
				errors.append("%s has an invalid step" % encounter_id)
				continue
			var action_id := str(step.get("id", ""))
			var actor := str(step.get("actor", ""))
			if action_id.is_empty() or action_ids.has(action_id):
				errors.append("%s has an invalid or duplicate action id" % encounter_id)
			action_ids[action_id] = true
			if str(step.get("verb", "")).is_empty() or str(step.get("instruction", "")).is_empty():
				errors.append("%s action %s needs an authored verb and instruction" % [encounter_id, action_id])
			has_alarm = has_alarm or actor == LENS_ALARM
			has_hope = has_hope or actor == LENS_HOPE
			has_swap = has_swap or actor == "role_swap"
			if actor not in [LENS_ALARM, LENS_HOPE, "role_swap"]:
				errors.append("%s action %s has an unknown actor" % [encounter_id, action_id])
		if not has_alarm or not has_hope:
			errors.append("%s must require complementary Alarm and Hope actions" % encounter_id)
		if bool(encounter.get("requires_role_swap", false)) != has_swap:
			errors.append("%s role-swap declaration does not match its steps" % encounter_id)
	return errors


func is_valid() -> bool:
	return catalog_errors.is_empty()


func current_encounter() -> Dictionary:
	var encounters: Array = catalog.get("encounters", [])
	if current_encounter_index < 0 or current_encounter_index >= encounters.size():
		return {}
	return encounters[current_encounter_index].duplicate(true)


func current_step() -> Dictionary:
	var steps: Array = current_encounter().get("steps", [])
	return steps[current_step_index].duplicate(true) if current_step_index >= 0 and current_step_index < steps.size() else {}


func configure_solo(enabled: bool, human_lens: String = LENS_ALARM) -> Dictionary:
	if phase != PHASE_READY:
		return _reject("configure_solo", "configuration_locked")
	if human_lens not in [LENS_ALARM, LENS_HOPE]:
		return _reject("configure_solo", "unknown_lens")
	solo_mode = enabled
	solo_human_lens = human_lens
	_update_controllers()
	return _result(true, "configured")


func start_current_encounter() -> Dictionary:
	if phase != PHASE_READY:
		return _reject("start_current_encounter", "out_of_order")
	if not is_valid():
		return _reject("start_current_encounter", "invalid_catalog")
	_set_phase(PHASE_ACTIVE)
	var encounter_id := str(current_encounter().get("id", ""))
	encounter_started.emit(encounter_id, current_encounter_index)
	_emit_current_step_started()
	return _result(true, "started")


func perform_action(action_id: String, actor_id: String) -> Dictionary:
	var encounter_id := str(current_encounter().get("id", ""))
	var receipt := "%s:%s" % [encounter_id, action_id]
	if _receipts.has(receipt):
		return _result(true, "already_complete")
	if phase != PHASE_ACTIVE:
		return _reject(action_id, "out_of_order")
	if actor_id == "solo_companion" and not _companion_ping_in_progress:
		return _reject(action_id, "explicit_companion_ping_required")
	var step := current_step()
	if action_id != str(step.get("id", "")):
		return _reject(action_id, "ordered_handoff_required")
	var lens := str(step.get("actor", ""))
	if lens == "role_swap":
		return _reject(action_id, "use_exchange_roles")
	if not _actor_controls_lens(actor_id, lens):
		return _reject(action_id, "%s_lens_required" % lens)
	_receipts[receipt] = true
	_emit_step_evidence(step)
	step_feedback.emit(action_id, true, "completed")
	step_completed.emit(encounter_id, action_id, current_step_index)
	_advance_step()
	return _result(true, "completed", action_id)


func exchange_roles(action_id: String = "storm.exchange_lenses") -> Dictionary:
	var encounter_id := str(current_encounter().get("id", ""))
	var receipt := "%s:%s" % [encounter_id, action_id]
	if _receipts.has(receipt):
		return _result(true, "already_complete")
	if phase != PHASE_ACTIVE or action_id != str(current_step().get("id", "")) or str(current_step().get("actor", "")) != "role_swap":
		return _reject(action_id, "role_exchange_not_available")
	if solo_mode:
		solo_human_lens = LENS_HOPE if solo_human_lens == LENS_ALARM else LENS_ALARM
	else:
		var prior_alarm := alarm_controller
		alarm_controller = hope_controller
		hope_controller = prior_alarm
	_update_controllers()
	_receipts[receipt] = true
	roles_swapped.emit(alarm_controller, hope_controller)
	step_feedback.emit(action_id, true, "roles_swapped")
	step_completed.emit(encounter_id, action_id, current_step_index)
	_advance_step()
	return _result(true, "roles_swapped", action_id)


func ping_solo_companion(action_id: String) -> Dictionary:
	if not solo_mode:
		var unavailable := _reject(action_id, "solo_mode_required")
		companion_ping_completed.emit(action_id, false, str(unavailable["reason"]))
		return unavailable
	_companion_ping_in_progress = true
	var result := perform_action(action_id, "solo_companion")
	_companion_ping_in_progress = false
	companion_ping_completed.emit(action_id, bool(result.get("accepted", false)), str(result.get("reason", "")))
	return result


func advance_to_next_encounter() -> Dictionary:
	if phase != PHASE_BETWEEN:
		return _reject("advance_to_next_encounter", "out_of_order")
	current_encounter_index += 1
	current_step_index = 0
	_set_phase(PHASE_READY)
	return _result(true, "advanced")


func request_completion() -> Dictionary:
	if completion_was_requested:
		return _result(true, "already_complete", "star_of_wisdom_completion_requested")
	if phase != PHASE_COMPLETION_READY:
		return _reject("request_completion", "out_of_order")
	completion_was_requested = true
	var treasure_id := str(catalog.get("reward_request", "star_of_wisdom"))
	evidence_emitted.emit("star_of_wisdom_completion_requested", {"treasure_id": treasure_id})
	completion_requested.emit(treasure_id)
	chapter_completed.emit(treasure_id)
	_set_phase(PHASE_COMPLETE)
	return _result(true, "completed", "star_of_wisdom_completion_requested")


func skip_session() -> Dictionary:
	if phase in [PHASE_COMPLETE, PHASE_SKIPPED]:
		return _result(true, "already_complete")
	_set_phase(PHASE_SKIPPED)
	return _result(true, "skipped_without_reward")


func _advance_step() -> void:
	current_step_index += 1
	var steps: Array = current_encounter().get("steps", [])
	if current_step_index < steps.size():
		_emit_current_step_started()
		return
	var encounter_id := str(current_encounter().get("id", ""))
	completed_encounter_ids[encounter_id] = true
	var environment_state := str(QUEST_ENVIRONMENT_STATES.get(encounter_id, ""))
	if not environment_state.is_empty():
		environment_state_requested.emit(environment_state, {
			"canonical_quest_id": encounter_id,
			"encounter_index": current_encounter_index,
		})
	if current_encounter_index + 1 < catalog.get("encounters", []).size():
		_set_phase(PHASE_BETWEEN)
	else:
		_set_phase(PHASE_COMPLETION_READY)


func _emit_step_evidence(step: Dictionary) -> void:
	for evidence in step.get("evidence", []):
		if evidence is Dictionary:
			var payload: Dictionary = evidence.duplicate(true)
			var event_id := str(payload.get("event", ""))
			payload.erase("event")
			evidence_emitted.emit(event_id, payload)


func _update_controllers() -> void:
	if solo_mode:
		alarm_controller = "solo_player" if solo_human_lens == LENS_ALARM else "solo_companion"
		hope_controller = "solo_player" if solo_human_lens == LENS_HOPE else "solo_companion"
	elif alarm_controller.begins_with("solo_") or hope_controller.begins_with("solo_"):
		alarm_controller = "player_1"
		hope_controller = "player_2"


func _actor_controls_lens(actor_id: String, lens: String) -> bool:
	return (lens == LENS_ALARM and actor_id == alarm_controller) or (lens == LENS_HOPE and actor_id == hope_controller)


func _set_phase(next_phase: String) -> void:
	phase = next_phase
	phase_changed.emit(phase)


func _reject(action_id: String, reason: String) -> Dictionary:
	action_rejected.emit(action_id, reason)
	step_feedback.emit(action_id, false, reason)
	if phase == PHASE_ACTIVE:
		step_revised.emit(str(current_encounter().get("id", "")),
			str(current_step().get("id", "")), reason)
	return _result(false, reason)


func _emit_current_step_started() -> void:
	var step := current_step()
	if step.is_empty():
		return
	step_started.emit(str(current_encounter().get("id", "")),
		str(step.get("id", "")), current_step_index)


func _result(accepted: bool, reason: String, event_id: String = "") -> Dictionary:
	return {"accepted": accepted, "reason": reason, "event": event_id, "phase": phase, "encounter_index": current_encounter_index, "step_index": current_step_index}
