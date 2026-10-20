extends Node3D
## Opt-in visual/interaction fixture. Never touches the player's real save.
var world: Node3D
var command: JavaScriptObject
var waiting_for_voice := false

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
			waiting_for_voice = true
		"harvest": world.chapter_world.harvest(0)
		"journal": world.chapter_world.journal()
		"fountain":
			world.player.position = Vector3(-58, 1, 32)
			world.camera.yaw = 0.6
			world.camera.pitch = -0.35
			var sound := world.journey_landscape.get_node("MeadowSingingFountain/MusicalFountain/FountainMusic") as AudioStreamPlayer3D
			if not sound.playing or sound.volume_db < -2: push_error("JOURNEY QA fountain not audible")
		"gate":
			_press_harvest(0)
			for i in 3:
				world._planter(i)
				_press("Confirm planting / appearance")
			world.progress.edit_phrase([0, 2, 1])
			world.progress.solve()
			world.progress.clear_wave(1)
			world.progress.clear_wave(2)
			world.player.position = Vector3(79, 1, 8)
			world.camera.yaw = -PI / 2
			world.camera.pitch = -0.28
			world.journey_landscape.tick(0)
			if not world.journey_landscape.gates[0].open: push_error("JOURNEY QA gate failed")
		"instrument":
			_press_harvest(2)
			world.player.position = Vector3(136, 1, 8)
			world.chapter_world.open_instrument(2)
	for i in 3: await get_tree().process_frame
	if world.modal_open:
		var rect: Rect2 = world.panel.get_global_rect()
		print("JOURNEY QA panel ", stage, " ", rect.size.x, " ", rect.size.y)
	print("JOURNEY QA stage ", stage)

func _press_harvest(index: int) -> void:
	world.chapter_world.harvest(index)
	_press("Harvest protected story allotment")
	world._close()

func _press(text: String) -> void:
	for button in world.options.find_children("*", "Button", true, false):
		if button.text == text: button.pressed.emit(); return
	push_error("JOURNEY QA missing control " + text)
