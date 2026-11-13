extends Node3D
const Art = preload("res://scripts/heart_melody/heart_art.gd")
const Catalog = preload("res://scripts/heart_melody/heart_melody_chapter_catalog.gd")
const Fruit = preload("res://scripts/heart_melody/heart_melody_fruit_catalog.gd")
const Director = preload("res://scripts/heart_melody/heart_melody_quest_director.gd")
const Challenge = preload("res://scripts/heart_melody/heart_instrument_challenge_controller.gd")
const EnvironmentState = preload("res://scripts/heart_melody/heart_melody_environment_state.gd")
const Encounter = preload("res://scripts/heart_melody/heart_melody_encounter_director.gd")
const QuestObject = preload("res://scripts/heart_melody/heart_quest_object_base.gd")
const HUD = preload("res://scripts/heart_melody/heart_melody_hud.gd")
const CENTRES := [Vector3(-45, 0, 12), Vector3(30, 0, 8), Vector3(145, 0, 8), Vector3(280, 0, 8), Vector3(396, 0, 8), Vector3(465, 0, 8)]
const FRUIT_POS := [Vector3(-57, 0, 24), Vector3(22, 0, 23), Vector3(119, 0, 22), Vector3(169, 0, 26), Vector3(309, 0, 23), Vector3(446, 0, 22)]
const STATIONS := {2: Vector3(144, 0, 3), 3: Vector3(155, 0, 23), 4: Vector3(178, 0, 12),
	5: Vector3(263, 0, 8), 6: Vector3(297, 0, 8), 7: Vector3(368, 0, 8), 9: Vector3(399, 0, 8)}
const ANCHORS := [Vector3(416, 0, 8), Vector3(387.5, 0, -8.45), Vector3(387.5, 0, 24.45)]
const ANCHOR_IDS := ["rhythm", "pitch", "direction"]
const NOTE_NAMES := ["Leaf / North", "Droplet / East", "Sun / South", "Diamond / West", "Crescent", "Heart"]
const GROVE_DIRECTIONS := ["beside the meadow entrance", "south of the Feeling Garden", "on the near riverbank", "beside the Rain Boat dock", "beside the Peace Garden", "between the stage and sanctuary"]
var world: Node3D
var director := Director.new()
var challenge := Challenge.new()
var encounter := Encounter.new()
var active_task := -1
var instrument_panel_open := false
var active_anchor := -1
var fruit_nodes: Array[Node3D] = []
var regrow: Dictionary = {}
var restoration: Array[Node3D] = []
var stage_shell: Node3D
var jewel: Node3D
var stage_label: Label3D
var wave_marker: Node3D
var clock := 0.0
var caption := ""
var timing_label: Label3D
var timing_lens: Node3D
var assistance := false
var rosin := false
var muted := false
var focus := 100.0
var focus_recovery := 0.0
var chapter_hud: Label
var presentation := HUD.new()
var fruit_objects: Array[Node3D] = []
var note_visuals: Dictionary = {}
var warning_steps := 0
var feedback_until := 0.0

func _ready() -> void:
	world = get_parent()
	director.configure(world.progress)
	assistance = director.snapshot().settings.assistance
	muted = director.snapshot().settings.muted
	_build_valley()
	_build_fruit()
	_build_instruments()
	director.changed.connect(func(_ids): refresh())
	challenge.feedback.connect(_feedback)
	challenge.changed.connect(_store_attempt)
	refresh()

func install_hud() -> void:
	var layer: CanvasLayer = world.get_node("HeartHUD")
	chapter_hud = presentation.build(layer, journal)

func _build_valley() -> void:
	# Extend the original riverbank into a single grounded valley, with broad
	# terraces and a six metre principal route. Scenery has no decorative collision.
	Art.box(self, Vector3(416, -1.1, 8), Vector3(140, 2, 70), Color("a6b29a"), true)
	Art.box(self, Vector3(416, 0.02, 8), Vector3(140, 0.14, 7), Color("e0d9c4"), true)
	# Fenced all round; its west side is open where the Peace Garden runs in.
	Art.rail_rect(self, Vector2(346, -27), Vector2(486, 43), {"x-": [Vector2(8, 58)]})
	for zone in 6:
		var growth := Node3D.new()
		growth.name = "Restoration" + str(zone)
		add_child(growth)
		restoration.append(growth)
		for i in 10:
			var x: float = CENTRES[zone].x - 17 + (i % 5) * 8
			var z := -18.0 if i < 5 else 37.0
			if zone == 3 and x < 308: continue
			Art.flower(growth, Vector3(x, 0, z), Color(["eab7c6", "b8abd5", "e8c875"][i % 3]), 0.8)
			if zone >= 4: Art.tree(self, Vector3(x, 0, z + (-4 if i < 5 else 3)), i % 2)
	for x in [359.0, 431.0, 459.0]:
		Art.flower(self, Vector3(x, 0, 18), Color("e8d489"), 2.0)
		world._object("chapter_checkpoint", int(x), Vector3(x, 1, 16), "Rest at Peace Flower · craft")
	Art.banner(self, "HARMONY STAGE\nBring the valley's voices together", Vector3(397, 10, -7), 32)
	Art.banner(self, "JEWEL SANCTUARY", Vector3(460, 7, -1), 32)
	world._gate(self, Vector3(477, 0, 8), "RETURN TO ART CASTLE")
	world._automatic_return_gate(self, Vector3(477, 0, 8))
	world._object("chapter_gate", 0, Vector3(474, 1, 8), "Return to the Art Castle")
	for index in 4:
		var pos := Vector3(353 + index * 35, 1, 30)
		Art.flower(self, pos - Vector3.UP, Color("b5b1d8"), 0.9)
		world._object("chapter_reflect", index, pos, "Optional private reflection")

func _build_fruit() -> void:
	for index in 6:
		var id: String = Fruit.IDS[index]
		var spec: Dictionary = Fruit.FRUITS[id]
		var grove := QuestObject.new()
		grove.configure(Fruit.story_location(id), ["harvest_story"], func(_action): return director.harvest_story(id))
		fruit_objects.append(grove)
		grove.position = FRUIT_POS[index]
		grove.name = "Fruit_" + id
		add_child(grove)
		Art.cone(grove, Vector3(0, 1.2, 0), 0.35, 0.2, 2.4, Color("826d58"))
		for leaf in 3:
			var branch := Art.cone(grove, Vector3((leaf - 1) * 1.2, 2.4, 0), 1.25, 0.1, 0.35, Color(["91ae81", "698f72", "4d795e"][leaf]), false, 3 + index)
			branch.rotation.z = (leaf - 1) * 0.35
		var fruit := Node3D.new()
		fruit.position = Vector3(0, 2.6, 0)
		grove.add_child(fruit)
		fruit_nodes.append(fruit)
		if index == 0:
			for berry in 5: Art.cone(fruit, Vector3(sin(berry * 2.4) * 0.5, berry * 0.12, cos(berry * 2.4) * 0.4), 0.36, 0.2, 0.6, Color(spec.colour), false, 6)
		else:
			Art.cone(fruit, Vector3.ZERO, 0.65 + index * 0.06, 0.16 if index in [2, 5] else 0.55, 1.2 if index != 4 else 0.9, Color(spec.colour), false, 5 + index)
			if index == 4:
				for rib in 5: Art.box(fruit, Vector3((rib - 2) * 0.25, 0.48, 0), Vector3(0.07, 0.06, 1.1), Color("e3dba6"))
		world._object("chapter_fruit", index, FRUIT_POS[index] + Vector3(0, 1, -2), "Harvest " + spec.label)

func _build_instruments() -> void:
	for task in [2, 3, 4, 5, 6, 7, 9]:
		var centre: Vector3 = STATIONS[task]
		world._object("chapter_instrument", task, centre + Vector3(0, 1, 0), Catalog.TITLES[task])
		if task < 7: continue # Original organ, harp roots, docks and chime arches remain.
		Art.cone(self, centre + Vector3(0, 0.08, 0), 6.5, 6.5, 0.08, Color("dfd7c3"), false, 16)
		if task != 9: Art.banner(self, Catalog.TITLES[task], centre + Vector3(0, 6.5, 0), 28)
	# Five actual strings; changing tension changes their visible height and curve.
	Art.banner(self, "HUSH VINE STRING HARP", Vector3(153, 7, 27), 30)
	Art.banner(self, "HARMONY BRIDGE CHIMES", Vector3(275, 7, 15), 30)
	for string_index in 5:
		var string_node := Art.box(self, Vector3(145 + string_index * 3, 3, 23), Vector3(0.10, 5, 0.10), Color("e7d7ae"))
		note_visuals[30 + string_index] = string_node
	for task in [2, 3, 4, 5, 6, 7, 9]:
		var count := 6 if task == 9 else (5 if task == 3 else (4 if task in [4, 7] else 3))
		for i in count:
			var centre: Vector3 = STATIONS[task]
			var pos := centre + Vector3((i - (count - 1) * 0.5) * 3, 0, -5)
			if task == 6: pos = Vector3(299 + i * 4, 0, 8 + (i - 1) * 3)
			var bloom := Art.flower(self, pos, Color(Fruit.FRUITS[Fruit.IDS[i]].colour), 0.8)
			note_visuals[task * 100 + i] = bloom
			world._object("chapter_note", task * 10 + i, pos + Vector3(0, 1, 1.5), "Play " + NOTE_NAMES[i])
	for i in 3:
		Art.cone(self, ANCHORS[i] + Vector3(0, 1, 0), 1.8, 1.1, 2, Color("e5d9be"), true)
		Art.flower(self, ANCHORS[i] + Vector3(0, 1, 0), Color("b4c7ae"), 1.3)
		world._object("chapter_anchor", i, ANCHORS[i] + Vector3(0, 1, 2.5), "Join " + ANCHOR_IDS[i] + " anchor")
	stage_shell = Node3D.new()
	stage_shell.position = Vector3(399, 0, 8)
	add_child(stage_shell)
	for i in 6:
		var angle := TAU * i / 6.0
		Art.cone(stage_shell, Vector3(sin(angle) * 4, 3, cos(angle) * 4), 1.0, 0.1, 6, Color("6a6175"))
	Art.cone(self, Vector3(399, 2.1, 8), 1.2, 0.5, 3.8, Color("ddcbbb"))
	Art.cone(self, Vector3(399, 4.3, 8), 0.65, 0.3, 1, Color("d3bd8b"))
	stage_label = Art.banner(self, "The Silent Conductor\nListen before you answer", Vector3(399, 7, 8), 30)
	wave_marker = Art.cone(self, Vector3(399, 0.2, 8), 12, 12, 0.12, Color("e3b882"), false, 24)
	wave_marker.visible = false
	timing_label = Art.label(self, "", Vector3(395, 6, -2), 26)
	timing_lens = Art.cone(self, Vector3(395, 4, -2), 0.8, 0.8, 0.1, Color("b8d6d1"))
	jewel = Art.cone(self, Vector3(460, 3, 8), 1.6, 0, 3, Color("b1ded9"), false, 6)
	Art.cone(self, Vector3(460, 0.5, 8), 3, 2.5, 1, Color("e4dcc8"), true)
	world._object("chapter_sanctuary", 0, Vector3(456, 1, 8), "Harmony Jewel sanctuary")

func objective() -> String:
	var id := Catalog.next_task(director.snapshot().tasks)
	if id.is_empty(): return "The valley sings again. Visit the Jewel Sanctuary or return to the Castle railway."
	var index := Catalog.TASKS.find(id)
	return ["Harvest Echo Berries beside the entrance, then plant three seeds.",
		"Answer Leaf → Sun → Droplet. Confirm the phrase and clear both Blight waves.",
		"Enter River Song. Harvest Dew Pears, then tune the three organ valves.",
		"Harvest Sun Plums in Feeling Garden, then tune the five Hush Vine strings beside the river.",
		"Harvest Bell Apples by the dock. Answer the Call Bells to unlock Bell Grove.",
		"Restore three bridge chimes on OPEN beats to unlock the next gate.",
		"Harvest Moon Melons. Follow Leaf → Sun → Droplet during QUIET gaps.",
		"Enter Harmony Stage. Arrange drums → water → harp → chimes at the loom.",
		"Complete three beat anchors during the Conductor's RECOVERY.",
		"Bring all six story fruits to the orchestra, then conduct four OPEN beats."][index]

func area_title() -> String:
	var x: float = world.player_local_position().x
	if x < 104: return "Feeling Garden"
	if x < 225: return "River Song"
	if x < 345: return "Bell Grove"
	if x < 439: return "Harmony Stage"
	return "Jewel Sanctuary"

func revealed_fruit(index: int) -> bool:
	var count: int = director.snapshot().tasks.size()
	# A grove becomes useful when its first activity is available. Completed
	# and physically discovered groves remain in the journal on backtracking.
	var required := [0, 3, 2, 4, 6, 9]
	return count >= required[index] or world.player_local_position().distance_to(FRUIT_POS[index]) < 24

func interact(kind: String, index: int) -> void:
	match kind:
		"chapter_fruit": harvest(index)
		"chapter_instrument": open_instrument(index)
		"chapter_note":
			var task := index / 10
			if active_task != task:
				open_instrument(task)
			else: play(index % 10)
		"chapter_anchor": open_anchor(index)
		"chapter_checkpoint":
			director.checkpoint("stage" if index < 450 else "sanctuary")
			world.player.heal(100)
			focus = 100
			journal()
		"chapter_reflect": reflect(index)
		"chapter_gate": world._return_to_castle()
		"chapter_sanctuary":
			world._open("Harmony Jewel Sanctuary", "Every feeling belonged in the song. The Guardian thanks you for listening.\n" + ("Harmony Jewel and Harmony Shield earned. The completed-world railway remains available at the Castle entrance." if Catalog.TASKS[9] in director.snapshot().tasks else "The Jewel forms when the Conductor is free."))
			world._button("Return to the valley", world._close)

func harvest(index: int) -> void:
	var id: String = Fruit.IDS[index]
	var spec: Dictionary = Fruit.FRUITS[id]
	world._open(spec.label, spec.property + "\nShape: " + spec.shape + " · Leaf: " + spec.leaf + " · Icon: " + spec.icon + "\nStory fruit is protected. Extra fruit is for crafting.")
	world._flow(["Listen to the fruit", "Harvest story allotment", "Use at this activity"])
	world._button("Preview note and silhouette", func(): _feedback(spec.label + " · " + spec.icon, index))
	world._button("Harvest protected story allotment", func():
		if fruit_objects[index].interact("harvest_story"):
			fruit_nodes[index].scale = Vector3.ONE * 0.45
			world.message.text = spec.label + " is in the unlimited quest pouch."
		else: world.message.text = "Saving failed. Your harvest is still here; retry saving in Help."
	)
	world._button("Harvest crafting fruit", func():
		if clock < float(regrow.get(id, -1)):
			world.message.text = "New fruit grows in %d seconds. Story fruit never requires waiting." % ceili(float(regrow[id]) - clock)
		elif director.harvest_material(id, 3):
			regrow[id] = clock + 45
			fruit_nodes[index].scale = Vector3.ONE * 0.45
			world.message.text = "Three crafting fruits collected. Full stacks overflow to checkpoint storage."
	)
	world._button("Back to exploring", world._close)

func open_instrument(task: int) -> void:
	if task not in STATIONS: return
	var chapter := director.snapshot()
	if not Catalog.available(Catalog.TASKS[task], chapter.tasks):
		world._notice("First complete " + Catalog.TITLES[task - 1] + ". Your completed instruments stay restored.")
		return
	if Catalog.TASKS[task] not in chapter.tasks:
		for fruit_id in Catalog.FRUIT_COSTS[task]:
			if chapter.quest_pouch.get(fruit_id, 0) < Catalog.FRUIT_COSTS[task][fruit_id]:
				world._notice("Harvest " + Fruit.FRUITS[fruit_id].label + " from its labelled grove. Story fruit has no inventory limit.\nUse Valley map for the grove location.")
				return
	if active_task != task or active_anchor >= 0:
		active_task = task
		active_anchor = -1
		var partial: Array = chapter.challenges.get(Catalog.TASKS[task], {}).get("input", [])
		challenge.configure("pitch" if task in [2, 3] else ("timing" if task in [5, 9] else "sequence"), Catalog.PATTERNS[task], partial)
		challenge.failures = int(chapter.challenges.get(Catalog.TASKS[task], {}).get("failures", 0))
		challenge.assisted = assistance
	timing_label.position = STATIONS[task] + Vector3(0, 5.5, 0)
	timing_lens.position = STATIONS[task] + Vector3(0, 4, 0)
	_instrument_panel()

func _instrument_panel() -> void:
	var explanations := {2: "Turn three valves to match the carved chord. Pitch, water height and mist change together.",
		3: "Tune five living strings into an ascending pattern. The vine stays alive. Each string can be edited separately.",
		4: "The returning ripple calls North, South, East, West. Ring the four directional bell flowers in that order.",
		5: "Aim at arches 1, 2, 3. Strike when OPEN appears on the wind marker. Each success grows a bridge section.",
		6: "Follow quiet flowers: Leaf, Sun, Droplet. Wait for QUIET before moving or answering. Completed steps survive retry.",
		7: "Arrange the recovered motifs: drums, water, harp, chimes. Audition tracks before adding them to the score.",
		8: "The shell rests after each wave. Answer this anchor's short lesson.",
		9: "Place Echo, Sun, Dew, Bell, Moon, Harmony fruits. Then conduct North, East, South, West on four open beats."}
	world._open(Catalog.TITLES[active_task], explanations[active_task] + "\nScore: " + _score())
	instrument_panel_open = true
	var steps := ["Listen / watch", "Play the pattern", "Check composition"]
	if active_task in [2, 3]: steps = ["Read target numbers", "Tune each control", "Check composition"]
	if active_task in [5, 9]: steps = ["Watch for OPEN", "Play the next note", "Check composition"]
	if active_task == 6: steps = ["Wait for QUIET", "Leaf → Sun → Droplet", "Check composition"]
	world._flow(steps)
	if active_task not in [2, 3]:
		var keys := Label.new()
		keys.text = "Click a note or use 1–6 · Backspace: undo · Enter: select focused button · Esc: leave"
		keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		keys.add_theme_font_size_override("font_size", 20)
		world.options.add_child(keys)
	if active_task in [2, 3]:
		var count := 3 if active_task == 2 else 5
		for i in count:
			var row := HBoxContainer.new()
			row.set_meta("tuning_index", i)
			world.options.add_child(row)
			var label := Label.new()
			label.text = _tuning_text(i)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.add_theme_font_size_override("font_size", 22)
			row.add_child(label)
			for change in [-1, 1]:
				var button := Button.new()
				button.text = "Loosen −" if change == -1 else "Tighten +"
				button.custom_minimum_size = Vector2(120, 52)
				button.add_theme_font_size_override("font_size", 21)
				row.add_child(button)
				button.pressed.connect(func():
					var current := int(challenge.input[i]) if challenge.input.size() > i else 0
					challenge.tune(i, clampi(current + change, 0, 5))
					if active_task == 2:
						world.river.channels[i].visible = true
						world._pulse(world.river.channels[i])
					else: world._pulse(note_visuals[30 + i])
					_update_score()
				)
	else:
		var count := 6 if active_task == 9 else (4 if active_task in [4, 7] or active_anchor == 2 else 3)
		var row := HBoxContainer.new()
		world.options.add_child(row)
		for i in count:
			var button := Button.new()
			button.text = str(i + 1) + "\n" + (["Drums", "Water", "Harp", "Chimes"][i] if active_task == 7 else NOTE_NAMES[i].split(" / ")[0])
			button.custom_minimum_size = Vector2(104, 70)
			button.add_theme_font_size_override("font_size", 22)
			row.add_child(button)
			button.pressed.connect(func(): play(i))
		if active_task == 7:
			for i in 4: world._button("Audition " + ["drums", "water", "harp", "chimes"][i], func(): _feedback("Track " + str(i + 1), i))
	world._button("Check composition", submit)
	world._button("Replay demonstration", func(): challenge.replay(get_tree(), 0.5 if assistance else 1.0))
	world._button("Undo last change", func(): challenge.undo(); _update_score())
	world._button("Reset this attempt", func(): challenge.reset(); _store_attempt(); _update_score())
	world._button("Hint", func(): world.message.text = challenge.hint(); _store_attempt())
	world._button("Play by moving between the flower keys", world._close)

func _input(event: InputEvent) -> void:
	if active_task < 0 or not world.modal_open or not instrument_panel_open or not (event is InputEventKey) or not event.pressed or event.echo: return
	if world.embedded_in_overworld and not world.embedded_active: return
	var code: int = event.physical_keycode
	if code >= KEY_1 and code <= KEY_6 and active_task not in [2, 3]:
		var count := 6 if active_task == 9 else (4 if active_task in [4, 7] or active_anchor == 2 else 3)
		if code - KEY_1 < count: play(code - KEY_1)
	elif code == KEY_BACKSPACE: challenge.undo(); _store_attempt(); _update_score()
	else: return
	get_viewport().set_input_as_handled()

func play(note: int) -> void:
	if active_task < 0: return
	if active_task == 6 and not _quiet():
		_feedback("WARNING · wait outside the ripple. Your completed flowers remain.", -1)
		return
	if active_task == 5 or (active_task == 9 and challenge.input.size() >= 6):
		if not _beat_open():
			_feedback("Aim at the next shape; wait for OPEN", note)
			return
	if challenge.mode == "pitch":
		_feedback("Use the valve / string controls to change tension", note)
		return
	challenge.enter(note)
	if active_task == 5 and challenge.input == challenge.target.slice(0, challenge.input.size()):
		for i in challenge.input.size():
			world.river.decks[i].scale = Vector3.ONE
			world._pulse(note_visuals[500 + i])
	if active_task == 9 and challenge.input.size() <= 6:
		var shell_index := challenge.input.size() - 1
		if shell_index >= 0 and note == challenge.target[shell_index]: stage_shell.get_child(shell_index).visible = false
	if not world.modal_open and challenge.input.size() == challenge.target.size(): submit()
	_update_score()

func submit() -> void:
	if not challenge.submit():
		_store_attempt()
		_update_score()
		return
	var success := false
	if active_anchor >= 0:
		success = director.complete_anchor(ANCHOR_IDS[active_anchor], challenge.input)
		if success and director.snapshot().anchors.size() == 3:
			success = director.finish_instrument(8, Catalog.PATTERNS[8])
	else: success = director.finish_instrument(active_task, challenge.input)
	if not success:
		challenge.solved = false
		world._notice("This answer is ready, but saving failed. Retry saving in Help, then check it again.")
		return
	var finished := active_task
	var finished_anchor := active_anchor
	active_task = -1
	active_anchor = -1
	refresh()
	world.river.refresh()
	if finished_anchor >= 0 and director.snapshot().anchors.size() < 3:
		world._notice("Anchor saved: %d / 3 singing. Wait for RECOVERY, then answer the remaining anchors." % director.snapshot().anchors.size())
	else:
		var next_step := objective()
		if finished in [2, 3]:
			next_step = "River Song: %d / 3 activities restored. Bell Grove needs the organ, harp and Call Bells.\n" % (finished - 1) + next_step
		elif finished == 4:
			next_step = "Bell Grove unlocked! Approach the gate on the flowering bridge beside the Rain Boat.\n" + next_step
		world._notice("The valley answers. " + Catalog.TITLES[finished] + " restored.\n" + next_step)
	if finished == 9: _award_finale()

func open_anchor(index: int) -> void:
	if Catalog.TASKS[7] not in director.snapshot().tasks:
		world._notice("Assemble the Heart Song at the loom before joining the Conductor.")
		return
	if ANCHOR_IDS[index] in director.snapshot().anchors:
		world._notice("This anchor is already singing. Its progress survives every retry.")
		return
	if encounter.phase != "recovery":
		world._notice("The reed wave is approaching. Wait outside the amber circle; approach an anchor during RECOVERY.")
		return
	active_task = 8
	active_anchor = index
	challenge.configure("sequence", [[0, 2, 1], [0, 1, 2], [0, 2, 1, 3]][index])
	_instrument_panel()

func _award_finale() -> void:
	if Catalog.TASKS[9] not in director.snapshot().tasks: return
	var state: Node = world.get_node("/root/JourneyState")
	if not state.has_treasure("harmony_jewel"):
		state._award_treasure("harmony_jewel")
		state.save()
	world.player.blocking_enabled = true
	caption = "Conductor freed · Harmony Jewel formed · Harmony Shield equipped"

func refresh() -> void:
	var chapter := director.snapshot()
	for i in restoration.size(): restoration[i].visible = EnvironmentState.zone_state(i, chapter.tasks) in ["completed", "restored"]
	if is_instance_valid(jewel): jewel.visible = chapter.tasks.size() == 10
	if is_instance_valid(stage_shell): stage_shell.visible = chapter.tasks.size() < 10
	if is_instance_valid(stage_label) and chapter.tasks.size() == 10: stage_label.text = "The Living Amphitheatre\nEvery voice belongs"
	if chapter.tasks.size() == 10 and world.player != null: _award_finale()

func _store_attempt() -> void:
	if active_task < 0 or active_anchor >= 0: return
	director.save_challenge(Catalog.TASKS[active_task], challenge.input, challenge.failures, challenge.hint_level)

func _feedback(text: String, note: int) -> void:
	caption = text
	feedback_until = clock + 5.0
	if note >= 0:
		if not muted: world.note(note, 0.18)
		if note_visuals.has(active_task * 100 + note): world._pulse(note_visuals[active_task * 100 + note])
		for device in Input.get_connected_joypads(): Input.start_joy_vibration(device, 0.15, 0.2, 0.12 + note * 0.025)
	if world.modal_open and instrument_panel_open and is_instance_valid(world.message): world.message.text = text + "\nScore: " + _score()

func _score() -> String:
	return str(challenge.input.map(func(n): return int(n) + 1))

func _tuning_text(index: int) -> String:
	var current := int(challenge.input[index]) if index < challenge.input.size() else 0
	return "%s %d · now %d / goal %d" % ["Valve" if active_task == 2 else "String", index + 1, current + 1, int(challenge.target[index]) + 1]

func _update_score() -> void:
	if instrument_panel_open and active_task in [2, 3]:
		for row in world.options.get_children():
			if row.has_meta("tuning_index"): row.get_child(0).text = _tuning_text(int(row.get_meta("tuning_index")))
	if world.modal_open and instrument_panel_open and is_instance_valid(world.message): world.message.text = caption + "\nScore: " + _score() + ("\nAssistance is available in Valley map." if challenge.failures >= 2 else "")

func _beat_open() -> bool:
	return fposmod(challenge.elapsed, 2.0) < (0.85 if assistance else (0.6 if rosin else 0.4))

func _quiet() -> bool:
	return fposmod(clock, 5.0 if assistance else 3.5) > 1.5

func tick(delta: float) -> void:
	if world.embedded_in_overworld and not world.embedded_active: return
	clock += delta
	challenge.advance(delta)
	if focus_recovery > 0:
		focus = minf(100, focus + delta * 5)
		focus_recovery = maxf(0, focus_recovery - delta)
	for i in fruit_nodes.size():
		if clock >= float(regrow.get(Fruit.IDS[i], 0)): fruit_nodes[i].scale = Vector3.ONE
	var chapter := director.snapshot()
	encounter.active = Catalog.TASKS[7] in chapter.tasks and Catalog.TASKS[8] not in chapter.tasks and world.player_local_position().x > 375
	encounter.assistance = assistance
	encounter.advance(delta, world.modal_open)
	wave_marker.visible = encounter.active and encounter.phase != "recovery"
	if encounter.active:
		stage_label.text = "Conductor · " + encounter.phase.to_upper() + "\n" + str(chapter.anchors.size()) + " / 3 anchors singing"
		if encounter.phase == "wave" and not encounter.struck and world.player_local_position().distance_to(Vector3(399, 1, 8)) < 11.5:
			encounter.struck = true
			world.player.take_damage(8 if assistance else 16, self)
	if active_task in [5, 9]:
		timing_label.text = "OPEN · STRIKE" if _beat_open() else "WIND · WAIT"
		timing_lens.scale = Vector3.ONE * (1.3 if _beat_open() else 0.65)
	elif active_task == 6: timing_label.text = "QUIET · MOVE" if _quiet() else "WARNING · WAIT"
	else: timing_label.text = ""
	if world.modal_open and instrument_panel_open and active_task in [5, 6, 9] and is_instance_valid(world.message):
		world.message.text = timing_label.text + "\nScore: " + _score() + "\n" + caption
	presentation.update(chapter.tasks.size(), focus, caption if clock < feedback_until else "", world._large_text)

func journal() -> void:
	var chapter := director.snapshot()
	world._open("Your Melody journal · " + area_title(), objective())
	var count: int = mini(chapter.tasks.size(), 10)
	var now: String = Catalog.TITLES[count] if count < 10 else "Harmony Jewel"
	world._flow(["Explore this area", now, "Open the next gate"])
	world._button("Current task · replay Milo's guidance", func(): world.milo_guide.replay())
	if count > 0:
		world._button("Completed activities (%d)" % count, func():
			world._open("Your restored instruments", "\n".join(Catalog.TITLES.slice(0, count)))
			world._button("Back to current task", journal)
		)
	world._button("Open fruit bucket / eat fruit", fruit_bucket)
	world._button("Assistance: " + ("ON" if assistance else "OFF"), func():
		assistance = not assistance
		challenge.assisted = assistance
		var settings: Dictionary = director.snapshot().settings
		settings.assistance = assistance
		director.save_settings(settings)
		journal()
	)
	world._button("Instrument sound: " + ("MUTED" if muted else "ON"), func():
		muted = not muted
		var settings: Dictionary = director.snapshot().settings
		settings.muted = muted
		director.save_settings(settings)
		journal()
	)
	for i in 6:
		if not revealed_fruit(i): continue
		var id: String = Fruit.IDS[i]
		world._button(Fruit.FRUITS[id].label + " · " + GROVE_DIRECTIONS[i], func(): caption = "Find " + Fruit.FRUITS[id].label + " " + GROVE_DIRECTIONS[i]; world._close())
	for recipe_id in Fruit.RECIPES:
		if count < 2 or (recipe_id == "harmony_glaze" and count < 10): continue
		var recipe: Dictionary = Fruit.RECIPES[recipe_id]
		if not revealed_fruit(Fruit.IDS.find(recipe.fruit)): continue
		world._button("Craft " + recipe_id.replace("_", " ") + " · %d fruit" % recipe.cost, func():
			caption = "Crafted " + recipe_id if director.craft(recipe_id) else "Restored garden and enough crafting fruit are required. Quest fruit stays protected."
			journal()
		)
		if chapter.recipes.get(recipe_id, 0) > 0: world._button("Use " + recipe_id.replace("_", " "), func(): use_recipe(recipe_id))
	world._button("Collect checkpoint overflow", func():
		for id in Fruit.IDS: director.withdraw(id)
		journal()
	)
	world._button("Return to exploring", world._close)

func fruit_bucket() -> void:
	world._open("Fruit bucket", "Eat one fruit to recover 20 health and 20 focus.\nStory fruit and unlocked instrument voices stay protected.")
	var chapter := director.snapshot()
	for id in Fruit.IDS:
		if not revealed_fruit(Fruit.IDS.find(id)): continue
		var count := int(chapter.materials.get(id, 0))
		var button: Button = world._button("Eat %s (%d)" % [Fruit.FRUITS[id].label, count], func(): eat_fruit(id))
		button.disabled = count == 0
	world._button("Back to valley journal", journal)
	for id in world.musical_garden.Catalog.FRUIT_ORDER:
		var count := int(world.progress.committed.music.basket.get(id, 0))
		var button: Button = world._button("Eat %s (%d)" % [world.musical_garden.Catalog.fruit_name(id), count], func():
			if world.progress.eat_orchard_fruit(id):
				world.player.heal(20)
				focus = minf(100, focus + 20)
				world.musical_garden.harvested.erase(id)
				world.musical_garden.refresh()
				fruit_bucket()
				world.message.text = "Fruit eaten! Recovered 20 health and 20 focus. Harvest again in the orchard."
			else: world.message.text = "Fruit could not be saved. Nothing was eaten; retry saving in Help."
		)
		button.disabled = count == 0
	world._button("Return to exploring", world._close)

func eat_fruit(id: String) -> bool:
	if not director.consume_fruit(id):
		world.message.text = "No fruit available, or saving failed. Your fruit has not been consumed."
		return false
	world.player.heal(20)
	focus = minf(100, focus + 20)
	caption = "Ate " + str(Fruit.FRUITS[id].label) + " - recovered health and focus."
	fruit_bucket()
	world.message.text = caption
	return true

func use_recipe(id: String) -> void:
	if id == "echo_nectar" and active_task < 0: world.message.text = "Begin an instrument first."; return
	if id == "dew_pear_preserve" and not [359, 431, 459].any(func(x): return world.player_local_position().distance_to(Vector3(x, 1, 18)) < 7):
		world.message.text = "Use preserves beside a Peace Flower checkpoint."
		return
	if not director.consume_recipe(id): return
	match id:
		"echo_nectar": challenge.replay(get_tree(), 0.5 if assistance else 1.0)
		"sunfruit_tonic": focus_recovery = 12
		"dew_pear_preserve": world.player.heal(100)
		"bell_apple_rosin": rosin = true
		"moon_melon_tea": assistance = true; challenge.assisted = true
		"harmony_glaze": world.player.blocking_enabled = true; jewel.material_override = Art.material(Color("edd5a1"))
	caption = "Used " + id.replace("_", " ")
	world._close()

func reflect(index: int) -> void:
	var prompts := [["energy", "E", "I", "Share the song", "Listen quietly"], ["information", "S", "N", "Notice the notes", "Imagine the whole song"], ["decisions", "T", "F", "Tune a clear pattern", "Listen to a friend's part"], ["structure", "J", "P", "Arrange first", "Explore freely"]]
	var entry: Array = prompts[index]
	world._open("Optional reflection · HM_ID_%02d" % (index + 5), "A preference is saved only if you answer. Skip and Keep private save nothing. No rewards or access depend on this, and no identity result appears here.")
	for side in 2:
		world._button(entry[3 + side], func():
			world.get_node("/root/PlayerIdentityTracker").record_evidence("HM_ID_%02d" % (index + 5), entry[0], entry[1 + side], "heart_melody")
			world._close()
		)
	world._button("Skip", world._close)
	world._button("Keep private", world._close)
