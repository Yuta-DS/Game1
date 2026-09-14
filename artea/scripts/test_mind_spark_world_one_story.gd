extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const PlayerScene := preload("res://scenes/player_3d.tscn")
const IdentityTrackerScript := preload("res://scripts/player_identity_tracker.gd")
const TEST_PROGRESS := "user://test_mind_spark_world_one_progress.json"
const TEST_OBJECTS := "user://test_mind_spark_world_one_story_objects.json"
const TEST_IDENTITY := "user://test_mind_spark_world_one_identity.json"

class FakeJourney extends Node:
	var thoughts: Array = []
	var star_awarded := false
	func record_thought_echo(text: String, echo_id: String) -> void:
		thoughts.append({"text": text, "mind_echo_id": echo_id, "popped": false})
	func mark_popped(text: String) -> void:
		for thought in thoughts:
			if thought.text == text: thought.popped = true
	func complete_mind_spark(minimum: int, required_ids: Array) -> bool:
		star_awarded = minimum == 2 and required_ids.size() == 2 and thoughts.size() == 2
		return star_awarded


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var player := PlayerScene.instantiate() as CharacterBody3D
	player.add_to_group("Player")
	root.add_child(player)
	var journey := FakeJourney.new()
	root.add_child(journey)
	var identity := IdentityTrackerScript.new()
	identity.save_path = TEST_IDENTITY
	root.add_child(identity)
	var world := _new_world(journey, identity)
	root.add_child(world)
	for _frame in 4: await process_frame
	var quest := world.get_node("QuestController") as MindSparkWorldOneQuest
	assert(quest.target_first_play_minutes() == 64, "the detailed Island One puzzle keeps first play inside the required 55–70 minutes")
	assert(quest.current_task().id == "wake_two_roots")
	var checkpoints: Array[QuestObjectBase] = []
	for object in world.get_quest_objects():
		if object.definition.object_kind == QuestObjectDefinition.ObjectKind.CHECKPOINT_SERVER_ROOT:
			checkpoints.append(object)
	var focus := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.FOCUS_BELL_BEACON)
	assert(str(focus.get_meta("current_required_target", "")).contains("Route Thought"),
		"Focus Bell identifies the first precise Signal Observatory objective")
	var compass := world.get_island_one_puzzle()
	assert(compass != null and compass.solve_for_test().reason == "completed")
	assert(bool(quest.progress.island_one_compass_solved), "Echo Seed completion is connected to Island One")
	player.take_damage(40.0)
	assert(checkpoints[0].available_actions() == [&"save", &"heal", &"task"])
	assert(checkpoints[0].interact(&"heal").accepted and player.current_health == player.max_health,
		"Checkpoint Server Root restores health from its clear three-item menu")
	assert(checkpoints[0].interact(&"task").accepted, "Checkpoint Server Root can read the current task")
	for checkpoint in checkpoints:
		assert(checkpoint.interact(&"save").accepted)
	assert(quest.current_task().id == "collect_two_sparks")
	for collectible in world.get_collectibles():
		assert(collectible.collect())
	for enemy in world.get_enemies():
		if enemy.encounter_id == "network": enemy.take_damage(999.0)
	var socket := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.THOUGHT_SPARK_SOCKET)
	assert(socket.definition.display_name == "Torch Spark Socket")
	assert(socket.interact().accepted and socket.interact().accepted)
	assert(world.is_quest_gate_open(0), "Quest One saves before opening its next path")
	assert(bool(quest.progress.island_two_invitation_received), "Island One sends its Echo Seed to Island Two")
	assert(str(world.get_meta("island_two_story_state")) == "invited")
	player.global_position = world.to_global(world.get_zone_position("03_constellation_court") + Vector3.UP * 3.0)
	quest.call("_try_begin_island_two_story")
	assert(bool(quest.progress.island_two_arrived), "crossing into Island Two begins the evidence story once")
	assert(str(world.get_meta("island_two_story_state")) == "received")
	var scanner := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER)
	assert(not scanner.interact(&"fact").accepted)
	for channel in 3:
		assert(not scanner.interact(&"capture", channel).accepted)
		for adjustment in [2, 1, 3][channel]:
			assert(scanner.interact(&"adjust", channel).accepted)
		assert(scanner.interact(&"capture", channel).accepted)
	assert(scanner.current_state.completed)
	for enemy in world.get_enemies():
		if enemy.encounter_id == "constellation": enemy.take_damage(999.0)
	var board := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.MEMORY_CONSTELLATION)
	assert(not board.interact().accepted)
	assert(not board.interact(&"replay").accepted)
	assert(board.interact(&"swap", 0).accepted)
	assert(board.interact(&"swap", 1).accepted)
	assert(board.interact(&"replay").completed)
	assert(board.current_state.completed)
	assert(socket.interact().completed, "the restored memory gives the third Spark for a player placement")
	var logic := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.LOGIC_GATE_ARCH)
	assert(logic.interaction_enabled, "3/3 explicitly opens the linked Logic Gate task")
	assert(not logic.interact(&"test").accepted)
	assert(logic.interact(&"trial", 0).accepted)
	assert(logic.interact(&"trial", 1).accepted)
	assert(logic.interact(&"model", 1).accepted)
	assert(logic.interact(&"test").completed)
	assert(world.is_quest_gate_open(1), "Quest Two opens only after its saved evidence chain")
	var lens := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.PERSPECTIVE_LENS)
	for view in 3:
		assert(lens.interact(&"view", view).accepted)
		assert(lens.interact(&"interpret", view).accepted)
	assert(lens.current_state.completed)
	var bridge := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
	assert(bridge.interact(&"approach", 0).accepted)
	for knob in [0, 0, 1]:
		assert(bridge.interact(&"tune", knob).accepted)
	assert(bridge.interact(&"project").completed)
	assert(quest.complete_garden_reflection(), "garden reflection completes the untimed investigation")
	assert(world.is_quest_gate_open(2), "elite guard completion saves the pre-boss checkpoint")
	var boss := world.get_warden() as MindSparkWardenBoss
	for anchor in world.get_quest_objects():
		if anchor.definition.object_kind == QuestObjectDefinition.ObjectKind.WARDEN_ANCHOR:
			anchor.interact(&"dodge")
			anchor.take_damage(25.0)
	assert(boss.phase == MindSparkWardenBoss.Phase.PHASE_3)
	assert(boss.take_damage(300.0) == 300.0)
	var basin := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.CALM_RAIN_BASIN)
	assert(basin.interact(&"hold").completed)
	assert(quest.completed_task_count() == 10 and bool(quest.progress.completed))
	assert(world.is_quest_gate_open(3), "the final quest saves before opening the sanctuary")
	assert(bool(world.get_node("WorldOneGeometry/OptionalCompletedWorldStationSpur").get_meta("available")),
		"the optional station spur becomes available only after completion")
	assert(journey.star_awarded, "Star of Wisdom follows two resolved curated thought echoes")
	assert(player.attack_damage == 30.0 and player.has_node("EquipmentSockets/WisdomBlade/WisdomBladeCrystal"),
		"Wisdom Blade is a visual socket upgrade with the documented 30 damage")
	assert(boss.rain.emitting and not boss.active, "combat remains stopped and the storm becomes gentle rain")
	assert(quest.pending_identity_count() == 8, "all eight optional identity evidence moments are queued")
	for index in 8: quest.call("_record_identity_side", index % 2 == 0)
	assert(identity.identity_evidence_ids.size() == 8 and identity.identity_result_code.is_empty(),
		"Mind Spark stores eight first answers but never chooses an identity")
	world.queue_free()
	await process_frame
	var restored := _new_world(journey, identity)
	root.add_child(restored)
	for _frame in 4: await process_frame
	var restored_quest := restored.get_node("QuestController") as MindSparkWorldOneQuest
	assert(restored_quest.completed_task_count() == 10 and restored.is_quest_gate_open(3),
		"save/reload preserves all quests, gates and completion")
	print("MindSparkWorldOneStory: all checks passed")
	restored.queue_free()
	player.queue_free()
	journey.queue_free()
	identity.queue_free()
	await process_frame
	_cleanup()
	quit()


func _new_world(journey: Node, identity: Node) -> MindSparkWorldOne:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = TEST_OBJECTS
	var quest := world.get_node("QuestController") as MindSparkWorldOneQuest
	quest.force_enable_without_world_hud = true
	quest.save_path = TEST_PROGRESS
	quest.inject_dependencies(journey, identity)
	return world


func _cleanup() -> void:
	for path in [TEST_PROGRESS, TEST_OBJECTS, TEST_IDENTITY]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
