extends Node3D

const MindSparkWorldGateScene := preload("res://scenes/mind_spark/world_gate.tscn")
const TreeOfLifeScene := preload("res://assets3D/tree_of_life/glb/artea_tree_of_life.glb")
const CrystalBranchCanopyScene := preload("res://assets3D/tree_of_life/canopy/glb/crystal_branch_canopy.glb")
const PoweredGravityBoughScene := preload("res://assets3D/tree_of_life/gravity_leaf_bough/glb/gravity_leaf_bough_runtime.glb")
const TREE_OF_LIFE_MANIFEST_PATH := "res://assets3D/tree_of_life/tree_of_life_manifest.json"

@export var embedded_in_gallery := false

# The playable Art Castle Galaxy: a 2 km x 2 km connected floating world based
# on the supplied concept image. Geometry is generated from shared materials at
# runtime so the authored scene stays reviewable and the world can be tuned as
# one coherent layout.

const WORLD_HALF_EXTENT := 1000.0
const PLAYER_SPAWN := Vector3(0.0, 4.0, 790.0)
const HUB := Vector3(0.0, 0.0, 1640.0)
const TREE_OF_LIFE_GAME_SCALE := 3.30
const TREE_OF_LIFE_SCALE_MULTIPLIER := 2.0
# The v3 Blender clear-path tiles sit 0.63 local metres above its origin. This
# offset places their scaled top exactly on the existing TreeCourt collision.
const TREE_OF_LIFE_COURT_SURFACE_Y := -0.24
const TREE_OF_LIFE_CLEAR_PATH_M := 9.5
const MIND := Vector3(-600.0, 0.0, 1640.0)
const MIND_GATE_POSITION := Vector3(-692.0, 1.0, 1544.0)
const MIND_GATE_RETURN_LANDING := Vector3(-650.0, 7.0, 1575.0)
# Keep the full six-island blueprint near enough to read from the Art Castle
# atlas while retaining a 300 m void buffer from the western district edge.
const MIND_WORLD_ONE_ORIGIN := Vector3(-2200.0, 0.0, 1640.0)
const MIND_DISTRICT_RADIUS := 175.0
# A centered odd grid keeps the Mind Bridge approach on an exact mirror axis.
# The island deck remains the single continuous collision surface at y = 0;
# these shallow rune inlays are visual detail only, so they cannot form steps or
# collision seams that catch the player.
const MIND_RUNE_GRID_SIZE := 9
const MIND_RUNE_TILE_SPACING := 27.0
const MIND_RUNE_TILE_SIZE := 25.2
const MIND_RUNE_TILE_HEIGHT := 0.08
# Walkable causeway from the Mind district out to the relocated World One.
const CAUSEWAY_WIDTH := 26.0
const CAUSEWAY_DECK_Y := 1.0
const CAUSEWAY_SEGMENT_LENGTH := 420.0
const CAUSEWAY_ISLAND_RADIUS := 46.0
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
	_build_mind_spark_world_one_gameplay()
	_build_world_one_walk_route()
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
	_materials.bridge_deck = _make_textured_material(
		Color("30394c"), Color("59667e"), Color("38d9e8"), 0.74, 16)
	_materials.bridge_edge = _make_textured_material(
		Color("d9dce7"), Color("a5acbd"), Color("f2c55e"), 0.84, 12)
	_materials.bridge_glass = _make_glow(Color(0.20, 0.88, 0.94, 0.32), 0.72, true)
	_materials.bridge_structure = _make_material(Color("475166"), 0.68)
	_materials.bridge_rubber = _make_material(Color("171b24"), 0.96)


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
	bridge.set_meta("structural_system", "continuous_static_deck_on_portal-frame-piers")
	bridge.set_meta("structural_mass_class", "infinite_static_mass")
	bridge.set_meta("architectural_scale", 4.0)
	bridge.set_meta("clear_walk_width_m", 13.6)
	bridge.set_meta("rail_height_m", 4.8)
	bridge.set_meta("deck_friction", 0.92)
	bridge.set_meta("maximum_live_character_mass_kg", 250.0)
	bridge.set_meta("design_gravity_m_s2", 9.8)
	bridge.set_meta("castle_carpet_end_global_z", 20.0)
	bridge.set_meta("walkway_start_global_z", to_global(start).z)
	bridge.set_meta("walkway_width", 16.0)
	_add_landmark_label(bridge, "CROWN JOURNEY WALKWAY", Vector3(0.0, 24.0, 615.0), Color("fff0b0"), 34)
	_build_approach_fall_recovery(bridge, start, finish)

func _add_bridge_between(parent: Node3D, start: Vector3, finish: Vector3, width: float) -> void:
	var direction := finish - start
	var length := direction.length()
	var midpoint := (start + finish) * 0.5
	var yaw := atan2(direction.x, direction.z)
	# Primary deck: a high-friction static body. StaticBody3D is intentionally
	# infinite mass, so player weight, jumping and movable props cannot displace
	# the bridge. The visible finish is a procedural circuit-stone texture.
	_add_box(parent, "ContinuousWalkway", midpoint, Vector3(width, 1.2, length),
		_materials.bridge_deck, true, yaw, 0.92, 0.0)
	_add_box(parent, "UnderDeckSpine", midpoint + Vector3(0, -2.35, 0),
		Vector3(4.0, 3.5, length - 2.0), _materials.bridge_structure, true, yaw, 0.88, 0.0)
	# Surface plates, anti-slip transverse strips and expansion joints make the
	# long span readable at walking height without creating collision seams.
	for metre in range(5, int(length), 10):
		var progress := float(metre) / length
		var plate_center := start.lerp(finish, progress) + Vector3(0, 0.68, 0)
		_add_box(parent, "DeckPlate_%03d" % metre, plate_center,
			Vector3(width - 1.6, 0.10, 8.8), _materials.bridge_deck, false, yaw)
		_add_box(parent, "AntiSlipJoint_%03d" % metre,
			plate_center + Vector3(0, 0.09, 0), Vector3(width - 1.0, 0.08, 0.42),
			_materials.bridge_rubber, false, yaw)
	var side_axis := Vector3(cos(yaw), 0.0, -sin(yaw))
	for side in [-1.0, 1.0]:
		var edge: Vector3 = midpoint + side_axis * float(side) * (width * 0.5 - 0.7) + Vector3(0.0, 2.4, 0.0)
		var side_name := "Left" if side < 0 else "Right"
		# A continuous collision curb remains at foot level; posts, glass infill
		# and the top rail provide the detailed visible guard system.
		_add_box(parent, "SafetyRail%s" % side_name, edge + Vector3(0, -1.65, 0),
			Vector3(1.2, 1.5, length), _materials.bridge_edge, true, yaw, 0.86, 0.0)
		_add_box(parent, "GuardGlass%s" % side_name, edge + Vector3(0, 0.15, 0),
			Vector3(0.34, 3.2, length - 1.0), _materials.bridge_glass, true, yaw, 0.35, 0.0)
		_add_box(parent, "TopRail%s" % side_name, edge + Vector3(0, 2.3, 0),
			Vector3(0.9, 0.65, length), _materials.bridge_edge, true, yaw, 0.82, 0.0)
		for metre in range(0, int(length) + 1, 10):
			var post_progress := minf(1.0, float(metre) / length)
			var post_position := start.lerp(finish, post_progress)
			post_position += side_axis * float(side) * (width * 0.5 - 0.7) + Vector3(0, 2.55, 0)
			_add_box(parent, "GuardPost%s_%03d" % [side_name, metre], post_position,
				Vector3(0.9, 5.1, 0.9), _materials.bridge_edge, true, yaw, 0.82, 0.0)
	for step in range(10, int(length), 20):
		var progress := float(step) / length
		var marker := start.lerp(finish, progress) + Vector3(0.0, 1.0, 0.0)
		_add_box(parent, "RainbowPathMarker", marker, Vector3(width - 3.0, 0.18, 2.0),
			_materials.aqua_glass, false, yaw)
	# Portal-frame piers take the visual load into the floating foundation.
	for metre in range(20, int(length), 30):
		var pier_progress := float(metre) / length
		var pier_center := start.lerp(finish, pier_progress) + Vector3(0, -10.5, 0)
		_add_box(parent, "PierCrossbeam_%03d" % metre, pier_center + Vector3(0, 4.0, 0),
			Vector3(width + 5.0, 2.2, 2.4), _materials.bridge_structure, true, yaw, 0.88, 0.0)
		for side in [-1.0, 1.0]:
			var pier_leg := pier_center + side_axis * float(side) * (width * 0.42)
			_add_box(parent, "PierLeg_%03d_%s" % [metre, "L" if side < 0 else "R"],
				pier_leg, Vector3(2.4, 21.0, 2.4), _materials.bridge_structure, true, yaw, 0.88, 0.0)
	# Carpet/deck and deck/island thresholds are broad, shallow, walkable ramps.
	for endpoint_data in [[start, "Castle"], [finish, "Island"]]:
		_add_box(parent, "%sThresholdRamp" % endpoint_data[1],
			(endpoint_data[0] as Vector3) + Vector3(0, 0.36, 0),
			Vector3(width - 0.8, 0.32, 5.0), _materials.bridge_edge, true, yaw, 0.94, 0.0)


func _build_approach_fall_recovery(parent: Node3D, start: Vector3, finish: Vector3) -> void:
	var recovery := Area3D.new()
	recovery.name = "ApproachFallRecovery"
	recovery.position = start.lerp(finish, 0.5) + Vector3(0, -22, 0)
	recovery.collision_layer = 0
	recovery.collision_mask = 1
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 20, start.distance_to(finish) + 30)
	shape_node.shape = shape
	recovery.add_child(shape_node)
	parent.add_child(recovery)
	recovery.body_entered.connect(_recover_approach_player.bind(start + Vector3(0, 4, 5)))


func _recover_approach_player(body: Node3D, safe_position: Vector3) -> void:
	if body != _player or _player == null:
		return
	_player.global_position = to_global(safe_position)
	_player.velocity = Vector3.ZERO


func _build_mind_district() -> void:
	var district := Node3D.new()
	district.name = "MindSparkDistrict"
	add_child(district)
	_build_island_foundation(district, MIND, MIND_DISTRICT_RADIUS, 52.0, 32)
	district.set_meta("symmetry_axis_z", MIND.z)
	district.set_meta("bridge_surface_y", MIND.y)
	district.set_meta("ground_surface_y", MIND.y)
	district.set_meta("ground_collision_source", "WalkableDeckCollision")
	district.set_meta("rune_grid_size", MIND_RUNE_GRID_SIZE)
	district.set_meta("requires_jump_from_mind_bridge", false)

	# An odd grid places one tile exactly on the bridge centerline. The shallow
	# visual inlays sit over the island's continuous deck collision rather than
	# creating 81 raised collision blocks.
	var half_grid := float(MIND_RUNE_GRID_SIZE - 1) * 0.5
	for row in MIND_RUNE_GRID_SIZE:
		for column in MIND_RUNE_GRID_SIZE:
			var tile_pos := MIND + Vector3(
				(float(column) - half_grid) * MIND_RUNE_TILE_SPACING,
				MIND_RUNE_TILE_HEIGHT * 0.5,
				(float(row) - half_grid) * MIND_RUNE_TILE_SPACING)
			var tile_mat: Material = _materials.aqua_glass if (row + column) % 2 == 0 else _materials.stone
			_add_box(district, "RuneTile_%02d_%02d" % [row, column], tile_pos,
				Vector3(MIND_RUNE_TILE_SIZE, MIND_RUNE_TILE_HEIGHT, MIND_RUNE_TILE_SIZE),
				tile_mat, false)

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
	# Mind Spark's story landmarks live in the complete six-island World One.
	# The original cyan district remains a clear World Gate forecourt.
	_build_heart_story_landmarks()
	_build_creator_story_landmarks()


func _build_mind_spark_world_one_gameplay() -> void:
	if has_node("MindSparkWorldOne"):
		return
	var world_one_scene := load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene
	if world_one_scene == null:
		return
	var world_one := world_one_scene.instantiate() as MindSparkWorldOne
	world_one.name = "MindSparkWorldOne"
	world_one.force_standalone_blueprint = true
	world_one.return_destination_world_local = MIND_GATE_RETURN_LANDING
	world_one.position = MIND_WORLD_ONE_ORIGIN
	add_child(world_one)
	var source_gate := MindSparkWorldGateScene.instantiate() as MindSparkWorldGate
	source_gate.name = "MindSparkWorldGate"
	source_gate.position = MIND_GATE_POSITION
	source_gate.destination_world_local = MIND_WORLD_ONE_ORIGIN \
		+ world_one.get_zone_position("01_world_gate_landing") + Vector3(0, 7, 0)
	source_gate.prompt_text = "Q • ENTER WORLD ONE: MIND SPARK"
	add_child(source_gate)
	_build_world_one_causeway(world_one)


func _build_world_one_causeway(world_one: MindSparkWorldOne) -> void:
	## A physically walkable route from the Mind Spark district out to the
	## relocated World One landing, so the new land is reachable on foot and not
	## only through the world gate. The span crosses open void, so it is built as
	## a piered causeway resting on intermediate support islands rather than as a
	## single unsupported deck.
	if has_node("MindSparkWorldOneCauseway"):
		return
	var causeway := Node3D.new()
	causeway.name = "MindSparkWorldOneCauseway"
	add_child(causeway)
	var landing := MIND_WORLD_ONE_ORIGIN \
		+ world_one.get_zone_position("01_world_gate_landing")
	var flat_direction := Vector3(landing.x - MIND.x, 0.0, landing.z - MIND.z).normalized()
	# Start on the district rim and finish on the Zone 01 floor, both slightly
	# inside the islands so neither joint leaves a gap the player can fall through.
	var start: Vector3 = MIND + flat_direction * (MIND_DISTRICT_RADIUS - 8.0)
	start.y = CAUSEWAY_DECK_Y
	var finish: Vector3 = landing - flat_direction * 118.0
	finish.y = CAUSEWAY_DECK_Y
	var span := start.distance_to(finish)
	var segment_count := maxi(2, int(round(span / CAUSEWAY_SEGMENT_LENGTH)))
	# Support islands sit between segments and carry the piers of both neighbours.
	for index in range(1, segment_count):
		var pier_center: Vector3 = start.lerp(finish, float(index) / float(segment_count))
		_build_causeway_support_island(causeway, pier_center, index)
	for index in segment_count:
		var leg_start: Vector3 = start.lerp(finish, float(index) / float(segment_count))
		var leg_finish: Vector3 = start.lerp(finish, float(index + 1) / float(segment_count))
		_add_bridge_between(causeway, leg_start, leg_finish, CAUSEWAY_WIDTH)
	_add_landmark_label(causeway, "CAUSEWAY • WALK TO WORLD ONE: MIND SPARK",
		start + flat_direction * 40.0 + Vector3(0.0, 26.0, 0.0), Color("8df8ff"), 40)
	_add_landmark_label(causeway, "WORLD ONE • MIND SPARK LANDING",
		finish - flat_direction * 40.0 + Vector3(0.0, 26.0, 0.0), Color("bffbff"), 40)
	causeway.set_meta("span_metres", span)
	causeway.set_meta("segment_count", segment_count)
	causeway.set_meta("deck_y", CAUSEWAY_DECK_Y)
	causeway.set_meta("walk_start", start)
	causeway.set_meta("walk_finish", finish)


func _build_causeway_support_island(parent: Node3D, center: Vector3, index: int) -> void:
	var island := Node3D.new()
	island.name = "CausewaySupportIsland_%02d" % index
	parent.add_child(island)
	# The deck lands on top of the island, so the walk stays level across it.
	_build_island_foundation(island, center, CAUSEWAY_ISLAND_RADIUS, 44.0, 24)
	_add_cylinder(island, "RestPlaza", center + Vector3(0.0, 0.15, 0.0),
		CAUSEWAY_ISLAND_RADIUS * 0.66, 0.3, _materials.aqua_glass, false, 24)
	for lamp in 4:
		var angle := TAU * float(lamp) / 4.0
		_add_cylinder(island, "CausewayLamp_%02d" % lamp,
			center + Vector3(cos(angle) * CAUSEWAY_ISLAND_RADIUS * 0.72, 7.0,
				sin(angle) * CAUSEWAY_ISLAND_RADIUS * 0.72), 1.1, 14.0,
			_materials.aqua, false, 8)


func _build_world_one_walk_route() -> void:
	var route := Node3D.new()
	route.name = "WalkRouteToMindSparkWorldGate"
	add_child(route)
	var points := [
		Vector3(0, 1.95, 675),
		Vector3(0, 1.95, 975),
		Vector3(0, 1.95, 1422),
		Vector3(-105, 1.95, 1535),
		Vector3(-210, 1.95, 1640),
		Vector3(-430, 1.95, 1640),
		MIND_GATE_POSITION + Vector3.UP * 0.95,
	]
	for index in points.size() - 1:
		_add_walk_route_dots(route, points[index], points[index + 1], index)
	_add_landmark_label(route, "WORLD ONE • MIND SPARK  ←  WALK LEFT",
		Vector3(-92, 24, 1518), Color("8df8ff"), 42)
	_add_landmark_label(route, "MIND SPARK WORLD GATE • QUESTS BEYOND",
		Vector3(-430, 20, 1640), Color("bffbff"), 35)


func _add_walk_route_dots(parent: Node3D, start: Vector3, finish: Vector3, segment_index: int) -> void:
	var direction := finish - start
	var distance := direction.length()
	var count := maxi(1, int(distance / 18.0))
	var yaw := atan2(direction.x, direction.z)
	for dot_index in count + 1:
		var progress := float(dot_index) / float(count)
		_add_box(parent, "MindRoute_%02d_%02d" % [segment_index, dot_index], start.lerp(finish, progress),
			Vector3(7.5, 0.16, 2.2), _materials.aqua, false, yaw)


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
		# The Crown Line Mind station occupies the former (-920, 0, 1640) site.
		# Move this 112 m tower south with its own approach so its giant solid body
		# no longer passes through the station platform and crystal canopy.
		{"name": "WestObservatory", "center": Vector3(-920.0, 0.0, 1430.0),
			"source_center": MIND, "source_radius": MIND_DISTRICT_RADIUS},
		{"name": "NorthObservatory", "center": Vector3(0.0, 0.0, 2565.0),
			"source_center": HEART, "source_radius": 175.0},
		{"name": "EastObservatory", "center": Vector3(920.0, 0.0, 1640.0),
			"source_center": CREATOR, "source_radius": 195.0},
		{"name": "SouthObservatory", "center": Vector3(0.0, 0.0, 710.0),
			"source_center": SOUTH_GATE, "source_radius": 155.0},
	]
	for info in points:
		var lookout := Node3D.new()
		lookout.name = info.name
		add_child(lookout)
		var center: Vector3 = info.center
		_build_island_foundation(lookout, center, 70.0, 38.0, 20)
		_add_torus(lookout, "CompassRing", center + Vector3(0.0, 1.0, 0.0), 33.0, 38.0, _materials.gold)
		_build_tower(lookout, center, 34.0, 112.0, _materials.ivory)
		_add_exact_twin_island_bridges("%sBridge" % info.name,
			info.source_center, float(info.source_radius), center, 70.0)


func _add_exact_twin_island_bridges(base_name: String, source_center: Vector3,
		source_radius: float, target_center: Vector3, target_radius: float) -> void:
	# Two narrow decks mirror each other around the centre-to-centre axis. Their
	# endpoints are solved on inset circles, keeping the complete deck width over
	# land rather than leaving an outer corner suspended past a curved island rim.
	const BRIDGE_WIDTH := 16.0
	const LANE_OFFSET := 18.0
	const LANDING_OVERLAP := 2.0
	var direction := Vector3(
		target_center.x - source_center.x, 0.0,
		target_center.z - source_center.z).normalized()
	var side_axis := Vector3(direction.z, 0.0, -direction.x)
	var source_usable_radius := source_radius - LANDING_OVERLAP - BRIDGE_WIDTH * 0.5
	var target_usable_radius := target_radius - LANDING_OVERLAP - BRIDGE_WIDTH * 0.5
	var source_along := sqrt(source_usable_radius * source_usable_radius - LANE_OFFSET * LANE_OFFSET)
	var target_along := sqrt(target_usable_radius * target_usable_radius - LANE_OFFSET * LANE_OFFSET)
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var start: Vector3 = source_center + direction * source_along + side_axis * side * LANE_OFFSET
		var finish: Vector3 = target_center - direction * target_along + side_axis * side * LANE_OFFSET
		var bridge_name := base_name if side < 0.0 else "%sTwin" % base_name
		_add_bridge(bridge_name, start, finish, BRIDGE_WIDTH)
		var bridge := get_node(bridge_name) as Node3D
		bridge.set_meta("connection_start", start)
		bridge.set_meta("connection_finish", finish)
		bridge.set_meta("symmetry_side", int(side))
		bridge.set_meta("symmetry_offset", LANE_OFFSET)
		bridge.set_meta("walk_surface_y", source_center.y)


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
	var manifest := _load_tree_of_life_manifest()
	var source := manifest.get("source", {}) as Dictionary
	var game_export := manifest.get("game_export", {}) as Dictionary
	var design := manifest.get("design", {}) as Dictionary
	var tree := Node3D.new()
	tree.name = "TreeOfImagination"
	tree.position = center + Vector3.UP * TREE_OF_LIFE_COURT_SURFACE_Y
	tree.set_meta("architecture", "nature_magic_technology_engineering")
	tree.set_meta("blueprint_revision", manifest.get("blueprint_revision", ""))
	tree.set_meta("blueprint_references", manifest.get("blueprint_references", []))
	tree.set_meta("source_blend", "res://assets3D/tree_of_life/source/artea_tree_of_life.blend")
	tree.set_meta("source_named_modules", int(source.get("named_mesh_modules", 0)))
	tree.set_meta("source_editable_vertices", int(source.get("vertices", 0)))
	tree.set_meta("source_editable_mesh_elements", int(source.get("editable_mesh_elements", 0)))
	tree.set_meta("game_render_systems", int(game_export.get("mesh_nodes", 0)))
	tree.set_meta("player_clear_path_m",
		float(design.get("player_clear_path_m", TREE_OF_LIFE_CLEAR_PATH_M)) * TREE_OF_LIFE_GAME_SCALE)
	tree.set_meta("foundation_depth_m", float(design.get("foundation_depth_m", 0.0)))
	tree.set_meta("canopy_collision", false)
	tree.set_meta("landmark_scale_multiplier", TREE_OF_LIFE_SCALE_MULTIPLIER)
	tree.set_meta("entrance_world_direction", "south")
	tree.set_meta("entrance_alignment", "Art Gallery -> Art Castle Entrance Bridge -> SouthArrivalBridge -> root doorway")
	parent.add_child(tree)
	var visual := TreeOfLifeScene.instantiate() as Node3D
	visual.name = "BlenderTreeOfLifeVisual"
	visual.scale = Vector3.ONE * TREE_OF_LIFE_GAME_SCALE
	tree.add_child(visual)
	_build_tree_of_life_collision(tree, manifest)
	_build_reference_faithful_tree_canopy(tree, visual)

	# The imported cyan crystal-sap materials provide the visible glow. One local
	# light lets that heart illumination reach the surrounding roots at night.
	var heart_light := OmniLight3D.new()
	heart_light.name = "WisdomHeartLight"
	heart_light.position = Vector3(0.0, 20.0 * TREE_OF_LIFE_GAME_SCALE, 0.0)
	heart_light.light_color = Color("55e9ff")
	heart_light.light_energy = 5.4
	heart_light.omni_range = 64.0
	heart_light.shadow_enabled = false
	tree.add_child(heart_light)


func _build_reference_faithful_tree_canopy(tree: Node3D, legacy_visual: Node3D) -> void:
	# Keep the proven trunk, roots, foundation and traversal arch, but remove the
	# old low-poly foliage meshes so the new painted relief leaves remain readable.
	for mesh in legacy_visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh as MeshInstance3D
		if mesh_instance.name.begins_with("Foliage") \
				or mesh_instance.name.begins_with("Branches"):
			mesh_instance.visible = false
	var canopy := CrystalBranchCanopyScene.instantiate() as Node3D
	canopy.name = "ReferenceFaithfulCrystalCanopy"
	canopy.scale = Vector3.ONE * TREE_OF_LIFE_GAME_SCALE
	# Blender negative Y exports toward Godot positive Z. Rotate the assembly so
	# its authored doorway and powered road face world south, directly toward the
	# Art Gallery / Galaxy Wall bridge approach on the x=0 centerline.
	canopy.rotation.y = PI
	canopy.set_meta("construction", "blender_crystal_branch_canopy")
	canopy.set_meta("leaf_types", [
		"living_leaf_fan", "magic_rune_leaf",
		"solar_glass_science_leaf", "emerald_sensor_leaf",
	])
	canopy.set_meta("leaf_instances", 20000)
	canopy.set_meta("leaf_family_counts", {
		"living_leaf_fan": 7500,
		"magic_rune_leaf": 5000,
		"solar_glass_science_leaf": 5000,
		"emerald_sensor_leaf": 2500,
	})
	canopy.set_meta("leaf_cluster_width_range_m", Vector2(0.90, 4.20))
	canopy.set_meta("individual_leaflet_width_range_m", Vector2(0.22, 1.05))
	canopy.set_meta("canopy_diameter_m", 84.0 * TREE_OF_LIFE_GAME_SCALE)
	canopy.set_meta("root_foundation_diameter_m", 38.4 * TREE_OF_LIFE_GAME_SCALE)
	canopy.set_meta("faces_south_arrival_bridge", true)
	canopy.set_meta("major_limbs", 22)
	canopy.set_meta("secondary_twigs", 24)
	canopy.set_meta("foliage_branch_clusters", 159)
	canopy.set_meta("leaf_support_twigs", 1431)
	canopy.set_meta("leaf_support_cyan_channels", 159)
	canopy.set_meta("leaves_attached_to_support_twigs", true)
	canopy.set_meta("living_root_trunks", 12)
	canopy.set_meta("secondary_ground_roots", 12)
	canopy.set_meta("entrance_framing_roots", 2)
	canopy.set_meta("doorway_living_root_jambs", 2)
	canopy.set_meta("doorway_editable_joints", 8)
	canopy.set_meta("doorway_electric_fibers", 6)
	canopy.set_meta("doorway_metal_frame", false)
	canopy.set_meta("editable_primary_root_joints", 60)
	canopy.set_meta("editable_secondary_root_joints", 36)
	canopy.set_meta("secondary_root_cyan_inlays", 12)
	canopy.set_meta("powered_root_door_clear_width_m", 9.6 * TREE_OF_LIFE_GAME_SCALE)
	canopy.set_meta("powered_route_mesh_crossbars", 17)
	canopy.set_meta("powered_route_deck_plates", 12)
	canopy.set_meta("powered_route_cables", 2)
	canopy.set_meta("root_radial_power_feeders", 6)
	canopy.set_meta("floating_root_relays", 8)
	canopy.set_meta("root_cyan_tributaries", 24)
	canopy.set_meta("root_mechanical_clamp_sets", 7)
	canopy.set_meta("cyan_energy_channels", 46)
	canopy.set_meta("brass_articulation_collars", 70)
	canopy.set_meta("collision_included", false)
	tree.add_child(canopy)
	_batch_canopy_leaf_families(canopy)

	var canopy_light := OmniLight3D.new()
	canopy_light.name = "CrystalCanopyEnergyLight"
	canopy_light.position = Vector3(0.0, 28.5 * TREE_OF_LIFE_GAME_SCALE, 0.0)
	canopy_light.light_color = Color("43ddff")
	canopy_light.light_energy = 7.2
	canopy_light.omni_range = 76.0
	canopy_light.shadow_enabled = false
	tree.add_child(canopy_light)
	_build_powered_living_bough_canopy(tree, canopy)


func _build_powered_living_bough_canopy(tree: Node3D, previous_canopy: Node3D) -> void:
	# Preserve the production roots, doorway and crystal heart, while replacing
	# the older radial foliage layer with authored gravity-bough modules.
	var flow_material := _create_powered_bough_flow_material()
	var powered_root_fiber_meshes := 0
	for mesh_node in previous_canopy.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		if mesh.name.begins_with("BioTechBranch_") \
				or mesh.name.begins_with("CyanSapChannel_") \
				or mesh.name.begins_with("BrassArticulationCollar_") \
				or mesh.name.begins_with("LeafSupportTwig_") \
				or mesh.name.begins_with("LeafSupportCyanChannel_"):
			mesh.visible = false
		if mesh.name.begins_with("RootCyanSapInlay_") \
				or mesh.name.begins_with("SecondaryRootCyanInlay_") \
				or mesh.name.begins_with("RootRadialPowerFeeder_") \
				or mesh.name.begins_with("RootCyanTributary_") \
				or mesh.name.begins_with("DoorwayElectricFiber_"):
			mesh.material_override = flow_material
			powered_root_fiber_meshes += 1
	for old_batch_node in previous_canopy.find_children(
			"CanopyLeafBatch_*", "MultiMeshInstance3D", true, false):
		(old_batch_node as MultiMeshInstance3D).visible = false

	var canopy := Node3D.new()
	canopy.name = "PoweredLivingBoughCanopy"
	canopy.set_meta("construction", "godot_layered_gravity_bough_modules")
	canopy.set_meta("module_source", "res://assets3D/tree_of_life/gravity_leaf_bough/glb/gravity_leaf_bough_runtime.glb")
	canopy.set_meta("root_skirt_boughs", 10)
	canopy.set_meta("lower_tier_boughs", 10)
	canopy.set_meta("middle_lower_boughs", 9)
	canopy.set_meta("middle_upper_boughs", 8)
	canopy.set_meta("upper_tier_boughs", 6)
	canopy.set_meta("crown_boughs", 5)
	canopy.set_meta("base_bough_clusters", 48)
	canopy.set_meta("growth_boughs_per_cluster", 10)
	canopy.set_meta("powered_bough_instances", 480)
	canopy.set_meta("source_compound_leaf_sockets", 622080)
	canopy.set_meta("compound_leaf_instances", 1244160)
	canopy.set_meta("leaf_transfer_nodes", 1244160)
	canopy.set_meta("foliage_layers_per_socket", 2)
	canopy.set_meta("runtime_leaf_scale", 1.18)
	canopy.set_meta("main_flow_streaks_removed", true)
	canopy.set_meta("leaf_twig_streaks_removed", true)
	canopy.set_meta("lateral_streaks_removed", true)
	canopy.set_meta("lateral_sap_streaks_removed", true)
	canopy.set_meta("visible_branch_energy", "three_strand_main_biofiber_braid")
	canopy.set_meta("floating_crystal_transfer_nodes_preserved", true)
	canopy.set_meta("powered_root_fiber_meshes", powered_root_fiber_meshes)
	canopy.set_meta("root_to_leaf_energy_continuity", true)
	canopy.set_meta("living_tree_silhouette", "six_irregular_root_to_crown_branch_layers")
	canopy.set_meta("canopy_collision", false)
	tree.add_child(canopy)

	var module_transforms: Array[Transform3D] = []
	var cluster_index := 0
	for tier_spec in [
		{"count": 10, "height": 37.0, "radius": 9.2, "scale": 3.02, "pitch": 3.0, "phase": 0.11},
		{"count": 10, "height": 51.0, "radius": 8.0, "scale": 2.86, "pitch": 10.0, "phase": 0.43},
		{"count": 9, "height": 65.0, "radius": 6.8, "scale": 2.58, "pitch": 18.0, "phase": 0.20},
		{"count": 8, "height": 78.0, "radius": 5.5, "scale": 2.29, "pitch": 28.0, "phase": 0.59},
		# Keep crown foliage face-readable. Steeper angles turn the emissive leaf
		# veins into unexplained horizontal lines when the leaf surface is edge-on.
		{"count": 6, "height": 84.0, "radius": 4.2, "scale": 1.15, "pitch": 21.0, "phase": 0.31},
		{"count": 5, "height": 92.0, "radius": 3.0, "scale": 0.75, "pitch": 24.0, "phase": 0.72},
	]:
		var count := int(tier_spec.count)
		for tier_index in count:
			var irregularity := sin(float(tier_index) * 2.17 + float(cluster_index) * 0.43)
			var yaw := TAU * float(tier_index) / float(count) + float(tier_spec.phase)
			yaw += irregularity * 0.095
			var cluster_root := Vector3(
				cos(yaw) * (float(tier_spec.radius) + irregularity * 0.65),
				float(tier_spec.height) + irregularity * 2.2,
				sin(yaw) * (float(tier_spec.radius) + irregularity * 0.65))
			var radial := Vector3(cos(yaw), 0.0, sin(yaw))
			var tangent := Vector3(-sin(yaw), 0.0, cos(yaw))
			for growth_index in 10:
				var growth_phase := TAU * float(growth_index) / 10.0
				var growth_noise := sin(float(cluster_index * 10 + growth_index) * 1.731)
				var root_target := cluster_root \
					+ tangent * cos(growth_phase) * (3.8 + float(growth_index % 3)) \
					+ radial * sin(growth_phase) * (2.4 + float(growth_index % 2)) \
					+ Vector3.UP * sin(growth_phase * 2.0) * 3.1
				var growth_yaw := yaw + sin(growth_phase) * 0.24 + growth_noise * 0.035
				var local_roll := deg_to_rad(irregularity * 5.5 + cos(growth_phase) * 8.0)
				var upward_pitch := deg_to_rad(
					float(tier_spec.pitch) + irregularity * 4.5 + sin(growth_phase * 1.7) * 7.0)
				var module_scale := float(tier_spec.scale) \
					* (0.56 + 0.08 * sin(growth_phase + irregularity))
				var orientation := Basis(Vector3.UP, growth_yaw) \
					* Basis(Vector3.BACK, upward_pitch) \
					* Basis(Vector3.RIGHT, local_roll)
				var scaled_basis := orientation.scaled(Vector3.ONE * module_scale)
				var authored_root_socket := Vector3(-18.0, 1.0, 0.0)
				module_transforms.append(Transform3D(
					scaled_basis, root_target - scaled_basis * authored_root_socket))
			cluster_index += 1
	_batch_powered_bough_canopy(canopy, module_transforms, flow_material)

	# A restrained canopy light supports the emissive shader without flattening
	# the green, violet, blue-glass and emerald leaf materials.
	var flow_light := OmniLight3D.new()
	flow_light.name = "PoweredBoughFlowLight"
	flow_light.position = Vector3(0.0, 61.0, 0.0)
	flow_light.light_color = Color("32cfff")
	flow_light.light_energy = 2.8
	flow_light.omni_range = 150.0
	flow_light.shadow_enabled = false
	canopy.add_child(flow_light)


func _node_transform_relative_to(node: Node3D, ancestor_root: Node3D) -> Transform3D:
	var relative_transform := node.transform
	var ancestor := node.get_parent()
	while ancestor != null and ancestor != ancestor_root:
		if ancestor is Node3D:
			relative_transform = (ancestor as Node3D).transform * relative_transform
		ancestor = ancestor.get_parent()
	return relative_transform


func _batch_powered_bough_canopy(
		parent: Node3D, module_transforms: Array[Transform3D],
		flow_material: ShaderMaterial) -> void:
	# The compact Blender runtime source contains one joined living-wood branch,
	# one joined biofiber network, four linked leaf meshes and crystal transfer
	# nodes.  Combining all 480 smaller bough placements into seven MultiMeshes
	# gives the requested tenfold population without 480 heavy scene hierarchies.
	var template := PoweredGravityBoughScene.instantiate() as Node3D
	_batch_powered_bough_meshes(
		parent, template, "GravityBough_CombinedStructure*",
		"PoweredBranchStructureBatch", module_transforms, null, 1, 1.0)
	_batch_powered_bough_meshes(
		parent, template, "Biofiber_CombinedFlow*",
		"PoweredBranchBiofiberBatch", module_transforms, flow_material, 1, 1.0)
	for family in [
		"living_leaf_fan", "magic_rune_leaf",
		"solar_glass_science_leaf", "emerald_sensor_leaf",
	]:
		_batch_powered_bough_meshes(
			parent, template, "GravityBough_SocketLeaf_%s_*" % family,
			"PoweredLeafBatch_%s" % family, module_transforms, null, 2, 1.18)
	_batch_powered_bough_meshes(
		parent, template, "Biofiber_LeafTransferNode_*",
		"PoweredLeafTransferNodeBatch", module_transforms, flow_material, 2, 0.78)
	# Biofiber_MainFlowPulse geometry intentionally is not batched. Those pulses
	# were the unexplained horizontal white/cyan streaks above the crown. Floating
	# crystal transfer nodes remain in their dedicated batch.
	template.free()


func _batch_powered_bough_meshes(
		parent: Node3D, template: Node3D, pattern: String, batch_name: String,
		module_transforms: Array[Transform3D], material_override: Material,
		growth_layers: int, local_scale: float) -> void:
	var meshes := template.find_children(pattern, "MeshInstance3D", true, false)
	if meshes.is_empty():
		push_warning("Powered bough runtime pattern has no meshes: %s" % pattern)
		return
	var first_mesh := meshes[0] as MeshInstance3D
	var source_transforms: Array[Transform3D] = []
	for mesh_node in meshes:
		source_transforms.append(_node_transform_relative_to(
			mesh_node as Node3D, template))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = first_mesh.mesh
	var source_count := source_transforms.size()
	multimesh.instance_count = module_transforms.size() * source_count * growth_layers
	var output_index := 0
	for module_index in module_transforms.size():
		var module_transform := module_transforms[module_index]
		for layer_index in growth_layers:
			for source_index in source_count:
				var local_transform := source_transforms[source_index]
				var stagger := -1.0 if (source_index + module_index) % 2 == 0 else 1.0
				if batch_name.begins_with("PoweredLeafBatch_") and module_index >= 370:
					# Upper compound leaves otherwise become edge-on glowing veins from
					# elevation views. Preserve the socket and tilt only the leaf face.
					local_transform.basis = local_transform.basis.rotated(
						Vector3.RIGHT, deg_to_rad(34.0 + stagger * 7.0))
				if growth_layers > 1:
					local_transform.basis = local_transform.basis.scaled(
						Vector3.ONE * local_scale)
				if layer_index > 0:
					local_transform.origin += Vector3(
						stagger * (0.16 + float(source_index % 3) * 0.045),
						0.20 + float(source_index % 5) * 0.025,
						-stagger * (0.13 + float(source_index % 4) * 0.035))
					local_transform.basis = local_transform.basis \
						.rotated(Vector3.UP, stagger * deg_to_rad(6.5)) \
						.scaled(Vector3.ONE * 0.94)
				multimesh.set_instance_transform(
					output_index, module_transform * local_transform)
				output_index += 1
	var batch := MultiMeshInstance3D.new()
	batch.name = batch_name
	batch.multimesh = multimesh
	batch.material_override = material_override
	batch.set_meta("source_meshes", source_count)
	batch.set_meta("module_instances", module_transforms.size())
	batch.set_meta("growth_layers", growth_layers)
	parent.add_child(batch)


func _create_powered_bough_flow_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
varying float flow_coordinate;
void vertex() {
	flow_coordinate = VERTEX.x + VERTEX.y * 0.42 + VERTEX.z * 0.71;
}
void fragment() {
	float wave = 0.5 + 0.5 * sin(flow_coordinate * 2.4 - TIME * 5.6);
	float filament = smoothstep(0.28, 0.92, wave);
	vec3 cyan = mix(vec3(0.005, 0.18, 0.48), vec3(0.18, 0.92, 1.0), filament);
	ALBEDO = cyan * 0.34;
	EMISSION = cyan * (1.35 + filament * 3.2);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _batch_canopy_leaf_families(canopy: Node3D) -> void:
	# The Blender source retains all 20,000 linked leaf objects for individual
	# editing. Runtime replaces those nodes with four MultiMeshes, preserving
	# every authored transform while reducing the crown to four foliage draws.
	var family_names := [
		"living_leaf_fan", "magic_rune_leaf",
		"solar_glass_science_leaf", "emerald_sensor_leaf",
	]
	var total_instances := 0
	for family_name in family_names:
		var leaves := canopy.find_children(
			"CanopyLeaf_%s_*" % family_name, "MeshInstance3D", true, false)
		if leaves.is_empty():
			continue
		var first_leaf := leaves[0] as MeshInstance3D
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = first_leaf.mesh
		multimesh.instance_count = leaves.size()
		for index in leaves.size():
			var leaf := leaves[index] as MeshInstance3D
			var relative_transform := leaf.transform
			var ancestor := leaf.get_parent()
			while ancestor != null and ancestor != canopy:
				if ancestor is Node3D:
					relative_transform = (ancestor as Node3D).transform * relative_transform
				ancestor = ancestor.get_parent()
			multimesh.set_instance_transform(index, relative_transform)
		var batch := MultiMeshInstance3D.new()
		batch.name = "CanopyLeafBatch_%s" % family_name
		batch.multimesh = multimesh
		batch.set_meta("leaf_family", family_name)
		batch.set_meta("leaf_instances", leaves.size())
		canopy.add_child(batch)
		total_instances += leaves.size()
		for leaf in leaves:
			var leaf_node := leaf as MeshInstance3D
			leaf_node.get_parent().remove_child(leaf_node)
			leaf_node.queue_free()
	canopy.set_meta("runtime_leaf_batches", family_names.size())
	canopy.set_meta("runtime_batched_leaf_instances", total_instances)


func _load_tree_of_life_manifest() -> Dictionary:
	if not FileAccess.file_exists(TREE_OF_LIFE_MANIFEST_PATH):
		return {}
	var file := FileAccess.open(TREE_OF_LIFE_MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _build_tree_of_life_collision(tree: Node3D, manifest: Dictionary) -> void:
	# The 172k-vertex Blender mesh is visual-only. Authored manifest primitives
	# approximate the load-bearing trunk and low roots without turning thousands
	# of leaves into expensive collision. The centerline remains a continuous
	# south-to-north arch wider than the production player capsule.
	var collision_root := Node3D.new()
	collision_root.name = "TreeOfLifeCollisionProxies"
	collision_root.set_meta("proxy_system", "low_cost_authored_primitives")
	collision_root.set_meta("clear_path_axis", "local_z")
	var policy := manifest.get("collision_policy", {}) as Dictionary
	var collision_scale := TREE_OF_LIFE_GAME_SCALE if bool(policy.get("scale_with_visual", true)) else 1.0
	collision_root.set_meta("minimum_clear_width_m", TREE_OF_LIFE_CLEAR_PATH_M * collision_scale)
	collision_root.set_meta("collision_scale", collision_scale)
	tree.add_child(collision_root)

	var trunk_specs := policy.get("trunk_pillars", []) as Array
	for value in trunk_specs:
		var spec := value as Dictionary
		var trunk_body := StaticBody3D.new()
		trunk_body.name = String(spec.get("name", "TrunkPillar"))
		trunk_body.position = Vector3(
			float(spec.get("x_m", 0.0)) * collision_scale,
			float(spec.get("y_m", 13.5)) * collision_scale,
			0.0)
		trunk_body.set_meta("tree_collision_role", "load_bearing_trunk")
		var trunk_shape_node := CollisionShape3D.new()
		var trunk_shape := CylinderShape3D.new()
		trunk_shape.radius = float(spec.get("radius_m", 3.25)) * collision_scale
		trunk_shape.height = float(spec.get("height_m", 27.0)) * collision_scale
		trunk_shape_node.shape = trunk_shape
		trunk_body.add_child(trunk_shape_node)
		collision_root.add_child(trunk_body)

	var root_specs := policy.get("root_proxies", []) as Array
	for value in root_specs:
		var spec := value as Dictionary
		var blender_xy := spec.get("position_blender_xy_m", [0.0, 0.0]) as Array
		var size_values := spec.get("size_m", [3.3, 3.0, 16.0]) as Array
		var root_body := StaticBody3D.new()
		root_body.name = String(spec.get("name", "LowRootProxy"))
		# Blender local Y becomes Godot local -Z through the glTF Y-up export.
		root_body.position = Vector3(
			float(blender_xy[0]) * collision_scale,
			float(size_values[1]) * collision_scale * 0.5,
			-float(blender_xy[1]) * collision_scale)
		root_body.rotation.y = deg_to_rad(float(spec.get("yaw_godot_deg", 0.0)))
		root_body.set_meta("tree_collision_role", "low_root")
		var root_shape_node := CollisionShape3D.new()
		var root_shape := BoxShape3D.new()
		root_shape.size = Vector3(
			float(size_values[0]), float(size_values[1]), float(size_values[2])) * collision_scale
		root_shape_node.shape = root_shape
		root_body.add_child(root_shape_node)
		collision_root.add_child(root_body)


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
		material: Material, collision_enabled: bool = false, yaw: float = 0.0,
		friction: float = 0.86, bounce: float = 0.0) -> MeshInstance3D:
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
		body.name = "%sCollision" % node_name
		var physics_material := PhysicsMaterial.new()
		physics_material.friction = friction
		physics_material.bounce = bounce
		body.physics_material_override = physics_material
		body.set_meta("mass_class", "infinite_static_mass")
		body.set_meta("friction", friction)
		body.set_meta("bounce", bounce)
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


func _make_textured_material(base: Color, panel: Color, circuit: Color,
		roughness: float, cell_size: int) -> StandardMaterial3D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var on_joint := x % cell_size <= 1 or y % cell_size <= 1
			var on_circuit := (x % (cell_size * 2) == cell_size / 2 and y % cell_size > 3) \
				or (y % (cell_size * 2) == cell_size / 2 and x % cell_size > 3)
			image.set_pixel(x, y, circuit if on_circuit else (panel if on_joint else base))
	var texture := ImageTexture.create_from_image(image)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = texture
	material.roughness = roughness
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.uv1_scale = Vector3(3.0, 3.0, 3.0)
	return material
