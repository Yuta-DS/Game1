extends SceneTree
var failures: Array[String] = []
func _init() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func run() -> void:
	var world = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
	world.test_mode = true
	world.progress.path = "res://../work/milo-guidance-test-save.json"
	root.add_child(world)
	current_scene = world
	for frame in 12: await physics_frame
	var guide = world.milo_guide
	var companion = root.get_node("MiloCompanionManager").get_active_milo()
	check(companion != null and companion.player == world.player, "narrator uses the existing walking companion")
	check(guide.current_line == "garden" and guide.voice.playing, "garden arrival plays its recorded instructions")
	check(world.player.input_enabled and world.player.get_meta("milo_heart_escort", false), "narration leaves movement enabled and escort active")
	check(companion.is_speaking() and companion._speech_remaining > 0, "recorded narration animates Milo's mouth")
	for id in guide.LINES.data.lines:
		var asset := "res://assets/audio/milo/heart_guidance/" + str(id) + ".ogg"
		check(ResourceLoader.exists(asset), "voice clip exported: " + str(id))
		if ResourceLoader.exists(asset):
			var stream = load(asset)
			check(stream.get_length() > 4, "complete spoken guidance: " + str(id))
	check(guide.LINES.data.reference == "res://assets/audio/milo/milo_voice.ogg", "tutorial recordings use the opening voice reference")
	guide.stop()
	guide._gap = 0
	guide.tick(0)
	check(guide.current_line.is_empty(), "heard introduction does not repeat while standing still")
	world._help()
	check(world.modal_open, "help opens normally")
	guide.replay()
	check(not world.modal_open and world.player.input_enabled and guide.current_line == "garden", "help replay restores exploration and replays the correct next step")
	guide.stop()
	guide.enabled = false
	guide.tick(0)
	check(not world.player.get_meta("milo_heart_escort", true) and not guide.panel.visible, "ending escort stops voice and subtitles cleanly")
	print("HEART MILO GUIDANCE: PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
