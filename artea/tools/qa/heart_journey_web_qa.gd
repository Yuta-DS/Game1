extends Node3D
## Opt-in visual/interaction fixture. Never touches the player's real save.
var world: Node3D
var command: JavaScriptObject
var waiting_for_voice := false
var first_caption := ""
var page_advanced := false

func _ready() -> void:
	world = (load("res://scenes/heart_melody/heart_melody_world.tscn") as PackedScene).instantiate()
	world.test_mode = true
	world.progress.path = "user://heart_journey_browser_qa.json"
	for suffix in ["", ".tmp", ".bak"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(world.progress.path + suffix))
	add_child(world)
	for i in 8: await get_tree().process_frame
	world.milo_guide.enabled = false
	world.milo_guide.stop()
	world.player.set_physics_process(false)
	world.player.position = Vector3(-65, 1.1, 24)
	command = JavaScriptBridge.create_callback(func(args): run(str(args[0])))
	JavaScriptBridge.get_interface("window").arteaJourneyQA = command
	print("JOURNEY QA ready")

func _process(_delta: float) -> void:
	if waiting_for_voice and world.milo_guide.panel.visible and not page_advanced and world.milo_guide.caption.text != first_caption:
		page_advanced = true
		print("JOURNEY QA transcript page advanced")
	if waiting_for_voice and not world.milo_guide.panel.visible:
		waiting_for_voice = false
		world.milo_guide.enabled = false
		print("JOURNEY QA voice ended and transcript hidden")

func run(stage: String) -> void:
	if world.modal_open: world._close()
	world.milo_guide.stop()
	world.milo_guide.enabled = false
	match stage:
		"intro": world._intro()
		"transcript":
			world.milo_guide.enabled = true
			world.milo_guide.play_line("garden")
			first_caption = world.milo_guide.caption.text
			page_advanced = false
			waiting_for_voice = true
		"harvest": world.chapter_world.harvest(0)
		"journal": world.chapter_world.journal()
		"fountain":
			world.player.position = Vector3(-58, 1, 32)
			world.camera.yaw = 0.6
			world.camera.pitch = -0.35
			var sound := world.journey_landscape.get_node("MeadowSingingFountain/MusicalFountain/FountainMusic") as AudioStreamPlayer3D
			if not sound.playing or sound.volume_db != -12 or sound.unit_size != 4 or sound.max_distance != 28: push_error("JOURNEY QA fountain not gently spatialized")
			if not world.soundscape.layers.is_empty(): push_error("JOURNEY QA garden background music still present")
		"gate":
			_press_harvest(0)
			for i in 3:
				world._planter(i)
				_press("Confirm planting / appearance")
			world.musical_garden._flower_activity()
			for symbol in ["LEAF", "SUN", "DROPLET"]: _press("Add " + symbol)
			_press("Answer the flowers")
			world._close()
			if not world.progress.committed.solved: push_error("JOURNEY QA flower answer did not unlock clearing")
			for wave in [1, 2]:
				world.player.position = world.encounter_center
				for i in 3: await get_tree().process_frame
				if world.active_wave != wave or world.enemies.is_empty(): push_error("JOURNEY QA clearing did not spawn wave " + str(wave))
				for enemy in world.enemies.duplicate():
					enemy.phase = "recovery"
					enemy.take_damage(100, world.player)
				world._close()
				print("JOURNEY QA flower answer wave ", wave, " cleared")
			world.player.position = Vector3(79, 1, 8)
			world.camera.yaw = -PI / 2
			world.camera.pitch = -0.28
			world.journey_landscape.tick(0)
			if not world.journey_landscape.gates[0].open: push_error("JOURNEY QA gate failed")
		"instrument":
			_press_harvest(2)
			world.player.position = Vector3(136, 1, 8)
			world.chapter_world.open_instrument(2)
		"river-organ": _river_activity(2, 2)
		"river-harp": _river_activity(3, 1)
		"river-bells": _river_activity(4, 3)
		"bridge-chimes":
			world._close()
			world.player.position = Vector3(250, 1, 8)
			for x in [262.0, 274.0, 286.0]:
				var target := world.to_global(Vector3(x, 1, 8))
				if world.player.test_move(world.player.global_transform, target - world.player.global_position):
					push_error("JOURNEY QA FAILURE: locked gate blocks a bridge chime")
				world.player.global_position = target
				await get_tree().physics_frame
			if world.journey_landscape.gates[2].open: push_error("JOURNEY QA FAILURE: bridge chime gate bypassed its requirements")
			world.camera.yaw = -PI / 2
			world.camera.pitch = -0.4
	for i in 3: await get_tree().process_frame
	if stage == "river-bells" and not world.journey_landscape.gates[1].collider.disabled:
		push_error("JOURNEY QA FAILURE: Bell Grove collider stayed closed")
	if world.modal_open:
		var rect: Rect2 = world.panel.get_global_rect()
		print("JOURNEY QA panel ", stage, " ", rect.size.x, " ", rect.size.y)
		await get_tree().create_timer(0.4).timeout
		if stage == "instrument":
			for row in world.options.get_children():
				if row.get_meta("tuning_index", -1) != 0: continue
				row.get_child(2).grab_focus()
				var enter := InputEventKey.new()
				enter.keycode = KEY_ENTER
				enter.physical_keycode = KEY_ENTER
				enter.pressed = true
				Input.parse_input_event(enter)
				await get_tree().process_frame
				enter = enter.duplicate()
				enter.pressed = false
				Input.parse_input_event(enter)
				await get_tree().process_frame
				if world.chapter_world.challenge.input[0] != 1 or not world.modal_open:
					push_error("JOURNEY QA FAILURE: Enter did not select the focused tuning button")
			var visible_rect: Rect2 = world.options.get_parent().get_global_rect()
			for button in world.options.find_children("*", "Button", true, false):
				if button.text != "Check composition": continue
				var button_rect: Rect2 = button.get_global_rect()
				if button_rect.position.y < visible_rect.position.y or button_rect.end.y > visible_rect.end.y + 1:
					push_error("JOURNEY QA FAILURE: organ confirmation is outside the visible controls")
				else: print("JOURNEY QA organ confirmation visible")
		var exit_menu := world.panel.find_child("ExitMenu", true, false) as Button
		if exit_menu == null or not world.panel.get_global_rect().encloses(exit_menu.get_global_rect()):
			push_error("JOURNEY QA FAILURE: menu exit is not visible inside the card")
		if world.options.get_parent().scroll_vertical != 0:
			push_error("JOURNEY QA menu did not start on its heading: " + stage)
			return
		print("JOURNEY QA heading visible ", stage)
	print("JOURNEY QA stage ", stage)

func _river_activity(task: int, fruit: int) -> void:
	_press_harvest(fruit)
	var kind: String = {2: "river_valve", 3: "river_bulb", 4: "river_boat"}[task]
	for index in world.interactables.size():
		var item: Dictionary = world.interactables[index]
		if item.kind != kind or item.index != 0: continue
		world.player.position = item.pos + Vector3(0, 0, 1)
		world.nearest = index
		world._interact_nearest()
		break
	if not world.modal_open or world.chapter_world.active_task != task:
		push_error("JOURNEY QA FAILURE: River control did not open task " + str(task))
		return
	var target: Array = world.chapter_world.challenge.target
	if task in [2, 3]:
		for row in world.options.get_children():
			if not row.has_meta("tuning_index"): continue
			var index := int(row.get_meta("tuning_index"))
			var notes: Array = world.chapter_world.challenge.input
			var current := int(notes[index]) if index < notes.size() else 0
			for step in absi(int(target[index]) - current): row.get_child(2 if target[index] > current else 1).pressed.emit()
	else:
		for note in target:
			for button in world.options.find_children("*", "Button", true, false):
				if button.text.begins_with(str(int(note) + 1) + "\n"): button.pressed.emit(); break
	_press("Check composition")
	world._close()
	world.player.position = Vector3(207, 1, -8)
	world.camera.yaw = -PI / 2
	world.camera.pitch = -0.25
	world.journey_landscape.tick(0)
	var gate: Dictionary = world.journey_landscape.gates[1]
	if world.progress.committed.chapter.tasks.size() != task + 1 or gate.open != (task == 4):
		push_error("JOURNEY QA FAILURE: River completion/gate mismatch for task " + str(task))
	if task < 4 and not gate.sign.text.contains("Hush Vine" if task == 2 else "Rain Boat"):
		push_error("JOURNEY QA FAILURE: River gate does not identify the next activity")

func _press_harvest(index: int) -> void:
	world.chapter_world.harvest(index)
	_press("Harvest protected story allotment")
	world._close()

func _press(text: String) -> void:
	for button in world.options.find_children("*", "Button", true, false):
		if button.text == text: button.pressed.emit(); return
	push_error("JOURNEY QA missing control " + text)
