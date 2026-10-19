extends SceneTree
const Progress = preload("res://scripts/heart_melody/heart_progress.gd")
const World = preload("res://scenes/heart_melody/heart_melody_world.tscn")
var failures: Array[String] = []
var world
func _init() -> void:
	call_deferred("run")
func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAIL: " + description)
		failures.append(description)
func run() -> void:
	var state = Progress.new()
	state.path = "user://heart_test.json"
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(state.path + suffix))
	check(not state.solve(), "cannot solve before planting")
	for choice in 7:
		check(state.plant(0, choice), "every authored feeling and sound commits")
	check(state.plant(1, 6) and state.plant(2, 6), "repeated neutral sounds succeed")
	check(state.edit_phrase([0, 1, 2]), "partial phrase commits")
	check(not state.solve() and state.data.phrase == [0, 1, 2], "mismatch preserves work")
	check(state.edit_phrase([0, 2, 1]) and state.solve(), "authored phrase solves")
	check(state.clear_wave(1), "first wave commits")
	var loaded = Progress.new()
	loaded.path = state.path
	loaded.load_progress()
	check(loaded.data.solved and loaded.data.waves.has(1), "reload preserves solved phrase and cleared wave")
	check(loaded.clear_wave(1) and loaded.data.xp == 12, "wave retry is idempotent")
	check(loaded.clear_wave(2) and loaded.data.xp == 119, "39 enemy plus 80 quest XP")
	check(loaded.clear_wave(2) and loaded.data.xp == 119, "completion cannot duplicate XP")
	var backup = Progress.new()
	backup.path = state.path
	var corrupted := FileAccess.open(backup.path, FileAccess.WRITE)
	corrupted.store_string("{broken")
	corrupted.close()
	backup.load_progress()
	check(backup.data.complete and backup.data.xp == 119, "corrupt primary recovers committed backup")
	check(not Progress.valid({"schema": 1, "phrase": ["invalid"]}), "malformed data is rejected safely")
	var broken = Progress.new()
	broken.path = "res://missing_directory/invalid.json"
	check(not broken.plant(0, 1) and broken.dirty and broken.data.planters.size() == 1, "failed save retains session state")
	var js = load("res://scripts/JourneyState.gd").new()
	js.save_path = "user://heart_journey_test.json"
	js.record_emotion("hope", Color.PINK)
	check(js.has_treasure("harmony_jewel"), "main canonical music reward remains available")
	# The chapter never calls record_emotion. Its existing version-2 saves
	# cannot infer a reward from an optional old emotion record.
	js.treasures.erase("harmony_jewel")
	js.save()
	var js2 = load("res://scripts/JourneyState.gd").new()
	js2.save_path = js.save_path
	js2.load_journey()
	check(not js2.has_treasure("harmony_jewel"), "reload cannot infer new jewel")
	var legacy := FileAccess.open(js.save_path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"emotions": [{"name": "hope"}]}))
	legacy.close()
	js2.load_journey()
	check(js2.has_treasure("harmony_jewel"), "old earned jewel entitlement migrates")
	js.clear_journey()
	js.free()
	js2.free()
	world = World.instantiate()
	world.test_mode = true
	world.progress.path = "user://heart_world_test.json"
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(world.progress.path + suffix))
	root.add_child(world)
	current_scene = world
	root.get_node("MiloCompanionManager").refresh_companion()
	check(not world.has_node("WonderfulCounsellorMilo"), "authored guides retain single interaction ownership")
	await physics_frame
	await physics_frame
	var crossing_query := PhysicsRayQueryParameters3D.create(Vector3(76, 5, 8), Vector3(76, -4, 8))
	check(not world.get_world_3d().direct_space_state.intersect_ray(crossing_query).is_empty(),
		"root crossing physically connects the garden before restoration")
	for point in [Vector3(-60, 1, 8), Vector3(55, 1, 8), Vector3(94, 1, 8), Vector3(118, 1, 8)]:
		await walk_to(point)
	check(not world.progress.data.complete, "connected exploration does not auto-complete garden progress")
	for point in [Vector3(94, 1, 8), Vector3(55, 1, 8), Vector3(-60, 1, 8), Vector3(-65, 1, 12)]:
		await walk_to(point)
	# Exercise the real player controller: continuous arrival-to-garden walking.
	Input.action_press("move_right")
	for frame in 240: await physics_frame
	Input.action_release("move_right")
	check(world.player.position.x > -35 and world.player.position.y > -2, "real player crosses connected meadow without falling")
	# Real UI buttons, including cancellation and retained mismatch.
	world.chapter_world.harvest(0)
	press("Harvest protected story allotment")
	world._close()
	world._planter(0)
	world.preview_choice = 0
	press("Preview sound and symbol")
	world._close()
	check(world.progress.data.planters.is_empty(), "cancel preview records nothing")
	for child in world.plants[0].get_children():
		if child is MeshInstance3D and child.position.y > 1 and child.position.y < 1.3:
			check(child.material_override.albedo_color == world.Catalog.COLOURS[6], "cancel restores neutral preview colour")
	for index in 3:
		if index == 1: await walk_to(Vector3(-34, 1, 26))
		if index == 2: await walk_to(Vector3(-20, 1, 26))
		await walk_to(Vector3(-40 + index * 14, 1, 6.2 if index != 1 else 25.2))
		world._process(0)
		check(world.nearest >= 0 and world.interactables[world.nearest].kind == "planter", "planter reachable through real walking and nearest prompt")
		world._interact_nearest()
		world.preview_choice = 6
		press("Confirm planting / appearance")
	check(world.progress.data.planters.size() == 3, "three confirmations through UI")
	await walk_to(Vector3(7, 1, 9))
	world._process(0)
	world._interact_nearest()
	check(world.modal_open, "phrase operating circle reachable from player camera")
	press("Hear the garden phrase")
	world._help()
	var help_text: String = world.message.text
	await create_timer(0.8).timeout
	check(world.message.text == help_text, "cancelled demonstration cannot overwrite help")
	world._phrase_panel()
	AudioServer.set_bus_mute(0, true)
	press("Leaf")
	press("Droplet")
	press("Sun")
	press("Confirm phrase")
	check(not world.progress.data.solved and world.progress.data.phrase.size() == 3, "UI mismatch retains phrase")
	press("Undo last note")
	press("Undo last note")
	press("Sun")
	press("Droplet")
	press("Confirm phrase")
	check(world.progress.data.solved, "UI revision solves phrase")
	AudioServer.set_bus_mute(0, false)
	world._close()
	world.player.take_damage(1000)
	await process_frame
	await physics_frame
	check(world.progress.data.solved and world.player.current_health == 100, "death preserves puzzle and restores health")
	world._start_wave(1)
	var enemy = world.enemies[0]
	world.modal_open = true
	var timer: float = enemy.remaining
	enemy._physics_process(0.5)
	check(enemy.remaining == timer, "modal suspends attack")
	world.modal_open = false
	world.player.position = Vector3(-56, 1, 17)
	enemy._physics_process(0.5)
	check(enemy.remaining == timer, "retreat suspends pursuit")
	check(not enemy._inside_dash_lane(enemy.target + (enemy.target - enemy.origin).normalized()), "moth cannot damage beyond marked lane")
	world.player.position = world.encounter_center + Vector3(0, 1, 4)
	world.player.fox_visuals.rotation = Vector3.ZERO
	enemy.position = world.player.position + Vector3(0, 0, 2.5)
	enemy.phase = "recovery"
	enemy.remaining = 10
	for strike in 2:
		Input.action_press("attack")
		for frame in 5: await physics_frame
		Input.action_release("attack")
		for frame in 38: await physics_frame
	check(world.progress.data.waves.has(1), "combat release commits first wave")
	world._start_wave(2)
	for target in world.enemies.duplicate():
		target.phase = "recovery"
		target.take_damage(50, world.player)
	check(world.progress.data.complete and world.progress.data.xp == 119, "full encounter restores garden")
	check(world.bridge.visible, "committed completion opens visible crossing")
	world._close()
	check(world.bridge.position == Vector3.ZERO and not world._restoring, "skip restoration settles deck and collision together")
	check(world.restored_creatures.size() == 3, "released shells leave three living creatures")
	world.player.position = Vector3(-65, 2, 8)
	Input.action_press("move_right")
	for frame in 850: await physics_frame
	Input.action_release("move_right")
	check(world.player.position.x > 70 and world.player.position.y > -2, "continuous arrival-to-overlook traversal")
	Input.action_press("move_left")
	for frame in 820: await physics_frame
	Input.action_release("move_left")
	print("RETURN POSITION ", world.player.position)
	check(world.player.position.x < -55 and world.player.position.y > -2, "continuous return traversal")
	if DisplayServer.get_name() != "headless":
		world.player.position = Vector3(-34, 2, 30)
		world.camera.position = Vector3(20, 108, 145)
		world.camera.look_at(Vector3(0, -3, 0))
		world._process(0)
		world.camera.position = Vector3(20, 108, 145)
		world.camera.look_at(Vector3(0, -3, 0))
		world.set_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://../work/heart-overview.png")
	world.queue_free()
	await process_frame
	print("HEART ISLAND: all checks passed" if failures.is_empty() else "HEART ISLAND FAILURES: " + str(failures))
	quit(0 if failures.is_empty() else 1)

func walk_to(target: Vector3) -> void:
	for frame in 900:
		var offset: Vector3 = target - world.player.position
		if Vector2(offset.x, offset.z).length() < 0.45: break
		for action in ["move_left", "move_right", "move_forward", "move_backward"]: Input.action_release(action)
		if absf(offset.x) > 0.2: Input.action_press("move_right" if offset.x > 0 else "move_left", minf(absf(offset.x), 1))
		if absf(offset.z) > 0.2: Input.action_press("move_backward" if offset.z > 0 else "move_forward", minf(absf(offset.z), 1))
		await physics_frame
	for action in ["move_left", "move_right", "move_forward", "move_backward"]: Input.action_release(action)
	check(Vector2(target.x - world.player.position.x, target.z - world.player.position.z).length() < 0.7, "walk reaches operating apron " + str(target))
func press(title: String) -> void:
	for node in world.options.find_children("*", "Button", true, false):
		if node.text == title:
			node.pressed.emit()
			return
	check(false, "button exists: " + title)
