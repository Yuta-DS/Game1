extends SceneTree

const Director = preload("res://scripts/mind_spark/mind_spark_encounter_director.gd")


func _init() -> void:
	_test_schema()
	_test_two_player_full_journey()
	_test_solo_explicit_companion_and_swap()
	_test_skip_has_no_reward()
	print("MindSparkEncounterDirector: all checks passed")
	quit()


func _test_schema() -> void:
	var catalog: Dictionary = Director.load_catalog()
	assert(Director.validate_catalog(catalog).is_empty(), "five-quest schema is valid")
	assert(catalog["encounters"].size() == 5, "exactly five escalating encounters")
	for index in catalog["encounters"].size():
		var encounter: Dictionary = catalog["encounters"][index]
		assert(encounter["order"] == index + 1)
		assert(not encounter["alarm_information"].is_empty() and not encounter["hope_information"].is_empty())
		assert(not encounter["shared_consequence"].is_empty())
		assert(encounter["steps"].any(func(step): return step["actor"] == "alarm"))
		assert(encounter["steps"].any(func(step): return step["actor"] == "hope"))
	var serialized := JSON.stringify(catalog).to_lower()
	for forbidden in ["http", "timer", "combat", "death", "diagnose"]:
		assert(not serialized.contains(forbidden), "catalog excludes %s paths" % forbidden)


func _test_two_player_full_journey() -> void:
	var state = Director.new()
	var events: Array[String] = []
	var rewards: Array[String] = []
	state.evidence_emitted.connect(func(event_id: String, _payload: Dictionary): events.append(event_id))
	state.completion_requested.connect(func(treasure_id: String): rewards.append(treasure_id))
	assert(state.start_current_encounter()["accepted"])
	assert(not state.perform_action("observatory.hear_chime", "player_2")["accepted"], "ordered handoff enforced")
	_complete_active_encounter(state)
	while state.phase == Director.PHASE_BETWEEN:
		assert(state.advance_to_next_encounter()["accepted"])
		assert(state.start_current_encounter()["accepted"])
		if state.current_encounter()["id"] == "quest.role_exchange_storm":
			assert(not state.perform_action("storm.exchange_lenses", "player_1")["accepted"])
			assert(state.exchange_roles()["accepted"])
			assert(state.exchange_roles()["reason"] == "already_complete", "role swap is idempotent")
		_complete_active_encounter(state)
	assert(state.phase == Director.PHASE_COMPLETION_READY)
	assert(state.completed_encounter_ids.size() == 5)
	assert(rewards.is_empty(), "journey never awards automatically")
	assert(state.request_completion()["accepted"])
	assert(state.request_completion()["reason"] == "already_complete")
	assert(rewards == ["star_of_wisdom"], "reward request fires exactly once")
	assert(events.count("thought_marked_popped") == 2, "both canonical thought rounds resolve")
	assert(events.count("hope_bridge_crossed") == 2)
	assert(events.count("wisdom_symbol_activated") == 3)
	assert(events.count("wisdom_symbols_connected") == 1)
	assert(events.count("star_of_wisdom_completion_requested") == 1)


func _complete_active_encounter(state) -> void:
	while state.phase == Director.PHASE_ACTIVE:
		var step: Dictionary = state.current_step()
		if step["actor"] == "role_swap":
			assert(state.exchange_roles(step["id"])["accepted"])
			continue
		var actor: String = state.alarm_controller if step["actor"] == "alarm" else state.hope_controller
		var action_id: String = step["id"]
		var result: Dictionary = state.ping_solo_companion(action_id) if actor == "solo_companion" else state.perform_action(action_id, actor)
		assert(result["accepted"])
		var replay: Dictionary = state.ping_solo_companion(action_id) if actor == "solo_companion" else state.perform_action(action_id, actor)
		assert(replay["reason"] == "already_complete", "replay emits no duplicate progress")


func _test_solo_explicit_companion_and_swap() -> void:
	var state = Director.new()
	assert(state.configure_solo(true, Director.LENS_ALARM)["accepted"])
	assert(state.start_current_encounter()["accepted"])
	assert(state.perform_action("observatory.scan_signal", "solo_player")["accepted"])
	assert(not state.perform_action("observatory.hear_chime", "solo_player")["accepted"], "human cannot auto-act for companion")
	assert(state.ping_solo_companion("observatory.hear_chime")["accepted"], "explicit ping performs one companion action")
	_complete_active_encounter(state)
	while state.current_encounter_index < 2:
		state.advance_to_next_encounter()
		state.start_current_encounter()
		_complete_active_encounter(state)
	state.advance_to_next_encounter()
	state.start_current_encounter()
	assert(state.current_step()["actor"] == "role_swap")
	assert(state.exchange_roles()["accepted"])
	assert(state.solo_human_lens == Director.LENS_HOPE)
	assert(state.alarm_controller == "solo_companion" and state.hope_controller == "solo_player")
	assert(state.ping_solo_companion("storm.scan_distance")["accepted"], "swapped companion controls Alarm")
	assert(state.perform_action("storm.raise_shelter", "solo_player")["accepted"], "swapped human controls Hope")


func _test_skip_has_no_reward() -> void:
	var state = Director.new()
	var events: Array[String] = []
	var rewards: Array[String] = []
	state.evidence_emitted.connect(func(event_id: String, _payload: Dictionary): events.append(event_id))
	state.completion_requested.connect(func(treasure_id: String): rewards.append(treasure_id))
	assert(state.skip_session()["accepted"])
	assert(state.phase == Director.PHASE_SKIPPED)
	assert(not state.request_completion()["accepted"])
	assert(events.is_empty() and rewards.is_empty() and state.completed_encounter_ids.is_empty(), "skip fabricates no evidence or reward")
