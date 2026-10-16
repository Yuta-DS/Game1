extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("WORLD_SPATIAL_AUDIO_INTEGRATION_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var packed := load("res://scenes/New_Hub_World.tscn") as PackedScene
	if packed == null:
		_fail("hub scene must load")
		return
	var hub := packed.instantiate() as Node3D
	root.add_child(hub)
	current_scene = hub
	for _frame in 12:
		await process_frame

	var managed_trains := 0
	for candidate in hub.find_children("*", "Node3D", true, false):
		var node := candidate as Node3D
		if node.has_meta("spatial_train_audio"):
			managed_trains += 1
			if node.get_node_or_null("TractionEngine3D") == null \
					or node.get_node_or_null("RailClatter3D") == null \
					or node.get_node_or_null("TravelWind3D") == null \
					or node.get_node_or_null("TrainEvents3D") == null:
				_fail("every discovered hub train must carry all four sound layers")
				return
	var named_emitters := 0
	var emitter_profiles := {}
	for candidate in hub.find_children("*", "Node3D", true, false):
		var node := candidate as Node3D
		if node.has_meta("spatial_world_emitter"):
			named_emitters += 1
			var kind: StringName = node.get_meta("spatial_world_emitter")
			emitter_profiles[kind] = int(emitter_profiles.get(kind, 0)) + 1
			if node.get_node_or_null("ObjectAmbience_%s" % String(kind)) == null:
				_fail("named %s emitter must own its attached AudioStreamPlayer3D" % kind)
				return
	if named_emitters < 3 or named_emitters > 5 \
			or int(emitter_profiles.get(&"cave_air", 0)) < 2 \
			or int(emitter_profiles.get(&"aether_power", 0)) < 1:
		_fail("hub should emit only from real cave-air and aether sources; found %s" % emitter_profiles)
		return
	for static_name in ["cl_blacksmith", "building_windmill_red2", "building_watermill_red2"]:
		for candidate in hub.find_children("*%s*" % static_name, "Node3D", true, false):
			if (candidate as Node3D).has_meta("spatial_world_emitter"):
				_fail("static %s must not play a continuous machine loop" % static_name)
				return
	for candidate in hub.find_children("*Station*", "Node3D", true, false):
		if (candidate as Node3D).has_meta("spatial_world_emitter"):
			_fail("an empty static station must be silent until a train supplies its sound")
			return
	var player := hub.get_node_or_null("NewPlayer") as CharacterBody3D
	if player == null or player.get_node_or_null("SurfaceFootsteps3D") == null \
			or player.get_node_or_null("VegetationBrush3D") == null:
		_fail("the live player needs separate positional foot-impact and foliage-brush sources")
		return
	var director := root.get_node_or_null("WorldSpatialAudio")
	if director == null or (director.get("_vegetation_anchors") as Array).size() < 8:
		_fail("the live hub should expose placed bushes/trees for pass-by brushing")
		return
	var surround_sources := hub.find_children("*", "AudioStreamPlayer3D", true, false)
	if surround_sources.size() < 10:
		_fail("the live hub should expose its physical sounds as 3D surround sources")
		return
	for candidate in surround_sources:
		var source := candidate as AudioStreamPlayer3D
		if not bool(source.get_meta("surround_7_1_ready", false)) \
				or source.panning_strength != 1.0 or source.area_mask != 1:
			_fail("live source %s bypassed the 7.1 surround policy" % source.get_path())
			return
		if source.attenuation_model != AudioStreamPlayer3D.ATTENUATION_DISABLED \
				and source.max_distance <= 0.0:
			_fail("live source %s needs a finite distance response" % source.get_path())
			return

	print("WORLD_SPATIAL_AUDIO_INTEGRATION_TEST: PASS — %d live physical sounds are 7.1-ready; %d genuine object sources and %d vegetation anchors remain contextual (%d dormant hub shuttles detected)" % [surround_sources.size(), named_emitters, (director.get("_vegetation_anchors") as Array).size(), managed_trains])
	quit()
