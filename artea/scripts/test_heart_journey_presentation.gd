extends SceneTree
const Scene = preload("res://scenes/heart_melody/heart_melody_world.tscn")
var world
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	if not ok: failures.append(text); push_error(text)
func press(text: String) -> void:
	for button in world.options.find_children("*", "Button", true, false):
		if button.text == text: button.pressed.emit(); return
	check(false, "Missing control: " + text)
func ray(at: Vector3) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(world.to_global(at - Vector3(2, 0, 0)), world.to_global(at + Vector3(2, 0, 0)), 1))
func run() -> void:
	world = Scene.instantiate()
	world.test_mode = true
	world.progress.path = "res://../work/heart_journey_presentation_test.json"
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(world.progress.path + suffix))
	root.add_child(world)
	current_scene = world
	for i in 12: await physics_frame
	var guide = world.milo_guide
	check(guide.panel.visible and guide._pages.size() > 1, "Long narration uses short transcript pages")
	check(world.hud.get_parent().get_global_rect().end.x <= root.get_visible_rect().size.x, "Status card stays inside the screen's right margin")
	check(guide.caption.text.length() < 180 and guide.panel.size.x < 500, "Transcript has a clear compact card")
	guide.voice.finished.emit()
	check(not guide.panel.visible and guide.current_line.is_empty(), "Transcript disappears on the actual voice finished signal")
	guide.enabled = false
	world._intro()
	await process_frame
	await process_frame
	await process_frame
	check(world.options.get_node_or_null("ActivityFlow") != null, "Arrival teaches one visual sequence")
	check(world.options.is_ancestor_of(root.gui_get_focus_owner()), "Keyboard and controller focus starts inside the activity menu")
	check(world.options.get_parent().scroll_vertical == 0, "The entry heading and visual sequence start in view")
	check(not world.options.get_parent().follow_focus, "Late browser focus cannot hide the introduction")
	var navigation := InputEventAction.new()
	navigation.action = "ui_down"
	navigation.pressed = true
	world._input(navigation)
	check(world.options.get_parent().follow_focus, "Controller navigation enables focus-follow through long menus")
	check(world.message.text.length() < 350 and not world.message.text.contains("Silent Conductor"), "Arrival does not dump future chapters")
	world._close()
	world.chapter_world.journal()
	var journal_text := ""
	for button in world.options.find_children("*", "Button", true, false): journal_text += button.text
	check(not journal_text.contains("Harmony Fig") and not journal_text.contains("Moon Melon"), "Journal reveals fruit routes when they become relevant")
	world._close()
	var landscape = world.journey_landscape
	check(landscape.gates.size() == 5 and landscape.waters.size() == 6, "Five progress gates and healing water under the crossings")
	check(not ray(Vector3(88, 2, 8)).is_empty(), "A real collider closes the River Song gate before restoration")
	var music = landscape.get_node("MeadowSingingFountain/MusicalFountain/FountainMusic")
	check(music.playing and music.volume_db == -12 and music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Meadow fountain plays gentle local music")
	check(music.unit_size == 4 and music.max_distance == 28 and music.max_db == -10, "Fountain fades with distance and caps nearby loudness")
	for state in [[false, false], [true, false], [true, true]]:
		world.soundscape.restore(state[0], state[1])
		check(world.soundscape.layers.is_empty() and world.soundscape.get_child_count() == 0, "Garden progression never starts background music")
	world.player.set_physics_process(false)
	world.player.position = Vector3(76, 1, 8)
	world.player.current_health = 40
	world.chapter_world.focus = 40
	for i in 3: await physics_frame
	landscape.tick(1)
	check(world.player.current_health > 40 and world.chapter_world.focus > 40, "Crossing the healing mist actually restores health and focus")
	world.chapter_world.harvest(0)
	press("Harvest protected story allotment")
	world._close()
	for i in 3:
		world._planter(i)
		press("Confirm planting / appearance")
	world.progress.edit_phrase([0, 2, 1])
	world.progress.solve()
	world.progress.clear_wave(1)
	world.progress.clear_wave(2)
	world._apply_restoration()
	world.player.position = Vector3(81, 1, 8)
	landscape.tick(0)
	for i in 3: await physics_frame
	check(landscape.gates[0].open and ray(Vector3(88, 2, 8)).is_empty(), "Saved garden completion opens the gate when approached")
	check(landscape.celebrations == 1, "Opening a gate celebrates once")
	landscape.tick(0)
	check(landscape.celebrations == 1, "Standing beside an open gate does not repeat the burst")
	guide.enabled = true
	guide._gap = 0
	guide._was_escorting = true
	guide.tick(0)
	check(guide.current_line == "done_0", "Committed milestones queue narrated completion in order")
	guide.stop()
	guide._pending.clear()
	guide._observed_tasks = 2
	guide._gap = 0
	guide.tick(0)
	check(guide.current_line.is_empty(), "Next-island lesson waits until the player reaches that island")
	world.player.position = Vector3(130, 1, 8)
	guide.tick(0)
	check(guide.current_line == "organ", "Arriving in River Song plays the next island instructions")
	guide.stop()
	world.chapter_world.harvest(2)
	press("Harvest protected story allotment")
	world._close()
	world.chapter_world.open_instrument(2)
	for i in 3: await process_frame
	check(world.options.get_node_or_null("ActivityFlow") != null, "Garden instrument receives visual instructions")
	check(world.options.get_parent().scroll_vertical == 0, "Instrument opens on its title, lesson and tuning controls")
	var tuning_row: HBoxContainer
	for row in world.options.get_children():
		if row.get_meta("tuning_index", -1) == 0: tuning_row = row
	tuning_row.get_child(2).grab_focus()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await process_frame
	enter = enter.duplicate()
	enter.pressed = false
	Input.parse_input_event(enter)
	await process_frame
	check(world.chapter_world.challenge.input[0] == 1 and world.modal_open, "Enter activates focused Tighten without submitting the composition")
	var exit_menu := world.panel.find_child("ExitMenu", true, false) as Button
	check(exit_menu != null and exit_menu.is_visible_in_tree(), "Every garden menu has a visible exit button")
	check(world.panel.get_global_rect().encloses(exit_menu.get_global_rect()), "Exit stays inside the card outside the scrolling content")
	exit_menu.pressed.emit()
	check(not world.modal_open and world.player.input_enabled, "Exit menu restores exploration controls")
	world._close()
	world.queue_free()
	await process_frame
	print("HEART JOURNEY PRESENTATION: PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
