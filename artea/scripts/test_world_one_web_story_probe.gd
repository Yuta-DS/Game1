extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const PlayerScene := preload("res://scenes/player_3d.tscn")
const IdentityTrackerScript := preload("res://scripts/player_identity_tracker.gd")
const StoryProbeScript := preload("res://scripts/mind_spark/world_one_web_story_probe.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var first_web_paths: Array[String] = StoryProbeScript.isolated_story_paths("first", true)
	var second_web_paths: Array[String] = StoryProbeScript.isolated_story_paths("second", true)
	var native_paths: Array[String] = StoryProbeScript.isolated_story_paths("native_nonce", false)
	assert(first_web_paths == second_web_paths and first_web_paths.size() == 4,
		"browser diagnostics must reuse a bounded set of isolated IDB files")
	assert(native_paths != first_web_paths
		and native_paths.all(func(path: String): return "native_nonce" in path),
		"native diagnostics retain unique temporary paths for immediate cleanup")
	OS.set_environment("ARTEA_WORLD_ONE_WEB_STORY", "1")
	var player := PlayerScene.instantiate() as CharacterBody3D
	player.add_to_group("Player")
	root.add_child(player)
	var identity := IdentityTrackerScript.new()
	identity.name = "PlayerIdentityTracker"
	root.add_child(identity)
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	var quest := world.get_node("QuestController") as MindSparkWorldOneQuest
	quest.force_enable_without_world_hud = true
	root.add_child(world)
	for _frame in 12:
		await process_frame
	assert(bool(world.get_meta("web_story_probe_enabled", false)),
		"the connected story probe is installed only when explicitly requested")
	assert(bool(world.get_meta("web_story_probe_completed", false)),
		"the connected story probe completes")
	var report: Dictionary = world.get_meta("web_story_results", {})
	assert(bool(report.get("ok", false)), "connected story report must pass: %s" % report)
	assert(int(report.get("tasks_completed", 0)) == 10
		and int(report.get("quests_completed", 0)) == 5,
		"all ten tasks and five quests progress through the live signal graph")
	assert(str(report.get("island_two_state", "")) == "guardian_freed",
		"Island 2 reaches its completed narrative state")
	assert(bool(report.get("gentle_rain", false))
		and bool(report.get("reflection_completed", false))
		and bool(report.get("oldest_tree_awake", false)),
		"Warden recovery, reflection and Oldest Tree conclusion all activate")
	assert(bool(report.get("star_awarded", false))
		and bool(report.get("save_reload_completed", false))
		and bool(report.get("temporary_save_isolation", false)),
		"reward and reload pass without writing to the player's save files")
	OS.set_environment("ARTEA_WORLD_ONE_WEB_STORY", "")
	world.call("_install_web_story_probe")
	assert(not world.has_node("WorldOneWebStoryProbe"),
		"normal production sessions keep the connected story diagnostic dormant")
	world.queue_free()
	player.queue_free()
	identity.queue_free()
	await process_frame
	print("WORLD_ONE_WEB_STORY_PROBE_TEST: PASS — connected 10-task story, Warden, rain, reflection, Oldest Tree, reward and reload")
	quit()
