extends SceneTree

const STORE := "user://test_island_two_story_continuity_objects.json"
const PROGRESS := "user://test_island_two_story_continuity_progress.json"
const Rules := preload("res://scripts/mind_spark/unfinished_light_rules.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup()
	var player := CharacterBody3D.new()
	player.add_to_group("Player")
	root.add_child(player)
	var world := _new_world()
	root.add_child(world)
	for _frame in 8:
		await process_frame
	var quest := world.get_node("QuestController") as MindSparkWorldOneQuest
	quest.progress.completed_task_ids = ["wake_two_roots", "collect_two_sparks"]
	quest.progress.completed_quest_ids = ["island_one_awareness"]
	quest.progress.island_two_invitation_received = true
	quest.set("_current_task_index", 2)
	quest.call("_sync_island_two_story_state")
	quest.call("_apply_task_gating")
	assert(str(world.get_meta("island_two_story_state")) == "invited")
	player.global_position = world.to_global(world.get_zone_position("03_constellation_court") + Vector3.UP * 3.0)
	quest.call("_try_begin_island_two_story")
	assert(str(world.get_meta("island_two_story_state")) == "received")

	var scanner := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER)
	for channel in 3:
		for _step in Rules.SCANNER_TARGETS[channel]:
			assert(scanner.interact(&"adjust", channel).accepted)
		assert(scanner.interact(&"capture", channel).accepted)
	assert(quest.current_task().id == "restore_memory")
	assert(str(world.get_meta("island_two_story_state")) == "evidence_sorted")

	var board := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.MEMORY_CONSTELLATION)
	assert(board.interact(&"swap", 0).accepted)
	assert(board.interact(&"swap", 1).accepted)
	assert(board.interact(&"replay").completed)
	assert(quest.current_task().id == "open_logic_gate")
	assert(str(world.get_meta("island_two_story_state")) == "memory_woven")

	var socket := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.THOUGHT_SPARK_SOCKET)
	socket.current_state.progress = 2
	socket.current_state.completed = false
	socket.set_meta("available_sparks", 3)
	assert(socket.interact(&"place_spark").completed)
	var logic := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.LOGIC_GATE_ARCH)
	assert(logic.interaction_enabled)
	for enemy in world.get_enemies():
		if enemy.encounter_id == "constellation":
			enemy.take_damage(999.0)
	assert(logic.interact(&"trial", 0).accepted)
	assert(logic.interact(&"trial", 1).accepted)
	assert(logic.interact(&"model", 1).accepted)
	assert(logic.interact(&"test").completed)
	assert(world.is_quest_gate_open(1))
	assert(str(world.get_meta("island_two_story_state")) == "archive_open")

	var lens := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.PERSPECTIVE_LENS)
	for view in 3:
		assert(lens.interact(&"view", view).accepted)
		assert(lens.interact(&"interpret", view).accepted)
	assert(str(world.get_meta("island_two_story_state")) == "hope_reframed")

	var truth := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
	assert(truth.interact(&"approach", 0).accepted)
	var target: Array = Rules.TARGETS[0]
	for _step in int(target[0]):
		assert(truth.interact(&"tune", 0).accepted)
	for _step in posmod(int(target[1]) - int(target[0]), 4):
		assert(truth.interact(&"tune", 1).accepted)
	var optics: Array = truth.current_state.optics
	for _step in posmod(int(target[2]) - int(optics[2]), 4):
		assert(truth.interact(&"tune", 2).accepted)
	assert(truth.interact(&"project").completed)
	assert(str(world.get_meta("island_two_story_state")) == "truth_materialised")
	assert(quest.complete_garden_reflection(),
		"sharing the completed peaceful experiment must replace the retired combat handoff")
	assert(quest.current_task().id == "free_warden_core")
	assert(str(world.get_meta("island_two_story_state")) == "guardian_freed")
	var reward_path := NodePath(
		"IslandTwoMemoryCampus/HopeMaterialisationConduit/GuardianRewardSocket/RewardHopeCrystal")
	assert((world.get_node(reward_path) as Node3D).visible)
	quest.call("_save_progress")

	world.queue_free()
	await process_frame
	var restored := _new_world()
	root.add_child(restored)
	for _frame in 8:
		await process_frame
	var restored_quest := restored.get_node("QuestController") as MindSparkWorldOneQuest
	assert(restored_quest.current_task().id == "free_warden_core")
	assert(str(restored.get_meta("island_two_story_state")) == "guardian_freed")
	assert(restored.is_quest_gate_open(1))
	assert((restored.get_node(reward_path) as Node3D).visible,
		"the live completion shrine restores after loading saved progress")
	restored.queue_free()
	await process_frame
	_cleanup()
	print("ISLAND_TWO_STORY: PASS — Echo Seed handoff, evidence, memory, archive, perspective, grounded hope, guardian and reload form one continuous quest")
	quit()


func _new_world() -> MindSparkWorldOne:
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STORE
	var quest := world.get_node("QuestController") as MindSparkWorldOneQuest
	quest.force_enable_without_world_hud = true
	quest.save_path = PROGRESS
	return world


func _cleanup() -> void:
	for path in [STORE, PROGRESS]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
