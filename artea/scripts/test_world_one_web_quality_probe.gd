extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const StateStore := preload("res://scripts/mind_spark/quest_objects/quest_object_state_store.gd")

const TEST_PATH := "user://test_world_one_web_quality_probe.json"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var store := StateStore.new(TEST_PATH)
	store.clear()
	assert(store.save_object("world_one.checkpoint.landing", {
		"completed": false,
		"last_action": "heal",
	}), "the restoration fixture must be saved")
	OS.set_environment("ARTEA_WORLD_ONE_WEB_QUALITY", "1")
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = TEST_PATH
	root.add_child(world)
	await process_frame
	assert(bool(world.get_meta("web_quality_probe_enabled", false)),
		"the world must expose that the opt-in quality verification is active")
	var waited := 0
	while world.has_node("WorldOneWebQualityProbe") and waited < 600:
		await process_frame
		waited += 1
	assert(bool(world.get_meta("web_quality_probe_completed", false)),
		"the browser verifier must finish all object input and persistence checks")
	var report: Dictionary = world.get_meta("web_quality_results", {})
	assert(bool(report.get("ok", false)), "the full browser quality report must pass: %s" % report)
	assert(int(report.get("fresh_completed", -1)) == 0,
		"the verifier begins from a fresh temporary state")
	assert(int(report.get("fresh_saved", -1)) == 0,
		"the isolated store contains no inherited player progress")
	assert(int(report.get("partial_saved", 0)) == 7,
		"the partial-progress checkpoint persists the first seven object states")
	assert(int(report.get("accepted_rewards", 0)) == 15 \
		and int(report.get("saved_objects", 0)) == 15,
		"all 15 mini-games complete and round-trip through browser-compatible storage")
	assert(int(report.get("durable_completed", 0)) == 10,
		"10 objects complete; two checkpoints, two utility tools and the incremental spark socket retain live state")
	assert(int(report.get("modes", 0)) == 5 and int(report.get("touch_modes", 0)) == 5,
		"every distinct game mode is driven through keyboard and touch paths")
	var checkpoint: QuestObjectBase
	for object in world.get_quest_objects():
		if object.save_id == "world_one.checkpoint.landing":
			checkpoint = object
			break
	assert(checkpoint != null and str(checkpoint.current_state.get("last_action", "")) == "heal",
		"the player's pre-probe object state is restored exactly")
	OS.set_environment("ARTEA_WORLD_ONE_WEB_QUALITY", "")
	world.call("_install_web_quality_probe")
	assert(not world.has_node("WorldOneWebQualityProbe"),
		"normal production sessions keep the diagnostic dormant")
	world.queue_free()
	store.clear()
	print("WORLD_ONE_WEB_QUALITY_PROBE_TEST: PASS — 15 rewards, fresh/partial/full saves, five keyboard and touch modes, and live-state restoration")
	quit()
