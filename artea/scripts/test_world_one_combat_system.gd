extends SceneTree

const PlayerScene := preload("res://scenes/player_3d.tscn")
const EnemyScene := preload("res://scenes/mind_spark/combat/enemy_base.tscn")
const WardenScene := preload("res://scenes/mind_spark/combat/thought_storm_warden.tscn")
const QuestObjectScene := preload("res://scenes/mind_spark/quest_objects/quest_object_base.tscn")
const AnchorDefinition := preload("res://resources/mind_spark/quest_objects/08_warden_anchor.tres")
const SentinelDefinition := preload("res://resources/mind_spark/enemies/blight_sentinel.tres")
const TEST_SAVE := "user://test_world_one_combat_system.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var progression := root.get_node("WorldOneProgression")
	progression.configure_save_path(TEST_SAVE, false)
	progression.clear_progress()
	for physics_rate in [30, 60, 120]:
		var player := PlayerScene.instantiate() as CharacterBody3D
		root.add_child(player)
		await process_frame
		player.call("_set_focus", 100.0)
		Input.action_press("block")
		var delta := 1.0 / float(physics_rate)
		for _frame in physics_rate:
			player.call("_update_block", delta)
		Input.action_release("block")
		player.call("_set_blocking", false)
		assert(is_equal_approx(float(player.get("current_focus")), 85.0),
			"blocking must cost 15 Focus per second at %d physics FPS" % physics_rate)
		player.set("_focus_recovery_delay_remaining", 0.0)
		for _frame in physics_rate:
			player.call("_update_combat", delta)
		assert(absf(float(player.get("current_focus")) - 100.0) < 0.01,
			"Focus recovery must be stable at %d physics FPS" % physics_rate)
		player.call("take_damage", 999.0)
		assert(float(player.get("current_health")) == 0.0,
			"lethal combat damage must enter the defeat state")
		player.call("recover_from_combat_failure")
		assert(is_equal_approx(float(player.get("current_health")), float(player.get("max_health"))) \
			and is_equal_approx(float(player.get("current_focus")), float(player.get("max_focus"))) \
			and float(player.get("_invulnerability_remaining")) >= 0.99,
			"encounter recovery restores health, Focus and a safe retry grace window")
		player.queue_free()
		await process_frame

	assert(progression.set_assistance(true))
	var enemy := EnemyScene.instantiate() as CharacterBody3D
	enemy.set("definition", SentinelDefinition)
	root.add_child(enemy)
	await process_frame
	enemy.call("_set_state", 2, 1.0)
	assert(is_equal_approx(float(enemy.get("_state_time")), 1.25),
		"adaptive assistance must lengthen enemy telegraphs by 25%")
	enemy.call("receive_knockback", Vector3.RIGHT, 8.0)
	assert((enemy.get("_knockback_velocity") as Vector3).x > 7.9,
		"combat impacts must deliver directional knockback")
	enemy.queue_free()
	var warden := WardenScene.instantiate()
	root.add_child(warden)
	await process_frame
	assert(is_equal_approx(float(warden.call("_assisted_telegraph_seconds")), 1.4375),
		"Warden telegraphs must use the same optional 25% assistance modifier")
	var anchors: Array[QuestObjectBase] = []
	for index in 3:
		var anchor := QuestObjectScene.instantiate() as QuestObjectBase
		anchor.definition = AnchorDefinition
		anchor.save_id = "test.combat.anchor.%d" % index
		anchor.persist_state = false
		root.add_child(anchor)
		anchors.append(anchor)
	await process_frame
	warden.bind_anchors(anchors)
	warden.start_battle()
	anchors[0].interact(&"dodge")
	anchors[0].interact(&"strike")
	assert(warden.phase == MindSparkWardenBoss.Phase.PHASE_2,
		"breaking the first anchor enters the second boss phase")
	warden.restart_current_phase()
	assert(warden.phase == MindSparkWardenBoss.Phase.PHASE_2 \
		and bool(anchors[0].current_state.get("completed", false)) \
		and not bool(anchors[1].current_state.get("completed", false)),
		"assisted retry preserves completed anchors and resets unfinished layers")
	for index in [1, 2]:
		anchors[index].interact(&"dodge")
		anchors[index].interact(&"strike")
	warden.take_damage(125.0)
	assert(float(warden.current_health) < float(warden.definition.max_health))
	warden.restart_current_phase()
	assert(warden.phase == MindSparkWardenBoss.Phase.PHASE_3 \
		and is_equal_approx(float(warden.current_health), float(warden.definition.max_health)),
		"phase-three retry keeps the open core but restarts its health budget")
	for anchor in anchors:
		anchor.queue_free()
	warden.queue_free()
	progression.clear_progress()
	await process_frame
	print("WORLD_ONE_COMBAT_SYSTEM: PASS — Focus, defeat recovery, boss phase retry, assistance and knockback are stable at 30/60/120 FPS")
	quit()
