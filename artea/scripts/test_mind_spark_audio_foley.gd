extends SceneTree

const Foley := preload("res://scripts/mind_spark/mind_spark_foley.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MIND_SPARK_AUDIO_FOLEY_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var identities: Dictionary = {}
	for object_kind in 12:
		var stream := Foley.make_quest_feedback(object_kind, false)
		if stream.mix_rate != 48000 or stream.stereo or stream.get_length() < 0.4:
			_fail("quest object %d lacks substantial 48 kHz mono Foley" % object_kind)
			return
		identities[String(stream.get_meta("foley_event", ""))] = true
	if identities.size() != 12:
		_fail("all twelve quest-object kinds must have distinct sound identities")
		return

	var events := [&"player_swing", &"player_block", &"player_hurt", &"enemy_notice",
		&"enemy_telegraph", &"enemy_attack", &"enemy_hit", &"enemy_block", &"enemy_defeat",
		&"warden_storm", &"warden_strike", &"warden_open", &"warden_hit", &"warden_free"]
	for event in events:
		var stream := Foley.make_combat_event(event)
		if stream.mix_rate != 48000 or stream.stereo \
				or stream.get_meta("foley_event", &"") != event:
			_fail("combat event %s lacks its named 48 kHz mono profile" % event)
			return

	var boss := (load("res://scenes/mind_spark/combat/thought_storm_warden.tscn") as PackedScene).instantiate()
	root.add_child(boss)
	await process_frame
	var boss_audio := boss.get_node_or_null("WardenCombatFoley3D") as AudioStreamPlayer3D
	if boss_audio == null or boss_audio.max_distance < 80.0 or boss_audio.panning_strength < 1.0:
		_fail("Warden has no long-range directional combat source")
		return
	boss.call("start_battle")
	if boss_audio.stream == null or boss_audio.stream.get_meta("foley_event", &"") != &"warden_storm":
		_fail("Warden battle start does not play the storm profile")
		return

	print("MIND_SPARK_AUDIO_FOLEY_TEST: PASS — 12 object identities and 14 positional combat events use 48 kHz mono Foley")
	quit()
