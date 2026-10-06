extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("ARTEA_WORLD_ONE_WEB_PERF", "1")
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://test_world_one_web_perf_probe.json"
	root.add_child(world)
	await process_frame
	assert(world.has_node("WorldOneWebPerfProbe"),
		"the opt-in production benchmark must attach after World One is built")
	assert(bool(world.get_meta("web_perf_probe_enabled", false)),
		"the world must expose that diagnostic sampling is active")
	var waited := 0
	while world.has_node("WorldOneWebPerfProbe") and waited < 2600:
		await process_frame
		waited += 1
	assert(bool(world.get_meta("web_perf_probe_completed", false)),
		"the benchmark must complete all production-camera samples")
	assert(bool(world.get_meta("web_perf_evidence_camera_on_dais", false))
			and float(world.get_meta("web_perf_evidence_camera_distance", INF)) < 30.0,
		"the Evidence Court benchmark must use the unscaled production operator camera")
	var results: Array = world.get_meta("web_perf_results", [])
	assert(results.size() == 9,
		"the benchmark must report four environment views and all five active mini-game modes")
	var environment_views := 0
	var active_modes := {}
	for result in results:
		var active := str(result.get("kind", "")) == "active_minigame"
		var expected_frames := 120 if active else 240
		assert(int(result.get("frames", 0)) == expected_frames \
				and float(result.get("mean_ms", 0.0)) > 0.0 \
				and float(result.get("process_mean_ms", 0.0)) > 0.0 \
				and int(result.get("spike_count", -1)) >= 0 \
				and result.has("spike_frames"),
			"every review view must contain complete frame, process and spike evidence")
		if active:
			active_modes[str(result.get("mode", ""))] = true
		else:
			environment_views += 1
	assert(environment_views == 4 and active_modes.size() == 5,
		"the benchmark must keep four matched environments and five distinct live game modes")
	OS.set_environment("ARTEA_WORLD_ONE_WEB_PERF", "")
	print("WORLD_ONE_WEB_PERF_PROBE: PASS — four environments and five active mini-games sampled; normal URL remains dormant")
	quit()
