extends SceneTree

const WorldScript := preload("res://scripts/mind_spark/mind_spark_world_one.gd")
const QuestScript := preload("res://scripts/mind_spark/mind_spark_world_one_quest.gd")
const PlayerScene := preload("res://scenes/player_3d.tscn")
const EnemyScene := preload("res://scenes/mind_spark/combat/enemy_base.tscn")
const MiteDefinition := preload("res://resources/mind_spark/enemies/static_mite.tres")
const TEST_SAVE := "user://test_world_one_combat_recovery_flow.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var progression := root.get_node("WorldOneProgression")
	progression.configure_save_path(TEST_SAVE, false)
	progression.clear_progress()

	var player := PlayerScene.instantiate() as CharacterBody3D
	player.add_to_group("Player")
	root.add_child(player)
	var world := WorldScript.new() as MindSparkWorldOne
	world.defer_world_build = true
	world.build_hud = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	var enemy := EnemyScene.instantiate() as MindSparkEnemyBase
	enemy.definition = MiteDefinition
	enemy.encounter_id = "network"
	world.add_child(enemy)
	var enemies: Array[MindSparkEnemyBase] = [enemy]
	world.set("_enemies", enemies)
	world.set("_enemy_waves", {"network": [enemy]})
	var controller := QuestScript.new() as MindSparkWorldOneQuest
	controller.force_enable_without_world_hud = true
	controller.save_path = "user://test_world_one_combat_recovery_story.json"
	controller.process_mode = Node.PROCESS_MODE_DISABLED
	controller.inject_dependencies(root.get_node_or_null("JourneyState"),
		root.get_node_or_null("PlayerIdentityTracker"))
	world.add_child(controller)
	await process_frame
	await process_frame

	var safe_position := Vector3(9.0, 3.0, -4.0)
	world.set("_last_safe_position", safe_position)
	assert(world.activate_enemy_wave("network") == 1 and enemy.active)
	enemy.current_health = 3.0
	player.global_position = Vector3(-30.0, 8.0, 12.0)
	player.take_damage(999.0, enemy)
	assert(not bool(player.get("input_enabled")),
		"lethal damage must suspend movement during the short recovery beat")
	await create_timer(1.25).timeout
	assert(is_equal_approx(float(player.get("current_health")), float(player.get("max_health"))) \
		and bool(player.get("input_enabled")),
		"the quest controller must restore health and player control")
	var respawn_flat := Vector2(player.global_position.x, player.global_position.z)
	var safe_flat := Vector2(safe_position.x, safe_position.z)
	assert(respawn_flat.distance_to(safe_flat) < 0.01 \
		and player.global_position.y <= safe_position.y \
		and player.global_position.y > safe_position.y - 5.0,
		"combat retry returns the player to World One's latest supported ground")
	assert(enemy.active and enemy.state == MindSparkEnemyBase.State.IDLE \
		and is_equal_approx(enemy.current_health, enemy.definition.max_health),
		"combat retry resets only the active encounter wave")

	controller.queue_free()
	world.queue_free()
	player.queue_free()
	progression.clear_progress()
	await process_frame
	print("WORLD_ONE_COMBAT_RECOVERY_FLOW: PASS — lethal damage pauses, resets the bounded wave, respawns safely, and restores control")
	quit()
