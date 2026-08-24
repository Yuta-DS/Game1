# Focused coordinator contract. Run with:
#   godot --headless --path artea --script res://scripts/test_mind_spark_split_world.gd
extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_split_world.tscn")
const SharedState := preload("res://scripts/mind_spark/mind_spark_shared_state.gd")


class FakeJourneyState extends Node:
	var record_calls: Array[Dictionary] = []
	var popped_calls: Array[String] = []
	var completion_calls := 0
	var awarded := false
	var required_ids: Array[String] = []

	func record_thought_echo(text: String, echo_id: String) -> void:
		record_calls.append({"text": text, "id": echo_id})

	func mark_popped(text: String) -> void:
		popped_calls.append(text)

	func complete_mind_spark(minimum_echoes: int = 2, required_echo_ids: Array[String] = []) -> bool:
		completion_calls += 1
		required_ids.assign(required_echo_ids)
		awarded = minimum_echoes == 2 and record_calls.size() == 2 and popped_calls.size() == 2 \
			and required_ids == ["round.small_step", "round.safe_connection"]
		return awarded


class FakeCampaign extends Node:
	var return_calls := 0

	func return_to_campaign(_tree: SceneTree = null) -> bool:
		return_calls += 1
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_complete_solo_run()
	await _test_local_coop_roles()
	await _test_skip_awards_nothing()
	print("Mind Spark split world: all checks passed")
	quit()


func _new_world(journey: FakeJourneyState, campaign: FakeCampaign):
	var world = WorldScene.instantiate()
	world.inject_dependencies(journey, campaign, SharedState.new())
	root.add_child(world)
	await process_frame
	return world


func _test_complete_solo_run() -> void:
	var journey := FakeJourneyState.new()
	var campaign := FakeCampaign.new()
	var world = await _new_world(journey, campaign)

	assert(world.alarm_viewport.size.x <= world.VIEWPORT_CAP.x and world.alarm_viewport.size.y <= world.VIEWPORT_CAP.y,
		"Alarm internal render size is capped")
	assert(world.hope_viewport.size.x <= world.VIEWPORT_CAP.x and world.hope_viewport.size.y <= world.VIEWPORT_CAP.y,
		"Hope internal render size is capped")
	assert(world.alarm_viewport.find_world_3d() != world.hope_viewport.find_world_3d(),
		"each side owns an isolated World3D")
	assert(world.alarm_perspective != world.hope_perspective,
		"two perspectives are independent instances")
	assert(world.get_input_action_names().size() == 12, "all standalone input actions are exposed")
	for action_name in world.get_input_action_names():
		assert(InputMap.has_action(action_name), "standalone action exists: %s" % action_name)
	var alarm_events_before := InputMap.action_get_events("mind_alarm_move_left").size()
	world._ensure_input_actions()
	assert(InputMap.action_get_events("mind_alarm_move_left").size() == alarm_events_before,
		"existing input actions are never duplicated or overwritten")
	var hope_ping := InputMap.action_get_events("mind_hope_ping")[0] as InputEventKey
	assert(hope_ping.physical_keycode == KEY_SHIFT and hope_ping.location == KeyLocation.KEY_LOCATION_RIGHT,
		"Hope ping defaults to Right Shift while remaining remappable")
	assert(not journey.awarded, "entry cannot award a Star")

	assert(world.select_pair("round.small_step"))
	assert(world.select_effect("effect.unsure"), "human Alarm Lens notices the first effect")
	assert(not world.select_response("response.small_step"), "companion action waits for an explicit ping")
	assert(world.pending_companion_action == "choose_response")
	assert(world.companion_ping(), "explicit solo ping performs the authored Hope action")
	assert(world.activate_anchor("anchor.signal_beacon"))
	assert(not world.activate_anchor("anchor.root_lantern"), "companion anchor also waits for a ping")
	assert(world.companion_ping())
	assert(world.integrate_bridge())
	assert(not journey.awarded, "first bridge is not enough for the Star")
	assert(not world.advance_round(), "role exchange is mandatory")
	assert(world.swap_roles(), "solo player carries the other Lens in round two")
	assert(world.advance_round())

	assert(world.select_pair("round.safe_connection"))
	assert(not world.select_effect("effect.not_sure"), "after swap the companion owns Alarm")
	assert(world.companion_ping())
	assert(world.select_response("response.safe_connection"), "after swap the player owns Hope")
	assert(not world.activate_anchor("anchor.truth_array"))
	assert(world.companion_ping())
	assert(world.activate_anchor("anchor.welcome_vine"))
	assert(world.integrate_bridge())
	assert(not journey.awarded, "two bridges still require the constellation")
	for symbol_id in ["symbol.notice", "symbol.name", "symbol.choose"]:
		assert(world.activate_constellation_symbol(symbol_id))
	assert(not journey.awarded, "constellation does not persist until explicit completion")
	assert(world.complete_world())
	assert(journey.awarded and journey.record_calls.size() == 2 and journey.popped_calls.size() == 2,
		"valid completion records exactly two resolved authored Echoes")
	assert(journey.completion_calls == 1, "Mind Spark completion is requested exactly once")
	assert(journey.required_ids == ["round.small_step", "round.safe_connection"],
		"Star validation is bound to the exact two authored bridges")
	assert(campaign.return_calls == 1, "valid completion returns through the campaign")
	assert(world.complete_world() and journey.completion_calls == 1, "completion is idempotent")
	world.queue_free()
	await process_frame


func _test_skip_awards_nothing() -> void:
	var journey := FakeJourneyState.new()
	var campaign := FakeCampaign.new()
	var world = await _new_world(journey, campaign)
	world.select_pair("round.small_step")
	world.skip_to_castle()
	world.skip_to_castle()
	assert(not journey.awarded and journey.record_calls.is_empty() and journey.completion_calls == 0,
		"confirmed safe skip fabricates no thought evidence and awards nothing")
	assert(campaign.return_calls == 1, "skip returns to Castle exactly once")
	world.queue_free()
	await process_frame


func _test_local_coop_roles() -> void:
	var journey := FakeJourneyState.new()
	var campaign := FakeCampaign.new()
	var world = await _new_world(journey, campaign)
	assert(world.set_solo_mode(false), "entry can select local co-op before progress")
	assert(not world.solo_mode and not world.companion_button.visible, "local co-op has no simulated companion")
	assert(world.select_pair("round.small_step"))
	assert(world.select_effect("effect.urgent"), "player one controls Alarm")
	assert(world.select_response("response.learning"), "player two controls Hope")
	assert(world.activate_anchor("anchor.signal_beacon"))
	assert(world.activate_anchor("anchor.root_lantern"))
	assert(world.integrate_bridge())
	assert(world.swap_roles(), "local co-op swaps player-to-Lens ownership")
	assert(world.shared_state.alarm_controller == "player_2" and world.shared_state.hope_controller == "player_1")
	assert(not journey.awarded, "co-op handoff alone cannot award a Star")
	world.queue_free()
	await process_frame
