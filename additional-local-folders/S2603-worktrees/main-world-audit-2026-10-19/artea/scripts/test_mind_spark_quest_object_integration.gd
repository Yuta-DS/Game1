extends SceneTree

const ChapterScene := preload("res://scenes/mind_spark/mind_spark_chapter_world.tscn")
const Director := preload("res://scripts/mind_spark/mind_spark_encounter_director.gd")
const CheckpointStore := preload("res://scripts/mind_spark/mind_spark_checkpoint_store.gd")


class FakeJourney extends Node:
	var audience_mode := "universal"


class FakeCampaign extends Node:
	func return_to_campaign(_tree: SceneTree = null) -> bool:
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var checkpoint := CheckpointStore.new("user://test_mind_spark_object_integration.json")
	checkpoint.clear()
	var world = ChapterScene.instantiate()
	world.inject_dependencies(FakeJourney.new(), FakeCampaign.new(), Director.new(), null, checkpoint)
	root.add_child(world)
	await process_frame
	world._on_continue()
	await process_frame

	var alarm = world.alarm_perspective
	var active := alarm.get_node("InteractionStation") as QuestObjectBase
	active.persist_state = false
	active.current_state = active._default_state()
	active._apply_visual_state(false)
	assert(active.definition.display_name == "Evidence Scanner", "first authored step uses its approved object")
	assert(world.director.current_step_index == 0)
	alarm.role.position = alarm.interaction_station_position()
	world._on_role_interaction("alarm")
	assert(world.director.current_step_index == 0, "scan feedback occurs before the story gate advances")
	assert(world._object_choice_bar.visible and world._object_choice_bar.get_child_count() == 2,
		"FACT and FEAR are explicit player choices")
	world._perform_object_interaction(alarm, "alarm", &"fact")
	assert(world.director.current_step_index == 1, "saved object completion advances the authored encounter")

	for support in alarm._support_objects:
		support.persist_state = false
		support.current_state = support._default_state()
		support._apply_visual_state(false)
	var before_support: int = world.director.current_step_index
	alarm.role.position = alarm._support_objects[0].position
	world._on_role_interaction("alarm")
	assert(world.director.current_step_index == before_support, "Focus Bell gives a hint without solving the step")
	assert(alarm._support_objects[0].current_state["hint_enabled"])

	checkpoint.clear()
	world.queue_free()
	await process_frame
	print("Mind Spark quest object integration: all checks passed")
	quit()
