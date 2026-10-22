extends Node3D

const Art = preload("res://scripts/heart_melody/heart_art.gd")
const Enemy = preload("res://scripts/heart_melody/heart_enemy.gd")
const NOTES := [2, 0, 1]
const SYMBOLS := ["Leaf", "Droplet", "Sun"]
const GROVE := Vector3(322, 1, 8)
## The Rain Boat waits on the water just beyond each bank's fence.
const NEAR_DOCK := 189.0
const FAR_DOCK := 215.0
var world: Node3D
var channels: Array[Node3D] = []
var bulbs: Array[Node3D] = []
var decks: Array[Node3D] = []
var boat: Node3D
var flower: Node3D
var riding := false
var _ride_time := 0.0
var _departure := Vector3.ZERO
var _destination := Vector3.ZERO
var _far_dock := false
var _fighting := false

func _ready() -> void:
	world = get_parent()
	# Every bank is fenced all round, open only where a bridge meets it; the
	# Peace Garden runs on into the Harmony valley, so its far end stays open.
	_land(Vector3(146, 0, 8), Vector3(76, 2, 58), {"x-": [Vector2(8, Art.CROSSING_WIDTH)], "x+": [Vector2(-8, ROOT_WALK_WIDTH)]})
	_land(Vector3(244, 0, 8), Vector3(48, 2, 44), {"x-": [Vector2(-8, ROOT_WALK_WIDTH)], "x+": [Vector2(8, CHIME_WIDTH)]})
	_land(Vector3(327, 0, 8), Vector3(54, 2, 58), {"x-": [Vector2(8, CHIME_WIDTH)], "x+": null}, 346.0)
	# Decks stand a few centimetres proud of the banks they meet: level with
	# the turf, overlapping ends flickered (z-fighting) as the camera moved.
	Art.crossing(self, 92, 108, 8)
	Art.banner(self, "WATERFALL ORGAN\nRestore the river's chord", Vector3(146, 10, -12), 32)
	for index in 3:
		var x := 126.0 + index * 17.0
		Art.cone(self, Vector3(x, 6 + index, -15), 2, 1.7, 12 + index * 2, Color("789d83"), true)
		Art.flower(self, Vector3(x, 0, 0), Color("e9c891"), 1.6)
		Art.symbol(self, Vector3(x, 0.2, 1), NOTES[index])
		world._object("river_valve", index, Vector3(x, 1, 3), "Tune organ valve %d" % (index + 1))
		channels.append(Art.box(self, Vector3(x, 5 + index, -12.8), Vector3(1.8, 10 + index * 2, 0.2), Color("86d4df")))
		var pos := Vector3(140 + index * 12, 0, 23)
		bulbs.append(Art.flower(self, pos, Color("755b82"), 1.9))
		world._object("river_bulb", index, pos + Vector3(0, 0, -3), "Release Hush Vine bulb %d" % (index + 1))
	for pos in [Vector3(116,0,-17), Vector3(174,0,-17), Vector3(234,0,-10), Vector3(342,0,-13)]: Art.tree(self, pos, 1)
	# A permanent flowering root walk joins both river banks. The Rain Boat stays
	# as a playful musical activity and shortcut, not the only route between land.
	Art.crossing(self, 184, 220, -8, ROOT_WALK_WIDTH)
	for x in [187.0, 195.0, 203.0, 211.0, 219.0]:
		Art.flower(self, Vector3(x, 0.1, -4.4), Color("e6b4c8") if int(x) % 2 else Color("eed17f"), 0.65)
	for x in [179, 225]:
		Art.cone(self, Vector3(x, 2.5, 16), 0.45, 0.4, 5, Color("816e5a"), true)
		Art.cone(self, Vector3(x, 4, 16), 1.1, 0.5, 1.4, Color("edcc7f"))
	world._object("river_boat", 0, Vector3(179, 1, 12), "Call / board Rain Boat")
	world._object("river_boat", 1, Vector3(225, 1, 12), "Return by Rain Boat")
	Art.banner(self, "RAIN BOAT\nRing the call bells, then board", Vector3(184, 7, 15), 28)
	boat = Node3D.new()
	boat.name = "RainBoat"
	add_child(boat)
	boat.position = Vector3(NEAR_DOCK, 0.1, 8)
	Art.box(boat, Vector3.ZERO, Vector3(8, 0.4, 6), Color("96764f"), true)
	for z in [-2.8, 2.8]: Art.box(boat, Vector3(0, 0.7, z), Vector3(8, 1, 0.3), Color("799d72"), true)
	for x in [-3, 3]: Art.cone(boat, Vector3(x, 2, 2.3), 0.2, 0.2, 4, Color("816e5a"))
	Art.cone(boat, Vector3(0, 4, 0), 4.6, 1, 0.7, Color("8db884"), false, 8)
	Art.banner(self, "BELL GROVE", Vector3(248, 8, -5), 32)
	for index in 3:
		var x := 262.0 + index * 12.0
		world._object("river_chime", index, Vector3(x, 1, 8), "Restore bridge chime %d" % (index + 1))
		Art.cone(self, Vector3(x, 2.5, 12), 0.35, 0.25, 5, Color("816e5a"))
		Art.cone(self, Vector3(x, 4, 12), 1, 0.5, 1.5, Color("edcc7f"))
		var deck := Node3D.new()
		deck.name = "ChimeBridge%d" % (index + 1)
		add_child(deck)
		decks.append(deck)
		# Three sections span exactly from the Bell Grove bank to the Peace Garden.
		var span := (300.0 - 268.0) / 3.0
		Art.crossing(deck, 268.0 + index * span, 268.0 + (index + 1) * span, 8, CHIME_WIDTH)
	world._object("river_warning", 0, Vector3(298, 1, 8), "Read the warning bells")
	Art.banner(self, "WARNING BELLS\nFollow the quiet gaps", Vector3(301, 7, 8), 28)
	Art.banner(self, "PEACE GARDEN\nA safe place to listen", Vector3(322, 6, -12), 30)
	flower = Art.flower(self, Vector3(343, 0, 8), Color("e7d68f"), 3)
	world._object("river_peace", 0, Vector3(339, 1, 8), "Awaken the Peace Flower")
	refresh()

const ROOT_WALK_WIDTH := 5.5
const CHIME_WIDTH := 8.0

# A rectangular bank with its fence. `fence_to_x` ends the long sides early
# where the bank runs on into the next platform.
func _land(at: Vector3, size: Vector3, sides: Dictionary, fence_to_x := INF) -> void:
	Art.box(self, at - Vector3.UP * size.y / 2, size, Color("8fab88"), true)
	Art.cone(self, at - Vector3.UP * 12, size.x * 0.35, size.x * 0.48, 22, Color("9f9982"))
	var low := Vector2(at.x - size.x / 2, at.z - size.z / 2)
	var high := Vector2(minf(at.x + size.x / 2, fence_to_x), at.z + size.z / 2)
	Art.rail_rect(self, low, high, sides)

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
	flower.scale = Vector3.ONE * 0.7
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
	return "River Song restored! Peace Flower checkpoint active. Follow the path onward to Harmony Stage."

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
			boat.position = Vector3(FAR_DOCK if _far_dock else NEAR_DOCK, 0.1, 8)
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
			if _save("peace", -1, "River Song restored!\nThe Peace Flower is now your resting checkpoint.\nThe organ, bells and garden sing together.\nFollow the path onward to Harmony Stage."):
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
	_destination = Vector3(NEAR_DOCK if _far_dock else FAR_DOCK, 0.1, 8)

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
