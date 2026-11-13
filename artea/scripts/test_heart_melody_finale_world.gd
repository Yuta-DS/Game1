extends SceneTree

const Preview := preload("res://scenes/heart_melody/heart_garden_preview.tscn")
var world


func _init() -> void: call_deferred("_run")


func _press(text: String) -> void:
	for child in world.panel_content.get_children():
		if child is Button and child.text == text:
			child.pressed.emit()
			return
	push_error("Missing finale button: " + text)
	quit(1)


func _run() -> void:
	var scene := Preview.instantiate()
	world = scene.get_node("HeartMelodyWorld")
	world.persist_progress = false
	root.add_child(scene)
	await process_frame
	await physics_frame
	_complete_heart_song()
	for id in ["conductor_beat_anchors", "harmony_fig_grove", "harmony_fruit_orchestra",
			"harmony_sanctuary", "creator_light_gate"]:
		assert(world.controls.has(id), "playable Shared Song control: " + id)
	world.open_control("conductor_beat_anchors")
	for item in [["Rhythm", ["Leaf", "Sun", "Droplet"]],
			["Pitch", ["Low", "High", "Calm"]], ["Direction", ["Left", "Centre", "Right"]]]:
		for step in item[1]: _press("%s: %s" % [item[0], step])
	assert(world.state.task_complete(world.State.ANCHOR_TASK))
	world.open_control("harmony_fig_grove")
	_press("Harvest six Harmony Figs")
	world.open_control("harmony_fruit_orchestra")
	for fruit_id in world.State.ORCHESTRA_TARGET:
		_press("Place %s" % str(fruit_id).replace("_", " ").capitalize())
	for direction in ["Up", "Left", "Right", "Down"]:
		_press("Conduct %s" % direction)
	_press("Complete the Heart Melody finale")
	assert(world.state.harmony_complete() and world.state.xp() == 719)
	assert(world._harmony_jewel.visible and world._harmony_shield.visible and world._creator_gate_light.visible)
	assert(world._shell_sections.all(func(shell): return not shell.visible))
	for point in [Vector3(950, 8, 12), Vector3(1010, 8, 16), Vector3(1090, 8, -58),
			Vector3(1170, 8, 10), Vector3(1208, 8, 10)]:
		var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 12)
		assert(not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
			"Shared Song floor at %s" % point)
	world.deactivate()
	scene.queue_free()
	await process_frame
	print("PASS: Shared Song region, Beat Anchors, Harmony Fig orchestra and sanctuary finale")
	quit()


func _complete_heart_song() -> void:
	var state = world.state
	state.grant_story_fruit("echo_berry", 3, "finale.world.echo")
	for index in 3: state.plant(index, "sound")
	for note in state.PHRASE: state.enter_note(note)
	state.confirm_phrase()
	for wave in state.WAVES:
		for enemy_id in wave: state.record_defeat(enemy_id)
		state.finish_wave(wave)
	state.grant_story_fruit("dew_pear", 3, "finale.world.dew")
	for index in 3: state.set_organ_valve(index, state.ORGAN_TARGET[index])
	state.confirm_organ()
	state.grant_story_fruit("sun_plum", 5, "finale.world.sun")
	for index in 5: state.set_vine_tension(index, state.VINE_TARGET[index])
	state.confirm_vines()
	state.grant_story_fruit("bell_apple", 4, "finale.world.bell")
	for direction in state.BELL_TARGET: state.enter_rain_bell(direction)
	state.confirm_rain_bells()
	for index in 3:
		state.set_chime_wind(index, state.CHIME_TARGET[index])
		state.strike_bridge_chime(index)
	state.grant_story_fruit("moon_melon", 3, "finale.world.moon")
	for channel in state.WARNING_TARGET: state.enter_warning_channel(channel)
	state.confirm_warning_path()
	for motif in state.LOOM_TARGET: state.enter_loom_motif(motif)
	state.confirm_loom()
