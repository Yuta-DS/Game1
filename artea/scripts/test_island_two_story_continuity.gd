extends SceneTree

const STORE := "user://test_island_two_story_continuity_objects.json"
const PROGRESS := "user://test_island_two_story_continuity_progress.json"


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
	for answer in [&"fact", &"fear", &"fact"]:
		assert(scanner.interact(&"scan").accepted)
		assert(scanner.interact(answer).accepted)
	assert(quest.current_task().id == "restore_memory")
	assert(str(world.get_meta("island_two_story_state")) == "evidence_sorted")

	var board := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.MEMORY_CONSTELLATION)
	for memory_step in ["notice", "name", "choose"]:
		assert(board.interact(&"node", memory_step).accepted)
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
	assert(logic.interact(&"place_evidence").accepted)
	assert(logic.interact(&"place_evidence").completed)
	assert(world.is_quest_gate_open(1))
	assert(str(world.get_meta("island_two_story_state")) == "archive_open")

	var lens := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.PERSPECTIVE_LENS)
	assert(lens.interact(&"turn").accepted)
	assert(lens.interact(&"turn").accepted)
	assert(lens.interact(&"turn").completed)
	assert(str(world.get_meta("island_two_story_state")) == "hope_reframed")

	var truth := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.TRUTH_BRIDGE_TILE)
	assert(not truth.interact(&"fear").accepted)
	assert(not truth.interact(&"fantasy").accepted)
	assert(truth.interact(&"true").completed)
	assert(str(world.get_meta("island_two_story_state")) == "truth_materialised")
	for enemy in world.get_enemies():
		if enemy.encounter_id == "ridge":
			enemy.take_damage(999.0)
	assert(quest.current_task().id == "free_warden_core")
	assert(str(world.get_meta("island_two_story_state")) == "guardian_freed")
	assert((world.get_node("IslandTwoMemoryCampus/EliteGuardianCourt/GuardianRewardSocket/RewardHopeCrystal") as Node3D).visible)
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
