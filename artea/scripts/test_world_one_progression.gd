extends SceneTree

const ProgressionScript := preload("res://scripts/world_one_progression.gd")
const TEST_PATH := "user://test_world_one_progression.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := ProgressionScript.new()
	root.add_child(state)
	state.configure_save_path(TEST_PATH, false)
	state.clear_progress()
	state.call("_load_catalog")
	assert(state.get_xp_thresholds() == PackedInt32Array(
		[0, 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700]))
	assert(state.get_all_item_definitions().size() == 19,
		"the authored catalog contains sixteen equipment pieces and three materials")
	assert(state.get_all_skill_definitions().size() == 12,
		"the skill catalog exposes four nodes in each of three branches")

	var landing := state.grant_quest_reward("world_one.checkpoint.landing")
	assert(landing.accepted and state.xp == 40 and state.spark_shards == 30)
	assert(state.has_item("signal_outfit") and state.item_quantity("signal_glass") == 2)
	assert(not state.grant_quest_reward("world_one.checkpoint.landing").accepted,
		"first-clear receipts prevent duplicate story rewards")
	state.grant_quest_reward("world_one.path_projector")
	assert(state.level == 2 and state.skill_points == 1,
		"the fixed XP curve awards one point at level two")
	assert("upgrade_signal_blade_1" in state.unlocked_recipes,
		"quest rewards expose authored recipes at the matching island station")
	assert(state.equip_item("signal_blade").accepted \
		and state.equipped.blade == "signal_blade")
	assert(state.unlock_skill("insight_scan").accepted and state.skill_points == 0)
	assert(not state.unlock_skill("insight_weakpoint").accepted,
		"skills require both their prerequisite and an available point")
	state.grant_item("signal_glass", 1, "craft:material")
	assert(state.craft_upgrade("upgrade_signal_blade_1", 1).accepted,
		"an unlocked recipe consumes its authored currency and material cost")

	for index in 35:
		state.grant_item("signal_blade" if index % 2 == 0 else "signal_shield", 1,
			"overflow:%d" % index)
	assert(state.inventory.size() == state.INVENTORY_CAPACITY)
	assert(not state.checkpoint_storage.is_empty(),
		"full inventory rewards move to checkpoint storage without loss")
	assert(state.save_progress())

	var restored := ProgressionScript.new()
	root.add_child(restored)
	restored.configure_save_path(TEST_PATH, false)
	restored.call("_load_catalog")
	assert(restored.load_progress() and restored.snapshot() == state.snapshot(),
		"progression saves round-trip exactly")
	var corrupt := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()
	assert(restored.load_progress() and restored.has_item("signal_blade"),
		"a corrupt primary save recovers from the persistent backup")

	state.clear_progress()
	restored.clear_progress()
	state.queue_free()
	restored.queue_free()
	await process_frame
	print("WORLD_ONE_PROGRESSION: PASS — catalog, rewards, levels, skills, equipment, overflow and atomic recovery")
	quit()
