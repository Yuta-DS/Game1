class_name MindSparkSharedState
extends RefCounted

signal phase_changed(phase_id: String)
signal round_started(round_id: String, round_index: int)
signal evidence_emitted(event_id: String, payload: Dictionary)
signal action_rejected(action_id: String, reason: String)
signal roles_swapped(alarm_controller: String, hope_controller: String)
signal companion_ping_completed(action_id: String, accepted: bool, reason: String)
signal completion_requested(treasure_id: String)

const DEFAULT_CATALOG_PATH := "res://data/mind_spark_thought_pairs.json"

const LENS_ALARM := "alarm"
const LENS_HOPE := "hope"

const PHASE_CHOOSE_PAIR := "choose_pair"
const PHASE_SCAN_EFFECT := "scan_effect"
const PHASE_CHOOSE_RESPONSE := "choose_response"
const PHASE_ACTIVATE_ANCHORS := "activate_anchors"
const PHASE_INTEGRATE_BRIDGE := "integrate_bridge"
const PHASE_BETWEEN_ROUNDS := "between_rounds"
const PHASE_CONSTELLATION := "constellation"
const PHASE_COMPLETION_READY := "completion_ready"
const PHASE_COMPLETE := "complete"

var catalog: Dictionary = {}
var catalog_errors := PackedStringArray()
var phase := PHASE_CHOOSE_PAIR
var current_round_index := 0
var selected_pair_id := ""
var selected_effect_id := ""
var selected_response_id := ""
var activated_anchor_ids: Dictionary = {}
var activated_symbol_ids: Dictionary = {}
var completed_round_ids: Dictionary = {}
var alarm_controller := "player_1"
var hope_controller := "player_2"
var solo_mode := false
var solo_human_lens := LENS_ALARM
var inter_round_role_swap_completed := false
var completion_was_requested := false

var _receipts: Dictionary = {}


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
		errors.append("catalog must be a non-empty dictionary")
		return errors
	if int(source.get("schema_version", 0)) != 1:
		errors.append("schema_version must be 1")
	if str(source.get("safety", {}).get("mode", "")) != "curated_offline":
		errors.append("safety.mode must be curated_offline")
	var rounds: Variant = source.get("rounds", null)
	if not rounds is Array or rounds.size() != 2:
		errors.append("rounds must contain exactly two authored rounds")
		return errors
	var known_ids := {}
	for index in rounds.size():
		var round_data: Variant = rounds[index]
		if not round_data is Dictionary:
			errors.append("rounds[%d] must be a dictionary" % index)
			continue
		var round_id := str(round_data.get("id", ""))
		if round_id.is_empty() or known_ids.has(round_id):
			errors.append("rounds[%d] needs a unique id" % index)
		known_ids[round_id] = true
		if int(round_data.get("order", 0)) != index + 1:
			errors.append("round %s has invalid order" % round_id)
		if str(round_data.get("thought", "")).strip_edges().is_empty():
			errors.append("round %s needs an authored thought" % round_id)
		_validate_choices(round_data.get("alarm_effects", null), "alarm_effects", round_id, true, errors)
		_validate_choices(round_data.get("hope_responses", null), "hope_responses", round_id, false, errors)
		var anchors: Variant = round_data.get("anchors", null)
		if not anchors is Array or anchors.size() != 2:
			errors.append("round %s must have exactly two anchors" % round_id)
		else:
			var lenses := PackedStringArray()
			for anchor in anchors:
				if anchor is Dictionary:
					lenses.append(str(anchor.get("lens", "")))
			if not lenses.has(LENS_ALARM) or not lenses.has(LENS_HOPE):
				errors.append("round %s needs one anchor for each lens" % round_id)
	var symbols: Variant = source.get("constellation", {}).get("symbols", null)
	if not symbols is Array or symbols.size() != 3:
		errors.append("constellation must have exactly three symbols")
	return errors


static func _validate_choices(value: Variant, field: String, round_id: String, require_neutral: bool, errors: PackedStringArray) -> void:
	if not value is Array or value.size() < 2:
		errors.append("round %s.%s must have at least two choices" % [round_id, field])
		return
	var has_neutral := false
	for choice in value:
		if not choice is Dictionary or str(choice.get("id", "")).is_empty() or str(choice.get("label", "")).is_empty():
			errors.append("round %s.%s has an invalid authored choice" % [round_id, field])
			continue
		if require_neutral and bool(choice.get("neutral", false)):
			has_neutral = true
		if not require_neutral and not bool(choice.get("grounded", false)):
			errors.append("round %s has an ungrounded Hope response" % round_id)
	if require_neutral and not has_neutral:
		errors.append("round %s must offer a neutral/not-sure effect" % round_id)


func is_valid() -> bool:
	return catalog_errors.is_empty()


func current_round() -> Dictionary:
	var rounds: Array = catalog.get("rounds", [])
	if current_round_index < 0 or current_round_index >= rounds.size():
		return {}
	return rounds[current_round_index].duplicate(true)


func configure_solo(enabled: bool, human_lens: String = LENS_ALARM) -> Dictionary:
	if phase != PHASE_CHOOSE_PAIR or current_round_index != 0 or not selected_pair_id.is_empty():
		return _reject("configure_solo", "configuration_locked")
	if human_lens != LENS_ALARM and human_lens != LENS_HOPE:
		return _reject("configure_solo", "unknown_lens")
	solo_mode = enabled
	solo_human_lens = human_lens
	if enabled:
		_update_solo_controllers()
	else:
		alarm_controller = "player_1"
		hope_controller = "player_2"
	return _result(true, "configured")


func swap_roles() -> Dictionary:
	if inter_round_role_swap_completed:
		return _result(true, "already_complete")
	if phase != PHASE_BETWEEN_ROUNDS:
		return _reject("swap_roles", "inter_round_handoff_required")
	if solo_mode:
		solo_human_lens = LENS_HOPE if solo_human_lens == LENS_ALARM else LENS_ALARM
		_update_solo_controllers()
	else:
		var previous_alarm := alarm_controller
		alarm_controller = hope_controller
		hope_controller = previous_alarm
	inter_round_role_swap_completed = true
	roles_swapped.emit(alarm_controller, hope_controller)
	return _result(true, "roles_swapped")


func choose_pair(pair_id: String) -> Dictionary:
	var receipt := "choose_pair:%s" % pair_id
	var prior := _idempotent(receipt)
	if not prior.is_empty():
		return prior
	if phase != PHASE_CHOOSE_PAIR:
		return _reject("choose_pair", "out_of_order")
	var round_data := current_round()
	if pair_id != str(round_data.get("id", "")):
		return _reject("choose_pair", "pair_not_available")
	selected_pair_id = pair_id
	_receipts[receipt] = true
	_emit_evidence("thought_cloud_selected", {"round_id": pair_id})
	_set_phase(PHASE_SCAN_EFFECT)
	round_started.emit(pair_id, current_round_index)
	return _result(true, "completed", "thought_cloud_selected")


func scan_effect(effect_id: String, actor_id: String) -> Dictionary:
	var receipt := "scan_effect:%s:%s" % [selected_pair_id, effect_id]
	var prior := _idempotent(receipt)
	if not prior.is_empty():
		return prior
	if phase != PHASE_SCAN_EFFECT:
		return _reject("scan_effect", "out_of_order")
	if not _actor_controls_lens(actor_id, LENS_ALARM):
		return _reject("scan_effect", "alarm_lens_required")
	if not _choice_exists(current_round().get("alarm_effects", []), effect_id):
		return _reject("scan_effect", "unknown_effect")
	selected_effect_id = effect_id
	_receipts[receipt] = true
	_emit_evidence("thought_effect_selected", {"round_id": selected_pair_id})
	_set_phase(PHASE_CHOOSE_RESPONSE)
	return _result(true, "completed", "thought_effect_selected")


func choose_response(response_id: String, actor_id: String) -> Dictionary:
	var receipt := "choose_response:%s:%s" % [selected_pair_id, response_id]
	var prior := _idempotent(receipt)
	if not prior.is_empty():
		return prior
	if phase != PHASE_CHOOSE_RESPONSE:
		return _reject("choose_response", "out_of_order")
	if not _actor_controls_lens(actor_id, LENS_HOPE):
		return _reject("choose_response", "hope_lens_required")
	if not _choice_exists(current_round().get("hope_responses", []), response_id):
		return _reject("choose_response", "unknown_response")
	selected_response_id = response_id
	_receipts[receipt] = true
	# Emit canonical Crown evidence in prerequisite order. Payloads contain only
	# authored IDs; no personal content is retained.
	_emit_evidence("thought_cloud_repositioned", {"round_id": selected_pair_id})
	_emit_evidence("both_reframe_windows_viewed", {"round_id": selected_pair_id})
	_set_phase(PHASE_ACTIVATE_ANCHORS)
	return _result(true, "completed", "both_reframe_windows_viewed")


func activate_anchor(anchor_id: String, actor_id: String) -> Dictionary:
	var receipt := "activate_anchor:%s:%s" % [selected_pair_id, anchor_id]
	var prior := _idempotent(receipt)
	if not prior.is_empty():
		return prior
	if phase != PHASE_ACTIVATE_ANCHORS:
		return _reject("activate_anchor", "out_of_order")
	var anchor := _item_by_id(current_round().get("anchors", []), anchor_id)
	if anchor.is_empty():
		return _reject("activate_anchor", "unknown_anchor")
	var lens := str(anchor.get("lens", ""))
	if not _actor_controls_lens(actor_id, lens):
		return _reject("activate_anchor", "%s_lens_required" % lens)
	activated_anchor_ids[anchor_id] = true
	_receipts[receipt] = true
	_emit_evidence("mind_spark_anchor_activated", {"round_id": selected_pair_id, "anchor_id": anchor_id, "lens": lens})
	if activated_anchor_ids.size() == current_round().get("anchors", []).size():
		_emit_evidence("mind_spark_anchors_activated", {"round_id": selected_pair_id})
		_set_phase(PHASE_INTEGRATE_BRIDGE)
	return _result(true, "completed", "mind_spark_anchor_activated")


func integrate_bridge(bridge_id: String) -> Dictionary:
	var receipt := "integrate_bridge:%s:%s" % [selected_pair_id, bridge_id]
	var prior := _idempotent(receipt)
	if not prior.is_empty():
		return prior
	if phase != PHASE_INTEGRATE_BRIDGE:
		return _reject("integrate_bridge", "out_of_order")
	if bridge_id != str(current_round().get("bridge", {}).get("id", "")):
		return _reject("integrate_bridge", "unknown_bridge")
	_receipts[receipt] = true
	completed_round_ids[selected_pair_id] = true
	# Resolution evidence is withheld until both lenses have activated their
	# anchors and the integrated bridge is actually complete.
	_emit_evidence("thought_marked_popped", {"round_id": selected_pair_id})
	_emit_evidence("hope_bridge_crossed", {"round_id": selected_pair_id})
	if current_round_index + 1 < catalog.get("rounds", []).size():
		_set_phase(PHASE_BETWEEN_ROUNDS)
	else:
		_set_phase(PHASE_CONSTELLATION)
	return _result(true, "completed", "hope_bridge_crossed")


func advance_to_next_round() -> Dictionary:
	if phase != PHASE_BETWEEN_ROUNDS:
		return _reject("advance_to_next_round", "out_of_order")
	if not inter_round_role_swap_completed:
		return _reject("advance_to_next_round", "role_swap_required")
	current_round_index += 1
	selected_pair_id = ""
	selected_effect_id = ""
	selected_response_id = ""
	activated_anchor_ids.clear()
	_set_phase(PHASE_CHOOSE_PAIR)
	return _result(true, "advanced")


func activate_constellation_symbol(symbol_id: String) -> Dictionary:
	var receipt := "constellation:%s" % symbol_id
	var prior := _idempotent(receipt)
	if not prior.is_empty():
		return prior
	if phase != PHASE_CONSTELLATION:
		return _reject("activate_constellation_symbol", "out_of_order")
	var symbols: Array = catalog.get("constellation", {}).get("symbols", [])
	if _item_by_id(symbols, symbol_id).is_empty():
		return _reject("activate_constellation_symbol", "unknown_symbol")
	activated_symbol_ids[symbol_id] = true
	_receipts[receipt] = true
	_emit_evidence("wisdom_symbol_activated", {"symbol_id": symbol_id})
	if activated_symbol_ids.size() == symbols.size():
		_emit_evidence(str(catalog.get("constellation", {}).get("completion_event", "wisdom_symbols_connected")), {})
		_set_phase(PHASE_COMPLETION_READY)
	return _result(true, "completed", "wisdom_symbol_activated")


func request_completion() -> Dictionary:
	if completion_was_requested:
		return _result(true, "already_complete", "star_of_wisdom_completion_requested")
	if phase != PHASE_COMPLETION_READY:
		return _reject("request_completion", "out_of_order")
	completion_was_requested = true
	var treasure_id := str(catalog.get("reward_request", "star_of_wisdom"))
	_emit_evidence("star_of_wisdom_completion_requested", {"treasure_id": treasure_id})
	completion_requested.emit(treasure_id)
	_set_phase(PHASE_COMPLETE)
	return _result(true, "completed", "star_of_wisdom_completion_requested")


# The solo companion never acts automatically. The player must explicitly ping
# for exactly one authored action controlled by the companion's current lens.
func ping_solo_companion(action_id: String, value_id: String) -> Dictionary:
	if not solo_mode:
		var unavailable := _reject("ping_solo_companion", "solo_mode_required")
		companion_ping_completed.emit(action_id, false, str(unavailable["reason"]))
		return unavailable
	var result: Dictionary
	match action_id:
		"scan_effect":
			result = scan_effect(value_id, "solo_companion")
		"choose_response":
			result = choose_response(value_id, "solo_companion")
		"activate_anchor":
			result = activate_anchor(value_id, "solo_companion")
		_:
			result = _reject("ping_solo_companion", "unknown_companion_action")
	companion_ping_completed.emit(action_id, bool(result.get("accepted", false)), str(result.get("reason", "")))
	return result


func _update_solo_controllers() -> void:
	alarm_controller = "solo_player" if solo_human_lens == LENS_ALARM else "solo_companion"
	hope_controller = "solo_player" if solo_human_lens == LENS_HOPE else "solo_companion"


func _actor_controls_lens(actor_id: String, lens: String) -> bool:
	if lens == LENS_ALARM:
		return actor_id == alarm_controller
	if lens == LENS_HOPE:
		return actor_id == hope_controller
	return false


func _choice_exists(choices: Array, choice_id: String) -> bool:
	return not _item_by_id(choices, choice_id).is_empty()


func _item_by_id(items: Array, item_id: String) -> Dictionary:
	for item in items:
		if item is Dictionary and str(item.get("id", "")) == item_id:
			return item
	return {}


func _idempotent(receipt: String) -> Dictionary:
	return _result(true, "already_complete") if _receipts.has(receipt) else {}


func _set_phase(next_phase: String) -> void:
	phase = next_phase
	phase_changed.emit(phase)


func _emit_evidence(event_id: String, payload: Dictionary) -> void:
	evidence_emitted.emit(event_id, payload.duplicate(true))


func _reject(action_id: String, reason: String) -> Dictionary:
	action_rejected.emit(action_id, reason)
	return _result(false, reason)


func _result(accepted: bool, reason: String, event_id: String = "") -> Dictionary:
	return {
		"accepted": accepted,
		"reason": reason,
		"event": event_id,
		"phase": phase,
		"round_index": current_round_index,
	}
