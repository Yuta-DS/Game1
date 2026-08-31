extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("SURROUND_AUDIO_COVERAGE_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var total_sources := 0
	for scene_path in ["res://scenes/New_Hub_World.tscn", "res://scenes/art_gallery_3d_inprogress.tscn"]:
		var packed := load(scene_path) as PackedScene
		if packed == null:
			_fail("cannot load %s" % scene_path)
			return
		var scene := packed.instantiate()
		root.add_child(scene)
		current_scene = scene
		for _frame in 18:
			await process_frame
		var sources := scene.find_children("*", "AudioStreamPlayer3D", true, false)
		if sources.is_empty():
			_fail("%s has no physical 3D sound sources" % scene_path)
			return
		for candidate in sources:
			var source := candidate as AudioStreamPlayer3D
			if not bool(source.get_meta("surround_7_1_ready", false)):
				_fail("%s was not registered for surround" % source.get_path())
				return
			if source.panning_strength != 1.0 or source.area_mask != 1:
				_fail("%s lacks full direction or reverb-area routing" % source.get_path())
				return
			if source.attenuation_model != AudioStreamPlayer3D.ATTENUATION_DISABLED \
					and source.max_distance <= 0.0:
				_fail("%s has unbounded distance audio" % source.get_path())
				return
		if scene_path.ends_with("art_gallery_3d_inprogress.tscn"):
			var managed_trains := scene.find_children("*", "Node3D", true, false).filter(
				func(node: Node): return node.has_meta("spatial_train_audio"))
			if managed_trains.size() != 1:
				_fail("the gallery must have exactly one managed Crown train, found %d" % managed_trains.size())
				return
		total_sources += sources.size()
		current_scene = null
		root.remove_child(scene)
		scene.queue_free()
		for _frame in 8:
			await process_frame
	print("SURROUND_AUDIO_COVERAGE_TEST: PASS — %d physical sources across hub and gallery are 7.1-ready with automatic stereo fallback" % total_sources)
	quit()
