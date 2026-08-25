extends SceneTree

const ProceduralFoleyScript := preload("res://scripts/procedural_foley.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("WORLD_SPATIAL_AUDIO_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var first_variant_data: Dictionary = {}
	for surface in [&"grass", &"earth", &"sand", &"gravel", &"brick", &"stone", &"wood", &"metal"]:
		for variant in 4:
			var stream := ProceduralFoleyScript.make_footstep(surface, variant)
			if stream == null or stream.data.size() < 1000 or stream.mix_rate != 22050:
				_fail("%s variant %d needs a generated 16-bit footstep stream" % [surface, variant])
				return
			if variant == 0:
				first_variant_data[surface] = stream.data
			elif stream.data == first_variant_data[surface]:
				_fail("%s footsteps need real deterministic variants, not pitch-only repetition" % surface)
				return
	if first_variant_data[&"grass"] == first_variant_data[&"metal"] \
			or first_variant_data[&"brick"] == first_variant_data[&"metal"] \
			or first_variant_data[&"stone"] == first_variant_data[&"metal"]:
		_fail("grass, brick and stone must not reuse the intentionally ringing metal waveform")
		return
	var brush := ProceduralFoleyScript.make_vegetation_brush(0)
	if brush == null or brush.loop_mode != AudioStreamWAV.LOOP_DISABLED or brush.data.size() < 18000:
		_fail("passing vegetation needs its own substantial non-looping swish")
		return
	var wind := ProceduralFoleyScript.make_wind_loop(2603, true)
	if wind.loop_mode != AudioStreamWAV.LOOP_FORWARD or wind.loop_end <= wind.loop_begin:
		_fail("tree wind must be a seamless generated loop")
		return
	for layer in [&"engine", &"rail"]:
		var train_loop := ProceduralFoleyScript.make_train_loop(layer)
		if train_loop.loop_mode != AudioStreamWAV.LOOP_FORWARD \
				or train_loop.data.size() < 40000:
			_fail("%s train layer must be a substantial generated loop" % layer)
			return
	for event_name in [&"departure", &"brake"]:
		var train_event := ProceduralFoleyScript.make_train_event(event_name)
		if train_event.loop_mode != AudioStreamWAV.LOOP_DISABLED \
				or train_event.data.size() < 20000:
			_fail("%s must be a generated one-shot train event" % event_name)
			return
	for object_kind in [&"mechanism", &"forge", &"cavern", &"station", &"magic"]:
		var object_loop := ProceduralFoleyScript.make_world_object_loop(object_kind)
		if object_loop.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			_fail("%s world-object ambience must loop" % object_kind)
			return

	var director := root.get_node_or_null("WorldSpatialAudio")
	if director == null:
		_fail("WorldSpatialAudio must be registered as an autoload")
		return
	if not is_equal_approx(float(ProjectSettings.get_setting(
			"audio/general/3d_panning_strength", 0.0)), 1.0) \
			or not is_equal_approx(float(ProjectSettings.get_setting(
			"audio/general/2d_panning_strength", 0.0)), 1.0):
		_fail("global 2D and 3D panning must preserve the strongest directional cue")
		return
	var unmanaged_source := AudioStreamPlayer3D.new()
	unmanaged_source.name = "UnmanagedPhysicalEffect"
	root.add_child(unmanaged_source)
	director.call("_configure_surround_source", unmanaged_source)
	if not bool(unmanaged_source.get_meta("surround_7_1_ready", false)) \
			or unmanaged_source.panning_strength != 1.0 \
			or unmanaged_source.max_distance != 72.0 \
			or unmanaged_source.attenuation_filter_cutoff_hz < 6200.0 \
			or unmanaged_source.bus != &"SFX" \
			or unmanaged_source.doppler_tracking \
				!= AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED:
		_fail("every physical 3D source must inherit the surround, distance and filtering policy")
		return
	var recorded_streams: Dictionary = director.get("_surface_streams")
	for surface in [&"grass", &"earth", &"sand", &"gravel", &"brick", &"stone", &"wood", &"metal"]:
		var takes: Array = recorded_streams.get(surface, [])
		if takes.size() < 6 or takes[0] is not AudioStreamOggVorbis:
			_fail("%s must use at least six field-recorded OGG takes before synthesis fallback" % surface)
			return
	var recorded_brushes: Array = director.get("_vegetation_brush_streams")
	if recorded_brushes.size() != 2 or recorded_brushes[0] is not AudioStreamOggVorbis:
		_fail("lateral vegetation needs the two field-recorded leaf takes")
		return
	var train_loops: Dictionary = director.get("_train_loop_streams")
	var world_loops: Dictionary = director.get("_world_loop_streams")
	for profile in [&"windmill", &"watermill", &"lumbermill", &"cave_air", &"aether_power"]:
		var recorded_loop := world_loops.get(profile) as AudioStreamWAV
		if recorded_loop == null or recorded_loop.loop_mode != AudioStreamWAV.LOOP_FORWARD \
				or recorded_loop.get_length() < 10.0:
			_fail("%s must use a substantial looping field recording" % profile)
			return
	var recorded_rail := train_loops.get(&"rail") as AudioStreamWAV
	if recorded_rail == null or recorded_rail.loop_mode != AudioStreamWAV.LOOP_FORWARD \
			or recorded_rail.get_length() < 10.0:
		_fail("train rail texture must be the substantial looping field recording")
		return
	var grass := StaticBody3D.new()
	grass.name = "Terrain3D"
	grass.add_to_group("grass_surface")
	root.add_child(grass)
	var bridge := StaticBody3D.new()
	bridge.name = "SouthArrivalBridgeCollision"
	root.add_child(bridge)
	var stair := StaticBody3D.new()
	stair.name = "CastleGrandStairTread"
	root.add_child(stair)
	var brick := StaticBody3D.new()
	brick.name = "CastleBrickPavingCollision"
	root.add_child(brick)
	var sand := StaticBody3D.new()
	sand.name = "BeachSandCollision"
	root.add_child(sand)
	var gravel := StaticBody3D.new()
	gravel.name = "PebbleGravelPathCollision"
	root.add_child(gravel)
	var metal := StaticBody3D.new()
	metal.name = "IronDeckPlateCollision"
	root.add_child(metal)
	var earth := StaticBody3D.new()
	earth.name = "VillageDirtGroundCollision"
	root.add_child(earth)
	var meadow_trail := StaticBody3D.new()
	meadow_trail.name = "MeadowTrailGroundCollision"
	root.add_child(meadow_trail)
	var railway := StaticBody3D.new()
	railway.name = "RailTrackCollision"
	root.add_child(railway)
	if director.call("classify_surface", grass) != &"grass" \
			or director.call("classify_surface", bridge) != &"wood" \
			or director.call("classify_surface", stair) != &"stone" \
			or director.call("classify_surface", brick) != &"brick" \
			or director.call("classify_surface", sand) != &"sand" \
			or director.call("classify_surface", gravel) != &"gravel" \
			or director.call("classify_surface", metal) != &"metal" \
			or director.call("classify_surface", earth) != &"earth" \
			or director.call("classify_surface", meadow_trail) != &"earth" \
			or director.call("classify_surface", railway) != &"metal":
		_fail("authored collider names must select all eight physical footstep families")
		return
	if director.call("_terrain_texture_to_surface", 0) != &"grass" \
			or director.call("_terrain_texture_to_surface", 1) != &"sand" \
			or director.call("_terrain_texture_to_surface", 2) != &"brick":
		_fail("painted hub terrain IDs must preserve grass, sand and ground-tile materials")
		return
	var web_map_texture := load("res://resources/web_hub_surface_map.png") as Texture2D
	if web_map_texture == null:
		_fail("Web terrain needs the baked material lookup")
		return
	var web_map := web_map_texture.get_image()
	var web_materials := {}
	for y in range(0, web_map.get_height(), 8):
		for x in range(0, web_map.get_width(), 8):
			web_materials[clampi(floori(web_map.get_pixel(x, y).r * 3.0), 0, 2)] = true
	if not web_materials.has(0) or not web_materials.has(1) or not web_materials.has(2):
		_fail("Web lookup must contain sampled grass, sand and tile regions")
		return
	var bush := Node3D.new()
	bush.name = "cl_bush_test"
	root.add_child(bush)
	bush.global_position = Vector3(1.4, 0.0, 0.0)
	(director.get("_vegetation_anchors") as Array).append(bush)
	if director.call("vegetation_is_beside", Vector3.ZERO, &"grass") \
			or not director.call("vegetation_is_beside", Vector3.ZERO, &"earth"):
		_fail("underfoot grass and lateral vegetation brush must remain separate scenarios")
		return
	var windmill := Node3D.new()
	windmill.name = "building_windmill_red2"
	var blacksmith := Node3D.new()
	blacksmith.name = "cl_blacksmith"
	var mine := Node3D.new()
	mine.name = "ms_mine"
	var station := Node3D.new()
	station.name = "Station_01_gallery"
	var misleading_lantern := Node3D.new()
	misleading_lantern.name = "Lantern_CreatorsLightExtMine"
	if director.call("classify_world_emitter", windmill) != &"windmill" \
			or director.call("classify_world_emitter", blacksmith) != &"forge" \
			or director.call("classify_world_emitter", mine) != &"cave_air" \
			or director.call("classify_world_emitter", station) != &"" \
			or director.call("classify_world_emitter", misleading_lantern) != &"":
		_fail("physical source names must map exactly without station or suffix false positives")
		return
	root.add_child(windmill)
	director.call("_register_world_emitter", windmill, &"windmill")
	if windmill.get_meta("sound_audit_treatment", "") != "static_silent" \
			or windmill.get_node_or_null("ObjectAmbience_windmill") != null:
		_fail("a static windmill must remain naturally silent")
		return
	var active_mill := Node3D.new()
	active_mill.name = "building_watermill_red2"
	active_mill.set_meta("sound_active", true)
	root.add_child(active_mill)
	var imported_child := Node3D.new()
	imported_child.name = "building_watermill_red2"
	active_mill.add_child(imported_child)
	director.call("_register_world_emitter", active_mill, &"watermill")
	director.call("_register_world_emitter", imported_child, &"watermill")
	if active_mill.get_node_or_null("ObjectAmbience_watermill") == null \
			or imported_child.get_node_or_null("ObjectAmbience_watermill") != null:
		_fail("one moving imported object must produce one source, not stacked child loops")
		return

	var train := Node3D.new()
	train.name = "RainbowGalaxyTrain"
	root.add_child(train)
	var imported_train_part := Node3D.new()
	imported_train_part.name = "TRAIN_Engine_SteamValve"
	train.add_child(imported_train_part)
	if bool(director.call("_is_train_root", imported_train_part)):
		_fail("an imported TRAIN_* visual part must not receive its own complete train rig")
		return
	director.call("_register_train", train)
	for audio_name in ["TractionEngine3D", "RailClatter3D", "TravelWind3D", "TrainEvents3D"]:
		var player := train.get_node_or_null(audio_name) as AudioStreamPlayer3D
		if player == null or player.attenuation_model != AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE \
				or player.panning_strength < 1.0 \
				or not bool(player.get_meta("surround_7_1_ready", false)) \
				or player.doppler_tracking \
					!= AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP:
			_fail("train layer %s must be attached as fully-panned inverse-distance audio" % audio_name)
			return
	train.global_position = Vector3(24.0, 0.0, 0.0)
	director.call("_update_train_audio", 0.1)
	var engine_audio := train.get_node("TractionEngine3D") as AudioStreamPlayer3D
	var rail_audio := train.get_node("RailClatter3D") as AudioStreamPlayer3D
	var event_audio := train.get_node("TrainEvents3D") as AudioStreamPlayer3D
	if engine_audio.pitch_scale <= 0.92 or engine_audio.pitch_scale > 1.081 \
			or rail_audio.pitch_scale > 1.101 or rail_audio.volume_db <= -52.0 \
			or event_audio.stream == null:
		_fail("measured train movement must raise engine/rail energy and trigger departure audio")
		return

	var compatibility := Node.new()
	compatibility.set_script(load("res://scripts/web_terrain_compat.gd"))
	root.add_child(compatibility)
	compatibility.call("_add_web_sky_dome")
	var dome := compatibility.get_node_or_null("WebSkyDome") as MeshInstance3D
	if dome == null or not dome.material_override is ShaderMaterial:
		_fail("the Web fallback must build a shader-driven atmospheric dome")
		return
	var shader := (dome.material_override as ShaderMaterial).shader
	if shader == null or shader.resource_path != "res://shaders/web_sky_dome.gdshader":
		_fail("the Web dome must use the WebGL-safe gradient/cloud/sun shader")
		return

	print("WORLD_SPATIAL_AUDIO_TEST: PASS — recorded material footsteps, motion-gated objects, 7.1-ready SPCAP sources, moving-train Doppler, positional attenuation, and atmospheric Web sky")
	quit()
