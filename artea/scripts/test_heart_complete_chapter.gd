extends SceneTree
const Scene = preload("res://scenes/heart_melody/heart_melody_world.tscn")
const Catalog = preload("res://scripts/heart_melody/heart_melody_chapter_catalog.gd")
const Progress = preload("res://scripts/heart_melody/heart_progress.gd")
var failures: Array[String] = []
var world

func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func press(text: String) -> void:
	for button in world.options.find_children("*", "Button", true, false):
		if button.text == text: button.pressed.emit(); return
	check(false, "button exists: " + text)

func run() -> void:
	world = Scene.instantiate()
	world.test_mode = true
	world.progress.path = "res://../work/heart_complete_chapter_test.json"
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(world.progress.path + suffix))
	root.add_child(world)
	current_scene = world
	await physics_frame
	var chapter = world.chapter_world
	var state = root.get_node("JourneyState")
	var prior_treasures: Dictionary = state.treasures.duplicate(true)
	state.treasures.harmony_jewel = false
	check(not world.progress.answer_flowers([0, 2, 1]), "flower answer cannot bypass three saved seeds")
	for i in 6:
		chapter.harvest(i)
		press("Harvest protected story allotment")
		world._close()
	check(world.progress.committed.chapter.quest_pouch.size() == 6, "six protected fruit harvests through UI")
	for i in 3:
		world._planter(i)
		press("Confirm planting / appearance")
	check(world.progress.committed.chapter.quest_pouch.echo_berry == 1, "celesta consumes three protected seeds once")
	check(not world.progress.answer_flowers([0, 1, 2]), "wrong flower order cannot unlock encounters")
	# Use the flower menu players actually encounter, without completing the
	# unrelated optional four-fruit orchard activity first.
	world.musical_garden._flower_activity()
	for symbol in ["LEAF", "SUN", "DROPLET"]: press("Add " + symbol)
	press("Answer the flowers")
	check(world.progress.committed.solved, "flower activity confirms the saved story phrase")
	var phrase_reload := Progress.new()
	phrase_reload.path = world.progress.path
	phrase_reload.load_progress()
	check(phrase_reload.committed.solved, "flower confirmation survives reload")
	world._close()
	# Exercise the actual shell exposure/release contract for both old waves.
	for wave in [1, 2]:
		world.player.position = world.encounter_center
		await process_frame
		await process_frame
		check(world.active_wave == wave and not world.enemies.is_empty(), "entering clearing automatically spawns wave %d" % wave)
		for enemy in world.enemies.duplicate():
			enemy.phase = "recovery"
			enemy.take_damage(100, world.player)
		world._close()
	check(world.progress.committed.complete, "original garden and encounters complete")
	for task in range(2, 8):
		chapter.open_instrument(task)
		check(chapter.active_task == task, "instrument %d opens in quest order" % task)
		if task in [2, 3]:
			for i in Catalog.PATTERNS[task].size(): chapter.challenge.tune(i, Catalog.PATTERNS[task][i])
		else:
			for note in Catalog.PATTERNS[task]:
				chapter.challenge.elapsed = 0
				chapter.clock = 2
				chapter.play(note)
		chapter.submit()
		check(Catalog.TASKS[task] in world.progress.committed.chapter.tasks, "instrument %d saves completion" % task)
		world._close()
	for i in 3:
		chapter.encounter.phase = "recovery"
		chapter.open_anchor(i)
		for note in chapter.challenge.target: chapter.play(note)
		chapter.submit()
		world._close()
		check(world.progress.committed.chapter.anchors.size() == i + 1, "anchor persists independently")
		if i == 0:
			world.player.position = Vector3(399, 1, 8)
			world._recover()
			check(world.progress.committed.chapter.anchors == ["rhythm"], "defeat preserves completed anchor")
	chapter.open_instrument(9)
	for note in Catalog.PATTERNS[9]:
		chapter.challenge.elapsed = 0
		chapter.play(note)
	chapter.submit()
	world._close()
	check(world.progress.committed.chapter.tasks == Catalog.TASKS, "all ten instruments complete")
	check(state.has_treasure("harmony_jewel") and world.player.blocking_enabled, "finale grants jewel and shield")
	check(chapter.jewel.visible and not chapter.stage_shell.visible, "restored sanctuary matches saved completion")
	var receipts: Array = world.progress.committed.chapter.reward_receipts.duplicate()
	check(chapter.director.finish_instrument(9, Catalog.PATTERNS[9]) and world.progress.committed.chapter.reward_receipts == receipts, "replay grants no duplicate rewards")
	var reload := Progress.new()
	reload.path = world.progress.path
	reload.load_progress()
	check(reload.committed.chapter.tasks.size() == 10 and reload.committed.chapter.anchors.size() == 3, "completed chapter reloads")
	# Walk the real capsule through the new connected region, around the stage and
	# sanctuary plinth. No teleporting between waypoints and no debug noclip.
	world.player.position = Vector3(348, 1.5, 8)
	for waypoint in [Vector3(372, 0, 8), Vector3(375, 0, 14), Vector3(439, 0, 14), Vector3(450, 0, 8), Vector3(454, 0, 8), Vector3(455, 0, 15), Vector3(473, 0, 15), Vector3(474, 0, 8)]:
		check(await walk(waypoint), "walk to " + str(waypoint))
	state.treasures = prior_treasures
	state.save()
	print("HEART COMPLETE CHAPTER: PASS" if failures.is_empty() else "HEART COMPLETE CHAPTER: " + str(failures))
	quit(0 if failures.is_empty() else 1)

func walk(target: Vector3) -> bool:
	for frame in 700:
		var offset: Vector3 = world.to_global(target) - world.player.global_position
		offset.y = 0
		for action in ["move_right", "move_left", "move_forward", "move_backward"]: Input.action_release(action)
		if offset.length() < 1.1: return true
		var direction := offset.normalized()
		var camera = world.player._active_camera()
		var right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
		var forward := Vector3(-camera.global_basis.z.x, 0, -camera.global_basis.z.z).normalized()
		var x := direction.dot(right)
		var y := direction.dot(forward)
		Input.action_press("move_right" if x > 0 else "move_left", absf(x))
		Input.action_press("move_forward" if y > 0 else "move_backward", absf(y))
		await physics_frame
	return false
