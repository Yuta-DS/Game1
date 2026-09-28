extends SceneTree
const Progress = preload("res://scripts/heart_melody/heart_progress.gd")
var world
var failures: Array[String] = []

func _init() -> void: _run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error("RIVER FAIL: " + text)

func _walk(target: Vector3, frames := 1000) -> bool:
	for frame in frames:
		var offset: Vector3 = world.to_global(target) - world.player.global_position
		offset.y = 0
		if offset.length() < 1.4:
			_release()
			return true
		var direction := offset.normalized()
		var camera = world.player._active_camera()
		var right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
		var forward := Vector3(-camera.global_basis.z.x, 0, -camera.global_basis.z.z).normalized()
		var x := direction.dot(right)
		var y := direction.dot(forward)
		_release()
		Input.action_press("move_right" if x > 0 else "move_left", absf(x))
		Input.action_press("move_forward" if y > 0 else "move_backward", absf(y))
		await physics_frame
	_release()
	print("RIVER WALK STALLED ", world.player_local_position(), " target ", target)
	return false

func _release() -> void:
	for action in ["move_forward", "move_backward", "move_left", "move_right"]: Input.action_release(action)

func _run() -> void:
	create_timer(150).timeout.connect(func(): _release(); push_error("River test timeout"); quit(1))
	var progress = Progress.new()
	progress.path = "user://river_test.json"
	check(not progress.river_step("valves", 0), "garden prerequisite enforced")
	for index in 3: progress.plant(index, 6)
	progress.edit_phrase([0, 2, 1])
	progress.solve()
	progress.clear_wave(1)
	progress.clear_wave(2)
	var legacy: Dictionary = progress.data.duplicate(true)
	legacy.erase("river")
	check(Progress.valid(legacy) and legacy.river == Progress.fresh_river(), "old Island 1 save migrates without losing progress")
	check(not progress.river_step("boat"), "cannot skip organ and vines")
	var invalid: Dictionary = progress.data.duplicate(true)
	invalid.river.valves = [0, 0]
	check(not Progress.valid(invalid), "duplicate valve save rejected")
	if OS.get_environment("ARTEA_RIVER_OVERWORLD") == "1":
		root.get_node("JourneyState").treasures["star_of_wisdom"] = true
		change_scene_to_file("res://scenes/art_gallery_3d_inprogress.tscn")
		await process_frame
		await process_frame
		world = current_scene.find_child("HeartMelodyIslandOne", true, false)
		world.test_mode = true
		world.progress.path = progress.path
		world.progress.load_progress()
		world._apply_restoration()
		world.river.refresh()
	else:
		world = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
		world.test_mode = true
		# Exercise all geometry and combat with a non-identity transform.
		world.position = Vector3(400, 20, -250)
		world.rotation.y = PI
		world.progress.path = progress.path
		root.add_child(world)
		current_scene = world
	var original_scene := current_scene
	for frame in 8: await physics_frame
	world.player.global_position = world.to_global(Vector3(60, 2, 8))
	world._process(0)
	check(await _walk(Vector3(118, 1, 8)), "walk restored garden crossing into River Song without jump")
	check(current_scene == original_scene, "river is in the same scene")
	check(await _walk(Vector3(178, 1, -8)), "near bank joins the flowering root walk")
	check(await _walk(Vector3(226, 1, -8)), "flowering root walk crosses the river without the boat")
	check(await _walk(Vector3(238, 1, -8)), "far bank joins the flowering root walk")
	check(not world.progress.committed.river.boat, "connected exploration does not skip the Rain Boat activity")
	check(await _walk(Vector3(178, 1, -8)), "connected river walk supports a safe return crossing")
	check(await _walk(Vector3(179, 1, 12)), "connected river walk returns to the near dock")
	world.river.interact("river_valve", 0)
	world.options.get_child(3).pressed.emit() # Leaf is wrong for the first Sun pipe.
	check(world.progress.data.river.valves.is_empty(), "wrong valve answer preserves work")
	world._close()
	for index in 3:
		world.river.interact("river_valve", index)
		world.options.get_child(3 + world.river.NOTES[index]).pressed.emit()
		world._close()
	check(world.progress.committed.river.valves.size() == 3, "all valve UI solutions persist")
	var bad_path: String = world.progress.path
	world.progress.path = "res://missing_river_directory/save.json"
	check(not world.progress.river_step("bulbs", 0) and world.progress.dirty, "failed write retains vine session change")
	check(not world.progress.river_step("boat"), "failed prerequisite save cannot unlock boat")
	world.progress.path = bad_path
	world.progress.commit()
	for index in 3:
		world.river.interact("river_bulb", index)
		world._close()
	check(await _walk(Vector3(179, 1, 12)), "walk along river to dock")
	world.river.interact("river_boat", 0)
	world._close()
	check(not world.river.riding, "cancelling boat confirmation stays on shore")
	world.river.interact("river_boat", 0)
	world.river.begin_ride()
	for frame in 440: await physics_frame
	check(not world.river.riding and world.progress.committed.river.boat, "confirmed boat arrives and saves")
	check(world.player_local_position().x > 220, "boat carries shared player to far dock")
	world._close()
	for index in 3:
		check(await _walk(Vector3(262 + index * 12, 1, 8)), "walk each grown chime section")
		world.river.interact("river_chime", index)
		world._close()
	check(await _walk(Vector3(298, 1, 8)), "walk complete bridge to warning bells")
	world.river.interact("river_warning", 0)
	world.options.get_child(3).pressed.emit()
	check(not world.progress.data.river.warning, "unsafe bell choice does not open path")
	world.options.get_child(2).pressed.emit()
	world._close()
	check(await _walk(Vector3(316, 1, 8)), "safe path reaches actual grove encounter")
	check(world.enemies.size() == 2, "grove encounter starts")
	for enemy in world.enemies.duplicate():
		enemy.phase = "recovery"
		enemy.take_damage(100)
	world._close()
	check(world.progress.committed.river.grove, "restoring both enemies commits grove")
	world.river.interact("river_peace", 0)
	world._close()
	check(world.progress.committed.river.peace, "Peace Flower completes River Song")
	var reloaded = Progress.new()
	reloaded.path = progress.path
	reloaded.load_progress()
	check(reloaded.data.river.peace and reloaded.data.xp == 119, "river save round trip preserves Island 1 XP")
	world._recover()
	check(world.player_local_position().distance_to(Vector3(336, 2, 16)) < 0.1, "Peace Flower is a recovery checkpoint")
	for point in [Vector3(322, 1, 8), Vector3(298, 1, 8), Vector3(262, 1, 8), Vector3(225, 1, 12)]:
		check(await _walk(point), "walk from Peace Flower back across restored bridge to return dock")
	world.river.interact("river_boat", 1)
	world.river.begin_ride()
	for frame in 440: await physics_frame
	check(world.player_local_position().x < 184 and world.player.input_enabled, "return boat restores controls at garden-side dock")
	check(await _walk(Vector3(60, 1, 8)), "walk back into original garden")
	check(not root.get_node("JourneyState").has_treasure("harmony_jewel"), "Island 2 does not award final-world Jewel")
	print("RIVER SONG: all checks passed" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
