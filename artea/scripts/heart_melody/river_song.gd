extends Node3D

const Art = preload("res://scripts/heart_melody/heart_art.gd")
const Enemy = preload("res://scripts/heart_melody/heart_enemy.gd")
const NOTES := [2, 0, 1]
const SYMBOLS := ["Leaf", "Droplet", "Sun"]
const GROVE := Vector3(322, 1, 8)
var world: Node3D
var channels: Array[Node3D] = []
var bulbs: Array[Node3D] = []
var decks: Array[Node3D] = []
var boat: Node3D
var flower: Node3D
var warning_barrier: Node3D
var riding := false
var _ride_time := 0.0
var _departure := Vector3.ZERO
var _destination := Vector3.ZERO
var _far_dock := false
var _fighting := false

func _ready() -> void:
	world = get_parent()
	_land(Vector3(146, 0, 8), Vector3(76, 2, 58))
	_land(Vector3(244, 0, 8), Vector3(48, 2, 44))
	_land(Vector3(327, 0, 8), Vector3(54, 2, 58))
	Art.box(self, Vector3(106, -0.1, 8), Vector3(28, 0.2, 6), Color("bdac90"), true)
	for z in [4.7, 11.3]: Art.box(self, Vector3(106, 0.85, z), Vector3(26, 1.6, 0.4), Color("816e5a"), true)
	Art.label(self, "FEELING GARDEN\nReturn across this bridge", Vector3(115, 5, 12), 28)
	Art.label(self, "RIVER SONG · WATERFALL ORGAN", Vector3(146, 15, -12), 40)
	Art.box(self, Vector3(146, 0.06, -9), Vector3(58, 0.1, 19), Color("74b9c4"))
	for index in 3:
		var x := 126.0 + index * 17.0
		Art.cone(self, Vector3(x, 6 + index, -15), 2, 1.7, 12 + index * 2, Color("789d83"), true)
		Art.flower(self, Vector3(x, 3, 0), Color("e9c891"), 1.6)
		Art.symbol(self, Vector3(x, 3, 1), NOTES[index])
		Art.label(self, "Valve %d · %s" % [index + 1, SYMBOLS[NOTES[index]]], Vector3(x, 5, 0), 27)
		world._object("river_valve", index, Vector3(x, 1, 3), "Tune organ valve %d" % (index + 1))
		channels.append(Art.box(self, Vector3(x, 5 + index, -12.8), Vector3(1.8, 10 + index * 2, 0.2), Color("86d4df")))
		var pos := Vector3(140 + index * 12, 1, 23)
		bulbs.append(Art.flower(self, pos, Color("755b82"), 1.9))
		world._object("river_bulb", index, pos + Vector3(0, 0, -3), "Release Hush Vine bulb %d" % (index + 1))
		Art.label(self, "Hush Vine %d" % (index + 1), pos + Vector3.UP * 4, 25)
	for pos in [Vector3(116,0,-17), Vector3(174,0,-17), Vector3(234,0,-10), Vector3(342,0,-13)]: Art.tree(self, pos, 1)
	Art.box(self, Vector3(202, -3, 8), Vector3(36, 0.2, 44), Color("66aeba"))
	# A permanent flowering root walk joins both river banks. The Rain Boat stays
	# as a playful musical activity and shortcut, not the only route between land.
	Art.box(self, Vector3(202, 0.0, -8), Vector3(40, 0.35, 5.5), Color("b89d72"), true)
	for z in [-11.0, -5.0]:
		Art.box(self, Vector3(202, 1.0, z), Vector3(40, 1.4, 0.45), Color("75684f"), true)
	for x in [187.0, 195.0, 203.0, 211.0, 219.0]:
		Art.flower(self, Vector3(x, 0.1, -4.4), Color("e6b4c8") if int(x) % 2 else Color("eed17f"), 0.65)
	Art.label(self, "FLOWERING ROOT WALK\nAll gardens connected", Vector3(202, 5.2, -8), 25)
	for x in [179, 225]:
		Art.cone(self, Vector3(x, 2.5, 16), 0.45, 0.4, 5, Color("816e5a"), true)
		Art.cone(self, Vector3(x, 4, 16), 1.1, 0.5, 1.4, Color("edcc7f"))
	world._object("river_boat", 0, Vector3(179, 1, 12), "Call / board Rain Boat")
	world._object("river_boat", 1, Vector3(225, 1, 12), "Return by Rain Boat")
	Art.label(self, "RAIN BOAT · ring the dock bell", Vector3(181, 7, 15), 26)
	boat = Node3D.new()
	boat.name = "RainBoat"
	add_child(boat)
	boat.position = Vector3(183, 0.1, 8)
	Art.box(boat, Vector3.ZERO, Vector3(8, 0.4, 6), Color("96764f"), true)
	for z in [-2.8, 2.8]: Art.box(boat, Vector3(0, 0.7, z), Vector3(8, 1, 0.3), Color("799d72"), true)
	for x in [-3, 3]: Art.cone(boat, Vector3(x, 2, 2.3), 0.2, 0.2, 4, Color("816e5a"))
	Art.cone(boat, Vector3(0, 4, 0), 4.6, 1, 0.7, Color("8db884"), false, 8)
	Art.label(self, "BELL GROVE", Vector3(248, 8, -5), 38)
	for index in 3:
		var x := 262.0 + index * 12.0
		world._object("river_chime", index, Vector3(x, 1, 8), "Restore bridge chime %d" % (index + 1))
		Art.cone(self, Vector3(x, 2.5, 12), 0.35, 0.25, 5, Color("816e5a"))
		Art.cone(self, Vector3(x, 4, 12), 1, 0.5, 1.5, Color("edcc7f"))
		var deck := Node3D.new()
		deck.name = "ChimeBridge%d" % (index + 1)
		add_child(deck)
		decks.append(deck)
		Art.box(deck, Vector3(x + 8, -0.1, 8), Vector3(12, 0.2, 8), Color("bdac90"), true)
		for z in [3.8, 12.2]: Art.box(deck, Vector3(x + 8, 0.8, z), Vector3(12, 1.5, 0.4), Color("816e5a"), true)
	world._object("river_warning", 0, Vector3(298, 1, 8), "Read the warning bells")
	Art.label(self, "WARNING BELLS\nCircle: SAFE · Triangle: WARNING · Diamond: NEEDS CARE", Vector3(301, 7, 8), 26)
	warning_barrier = Art.box(self, Vector3(302, 1.5, 8), Vector3(0.5, 3, 8), Color("a887ad"), true)
	Art.label(self, "GROVE CLEARING\nRead the bells, then release the Blight", Vector3(322, 6, -12), 30)
	flower = Art.flower(self, Vector3(343, 0, 8), Color("e7d68f"), 3)
	world._object("river_peace", 0, Vector3(339, 1, 8), "Awaken the Peace Flower")
	Art.label(self, "PEACE FLOWER", Vector3(343, 6, 8), 30)
	world._gate(self, Vector3(350, 0, 8), "Harmony Stage · coming next")
	Art.box(self, Vector3(351, 2, 8), Vector3(0.5, 4, 6), Color("799d72"), true)
	refresh()

func _land(at: Vector3, size: Vector3) -> void:
	Art.box(self, at - Vector3.UP * size.y / 2, size, Color("8fab88"), true)
	Art.cone(self, at - Vector3.UP * 12, size.x * 0.35, size.x * 0.48, 22, Color("9f9982"))
	# Protect the long banks; docks and bridge entrances remain open at either end.
	for side in [-1, 1]: Art.box(self, at + Vector3(0, 0.8, side * size.z / 2), Vector3(size.x, 1.6, 0.5), Color("816e5a"), true)

func _show_solid(node: Node3D, enabled: bool) -> void:
	node.visible = enabled
	for shape in node.find_children("*", "CollisionShape3D", true, false): shape.set_deferred("disabled", not enabled)

func refresh() -> void:
	var saved: Dictionary = world.progress.committed.river
	for index in 3:
		channels[index].visible = saved.valves.has(index)
		bulbs[index].scale = Vector3.ONE * (0.45 if saved.bulbs.has(index) else 1.0)
		# Keep essential terrain connected. Each completed chime raises its bridge
		# to full visual strength instead of spawning a previously missing floor.
		_show_solid(decks[index], true)
		decks[index].scale = Vector3.ONE if saved.chimes.has(index) else Vector3(1.0, 0.75, 1.0)
	_show_solid(warning_barrier, not saved.warning)
	flower.scale = Vector3.ONE * (1.5 if saved.peace else 0.7)
	if saved.grove:
		for index in 2:
			world.restore_creature({"id": "river_moth" if index == 0 else "river_slime", "kind": "moth" if index == 0 else "slime"}, GROVE + Vector3(index * 5, 0, -8))

func objective() -> String:
	var r: Dictionary = world.progress.committed.river
	if r.valves.size() < 3: return "Cross the restored garden bridge. Tune the three river valves using their carved symbols."
	if r.bulbs.size() < 3: return "Release the three Hush Vine bulbs beside the river."
	if not r.boat: return "Ring the dock bell, then confirm your Rain Boat ride."
	if r.chimes.size() < 3: return "Restore the bridge chimes one at a time to grow a safe crossing."
	if not r.warning: return "Read the warning bells and choose the safe route."
	if not r.grove: return "Enter the grove. Step aside, then strike exposed shells."
	if not r.peace: return "Awaken the Peace Flower to complete the Heart Song."
	return "River Song restored! Peace Flower checkpoint active. Harmony Stage is coming next."

func interact(kind: String, index: int) -> void:
	if not world.progress.committed.complete:
		world._notice("The connected root walk lets you explore every Heart Melody garden. To awaken River Song, plant three seeds, solve the flower phrase and clear both Blight waves in Feeling Garden. If saving fails, use Help > Retry saving.")
		return
	match kind:
		"river_valve":
			world._open("Waterfall Organ · valve %d" % (index + 1), "Match the carved %s symbol. You can listen and retry without a timer." % SYMBOLS[NOTES[index]])
			world._button("Listen to this pipe", func(): world.note(NOTES[index]))
			for note in 3:
				world._button(SYMBOLS[note], func():
					world.note(note)
					if note == NOTES[index]: _save("valves", index, "The pipe is tuned. Its water channel is flowing.")
					else: world.message.text = "Listen again or read the carved symbol. Your other valves are unchanged."
				)
			world._button("Leave valve", world._close)
		"river_bulb": _save("bulbs", index, "The Blight shell opens. The living vine is safe.")
		"river_boat":
			if world.progress.committed.river.bulbs.size() != 3:
				world._notice("Tune the organ and release all three vine bulbs to free the Rain Boat.")
				return
			_far_dock = index == 1
			world.note(1, 0.18)
			boat.position = Vector3(221 if _far_dock else 183, 0.1, 8)
			world._open("Rain Boat", "The boat will wait here. Board only when you are ready. You can return from the other dock at any time.")
			world._button("Board and sail", begin_ride)
			world._button("Stay on shore", world._close)
		"river_chime":
			if world.progress.committed.river.chimes.size() < index:
				world._notice("Restore the nearer bridge chime first.")
			else: _save("chimes", index, "A supported bridge section grows. Walk to the next chime.")
		"river_warning":
			world._open("Read the warning bells", "Circle · SAFE: a quiet open path.\nTriangle · WARNING: an active pulse.\nDiamond · NEEDS CARE: a damaged path.\nWhich route can you use now?")
			world._button("Circle · take the quiet safe path", func(): _save("warning", -1, "The safe path opens. Watch the grove's attack markings before striking."))
			world._button("Triangle · enter the active pulse", func(): world.message.text = "Wait outside an active warning. Choose the quiet, open path.")
			world._button("Diamond · use the damaged path", func(): world.message.text = "This path needs repair. Choose the quiet, open path.")
			world._button("Leave bells", world._close)
		"river_peace":
			if _save("peace", -1, "River Song restored!\nThe Peace Flower is now your resting checkpoint.\nThe organ, bells and garden sing together.\nHarmony Stage is coming next."):
				world.player.heal(100)
				world._demonstrate([2, 0, 1, 0, 2, 1])

func _save(stage: String, index: int, text: String) -> bool:
	var success: bool = world.progress.river_step(stage, index)
	if success and stage in ["bulbs", "chimes"]: world.note(index, 0.22)
	refresh()
	world._notice(text if success else ("Save pending. Your work remains here; retry saving in Help." if world.progress.dirty else "Finish the earlier river tasks first.\n" + objective()))
	return success

func begin_ride() -> void:
	world._close()
	riding = true
	world.player.set_input_enabled(false)
	_ride_time = 0
	_departure = boat.position
	_destination = Vector3(183 if _far_dock else 221, 0.1, 8)

func tick(delta: float) -> void:
	if riding:
		_ride_time = minf(_ride_time + delta, 6.0)
		boat.position = _departure.lerp(_destination, smoothstep(0, 1, _ride_time / 6.0))
		world.player.global_position = boat.to_global(Vector3(0, 1.4, 0))
		world.player.velocity = Vector3.ZERO
		if _ride_time >= 6:
			riding = false
			world.player.global_position = world.to_global(Vector3(178 if _far_dock else 227, 1.2, 8))
			world.player.set_input_enabled(true)
			if not _far_dock: _save("boat", -1, "Welcome to Bell Grove. Restore the three bridge chimes.")
		return
	if world.modal_open or (world.embedded_in_overworld and not world.embedded_active): return
	if world.progress.committed.river.warning and not world.progress.data.river.grove and not _fighting and world.player_local_position().distance_to(GROVE) < 12:
		_start_grove()

func _start_grove() -> void:
	_fighting = true
	world.encounter_center = GROVE
	for index in 2:
		var enemy := Enemy.new()
		enemy.spec = {"id": "river_moth" if index == 0 else "river_slime", "kind": "moth" if index == 0 else "slime", "hp": 40, "damage": 8, "warning": 1.4, "recovery": 2.0}
		enemy.world = world
		enemy.player = world.player
		enemy.position = GROVE + Vector3(-4 + index * 8, 0, -4)
		enemy.released.connect(_released)
		world.enemies.append(enemy)
		world.add_child(enemy)

func _released(enemy: Node) -> void:
	world.enemies.erase(enemy)
	if world.enemies.is_empty():
		_fighting = false
		_save("grove", -1, "The grove creatures are restored. Awaken the Peace Flower.")

func reset_encounter() -> void:
	_fighting = false
	riding = false
	if not world.progress.committed.river.grove:
		for id in ["river_moth", "river_slime"]:
			if world.restored_creatures.has(id):
				world.restored_creatures[id].queue_free()
				world.restored_creatures.erase(id)

func recovery_position() -> Vector3:
	var saved: Dictionary = world.progress.committed.river
	if saved.peace: return Vector3(336, 2, 16)
	if saved.boat: return Vector3(238, 2, 8)
	return Vector3(118, 2, 8)
