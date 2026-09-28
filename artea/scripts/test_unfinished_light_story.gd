extends SceneTree
const STORE := "user://unfinished_light_test_objects.json"
const SAVE := "user://unfinished_light_test_progress.json"
const Rules := preload("res://scripts/mind_spark/unfinished_light_rules.gd")
var world: MindSparkWorldOne
var quest: MindSparkWorldOneQuest

func _init() -> void:
	call_deferred("run")

func make_world() -> void:
	world = load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate()
	world.build_hud = false
	world.object_state_store_path = STORE
	quest = world.get_node("QuestController")
	quest.force_enable_without_world_hud = true
	quest.save_path = SAVE
	root.add_child(world)
	await process_frame

func use(id: int, action: StringName, value: Variant = null, expected := true) -> void:
	var station: QuestObjectBase = null
	if station == null:
		for item in world.get_quest_objects():
			if item.save_id == Rules.IDS[id]: station = item
	assert(station != null)
	var result: Dictionary = station.interact(action, value)
	assert(bool(result.accepted) == expected, str(result))

func station_at(index: int) -> QuestObjectBase:
	for item in world.get_quest_objects():
		if item.save_id == Rules.IDS[index]: return item
	return null

func run() -> void:
	for path in [STORE, SAVE]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await make_world()
	assert(quest.QUESTS.size() == 5)
	quest.progress.completed_task_ids = ["wake_two_roots", "collect_two_sparks"]
	quest.progress.completed_quest_ids = ["island_one_awareness"]
	quest.call("_restore_runtime_state")
	quest.call("_apply_task_gating")
	assert(quest.progress.completed_quest_ids.has("notice_signal"))
	assert(not quest.complete_garden_reflection())
	use(4, &"project", null, false)
	use(0, &"capture", 0, false)
	for i in 3:
		for step in [2, 1, 3][i]: use(0, &"adjust", i)
		use(0, &"capture", i)
	assert(quest.current_task().id == "restore_memory")
	use(1, &"replay", null, false)
	use(1, &"swap", 0)
	quest.call("_save_progress")
	var xp: int = quest.progress.xp
	world.queue_free()
	await process_frame
	await make_world()
	assert(station_at(1).current_state.timeline.map(func(v): return int(v)) == [0, 2, 1])
	assert(station_at(0).current_state.completed)
	assert(quest.progress.xp == xp)
	use(1, &"swap", 1)
	use(1, &"replay")
	assert(quest.current_task().id == "open_logic_gate")
	for enemy in world.get_enemies():
		if enemy.encounter_id == "constellation":
			enemy.take_damage(999.0)
	var socket := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.THOUGHT_SPARK_SOCKET)
	socket.current_state.progress = 2
	socket.current_state.completed = false
	socket.set_meta("available_sparks", 3)
	assert(socket.interact(&"place_spark").completed)
	use(2, &"model", 0)
	use(2, &"test", null, false)
	use(2, &"model", 1)
	use(2, &"test", null, false)
	use(2, &"trial", 0)
	use(2, &"trial", 1)
	use(2, &"test")
	assert(quest.current_task().id == "turn_lens")
	assert(world.is_quest_gate_open(1))
	for i in 3:
		use(3, &"view", i)
		use(3, &"interpret", (i + 1) % 3, false)
		use(3, &"interpret", i)
	assert(quest.current_task().id == "form_truth_bridge")
	for approach in 3:
		var projector := station_at(4)
		projector.current_state.completed = false
		projector.set("_completion_emitted", false)
		projector.interaction_enabled = true
		use(4, &"approach", approach)
		if approach == 2:
			use(4, &"tune", 0, false)
			use(4, &"cooling")
		use(4, &"project", null, false)
		use(4, &"tune", 0)
		use(4, &"undo")
		assert(projector.current_state.optics == ([0, 0, 3] if approach == 1 else [0, 0, 0]))
		var target: Array = Rules.TARGETS[approach]
		for step in int(target[0]): use(4, &"tune", 0)
		for step in posmod(int(target[1]) - int(target[0]), 4): use(4, &"tune", 1)
		var optics: Array = projector.current_state.optics
		for step in posmod(int(target[2]) - int(optics[2]), 4): use(4, &"tune", 2)
		use(4, &"project")
		assert(projector.current_state.completed)
	assert(quest.current_task().id == "clear_elite_guard")
	assert(quest.complete_garden_reflection())
	assert(not quest.complete_garden_reflection())
	assert(quest.current_task().id == "free_warden_core")
	assert(world.is_quest_gate_open(2))
	assert(quest.progress.defeated_enemy_ids.is_empty())
	quest.call("_save_progress")
	world.queue_free()
	await process_frame
	await make_world()
	assert(quest.current_task().id == "free_warden_core")
	assert(quest.progress.garden_approach == Rules.APPROACHES[2])
	# Controls must build for every station, including the post-completion action.
	# Older saved restorations used a text result instead of the new dictionary.
	station_at(4).current_state["result"] = "legacy restoration"
	var actor := Node3D.new()
	world.add_child(actor)
	for i in 5:
		var panel := preload("res://scripts/mind_spark/island_two_station_panel.gd").new()
		world.add_child(panel)
		actor.global_position = station_at(i).global_position
		panel.open_object(station_at(i), actor, 18)
		assert(panel.find_children("*", "Button", true, false).size() > 0)
		panel.queue_free()
		await process_frame
	world.queue_free()
	await process_frame
	for path in [STORE, SAVE]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("UNFINISHED_LIGHT: PASS — five quests, legacy migration, incorrect models, local revision, partial reload, three optical approaches, undo, peaceful handoff and panel controls")
	quit()
