extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	root.add_child(world)
	for _frame in 6:
		await physics_frame

	var soundscape := world.get_node(
		"WorldOneGeometry/ThreeIslandEnvironmentAudio") as Node3D
	assert(soundscape != null, "the fused World One owns its local environment soundscape")
	assert(str(soundscape.get_meta("design_revision", "")) == "district_soundscape_v1")
	assert(not bool(soundscape.get_meta("quest_evidence_audio_only", true)),
		"environment sound never carries required puzzle evidence")

	var expected := {
		"IslandOneCanopyWind": [1, "living canopy"],
		"IslandTwoMemoryEngine": [2, "memory observatory machinery"],
		"IslandThreeStormworksEngine": [3, "stormworks civic machinery"],
		"IslandThreeOldestTreeWind": [3, "oldest tree canopy"],
		"RainHarvestRecoveryWater": [3, "recovered rain water"],
	}
	for source_name in expected:
		var source := soundscape.get_node(str(source_name)) as AudioStreamPlayer3D
		assert(source != null and source.stream != null,
			"%s has a playable 3D stream" % source_name)
		assert(source.autoplay and bool(source.get_meta("continuous_loop", false)),
			"%s remains active for the whole district visit" % source_name)
		assert(source.playback_type == AudioServer.PLAYBACK_TYPE_STREAM,
			"%s uses the portable Web streaming path" % source_name)
		assert(source.max_distance >= 150.0 and source.unit_size == 34.0,
			"%s uses bounded positional falloff" % source_name)
		assert(int(source.get_meta("physical_island", 0)) == int(expected[source_name][0]))
		assert(str(source.get_meta("sound_role", "")) == str(expected[source_name][1]))
		if source.stream is AudioStreamOggVorbis:
			assert((source.stream as AudioStreamOggVorbis).loop,
				"%s duplicates and loops its imported Ogg stream" % source_name)
		elif source.stream is AudioStreamWAV:
			assert((source.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD,
				"%s duplicates and loops its imported WAV stream" % source_name)
			assert((source.stream as AudioStreamWAV).loop_end
				> (source.stream as AudioStreamWAV).loop_begin,
				"%s has a non-empty WAV loop region" % source_name)

	# Every ambience source constructed in the active blueprint passes through
	# the same loop-safe helper; compact and galaxy modes may add two more beds.
	var continuous_sources := world.find_children("*", "AudioStreamPlayer3D", true, false) \
		.filter(func(node: Node) -> bool: return bool(node.get_meta("continuous_loop", false)))
	assert(continuous_sources.size() >= 5,
		"all five fused-island environment layers remain continuous")

	var rain := soundscape.get_node("RainHarvestRecoveryWater") as AudioStreamPlayer3D
	assert(is_equal_approx(rain.volume_db, -80.0)
		and str(rain.get_meta("unlocks_on_world_state", "")) == "gentle_rain",
		"recovery water is inaudible before the rain story beat")
	world.set_world_state("gentle_rain")
	assert(is_equal_approx(float(rain.get_meta("target_volume_db", -80.0)), -24.0),
		"gentle-rain recovery fades the observatory water layer in")
	world.set_world_state("waking")
	assert(is_equal_approx(float(rain.get_meta("target_volume_db", 0.0)), -80.0),
		"leaving the recovered state fades the water layer out")

	world.queue_free()
	await process_frame
	print("WORLD_ONE_ENVIRONMENT_AUDIO: PASS — three local island identities and stateful recovery rain")
	quit()
