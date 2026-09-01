extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CROWN_TRAIN_SPATIAL_AUDIO_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var scene_root := Node3D.new()
	scene_root.name = "ArtCastleAudioHarness"
	root.add_child(scene_root)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	scene_root.add_child(player)
	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	scene_root.add_child(railway)
	for _frame in 10:
		await process_frame
	var train := railway.find_child("RainbowGalaxyTrain", true, false) as Node3D
	if train == null:
		_fail("the real Crown Line builder must create its train")
		return
	var director := root.get_node_or_null("WorldSpatialAudio")
	director.call("_register_train", train)
	if not train.has_meta("spatial_train_audio"):
		_fail("the real Crown Line train must be accepted by the shared manager")
		return
	for audio_name in ["TractionEngine3D", "RailClatter3D", "TravelWind3D", "TrainEvents3D"]:
		var audio := train.get_node_or_null(audio_name) as AudioStreamPlayer3D
		if audio == null or audio.max_distance < 180.0 or audio.panning_strength < 1.0:
			_fail("%s must be long-range fully directional train audio" % audio_name)
			return
	var controls := train.get_node_or_null("TrainControls3D") as AudioStreamPlayer3D
	if controls == null or controls.max_distance > 100.0 or controls.panning_strength < 1.0:
		_fail("cab and passenger control sounds need a close-range spatial source")
		return
	var engine := train.get_node("TractionEngine3D") as AudioStreamPlayer3D
	var engine_loop := engine.stream as AudioStreamWAV
	if engine_loop == null or engine_loop.get_length() < 7.9 \
			or engine_loop.loop_mode != AudioStreamWAV.LOOP_FORWARD or not engine_loop.stereo:
		_fail("the train engine must use the substantial stereo steam-modern loop")
		return
	if engine.position.distance_to(Vector3(0.0, 4.2, -15.0)) > 0.1:
		_fail("the steam, gear and sci-fi engine sound must radiate from the nose power orb")
		return
	var horn_streams: Dictionary = director.get("_train_event_streams")
	var horn := horn_streams.get(&"horn") as AudioStreamWAV
	if horn == null or horn.get_length() < 3.1 or horn.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		_fail("H must trigger the substantial realistic locomotive horn one-shot")
		return
	if not bool(director.call("request_train_horn", train)):
		_fail("the shared train audio manager rejected the H horn request")
		return
	var events := train.get_node("TrainEvents3D") as AudioStreamPlayer3D
	if not events.playing or events.stream != horn:
		_fail("the H horn request did not play through the train's spatial event source")
		return
	var close_events := [&"power_on", &"reverser", &"throttle", &"valve",
		&"board", &"seat", &"ui_confirm", &"brake_release"]
	var distant_events := [&"departure", &"brake", &"arrival", &"door"]
	for event_name in close_events + distant_events:
		var stream := horn_streams.get(event_name) as AudioStreamWAV
		if stream == null or stream.get_length() < 0.2 \
				or stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			_fail("%s needs a substantial Web-safe one-shot" % event_name)
			return
		if not bool(director.call("request_train_event", train, event_name)):
			_fail("shared audio manager rejected %s" % event_name)
			return
		var expected_source := controls if event_name in close_events else events
		if expected_source.stream != stream \
				or expected_source.get_meta("last_train_event", &"") != event_name:
			_fail("%s played from the wrong train position" % event_name)
			return
	print("CROWN_TRAIN_SPATIAL_AUDIO_TEST: PASS — engine, rails, H horn and all cab/passenger events are spatially attached")
	quit()
