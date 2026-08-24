extends SceneTree

const ChapterScene := preload("res://scenes/mind_spark/mind_spark_chapter_world.tscn")
const Director := preload("res://scripts/mind_spark/mind_spark_encounter_director.gd")
const Store := preload("res://scripts/mind_spark/mind_spark_checkpoint_store.gd")


class FakeJourneyState extends Node:
	var audience_mode := "universal"
	var records: Array[Dictionary] = []
	var popped: Array[String] = []
	var completion_calls := 0

	func record_thought_echo(text: String, echo_id: String) -> void:
		records.append({"text": text, "id": echo_id})

	func mark_popped(text: String) -> void:
		popped.append(text)

	func complete_mind_spark(minimum: int, ids: Array[String]) -> bool:
		completion_calls += 1
		return minimum == 2 and ids == ["round.small_step", "round.safe_connection"] \
			and records.size() == 2 and popped.size() == 2


class FakeCampaign extends Node:
	var returns := 0
	func return_to_campaign(_tree: SceneTree = null) -> bool:
		returns += 1
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_complete_five_quest_chapter()
	await _test_local_coop_entry()
	await _test_skip_awards_nothing()
	print("MindSparkChapterWorld: all checks passed")
	quit()


func _new_world(journey: FakeJourneyState, campaign: FakeCampaign):
	var world = ChapterScene.instantiate()
	var checkpoint = Store.new("user://test_mind_spark_chapter_world_checkpoint.json")
	checkpoint.clear()
	world.inject_dependencies(journey, campaign, Director.new(), null, checkpoint)
	root.add_child(world)
	await process_frame
	return world


func _test_complete_five_quest_chapter() -> void:
	var journey := FakeJourneyState.new()
	var campaign := FakeCampaign.new()
	var world = await _new_world(journey, campaign)
	assert(world.story.is_valid() and world.director.is_valid())
	assert(world.audience_profile == "universal")
	assert(world.guardian_name_label.text == "Guardian of Wisdom")
	assert(world.alarm_viewport.find_world_3d() != world.hope_viewport.find_world_3d())
	world._on_continue()
	while world.director.phase != Director.PHASE_COMPLETION_READY:
		if world.director.phase == Director.PHASE_BETWEEN:
			world._on_continue()
			continue
		var step: Dictionary = world.director.current_step()
		if step["actor"] == "role_swap":
			world._exchange_roles()
			continue
		var lens: String = step["actor"]
		var actor: String = world.director.alarm_controller if lens == "alarm" else world.director.hope_controller
		var result: Dictionary = world.director.ping_solo_companion(step["id"]) if actor == "solo_companion" \
			else world.director.perform_action(step["id"], actor)
		assert(result["accepted"])
		world._play_cross_seam_consequence()
		world._render()
	assert(world.director.completed_encounter_ids.size() == 5)
	assert(journey.completion_calls == 0, "no early Star before consent")
	world._complete_chapter("watch")
	assert(world.completion_committed and journey.completion_calls == 1)
	assert(journey.records.map(func(item): return item["id"]) == ["round.small_step", "round.safe_connection"])
	world._on_continue()
	assert(campaign.returns == 1)
	world.queue_free()
	await process_frame


func _test_skip_awards_nothing() -> void:
	var journey := FakeJourneyState.new()
	var campaign := FakeCampaign.new()
	var world = await _new_world(journey, campaign)
	world._confirm_skip()
	assert(journey.records.is_empty() and journey.completion_calls == 0)
	assert(campaign.returns == 1)
	world.queue_free()
	await process_frame


func _test_local_coop_entry() -> void:
	var journey := FakeJourneyState.new()
	var campaign := FakeCampaign.new()
	var world = await _new_world(journey, campaign)
	world._set_local_coop(true)
	assert(not world.solo_mode)
	assert(world.director.alarm_controller == "player_1" and world.director.hope_controller == "player_2")
	world._on_continue()
	assert(world.director.current_step()["actor"] == "alarm")
	assert(world.director.perform_action(world.director.current_step()["id"], "player_1")["accepted"])
	assert(journey.completion_calls == 0)
	world.queue_free()
	await process_frame
