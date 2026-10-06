extends SceneTree

const Preview := preload("res://scenes/heart_melody/heart_garden_preview.tscn")
const World := preload("res://scripts/heart_melody/heart_garden_world.gd")
var world: World


func _init() -> void: call_deferred("_run")


func _press(text: String) -> void:
	for child in world.panel_content.get_children():
		if child is Button and child.text == text:
			child.pressed.emit()
			return
	push_error("Missing Shared Song button: " + text)
	quit(1)


func _run() -> void:
	var scene := Preview.instantiate()
	world = scene.get_node("HeartMelodyWorld")
	world.persist_progress = false
	root.add_child(scene)
	await process_frame
	await physics_frame
	_complete_river()
	for id in ["harmony_bridge_chimes", "moon_melon_grove", "warning_bell_path", "heart_song_loom"]:
		assert(world.controls.has(id), "playable Bell Grove control: " + id)
	world.open_control("harmony_bridge_chimes")
	_press("Aim chime 1")
	_press("Strike chime 1")
	_press("Aim chime 2")
	_press("Aim chime 2")
	_press("Strike chime 2")
	_press("Strike chime 3")
	assert(world.state.task_complete(world.State.CHIME_TASK))
	assert(world._bridge_growth.all(func(node): return node.visible))
	world.open_control("moon_melon_grove")
	_press("Harvest 3 Moon Melon")
	world.open_control("warning_bell_path")
	for channel in ["Left", "Centre", "Right", "Centre"]:
		_press("Move %s" % channel)
	_press("Confirm safe crossing")
	assert(world.state.task_complete(world.State.WARNING_TASK))
	world.open_control("heart_song_loom")
	for motif in ["Drum", "Water", "Harp", "Chime"]:
		_press("Add %s motif" % motif)
	_press("Confirm Heart Song")
	assert(world.state.heart_song_complete() and world.state.xp() == 354)
	assert(world._loom_tracks.all(func(track): return track.material_override.albedo_color == world.Kit.material("gold").albedo_color))
	for point in [Vector3(670, 8, 18), Vector3(700, 8, 20), Vector3(748, 8, -48),
			Vector3(795, 8, 20), Vector3(885, 8, 0)]:
		var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 12)
		assert(not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
			"Bell Grove floor at %s" % point)
	world.deactivate()
	scene.queue_free()
	await process_frame
	print("PASS: Harmony Chimes, Moon Melons, Warning Bell Path and Heart Song Loom world flow")
	quit()


func _complete_river() -> void:
	var state = world.state
	state.grant_story_fruit("echo_berry", 3, "heart.world.echo")
	for index in 3: state.plant(index, "sound")
	for note in state.PHRASE: state.enter_note(note)
	state.confirm_phrase()
	for wave in state.WAVES:
		for enemy_id in wave: state.record_defeat(enemy_id)
		state.finish_wave(wave)
	state.grant_story_fruit("dew_pear", 3, "heart.world.dew")
	for index in 3: state.set_organ_valve(index, state.ORGAN_TARGET[index])
	state.confirm_organ()
	state.grant_story_fruit("sun_plum", 5, "heart.world.sun")
	for index in 5: state.set_vine_tension(index, state.VINE_TARGET[index])
	state.confirm_vines()
	state.grant_story_fruit("bell_apple", 4, "heart.world.bell")
	for direction in state.BELL_TARGET: state.enter_rain_bell(direction)
	state.confirm_rain_bells()
