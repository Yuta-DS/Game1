# Focused, save-independent state-machine test.
#   godot --headless --path artea --script res://scripts/test_mind_spark_shared_state.gd
extends SceneTree

const StateScript = preload("res://scripts/mind_spark/mind_spark_shared_state.gd")


func _init() -> void:
	_test_catalog_contract()
	_test_two_player_full_path_and_rejections()
	_test_solo_ping_and_role_swap()
	print("MindSparkSharedState: all checks passed")
	quit()


func _test_catalog_contract() -> void:
	var catalog: Dictionary = StateScript.load_catalog()
	assert(StateScript.validate_catalog(catalog).is_empty(), "catalog is valid")
	assert(catalog["rounds"].size() == 2, "vertical slice has exactly two authored rounds")
	for round_data in catalog["rounds"]:
		assert(round_data["alarm_effects"].any(func(choice): return choice.get("neutral", false)),
			"every round offers neutral/not-sure")
		assert(round_data["hope_responses"].all(func(choice): return choice.get("grounded", false)),
			"every Hope response is grounded")
	var serialized := JSON.stringify(catalog).to_lower()
	assert(not serialized.contains("http"), "catalog has no network route")
	assert(not serialized.contains("timer"), "catalog has no timer")
	assert(serialized.contains("never diagnose") and serialized.contains("never require personal disclosure"),
		"catalog carries the child-safe contract")


func _test_two_player_full_path_and_rejections() -> void:
	var state = StateScript.new()
	var events: Array[String] = []
	var completion_requests: Array[String] = []
	state.evidence_emitted.connect(func(event_id: String, _payload: Dictionary): events.append(event_id))
	state.completion_requested.connect(func(treasure_id: String): completion_requests.append(treasure_id))
	assert(state.is_valid(), "state loads valid catalog")
	assert(not state.scan_effect("effect.urgent", "player_1")["accepted"], "scan cannot precede pair")

	_complete_round_one(state)
	assert(state.phase == StateScript.PHASE_BETWEEN_ROUNDS, "first bridge pauses between rounds")
	assert(events.count("thought_marked_popped") == 1, "resolution evidence waits for the first bridge")
	assert(events.find("thought_marked_popped") < events.find("hope_bridge_crossed"),
		"resolution evidence remains in canonical order before bridge completion")
	assert(not state.choose_pair("round.safe_connection")["accepted"], "next pair needs explicit advance")
	assert(not state.configure_solo(true)["accepted"], "play mode cannot change to bypass the handoff")
	assert(not state.advance_to_next_round()["accepted"], "round two cannot bypass the role exchange")
	assert(state.swap_roles()["accepted"], "roles exchange at the inter-round handoff")
	assert(state.swap_roles()["reason"] == "already_complete", "role exchange cannot toggle twice")
	assert(state.advance_to_next_round()["accepted"], "advance begins round two")
	assert(state.choose_pair("round.safe_connection")["accepted"])
	assert(not state.scan_effect("effect.left_out", "player_1")["accepted"], "old Alarm role cannot scan")
	assert(state.scan_effect("effect.not_sure", "player_2")["accepted"], "neutral choice is full progress")
	assert(state.choose_response("response.safe_connection", "player_1")["accepted"])
	assert(state.activate_anchor("anchor.welcome_vine", "player_1")["accepted"], "anchors work in either order")
	assert(state.activate_anchor("anchor.truth_array", "player_2")["accepted"])
	assert(state.integrate_bridge("bridge.safe_connection")["accepted"])
	assert(state.phase == StateScript.PHASE_CONSTELLATION)
	assert(state.activate_constellation_symbol("symbol.choose")["accepted"], "symbols work in any order")
	assert(state.activate_constellation_symbol("symbol.notice")["accepted"])
	assert(state.activate_constellation_symbol("symbol.name")["accepted"])
	assert(state.phase == StateScript.PHASE_COMPLETION_READY)
	assert(completion_requests.is_empty(), "treasure is not requested automatically")
	assert(state.request_completion()["accepted"])
	assert(state.request_completion()["reason"] == "already_complete", "completion request is idempotent")
	assert(completion_requests == ["star_of_wisdom"], "completion signal fires exactly once")
	assert(events.count("thought_cloud_selected") == 2)
	assert(events.count("hope_bridge_crossed") == 2)
	assert(events.count("wisdom_symbols_connected") == 1)
	assert(events.count("star_of_wisdom_completion_requested") == 1)


func _complete_round_one(state) -> void:
	assert(state.choose_pair("round.small_step")["accepted"])
	assert(state.choose_pair("round.small_step")["reason"] == "already_complete", "retry is idempotent")
	assert(state.scan_effect("effect.urgent", "player_1")["accepted"])
	assert(not state.choose_response("response.small_step", "player_1")["accepted"], "Alarm player cannot act as Hope")
	assert(state.choose_response("response.small_step", "player_2")["accepted"])
	assert(state.activate_anchor("anchor.root_lantern", "player_2")["accepted"])
	assert(state.activate_anchor("anchor.root_lantern", "player_2")["reason"] == "already_complete")
	assert(state.activate_anchor("anchor.signal_beacon", "player_1")["accepted"])
	assert(state.integrate_bridge("bridge.first_step")["accepted"])


func _test_solo_ping_and_role_swap() -> void:
	var state = StateScript.new()
	assert(state.configure_solo(true, StateScript.LENS_ALARM)["accepted"])
	assert(not state.swap_roles()["accepted"], "solo roles cannot swap before the handoff")
	assert(state.choose_pair("round.small_step")["accepted"])
	assert(state.scan_effect("effect.unsure", "solo_player")["accepted"])
	assert(not state.choose_response("response.learning", "solo_player")["accepted"],
		"companion action never auto-completes")
	assert(state.ping_solo_companion("choose_response", "response.learning")["accepted"],
		"explicit ping completes the companion action")
	assert(state.activate_anchor("anchor.signal_beacon", "solo_player")["accepted"])
	assert(state.ping_solo_companion("activate_anchor", "anchor.root_lantern")["accepted"])
	assert(state.integrate_bridge("bridge.first_step")["accepted"])
	assert(not state.advance_to_next_round()["accepted"], "solo mode cannot bypass its role exchange")
	assert(state.swap_roles()["accepted"])
	assert(state.solo_human_lens == StateScript.LENS_HOPE, "solo role swap is retained")
	assert(state.swap_roles()["reason"] == "already_complete", "solo role exchange happens exactly once")
	assert(state.advance_to_next_round()["accepted"])
	assert(state.choose_pair("round.safe_connection")["accepted"])
	assert(not state.scan_effect("effect.left_out", "solo_player")["accepted"])
	assert(state.ping_solo_companion("scan_effect", "effect.left_out")["accepted"],
		"swapped companion controls Alarm Lens")
	assert(state.choose_response("response.safe_connection", "solo_player")["accepted"],
		"swapped human controls Hope Lens")
