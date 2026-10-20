extends Node3D

const Art = preload("res://scripts/heart_melody/heart_art.gd")
const Catalog = preload("res://scripts/heart_melody/musical_fruit_catalog.gd")

var world
var fruit_visuals: Dictionary = {}
var instrument_visuals: Dictionary = {"drums": [], "marimba": [], "harp": [], "bells": []}
var garden_blooms: Array[Node3D] = []
var garden_lights: Array[Node3D] = []
var basket: Node3D
var basket_fruit: Dictionary = {}
var harvested: Dictionary = {}
var recording := false
var rhythm_assist := true
var rhythm_speed := 0.8

func _ready() -> void:
	world = get_parent()
	_build_island_spaces()
	refresh()

func _build_island_spaces() -> void:
	name = "MusicalOrchardAndInstruments"
	# Moss ribbons connect the existing arrival/planter loop to each new clearing.
	for segment in [
		[Vector3(-54, 0.09, 12), Vector3(-66, 0.09, -8)],
		[Vector3(-66, 0.09, -8), Vector3(-48, 0.09, -28)],
		[Vector3(-48, 0.09, -28), Vector3(-21, 0.09, -31)],
		[Vector3(-21, 0.09, -31), Vector3(8, 0.09, -34)],
		[Vector3(8, 0.09, -34), Vector3(21, 0.09, -29)],
		[Vector3(21, 0.09, -29), Vector3(23, 0.09, -10)],
		[Vector3(23, 0.09, -10), Vector3(15, 0.09, 4)],
		[Vector3(15, 0.09, 4), Vector3(8, 0.09, 20)],
		[Vector3(8, 0.09, 20), Vector3(8, 0.09, 29)],
		[Vector3(8, 0.09, 29), Vector3(15, 0.09, 29)],
		[Vector3(8, 0.09, 20), Vector3(26, 0.09, 20)],
		[Vector3(26, 0.09, 20), Vector3(42, 0.09, 24)],
		[Vector3(15, 0.09, 4), Vector3(42, 0.09, 28)],
		[Vector3(42, 0.09, 28), Vector3(30, 0.09, 43)],
		[Vector3(30, 0.09, 43), Vector3(-12, 0.09, 26)],
	]:
		_path(segment[0], segment[1], 3.2, Color("6f9b74"))

	# Orchard: four strong canopy silhouettes and fruit at ordinary camera height.
	Art.banner(self, "MUSICAL ORCHARD\nListen before you harvest", Vector3(-54, 7, -16), 32)
	var positions := [Vector3(-70, 0, -13), Vector3(-58, 0, -28), Vector3(-40, 0, -33), Vector3(-27, 0, -26)]
	for i in Catalog.FRUIT_ORDER.size():
		_build_fruit_tree(Catalog.FRUIT_ORDER[i], positions[i], i)
	for i in 7:
		var bloom := Art.garden_flower(self, Vector3(-68 + i * 7, 0, -21 - (i % 2) * 8), i % 3, Color("efb5c7") if i % 2 == 0 else Color("f0cf79"))
		garden_blooms.append(bloom)

	# Shallow pool and a compact, non-blocking waterfall landmark.
	Art.cone(self, Vector3(-7, 0.07, -39), 7.5, 7.5, 0.08, Color("70b9bd"), false, 16)
	Art.box(self, Vector3(-7, 2.5, -45), Vector3(13, 5, 1.2), Color("789079"), true)
	for x in [-4.0, 0.0, 4.0]:
		Art.box(self, Vector3(-7 + x, 2.2, -44.25), Vector3(2.2, 4.2, 0.25), Color("9bd5d3"))

	_build_marimba(Vector3(-21, 0, -32))
	_build_harp(Vector3(8, 0, -34))
	_build_bells(Vector3(42, 0, 28))
	_build_ensemble(Vector3(30, 0, 43))
	_build_flower_activity(Vector3(15, 0, 29))
	_build_basket()
	# Small satellite beds outside playing positions, with an open path in front.
	for spec in [["marimba_pear", Vector3(-30, 0, -39)], ["shaker_berry", Vector3(23, 0, 33)], ["bell_apple", Vector3(51, 0, 24)], ["bass_melon", Vector3(19, 0, 43)]]:
		_build_fruit_tree(spec[0], spec[1], Catalog.FRUIT_ORDER.find(spec[0]), false)


func _path(a: Vector3, b: Vector3, width: float, colour: Color) -> void:
	var path := Art.box(self, (a + b) * 0.5, Vector3(width, 0.05, a.distance_to(b) + 0.6), colour)
	# Local basis, not look_at_from_position(): that sets a global transform, so
	# on the island embedded in the gallery world the paths landed by the gallery.
	path.basis = Basis.looking_at(b - a)

func _build_fruit_tree(fruit_id: String, pos: Vector3, variant: int, primary := true) -> void:
	var tree := Node3D.new()
	tree.name = ("FruitTree_" if primary else "FruitBed_") + fruit_id
	tree.position = pos
	add_child(tree)
	var fruit_height := 3.6
	if variant < 2:
		Art.cone(tree, Vector3(0, 3.4, -0.8), 0.65, 0.3, 6.8, Color("765c45"), true, 7)
		for offset in [Vector3(-1.7, 6.5, -0.8), Vector3(1.8, 7.0, -1.0)]:
			var canopy := Art.cone(tree, offset, 2.8, 0.7, 3.0, Color("6c9e73"), false, 7)
			Art.camera_obstacle(canopy)
		# A real branch joins the fruit stem to the crown.
		Art.box(tree, Vector3(0, 5.35, 0.5), Vector3(0.22, 0.22, 2.8), Color("765c45"))
	else:
		fruit_height = 0.9 if variant == 3 else 2.0
		if variant == 2:
			Art.cone(tree, Vector3(-0.8, 1.6, 1.8), 0.14, 0.08, 3.2, Color("53805b"), false, 5)
			Art.box(tree, Vector3(-0.4, 3.2, 1.8), Vector3(0.95, 0.13, 0.13), Color("53805b"))
		for side in [-1, 1]:
			Art.cone(tree, Vector3(side * 1.5, 0.7, -0.4), 1.0, 0.35, 1.4, Color("578664"), false, 7)
		Art.box(tree, Vector3(0, 0.18, 0.6), Vector3(3.8, 0.22, 0.28), Color("53805b"))
	var fruit := Node3D.new()
	fruit.name = "Harvestable_" + fruit_id
	fruit.position = Vector3(0, fruit_height, 1.8)
	tree.add_child(fruit)
	_build_fruit_shape(fruit, fruit_id, Vector3.ZERO, 1.0)
	# Stem/vine naturally attaches the primary fruit, without hiding its silhouette.
	Art.box(tree, Vector3(0, fruit_height + 1.25, 1.8), Vector3(0.12, 0.6, 0.12), Color("64764a"))
	if primary: fruit_visuals[fruit_id] = fruit
	else:
		fruit.scale = Vector3.ONE * 0.8
	world._object("music_fruit", variant, pos + Vector3(0, 1, 3.6), "Listen / harvest " + Catalog.fruit_name(fruit_id))
	for j in 5:
		var flower_pos := Vector3(-3.1 + j * 1.5, 0, -2.8 - (j % 2) * 0.6)
		garden_blooms.append(Art.garden_flower(tree, flower_pos, (j + variant) % 3, [Color("efb5c7"), Color("ebd085"), Color("b6aed6")][variant % 3]))

func _build_fruit_shape(parent: Node3D, fruit_id: String, pos: Vector3, scale_value := 1.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale_value
	parent.add_child(root)
	var colour: Color = Catalog.FRUITS[fruit_id].colour
	match fruit_id:
		"bell_apple":
			Art.fruit_body(root, Vector3.ZERO, [Vector2(0,-0.7), Vector2(0.55,-0.8), Vector2(0.95,-0.35), Vector2(1,0.3), Vector2(0.72,0.75), Vector2(0,0.55)], colour)
		"marimba_pear":
			Art.fruit_body(root, Vector3.ZERO, [Vector2(0,-0.8), Vector2(0.6,-0.8), Vector2(1,-0.3), Vector2(0.85,0.3), Vector2(0.4,0.85), Vector2(0.23,1.25), Vector2(0,1.3)], colour)
		"shaker_berry":
			for offset in [Vector3(-0.45,0.3,0), Vector3(0.45,0.3,0), Vector3(0,0.3,-0.55), Vector3(0,0.3,0.55), Vector3(-0.25,-0.35,0.2), Vector3(0.3,-0.35,-0.15), Vector3(0,-0.85,0)]:
				Art.fruit_body(root, offset, [Vector2(0,-0.45),Vector2(0.4,-0.2),Vector2(0.46,0.16),Vector2(0.28,0.4),Vector2(0,0.46)], colour)
		"bass_melon":
			Art.fruit_body(root, Vector3.ZERO, [Vector2(0,-0.9),Vector2(0.7,-0.78),Vector2(1.2,-0.35),Vector2(1.3,0.2),Vector2(0.95,0.75),Vector2(0,0.95)], colour, true)
	var stem_height := 1.3 if fruit_id == "marimba_pear" else 0.95
	Art.box(root, Vector3(0, stem_height, 0), Vector3(0.13, 0.65, 0.13), Color("6e4d37"))
	var leaf := Art.cone(root, Vector3(0.4, stem_height + 0.2, 0), 0.6, 0.05, 0.13, Color("4d855d"), false, 4)
	leaf.scale.z = 0.5
	leaf.rotation.z = 0.2
	Art.merge_coloured(root)

func _build_basket() -> void:
	basket = Node3D.new()
	basket.name = "MusicalBasket"
	add_child(basket)
	# Carried beside the player; four visible slots use persistent discoveries.
	Art.cone(basket, Vector3.ZERO, 0.35, 0.52, 0.5, Color("aa8052"), false, 8)
	for side in [-1, 1]: Art.box(basket, Vector3(side * 0.44, 0.4, 0), Vector3(0.07, 0.65, 0.07), Color("795a3a"))
	Art.box(basket, Vector3(0, 0.7, 0), Vector3(0.95, 0.07, 0.07), Color("795a3a"))
	for i in Catalog.FRUIT_ORDER.size():
		var fruit := Node3D.new()
		basket.add_child(fruit)
		fruit.position = Vector3(-0.23 + (i % 2) * 0.46, 0.3, -0.2 + (i / 2) * 0.4)
		_build_fruit_shape(fruit, Catalog.FRUIT_ORDER[i], Vector3.ZERO, 0.2)
		basket_fruit[Catalog.FRUIT_ORDER[i]] = fruit

func _process(_delta: float) -> void:
	if basket != null and world.player != null:
		basket.global_position = world.player.global_position + Vector3(0.9, 0.1, 0)
		basket.visible = not world.embedded_in_overworld or world.embedded_active

func _harvest_visual(fruit_id: String) -> void:
	var source: Node3D = fruit_visuals[fruit_id]
	if harvested.has(fruit_id): return
	harvested[fruit_id] = true
	source.hide()
	if world.reduced_motion:
		basket_fruit[fruit_id].show()
		return
	var flying := Node3D.new()
	add_child(flying)
	flying.global_position = source.global_position
	_build_fruit_shape(flying, fruit_id, Vector3.ZERO)
	basket_fruit[fruit_id].hide()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(flying, "global_position", basket.global_position + Vector3.UP * 0.35, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(flying, "scale", Vector3.ONE * 0.2, 0.8)
	tween.chain().tween_callback(func(): flying.queue_free(); basket_fruit[fruit_id].show())
	_respond_flowers(source.global_position)

func _respond_flowers(at: Vector3) -> void:
	for bloom in garden_blooms:
		if bloom.global_position.distance_to(at) > 18: continue
		# Stop/restart from a fixed rest pose to avoid cumulative scale drift.
		if bloom.has_meta("response_tween"):
			var previous: Tween = bloom.get_meta("response_tween")
			if previous.is_valid(): previous.kill()
		if world.reduced_motion: continue
		var tween := create_tween()
		bloom.set_meta("response_tween", tween)
		tween.tween_property(bloom, "rotation:z", 0.12, 0.4)
		tween.tween_property(bloom, "rotation:z", 0.0, 0.8)

func _build_marimba(pos: Vector3) -> void:
	var root := Node3D.new(); root.name = "FruitMarimba"; root.position = pos; add_child(root)
	Art.banner(root, "FRUIT MARIMBA\nFive notes, many voices", Vector3(0, 7, 0), 30)
	for x in [-6.2, 6.2]: Art.cone(root, Vector3(x, 1.2, 0), 0.65, 0.9, 2.4, Color("73563e"), true, 7)
	for i in 5:
		var bar := Art.box(root, Vector3(-4.4 + i * 2.2, 2.2, 0), Vector3(1.75, 0.45, 5.0 - i * 0.35), Color("c18a55") if i % 2 == 0 else Color("a66f49"), true)
		instrument_visuals.marimba.append(bar)
		world._object("music_marimba", i, pos + Vector3(-4.4 + i * 2.2, 1, 3.1), "Play marimba note %d" % (i + 1))
	world._object("music_marimba_panel", -1, pos + Vector3(0, 1, -3.5), "Fruit Marimba controls")

func _build_harp(pos: Vector3) -> void:
	var root := Node3D.new(); root.name = "VineHarp"; root.position = pos; add_child(root)
	Art.banner(root, "VINE HARP\nRest · play · record", Vector3(0, 8, 0), 30)
	for x in [-5.0, 5.0]:
		var branch := Art.cone(root, Vector3(x, 3.5, 0), 0.8, 0.45, 7, Color("725940"), true, 7)
		branch.rotation.z = -0.18 * signf(x)
	Art.box(root, Vector3(0, 7, 0), Vector3(10, 0.7, 0.7), Color("725940"), true)
	for i in 5:
		var string := Art.box(root, Vector3(-3.6 + i * 1.8, 4.2, 0), Vector3(0.09, 5.0, 0.09), Color("e7cf96"))
		instrument_visuals.harp.append(string)
		world._object("music_harp", i, pos + Vector3(-3.6 + i * 1.8, 1, 1.8), "Pluck harp string %d" % (i + 1))
	world._object("music_harp_panel", -1, pos + Vector3(0, 1, -2.5), "Vine Harp controls")

func _build_bells(pos: Vector3) -> void:
	var root := Node3D.new(); root.name = "HangingBellGarden"; root.position = pos; add_child(root)
	Art.banner(root, "HANGING BELL GARDEN\nFind the missing note", Vector3(0, 9, 0), 30)
	for x in [-6.0, 6.0]: Art.cone(root, Vector3(x, 3.5, 0), 0.8, 0.55, 7, Color("725940"), true, 7)
	Art.box(root, Vector3(0, 7, 0), Vector3(13, 0.8, 0.8), Color("725940"), true)
	for i in 5:
		var bell := Node3D.new(); bell.position = Vector3(-4.8 + i * 2.4, 4.8 + (i % 2) * 0.5, 0); root.add_child(bell)
		Art.box(bell, Vector3(0, 1.2, 0), Vector3(0.09, 2.4, 0.09), Color("d5c493"))
		Art.cone(bell, Vector3(0, 0, 0), 0.8 + i * 0.06, 0.35, 1.5, Color("e2b866"), false, 8)
		instrument_visuals.bells.append(bell)
		world._object("music_bell", i, pos + Vector3(-4.8 + i * 2.4, 1, 2.0), "Ring bell %d" % (i + 1))
	world._object("music_bell_panel", -1, pos + Vector3(0, 1, -3.0), "Bell Grove activity")

func _build_ensemble(pos: Vector3) -> void:
	var root := Node3D.new(); root.name = "GardenEnsembleStage"; root.position = pos; add_child(root)
	Art.cone(root, Vector3(0, 0.35, 0), 11, 9, 0.7, Color("b99674"), true, 16)
	for i in 8:
		var angle := TAU * i / 8.0
		var light := Art.cone(root, Vector3(cos(angle) * 8, 1.3, sin(angle) * 8), 0.55, 0.35, 2.4, Color("e7c56f"), false, 7)
		garden_lights.append(light)
	Art.banner(root, "GARDEN ENSEMBLE\nLayer the valley's song", Vector3(0, 8, 0), 32)
	world._object("music_ensemble", -1, pos + Vector3(0, 1, 7), "Open the Garden Ensemble")

func _build_flower_activity(pos: Vector3) -> void:
	Art.banner(self, "FLOWER DRUM CLEARING\nAnswer the garden's rhythm", pos + Vector3(0, 7, 0), 30)
	for i in 4:
		var angle := TAU * i / 4.0
		var drum_pos := pos + Vector3(cos(angle) * 5.0, 0, sin(angle) * 5.0)
		Art.cone(self, drum_pos + Vector3(0, 0.45, 0), 1.7, 1.4, 0.9, Color("6f8066"), true, 8)
		var drum := Art.flower(self, drum_pos + Vector3(0, 0.8, 0), [Color("ef8f9f"), Color("8fcad0"), Color("f2ca6f"), Color("b89bd7")][i], 2.1)
		instrument_visuals.drums.append(drum)
		world._object("music_drum", i, drum_pos + Vector3(0, 1, 2.8), "Play %s flower drum" % ["Leaf", "Droplet", "Sun", "Moon"][i])
	world._object("music_flowers", -1, pos + Vector3(0, 1, 5), "Flower Drum play mode")

func interact(kind: String, index: int) -> void:
	match kind:
		"music_fruit": _fruit_panel(Catalog.FRUIT_ORDER[index])
		"music_drum": play_note("drums", index)
		"music_marimba": play_note("marimba", index)
		"music_harp": play_note("harp", index)
		"music_bell": play_note("bells", index)
		"music_marimba_panel": _instrument_panel("marimba")
		"music_harp_panel": _instrument_panel("harp")
		"music_bell_panel": _bell_activity()
		"music_flowers": _flower_activity()
		"music_ensemble": _ensemble_panel()

func _fruit_panel(fruit_id: String) -> void:
	var info: Dictionary = Catalog.FRUITS[fruit_id]
	world._open(str(info.name), "%s\n%s\n\nListen first, then harvest. Eat collected fruit from the fruit bucket in the valley journal. Its unlocked instrument voice stays available after eating." % [info.symbol, info.role])
	world._button("Preview sound", func():
		world.note(Catalog.FRUIT_ORDER.find(fruit_id), 0.18, int(info.timbre)); _pulse(fruit_visuals[fruit_id])
		world.message.text = "%s sounds like %s. Pitch will come from an instrument slot." % [info.name, info.role]
	)
	world._button("Harvest into musical basket", func():
		var first: bool = not world.progress.data.music.discovered.has(fruit_id)
		if world.progress.discover_fruit(fruit_id):
			world.note(Catalog.FRUIT_ORDER.find(fruit_id), 0.20, int(info.timbre)); refresh(); _harvest_visual(fruit_id)
			world.message.text = "%s added to the basket%s. Open the valley journal to eat it." % [info.name, " for the first time" if first else " again"]
			_check_orchard_activity()
			world._close()
		else: world.message.text = "The fruit is safe in this session. Saving is pending; retry from Help."
	)
	world._button("Back to orchard", world._close)

func _check_orchard_activity() -> void:
	if world.progress.data.music.discovered.size() == 4 and not world.progress.data.music.completed.has(Catalog.ACTIVITY_ORCHARD):
		if world.progress.complete_music_activity(Catalog.ACTIVITY_ORCHARD):
			world.message.text += "\n\nActivity complete: the orchard's four voices awaken nearby flowers."

func play_note(instrument: String, note_index: int, record_event := true) -> void:
	var placements: Array = world.progress.data.music.placements[instrument]
	var slot := mini(note_index, placements.size() - 1)
	var fruit_id := str(placements[slot]) if slot >= 0 else ""
	var timbre := Catalog.timbre(fruit_id) if not fruit_id.is_empty() else 0
	world.note(note_index, 0.20, timbre)
	var visuals: Array = instrument_visuals[instrument]
	if note_index < visuals.size():
		_pulse(visuals[note_index])
		_respond_flowers(visuals[note_index].global_position)
	if recording and record_event:
		var events: Array = world.progress.data.music.phrases.recording.duplicate(true)
		if events.size() < Catalog.MAX_RECORDED_EVENTS:
			events.append({"instrument": instrument, "note": note_index, "beat": events.size()})
			world.progress.set_recording(events)

func on_flower_play(note_index: int) -> void:
	if recording:
		var events: Array = world.progress.data.music.phrases.recording.duplicate(true)
		if events.size() < Catalog.MAX_RECORDED_EVENTS:
			events.append({"instrument": "drums", "note": note_index, "beat": events.size()})
			world.progress.set_recording(events)

func _instrument_panel(instrument: String) -> void:
	world._open(Catalog.instrument_name(instrument), "Free play is always available. Note position sets pitch; fruit changes only the tone. Use Tab / arrows and Enter, controller focus, or touch.")
	var note_count: int = int(Catalog.INSTRUMENTS[instrument].notes)
	for note_index in note_count:
		world._button("Play note %d  %s" % [note_index + 1, _slot_description(instrument, note_index)], func(): play_note(instrument, note_index))
	world._button("Configure fruit holders", func(): _placement_panel(instrument))
	world._button("Hear guided phrase", func(): _play_phrase(instrument, Catalog.HARP_PHRASE if instrument == "harp" else Catalog.MARIMBA_PHRASE))
	if instrument == "marimba": world._button("Build the guided melody", _marimba_activity)
	else: world._button("Try the Vine Harp phrase", _harp_activity)
	_add_recorder_buttons(instrument)
	world._button("Exit instrument", world._close)

func _slot_description(instrument: String, slot: int) -> String:
	var placements: Array = world.progress.data.music.placements[instrument]
	if slot >= placements.size() or str(placements[slot]).is_empty(): return "(neutral tone)"
	return "(" + Catalog.fruit_name(str(placements[slot])) + ")"

func _placement_panel(instrument: String) -> void:
	world._open(Catalog.instrument_name(instrument) + " fruit holders", "Choose a holder, then place, swap, or retrieve fruit. The basket keeps every discovered fruit, so experimenting cannot lose progress.")
	var slots: int = int(Catalog.INSTRUMENTS[instrument].slots)
	for slot in slots:
		world._button("Holder %d %s" % [slot + 1, _slot_description(instrument, slot)], func(): _slot_panel(instrument, slot))
	world._button("Back to instrument", func(): _instrument_panel(instrument))

func _slot_panel(instrument: String, slot: int) -> void:
	world._open("%s holder %d" % [Catalog.instrument_name(instrument), slot + 1], "Fruit changes timbre, never the note or whether a solution succeeds.")
	for fruit_id in world.progress.data.music.discovered:
		world._button("Place " + Catalog.fruit_name(fruit_id) + " / " + Catalog.fruit_symbol(fruit_id), func():
			world.progress.configure_instrument(instrument, slot, fruit_id)
			play_note(instrument, slot, false)
			_slot_panel(instrument, slot)
		)
	world._button("Retrieve fruit / neutral tone", func(): world.progress.configure_instrument(instrument, slot, ""); _slot_panel(instrument, slot))
	world._button("Back to holders", func(): _placement_panel(instrument))

func _flower_activity() -> void:
	world._open("Answer the Flowers", "The flowers call LEAF - SUN - DROPLET. Sound and symbols show the same clue. Enter or revise the response; there is no timer.")
	world._button("Hear and see the call", func(): _play_phrase("drums", Catalog.FLOWER_PHRASE))
	world._button("Configure fruit / Shaker Berry holders", func(): _placement_panel("drums"))
	for note_index in 3:
		world._button("Add " + ["LEAF", "DROPLET", "SUN"][note_index], func():
			var notes: Array = world.progress.data.music.phrases.flowers.duplicate()
			if notes.size() < 3: notes.append(note_index); world.progress.set_music_phrase("flowers", notes)
			play_note("drums", note_index, false); world.message.text = _phrase_text("flowers", ["LEAF", "DROPLET", "SUN"])
		)
	world._button("Undo response", func(): _undo_phrase("flowers"))
	world._button("Reset response", func(): world.progress.set_music_phrase("flowers", []); world.message.text = _phrase_text("flowers", ["LEAF", "DROPLET", "SUN"]))
	world._button("Answer the flowers", func():
		if world.progress.data.music.phrases.flowers == Catalog.FLOWER_PHRASE and world.progress.complete_music_activity(Catalog.ACTIVITY_FLOWERS):
			world.message.text = "The flowers answer in harmony. Activity complete; your exact progress is saved."
		else: world.message.text = "The matching beginning is kept. Listen again, undo, or revise without penalty."
	)
	world._button("Optional rhythm mode: %s" % ("assisted" if rhythm_assist else "standard"), func(): rhythm_assist = not rhythm_assist; rhythm_speed = 1.1 if rhythm_assist else 0.7; _flower_activity())
	world._button("Exit flower play", world._close)

func _drum_timbre(slot: int) -> int:
	var fruit := str(world.progress.data.music.placements.drums[slot])
	return Catalog.timbre(fruit) if not fruit.is_empty() else 6

func _marimba_activity() -> void:
	world._open("Build a Fruit Melody", "Example: low - middle - high, shown as 1 - 3 - 5. Any fruit combination succeeds because the bars determine pitch.")
	world._button("Hear example 1 - 3 - 5", func(): _play_phrase("marimba", Catalog.MARIMBA_PHRASE))
	for note_index in 5:
		world._button("Add bar %d" % (note_index + 1), func():
			var notes: Array = world.progress.data.music.phrases.marimba.duplicate()
			if notes.size() < 3: notes.append(note_index); world.progress.set_music_phrase("marimba", notes)
			play_note("marimba", note_index, false); world.message.text = _phrase_text("marimba", ["1", "2", "3", "4", "5"])
		)
	world._button("Preview my melody", func(): _play_phrase("marimba", world.progress.data.music.phrases.marimba))
	world._button("Undo last bar", func(): _undo_phrase("marimba"))
	world._button("Reset melody", func(): world.progress.set_music_phrase("marimba", []); _marimba_activity())
	world._button("Confirm guided melody", func():
		if world.progress.data.music.phrases.marimba == Catalog.MARIMBA_PHRASE and world.progress.complete_music_activity(Catalog.ACTIVITY_MARIMBA): world.message.text = "Melody complete. Fruit changed its character without changing the answer."
		else: world.message.text = "Your notes are kept. Compare them with 1 - 3 - 5 and revise."
	)
	world._button("Creative arrangement / free play", func(): _instrument_panel("marimba"))
	world._button("Exit", world._close)

func _harp_activity() -> void:
	world._open("Vine Harp guided phrase", "Pluck 1 - 3 - 5 slowly. This is a replayable harmony exercise and does not gate essential progress.")
	world._button("Demonstrate 1 - 3 - 5", func(): _play_phrase("harp", Catalog.HARP_PHRASE))
	for note_index in 5: world._button("Pluck %d" % (note_index + 1), func(): play_note("harp", note_index))
	world._button("Back", func(): _instrument_panel("harp"))

func _bell_activity() -> void:
	world._open("Wake the Bell Grove", "The authored phrase is 1 - 2 - ? - 4 - 5. The empty diamond marks the missing position. Try a bell, hear the result, and revise.")
	world._button("Hear visible phrase with a quiet gap", func(): _play_phrase("bells", Catalog.BELL_VISIBLE_PHRASE))
	for note_index in 5:
		world._button("Try bell %d%s" % [note_index + 1, " / TRIANGLE" if note_index == 2 else ""], func():
			play_note("bells", note_index, false); world.progress.set_music_phrase("bells", [note_index])
			if note_index == Catalog.BELL_MISSING_NOTE: world.message.text = "The complete phrase rises 1 - 2 - 3 - 4 - 5. Confirm when ready."
			else: world.message.text = "That bell can be revised. The gap sits between 2 and 4; symbols remain visible."
		)
	world._button("Confirm missing note", func():
		if world.progress.data.music.phrases.bells == [Catalog.BELL_MISSING_NOTE] and world.progress.complete_music_activity(Catalog.ACTIVITY_BELLS):
			world.message.text = "Bell Grove awake. The Garden Ensemble is ready."
		else: world.message.text = "Try a bell first. Nothing is lost."
	)
	world._button("Replay instructions", _bell_activity)
	world._button("Exit bells", world._close)

func _ensemble_panel() -> void:
	var ready: bool = world.progress.data.music.completed.has(Catalog.ACTIVITY_BELLS)
	world._open("The Garden Ensemble", ("Combine rhythm, melody, harmony and accents. Fruit choices colour the timbre." if ready else "The ensemble is resting. Complete Orchard Voices, Answer the Flowers, Fruit Melody and Bell Grove first."))
	if ready:
		for layer in ["drums", "marimba", "harp", "bells"]:
			world._button("%s layer: %s" % [Catalog.instrument_name(layer), "ON" if world.progress.data.music.ensemble[layer] else "OFF"], func(): world.progress.set_ensemble_layer(layer, not world.progress.data.music.ensemble[layer]); _ensemble_panel())
		world._button("Preview ensemble", func(): _play_ensemble(false))
		world._button("Perform and awaken the island", func(): _play_ensemble(true))
		world._button("Play saved arrangement", func(): _play_recording(world.progress.data.music.saved_arrangement))
		world._button("Replace saved arrangement with recording", func(): world.progress.set_recording(world.progress.data.music.phrases.recording, true); world.message.text = "Current symbolic phrase saved.")
		world._button("Clear saved arrangement", func(): world.progress.set_recording([], true); world.message.text = "Saved phrase cleared. Guided progress remains safe.")
	world._button("Exit ensemble", world._close)

func _play_ensemble(complete: bool) -> void:
	var sequences := {"drums": Catalog.FLOWER_PHRASE, "marimba": Catalog.MARIMBA_PHRASE, "harp": Catalog.HARP_PHRASE, "bells": [2, 4]}
	for beat in 3:
		for layer in ["drums", "marimba", "harp", "bells"]:
			if world.progress.data.music.ensemble[layer] and beat < sequences[layer].size():
				if layer == "drums": world.note(sequences[layer][beat], 0.10, _drum_timbre(sequences[layer][beat]))
				else: play_note(layer, sequences[layer][beat], false)
		await world.get_tree().create_timer(1.0 if rhythm_assist else rhythm_speed).timeout
	if complete and world.progress.complete_music_activity(Catalog.ACTIVITY_ENSEMBLE):
		refresh()
		world.message.text = "The island's celebration is awake. Flowers, fruit, water lights and your chosen layers now respond. No campaign treasure or future world was awarded."

func _add_recorder_buttons(instrument: String) -> void:
	world._button("Recorder: %s" % ("ON - play notes now" if recording else "off"), func(): recording = not recording; _instrument_panel(instrument))
	world._button("Playback current phrase", func(): _play_recording(world.progress.data.music.phrases.recording))
	world._button("Clear current phrase", func(): world.progress.set_recording([]); world.message.text = "Current phrase cleared. Saved arrangement is unchanged.")
	world._button("Save current phrase", func(): world.progress.set_recording(world.progress.data.music.phrases.recording, true); world.message.text = "Symbolic events saved for reopening later.")

func _play_recording(events: Array) -> void:
	for event in events:
		var instrument := str(event.instrument)
		if instrument == "drums": world.note(int(event.note), 0.16, _drum_timbre(mini(int(event.note), 3)))
		else: play_note(instrument, int(event.note), false)
		await world.get_tree().create_timer(rhythm_speed).timeout

func _play_phrase(instrument: String, notes: Array) -> void:
	for raw in notes:
		var note_index := int(raw)
		if note_index < 0:
			await world.get_tree().create_timer(rhythm_speed).timeout
			continue
		if instrument == "drums": world.note(note_index, 0.18, _drum_timbre(mini(note_index, 3)))
		else: play_note(instrument, note_index, false)
		if world.message: world.message.text = "Now playing symbol / position %d" % (note_index + 1)
		await world.get_tree().create_timer(rhythm_speed if not world.puzzle_assist else 1.25).timeout

func _phrase_text(kind: String, names: Array) -> String:
	var result: PackedStringArray = []
	for note_index in world.progress.data.music.phrases[kind]: result.append(str(names[int(note_index)]))
	return "Your phrase: " + (" - ".join(result) if not result.is_empty() else "empty")

func _undo_phrase(kind: String) -> void:
	var notes: Array = world.progress.data.music.phrases[kind].duplicate()
	if not notes.is_empty(): notes.pop_back()
	world.progress.set_music_phrase(kind, notes)
	world.message.text = "Last note removed. The rest of your response is kept."

func basket_summary() -> String:
	var symbols: PackedStringArray = []
	for fruit_id in Catalog.FRUIT_ORDER:
		if world.progress.data.music.basket.get(fruit_id, 0) > 0: symbols.append(Catalog.fruit_symbol(fruit_id).get_slice(" / ", 0))
	return "Basket " + (" + ".join(symbols) if not symbols.is_empty() else "empty")

func objective() -> String:
	var done: Array = world.progress.data.music.completed
	if not done.has(Catalog.ACTIVITY_ORCHARD): return "Explore the Musical Orchard; preview and harvest four fruit voices."
	if not done.has(Catalog.ACTIVITY_FLOWERS): return "Answer the Flowers at the drum clearing (LEAF - SUN - DROPLET)."
	if not done.has(Catalog.ACTIVITY_MARIMBA): return "Build the Fruit Marimba melody (bars 1 - 3 - 5)."
	if not done.has(Catalog.ACTIVITY_BELLS): return "Wake the Bell Grove by finding the visible missing note."
	if not done.has(Catalog.ACTIVITY_ENSEMBLE): return "Choose layers and perform at the Garden Ensemble stage."
	return "The island's song is awake. Replay, swap fruit, record, or visit River Song."

func progress_text() -> String:
	return "Music %d/5" % world.progress.data.music.completed.size()

func refresh() -> void:
	var level: int = world.progress.data.music.completed.size()
	for i in garden_blooms.size():
		garden_blooms[i].scale = Vector3.ONE
	for light in garden_lights:
		light.visible = level >= 4
	for fruit_id in fruit_visuals:
		var collected: bool = world.progress.data.music.basket.get(fruit_id, 0) > 0
		fruit_visuals[fruit_id].visible = not collected
		basket_fruit[fruit_id].visible = collected

func _pulse(node: Node3D) -> void:
	world._pulse(node)
