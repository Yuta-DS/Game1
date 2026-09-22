extends Node3D
const Art = preload("res://scripts/heart_melody/heart_art.gd")
const Catalog = preload("res://scripts/heart_melody/heart_catalog.gd")
const Progress = preload("res://scripts/heart_melody/heart_progress.gd")
const Enemy = preload("res://scripts/heart_melody/heart_enemy.gd")
const PlayerScene = preload("res://scenes/player_3d.tscn")
@export var embedded_in_overworld := false
var overworld_player: CharacterBody3D
var embedded_active := false
var _introduced := false
var _previous_camera: Camera3D
var _previous_player_camera: Camera3D
var _previous_speed := 10.0
var _previous_blocking := false
var _suspended_nodes: Array[Dictionary] = []
var progress = Progress.new()
var player: CharacterBody3D
var camera: Camera3D
var modal_open := false
var combat_assist := false
var puzzle_assist := false
var reduced_motion := false
var encounter_center := Vector3(44, 1, -16)
var interactables: Array[Dictionary] = []
var plants: Array[Node3D] = []
var drums: Array[Node3D] = []
var enemies: Array = []
var active_wave := 0
var nearest := -1
var hud: Label
var prompt: Button
var panel: PanelContainer
var options: VBoxContainer
var message: Label
var bridge: Node3D
var bridge_barrier: StaticBody3D
var preview_choice := 6
var preview_planter := 0
var hint_level := 0
var audio: AudioStreamPlayer
var demonstration := false
var scene_ready := false
var test_mode := false
var _ambient_time := 0.0
var _ambient_step := 0
var _controller_bindings: Array = []
var _note_cache: Dictionary = {}
var _panel_generation := 0
var _large_text := false
var _restoration_tween: Tween
var _restoring := false
var soundscape: Node
var phrase_platform: Node3D
var restored_creatures: Dictionary = {}
var _view_garden := false

func _ready() -> void:
	# This island's authored guides share its single interaction owner. The
	# generic following Milo otherwise polls Q independently and opens a second UI.
	set_meta("owns_companion_guidance", true)
	progress.load_progress()
	_load_settings()
	_configure_controller()
	_build_environment()
	_build_player()
	_build_hud()
	_refresh_plants()
	_apply_restoration()
	scene_ready = true
	if embedded_in_overworld:
		get_node("HeartHUD").hide()
		for layer in soundscape.layers: layer.stream_paused = true
	else:
		if not test_mode: _intro()
		if not progress.recovery_message.is_empty(): _notice(progress.recovery_message)

func player_local_position() -> Vector3:
	return to_local(player.global_position)

func _set_embedded_active(active: bool) -> void:
	if embedded_active == active: return
	embedded_active = active
	player.set_meta("heart_melody_active", active)
	get_node("HeartHUD").visible = active
	for layer in soundscape.layers: layer.stream_paused = not active
	if active:
		_previous_camera = get_viewport().get_camera_3d()
		_previous_player_camera = player.get("_camera")
		_previous_speed = player.speed
		_previous_blocking = player.blocking_enabled
		player.speed = 10.0
		player.blocking_enabled = get_node("/root/JourneyState").has_treasure("harmony_jewel")
		player.set("_camera", camera)
		camera.make_current()
		_camera_update(1)
		# Suspend only the competing local guides/story UI, preserving their state.
		var scene := get_tree().current_scene
		if scene != null:
			for node_name in ["WonderfulCounsellorMilo", "ConnectedKingdomStory", "ConnectedStoryHUD", "CrownLineHUD", "CombatHelpHUD"]:
				var node := scene.find_child(node_name, true, false)
				if node == null: continue
				var record := {"node": node, "mode": node.process_mode}
				if node is CharacterBody3D:
					record["collision_layer"] = node.collision_layer
					record["collision_mask"] = node.collision_mask
					node.collision_layer = 0
					node.collision_mask = 0
				if node is CanvasLayer or node is CanvasItem or node is Node3D:
					record["visible"] = node.visible
					node.hide()
				node.process_mode = Node.PROCESS_MODE_DISABLED
				_suspended_nodes.append(record)
		if not _introduced and not test_mode:
			_introduced = true
			_intro()
		if not progress.recovery_message.is_empty(): _notice(progress.recovery_message)
	else:
		if modal_open: _close()
		audio.stop()
		progress.commit()
		player.speed = _previous_speed
		player.blocking_enabled = _previous_blocking
		player.set("_camera", _previous_player_camera)
		if is_instance_valid(_previous_camera):
			_previous_camera.make_current()
			if _previous_camera.has_method("_snap_to_follow_target"):
				_previous_camera.call("_snap_to_follow_target")
		for record in _suspended_nodes:
			if not is_instance_valid(record.node): continue
			record.node.process_mode = record.mode
			if record.has("visible"): record.node.visible = record.visible
			if record.has("collision_layer"):
				record.node.collision_layer = record.collision_layer
				record.node.collision_mask = record.collision_mask
		_suspended_nodes.clear()

func _build_environment() -> void:
	var island := Node3D.new()
	island.name = "IslandOne"
	add_child(island)
	Art.paired_island(island, embedded_in_overworld)
	var recovery := Area3D.new()
	recovery.name = "RecoveryVolume"
	recovery.position = Vector3(0, -18, 0)
	recovery.collision_layer = 0
	recovery.collision_mask = 1
	var recovery_shape := CollisionShape3D.new()
	var recovery_box := BoxShape3D.new()
	recovery_box.size = Vector3(500, 6, 300)
	recovery_shape.shape = recovery_box
	recovery.add_child(recovery_shape)
	island.add_child(recovery)
	recovery.body_entered.connect(func(body):
		if body == player and (not embedded_in_overworld or embedded_active): call_deferred("_recover")
	)

	# Broad connected ground; paths sit flush above it and require no jumps.
	for segment in [[Vector3(-70, 0.04, 12), Vector3(-35, 0.04, 12)], [Vector3(-35, 0.04, 12), Vector3(5, 0.04, 8)], [Vector3(5, 0.04, 8), Vector3(42, 0.04, 8)], [Vector3(42, 0.04, 8), Vector3(64, 0.04, 8)]]:
		var a: Vector3 = segment[0]
		var b: Vector3 = segment[1]
		var path := Art.box(island, (a + b) / 2, Vector3(5, 0.06, a.distance_to(b) + 1), Color("cdb990"))
		path.look_at_from_position(to_global((a + b) / 2), to_global(b))
	for segment in [[Vector3(-40, 0.06, 8), Vector3(-34, 0.06, 26)], [Vector3(-34, 0.06, 26), Vector3(-20, 0.06, 26)], [Vector3(-20, 0.06, 26), Vector3(-12, 0.06, 8)], [Vector3(25, 0.06, 8), Vector3(44, 0.06, -4)], [Vector3(-60, 0.06, 12), Vector3(-60, 0.06, 21)]]:
		var a: Vector3 = segment[0]
		var b: Vector3 = segment[1]
		var path := Art.box(island, (a + b) / 2, Vector3(3, 0.04, a.distance_to(b) + 1), Color("cdb990"))
		path.look_at(to_global(b))
	for pos in [Vector3(-76,0,-16), Vector3(-58,0,-31), Vector3(-22,0,-34), Vector3(-13,0,33), Vector3(17,0,33), Vector3(57,0,-30), Vector3(57,0,32)]:
		Art.tree(island, pos, int(absf(pos.x)) % 2)
	for i in 24:
		var angle := TAU * i / 24.0
		var pos := Vector3(cos(angle) * 78, 0, sin(angle) * 42)
		if pos.x > 62: continue
		Art.cone(island, pos + Vector3(0, 0.7, 0), 1.7, 0.8, 1.4, Color("b8b2a2"), true, 5 + i % 3)
		Art.flower(island, pos + Vector3(2, 0, 1), Color("d8b7ba"), 0.6)
	# The overlook is physically separate: the committed crossing spans real void.
	Art.box(island, Vector3(66, 0.85, -21), Vector3(1, 1.7, 54), Color("796e56"), true)
	Art.box(island, Vector3(66, 0.85, 30), Vector3(1, 1.7, 37), Color("796e56"), true)
	Art.island(island, Vector3(94, 0, 8), 9, 12, Color("8fab88"))
	for i in range(1, 14):
		var angle := -PI + i * TAU / 14.0
		var pos := Vector3(94 + cos(angle) * 8.5, 0.8, 8 + sin(angle) * 8.5)
		var rail := Art.box(island, pos, Vector3(4.2, 1.6, 0.7), Color("796e56"), true)
		rail.rotation.y = -angle + PI / 2
	Art.cone(island, Vector3(-35, 0.06, -16), 9, 9, 0.07, Color("8fc5c4"), false, 16)
	Art.label(island, "QUIET MEADOW", Vector3(-53, 6, -6), 45)
	Art.label(island, "FEELING GARDEN", Vector3(8, 7, -10), 45)
	var landmark := Art.flower(island, Vector3(8, 0, -23), Color("dba0b2"), 6.0)
	landmark.name = "GardenHeartBlossom"
	landmark.scale = Vector3(0.4, 0.7, 0.4)
	var blight := Node3D.new()
	blight.name = "BlightCovering"
	island.add_child(blight)
	for i in 7:
		Art.cone(blight, Vector3(8 + cos(i * TAU / 7) * 4, 1.2, -23 + sin(i * TAU / 7) * 4), 1.4, 0.1, 2.4, Color("685971"), false, 5)
	Art.cone(island, Vector3(8, 0.7, -23), 5.8, 5.2, 1.4, Color("879477"), true)
	_gate(island, Vector3(-76, 0, 12), "Walk back to station 03" if embedded_in_overworld else "Castle return")
	if not embedded_in_overworld:
		_object("gate", -1, Vector3(-72, 1, 12), "Return to the Castle")
	Art.box(island, Vector3(-60, 1, 23), Vector3(5, 0.5, 1.5), Color("816c5a"), true)
	for x in [-62, -58]: Art.box(island, Vector3(x, 0.4, 23), Vector3(0.5, 0.8, 1.2), Color("b5aa95"), true)
	_object("bench", -1, Vector3(-60, 1, 21), "Song Memory Bench")
	Art.label(island, "SONG MEMORY BENCH", Vector3(-60, 3, 23), 26)
	Art.cone(island, Vector3(-54, 1.5, 23), 0.7, 0.3, 3, Color("85765b"), true)
	Art.cone(island, Vector3(-54, 3.4, 23), 1.1, 0.5, 1.6, Color("f1cf88"))
	_object("lantern", -1, Vector3(-54, 1, 21), "Comfort Lantern · heal and rest")
	Art.label(island, "COMFORT LANTERN", Vector3(-54, 5, 23), 26)
	for i in 3:
		var pos := Vector3(-40 + i * 14, 0, 3 if i != 1 else 22)
		var bloom := Art.planter(island, pos, i)
		plants.append(bloom)
		Art.label(island, Catalog.SYMBOLS[i] + " seed", pos + Vector3(0, 4.8, 0), 30)
		_object("planter", i, pos + Vector3(0, 1, 3.2), "Plant / replay " + Catalog.SYMBOLS[i] + " seed")
	for i in 3:
		var pos := Vector3(0 + i * 7, 0, 0)
		Art.cone(island, pos + Vector3(0, 0.5, 0), 1.5, 1.2, 1, Color("879477"), true)
		drums.append(Art.flower(island, pos + Vector3(0, 0.8, 0), Catalog.COLOURS[i * 2], 2.2))
		Art.symbol(island, pos + Vector3(0, 0.9, 2), i)
		Art.label(island, Catalog.SYMBOLS[i], pos + Vector3(0, 5, 0), 34)
		_object("drum", i, pos + Vector3(0, 1, 3.2), "Play " + Catalog.SYMBOLS[i])
	_object("phrase", -1, Vector3(7, 1, 9), "Arrange the garden phrase")
	Art.label(island, "LISTENING CIRCLE", Vector3(7, 0.4, 12), 24)
	Art.cone(island, Vector3(44, 0.06, -16), 14, 14, 0.08, Color("b6b292"), false, 20)
	Art.label(island, "BLIGHT CLEARING\nEnter when the flowers are singing", Vector3(44, 5, -29), 32)
	Art.label(island, "SHELTER · return towards the lantern to rest", Vector3(27, 2, 7), 25)
	phrase_platform = Node3D.new()
	phrase_platform.name = "SettledSongPlatform"
	island.add_child(phrase_platform)
	Art.box(phrase_platform, Vector3(26, -0.1, 8), Vector3(6, 0.3, 4), Color("b19c79"), true)
	for z in [6.2, 9.8]: Art.cone(phrase_platform, Vector3(26, -0.6, z), 0.7, 0.7, 0.7, Color("796e56"))
	bridge = Node3D.new()
	bridge.name = "RestoredRootCrossing"
	add_child(bridge)
	Art.box(bridge, Vector3(76, 0.1, 8), Vector3(24, 0.2, 4), Color("b19c79"), true)
	for z in [5.7, 10.3]: Art.box(bridge, Vector3(76, 1, z), Vector3(24, 1.6, 0.5), Color("7e785a"), true)
	var barrier_mesh := Art.box(self, Vector3(66, 1.5, 8), Vector3(0.7, 3, 4.5), Color("747357"), true)
	bridge_barrier = barrier_mesh.get_child(0)
	bridge_barrier.name = "ClosedRootCollision"
	bridge_barrier.set_meta("visual", barrier_mesh)
	_gate(island, Vector3(88, 0, 8), "River Song — coming next")
	Art.box(island, Vector3(89, 2, 8), Vector3(0.8, 4, 5), Color("748465"), true)
	Art.island(island, Vector3(160, -6, -12), 24, 25, Color("93afa0"))
	Art.tree(island, Vector3(158, -6, -12), 1)
	for info in [["mayor_milo", Vector3(-63, 0, 6)], ["guardian_angel", Vector3(-54, 0, 5)]]:
		var guide: Node3D = load("res://scenes/mind_spark/cast/" + info[0] + ".tscn").instantiate()
		guide.position = info[1]
		guide.scale = Vector3.ONE * 0.5
		guide.default_line = "Every feeling may speak here. Choose a feeling, or simply choose a sound."
		island.add_child(guide)
	_object("intro", -1, Vector3(-60, 1, 8), "Talk with Milo and the Guardian")
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c5dce0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e3e8d6")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	if not embedded_in_overworld: add_child(environment)
	else: environment.free()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_color = Color("fff1d2")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	if not embedded_in_overworld: add_child(sun)
	else: sun.free()
	audio = AudioStreamPlayer.new()
	audio.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(audio)
	soundscape = preload("res://scripts/heart_melody/heart_soundscape.gd").new()
	add_child(soundscape)
	for spec in Catalog.ENEMIES:
		var wave := 1 if str(spec.id).begins_with("wave1") else 2
		if progress.committed.waves.has(wave): restore_creature(spec, Vector3(38 + wave * 4, 1, -22 if spec.kind == "moth" else -10))

func _gate(parent: Node3D, pos: Vector3, words: String) -> void:
	for z in [-3, 3]: Art.cone(parent, pos + Vector3(0, 3, z), 0.9, 0.5, 6, Color("84775d"), true)
	Art.box(parent, pos + Vector3(0, 6, 0), Vector3(1, 0.8, 7), Color("84775d"))
	Art.flower(parent, pos + Vector3(0, 5.5, 0), Color("e7b8c2"), 1.4)
	Art.label(parent, words, pos + Vector3(0, 8, 0), 30)

func _object(kind: String, index: int, pos: Vector3, title: String) -> void:
	interactables.append({"kind": kind, "index": index, "pos": pos, "title": title})

func _build_player() -> void:
	if embedded_in_overworld:
		player = overworld_player
		player.health_changed.connect(_health_changed)
		camera = Camera3D.new()
		camera.fov = 62
		add_child(camera)
		camera.current = false
		return
	player = PlayerScene.instantiate()
	player.name = "Player"
	player.blocking_enabled = get_node("/root/JourneyState").has_treasure("harmony_jewel")
	player.add_to_group("Player")
	player.position = Vector3(-65, 2, 12) if progress.data.checkpoint == "arrival" else Vector3(20, 2, 12)
	var visuals := Node3D.new()
	visuals.name = "FoxVisuals"
	var fox: Node3D = load("res://assets3D/characters/fox.glb").instantiate()
	fox.name = "Fox"
	fox.scale = Vector3.ONE * 3
	fox.position.y = -0.98
	visuals.add_child(fox)
	player.add_child(visuals)
	player.get_node("MeshInstance3D").hide()
	add_child(player)
	player.get_node("CombatHelpHUD").queue_free()
	player.health_changed.connect(_health_changed)
	camera = Camera3D.new()
	camera.fov = 62
	camera.current = true
	camera.attributes = CameraAttributesPractical.new()
	add_child(camera)
	_camera_update(1)

func _camera_update(delta: float) -> void:
	var target := player.global_position + Vector3(8 if _view_garden and modal_open else 0, 15, 21)
	camera.global_position = camera.global_position.lerp(target, minf(delta * 7, 1))
	camera.look_at(camera.global_position + Vector3(0, -14, -21))

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HeartHUD"
	add_child(layer)
	var top := PanelContainer.new()
	top.position = Vector2(24, 20)
	top.custom_minimum_size = Vector2(600, 130)
	layer.add_child(top)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 30 if _large_text else 24)
	hud.custom_minimum_size.x = 600
	hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(hud)
	prompt = Button.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	prompt.position = Vector2(24, -85)
	prompt.custom_minimum_size = Vector2(620, 96 if DisplayServer.is_touchscreen_available() else 60)
	prompt.add_theme_font_size_override("font_size", 24)
	prompt.pressed.connect(_interact_nearest)
	layer.add_child(prompt)
	var help := Button.new()
	help.text = "Help & settings"
	help.position = Vector2(670, 24)
	help.custom_minimum_size = Vector2(200, 52)
	help.add_theme_font_size_override("font_size", 24)
	help.pressed.connect(_help)
	layer.add_child(help)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-350, -330)
	panel.custom_minimum_size = Vector2(700, 560)
	layer.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("293d36")
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 560)
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	options = VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 8)
	scroll.add_child(options)
	panel.hide()
	if DisplayServer.is_touchscreen_available():
		for entry in [["←", "move_left", Vector2(24, -230)], ["↑", "move_forward", Vector2(128, -334)], ["↓", "move_backward", Vector2(128, -230)], ["→", "move_right", Vector2(232, -230)], ["Strike", "attack", Vector2(350, -230)]]:
			var button := Button.new()
			button.text = entry[0]
			button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
			button.position = entry[2]
			button.custom_minimum_size = Vector2(96, 96)
			button.add_theme_font_size_override("font_size", 24)
			button.button_down.connect(func(): Input.action_press(entry[1]))
			button.button_up.connect(func(): Input.action_release(entry[1]))
			layer.add_child(button)

func _process(delta: float) -> void:
	if not scene_ready: return
	if embedded_in_overworld:
		var local := player_local_position()
		if embedded_active and local.y < -15:
			_recover()
			local = player_local_position()
		# Hysteresis keeps the camera steady at the foot of the entrance arch.
		var inside := local.x > (-100 if embedded_active else -88) and local.x < 110 and absf(local.z) < 66 and local.y < 24 and local.y > -12
		if inside and not embedded_active and get_node("/root/JourneyCampaign").can_enter_kingdom("heart"):
			_set_embedded_active(true)
		elif not inside and embedded_active:
			_set_embedded_active(false)
		if not embedded_active: return
	_camera_update(delta)
	if player_local_position().y < -15: _recover()
	nearest = -1
	var distance := 5.0
	for i in interactables.size():
		var d: float = player_local_position().distance_to(interactables[i].pos)
		if d < distance and _clear_sight(interactables[i].pos):
			distance = d
			nearest = i
	prompt.visible = nearest >= 0 and not modal_open
	if nearest >= 0: prompt.text = "Q / A · " + str(interactables[nearest].title)
	hud.text = "  HEART MELODY · Wake the Feeling Garden\n  " + objective() + "\n  Seeds %d/3  ·  Health %d  ·  XP %d" % [progress.data.planters.size(), player.current_health, progress.data.xp]
	if progress.dirty: hud.text += "  ·  Save pending — retry in Help"
	if not modal_open and progress.committed.solved and not progress.data.complete and active_wave == 0 and player_local_position().distance_to(encounter_center) < 13:
		_start_wave(2 if progress.data.waves.has(1) else 1)
	_ambient_time += delta
	if progress.committed.complete and not reduced_motion:
		for i in plants.size(): plants[i].rotation.z = sin(_ambient_time * 1.3 + i) * 0.025

func objective() -> String:
	if progress.data.complete and not progress.committed.complete: return "Garden restored in this session. Retry saving in Help to open the crossing."
	if progress.data.complete: return "Feeling Garden restored — 80 XP. The river is waiting."
	if progress.data.solved and not progress.committed.solved: return "Phrase solved in this session. Retry saving in Help before the encounter."
	if progress.data.solved: return "Enter the Blight clearing. Step aside; strike during recovery."
	if progress.data.planters.size() == 3 and progress.committed.planters.size() < 3: return "Three seeds planted in this session. Retry saving in Help to awaken the drums."
	if progress.data.planters.size() == 3: return "Listen to the flowers, then play their three-note phrase."
	return "Plant three seeds. Every feeling or sound is welcome."

func _unhandled_input(event: InputEvent) -> void:
	if embedded_in_overworld and not embedded_active: return
	if event.is_action_pressed("ui_cancel") and modal_open:
		_close()
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("interact") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A)) and not modal_open:
		_interact_nearest()
		get_viewport().set_input_as_handled()

func _interact_nearest() -> void:
	if nearest < 0 or modal_open: return
	var item: Dictionary = interactables[nearest]
	if player_local_position().distance_to(item.pos) >= 5 or not _clear_sight(item.pos): return
	match item.kind:
		"planter": _planter(item.index)
		"drum":
			if progress.committed.planters.size() < 3: _notice("The flowers are resting. Plant and save all three seeds first. Retry a pending save in Help.")
			else:
				note(item.index)
				_pulse(drums[item.index])
				if not progress.data.solved and progress.data.phrase.size() < 3:
					var phrase: Array = progress.data.phrase.duplicate()
					phrase.append(item.index)
					progress.edit_phrase(phrase)
		"phrase": _phrase_panel()
		"bench": _bench()
		"lantern":
			player.heal(100)
			note(2)
			_notice("Restored to full health.\n" + objective())
		"intro": _intro()
		"gate":
			if progress.commit(): get_node("/root/JourneyCampaign").return_to_campaign()
			else: _notice("Your progress is still here. Saving failed; retry before leaving.")

func _open(title: String, body: String) -> void:
	_view_garden = false
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -380
	panel.offset_top = -330
	panel.offset_right = 380
	panel.offset_bottom = 330
	_panel_generation += 1
	demonstration = false
	modal_open = true
	player.set_input_enabled(false)
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 34 if _large_text else 30)
	options.add_child(heading)
	message = Label.new()
	message.text = body
	message.custom_minimum_size.x = 680
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 28 if _large_text else 22)
	options.add_child(message)
	panel.show()

func _button(title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 96 if DisplayServer.is_touchscreen_available() else 52
	button.add_theme_font_size_override("font_size", 27 if _large_text else 21)
	button.pressed.connect(action)
	options.add_child(button)
	if options.get_child_count() == 3: button.grab_focus()
	return button

func _close() -> void:
	_panel_generation += 1
	demonstration = false
	if _restoring: _finish_restoration()
	_refresh_plants()
	modal_open = false
	panel.hide()
	player.set_input_enabled(true)
	prompt.grab_focus()

func _notice(body: String) -> void:
	_open("Heart Melody", body)
	_button("Continue", _close)

func _intro() -> void:
	_open("A garden waiting for its song", "Milo: The garden has gone quiet. Let's plant three seeds and help its flowers find their song.\n\nMother Guardian: Every feeling may speak here. You can choose a feeling, or simply choose a sound.")
	_button("Explore the garden", _close)
	_button("Optional greeting", func(): _identity(0))
	_button("Skip introduction", _close)

func _planter(index: int) -> void:
	preview_planter = index
	_open(Catalog.SYMBOLS[index] + " planter", "Choose an appearance and sound. All choices succeed. Nothing is saved until you confirm.")
	if progress.data.planters.has(str(index)):
		_button("Replay planted note", func(): note(index, 0.22, int(progress.data.planters[str(index)])); _pulse(plants[index]))
	var row := HBoxContainer.new()
	options.add_child(row)
	var select := OptionButton.new()
	for choice in Catalog.CHOICES: select.add_item("Choose a sound instead" if choice == "Sound" else choice)
	select.selected = int(progress.data.planters.get(str(index), 6))
	preview_choice = select.selected
	select.item_selected.connect(func(value: int): preview_choice = value)
	select.custom_minimum_size = Vector2(650, 52)
	select.add_theme_font_size_override("font_size", 27 if _large_text else 21)
	row.add_child(select)
	select.grab_focus()
	_button("Preview sound and symbol", func():
		note(index, 0.22, preview_choice)
		plants[index].scale = Vector3.ONE * 0.55
		for child in plants[index].get_children():
			if child is MeshInstance3D and child.position.y > 1 and child.position.y < 1.3:
				child.material_override = Art.material(Catalog.COLOURS[preview_choice])
		message.text = "Preview: " + Catalog.CHOICES[preview_choice] + " · " + Catalog.SYMBOLS[index] + ". Confirm to grow this flower."
	)
	_button("Confirm planting / appearance", func():
		progress.plant(index, preview_choice)
		_refresh_plants()
		note(index, 0.22, preview_choice)
		_close()
		if not reduced_motion:
			plants[index].scale = Vector3.ONE * 0.3
			create_tween().tween_property(plants[index], "scale", Vector3.ONE, 0.65)
	)
	_button("Cancel — keep previous flower", _close)

func _refresh_plants() -> void:
	for i in plants.size():
		var planted: bool = progress.data.planters.has(str(i))
		plants[i].scale = Vector3.ONE if planted else Vector3(0.28, 0.45, 0.28)
		for child in plants[i].get_children():
			if child is MeshInstance3D and child.position.y > 1 and child.position.y < 1.3:
				child.material_override = Art.material(Catalog.COLOURS[int(progress.data.planters.get(str(i), 6))])
	soundscape.restore(progress.committed.planters.size() == 3, progress.committed.complete)
	for drum in drums: drum.scale = Vector3.ONE if progress.committed.planters.size() == 3 else Vector3(0.55, 0.8, 0.55)

func _phrase_text() -> String:
	var names: PackedStringArray = []
	for value in progress.data.phrase: names.append(Catalog.SYMBOLS[int(value)])
	return "Your phrase: " + (" → ".join(names) if names.size() else "no notes yet")

func _phrase_panel() -> void:
	if progress.committed.planters.size() < 3:
		_notice("Plant and save three seeds to open the drum flowers. Retry a pending save in Help.")
		return
	_open("The flower phrase", "Hear the garden phrase, then arrange three notes. There is no time limit.\n" + _phrase_text())
	_view_garden = true
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -800
	panel.offset_top = -330
	panel.offset_right = -40
	panel.offset_bottom = 330
	_button("Hear the garden phrase", func(): _demonstrate(Catalog.PHRASE))
	if not progress.data.solved:
		var row := HBoxContainer.new()
		options.add_child(row)
		for i in 3:
			var button := Button.new()
			button.text = Catalog.SYMBOLS[i]
			button.custom_minimum_size = Vector2(215, 55)
			if DisplayServer.is_touchscreen_available(): button.custom_minimum_size.y = 96
			button.add_theme_font_size_override("font_size", 27 if _large_text else 21)
			button.pressed.connect(func():
				note(i)
				_pulse(drums[i])
				if progress.data.phrase.size() < 3:
					var phrase: Array = progress.data.phrase.duplicate()
					phrase.append(i)
					progress.edit_phrase(phrase)
				message.text = _phrase_text()
			)
			row.add_child(button)
		_button("Listen to my phrase", func(): _demonstrate(progress.data.phrase.duplicate()))
		_button("Undo last note", func():
			var phrase: Array = progress.data.phrase.duplicate()
			phrase.pop_back()
			progress.edit_phrase(phrase)
			message.text = _phrase_text()
		)
		_button("Reset phrase", func():
			progress.edit_phrase([])
			message.text = _phrase_text()
		)
		_button("Confirm phrase", _confirm_phrase)
	_button("Optional approach", func(): _identity(3))
	_button("Back to garden", _close)

func _confirm_phrase() -> void:
	if progress.data.phrase != Catalog.PHRASE:
		note(0, 0.08)
		var mismatch := 0
		while mismatch < progress.data.phrase.size() and progress.data.phrase[mismatch] == Catalog.PHRASE[mismatch]: mismatch += 1
		message.text = "Note %d is the %s flower. Your phrase is kept; undo or listen again.\n%s" % [mismatch + 1, Catalog.SYMBOLS[Catalog.PHRASE[mini(mismatch, 2)]], _phrase_text()]
		return
	if progress.solve():
		_apply_restoration()
		_notice("The flowers found their phrase. Walk into the marked clearing when ready.\nRead the warning, step aside, then press F to release the shell during recovery.")
		_demonstrate(Catalog.PHRASE)
	else: _notice("The phrase is solved in this session. Please retry saving from Help.")

func _demonstrate(sequence: Array) -> void:
	if demonstration: return
	demonstration = true
	var generation := _panel_generation
	var original := message.text if is_instance_valid(message) else ""
	for raw in sequence:
		if generation != _panel_generation: return
		var index := int(raw)
		note(index)
		_pulse(drums[index])
		if is_instance_valid(message): message.text = "Listen: " + Catalog.SYMBOLS[index] + "\n" + original
		await get_tree().create_timer(1.2 if puzzle_assist else 0.7).timeout
	if generation != _panel_generation: return
	if is_instance_valid(message): message.text = original
	demonstration = false

func _pulse(object: Node3D) -> void:
	if reduced_motion: return
	var tween := create_tween()
	tween.tween_property(object, "scale", Vector3.ONE * 1.12, 0.18)
	tween.tween_property(object, "scale", Vector3.ONE, 0.25)

func _bench() -> void:
	_open("Song Memory Bench", objective())
	_button("Replay the clue with symbols", func(): _demonstrate(Catalog.PHRASE))
	_button("A gentle hint", func():
		hint_level = mini(hint_level + 1, 3)
		message.text = ["", "Find the three large flowers beyond the planters.", "The order is Leaf → Sun → Droplet.", "Watch each flower as the phrase plays slowly."][hint_level]
		if hint_level == 2: _demonstrate(Catalog.PHRASE)
		if hint_level == 3:
			puzzle_assist = true
			_demonstrate(Catalog.PHRASE)
	)
	_button("Optional listening preference", func(): _identity(1))
	_button("Optional helping preference", func(): _identity(2))
	_button("Rest finished", _close)

func _identity(index: int) -> void:
	var entries := [
		["Greeting", "energy", "E", "I", "Talk together first", "Have a quiet moment first"],
		["Listening", "information", "S", "N", "Notice one individual sound", "Notice the whole pattern"],
		["Helping", "decisions", "T", "F", "Try a clear sequence", "Begin with what needs care"],
		["Arranging", "structure", "J", "P", "Plan my phrase first", "Explore sounds first"],
	]
	var entry: Array = entries[index]
	_open("Optional · " + entry[0], "Choosing an answer saves that preference on this device. Skip or Keep private saves nothing. Rewards and puzzle outcomes stay the same.")
	for side in 2:
		_button(entry[4 + side], func():
			if get_node("/root/PlayerIdentityTracker").record_evidence("HM_ID_%02d" % (index + 1), entry[1], entry[2 + side], "heart_melody"): _close()
			else: message.text = "That preference could not be saved. You can try again, skip, or keep it private."
		)
	_button("Skip", _close)
	_button("Keep private — record nothing", _close)

func _help() -> void:
	_save_settings()
	_open("Make yourself comfortable", "WASD / arrows: move · Q: interact · F: strike\nSpace: jump (never required) · Escape: close\n" + objective())
	_button("Combat assistance: " + ("on" if combat_assist else "off"), func(): combat_assist = not combat_assist; _help())
	_button("Slow puzzle demonstrations: " + ("on" if puzzle_assist else "off"), func(): puzzle_assist = not puzzle_assist; _help())
	_button("Reduced motion: " + ("on" if reduced_motion else "off"), func(): reduced_motion = not reduced_motion; _help())
	_button("Text size: toggle large", func():
		_large_text = not _large_text
		hud.add_theme_font_size_override("font_size", 30 if _large_text else 24)
		_help()
	)
	_button("Retry saving", func():
		message.text = "Progress saved." if progress.commit() else "Save failed. Progress remains in this session. Please retry."
		_apply_restoration()
	)
	_button("Return to garden", _close)

func _start_wave(wave: int) -> void:
	if not progress.committed.solved or active_wave != 0 or progress.data.waves.has(wave): return
	active_wave = wave
	for spec in Catalog.ENEMIES:
		if not str(spec.id).begins_with("wave%d" % wave): continue
		var enemy := Enemy.new()
		enemy.spec = spec
		enemy.player = player
		enemy.world = self
		enemy.position = encounter_center + Vector3(-4 if spec.kind == "moth" else 4, 0, -3)
		enemy.released.connect(_enemy_released)
		enemies.append(enemy)
		add_child(enemy)

func _enemy_released(enemy: Node) -> void:
	enemies.erase(enemy)
	if not enemies.is_empty(): return
	var saved: bool = progress.clear_wave(active_wave)
	active_wave = 0
	if saved and progress.data.complete:
		_present_restoration()

func _apply_restoration() -> void:
	var restored: bool = progress.committed.complete
	phrase_platform.position.y = 0 if progress.committed.solved else -0.6
	bridge.visible = restored
	soundscape.restore(progress.committed.planters.size() == 3, restored)
	get_node("IslandOne/BlightCovering").visible = not restored
	get_node("IslandOne/GardenHeartBlossom").scale = Vector3.ONE if restored else Vector3(0.4, 0.7, 0.4)
	bridge_barrier.get_meta("visual").visible = not restored
	for child in bridge_barrier.get_children():
		if child is CollisionShape3D: child.set_deferred("disabled", restored)
	for body in bridge.find_children("*", "CollisionShape3D", true, false): body.set_deferred("disabled", not restored)

func _health_changed(current: float, _maximum: float) -> void:
	if embedded_in_overworld and not embedded_active: return
	if current <= 0: call_deferred("_recover")

func _recover() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy): enemy.queue_free()
	enemies.clear()
	for id in restored_creatures.keys():
		var wave := 1 if str(id).begins_with("wave1") else 2
		if not progress.data.waves.has(wave):
			restored_creatures[id].queue_free()
			restored_creatures.erase(id)
	active_wave = 0
	player.global_position = to_global(Vector3(-56, 2, 17))
	player.velocity = Vector3.ZERO
	player.heal(100)

func note(index: int, volume := 0.22, timbre := 6) -> void:
	var cache_key := str(index) + ":" + str(timbre)
	if _note_cache.has(cache_key):
		audio.stream = _note_cache[cache_key]
		audio.volume_db = linear_to_db(volume)
		audio.play()
		return
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(11025 * 2)
	var frequency: float = [261.63, 329.63, 392.0][index]
	for i in 11025:
		var t := i / 22050.0
		var sample := (sin(TAU * frequency * t) + 0.18 * sin(TAU * frequency * (2 + timbre % 3) * t)) * exp(-t * (5 + timbre * 0.4)) * minf(t * 100, 1) * 0.7
		bytes.encode_s16(i * 2, int(sample * 32767))
	wave.data = bytes
	_note_cache[cache_key] = wave
	audio.volume_db = linear_to_db(volume)
	audio.stream = wave
	audio.play()





func _clear_sight(target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 1.1, 0), to_global(target + Vector3(0, 0.5, 0)), 1, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _configure_controller() -> void:
	for entry in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0], ["move_forward", JOY_AXIS_LEFT_Y, -1.0], ["move_backward", JOY_AXIS_LEFT_Y, 1.0]]:
		var event := InputEventJoypadMotion.new()
		event.axis = entry[1]
		event.axis_value = entry[2]
		if not InputMap.action_has_event(entry[0], event):
			InputMap.action_add_event(entry[0], event)
			_controller_bindings.append([entry[0], event])
	for entry in [["attack", JOY_BUTTON_X], ["jump", JOY_BUTTON_B], ["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var event := InputEventJoypadButton.new()
		event.button_index = entry[1]
		if not InputMap.action_has_event(entry[0], event):
			InputMap.action_add_event(entry[0], event)
			_controller_bindings.append([entry[0], event])

func _exit_tree() -> void:
	for binding in _controller_bindings: InputMap.action_erase_event(binding[0], binding[1])
	for action in ["move_left", "move_right", "move_forward", "move_backward", "attack"]: Input.action_release(action)

func _present_restoration() -> void:
	_notice("Feeling Garden restored — 80 XP\nMilo: You helped the garden find its song.\nThe garden's song is restored. The river is waiting.")
	_button("Skip celebration and explore", _close)
	_apply_restoration()
	if reduced_motion: return
	_restoring = true
	bridge.position.y = -3
	bridge_barrier.get_meta("visual").visible = true
	for shape in bridge_barrier.get_children():
		if shape is CollisionShape3D: shape.set_deferred("disabled", false)
	var blight: Node3D = get_node("IslandOne/BlightCovering")
	blight.show()
	_restoration_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_restoration_tween.tween_property(blight, "scale", Vector3.ONE * 0.01, 0.6)
	_restoration_tween.tween_callback(func(): _demonstrate(Catalog.PHRASE))
	_restoration_tween.tween_property(bridge, "position:y", 0.0, 1.5)
	_restoration_tween.tween_callback(_finish_restoration)

func _finish_restoration() -> void:
	_restoring = false
	if _restoration_tween and _restoration_tween.is_running(): _restoration_tween.kill()
	bridge.position = Vector3.ZERO
	_apply_restoration()
	for flower in plants: _pulse(flower)

func restore_creature(spec: Dictionary, at: Vector3) -> void:
	if restored_creatures.has(spec.id): return
	var creature := Node3D.new()
	creature.name = "Restored_" + str(spec.id)
	creature.position = at
	add_child(creature)
	restored_creatures[spec.id] = creature
	Art.cone(creature, Vector3(0, 1, 0), 1.2, 0.7, 1.6, Color("9bcbb0"), false, 8)
	if spec.kind == "moth":
		for x in [-1, 1]:
			for z in [-1, 1]:
				Art.cone(creature, Vector3(x * 1.3, 1.3, z * 0.7), 1.1, 0.6, 0.2, Color("f2c5a8"), false, 5)
	else:
		Art.cone(creature, Vector3(0.3, 2.1, 0), 0.5, 0, 0.8, Color("53876a"), false, 4)
	Art.label(creature, "Moth restored" if spec.kind == "moth" else "Slime restored", Vector3(0, 3, 0), 22)

func _load_settings() -> void:
	if test_mode: return
	var settings := ConfigFile.new()
	if settings.load("user://heart_melody_settings.cfg") != OK: return
	combat_assist = settings.get_value("accessibility", "combat", false) == true
	puzzle_assist = settings.get_value("accessibility", "puzzle", false) == true
	reduced_motion = settings.get_value("accessibility", "motion", false) == true
	_large_text = settings.get_value("accessibility", "large_text", false) == true

func _save_settings() -> void:
	if test_mode: return
	var settings := ConfigFile.new()
	settings.set_value("accessibility", "combat", combat_assist)
	settings.set_value("accessibility", "puzzle", puzzle_assist)
	settings.set_value("accessibility", "motion", reduced_motion)
	settings.set_value("accessibility", "large_text", _large_text)
	settings.save("user://heart_melody_settings.cfg")
