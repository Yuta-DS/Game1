extends SceneTree

const Preview := preload("res://scenes/heart_melody/heart_garden_preview.tscn")
const World := preload("res://scripts/heart_melody/heart_garden_world.gd")
var scene: Node3D
var world: World


func _init() -> void:
	call_deferred("_run")


func _press(text: String) -> void:
	for child in world.panel_content.get_children():
		if child is Button and child.text == text:
			child.pressed.emit()
			return
	push_error("Missing River Voice button: " + text)
	quit(1)


func _run() -> void:
	scene = Preview.instantiate()
	world = scene.get_node("HeartMelodyWorld")
	world.persist_progress = false
	world.save_path = "user://heart_river_world_unused.json"
	root.add_child(scene)
	await process_frame
	await physics_frame
	assert(world.find_child("RiverVoiceRegion", true, false) != null)
	for id in ["dew_pear_grove", "waterfall_organ", "sun_plum_grove",
			"hush_vine_harp", "bell_apple_grove", "rain_boat_bells"]:
		assert(world.controls.has(id), "playable River Voice control: " + id)
	_complete_feeling_garden()
	await create_timer(1.2).timeout
	assert(not world._bridge_blocker.visible, "completed Feeling Garden opens the real river route")
	world.open_control("dew_pear_grove")
	_press("Harvest 3 Dew Pear")
	world.open_control("waterfall_organ")
	_press("Raise channel 1")
	_press("Raise channel 2")
	_press("Raise channel 2")
	_press("Confirm Waterfall chord")
	assert(world.state.task_complete(world.State.ORGAN_TASK))
	world.open_control("sun_plum_grove")
	_press("Harvest 5 Sun Plum")
	world.open_control("hush_vine_harp")
	for index in 5:
		for step in index:
			_press("Tighten string %d" % (index + 1))
	_press("Confirm the rising harmony")
	assert(world.state.task_complete(world.State.VINE_TASK))
	world.open_control("bell_apple_grove")
	_press("Harvest 4 Bell Apple")
	world.open_control("rain_boat_bells")
	for direction in ["North", "East", "South", "West"]:
		_press("Ring %s bell" % direction)
	_press("Confirm Rain Boat call")
	assert(world.state.river_complete() and world.state.xp() == 224)
	assert(world._rain_boat.visible)
	assert(world._organ_water[0].material_override.albedo_color == world.Kit.material("leaf_light").albedo_color)
	assert(world._rain_bells[0].material_override.albedo_color == world.Kit.material("blue").albedo_color)
	for point in [Vector3(365, 7, 0), Vector3(430, 7, -28), Vector3(525, 7, 34),
			Vector3(610, 7, -32), Vector3(642, 7, 28)]:
		var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 10.0)
		assert(not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
			"River Voice walkable floor at %s" % point)
	world.deactivate()
	scene.queue_free()
	await process_frame
	print("PASS: River Voice physical region, fruit harvests, three distinct instruments and completion feedback")
	quit()


func _complete_feeling_garden() -> void:
	var state = world.state
	state.grant_story_fruit("echo_berry", 3, "intro.echo")
	for index in 3:
		state.plant(index, "sound")
	for note in state.PHRASE:
		state.enter_note(note)
	state.confirm_phrase()
	for wave in state.WAVES:
		for enemy_id in wave:
			state.record_defeat(enemy_id)
		state.finish_wave(wave)
