extends Node3D

@export var embedded_in_gallery := false

# The playable Art Castle Galaxy: a 2 km x 2 km connected floating world based
# on the supplied concept image. Geometry is generated from shared materials at
# runtime so the authored scene stays reviewable and the world can be tuned as
# one coherent layout.

const WORLD_HALF_EXTENT := 1000.0
const PLAYER_SPAWN := Vector3(0.0, 4.0, 790.0)
const HUB := Vector3(0.0, 0.0, 1640.0)
const MIND := Vector3(-600.0, 0.0, 1640.0)
const HEART := Vector3(0.0, 0.0, 2290.0)
const CREATOR := Vector3(600.0, 0.0, 1640.0)
const SOUTH_GATE := Vector3(0.0, 0.0, 820.0)
const RETURN_SCENE_PATH := "res://scenes/art_gallery_3d_inprogress.tscn"

var _player: CharacterBody3D
var _materials: Dictionary = {}
var _animated_nodes: Array[Node3D] = []
var _travelling := false


func _ready() -> void:
	_player = get_node_or_null("Player3D") as CharacterBody3D
	if _player == null and embedded_in_gallery and get_parent() != null:
		_player = get_parent().get_node_or_null("Player3D") as CharacterBody3D
	if _player != null and embedded_in_gallery:
		_player.set("speed", maxf(float(_player.get("speed")), 24.0))
	_build_materials()
	_build_central_sanctuary()
	_build_arrival_island()
	if embedded_in_gallery:
		_build_castle_approach_bridge()
	_build_mind_district()
	_build_heart_district()
	_build_creator_district()
	_build_story_landmarks()
	_build_boundary_observatories()
	_build_skyline()
	_build_cloud_banks()
	_build_world_labels()
	if not embedded_in_gallery:
		_build_standalone_minimap()
		_build_return_gate()


func _build_standalone_minimap() -> void:
	# This scene is also useful as a directly runnable gameplay scene. The
	# embedded gallery supplies its own map, but the standalone scene must create
	# one itself or launching it from the editor leaves the player with no HUD.
	var canvas := CanvasLayer.new()
	canvas.name = "WorldMapCanvas"
	canvas.layer = 40
	add_child(canvas)
	var minimap := Control.new()
	minimap.name = "ArteaWorldMinimap"
	minimap.set_script(load("res://scripts/art_castle_minimap.gd"))
	minimap.set("map_context", "galaxy")
	canvas.add_child(minimap)


func _process(delta: float) -> void:
	for index in _animated_nodes.size():
		var node := _animated_nodes[index]
		node.rotation.y += delta * (0.10 + float(index % 5) * 0.018)
	if _player != null and _player.global_position.y < -120.0:
		var respawn := PLAYER_SPAWN
		var regions := get_node_or_null("KingdomRegions3000m")
		if regions != null and regions.has_method("get_safe_respawn"):
			respawn = regions.call("get_safe_respawn", to_local(_player.global_position))
		_player.global_position = to_global(respawn)
		_player.velocity = Vector3.ZERO


func get_exploration_size() -> Vector2:
	return Vector2(WORLD_HALF_EXTENT * 2.0, WORLD_HALF_EXTENT * 2.0)


func get_kingdom_exploration_size() -> Vector2:
	return Vector2(3000.0, 3000.0)


func get_player_spawn() -> Vector3:
	return PLAYER_SPAWN


func get_return_scene_path() -> String:
	return RETURN_SCENE_PATH


func is_embedded_in_gallery() -> bool:
	return embedded_in_gallery


func _build_materials() -> void:
	_materials.ivory = _make_material(Color("e9e5ee"), 0.78)
	_materials.ivory_shadow = _make_material(Color("b9b8ce"), 0.92)
	_materials.stone = _make_material(Color("d3d4e2"), 0.88)
	_materials.aqua = _make_glow(Color("49d8e4"), 0.65)
	_materials.aqua_glass = _make_glow(Color(0.20, 0.88, 0.94, 0.70), 0.82, true)
	_materials.portal = _make_glow(Color(0.20, 0.88, 0.94, 0.20), 0.58, true)
	_materials.pink = _make_glow(Color("f08fca"), 0.62)
	_materials.purple = _make_glow(Color("9a72e8"), 0.52)
	_materials.purple_leaf = _make_material(Color("8566c7"), 0.86)
	_materials.pink_leaf = _make_material(Color("db79bd"), 0.84)
	_materials.green = _make_material(Color("58a77d"), 0.92)
	_materials.gold = _make_glow(Color("f2c55e"), 0.55)
	_materials.wood = _make_material(Color("8a5d3b"), 0.88)
	_materials.canvas = _make_material(Color("fff9e8"), 0.96)
	_materials.black = _make_material(Color("171424"), 0.72)
	_materials.window = _make_glow(Color("3ad2ee"), 0.76)


func _build_central_sanctuary() -> void:
	var island := Node3D.new()
	island.name = "CentralSanctuary"
	add_child(island)
	_build_island_foundation(island, HUB, 220.0, 58.0, 40)

	# Concentric paths and planted rings reproduce the round garden composition.
	_add_torus(island, "OuterGardenRing", HUB + Vector3(0.0, 0.35, 0.0), 153.0, 165.0, _materials.purple)
	_add_cylinder(island, "TreeCourt", HUB + Vector3(0.0, 0.1, 0.0), 108.0, 1.4, _materials.stone, true, 48)
	_add_torus(island, "InnerGardenRing", HUB + Vector3(0.0, 1.0, 0.0), 62.0, 68.0, _materials.aqua)

	for index in 72:
		var angle := TAU * float(index) / 72.0
		var radius := 132.0 + sin(float(index) * 2.3) * 15.0
		_add_flower_cluster(island, HUB + Vector3(cos(angle) * radius, 2.0, sin(angle) * radius),
			index % 3 == 0)

	_build_life_tree(island, HUB)
	_build_cat_companion(island, HUB + Vector3(-18.0, 2.0, -68.0))
	_build_radial_arches(island)

	_add_bridge("SouthArrivalBridge", Vector3(0.0, 0.0, 1422.0), Vector3(0.0, 0.0, 975.0), 62.0)
	_add_bridge("MindBridge", Vector3(-218.0, 0.0, 1640.0), Vector3(-430.0, 0.0, 1640.0), 58.0)
	_add_bridge("HeartBridge", Vector3(0.0, 0.0, 1858.0), Vector3(0.0, 0.0, 2120.0), 58.0)
	_add_bridge("CreatorBridge", Vector3(218.0, 0.0, 1640.0), Vector3(410.0, 0.0, 1640.0), 58.0)


func _build_arrival_island() -> void:
	var island := Node3D.new()
	island.name = "ArrivalIsland"
	add_child(island)
	_build_island_foundation(island, SOUTH_GATE, 155.0, 42.0, 28)
	_add_box(island, "ArrivalPromenade", Vector3(0.0, 0.3, 760.0), Vector3(86.0, 1.0, 180.0), _materials.stone, true)
	_add_box(island, "ArrivalMosaic", Vector3(0.0, 1.0, 760.0), Vector3(38.0, 0.8, 118.0), _materials.aqua_glass, false)
	for step in 6:
		var z := 710.0 + float(step) * 20.0
		_add_box(island, "MosaicRune_%02d" % step, Vector3(0.0, 1.7, z),
			Vector3(24.0, 0.35, 3.0), _materials.gold, false)
		_add_flower_cluster(island, Vector3(-47.0, 2.5, z), step % 2 == 0)
		_add_flower_cluster(island, Vector3(47.0, 2.5, z), step % 2 != 0)
	_build_frame(island, Vector3(0.0, 0.0, 715.0), 48.0, 62.0, _materials.gold, "ART CASTLE GALAXY")
	for side in [-1.0, 1.0]:
		_build_cypress(island, Vector3(side * 82.0, 2.0, 785.0), 34.0, _materials.purple_leaf)
		_build_cypress(island, Vector3(side * 108.0, 2.0, 865.0), 28.0, _materials.pink_leaf)
	for index in 18:
		var angle := TAU * float(index) / 18.0
		_add_flower_cluster(island, SOUTH_GATE + Vector3(cos(angle) * 125.0, 2.0, sin(angle) * 125.0), index % 2 == 0)


func _build_castle_approach_bridge() -> void:
	# The gallery's red-carpet PlaneMesh is centred at global z=10 and scaled to
	# 20 m long, so its front edge is global z=20 (local z=500 here). The bridge
	# begins on that exact boundary: no gap, no doubled surface, and no collision
	# overlap. Both remain aligned on x=0. The island
	# starts at local z=665 (centre 820 minus radius 155), leaving exactly 175 m.
	# Only the island end overlaps slightly, removing its collision seam.
	var bridge := Node3D.new()
	bridge.name = "ArtCastleEntranceBridge175m"
	add_child(bridge)
	var start := Vector3(0.0, 0.0, 500.0)
	var finish := Vector3(0.0, 0.0, 670.0)
	_add_bridge_between(bridge, start, finish, 16.0)
	bridge.set_meta("castle_carpet_end_global_z", 20.0)
	bridge.set_meta("walkway_start_global_z", to_global(start).z)
	bridge.set_meta("walkway_width", 16.0)
	_add_landmark_label(bridge, "CROWN JOURNEY WALKWAY", Vector3(0.0, 24.0, 615.0), Color("fff0b0"), 34)


func _add_bridge_between(parent: Node3D, start: Vector3, finish: Vector3, width: float) -> void:
	var direction := finish - start
	var length := direction.length()
	var midpoint := (start + finish) * 0.5
	var yaw := atan2(direction.x, direction.z)
	_add_box(parent, "ContinuousWalkway", midpoint, Vector3(width, 1.2, length), _materials.stone, true, yaw)
	var side_axis := Vector3(cos(yaw), 0.0, -sin(yaw))
	for side in [-1.0, 1.0]:
		var edge: Vector3 = midpoint + side_axis * float(side) * (width * 0.5 - 0.7) + Vector3(0.0, 2.4, 0.0)
		_add_box(parent, "SafetyRailLeft" if side < 0 else "SafetyRailRight", edge,
			Vector3(1.2, 4.8, length), _materials.ivory, true, yaw)
	for step in range(10, int(length), 20):
		var progress := float(step) / length
		var marker := start.lerp(finish, progress) + Vector3(0.0, 1.0, 0.0)
		_add_box(parent, "RainbowPathMarker", marker, Vector3(width - 3.0, 0.18, 2.0),
			_materials.aqua_glass, false, yaw)


func _build_mind_district() -> void:
	var district := Node3D.new()
	district.name = "MindSparkDistrict"
	add_child(district)
	_build_island_foundation(district, MIND, 175.0, 52.0, 32)

	# A large luminous tile puzzle provides readable detail at this world scale.
	for row in 8:
		for column in 8:
			var tile_pos := MIND + Vector3((column - 3.5) * 31.0, 1.0, (row - 3.5) * 31.0)
			var tile_mat: Material = _materials.aqua_glass if (row + column) % 2 == 0 else _materials.stone
			_add_box(district, "RuneTile_%02d_%02d" % [row, column], tile_pos,
				Vector3(28.0, 1.8, 28.0), tile_mat, true)

	var cube_positions := [Vector3(-685.0, 18.0, 55.0), Vector3(-560.0, 14.0, 70.0),
		Vector3(-650.0, 12.0, -70.0), Vector3(-535.0, 20.0, -48.0)]
	for index in cube_positions.size():
		_build_rune_cube(district, cube_positions[index], 24.0 + float(index % 2) * 8.0, index)

	_build_frame(district, MIND + Vector3(-92.0, 0.0, -96.0), 58.0, 76.0,
		_materials.aqua, "MIND SPARK")
	_build_ruin_wall(district, MIND + Vector3(-112.0, 0.0, 96.0), 150.0, 48.0, 0.0, _materials.ivory)
	for index in 24:
		var angle := TAU * float(index) / 24.0
		_add_flower_cluster(district, MIND + Vector3(cos(angle) * 148.0, 2.0, sin(angle) * 148.0), false)


func _build_heart_district() -> void:
	var district := Node3D.new()
	district.name = "HeartMelodyTemple"
	add_child(district)
	_build_island_foundation(district, HEART, 175.0, 55.0, 32)
	_add_cylinder(district, "MelodyStage", HEART + Vector3(0.0, 2.0, 0.0), 118.0, 4.0, _materials.pink, true, 40)

	# Seven playable-looking note pads arranged as a melody constellation.
	for index in 7:
		var angle := -PI * 0.8 + float(index) * PI * 0.27
		var radius := 65.0 + float(index % 2) * 24.0
		var pad_pos := HEART + Vector3(cos(angle) * radius, 5.0, sin(angle) * radius)
		_add_cylinder(district, "MelodyPad_%02d" % index, pad_pos, 17.0, 2.0,
			_materials.pink if index % 2 == 0 else _materials.purple, true, 24)

	# Temple arcade and central open doorway.
	for index in 7:
		var x := -108.0 + float(index) * 36.0
		_build_arch(district, HEART + Vector3(x, 2.0, -105.0), 26.0, 62.0, 10.0, _materials.ivory)
	_build_frame(district, HEART + Vector3(0.0, 2.0, -118.0), 44.0, 64.0, _materials.pink, "HEART MELODY")
	for index in 34:
		var angle := TAU * float(index) / 34.0
		_add_flower_cluster(district, HEART + Vector3(cos(angle) * 147.0, 3.0, sin(angle) * 147.0), true)


func _build_creator_district() -> void:
	var district := Node3D.new()
	district.name = "CreatorsLightStudio"
	add_child(district)
	_build_island_foundation(district, CREATOR, 195.0, 50.0, 36)
	_add_box(district, "StudioFloor", CREATOR + Vector3(0.0, 1.0, 0.0),
		Vector3(310.0, 2.0, 260.0), _make_material(Color("d9b275"), 0.88), true)
	_add_box(district, "StudioBackWall", CREATOR + Vector3(92.0, 48.0, -92.0),
		Vector3(120.0, 96.0, 9.0), _materials.ivory, true)

	for index in 6:
		var row := index / 3
		var column := index % 3
		_build_easel(district, CREATOR + Vector3(-82.0 + column * 78.0, 2.0, -40.0 + row * 92.0), index)
	_build_art_table(district, CREATOR + Vector3(92.0, 2.0, 68.0))
	_build_sun_rune(district, CREATOR + Vector3(92.0, 49.0, -86.5))
	_build_frame(district, CREATOR + Vector3(-105.0, 0.0, -105.0), 48.0, 66.0, _materials.gold, "CREATOR'S LIGHT")
	for index in 30:
		var angle := TAU * float(index) / 30.0
		_add_flower_cluster(district, CREATOR + Vector3(cos(angle) * 168.0, 2.0, sin(angle) * 168.0), index % 3 == 0)


# Readable physical landmarks turn the story document into an explorable route.
# Each named node is also a stable hook for later quest interaction scripts.
func _build_story_landmarks() -> void:
	_build_mind_story_landmarks()
	_build_heart_story_landmarks()
	_build_creator_story_landmarks()


func _build_mind_story_landmarks() -> void:
	var story := Node3D.new()
	story.name = "MindSparkQuestLandmarks"
	add_child(story)
	# A dark computer-tower forest softened by living vines.
	for index in 7:
		var angle := -1.2 + float(index) * 0.38
		var tower_pos := MIND + Vector3(cos(angle) * 132.0, 0.0, sin(angle) * 132.0)
		_add_box(story, "ThoughtTower_%02d" % index, tower_pos + Vector3(0.0, 25.0, 0.0),
			Vector3(18.0, 50.0 + float(index % 3) * 13.0, 18.0), _materials.black, true)
		_add_box(story, "LivingVine_%02d" % index, tower_pos + Vector3(9.5, 24.0, -9.5),
			Vector3(2.5, 45.0, 2.5), _materials.green)
	# The three reframing gates from the chapter.
	var gates := [
		{"name": "FearGate", "text": "FEAR GATE", "offset": Vector3(-118.0, 0.0, 24.0)},
		{"name": "ProofGate", "text": "PROOF GATE", "offset": Vector3(-40.0, 0.0, -118.0)},
		{"name": "WhatElseIsTrueGate", "text": "WHAT ELSE IS TRUE?", "offset": Vector3(72.0, 0.0, -105.0)},
	]
	for gate_data in gates:
		var gate := Node3D.new()
		gate.name = gate_data.name
		story.add_child(gate)
		_build_arch(gate, MIND + gate_data.offset, 24.0, 38.0, 9.0, _materials.aqua)
		_add_landmark_label(gate, gate_data.text, MIND + gate_data.offset + Vector3(0.0, 49.0, 0.0), Color("a9f7ff"))
	# Thought storm and the sanctuary reward at the oldest tree.
	var storm := Node3D.new()
	storm.name = "ThoughtStormBecomingGentleRain"
	story.add_child(storm)
	for index in 12:
		var angle := TAU * float(index) / 12.0
		_add_sphere(storm, "StormCloud", MIND + Vector3(cos(angle) * 52.0, 65.0 + index % 3 * 6.0, sin(angle) * 42.0),
			Vector3(16.0, 7.0, 11.0), _materials.purple)
	var sanctuary := Node3D.new()
	sanctuary.name = "OldestTreeSanctuary"
	story.add_child(sanctuary)
	_build_cypress(sanctuary, MIND + Vector3(118.0, 2.0, 45.0), 62.0, _materials.green)
	_add_torus(sanctuary, "StarOfWisdom", MIND + Vector3(118.0, 68.0, 45.0), 8.0, 12.0, _materials.gold)
	_add_landmark_label(sanctuary, "OLDEST TREE • STAR OF WISDOM", MIND + Vector3(118.0, 88.0, 45.0), Color("fff1a4"))


func _build_heart_story_landmarks() -> void:
	var story := Node3D.new()
	story.name = "HeartMelodyQuestLandmarks"
	add_child(story)
	# Seven emotional places circle the Personal Song amphitheatre.
	var places := [
		{"name": "JoyGarden", "text": "JOY GARDEN", "offset": Vector3(-125.0, 0.0, 42.0), "mat": _materials.gold},
		{"name": "FrustrationDrums", "text": "FRUSTRATION DRUMS", "offset": Vector3(-92.0, 0.0, -80.0), "mat": _materials.pink},
		{"name": "SadnessRainBoat", "text": "SADNESS RAIN BOAT", "offset": Vector3(-8.0, 0.0, -135.0), "mat": _materials.aqua},
		{"name": "FearWarningBells", "text": "FEAR WARNING BELLS", "offset": Vector3(95.0, 0.0, -82.0), "mat": _materials.purple},
		{"name": "PeaceFlowers", "text": "PEACE FLOWERS", "offset": Vector3(132.0, 0.0, 20.0), "mat": _materials.green},
		{"name": "HopeMorningStage", "text": "HOPE MORNING STAGE", "offset": Vector3(70.0, 0.0, 118.0), "mat": _materials.gold},
	]
	for index in places.size():
		var info: Dictionary = places[index]
		var landmark := Node3D.new()
		landmark.name = info.name
		story.add_child(landmark)
		var position_value: Vector3 = HEART + info.offset
		_add_cylinder(landmark, "EmotionInstrument", position_value + Vector3(0.0, 8.0, 0.0),
			12.0 + float(index % 2) * 4.0, 16.0, info.mat, true, 20)
		_add_landmark_label(landmark, info.text, position_value + Vector3(0.0, 31.0, 0.0), Color("ffe5f4"), 31)
	var song := Node3D.new()
	song.name = "PersonalSongAmphitheatre"
	story.add_child(song)
	_add_torus(song, "HarmonyJewelRing", HEART + Vector3(0.0, 9.0, 0.0), 32.0, 39.0, _materials.gold)
	_add_landmark_label(song, "RAPHAEL • PERSONAL SONG • HARMONY JEWEL", HEART + Vector3(0.0, 58.0, 0.0), Color("fff0b0"), 34)


func _build_creator_story_landmarks() -> void:
	var story := Node3D.new()
	story.name = "CreatorsLightQuestLandmarks"
	add_child(story)
	var studios := [
		{"name": "DrawingStudio", "text": "DRAWING STUDIO", "offset": Vector3(-130.0, 0.0, 70.0)},
		{"name": "DreamDoorWorkshop", "text": "DREAM DOOR WORKSHOP", "offset": Vector3(-115.0, 0.0, -18.0)},
		{"name": "RestingPlaceCanvas", "text": "RESTING PLACE CANVAS", "offset": Vector3(0.0, 0.0, 110.0)},
		{"name": "ArtRealGarden", "text": "ART-REAL GARDEN", "offset": Vector3(125.0, 0.0, 65.0)},
	]
	for index in studios.size():
		var info: Dictionary = studios[index]
		var landmark := Node3D.new()
		landmark.name = info.name
		story.add_child(landmark)
		var position_value: Vector3 = CREATOR + info.offset
		_build_frame(landmark, position_value, 28.0, 38.0,
			_materials.aqua if index % 2 == 0 else _materials.gold, info.text)
	# Floating shapes, glass seeds and silver pipes give this world the highest
	# magic/technology balance while keeping the handmade art studio central.
	for index in 10:
		var angle := TAU * float(index) / 10.0
		var shape_pos := CREATOR + Vector3(cos(angle) * 145.0, 45.0 + index % 3 * 14.0, sin(angle) * 145.0)
		_add_sphere(story, "GlassSeed_%02d" % index, shape_pos, Vector3(5.0, 10.0, 5.0), _materials.aqua_glass)
		_add_cylinder(story, "SilverPipe_%02d" % index, shape_pos + Vector3(0.0, -24.0, 0.0), 2.6, 42.0, _materials.stone, false, 10)
	var blank := Node3D.new()
	blank.name = "PerfectBlankSanctuary"
	story.add_child(blank)
	_build_frame(blank, CREATOR + Vector3(108.0, 0.0, -108.0), 60.0, 82.0, _materials.canvas, "THE PERFECT BLANK")
	_add_torus(blank, "CreatorsLight", CREATOR + Vector3(108.0, 48.0, -102.0), 11.0, 16.0, _materials.gold)
	_add_landmark_label(blank, "URIEL • CREATOR'S LIGHT", CREATOR + Vector3(108.0, 104.0, -108.0), Color("fff0a8"))


func _build_boundary_observatories() -> void:
	var points := [
		{"name": "WestObservatory", "center": Vector3(-920.0, 0.0, 1640.0), "from": Vector3(-775.0, 0.0, 1640.0), "to": Vector3(-850.0, 0.0, 1640.0)},
		{"name": "NorthObservatory", "center": Vector3(0.0, 0.0, 2565.0), "from": Vector3(0.0, 0.0, 2465.0), "to": Vector3(0.0, 0.0, 2495.0)},
		{"name": "EastObservatory", "center": Vector3(920.0, 0.0, 1640.0), "from": Vector3(795.0, 0.0, 1640.0), "to": Vector3(850.0, 0.0, 1640.0)},
		{"name": "SouthObservatory", "center": Vector3(0.0, 0.0, 710.0), "from": Vector3(0.0, 0.0, 740.0), "to": Vector3(0.0, 0.0, 765.0)},
	]
	for info in points:
		var lookout := Node3D.new()
		lookout.name = info.name
		add_child(lookout)
		var center: Vector3 = info.center
		_build_island_foundation(lookout, center, 70.0, 38.0, 20)
		_add_torus(lookout, "CompassRing", center + Vector3(0.0, 1.0, 0.0), 33.0, 38.0, _materials.gold)
		_build_tower(lookout, center, 34.0, 112.0, _materials.ivory)
		var from: Vector3 = info.from
		var to: Vector3 = info.to
		if from.distance_to(to) > 1.0:
			_add_bridge("%sBridge" % info.name, from, to, 34.0)


func _build_skyline() -> void:
	var skyline := Node3D.new()
	skyline.name = "DistantSkyline"
	add_child(skyline)
	var tower_data := [
		Vector4(-860, -720, 180, 42), Vector4(-610, -880, 240, 48),
		Vector4(-330, -900, 150, 36), Vector4(330, -900, 210, 44),
		Vector4(670, -820, 160, 38), Vector4(900, -650, 225, 46),
		Vector4(-940, -430, 145, 34), Vector4(940, -390, 170, 38),
		Vector4(-870, 540, 190, 42), Vector4(850, 560, 230, 48),
		Vector4(-600, 760, 145, 34), Vector4(600, 790, 175, 38),
	]
	for index in tower_data.size():
		var data: Vector4 = tower_data[index]
		var base := Vector3(data.x, -30.0 - float(index % 3) * 16.0, data.y)
		_build_cloud_tower(skyline, base, data.w, data.z, index)


func _build_cloud_banks() -> void:
	var clouds := Node3D.new()
	clouds.name = "CloudSea"
	add_child(clouds)
	var cloud_material := _make_material(Color(0.88, 0.94, 0.98, 0.72), 1.0, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 26032026
	for index in 120:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(280.0, 1120.0)
		var puff := MeshInstance3D.new()
		puff.name = "Cloud_%03d" % index
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(30.0, 80.0)
		mesh.height = mesh.radius * rng.randf_range(0.65, 1.1)
		mesh.radial_segments = 8
		mesh.rings = 4
		puff.mesh = mesh
		puff.scale = Vector3(rng.randf_range(1.4, 2.6), 0.45, rng.randf_range(0.9, 1.5))
		puff.position = Vector3(cos(angle) * radius, rng.randf_range(-95.0, -45.0), sin(angle) * radius)
		puff.material_override = cloud_material
		clouds.add_child(puff)


func _build_world_labels() -> void:
	_add_world_label("CentralLabel", "TREE OF IMAGINATION • CROWN LINE", HUB + Vector3(0.0, 72.0, -80.0), Color("e9d9ff"), 74)
	_add_world_label("GalleryStationLabel", "ARTÉA GALLERY STATION • JOURNEY BEGINS", Vector3(0.0, 76.0, 750.0), Color("fff0b0"), 54)
	_add_world_label("MindLabel", "MIND SPARK  •  CONSTELLATION COURT", MIND + Vector3(0.0, 82.0, 125.0), Color("9ff7ff"), 58)
	_add_world_label("HeartLabel", "HEART MELODY  •  TEMPLE OF SONG", HEART + Vector3(0.0, 90.0, 120.0), Color("ffd0ea"), 58)
	_add_world_label("CreatorLabel", "CREATOR'S LIGHT  •  SKY STUDIO", CREATOR + Vector3(0.0, 88.0, 135.0), Color("ffe4a0"), 58)
	if embedded_in_gallery:
		return

	var canvas := CanvasLayer.new()
	canvas.name = "WorldHUD"
	add_child(canvas)
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.04, 0.13, 0.72)
	panel.position = Vector2(22.0, 22.0)
	panel.size = Vector2(390.0, 92.0)
	canvas.add_child(panel)
	var label := Label.new()
	label.text = "ART CASTLE GALAXY\n2 KM FLOATING WORLD  •  WASD + MOUSE"
	label.position = Vector2(18.0, 14.0)
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color("f4eaff")
	panel.add_child(label)


func _build_return_gate() -> void:
	var exit_area := Area3D.new()
	exit_area.name = "ReturnToCastleGate"
	exit_area.position = Vector3(0.0, 6.0, 958.0)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(58.0, 18.0, 20.0)
	shape_node.shape = shape
	exit_area.add_child(shape_node)
	exit_area.body_entered.connect(_on_return_gate_entered)
	add_child(exit_area)
	_add_world_label("ReturnLabel", "RETURN TO ART GALLERY", Vector3(0.0, 28.0, 950.0), Color("fff0b0"), 42)


func _on_return_gate_entered(body: Node3D) -> void:
	if _travelling or body != _player:
		return
	if not ResourceLoader.exists(RETURN_SCENE_PATH):
		return
	_travelling = true
	get_tree().change_scene_to_file.call_deferred(RETURN_SCENE_PATH)


func _build_island_foundation(parent: Node3D, center: Vector3, radius: float,
		depth: float, segments: int) -> void:
	_add_cylinder(parent, "WalkableDeck", center + Vector3(0.0, -1.5, 0.0), radius,
		3.0, _materials.ivory, true, segments)
	var underside := MeshInstance3D.new()
	underside.name = "FloatingUnderside"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.94
	mesh.bottom_radius = radius * 0.20
	mesh.height = depth
	mesh.radial_segments = segments
	underside.mesh = mesh
	underside.position = center + Vector3(0.0, -depth * 0.5 - 2.0, 0.0)
	underside.material_override = _materials.ivory_shadow
	parent.add_child(underside)
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var crystal := MeshInstance3D.new()
		var crystal_mesh := CylinderMesh.new()
		crystal_mesh.top_radius = radius * 0.035
		crystal_mesh.bottom_radius = radius * 0.006
		crystal_mesh.height = depth * (0.55 + float(index % 3) * 0.10)
		crystal_mesh.radial_segments = 5
		crystal.mesh = crystal_mesh
		crystal.position = center + Vector3(cos(angle) * radius * 0.72, -depth * 0.78, sin(angle) * radius * 0.72)
		crystal.material_override = _materials.ivory_shadow
		parent.add_child(crystal)


func _add_bridge(node_name: String, start: Vector3, end: Vector3, width: float) -> void:
	var bridge := Node3D.new()
	bridge.name = node_name
	add_child(bridge)
	var direction := end - start
	var length := direction.length()
	var midpoint := (start + end) * 0.5 + Vector3(0.0, -2.0, 0.0)
	var yaw := atan2(direction.x, direction.z)
	_add_box(bridge, "Walkway", midpoint, Vector3(width, 4.0, length), _materials.stone, true, yaw)
	var side_axis := Vector3(cos(yaw), 0.0, -sin(yaw))
	for side in [-1.0, 1.0]:
		var edge_position: Vector3 = midpoint + side_axis * float(side) * (width * 0.5 - 2.0) + Vector3(0.0, 5.0, 0.0)
		_add_box(bridge, "SafetyRail", edge_position, Vector3(3.0, 10.0, length), _materials.ivory, true, yaw)
		for step in range(0, int(length), 55):
			var t := float(step) / length
			var planter_pos: Vector3 = start.lerp(end, t) + side_axis * float(side) * (width * 0.5 - 7.0) + Vector3(0.0, 3.0, 0.0)
			_add_flower_cluster(bridge, planter_pos, (step / 55) % 2 == 0)
	for step in range(45, int(length), 90):
		var t := float(step) / length
		var support_pos := start.lerp(end, t) + Vector3(0.0, -24.0, 0.0)
		_add_arch_support(bridge, support_pos, width, yaw)


func _build_life_tree(parent: Node3D, center: Vector3) -> void:
	var tree := Node3D.new()
	tree.name = "TreeOfImagination"
	tree.position = center
	parent.add_child(tree)
	_add_cylinder(tree, "Trunk", Vector3(0.0, 25.0, 0.0), 8.5, 50.0, _materials.wood, false, 9)
	for branch in 9:
		var angle := TAU * float(branch) / 9.0
		var branch_node := _add_box(tree, "Branch_%02d" % branch,
			Vector3(cos(angle) * 18.0, 51.0, sin(angle) * 18.0), Vector3(7.0, 7.0, 42.0),
			_materials.wood, false, angle)
		branch_node.rotation.x = deg_to_rad(-28.0)
	for index in 46:
		var angle := float(index) * 2.39996
		var radius := 15.0 + sqrt(float(index)) * 7.0
		var bloom := MeshInstance3D.new()
		bloom.name = "CanopyBloom_%02d" % index
		var mesh := SphereMesh.new()
		mesh.radius = 13.0 + float(index % 4) * 2.5
		mesh.height = mesh.radius * 1.5
		mesh.radial_segments = 8
		mesh.rings = 4
		bloom.mesh = mesh
		bloom.position = Vector3(cos(angle) * radius, 62.0 + sin(float(index) * 1.4) * 15.0, sin(angle) * radius)
		bloom.material_override = _materials.purple_leaf if index % 3 else _materials.pink_leaf
		tree.add_child(bloom)


func _build_cat_companion(parent: Node3D, position: Vector3) -> void:
	var cat := Node3D.new()
	cat.name = "BlackCatGuide"
	cat.position = position
	parent.add_child(cat)
	_add_sphere(cat, "Body", Vector3(0.0, 5.0, 0.0), Vector3(5.5, 7.0, 4.5), _materials.black)
	_add_sphere(cat, "Head", Vector3(0.0, 12.0, 0.0), Vector3(4.8, 4.8, 4.8), _materials.black)
	for side in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(3.5, 5.0, 2.5)
		ear.mesh = mesh
		ear.position = Vector3(side * 2.7, 16.0, 0.0)
		ear.material_override = _materials.black
		cat.add_child(ear)
		_add_sphere(cat, "Eye", Vector3(side * 1.8, 12.7, -4.2), Vector3(0.75, 1.0, 0.45), _materials.gold)


func _build_radial_arches(parent: Node3D) -> void:
	var configs := [HUB + Vector3(-145.0, 0.0, -145.0), HUB + Vector3(145.0, 0.0, -145.0),
		HUB + Vector3(-145.0, 0.0, 145.0), HUB + Vector3(145.0, 0.0, 145.0)]
	for index in configs.size():
		_build_arch(parent, configs[index], 34.0, 58.0, 12.0, _materials.ivory)


func _build_rune_cube(parent: Node3D, position: Vector3, size: float, index: int) -> void:
	var cube := _add_box(parent, "ConstellationCube_%02d" % index, position,
		Vector3.ONE * size, _materials.aqua_glass, true, float(index) * 0.32)
	_animated_nodes.append(cube)
	_add_torus(parent, "CubeOrbit_%02d" % index, position, size * 0.72, size * 0.79, _materials.gold, Vector3(90.0, 25.0, 0.0))


func _build_easel(parent: Node3D, position: Vector3, index: int) -> void:
	var easel := Node3D.new()
	easel.name = "PaintingEasel_%02d" % index
	easel.position = position
	parent.add_child(easel)
	for side in [-1.0, 1.0]:
		var leg := _add_box(easel, "Leg", Vector3(side * 11.0, 18.0, 2.0), Vector3(4.0, 40.0, 4.0), _materials.wood)
		leg.rotation.z = deg_to_rad(side * 8.0)
	_add_box(easel, "RearLeg", Vector3(0.0, 16.0, 10.0), Vector3(4.0, 38.0, 4.0), _materials.wood)
	_add_box(easel, "Canvas", Vector3(0.0, 34.0, -1.0), Vector3(38.0, 45.0, 3.0), _materials.canvas)
	_add_box(easel, "CanvasRest", Vector3(0.0, 12.0, 0.0), Vector3(46.0, 4.0, 7.0), _materials.wood)


func _build_art_table(parent: Node3D, position: Vector3) -> void:
	var table := Node3D.new()
	table.name = "ArtistMaterialsTable"
	table.position = position
	parent.add_child(table)
	_add_box(table, "Top", Vector3(0.0, 20.0, 0.0), Vector3(72.0, 5.0, 38.0), _materials.wood, true)
	for x in [-29.0, 29.0]:
		for z in [-12.0, 12.0]:
			_add_box(table, "Leg", Vector3(x, 9.0, z), Vector3(5.0, 18.0, 5.0), _materials.wood)
	for index in 8:
		var color_mat: Material = [_materials.aqua, _materials.pink, _materials.purple, _materials.gold][index % 4]
		_add_cylinder(table, "PaintPot_%02d" % index, Vector3(-26.0 + index * 7.5, 25.0, 0.0), 3.0, 5.0, color_mat, false, 12)


func _build_sun_rune(parent: Node3D, position: Vector3) -> void:
	_add_torus(parent, "SunRuneOuter", position, 22.0, 25.0, _materials.gold, Vector3(90.0, 0.0, 0.0))
	_add_torus(parent, "SunRuneInner", position + Vector3(0.0, 0.0, -1.0), 8.0, 10.0, _materials.gold, Vector3(90.0, 0.0, 0.0))
	for index in 8:
		var angle := TAU * float(index) / 8.0
		_add_box(parent, "SunRay", position + Vector3(cos(angle) * 34.0, sin(angle) * 34.0, 0.0),
			Vector3(3.0, 15.0, 3.0), _materials.gold, false, -angle)


func _build_cloud_tower(parent: Node3D, base: Vector3, width: float, height: float, index: int) -> void:
	var tower := Node3D.new()
	tower.name = "SkyTower_%02d" % index
	tower.position = base
	parent.add_child(tower)
	_add_box(tower, "TowerBody", Vector3(0.0, height * 0.5, 0.0), Vector3(width, height, width * 0.72), _materials.ivory)
	_add_box(tower, "TowerCrown", Vector3(0.0, height + 15.0, 0.0), Vector3(width * 0.72, 30.0, width * 0.62), _materials.ivory)
	for level in range(35, int(height), 42):
		_add_box(tower, "LuminousWindow", Vector3(0.0, float(level), -width * 0.37), Vector3(width * 0.20, 24.0, 2.5), _materials.window)
	_build_cypress(tower, Vector3(width * 0.34, height + 30.0, 0.0), 22.0 + float(index % 4) * 4.0, _materials.purple_leaf)


func _build_tower(parent: Node3D, base: Vector3, width: float, height: float, material: Material) -> void:
	_add_box(parent, "ObservatoryTower", base + Vector3(0.0, height * 0.5, 18.0), Vector3(width, height, width), material, true)
	_add_box(parent, "ObservatoryWindow", base + Vector3(0.0, height * 0.62, 0.5), Vector3(width * 0.28, height * 0.34, 3.0), _materials.window)
	_build_cypress(parent, base + Vector3(width * 0.75, 2.0, -18.0), 28.0, _materials.purple_leaf)


func _build_ruin_wall(parent: Node3D, center: Vector3, width: float, height: float,
		yaw: float, material: Material) -> void:
	_add_box(parent, "RuinWall", center + Vector3(0.0, height * 0.5, 0.0), Vector3(width, height, 10.0), material, true, yaw)
	for index in 4:
		_build_arch(parent, center + Vector3(-width * 0.36 + index * width * 0.24, 1.0, -6.0), 22.0, 36.0, 8.0, _materials.aqua)


func _build_arch(parent: Node3D, position: Vector3, opening_width: float,
		height: float, depth: float, material: Material) -> void:
	var arch := Node3D.new()
	arch.name = "OpenArch"
	arch.position = position
	parent.add_child(arch)
	_add_box(arch, "LeftPillar", Vector3(-opening_width * 0.62, height * 0.45, 0.0), Vector3(opening_width * 0.24, height * 0.9, depth), material, true)
	_add_box(arch, "RightPillar", Vector3(opening_width * 0.62, height * 0.45, 0.0), Vector3(opening_width * 0.24, height * 0.9, depth), material, true)
	_add_box(arch, "Lintel", Vector3(0.0, height, 0.0), Vector3(opening_width * 1.48, height * 0.20, depth), material, true)
	_add_torus(arch, "ArchGlow", Vector3(0.0, height * 0.62, -depth * 0.55), opening_width * 0.42,
		opening_width * 0.48, _materials.pink, Vector3(90.0, 0.0, 0.0))


func _build_frame(parent: Node3D, position: Vector3, width: float, height: float,
		material: Material, label_text: String) -> void:
	var frame := Node3D.new()
	frame.name = "%sPortalFrame" % label_text.replace("'", "").replace(" ", "")
	frame.position = position
	parent.add_child(frame)
	_add_box(frame, "Left", Vector3(-width * 0.5, height * 0.5, 0.0), Vector3(7.0, height, 8.0), material, true)
	_add_box(frame, "Right", Vector3(width * 0.5, height * 0.5, 0.0), Vector3(7.0, height, 8.0), material, true)
	_add_box(frame, "Top", Vector3(0.0, height, 0.0), Vector3(width + 7.0, 7.0, 8.0), material, true)
	_add_box(frame, "PortalSurface", Vector3(0.0, height * 0.5, 2.0), Vector3(width - 8.0, height - 10.0, 1.5),
		_materials.portal, false)
	var label := Label3D.new()
	label.text = label_text
	label.position = Vector3(0.0, height + 15.0, 0.0)
	label.font_size = 48
	label.outline_size = 10
	label.modulate = Color("fff1c4")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	frame.add_child(label)


func _build_cypress(parent: Node3D, position: Vector3, height: float, material: Material) -> void:
	var tree := Node3D.new()
	tree.name = "SkyCypress"
	tree.position = position
	parent.add_child(tree)
	_add_cylinder(tree, "Trunk", Vector3(0.0, height * 0.35, 0.0), height * 0.07, height * 0.7, _materials.wood, false, 7)
	for level in 5:
		var crown := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.8
		mesh.bottom_radius = height * (0.18 - level * 0.018)
		mesh.height = height * 0.28
		mesh.radial_segments = 7
		crown.mesh = mesh
		crown.position.y = height * (0.43 + level * 0.115)
		crown.material_override = material
		tree.add_child(crown)


func _add_flower_cluster(parent: Node3D, position: Vector3, pink: bool) -> void:
	var cluster := MeshInstance3D.new()
	cluster.name = "FlowerGarden"
	var mesh := SphereMesh.new()
	mesh.radius = 5.5
	mesh.height = 7.0
	mesh.radial_segments = 6
	mesh.rings = 3
	cluster.mesh = mesh
	cluster.scale = Vector3(1.7, 0.75, 1.0)
	cluster.position = position
	cluster.material_override = _materials.pink_leaf if pink else _materials.purple_leaf
	parent.add_child(cluster)


func _add_arch_support(parent: Node3D, position: Vector3, width: float, yaw: float) -> void:
	var support := Node3D.new()
	support.position = position
	support.rotation.y = yaw
	parent.add_child(support)
	_add_box(support, "LeftPier", Vector3(-width * 0.38, 0.0, 0.0), Vector3(7.0, 48.0, 8.0), _materials.ivory_shadow)
	_add_box(support, "RightPier", Vector3(width * 0.38, 0.0, 0.0), Vector3(7.0, 48.0, 8.0), _materials.ivory_shadow)
	_add_box(support, "SupportBeam", Vector3(0.0, 22.0, 0.0), Vector3(width, 6.0, 8.0), _materials.ivory_shadow)


func _add_world_label(node_name: String, text: String, position: Vector3,
		color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = position
	label.font_size = font_size
	label.outline_size = 12
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _add_landmark_label(parent: Node3D, text: String, position: Vector3,
		color: Color, font_size: int = 36) -> void:
	var label := Label3D.new()
	label.name = "%sLabel" % text.to_pascal_case().replace("'", "").replace("•", "")
	label.text = text
	label.position = position
	label.font_size = font_size
	label.outline_size = 9
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)


func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3,
		material: Material, collision_enabled: bool = false, yaw: float = 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.rotation.y = yaw
	instance.material_override = material
	parent.add_child(instance)
	if collision_enabled:
		var body := StaticBody3D.new()
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		body.position = position
		body.rotation.y = yaw
		parent.add_child(body)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, position: Vector3,
		radius: float, height: float, material: Material, collision_enabled: bool,
		segments: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	if collision_enabled:
		var body := StaticBody3D.new()
		var shape_node := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		shape_node.shape = shape
		body.add_child(shape_node)
		body.position = position
		parent.add_child(body)
	return instance


func _add_torus(parent: Node3D, node_name: String, position: Vector3,
		inner_radius: float, outer_radius: float, material: Material,
		rotation_degrees_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 48
	mesh.ring_segments = 8
	instance.mesh = mesh
	instance.position = position
	instance.rotation_degrees = rotation_degrees_value
	instance.material_override = material
	parent.add_child(instance)
	_animated_nodes.append(instance)
	return instance


func _add_sphere(parent: Node3D, node_name: String, position: Vector3,
		scale_value: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	instance.mesh = mesh
	instance.position = position
	instance.scale = scale_value
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _make_material(color: Color, roughness: float,
		transparent: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _make_glow(color: Color, energy: float,
		transparent: bool = false) -> StandardMaterial3D:
	var material := _make_material(color, 0.38, transparent)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
