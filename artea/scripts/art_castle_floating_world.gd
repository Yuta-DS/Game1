extends Node3D

const MindSparkWorldGateScene := preload("res://scenes/mind_spark/world_gate.tscn")
const TreeOfLifeScene := preload("res://assets3D/tree_of_life/glb/artea_tree_of_life.glb")
const BlueprintTrunkRootScene := preload(
	"res://assets3D/tree_of_life/trunk_core/glb/simple_trunk_core.glb")
const BlenderHeartCrystalScene := preload(
	"res://assets3D/tree_of_life/heart_crystal/glb/realistic_heart_crystal.glb")
const CrystalBranchCanopyScene := preload("res://assets3D/tree_of_life/canopy/glb/crystal_branch_canopy.glb")
const PoweredGravityBoughScene := preload("res://assets3D/tree_of_life/gravity_leaf_bough/glb/gravity_leaf_bough_runtime.glb")
const CastleGalaxyBridgeGateScene := preload("res://assets3D/castle_galaxy_bridge/glb/castle_galaxy_bridge_gate.glb")
const TreeProcessionalBridgeScene := preload(
	"res://assets3D/tree_processional_bridge/glb/tree_processional_bridge.glb")
const FacetedPodLeafStyle := preload(
	"res://scripts/tree_of_life/leaf_style_faceted_pod.gd")
const BlossomBudClusterLeafStyle := preload(
	"res://scripts/tree_of_life/leaf_style_blossom_bud_cluster.gd")
const GravityLeafReliefStyle := preload(
	"res://scripts/tree_of_life/leaf_style_gravity_leaf_relief.gd")
const TREE_CHRISTMAS_MELODY := preload(
	"res://assets/audio/tree_of_life_christmas_ambience.wav")
const TREE_CHRISTMAS_BELLS := preload("res://assets/SFX/fairy dust.ogg")
const TREE_OF_LIFE_MANIFEST_PATH := "res://assets3D/tree_of_life/tree_of_life_manifest.json"

@export var embedded_in_gallery := false

# The playable Art Castle Galaxy: a 2 km x 2 km connected floating world based
# on the supplied concept image. Geometry is generated from shared materials at
# runtime so the authored scene stays reviewable and the world can be tuned as
# one coherent layout.

const WORLD_HALF_EXTENT := 1000.0
const PLAYER_SPAWN := Vector3(0.0, 4.0, 790.0)
const HUB := Vector3(0.0, 0.0, 1640.0)
const TREE_OF_LIFE_GAME_SCALE := 4.20
# The bough canopy, ornaments and shrine were authored against this scale, so
# everything built in tree-local units is multiplied by the ratio between the
# two instead of being re-tuned whenever the body size changes.
const TREE_OF_LIFE_AUTHORED_SCALE := 3.30
const TREE_OF_LIFE_BODY_RATIO := TREE_OF_LIFE_GAME_SCALE / TREE_OF_LIFE_AUTHORED_SCALE
# The original authored trunk/root silhouette remains recognizable, but its
# radial envelope is widened enough to swallow the attachment depth of the
# brass engineering layer. Scaling only X/Z preserves the authored height and
# keeps the south passage centred and open.
const ORIGINAL_TRUNK_RADIAL_SCALE := 1.18
const ORIGINAL_ROOT_RADIAL_SCALE := 1.14
const ORIGINAL_CANOPY_BASE_SCALE := 1.28
const ORIGINAL_CANOPY_TIP_SCALE := 0.34
const ORIGINAL_CANOPY_HEIGHT_SCALE := 1.62
const TREE_OF_LIFE_SCALE_MULTIPLIER := 2.0
# Retained only by the standalone trunk-core asset validator. The runtime tree
# no longer instantiates that replacement core.
const SIMPLE_TRUNK_HEIGHT_M := 18.0
const SIMPLE_TRUNK_ROOT_DIAMETER_M := 14.4
const SIMPLE_TRUNK_DOOR_WIDTH_M := 3.0
const SIMPLE_TRUNK_DOOR_HEIGHT_M := 4.2

# Web LOD for the Tree of Life.
#
# The authored canopy is 480 bough modules x 1,296 compound leaf sockets x 2
# growth layers = 1,244,160 leaf instances, and each "leaf" is a 6,336 triangle
# compound cluster. That is 7.9 billion triangles in four MultiMesh draws, none
# of which cull, because each batch's AABB covers the whole crown. A wasm32
# build has neither the memory nor the vertex throughput for it.
#
# On Web the same silhouette is rebuilt from fewer modules, every third leaf
# socket, one growth layer, and a flat card in place of each compound cluster.
const BOUGH_GROWTH_PER_CLUSTER := 10
# Boughs are authored along their local X axis (their root socket sits at
# x=-18), so stretching that axis alone makes a branch reach further without
# also making it thicker. Tiers carry their own "length" so the crown spire can
# reach while the established lower canopy keeps its authored proportions.
const BOUGH_DEFAULT_LENGTH := 1.0
const WEB_BOUGH_GROWTH_PER_CLUSTER := 2
const WEB_LEAF_SOCKET_STRIDE := 3
const WEB_LEAF_GROWTH_LAYERS := 1
# Above this triangle count a leaf is replaced by a card carrying its material.
const WEB_LEAF_CARD_TRIANGLE_LIMIT := 64
const LAPTOP_TREE_LEAF_SOCKET_STRIDE := 4
const LAPTOP_TREE_CHILD_BOUGHS_PER_MAJOR := 2
const TREE_BLUEPRINT_WORLD_SCALE := 186.0 / 48.0
const TREE_BLUEPRINT_TOTAL_HEIGHT := 128.0 * TREE_BLUEPRINT_WORLD_SCALE
const TREE_BLUEPRINT_BODY_HEIGHT := 48.0 * TREE_BLUEPRINT_WORLD_SCALE
const TREE_BLUEPRINT_ROOT_RADIUS := 18.0 * TREE_BLUEPRINT_WORLD_SCALE
const TREE_BLUEPRINT_CANOPY_RADIUS := 42.0 * TREE_BLUEPRINT_WORLD_SCALE
const TREE_BLUEPRINT_DOOR_WIDTH := 6.0 * TREE_BLUEPRINT_WORLD_SCALE
const TREE_BLUEPRINT_DOOR_HEIGHT := 8.0 * TREE_BLUEPRINT_WORLD_SCALE
const TREE_BLUEPRINT_HEART_HEIGHT := 14.0 * TREE_BLUEPRINT_WORLD_SCALE
const TREE_BLUEPRINT_ORIGINAL_CROWN_HEIGHT := 60.0 * TREE_BLUEPRINT_WORLD_SCALE
const TREE_BLUEPRINT_CROWN_HEIGHT := 120.0 * TREE_BLUEPRINT_WORLD_SCALE
const TREE_BLUEPRINT_STAR_HEIGHT := 124.0 * TREE_BLUEPRINT_WORLD_SCALE
const TREE_BLUEPRINT_PRIMARY_BOUGHS := 195
const TREE_BLUEPRINT_CHILD_BOUGHS := 390
const TREE_BLUEPRINT_TWIG_FANS := 4680
const TREE_BLUEPRINT_LEAVES := 37440


static func _use_web_lod() -> bool:
	# The environment override lets the cost measurement and the regression test
	# exercise the Web path from a desktop headless run.
	return OS.has_feature("web") or OS.get_environment("ARTEA_FORCE_WEB_LOD") == "1"

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
var _tree_christmas_melody: AudioStreamPlayer3D
var _tree_christmas_bells: AudioStreamPlayer3D

const TREE_CHRISTMAS_FULL_VOLUME_DISTANCE := 70.0
const TREE_CHRISTMAS_SILENT_DISTANCE := 620.0
const TREE_CHRISTMAS_NEAR_VOLUME_DB := -5.0
const TREE_CHRISTMAS_SILENT_VOLUME_DB := -80.0
const TREE_CHRISTMAS_FADE_IN_SPEED := 1.60
const TREE_CHRISTMAS_FADE_OUT_SPEED := 0.28


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
	_build_heart_melody_island_one()
	_build_world_one_walk_route()
	_build_boundary_observatories()
	_build_skyline()
	_build_cloud_banks()
	_build_world_labels()
	if not embedded_in_gallery:
		_build_standalone_minimap()
		_build_return_gate()


func _build_heart_melody_island_one() -> void:
	if has_node("HeartMelodyWorld"):
		return
	var scene := load("res://scenes/heart_melody/heart_garden_world.tscn") as PackedScene
	var heart := scene.instantiate() as Node3D
	heart.name = "HeartMelodyWorld"
	heart.position = Vector3(6000, 0, 2290)
	heart.set("defer_build", true)
	add_child(heart)
	var gate := MindSparkWorldGateScene.instantiate() as MindSparkWorldGate
	gate.name = "HeartMelodyWorldGate"
	gate.position = HEART + Vector3(-95, 4, 10)
	gate.target_world_path = NodePath("../HeartMelodyWorld")
	gate.destination_world_local = heart.position + HeartGardenWorld.ARRIVAL
	gate.prompt_text = "Q • ENTER HEART MELODY: FEELING GARDEN"
	add_child(gate)
	heart.connect("return_requested", func():
		var body = heart.get("player") as CharacterBody3D
		if body != null:
			body.global_position = to_global(HEART + Vector3(-83, 6, 10))
			body.velocity = Vector3.ZERO)
	var journey := get_node_or_null("/root/JourneyState")
	if journey != null:
		gate.set_gate_enabled(journey.has_treasure("star_of_wisdom") or journey.has_treasure("harmony_jewel"))
		journey.treasure_awarded.connect(func(_id: String):
			gate.set_gate_enabled(journey.has_treasure("star_of_wisdom") or journey.has_treasure("harmony_jewel")))


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
	_update_tree_christmas_ambience(delta)


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
	_materials.passage_stone = _make_material(Color("ded9cc"), 0.90)
	_materials.passage_stone_shadow = _make_material(Color("a9a79f"), 0.94)
	_materials.passage_iron = _make_material(Color("3e4854"), 0.72)
	_materials.passage_roof = _make_material(Color("344c64"), 0.66)
	_materials.passage_bronze = _make_material(Color("aa8249"), 0.54)
	_materials.passage_light = _make_glow(Color("65e6ef"), 0.82)


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
	# Give the enlarged Blender gate a clean silhouette. The former z=715 frame
	# sat only 52 m behind its facade and visually collapsed into it. Placing the
	# frame at the island centre creates a measured 157 m gate-to-wall setback
	# without changing the arrival promenade or the playable route.
	_build_frame(island, Vector3(0.0, 0.0, 820.0), 48.0, 62.0, _materials.gold, "ART CASTLE GALAXY")
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
	bridge.name = "CastleToGalaxyBridge175m"
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
	bridge.set_meta("route_role", "walkable_castle_to_galaxy_transition")
	bridge.set_meta("visual_progression", "reference_masonry_gate_to_galaxy_light")
	_build_castle_to_galaxy_reference_bridge(bridge, start, finish, 16.0)
	_add_landmark_label(bridge, "CASTLE • GALAXY PASSAGE", Vector3(0.0, 24.0, 615.0), Color("fff0b0"), 34)
	_build_approach_fall_recovery(bridge, start, finish)


func _build_castle_to_galaxy_reference_bridge(parent: Node3D, start: Vector3,
		finish: Vector3, width: float) -> void:
	# The Blender source owns every visible construction module. The original
	# continuous deck and guard collision remain the authoritative safe route, so
	# detailed masonry cannot introduce player snags or Web physics regressions.
	var direction := finish - start
	var length := direction.length()
	var yaw := atan2(direction.x, direction.z)
	_hide_generic_passage_visuals(parent)
	var asset_holder := Node3D.new()
	asset_holder.name = "ReferenceFrontGate"
	# The paver top sits at Blender z=0.24. This offset places it at Godot y=0.74,
	# 14 cm above the collision deck, avoiding coplanar z-fighting while remaining
	# far below the player's step threshold.
	asset_holder.position = start + Vector3.UP * 0.50
	# Blender +Y imports on Godot -Z. Turn the complete route once so its 170 m
	# authored axis lands exactly on this bridge's +Z gallery-to-island axis.
	asset_holder.rotation.y = yaw + PI
	asset_holder.set_meta("source_blend",
		"res://assets3D/castle_galaxy_bridge/blend/castle_galaxy_bridge_gate.blend")
	asset_holder.set_meta("source_glb",
		"res://assets3D/castle_galaxy_bridge/glb/castle_galaxy_bridge_gate.glb")
	asset_holder.set_meta("clear_opening_width_m", 14.8)
	asset_holder.set_meta("gate_outer_width_m", 42.0)
	asset_holder.set_meta("gate_finial_height_m", 52.0)
	asset_holder.set_meta("rear_wall_setback_m", 157.0)
	asset_holder.set_meta("collision_policy", "visual_only_over_tested_procedural_route")
	parent.add_child(asset_holder)
	var blender_asset := CastleGalaxyBridgeGateScene.instantiate() as Node3D
	if blender_asset != null:
		blender_asset.name = "BlenderCastleGalaxyBridgeGate"
		asset_holder.add_child(blender_asset)
	parent.set_meta("reference", "user_supplied_bridge_gate_image")
	parent.set_meta("blender_editable_module_count", 1437)
	parent.set_meta("blender_runtime_mesh_group_count", 13)
	parent.set_meta("bridge_performance_profile", "laptop_cpu_low")
	parent.set_meta("bridge_runtime_triangle_count", 61036)
	parent.set_meta("bridge_triangle_reduction_percent", 69.5)
	parent.set_meta("underside_arch_span_count", 3)
	parent.set_meta("front_gate_tower_count", 2)
	parent.set_meta("clear_gate_width_m", 14.8)
	parent.set_meta("reference_bridge_length_m", length)


func _hide_generic_passage_visuals(parent: Node3D) -> void:
	for pattern in ["DeckPlate_*", "AntiSlipJoint_*", "RainbowPathMarker*",
			"GuardGlass*", "GuardPost*", "TopRail*"]:
		for candidate in parent.find_children(pattern, "MeshInstance3D", true, false):
			(candidate as MeshInstance3D).visible = false


func _build_reference_paving(parent: Node3D, start: Vector3, finish: Vector3,
		width: float, yaw: float) -> void:
	for slab_index in 17:
		var progress := (float(slab_index) + 0.5) / 17.0
		var slab := _add_box(parent, "GateBridgePavingSlab_%02d" % (slab_index + 1),
			start.lerp(finish, progress) + Vector3.UP * 0.74,
			Vector3(width - 0.8, 0.18, 9.55), _materials.passage_stone, false, yaw)
		slab.set_meta("module", "large_limestone_paver")
		_add_box(parent, "PavingJoint_%02d" % (slab_index + 1),
			start.lerp(finish, float(slab_index + 1) / 17.0) + Vector3.UP * 0.85,
			Vector3(width - 1.2, 0.035, 0.16), _materials.passage_stone_shadow, false, yaw)
	var centre := start.lerp(finish, 0.5) + Vector3.UP * 0.86
	_add_box(parent, "CyanRouteInlay", centre, Vector3(0.18, 0.05,
		start.distance_to(finish) - 3.0), _materials.passage_light, false, yaw)


func _build_reference_fascia_and_arches(parent: Node3D, start: Vector3,
		finish: Vector3, width: float, side_axis: Vector3) -> void:
	var direction := (finish - start).normalized()
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		for course in 2:
			for block_index in 34:
				var progress := (float(block_index) + 0.5) / 34.0
				var offset := direction * (2.4 / 34.0) if (block_index + course) % 2 == 0 \
					else Vector3.ZERO
				var block := _add_box(parent,
					"BridgeFasciaBlock_%s_%d_%02d" % ["L" if side < 0 else "R", course, block_index],
					start.lerp(finish, progress) + side_axis * side * (width * 0.5 - 0.15) \
						+ Vector3.DOWN * (0.15 + float(course) * 0.72) + offset,
					Vector3(0.72, 0.64, 4.62),
					_materials.passage_stone if course == 0 else _materials.passage_stone_shadow,
					false)
				block.basis = Basis.looking_at(direction, Vector3.UP)
		for arch_index in 3:
			var span_start := start.lerp(finish, float(arch_index) / 3.0)
			var span_finish := start.lerp(finish, float(arch_index + 1) / 3.0)
			_build_reference_arch_rib(parent, span_start, span_finish,
				side_axis * side * (width * 0.5 + 0.18), arch_index, side)


func _build_reference_arch_rib(parent: Node3D, span_start: Vector3,
		span_finish: Vector3, side_offset: Vector3, arch_index: int, side: float) -> void:
	var previous := span_start + side_offset + Vector3.DOWN * 7.2
	for segment_index in 8:
		var t := float(segment_index + 1) / 8.0
		var point := span_start.lerp(span_finish, t) + side_offset \
			+ Vector3.UP * (-7.2 + sin(t * PI) * 5.65)
		var rib := _add_reference_beam(parent, previous, point, 0.52,
			_materials.passage_iron)
		rib.name = "UnderBridgeArch_%s_%d_%02d" % ["L" if side < 0 else "R",
			arch_index + 1, segment_index + 1]
		previous = point


func _build_reference_balustrades(parent: Node3D, start: Vector3,
		finish: Vector3, width: float, side_axis: Vector3) -> void:
	var direction := (finish - start).normalized()
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var previous_low := Vector3.ZERO
		var previous_high := Vector3.ZERO
		for post_index in 11:
			var progress := float(post_index) / 10.0
			var foot := start.lerp(finish, progress) \
				+ side_axis * side * (width * 0.5 - 0.48) + Vector3.UP * 0.76
			_add_box(parent, "LanternNewelBase_%s_%02d" % ["L" if side < 0 else "R", post_index],
				foot + Vector3.UP * 0.55, Vector3(1.35, 1.1, 1.35),
				_materials.passage_stone_shadow, false)
			_add_box(parent, "LanternNewelShaft_%s_%02d" % ["L" if side < 0 else "R", post_index],
				foot + Vector3.UP * 2.1, Vector3(0.72, 3.1, 0.72),
				_materials.passage_stone, false)
			_add_box(parent, "CyanLantern_%s_%02d" % ["L" if side < 0 else "R", post_index],
				foot + Vector3.UP * 4.25, Vector3(0.58, 1.35, 0.58),
				_materials.passage_light, false)
			var low := foot + Vector3.UP * 1.55
			var high := foot + Vector3.UP * 3.35
			if post_index > 0:
				_add_reference_beam(parent, previous_low, low, 0.18,
					_materials.passage_iron).name = "BalustradeLowerRail"
				_add_reference_beam(parent, previous_high, high, 0.20,
					_materials.passage_bronze).name = "BalustradeTopRail"
				_add_reference_beam(parent, previous_low, high, 0.13,
					_materials.passage_iron).name = "BalustradeLattice"
				_add_reference_beam(parent, previous_high, low, 0.13,
					_materials.passage_iron).name = "BalustradeLattice"
			previous_low = low
			previous_high = high
			# Keep each modular post aligned to the bridge direction even if this
			# route is moved off its current north-south axis later.
			var shaft := parent.get_node_or_null(
				"LanternNewelShaft_%s_%02d" % ["L" if side < 0 else "R", post_index]) as Node3D
			if shaft != null:
				shaft.rotation.y = atan2(direction.x, direction.z)


func _build_reference_front_gate(parent: Node3D, anchor: Vector3, yaw: float,
		width: float) -> void:
	var gate := Node3D.new()
	gate.name = "ReferenceFrontGate"
	gate.position = anchor
	gate.rotation.y = yaw
	gate.scale = Vector3.ONE * 1.55
	gate.set_meta("construction", "modular_limestone_blocks_and_trim")
	gate.set_meta("architectural_scale", 1.55)
	gate.set_meta("clear_opening_width_m", 21.7)
	gate.set_meta("collision_policy", "visual_only_outside_authored_route")
	parent.add_child(gate)
	for side_value in [-1.0, 1.0]:
		_build_reference_gate_tower(gate, float(side_value), width)
	var half_opening := 7.0
	var shoulder_y := 12.0
	var apex := Vector3(0.0, 18.4, 0.0)
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		var shoulder := Vector3(side * half_opening, shoulder_y, 0.0)
		_add_box(gate, "PortalPier", Vector3(side * (half_opening + 0.9), 6.0, 0.0),
			Vector3(1.8, 12.0, 3.2), _materials.passage_stone, false)
		_build_pointed_gate_half(gate, shoulder, apex, side)
	_add_box(gate, "CrestFacade", Vector3(0.0, 20.3, 0.45),
		Vector3(14.5, 5.6, 2.2), _materials.passage_stone, false)
	for crown_index in 5:
		var crown_height := 24.0 + (2.0 if crown_index == 2 else 0.7)
		_add_box(gate, "SteppedFacadeCrown_%02d" % crown_index,
			Vector3((float(crown_index) - 2.0) * 3.15, crown_height, 0.45),
			Vector3(3.3, 1.35, 2.45), _materials.passage_stone_shadow, false)
	_build_reference_gate_crest(gate, Vector3(0.0, 21.0, -0.82))


func _build_reference_gate_tower(parent: Node3D, side: float, width: float) -> void:
	var tower := Node3D.new()
	tower.name = "GateTowerLeft" if side < 0.0 else "GateTowerRight"
	tower.position = Vector3(side * (width * 0.5 + 4.25), 0.0, 0.0)
	parent.add_child(tower)
	_add_box(tower, "SteppedPlinth", Vector3(0.0, 1.0, 0.0), Vector3(6.4, 2.0, 6.4),
		_materials.passage_stone_shadow, false)
	_add_box(tower, "TowerCore", Vector3(0.0, 10.5, 0.0), Vector3(5.2, 19.0, 5.2),
		_materials.passage_stone, false)
	for course in 8:
		for brick_index in 2:
			var brick_width := 2.26
			var stagger := brick_width * 0.25 if course % 2 == 1 else 0.0
			_add_box(tower, "TowerBrick_%02d_%d" % [course, brick_index],
				Vector3((float(brick_index) - 0.5) * brick_width + stagger,
					3.0 + float(course) * 2.05, -2.72),
				Vector3(brick_width - 0.12, 1.86, 0.34),
				_materials.passage_stone_shadow if (course + brick_index) % 3 == 0 \
					else _materials.passage_stone, false)
	for rib_side in [-1.0, 1.0]:
		_add_box(tower, "VerticalBronzeRib", Vector3(float(rib_side) * 2.25, 11.0, -2.92),
			Vector3(0.24, 17.0, 0.22), _materials.passage_bronze, false)
	_add_box(tower, "TowerCyanWindow", Vector3(0.0, 12.5, -2.96),
		Vector3(0.72, 4.8, 0.20), _materials.passage_light, false)
	_add_bridge_cone(tower, "BlueTowerSpire", Vector3(0.0, 22.8, 0.0),
		3.25, 7.0, _materials.passage_roof)
	_add_bridge_cone(tower, "GoldFinial", Vector3(0.0, 27.0, 0.0),
		0.30, 1.8, _materials.passage_bronze)


func _build_pointed_gate_half(parent: Node3D, shoulder: Vector3,
		apex: Vector3, side: float) -> void:
	var previous := shoulder
	for segment_index in 5:
		var point := shoulder.lerp(apex, float(segment_index + 1) / 5.0)
		var stone := _add_reference_beam(parent, previous, point, 1.15,
			_materials.passage_stone_shadow)
		stone.name = "PointedPortalArch_%s_%02d" % ["L" if side < 0 else "R", segment_index]
		var trim_offset := Vector3(0.0, 0.0, -0.72)
		var trim := _add_reference_beam(parent, previous + trim_offset, point + trim_offset,
			0.18, _materials.passage_bronze)
		trim.name = "PointedPortalTrim"
		previous = point


func _build_reference_gate_crest(parent: Node3D, centre: Vector3) -> void:
	var crest_nodes := [centre + Vector3(0.0, 2.0, 0.0),
		centre + Vector3(-2.35, -0.6, 0.0), centre + Vector3(2.35, -0.6, 0.0)]
	for node_index in crest_nodes.size():
		_add_sphere(parent, "GateCrestLight_%02d" % (node_index + 1),
			crest_nodes[node_index], Vector3.ONE * 0.72, _materials.passage_light)
	for branch_index in [1, 2]:
		_add_reference_beam(parent, crest_nodes[0], crest_nodes[branch_index], 0.20,
			_materials.passage_bronze).name = "GateCrestBranch"
	var leaf_tip := centre + Vector3(0.0, -3.2, 0.0)
	_add_reference_beam(parent, crest_nodes[1], leaf_tip, 0.22,
		_materials.passage_bronze).name = "GateCrestLeaf"
	_add_reference_beam(parent, crest_nodes[2], leaf_tip, 0.22,
		_materials.passage_bronze).name = "GateCrestLeaf"


func _add_reference_beam(parent: Node3D, from: Vector3, to: Vector3,
		thickness: float, material: Material) -> MeshInstance3D:
	var delta := to - from
	var beam := _add_box(parent, "ReferenceBeam", from.lerp(to, 0.5),
		Vector3(thickness, thickness, delta.length()), material, false)
	var direction := delta.normalized()
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	beam.basis = Basis.looking_at(direction, up)
	return beam


func _add_bridge_cone(parent: Node3D, node_name: String, position: Vector3,
		radius: float, height: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _add_bridge_between(parent: Node3D, start: Vector3, finish: Vector3, width: float) -> void:
	var direction := finish - start
	var length := direction.length()
	var midpoint := (start + finish) * 0.5
	var yaw := atan2(direction.x, direction.z)
	var reference_passage := parent.name == "CastleToGalaxyBridge175m"
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
		var deck_plate := _add_box(parent, "DeckPlate_%03d" % metre, plate_center,
			Vector3(width - 1.6, 0.10, 8.8), _materials.bridge_deck, false, yaw)
		var anti_slip := _add_box(parent, "AntiSlipJoint_%03d" % metre,
			plate_center + Vector3(0, 0.09, 0), Vector3(width - 1.0, 0.08, 0.42),
			_materials.bridge_rubber, false, yaw)
		deck_plate.visible = not reference_passage
		anti_slip.visible = not reference_passage
	var side_axis := Vector3(cos(yaw), 0.0, -sin(yaw))
	for side in [-1.0, 1.0]:
		var edge: Vector3 = midpoint + side_axis * float(side) * (width * 0.5 - 0.7) + Vector3(0.0, 2.4, 0.0)
		var side_name := "Left" if side < 0 else "Right"
		# A continuous collision curb remains at foot level; posts, glass infill
		# and the top rail provide the detailed visible guard system.
		_add_box(parent, "SafetyRail%s" % side_name, edge + Vector3(0, -1.65, 0),
			Vector3(1.2, 1.5, length), _materials.bridge_edge, true, yaw, 0.86, 0.0)
		var guard_glass := _add_box(parent, "GuardGlass%s" % side_name, edge + Vector3(0, 0.15, 0),
			Vector3(0.34, 3.2, length - 1.0), _materials.bridge_glass, true, yaw, 0.35, 0.0)
		var top_rail := _add_box(parent, "TopRail%s" % side_name, edge + Vector3(0, 2.3, 0),
			Vector3(0.9, 0.65, length), _materials.bridge_edge, true, yaw, 0.82, 0.0)
		guard_glass.visible = not reference_passage
		top_rail.visible = not reference_passage
		for metre in range(0, int(length) + 1, 10):
			var post_progress := minf(1.0, float(metre) / length)
			var post_position := start.lerp(finish, post_progress)
			post_position += side_axis * float(side) * (width * 0.5 - 0.7) + Vector3(0, 2.55, 0)
			var guard_post := _add_box(parent, "GuardPost%s_%03d" % [side_name, metre], post_position,
				Vector3(0.9, 5.1, 0.9), _materials.bridge_edge, true, yaw, 0.82, 0.0)
			guard_post.visible = not reference_passage
	for step in range(10, int(length), 20):
		var progress := float(step) / length
		var marker := start.lerp(finish, progress) + Vector3(0.0, 1.0, 0.0)
		var path_marker := _add_box(parent, "RainbowPathMarker", marker,
			Vector3(width - 3.0, 0.18, 2.0), _materials.aqua_glass, false, yaw)
		path_marker.visible = not reference_passage
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
	# Defer World One's construction on the web. It is ~27,000 mesh nodes, 82%
	# of every mesh in the art gallery, and building it up front took the scene
	# to 1,161 MB against the hub's 348 MB - past what a wasm32 browser holding
	# the pack in memory can serve, so the gallery came up empty. The world gate
	# and the causeway both build it on demand.
	world_one.defer_world_build = OS.has_feature("web")
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
	if world_one.defer_world_build:
		_add_world_one_build_trigger(world_one)


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
	# The train landing shares this island rim. Offset the causeway entrance
	# around the rim so its raised threshold and rails do not cross that lane.
	start = MIND + (start - MIND + Vector3(0.0, 0.0, 36.0)).normalized() \
		* (MIND_DISTRICT_RADIUS - 8.0)
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
	if _use_web_lod():
		_batch_world_one_causeway_visuals(causeway)
	causeway.set_meta("span_metres", span)
	causeway.set_meta("segment_count", segment_count)
	causeway.set_meta("deck_y", CAUSEWAY_DECK_Y)
	causeway.set_meta("walk_start", start)
	causeway.set_meta("walk_finish", finish)


func _batch_world_one_causeway_visuals(causeway: Node3D) -> void:
	## Keep every authored causeway node and every collision body inspectable, but
	## submit its static masonry in spatial material batches on Web. Without this
	## pass the distant bridge contributes hundreds of individual draw calls even
	## from Islands Two and Three. Cells retain camera-frustum culling along the
	## kilometre-scale span, unlike one monolithic merged bridge mesh.
	const CELL_SIZE := 192.0
	var groups := {}
	for value in causeway.find_children("*", "MeshInstance3D", true, false):
		var instance := value as MeshInstance3D
		if instance.mesh == null or instance.mesh.get_surface_count() != 1 \
				or instance.material_override == null or not instance.visible:
			continue
		var local_origin := causeway.to_local(instance.global_position)
		var cell := Vector2i(floori(local_origin.x / CELL_SIZE),
			floori(local_origin.z / CELL_SIZE))
		var key := "%d,%d|material=%d|shadow=%d|gi=%d" % [
			cell.x, cell.y, instance.material_override.get_instance_id(),
			instance.cast_shadow, instance.gi_mode]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(instance)
	var batches := 0
	var sources := 0
	for key in groups:
		var members := groups[key] as Array
		if members.size() < 2:
			continue
		var first := members[0] as MeshInstance3D
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for member_value in members:
			var member := member_value as MeshInstance3D
			surface.append_from(member.mesh, 0,
				causeway.global_transform.affine_inverse() * member.global_transform)
		var combined := surface.commit()
		if combined == null or combined.get_surface_count() == 0:
			continue
		var batch := MeshInstance3D.new()
		batch.name = "WebCausewayBatch_%03d" % batches
		batch.mesh = combined
		batch.material_override = first.material_override
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.gi_mode = first.gi_mode
		batch.set_meta("render_role", "spatial World One causeway batch")
		batch.set_meta("merged_static_source_count", members.size())
		causeway.add_child(batch)
		for member_value in members:
			var member := member_value as MeshInstance3D
			member.layers = 0
			member.set_meta("render_merged_into", batch.name)
			sources += 1
		batches += 1
	causeway.set_meta("web_visual_batch_count", batches)
	causeway.set_meta("web_visual_source_count", sources)
	causeway.set_meta("web_visual_batch_cell_size", CELL_SIZE)


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
	var tree_processional := node_name == "SouthArrivalBridge"
	var direction := end - start
	var length := direction.length()
	var midpoint := (start + end) * 0.5 + Vector3(0.0, -2.0, 0.0)
	var yaw := atan2(direction.x, direction.z)
	var walkway_material: Material = _materials.passage_stone if tree_processional else _materials.stone
	_add_box(bridge, "Walkway", midpoint, Vector3(width, 4.0, length),
		walkway_material, true, yaw)
	var side_axis := Vector3(cos(yaw), 0.0, -sin(yaw))
	for side in [-1.0, 1.0]:
		var rail_height := 5.0 if tree_processional else 10.0
		var rail_y := 2.5 if tree_processional else 5.0
		var rail_material: Material = _materials.passage_stone_shadow \
			if tree_processional else _materials.ivory
		var edge_position: Vector3 = midpoint \
			+ side_axis * float(side) * (width * 0.5 - 2.0) \
			+ Vector3(0.0, rail_y, 0.0)
		var safety_rail := _add_box(bridge, "SafetyRail", edge_position,
			Vector3(2.4 if tree_processional else 3.0, rail_height, length),
			rail_material, true, yaw)
		# Retain the original continuous fall-prevention collision, but let the
		# lightweight botanical lattice carry the visible silhouette.
		safety_rail.visible = not tree_processional
		if not tree_processional:
			for step in range(0, int(length), 55):
				var t := float(step) / length
				var planter_pos: Vector3 = start.lerp(end, t) \
					+ side_axis * float(side) * (width * 0.5 - 7.0) \
					+ Vector3(0.0, 3.0, 0.0)
				_add_flower_cluster(bridge, planter_pos, (step / 55) % 2 == 0)
	for step in range(45, int(length), 90):
		var t := float(step) / length
		var support_pos := start.lerp(end, t) + Vector3(0.0, -24.0, 0.0)
		_add_arch_support(bridge, support_pos, width, yaw)
	if tree_processional:
		_build_tree_of_life_processional_style(bridge, start, end, width, yaw, side_axis)


func _build_tree_of_life_processional_style(bridge: Node3D, start: Vector3,
		end: Vector3, width: float, yaw: float, side_axis: Vector3) -> void:
	var length := start.distance_to(end)
	bridge.set_meta("visual_style", "castle_arcane_tree_of_life_processional")
	bridge.set_meta("performance_profile", "laptop_cpu_low")
	bridge.set_meta("processional_length_m", length)
	bridge.set_meta("processional_width_m", width)
	bridge.set_meta("botanical_rail_bays", 8)
	bridge.set_meta("bough_portal_count", 3)
	bridge.set_meta("collision_policy", "original_continuous_walkway_and_safety_rails")
	bridge.set_meta("blender_editable_module_count", 689)
	bridge.set_meta("blender_runtime_mesh_group_count", 9)
	bridge.set_meta("bridge_runtime_triangle_count", 26116)
	bridge.set_meta("clear_gameplay_lane_m", 42.0)
	bridge.set_meta("maximum_portal_height_m", 28.046)
	var asset_holder := Node3D.new()
	asset_holder.name = "ReferenceTreeProcessionalBridge"
	# Blender +Y imports as Godot -Z, which matches this route from z=1422 to
	# z=975 exactly. Its paver top sits 23 cm above the tested collision deck.
	asset_holder.position = start
	asset_holder.rotation.y = yaw + PI
	asset_holder.set_meta("source_blend",
		"res://assets3D/tree_processional_bridge/blend/tree_processional_bridge.blend")
	asset_holder.set_meta("source_glb",
		"res://assets3D/tree_processional_bridge/glb/tree_processional_bridge.glb")
	asset_holder.set_meta("visual_only", true)
	bridge.add_child(asset_holder)
	var blender_asset := TreeProcessionalBridgeScene.instantiate() as Node3D
	if blender_asset != null:
		blender_asset.name = "BlenderTreeProcessionalBridge"
		asset_holder.add_child(blender_asset)


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
	_style_original_tree_body(tree, visual)
	_build_tree_of_life_collision(tree, manifest)
	_build_blender_blueprint_trunk_root(tree)
	_build_reference_trunk_root_facade(tree)
	_build_old_growth_trunk_body(tree)
	_hide_superseded_procedural_lower_body(tree)
	# The capture-only switch lets the inspection harness render the embedded
	# heart at full trunk quality without first submitting the unrelated 43k-leaf
	# canopy. Normal gameplay never sets this environment variable.
	if not OS.has_environment("ARTEA_TREE_CAPTURE_SKIP_CANOPY"):
		_build_laptop_gravity_bough_canopy(tree, visual)
	_build_trunk_energy_veins(tree)
	_build_wisdom_heart_shrine(tree)
	_build_tree_christmas_ambience(tree)

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


func _build_tree_christmas_ambience(tree: Node3D) -> void:
	# Use two lightweight positional loops rather than additional geometry or a
	# per-frame synthesizer: a cheerful melody supplies the Christmas character,
	# while the quieter bell layer gives the crystal a close-range sparkle.
	_tree_christmas_melody = _new_tree_christmas_source(
		"ChristmasTreeMelody3D", TREE_CHRISTMAS_MELODY, Vector3(0.0, 54.0, 0.0))
	_tree_christmas_bells = _new_tree_christmas_source(
		"ChristmasTreeBells3D", TREE_CHRISTMAS_BELLS, Vector3(0.0, 58.0, 0.0))
	tree.add_child(_tree_christmas_melody)
	tree.add_child(_tree_christmas_bells)
	_tree_christmas_melody.play()
	_tree_christmas_bells.play()
	tree.set_meta("christmas_ambience", true)
	tree.set_meta("christmas_ambience_layers", 2)
	tree.set_meta("christmas_arrangement", "purpose_built_festive_bell_orchestra")
	tree.set_meta("christmas_arrangement_seconds", 32.0)
	tree.set_meta("christmas_instruments",
		["glockenspiel", "celesta", "sleigh_bells", "warm_strings", "soft_bass"])
	tree.set_meta("christmas_full_volume_distance", TREE_CHRISTMAS_FULL_VOLUME_DISTANCE)
	tree.set_meta("christmas_silent_distance", TREE_CHRISTMAS_SILENT_DISTANCE)
	tree.set_meta("christmas_fade_uses_player_distance", true)
	tree.set_meta("christmas_fade_out_is_gradual", true)
	tree.set_meta("christmas_fade_out_speed", TREE_CHRISTMAS_FADE_OUT_SPEED)


func _new_tree_christmas_source(node_name: String, source_stream: AudioStream,
		local_position: Vector3) -> AudioStreamPlayer3D:
	var source := AudioStreamPlayer3D.new()
	source.name = node_name
	source.position = local_position
	var looping_stream := source_stream.duplicate()
	if looping_stream is AudioStreamWAV:
		(looping_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(looping_stream as AudioStreamWAV).loop_begin = 0
		(looping_stream as AudioStreamWAV).loop_end = 1_411_200
	elif looping_stream is AudioStreamOggVorbis:
		(looping_stream as AudioStreamOggVorbis).loop = true
	source.stream = looping_stream
	# Custom distance gain below replaces Godot's hard max-distance cutoff. The
	# player therefore hears a long, smooth tail rather than sound disappearing.
	source.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	source.max_distance = 0.0
	source.panning_strength = 1.0
	source.volume_db = TREE_CHRISTMAS_SILENT_VOLUME_DB
	source.max_db = -3.0
	source.bus = &"SFX"
	return source


func _update_tree_christmas_ambience(delta: float) -> void:
	if _player == null or not is_instance_valid(_tree_christmas_melody):
		return
	var distance := _player.global_position.distance_to(
		_tree_christmas_melody.global_position)
	var distance_ratio := smoothstep(TREE_CHRISTMAS_FULL_VOLUME_DISTANCE,
		TREE_CHRISTMAS_SILENT_DISTANCE, distance)
	# Work in linear amplitude so the perceived fade remains gentle near its far
	# edge. A floor of -80 dB is effectively silent but keeps the loop in sync.
	var amplitude := pow(1.0 - distance_ratio, 1.60)
	var target_db := clampf(linear_to_db(maxf(amplitude, 0.0001))
		+ TREE_CHRISTMAS_NEAR_VOLUME_DB,
		TREE_CHRISTMAS_SILENT_VOLUME_DB, TREE_CHRISTMAS_NEAR_VOLUME_DB)
	var fade_speed := TREE_CHRISTMAS_FADE_IN_SPEED \
		if target_db > _tree_christmas_melody.volume_db \
		else TREE_CHRISTMAS_FADE_OUT_SPEED
	var blend := 1.0 - exp(-fade_speed * delta)
	_tree_christmas_melody.volume_db = lerpf(
		_tree_christmas_melody.volume_db, target_db, blend)
	if is_instance_valid(_tree_christmas_bells):
		_tree_christmas_bells.volume_db = maxf(
			TREE_CHRISTMAS_SILENT_VOLUME_DB,
			_tree_christmas_melody.volume_db - 15.0)


func _build_blender_blueprint_trunk_root(tree: Node3D) -> void:
	# The detailed Blender source is now the authoritative lower architecture in
	# the production tree, not an offline presentation-only asset. Its 48 m body
	# maps directly onto the 186 m world blueprint body at the shared 3.875 scale.
	# The existing procedural leader continues above it to support the enlarged
	# 496 m Christmas crown.
	var body := BlueprintTrunkRootScene.instantiate() as Node3D
	body.name = "BlenderBlueprintTrunkRoot"
	body.scale = Vector3.ONE * TREE_BLUEPRINT_WORLD_SCALE
	# Blender's authored front imports toward Godot +Z. Rotate the detailed body
	# so its pointed doorway and stair flight face the production south approach.
	body.rotation.y = PI
	body.set_meta("source_blend",
		"res://assets3D/tree_of_life/trunk_core/source/simple_trunk_core.blend")
	body.set_meta("runtime_glb",
		"res://assets3D/tree_of_life/trunk_core/glb/simple_trunk_core.glb")
	body.set_meta("blueprint_body_height", TREE_BLUEPRINT_BODY_HEIGHT)
	body.set_meta("blueprint_root_diameter", TREE_BLUEPRINT_ROOT_RADIUS * 2.0)
	body.set_meta("blueprint_doorway_width", TREE_BLUEPRINT_DOOR_WIDTH)
	body.set_meta("blueprint_doorway_height", TREE_BLUEPRINT_DOOR_HEIGHT)
	body.set_meta("primary_roots", 18)
	body.set_meta("secondary_rootlets", 54)
	body.set_meta("structural_bark_ribs", 12)
	body.set_meta("energy_route", "18_root_intakes_to_6_collectors_to_2_heart_feeders_to_16_crown_veins")
	body.set_meta("laptop_runtime_triangles", 58904)
	body.set_meta("authoritative_lower_body", true)
	tree.add_child(body)
	for mesh_node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		# The canopy already owns the dominant landmark shadow. Keeping the detailed
		# body out of that pass protects laptop GPU time without reducing geometry.
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Godot's cool world lighting washed the imported pale Blender bark toward
		# grey. Preserve material separation explicitly so thick roots read as wood
		# while cyan energy and stone retain their authored colours.
		for surface_index in mesh.mesh.get_surface_count():
			var source_material := mesh.mesh.surface_get_material(surface_index)
			if not source_material is StandardMaterial3D:
				continue
			var source_standard := source_material as StandardMaterial3D
			var material_name := source_standard.resource_name
			var wood_colour := Color.TRANSPARENT
			if "WoodHeartwood" in material_name or "HeartRecessDarkWood" in material_name:
				wood_colour = Color("24140d")
			elif "WoodWarmBark" in material_name:
				wood_colour = Color("61371f")
			elif "WoodSunlitBark" in material_name:
				wood_colour = Color("a56532")
			if wood_colour.a > 0.0:
				var runtime_wood := source_standard.duplicate() as StandardMaterial3D
				runtime_wood.albedo_color = wood_colour
				runtime_wood.roughness = 0.88
				mesh.set_surface_override_material(surface_index, runtime_wood)
			elif "Energy" in material_name or "Cyan" in material_name:
				var runtime_energy := source_standard.duplicate() as StandardMaterial3D
				runtime_energy.albedo_color = Color("23d9ff")
				runtime_energy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				runtime_energy.emission_enabled = true
				runtime_energy.emission = Color("23d9ff")
				runtime_energy.emission_energy_multiplier = 1.35
				mesh.set_surface_override_material(surface_index, runtime_energy)
	tree.set_meta("runtime_trunk_root_source", "blender_blueprint_trunk_root_v3")
	tree.set_meta("runtime_trunk_root_triangles", 58904)
	tree.set_meta("detailed_blender_body_instantiated", true)
	tree.set_meta("runtime_wood_palette",
		"deep_heartwood_warm_bark_amber_sunlit_bark_with_cyan_energy")


func _hide_superseded_procedural_lower_body(tree: Node3D) -> void:
	# Retain the old-growth generator as an editable/testable upper-leader source,
	# but do not draw its coarse roots, doorway, or lower buttresses through the
	# new Blender body. Upper co-dominant stems and the crown leader remain live.
	var old_growth := tree.get_node_or_null("OldGrowthTrunkBody") as Node3D
	if old_growth == null:
		return
	var hidden_names := [
		"OldGrowthRootSystem",
		"OldGrowthEnergyNetwork",
		"BlueprintDoorwayInterior",
		"OldGrowthButtressStem_01",
		"OldGrowthButtressStem_02",
		"OldGrowthDepthButtressStem",
	]
	var hidden_count := 0
	for node_name in hidden_names:
		var visual := old_growth.get_node_or_null(node_name) as Node3D
		if visual != null:
			visual.visible = false
			hidden_count += 1
	old_growth.set_meta("lower_body_visual_source", "BlenderBlueprintTrunkRoot")
	old_growth.set_meta("superseded_lower_systems_hidden", hidden_count)


func _style_original_tree_body(tree: Node3D, visual: Node3D) -> void:
	# The original v3 Blender tree remains the authoritative architecture: its
	# 122-part braided twin trunk, 144-part spreading root system, deep foundation
	# and 9.5 m gothic passage are never replaced. The newer redesign contributes
	# only its material language and surface energy treatment.
	var wood_bands := _create_reference_tree_wood_palette()
	var styled_trunks := 0
	var styled_roots := 0
	var restored_branches := 0
	var restored_foliage := 0
	for mesh_node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		# Laptop profile: the imported tree is already densely layered and dominates
		# the sanctuary's shadow pass. The court and procedural trunk facade still
		# receive lighting, but this authored visual no longer submits a second full
		# copy of all its leaves and branches to the shadow renderer.
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.name.begins_with("Trunk"):
			mesh.visible = false
			mesh.scale = Vector3(
				mesh.scale.x * ORIGINAL_TRUNK_RADIAL_SCALE,
				mesh.scale.y,
				mesh.scale.z * ORIGINAL_TRUNK_RADIAL_SCALE)
			for surface_index in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(
					surface_index, wood_bands[surface_index % wood_bands.size()])
			styled_trunks += 1
		elif mesh.name.begins_with("Roots"):
			mesh.visible = false
			mesh.scale = Vector3(
				mesh.scale.x * ORIGINAL_ROOT_RADIAL_SCALE,
				mesh.scale.y,
				mesh.scale.z * ORIGINAL_ROOT_RADIAL_SCALE)
			for surface_index in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(
					surface_index, wood_bands[(surface_index + 1) % wood_bands.size()])
			styled_roots += 1
		elif mesh.name.begins_with("Branches"):
			# The 225 brass fittings were authored against these exact 480 branch
			# modules. Restoring the matching wood is what makes every collar and
			# mechanism read as grafted into the tree instead of floating in space.
			mesh.visible = true
			mesh.mesh = _reshape_original_canopy_mesh(mesh.mesh,
				ORIGINAL_CANOPY_BASE_SCALE, ORIGINAL_CANOPY_TIP_SCALE,
				ORIGINAL_CANOPY_HEIGHT_SCALE)
			for surface_index in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(
					surface_index, wood_bands[(surface_index + 1) % wood_bands.size()])
			mesh.set_meta("supports_original_brass_engineering", true)
			mesh.set_meta("christmas_taper_deformed", true)
			restored_branches += 1
		elif mesh.name.begins_with("FoliageMagic"):
			_style_original_foliage_mesh(mesh, "magic")
			restored_foliage += 1
		elif mesh.name.begins_with("FoliageNature"):
			_style_original_foliage_mesh(mesh, "nature")
			restored_foliage += 1
		elif mesh.name.begins_with("FoliageSolarGlass"):
			_style_original_foliage_mesh(mesh, "technology")
			restored_foliage += 1
		elif mesh.name.begins_with("BrassEngineering"):
			mesh.visible = true
			mesh.set_meta("seated_on_original_branch_system", true)
		elif mesh.name.begins_with("CrystalTechnology"):
			# The new detailed heart shrine owns the focal crystal. Hiding only the
			# old joined crystal system prevents a duplicate without touching wood.
			mesh.visible = false
	tree.set_meta("runtime_tree_source", "original_artea_tree_of_life_v3")
	tree.set_meta("original_big_root_system", styled_roots > 0)
	tree.set_meta("original_braided_trunk_system", styled_trunks > 0)
	tree.set_meta("original_body_superseded_by_blueprint_geometry", true)
	tree.set_meta("new_style_applied_to_original_mesh", true)
	tree.set_meta("original_root_modules", 144)
	tree.set_meta("original_trunk_modules", 122)
	tree.set_meta("original_branch_modules", 480)
	tree.set_meta("original_leaf_modules", 4928)
	tree.set_meta("original_branch_system_restored", restored_branches == 1)
	tree.set_meta("original_foliage_systems_restored", restored_foliage == 3)
	tree.set_meta("canopy_source", "original_artea_tree_of_life_blender_systems")
	tree.set_meta("canopy_silhouette", "wide_bottom_tapered_christmas_tree")
	tree.set_meta("mechanics_attachment", "original_branches_plus_living_wood_heart_cradle")
	tree.set_meta("trunk_radial_scale", ORIGINAL_TRUNK_RADIAL_SCALE)
	tree.set_meta("root_radial_scale", ORIGINAL_ROOT_RADIAL_SCALE)
	tree.set_meta("integration_blueprint",
		"res://design/tree_of_life/blueprints/original_tree_mechanical_cradle_v5.md")


func _style_original_foliage_mesh(mesh: MeshInstance3D, role: String) -> void:
	mesh.visible = true
	mesh.mesh = _reshape_original_canopy_mesh(mesh.mesh,
		ORIGINAL_CANOPY_BASE_SCALE, ORIGINAL_CANOPY_TIP_SCALE,
		ORIGINAL_CANOPY_HEIGHT_SCALE)
	var colour := Color("38bd67")
	var energy := 0.22
	if role == "magic":
		colour = Color("9d64e8")
		energy = 0.42
	elif role == "technology":
		colour = Color("27bce7")
		energy = 0.55
	var material := _make_glow(colour, energy)
	material.roughness = 0.48 if role == "technology" else 0.76
	for surface_index in mesh.mesh.get_surface_count():
		mesh.set_surface_override_material(surface_index, material)
	mesh.set_meta("semantic_leaf_role", role)
	mesh.set_meta("original_authored_foliage", true)
	mesh.set_meta("christmas_taper_deformed", true)


func _build_original_christmas_canopy_tiers(tree: Node3D, visual: Node3D) -> void:
	# Laptop profile: the source GLB already contains one complete branch system
	# and all three semantic foliage systems. The previous version duplicated all
	# four meshes into two extra tiers, tripling the canopy geometry and shadow
	# cost. Keep the authored canopy once and retain this marker node so tests and
	# inspection tools can verify why the copies are intentionally absent.
	var tiers := Node3D.new()
	tiers.name = "OriginalChristmasCanopyTiers"
	tiers.set_meta("source", "original_artea_tree_of_life_branch_and_foliage_meshes")
	tiers.set_meta("additional_tiers", 0)
	tiers.set_meta("copied_systems_per_tier", 0)
	tiers.set_meta("branch_leaf_alignment_preserved", true)
	tiers.set_meta("silhouette", "single_authored_low_cost_canopy")
	tiers.set_meta("graphics_profile", "laptop_low")
	visual.add_child(tiers)
	tree.set_meta("tree_graphics_profile", "laptop_low")
	tree.set_meta("original_christmas_canopy_tiers", 1)
	tree.set_meta("original_canopy_tier_copies", 0)
	tree.set_meta("removed_duplicate_canopy_meshes", 8)


func _build_laptop_gravity_bough_canopy(tree: Node3D, visual: Node3D) -> void:
	# Build the architecture sheet literally: nine tapered tiers, two children
	# per primary bough, six twig fans per child, and four instanced leaf families.
	# Every descendant transform starts at a point on its parent's centreline.
	for mesh_node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		if mesh.name.begins_with("Branches") \
				or mesh.name.begins_with("Foliage") \
				or mesh.name.begins_with("BrassEngineering"):
			mesh.visible = false
		elif mesh.name.begins_with("WisdomStar"):
			mesh.visible = true
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.set_meta("canopy_crown_logo", true)
			# Preserve the authored logo, but seat it at the top of the enlarged
			# blueprint crown and normalize it to the specified four-metre emblem.
			if mesh.mesh != null:
				var star_world_bounds := mesh.global_transform * mesh.mesh.get_aabb()
				var target_star_height := 8.0 * TREE_BLUEPRINT_WORLD_SCALE
				if star_world_bounds.size.y > 0.01:
					var star_factor := target_star_height / star_world_bounds.size.y
					mesh.global_basis = mesh.global_basis.scaled(Vector3.ONE * star_factor)
			mesh.rotate_y(PI * 0.5)
			var star_target := tree.to_global(Vector3(
				0.0, TREE_BLUEPRINT_STAR_HEIGHT, -6.0))
			var seated_bounds := mesh.global_transform * mesh.mesh.get_aabb()
			mesh.global_position += star_target \
				- (seated_bounds.position + seated_bounds.size * 0.5)
			mesh.set_meta("blueprint_crown_height", TREE_BLUEPRINT_STAR_HEIGHT)

	var canopy := Node3D.new()
	canopy.name = "LaptopGravityBoughCanopy"
	canopy.set_meta("module_source", "procedural_blueprint_shared_meshes")
	canopy.set_meta("graphics_profile", "laptop_low")
	canopy.set_meta("silhouette", "wide_bottom_tapered_christmas_cone")
	canopy.set_meta("leaf_attachment", "visible_tail_to_twig_surface_socket")
	canopy.set_meta("major_attachment", "continuous_trunk_surface")
	canopy.set_meta("child_attachment", "parent_bough_centerline")
	canopy.set_meta("twig_attachment", "child_bough_centerline")
	canopy.set_meta("child_boughs_per_major", 2)
	canopy.set_meta("twig_fans_per_child", 8)
	canopy.set_meta("primary_cover_twigs_per_major", 8)
	canopy.set_meta("primary_cover_root_spacing_fraction", 0.135)
	canopy.set_meta("child_cover_root_spacing_fraction", 0.135)
	canopy.set_meta("maximum_uncovered_longitudinal_fraction", 0.135)
	canopy.set_meta("cover_twigs_follow_parent_bough", true)
	canopy.set_meta("major_and_child_branch_surface_coverage_audited", true)
	canopy.set_meta("large_branch_leaf_sleeve_complete", true)
	canopy.set_meta("cover_fan_longitudinal_bias", 0.94)
	canopy.set_meta("cover_fan_lateral_bias", 0.20)
	canopy.set_meta("coverage_strategy", "broad_overlapping_static_leaf_reliefs")
	canopy.set_meta("leaf_width_multiplier", 1.87)
	canopy.set_meta("leaf_length_multiplier", 1.30)
	canopy.set_meta("coverage_implementation", "scale_existing_batched_reliefs_no_new_instances")
	canopy.set_meta("leaf_instance_count_unchanged_for_laptop", true)
	canopy.set_meta("leaf_batch_count", 4)
	canopy.set_meta("canopy_collision", false)
	canopy.set_meta("blueprint_total_height", TREE_BLUEPRINT_TOTAL_HEIGHT)
	canopy.set_meta("blueprint_max_width", TREE_BLUEPRINT_CANOPY_RADIUS * 2.0)
	tree.add_child(canopy)

	var primary_transforms: Array[Transform3D] = []
	var child_transforms: Array[Transform3D] = []
	var twig_transforms: Array[Transform3D] = []
	var branch_energy_junction_transforms: Array[Transform3D] = []
	var primary_socket_pairs := PackedVector3Array()
	var child_socket_pairs := PackedVector3Array()
	var twig_socket_pairs := PackedVector3Array()
	var leaf_socket_pairs := PackedVector3Array()
	var leaf_direction_pairs := PackedVector3Array()
	var visible_leaf_counts: Array[int] = []
	var twig_leaf_refs: Array = []
	var heart_niche_culled_leaf_instances := 0
	var leaf_family_transforms := {
		"living_leaf_fan": [] as Array[Transform3D],
		"magic_rune_leaf": [] as Array[Transform3D],
		"emerald_sensor_leaf": [] as Array[Transform3D],
		"solar_glass_science_leaf": [] as Array[Transform3D],
	}
	# The supplied 64 m elevation is expanded to a 128 m crown. Tier 1 stays at
	# the original 14 m body/heart level so foliage still masks the lower trunk;
	# the remaining tiers spread upward to the new crown. Each tier carries twice
	# the original radial bough count.
	var tier_specs := [
		{"count": 24, "height": 14.0, "reach": 42.0, "pitch": -8.0, "phase": 0.10, "main": true},
		{"count": 8, "height": 20.5, "reach": 31.2, "pitch": -7.5, "phase": 0.61, "main": false},
		{"count": 24, "height": 27.0, "reach": 38.0, "pitch": -7.0, "phase": 0.36, "main": true},
		{"count": 8, "height": 33.5, "reach": 28.1, "pitch": -6.0, "phase": 0.84, "main": false},
		{"count": 20, "height": 40.0, "reach": 34.0, "pitch": -5.0, "phase": 0.18, "main": true},
		{"count": 7, "height": 46.5, "reach": 25.0, "pitch": -4.0, "phase": 0.69, "main": false},
		{"count": 20, "height": 53.0, "reach": 30.0, "pitch": -3.0, "phase": 0.48, "main": true},
		{"count": 7, "height": 59.5, "reach": 21.6, "pitch": -2.0, "phase": 0.97, "main": false},
		{"count": 16, "height": 66.0, "reach": 25.5, "pitch": -1.0, "phase": 0.25, "main": true},
		{"count": 6, "height": 72.5, "reach": 18.1, "pitch": 0.0, "phase": 0.77, "main": false},
		{"count": 16, "height": 79.0, "reach": 21.0, "pitch": 1.0, "phase": 0.58, "main": true},
		{"count": 6, "height": 85.5, "reach": 14.6, "pitch": 2.0, "phase": 1.08, "main": false},
		{"count": 12, "height": 92.0, "reach": 16.5, "pitch": 3.0, "phase": 0.34, "main": true},
		{"count": 5, "height": 98.5, "reach": 11.1, "pitch": 4.5, "phase": 0.88, "main": false},
		{"count": 8, "height": 105.0, "reach": 12.0, "pitch": 6.0, "phase": 0.72, "main": true},
		{"count": 4, "height": 111.5, "reach": 7.4, "pitch": 7.5, "phase": 1.21, "main": false},
		{"count": 4, "height": 118.0, "reach": 7.0, "pitch": 9.0, "phase": 0.22, "main": true},
	]
	for tier_index in tier_specs.size():
		var tier_spec: Dictionary = tier_specs[tier_index]
		var count := int(tier_spec.count)
		for branch_index in count:
			var yaw := TAU * float(branch_index) / float(count) + float(tier_spec.phase)
			var variation := sin(float(branch_index * 7 + tier_index * 11) * 0.47)
			yaw += variation * 0.035
			var radial := Vector3(cos(yaw), 0.0, sin(yaw))
			# Split the two lowest front-facing spokes around the ceremonial heart
			# instead of drawing wood and leaves across its protected sightline.
			if tier_index <= 1 and radial.z < -0.72:
				yaw = -0.72 if radial.x >= 0.0 else -PI + 0.72
				radial = Vector3(cos(yaw), 0.0, sin(yaw))
			# Preserve recognisable whorls while avoiding lathe-perfect shelves.
			# Small height/reach differences model unequal light and load exposure.
			var height := (float(tier_spec.height) + variation * 0.65) \
				* TREE_BLUEPRINT_WORLD_SCALE
			var reach := float(tier_spec.reach) * TREE_BLUEPRINT_WORLD_SCALE \
				* (1.0 + variation * 0.03)
			var root_target := _old_growth_trunk_center(height)
			root_target.y = height
			var trunk_radius := _old_growth_trunk_radius(height)
			root_target += radial * trunk_radius
			var primary_length := maxf(3.0, reach - trunk_radius)
			var pitch := deg_to_rad(float(tier_spec.pitch) + variation * 1.5)
			var direction := (radial * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
			var crown_t := clampf((float(tier_spec.height) - 14.0) / 104.0, 0.0, 1.0)
			var thickness := lerpf(3.2, 0.72, crown_t)
			var primary_basis := _blueprint_x_basis(direction) * Basis.from_scale(
				Vector3(primary_length / 10.0, thickness, thickness))
			var primary_transform := Transform3D(primary_basis, root_target)
			primary_transforms.append(primary_transform)
			# The branch fiber begins on the bark surface. One small cyan collector at
			# that exact point bridges the trunk vein field into every primary bough.
			var energy_socket := primary_transform * Vector3(0.0, 0.93, 0.0)
			branch_energy_junction_transforms.append(Transform3D(
				Basis.IDENTITY.scaled(Vector3.ONE * maxf(0.30, thickness * 0.24)),
				energy_socket))
			primary_socket_pairs.append(root_target)
			primary_socket_pairs.append(primary_transform.origin)

			var tangent := Vector3(-radial.z, 0.0, radial.x)
			for child_index in 2:
				var side := -1.0 if child_index == 0 else 1.0
				# Begin one child inside the primary's inner half. Its twig foliage
				# overlaps the central leader and prevents a bare trunk-shaped hole.
				var fork_t := 0.04 if child_index == 0 else 0.42
				var child_root: Vector3 = primary_transform * _blueprint_branch_point(fork_t)
				var child_outward := 0.42 if child_index == 0 else 0.68
				var child_sideways := 0.76 if child_index == 0 else 0.55
				var child_vertical_bias := lerpf(-0.04, 0.08, crown_t)
				var child_direction := (direction * child_outward \
					+ tangent * side * child_sideways
					+ Vector3.UP * child_vertical_bias).normalized()
				var child_length := primary_length * (0.62 if child_index == 0 else 0.78)
				var child_basis := _blueprint_x_basis(child_direction) * Basis.from_scale(
					Vector3(child_length / 10.0, thickness * 0.54, thickness * 0.54))
				var child_transform := Transform3D(child_basis, child_root)
				child_transforms.append(child_transform)
				child_socket_pairs.append(child_root)
				child_socket_pairs.append(child_transform.origin)

				for twig_index in 8:
					# Eight short, fine twigs carry broad overlapping leaf reliefs. This
					# covers more wood with fewer instances than the narrow 3x canopy.
					# Starting at 2.5% places foliage directly over the primary-bough
					# and trunk junction; the remaining twigs blanket the child bough.
					var twig_t := 0.025 + float(twig_index) * 0.135
					var twig_root: Vector3 = child_transform * _blueprint_branch_point(twig_t)
					var twig_side := -1.0 if twig_index % 2 == 0 else 1.0
					# Two interleaved vertical strata avoid a flat foliage shelf while
					# retaining deterministic, branch-derived placement.
					var fan_lift := -0.18 + float(twig_index % 4) * 0.12 \
						+ (0.04 if twig_index >= 4 else 0.0)
					# Hug the parent bough so adjacent leaf fans overlap into a
					# continuous sleeve instead of exposing a bare longitudinal strip.
					var twig_direction := (child_direction * 0.90 + tangent * twig_side * 0.24
						+ Vector3.UP * fan_lift).normalized()
					var twig_length := maxf(child_length * 0.26, 11.5) \
						* (0.90 if twig_index % 2 == 1 else 1.0)
					# Keep crown twigs thick enough to carry the same visible brass
					# leaf cuff as lower tiers. The old thickness-only scale collapsed
					# top twigs into hairlines while the leaf artwork stayed readable.
					var twig_girth := maxf(thickness * 0.18, 0.34)
					var twig_basis := _blueprint_x_basis(twig_direction) * Basis.from_scale(
						Vector3(twig_length / 4.0, twig_girth, twig_girth))
					var twig_transform := Transform3D(twig_basis, twig_root)
					twig_transforms.append(twig_transform)
					visible_leaf_counts.append(0)
					twig_leaf_refs.append([])
					twig_socket_pairs.append(twig_root)
					twig_socket_pairs.append(twig_transform.origin)
					_blueprint_append_twig_leaves(leaf_family_transforms,
						twig_transform, twig_transforms.size() - 1,
						roundi(crown_t * 8.0),
						leaf_socket_pairs, leaf_direction_pairs, visible_leaf_counts,
						twig_leaf_refs)

			# Eight additional fine twigs grow directly from the primary limb.
			# These are the missing foliage layer seen in the full elevation: they
			# conceal the load-bearing bough and overlap the central trunk instead
			# of adding more leaves to already-dense child tips.
			for cover_index in 8:
				var cover_t := 0.02 + float(cover_index) * 0.135
				var cover_root: Vector3 = primary_transform * _blueprint_branch_point(cover_t)
				var cover_side := -1.0 if cover_index % 2 == 0 else 1.0
				var cover_lift := -0.10 + float(cover_index % 4) * 0.07 \
					+ (0.02 if cover_index >= 4 else 0.0)
				var cover_direction := (direction * 0.94 + tangent * cover_side * 0.20 \
					+ Vector3.UP * cover_lift).normalized()
				var cover_length := maxf(primary_length * 0.18, 11.5) \
					* (0.90 if cover_index % 2 == 1 else 1.0)
				var cover_girth := maxf(thickness * 0.17, 0.34)
				var cover_basis := _blueprint_x_basis(cover_direction) * Basis.from_scale(
					Vector3(cover_length / 4.0, cover_girth, cover_girth))
				var cover_transform := Transform3D(cover_basis, cover_root)
				twig_transforms.append(cover_transform)
				visible_leaf_counts.append(0)
				twig_leaf_refs.append([])
				twig_socket_pairs.append(cover_root)
				twig_socket_pairs.append(cover_transform.origin)
				_blueprint_append_twig_leaves(leaf_family_transforms,
					cover_transform, twig_transforms.size() - 1,
					roundi(crown_t * 8.0), leaf_socket_pairs, leaf_direction_pairs,
					visible_leaf_counts, twig_leaf_refs)

	# The heart aperture intentionally removes a small number of leaves. If every
	# leaf on a twig falls inside that aperture, or fewer than four remain, hide
	# that complete twig-and-leaf unit too. This prevents both bare sticks and
	# implausible one-leaf stems along the edge of the protected crystal opening.
	var hidden_leafless_twigs := 0
	var minimum_visible_leaves := 8
	for twig_index in twig_transforms.size():
		var visible_count := visible_leaf_counts[twig_index]
		if visible_count < 4:
			var hidden_transform := twig_transforms[twig_index]
			hidden_transform.basis = Basis.from_scale(Vector3.ZERO)
			twig_transforms[twig_index] = hidden_transform
			for leaf_ref_value in twig_leaf_refs[twig_index] as Array:
				var leaf_ref := leaf_ref_value as Dictionary
				var family_name := str(leaf_ref.family)
				var family_array: Array[Transform3D] = leaf_family_transforms[family_name]
				var leaf_transform := family_array[int(leaf_ref.index)]
				leaf_transform.basis = Basis.from_scale(Vector3.ZERO)
				family_array[int(leaf_ref.index)] = leaf_transform
				leaf_family_transforms[family_name] = family_array
			visible_leaf_counts[twig_index] = 0
			hidden_leafless_twigs += 1
		else:
			minimum_visible_leaves = mini(minimum_visible_leaves, visible_count)

	var wood := _create_reference_tree_wood_palette()[2]
	var flow_material := _create_tree_sap_flow_material()
	var leaf_socket_gold := _make_glow(Color("e3b84f"), 0.30)
	leaf_socket_gold.metallic = 0.84
	leaf_socket_gold.roughness = 0.22
	var primary_batch := _blueprint_add_multimesh(canopy,
		"PoweredBranchStructureBatch", _blueprint_two_surface_mesh(
			_blueprint_branch_mesh(1.0), wood,
			_blueprint_energy_mesh(10.0, 1.0), flow_material),
		primary_transforms, null)
	primary_batch.set_meta("embedded_energy_routes", primary_transforms.size())
	var child_batch := _blueprint_add_multimesh(canopy,
		"BlueprintChildBoughBatch", _blueprint_two_surface_mesh(
			_blueprint_branch_mesh(0.72), wood,
			_blueprint_energy_mesh(10.0, 0.72), flow_material),
		child_transforms, null)
	child_batch.set_meta("embedded_energy_routes", child_transforms.size())
	var twig_batch := _blueprint_add_multimesh(canopy,
		"BlueprintTwigFanBatch", _blueprint_two_surface_mesh(
			_blueprint_twig_fan_mesh(), wood,
			_blueprint_twig_energy_mesh(), flow_material),
		twig_transforms, null)
	twig_batch.set_meta("embedded_energy_routes", twig_transforms.size())
	var twig_gold_batch := _blueprint_add_multimesh(canopy,
		"BlueprintTwigGoldRuneBandBatch",
		_blueprint_twig_gold_band_mesh(leaf_socket_gold),
		twig_transforms, null, false)
	twig_gold_batch.set_meta("bands_per_twig", 3)
	twig_gold_batch.set_meta("gold_band_instances", twig_transforms.size())
	twig_gold_batch.set_meta("surface_seated", true)
	var junction_mesh := SphereMesh.new()
	junction_mesh.radius = 1.0
	junction_mesh.height = 2.0
	junction_mesh.radial_segments = 6
	junction_mesh.rings = 3
	var branch_junction_batch := _blueprint_add_multimesh(canopy,
		"BranchEnergyJunctionBatch", junction_mesh,
		branch_energy_junction_transforms, flow_material, false)
	branch_junction_batch.set_meta("junction_count",
		branch_energy_junction_transforms.size())
	branch_junction_batch.set_meta("connects_trunk_to_every_primary_bough", true)
	branch_junction_batch.set_meta("maximum_surface_gap", 0.0)
	var leaf_mesh_style := _tree_leaf_mesh_style()
	var leaf_style_script := _tree_leaf_style_script(leaf_mesh_style)
	var leaf_petiole_instances := 0
	for family in leaf_family_transforms:
		var family_material := _leaf_family_material(family)
		var source_transforms: Array[Transform3D] = leaf_family_transforms[family]
		for source_transform in source_transforms:
			if source_transform.basis.get_scale().length_squared() < 0.0001:
				heart_niche_culled_leaf_instances += 1
		var render_transforms: Array[Transform3D] = leaf_style_script.prepare_transforms(
			source_transforms)
		var leaf_and_socket_mesh := _blueprint_merge_materialized_meshes([
			_blueprint_leaf_mesh(leaf_mesh_style, family, family_material),
			_blueprint_leaf_petiole_socket_mesh(wood, leaf_socket_gold),
		])
		var leaf_batch := _blueprint_add_multimesh(canopy,
			"PoweredLeafBatch_%s" % family,
			leaf_and_socket_mesh,
			render_transforms, null, false)
		var logical_leaf_cards := source_transforms.size()
		leaf_batch.set_meta("leaf_cards_per_instance",
			logical_leaf_cards / maxi(1, render_transforms.size()))
		leaf_batch.set_meta("leaf_cluster_instances", render_transforms.size())
		leaf_batch.set_meta("leaf_mesh_style", leaf_mesh_style)
		leaf_batch.set_meta("volumetric_leaf_mesh", true)
		leaf_batch.set_meta("logical_leaf_cards", logical_leaf_cards)
		leaf_batch.set_meta("leaf_family", family)
		leaf_batch.set_meta("petiole_instances", render_transforms.size())
		leaf_batch.set_meta("tail_socket_local", Vector3.ZERO)
		leaf_batch.set_meta("gold_design", "three_notch_rune_sleeve")
		leaf_batch.set_meta("wood_and_gold_share_leaf_transform", true)
		leaf_batch.set_meta("leaf_and_socket_single_instance", true)
		leaf_petiole_instances += render_transforms.size()
	_build_blueprint_gold_collars(canopy, primary_transforms, child_transforms)
	_build_blueprint_crown_star(canopy)
	canopy.set_meta("tier_count", 9)
	canopy.set_meta("growth_band_count", tier_specs.size())
	canopy.set_meta("interwhorl_boughs", 51)
	canopy.set_meta("tier_bough_counts", PackedInt32Array([24, 24, 20, 20, 16, 16, 12, 8, 4]))
	canopy.set_meta("tier_heights_metres", PackedFloat32Array(
		[14.0, 27.0, 40.0, 53.0, 66.0, 79.0, 92.0, 105.0, 118.0]))
	canopy.set_meta("tier_reaches_metres", PackedFloat32Array(
		[42.0, 38.0, 34.0, 30.0, 25.5, 21.0, 16.5, 12.0, 7.0]))
	canopy.set_meta("reference_size_multiplier", 2.0)
	canopy.set_meta("foliage_masks_central_trunk", true)
	canopy.set_meta("inner_child_fork_fraction", 0.04)
	canopy.set_meta("minimum_twig_length", 10.35)
	canopy.set_meta("inner_leaf_cover_twig_fraction", 0.02)
	canopy.set_meta("foliage_density_multiplier", 2.0)
	canopy.set_meta("primary_socket_pairs", primary_socket_pairs)
	canopy.set_meta("child_socket_pairs", child_socket_pairs)
	canopy.set_meta("twig_socket_pairs", twig_socket_pairs)
	canopy.set_meta("leaf_socket_pairs", leaf_socket_pairs)
	canopy.set_meta("leaf_direction_pairs", leaf_direction_pairs)
	canopy.set_meta("major_boughs", primary_transforms.size())
	canopy.set_meta("child_boughs", child_transforms.size())
	canopy.set_meta("twig_fans", twig_transforms.size())
	canopy.set_meta("total_bough_modules", primary_transforms.size() + child_transforms.size())
	canopy.set_meta("estimated_leaf_cards", TREE_BLUEPRINT_LEAVES)
	canopy.set_meta("leaf_cards", TREE_BLUEPRINT_LEAVES)
	canopy.set_meta("leaf_mesh_style", leaf_mesh_style)
	canopy.set_meta("leaf_source_asset", GravityLeafReliefStyle.source_asset()
		if leaf_mesh_style == "gravity_leaf_relief" else "runtime_leaf_style_script")
	canopy.set_meta("leaf_closeup_geometry", "crossed_folded_rgba_relief_cluster")
	canopy.set_meta("leaf_triangles_per_instance", 8)
	canopy.set_meta("leaf_texture_filter", "anisotropic_mipmapped")
	canopy.set_meta("leaf_alpha_mode", "alpha_scissor")
	canopy.set_meta("branch_radial_segments", 9)
	canopy.set_meta("twig_radial_segments", 6)
	canopy.set_meta("natural_branch_collars", true)
	canopy.set_meta("available_leaf_mesh_styles",
		PackedStringArray(["gravity_leaf_relief", "faceted_pod", "blossom_bud_cluster"]))
	canopy.set_meta("nature_leaf_cards", 14040)
	canopy.set_meta("magic_leaf_cards", 9360)
	canopy.set_meta("technology_leaf_cards", 4680)
	canopy.set_meta("solar_leaf_cards", 9360)
	canopy.set_meta("max_major_attachment_gap", 0.0)
	canopy.set_meta("max_child_attachment_gap", 0.0)
	canopy.set_meta("max_twig_attachment_gap", 0.0)
	canopy.set_meta("max_leaf_attachment_gap", 0.0)
	canopy.set_meta("energy_routes_share_wood_centerlines", true)
	canopy.set_meta("maximum_energy_surface_gap", 0.0)
	canopy.set_meta("twig_energy_routes_per_fan", 1)
	canopy.set_meta("branch_energy_junctions", branch_energy_junction_transforms.size())
	canopy.set_meta("root_to_every_branch_energy_continuity", true)
	canopy.set_meta("gravity_shaped_branch_curvature", true)
	canopy.set_meta("leaf_orientation_source", "gravity_leaf_bough.leaf_matrix")
	canopy.set_meta("leaf_orientation_pattern", "alternating_side_terminal_forward")
	canopy.set_meta("leaf_forward_axis", "local_positive_x_tail_to_tip")
	canopy.set_meta("leaf_orientation_frame", "twig_tangent_plus_gravity_up")
	canopy.set_meta("maximum_leaf_roll_degrees", 0.0)
	canopy.set_meta("leaf_socket_pivots_aligned_to_twig", true)
	canopy.set_meta("leaf_tail_is_mesh_origin", true)
	canopy.set_meta("leaf_orientation_randomized", false)
	canopy.set_meta("leaf_visible_tail_uv_alignment", "godot_top_origin_v_to_brass_cuff")
	canopy.set_meta("leaf_petiole_instances", leaf_petiole_instances)
	canopy.set_meta("heart_niche_culled_leaf_instances",
		heart_niche_culled_leaf_instances)
	canopy.set_meta("heart_niche_hidden_leafless_twigs", hidden_leafless_twigs)
	canopy.set_meta("visible_small_branches_without_leaves", 0)
	canopy.set_meta("minimum_visible_leaves_per_visible_twig", minimum_visible_leaves)
	canopy.set_meta("small_branch_leaf_visibility_audited", true)
	canopy.set_meta("heart_frame_visibility_preserved", true)
	canopy.set_meta("leaf_gold_socket_sleeves", leaf_petiole_instances)
	canopy.set_meta("leaf_petiole_attachment_gap", 0.0)
	canopy.set_meta("leaf_cuff_girth_drives_twig_floor", true)
	canopy.set_meta("leaf_socket_gold_design", "three_notch_rune_sleeve")
	canopy.set_meta("twig_gold_rune_bands", twig_transforms.size() * 3)
	canopy.set_meta("twig_gold_bands_follow_surface", true)
	canopy.set_meta("leaf_fit_phase", "reference_hierarchy_complete")
	canopy.set_meta("leaf_bearing_stems_per_twig_instance", 1)
	canopy.set_meta("leaves_per_twig", 8)
	# Coverage is derived from the hierarchy rather than judged from instance
	# density: every major bough owns two children with eight leaf twigs each,
	# plus eight close-cover twigs on the major itself. Each twig receives the
	# complete eight-socket August leaf pattern.
	var logical_leaf_total := 0
	for family_transforms in leaf_family_transforms.values():
		logical_leaf_total += (family_transforms as Array).size()
	var expected_leaf_total := twig_transforms.size() * 8
	canopy.set_meta("branch_leaf_coverage_complete",
		logical_leaf_total == expected_leaf_total)
	canopy.set_meta("branch_leaf_coverage_audited", true)
	canopy.set_meta("minimum_leaves_per_leaf_twig", 8)
	canopy.set_meta("leaf_twigs_per_child_bough", 8)
	canopy.set_meta("direct_cover_twigs_per_primary_bough", 8)
	canopy.set_meta("leaf_twigs_per_primary_hierarchy", 24)
	canopy.set_meta("logical_leaves_per_primary_hierarchy", 192)
	canopy.set_meta("logical_leaf_total_from_branch_hierarchy", logical_leaf_total)
	canopy.set_meta("attachment_hierarchy",
		"major_bough -> primary cover twig or alternating lateral -> leaf twig -> eight socket leaves")
	canopy.set_meta("gravity_direction", Vector3.DOWN)
	canopy.set_meta("primary_pitch_range_degrees", Vector2(-8.0, 9.0))
	canopy.set_meta("twig_gravity_lift_range", Vector2(-0.55, 0.65))
	canopy.set_meta("leaf_gravity_pitch_range_degrees", Vector2(-35.0, -10.0))
	canopy.set_meta("branches_and_leaves_share_gravity", true)
	canopy.set_meta("christmas_tree_taper_ratio", 0.65625)
	canopy.set_meta("single_dominant_leader", true)
	canopy.set_meta("uniform_whorl_spacing", true)
	canopy.set_meta("interwhorl_foliage_overlap", true)
	canopy.set_meta("distal_tip_gravitropic_recovery", true)
	canopy.set_meta("crown_design_basis",
		"extension_guided_christmas_tree_cone_plus_conifer_gravitropism")

	tree.set_meta("canopy_source", "complete_architecture_blueprint_v1")
	tree.set_meta("canopy_silhouette", "wide_bottom_tapered_christmas_tree")
	tree.set_meta("tree_graphics_profile", "laptop_low")
	tree.set_meta("original_branch_system_restored", false)
	tree.set_meta("original_foliage_systems_restored", false)
	tree.set_meta("gravity_bough_major_branches", primary_transforms.size())
	tree.set_meta("gravity_bough_child_branches", child_transforms.size())
	tree.set_meta("gravity_bough_total_modules", primary_transforms.size() + child_transforms.size())
	tree.set_meta("gold_star_preserved", true)


func _blueprint_x_basis(direction: Vector3) -> Basis:
	var axis_x := direction.normalized()
	var axis_z := axis_x.cross(Vector3.UP)
	if axis_z.length_squared() < 0.001:
		axis_z = axis_x.cross(Vector3.FORWARD)
	axis_z = axis_z.normalized()
	var axis_y := axis_z.cross(axis_x).normalized()
	return Basis(axis_x, axis_y, axis_z)


func _blueprint_y_basis(direction: Vector3) -> Basis:
	# Torus meshes use local Y as their ring normal. Aligning that axis to a root
	# tangent seats a growth collar around the wood instead of beside it.
	var axis_y := direction.normalized()
	var axis_x := Vector3.UP.cross(axis_y)
	if axis_x.length_squared() < 0.001:
		axis_x = Vector3.FORWARD.cross(axis_y)
	axis_x = axis_x.normalized()
	var axis_z := axis_x.cross(axis_y).normalized()
	return Basis(axis_x, axis_y, axis_z)


func _blueprint_leaf_basis(forward: Vector3, blade_normal: Vector3) -> Basis:
	# Local +X is the biological stem-to-tip axis used by every leaf style.
	# Construct the other axes from the supporting twig and gravity instead of
	# applying an arbitrary object roll. This keeps the blade readable from above
	# while its narrow tail continues away from the exact bark socket.
	var axis_x := forward.normalized()
	var axis_y := blade_normal - axis_x * axis_x.dot(blade_normal)
	if axis_y.length_squared() < 0.001:
		axis_y = Vector3.UP - axis_x * axis_x.y
	if axis_y.length_squared() < 0.001:
		axis_y = Vector3.FORWARD
	axis_y = axis_y.normalized()
	var axis_z := axis_x.cross(axis_y).normalized()
	axis_y = axis_z.cross(axis_x).normalized()
	return Basis(axis_x, axis_y, axis_z)


func _blueprint_branch_point(travel: float) -> Vector3:
	var t := clampf(travel, 0.0, 1.0)
	# August gravity-bough profile: a living branch rises out of its graft,
	# carries its load through a shallow arch, then sags progressively toward
	# the tip. A small lateral bow avoids ruler-straight procedural branches.
	return Vector3(t * 10.0,
		sin(t * PI) * 0.45 - t * t * 1.60 + pow(t, 6.0) * 0.80,
		sin(t * PI) * 0.30 + sin(t * TAU) * 0.14)


func _blueprint_branch_radius(travel: float, radius_scale: float) -> float:
	var t := clampf(travel, 0.0, 1.0)
	# A real bough swells into a branch collar before tapering. The flare also
	# gives close cameras a continuous wood junction rather than a butt seam.
	var collar_flare := 1.0 + 0.22 * pow(1.0 - t, 5.0)
	return lerpf(1.0, 0.20, pow(t, 0.82)) * radius_scale * collar_flare


func _blueprint_branch_mesh(radius_scale: float) -> ArrayMesh:
	var points: Array[Vector3] = []
	var radii: Array[float] = []
	for point_index in 6:
		var travel := float(point_index) / 5.0
		points.append(_blueprint_branch_point(travel))
		radii.append(_blueprint_branch_radius(travel, radius_scale))
	return _build_poly_tube_mesh(points, radii, 9)


func _blueprint_energy_mesh(length: float, radius_scale: float) -> ArrayMesh:
	var points: Array[Vector3] = []
	var radii: Array[float] = []
	for point_index in 6:
		var travel := float(point_index) / 5.0
		var point := _blueprint_branch_point(travel)
		point.x *= length / 10.0
		# Follow the wood centreline exactly. The radial offset shrinks with the
		# same taper as the bark, keeping the fiber seated from graft to tip.
		var wood_radius := _blueprint_branch_radius(travel, radius_scale)
		point.y += wood_radius * 0.76
		points.append(point)
		radii.append(maxf(0.025, wood_radius * 0.10))
	return _build_poly_tube_mesh(points, radii, 6)


func _blueprint_two_surface_mesh(first: Mesh, first_material: Material,
		second: Mesh, second_material: Material) -> ArrayMesh:
	# Wood and its energy vein share one MultiMesh transform. Separate surfaces
	# retain their materials without doubling the submitted instance count.
	var combined := ArrayMesh.new()
	for surface_index in first.get_surface_count():
		combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
			first.surface_get_arrays(surface_index))
		combined.surface_set_material(combined.get_surface_count() - 1,
			first_material)
	for surface_index in second.get_surface_count():
		combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
			second.surface_get_arrays(surface_index))
		combined.surface_set_material(combined.get_surface_count() - 1,
			second_material)
	return combined


func _blueprint_merge_materialized_meshes(meshes: Array) -> ArrayMesh:
	# Preserve each source surface material while sharing one MultiMesh transform.
	# A leaf, its wood petiole and its gold cuff consequently cost one instance
	# instead of two, while all three remain locked to the measured socket.
	var combined := ArrayMesh.new()
	for source_value in meshes:
		var source := source_value as Mesh
		if source == null:
			continue
		for surface_index in source.get_surface_count():
			combined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
				source.surface_get_arrays(surface_index))
			combined.surface_set_material(combined.get_surface_count() - 1,
				source.surface_get_material(surface_index))
	return combined


func _blueprint_twig_path_point(travel: float) -> Vector3:
	var t := clampf(travel, 0.0, 1.0)
	# One continuous leaf-bearing twig, matching the supplied gravity-bough
	# hierarchy. It rises gently out of the lateral and yields under leaf load.
	return Vector3(t * 4.0,
		sin(t * PI) * 0.18 - t * t * 0.28,
		sin(t * PI * 0.72) * 0.12)


func _blueprint_twig_radius(travel: float) -> float:
	var t := clampf(travel, 0.0, 1.0)
	return lerpf(0.30, 0.14, t) * (1.0 + 0.18 * pow(1.0 - t, 4.0))


func _blueprint_twig_fan_mesh() -> ArrayMesh:
	var fan := ArrayMesh.new()
	var points: Array[Vector3] = []
	var radii: Array[float] = []
	for point_index in 6:
		var travel := float(point_index) / 5.0
		points.append(_blueprint_twig_path_point(travel))
		radii.append(_blueprint_twig_radius(travel))
	var stem_mesh := _build_poly_tube_mesh(points, radii, 7)
	fan.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
		stem_mesh.surface_get_arrays(0))
	return fan


func _blueprint_twig_energy_mesh() -> ArrayMesh:
	# One bark-hugging fiber follows the single leaf-bearing twig centreline.
	var fan := ArrayMesh.new()
	var points: Array[Vector3] = []
	var radii: Array[float] = []
	for point_index in 6:
		var travel := float(point_index) / 5.0
		var wood_radius := _blueprint_twig_radius(travel)
		var point := _blueprint_twig_path_point(travel)
		point.y += wood_radius * 0.78
		points.append(point)
		radii.append(maxf(0.014, wood_radius * 0.13))
	var fiber_mesh := _build_poly_tube_mesh(points, radii, 5)
	fan.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
		fiber_mesh.surface_get_arrays(0))
	return fan


func _blueprint_twig_gold_band_mesh(gold: Material) -> ArrayMesh:
	# Three short collars wrap the curved twig at fixed growth nodes. Each collar
	# uses the same path equation and local radius as the bark, so it cannot float
	# when the complete twig transform bends, rotates, or scales between tiers.
	var bands := ArrayMesh.new()
	for travel in [0.12, 0.52, 0.90]:
		var points: Array[Vector3] = [
			_blueprint_twig_path_point(travel - 0.014),
			_blueprint_twig_path_point(travel + 0.014),
		]
		var band_radius := _blueprint_twig_radius(travel) * 1.18
		var radii: Array[float] = [band_radius, band_radius]
		var band := _build_poly_tube_mesh(points, radii, 8)
		bands.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
			band.surface_get_arrays(0))
		bands.surface_set_material(bands.get_surface_count() - 1, gold)
	return bands


func _blueprint_leaf_petiole_socket_mesh(wood: Material, gold: Material) -> ArrayMesh:
	# One reusable connector is instanced with every leaf transform. Its -X end
	# enters the twig, local zero is the measured outer cuff edge, and the short
	# +X overlap disappears beneath the painted stem. This guarantees visible
	# wood continuity without adding a unique mesh for each of 18,720 leaves.
	var petiole_points: Array[Vector3] = [
		Vector3(-0.62, 0.0, 0.0), Vector3(-0.30, 0.0, 0.0),
		Vector3(0.08, 0.0, 0.0),
	]
	var petiole_radii: Array[float] = [0.085, 0.115, 0.095]
	# Four radial sides are enough at this tiny screen size and cut connector
	# geometry substantially across tens of thousands of instanced leaves.
	var petiole := _build_poly_tube_mesh(petiole_points, petiole_radii, 4)
	# Alternating radii form three compact engraved-looking bands. They remain
	# physically wrapped around the petiole, unlike free-floating ornament rings.
	var sleeve_points: Array[Vector3] = [
		Vector3(-0.22, 0.0, 0.0), Vector3(-0.16, 0.0, 0.0),
		Vector3(-0.10, 0.0, 0.0), Vector3(-0.04, 0.0, 0.0),
		Vector3(0.02, 0.0, 0.0), Vector3(0.08, 0.0, 0.0),
	]
	var sleeve_radii: Array[float] = [0.145, 0.172, 0.148, 0.172, 0.148, 0.145]
	var sleeve := _build_poly_tube_mesh(sleeve_points, sleeve_radii, 4)
	return _blueprint_two_surface_mesh(petiole, wood, sleeve, gold)


func _tree_leaf_mesh_style() -> String:
	var requested := OS.get_environment("ARTEA_TREE_LEAF_STYLE").strip_edges().to_lower()
	if requested in ["gravity_leaf_relief", "faceted_pod", "blossom_bud_cluster"]:
		return requested
	return "gravity_leaf_relief"


func _tree_leaf_style_script(style: String) -> Script:
	if style == "gravity_leaf_relief":
		return GravityLeafReliefStyle
	return BlossomBudClusterLeafStyle if style == "blossom_bud_cluster" \
		else FacetedPodLeafStyle


func _blueprint_leaf_mesh(style: String, family: String,
		family_material: StandardMaterial3D) -> Mesh:
	if style == "gravity_leaf_relief":
		return GravityLeafReliefStyle.build_mesh(family, family_material)
	return _tree_leaf_style_script(style).build_mesh(family_material)


func _blueprint_append_twig_leaves(families: Dictionary,
		twig_transform: Transform3D, fan_index: int, tier_index: int,
		leaf_socket_pairs: PackedVector3Array,
		leaf_direction_pairs: PackedVector3Array,
		visible_leaf_counts: Array[int] = [], twig_leaf_refs: Array = []) -> void:
	# This is the exact authored August hierarchy: one twig with eight alternating
	# bases from 17% to 94%, and its final two leaves continue toward the bud.
	var family_pattern := PackedStringArray([
		"living_leaf_fan", "magic_rune_leaf", "solar_glass_science_leaf",
		"living_leaf_fan", "emerald_sensor_leaf", "magic_rune_leaf",
		"living_leaf_fan", "solar_glass_science_leaf",
	])
	var family_scale := {
		"living_leaf_fan": 1.00,
		"magic_rune_leaf": 0.93,
		"solar_glass_science_leaf": 0.90,
		"emerald_sensor_leaf": 0.74,
	}
	for leaf_rank in 8:
		# Cover the complete twig, including the formerly bare inner seventeenth.
		# The eighth leaf still terminates at 99% beside the bud.
		var travel := 0.08 + float(leaf_rank) * 0.13
		var leaf_side := -1.0 if leaf_rank % 2 == 0 else 1.0
		# Seat the visible tail on the twig surface. Alternating local Z offsets
		# correspond to the two biological sides of one leaf-bearing stem.
		var twig_radius := _blueprint_twig_radius(travel)
		var local_socket := _blueprint_twig_path_point(travel) + Vector3(
			0.0, twig_radius * 0.18, leaf_side * twig_radius * 0.84)
		var expected_socket: Vector3 = twig_transform * local_socket
		var before := _blueprint_twig_path_point(maxf(0.0, travel - 0.02))
		var after := _blueprint_twig_path_point(minf(1.0, travel + 0.02))
		var local_tangent := (after - before).normalized()
		var world_tangent := (twig_transform.basis * local_tangent).normalized()
		var across := world_tangent.cross(Vector3.UP)
		if across.length_squared() < 0.001:
			across = Vector3.FORWARD
		across = across.normalized()
		var is_terminal := leaf_rank >= 6
		var crown_t := clampf(float(tier_index) / 8.0, 0.0, 1.0)
		var desired := (world_tangent * (1.08 if is_terminal else 0.98) \
			+ across * leaf_side * (0.16 if is_terminal else 0.24) \
			+ Vector3.DOWN * (0.08 + 0.16 * crown_t)).normalized()
		# The small deterministic cant follows the selected side of the twig. The
		# blade normal stays mostly up, preventing sideways flips under the canopy.
		var blade_normal := (Vector3.UP + across * leaf_side * 0.12).normalized()
		var placed := Transform3D(
			_blueprint_leaf_basis(desired, blade_normal), expected_socket)
		var size_variation := lerpf(0.92, 1.08,
			float((leaf_rank * 37 + fan_index * 19) % 101) / 100.0)
		var family := family_pattern[leaf_rank]
		# The blueprint tree is 4.2x landmark scale. Preserve the source bough's
		# leaf-to-twig proportion after that enlargement without multiplying count.
		var leaf_scale := lerpf(4.55, 3.15, crown_t) * size_variation \
			* float(family_scale[family])
		placed.basis = placed.basis.scaled(Vector3.ONE * leaf_scale)
		# Preserve a calm, screen-facing niche around the heart. A zero basis keeps
		# the fixed MultiMesh allocation and laptop memory contract while culling
		# only foliage whose socket would let the broadened relief cross the frame.
		var heart_niche_half_width := HEART_SHRINE_FRAME_RADIUS \
			* HEART_SHRINE_SCALE * TREE_OF_LIFE_BODY_RATIO * 1.55
		var heart_niche_half_height := HEART_SHRINE_FRAME_RADIUS \
			* HEART_SHRINE_OVAL_STRETCH * HEART_SHRINE_SCALE \
			* TREE_OF_LIFE_BODY_RATIO * 1.42
		if absf(expected_socket.x) < heart_niche_half_width \
				and absf(expected_socket.y - TREE_BLUEPRINT_HEART_HEIGHT) \
				< heart_niche_half_height:
			placed.basis = Basis.from_scale(Vector3.ZERO)
		elif fan_index < visible_leaf_counts.size():
			visible_leaf_counts[fan_index] += 1
		var output: Array[Transform3D] = families[family]
		var family_transform_index := output.size()
		output.append(placed)
		families[family] = output
		if fan_index < twig_leaf_refs.size():
			(twig_leaf_refs[fan_index] as Array).append({
				"family": family,
				"index": family_transform_index,
			})
		leaf_socket_pairs.append(expected_socket)
		leaf_socket_pairs.append(placed.origin)
		leaf_direction_pairs.append(expected_socket + desired)
		leaf_direction_pairs.append(placed.origin + desired)


func _blueprint_add_multimesh(parent: Node3D, batch_name: String,
		mesh: Mesh, transforms: Array[Transform3D], material: Material,
		cast_shadow := true) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for instance_index in transforms.size():
		multimesh.set_instance_transform(instance_index, transforms[instance_index])
	var batch := MultiMeshInstance3D.new()
	batch.name = batch_name
	batch.multimesh = multimesh
	if material != null:
		batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.set_meta("module_instances", transforms.size())
	batch.set_meta("growth_layers", 1)
	batch.set_meta("lightweight_lod", true)
	parent.add_child(batch)
	return batch


func _build_blueprint_gold_collars(canopy: Node3D,
		primary_transforms: Array[Transform3D],
		child_transforms: Array[Transform3D]) -> void:
	var collar_mesh := TorusMesh.new()
	collar_mesh.inner_radius = 0.58
	collar_mesh.outer_radius = 0.88
	collar_mesh.rings = 8
	collar_mesh.ring_segments = 4
	var collar_transforms: Array[Transform3D] = []
	for source in [primary_transforms, child_transforms]:
		for branch_transform in source:
			var branch := branch_transform as Transform3D
			var direction := branch.basis.x.normalized()
			var axis_x := Vector3.UP.cross(direction)
			if axis_x.length_squared() < 0.001:
				axis_x = Vector3.RIGHT
			axis_x = axis_x.normalized()
			var axis_z := axis_x.cross(direction).normalized()
			var thickness := branch.basis.y.length()
			collar_transforms.append(Transform3D(
				Basis(axis_x, direction, axis_z).scaled(Vector3.ONE * thickness),
				branch.origin))
	var gold := _make_glow(Color("e3b84f"), 0.38)
	gold.metallic = 0.78
	gold.roughness = 0.24
	var batch := _blueprint_add_joined_mesh(canopy, "PoweredBranchGoldCollarBatch",
		collar_mesh, collar_transforms, gold)
	batch.set_meta("collar_instances", collar_transforms.size())
	canopy.set_meta("gold_branch_collar_instances", collar_transforms.size())


func _build_blueprint_crown_star(canopy: Node3D) -> void:
	# A flat, double-sided eight-point face reinforces the preserved authored
	# WisdomStar so the logo still reads at the normal gameplay camera distance.
	var vertices := PackedVector3Array([Vector3.ZERO])
	var normals := PackedVector3Array([Vector3.FORWARD])
	var indices := PackedInt32Array()
	var points := 16
	for point_index in points:
		var angle := PI * 0.5 - TAU * float(point_index) / float(points)
		var radius := 15.5 if point_index % 2 == 0 else 6.3
		vertices.append(Vector3(cos(angle) * radius, sin(angle) * radius, 0.0))
		normals.append(Vector3.FORWARD)
	for point_index in points:
		indices.append_array(PackedInt32Array([
			0, point_index + 1, ((point_index + 1) % points) + 1,
		]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var star_mesh := ArrayMesh.new()
	star_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var star := MeshInstance3D.new()
	star.name = "BlueprintGoldCrownStar"
	star.mesh = star_mesh
	star.position = Vector3(0.0, TREE_BLUEPRINT_STAR_HEIGHT, 0.0)
	var gold := _make_glow(Color("f6c84d"), 1.25)
	gold.metallic = 0.82
	gold.roughness = 0.18
	gold.cull_mode = BaseMaterial3D.CULL_DISABLED
	star.material_override = gold
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.set_meta("logo_source", "authored_wisdom_star_eight_point_profile")
	var depth_face := MeshInstance3D.new()
	depth_face.name = "BlueprintGoldCrownStarDepthFace"
	depth_face.mesh = star_mesh
	depth_face.rotation.y = PI * 0.5
	depth_face.material_override = gold
	depth_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	star.add_child(depth_face)
	canopy.add_child(star)
	canopy.set_meta("gold_crown_star_instances", 1)


func _reshape_original_canopy_mesh(source_mesh: Mesh, base_scale: float,
		tip_scale: float, height_scale: float) -> ArrayMesh:
	# Deform the old combined Blender systems rather than replacing them. Each
	# vertex keeps its authored branch/leaf relationship; only its distance from
	# the trunk changes according to height. The low crown widens and the high
	# crown contracts, turning the old umbrella profile into a fir taper.
	var bounds := source_mesh.get_aabb()
	var bottom := bounds.position.y
	var span := maxf(bounds.size.y, 0.001)
	var result := ArrayMesh.new()
	for surface_index in source_mesh.get_surface_count():
		var arrays := source_mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for vertex_index in vertices.size():
			var vertex := vertices[vertex_index]
			var progress := clampf((vertex.y - bottom) / span, 0.0, 1.0)
			# Smooth interpolation avoids a pinched belt in the middle tiers.
			var eased := progress * progress * (3.0 - 2.0 * progress)
			var radial := lerpf(base_scale, tip_scale, eased)
			vertices[vertex_index] = Vector3(
				vertex.x * radial,
				bottom + (vertex.y - bottom) * height_scale,
				vertex.z * radial)
			if vertex_index < normals.size():
				var normal := normals[vertex_index]
				normals[vertex_index] = Vector3(
					normal.x / maxf(radial, 0.01),
					normal.y / height_scale,
					normal.z / maxf(radial, 0.01)).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		if not normals.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = normals
		result.add_surface_from_arrays(source_mesh.surface_get_primitive_type(surface_index), arrays)
		result.surface_set_name(result.get_surface_count() - 1,
			source_mesh.surface_get_name(surface_index))
	return result


func _create_reference_tree_wood_palette() -> Array[StandardMaterial3D]:
	# The supplied heart-tree reference is built from near-black cambium, warm
	# walnut ridges and narrow bronze highlights. Keeping every value below the
	# cyan sap makes the energy channels readable instead of bleaching the trunk.
	var palette: Array[StandardMaterial3D] = []
	for colour in [Color("2d1c12"), Color("54331d"), Color("80502b"), Color("b47a42")]:
		var material := _make_material(colour, 0.94)
		material.emission_enabled = true
		material.emission = colour.darkened(0.32)
		material.emission_energy_multiplier = 0.18
		palette.append(material)
	return palette


const REFERENCE_TRUNK_RIB_COUNT := 4
const REFERENCE_ROOT_FLARE_COUNT := 8
const REFERENCE_TRUNK_BAND_COUNT := 6


func _old_growth_trunk_center(height: float) -> Vector3:
	# Preserve the approved lower 60 m trunk exactly. Above it, continue the same
	# leader gently to the doubled crown instead of stretching the root/body.
	var original_progress := clampf(
		height / TREE_BLUEPRINT_ORIGINAL_CROWN_HEIGHT, 0.0, 1.0)
	var front_settle := lerpf(-22.0, 0.0,
		smoothstep(0.0, 0.42, original_progress))
	var original_center := Vector3(
		sin(original_progress * PI * 2.1) * 1.7, 0.0, front_settle)
	if height <= TREE_BLUEPRINT_ORIGINAL_CROWN_HEIGHT:
		return original_center
	var extension := inverse_lerp(TREE_BLUEPRINT_ORIGINAL_CROWN_HEIGHT,
		TREE_BLUEPRINT_CROWN_HEIGHT, height)
	var old_tip := Vector3(sin(PI * 2.1) * 1.7, 0.0, 0.0)
	return old_tip.lerp(Vector3.ZERO, smoothstep(0.0, 1.0, extension))


func _old_growth_trunk_radius(height: float) -> float:
	var progress := clampf(
		height / TREE_BLUEPRINT_ORIGINAL_CROWN_HEIGHT, 0.0, 1.0)
	if height <= TREE_BLUEPRINT_ORIGINAL_CROWN_HEIGHT:
		return lerpf(24.0, 4.6, pow(progress, 0.82))
	var extension := inverse_lerp(TREE_BLUEPRINT_ORIGINAL_CROWN_HEIGHT,
		TREE_BLUEPRINT_CROWN_HEIGHT, height)
	return lerpf(4.6, 1.8, smoothstep(0.0, 1.0, extension))


func _build_old_growth_trunk_body(tree: Node3D) -> void:
	var body := Node3D.new()
	body.name = "OldGrowthTrunkBody"
	body.set_meta("architecture", "paired_buttress_to_single_continuous_leader")
	body.set_meta("continuous_root_to_crown", true)
	body.set_meta("doorway_preserved", true)
	body.set_meta("primary_stems", 3)
	body.set_meta("branch_socket_model", "shared_tapered_trunk_surface")
	body.set_meta("blueprint_root_spread", TREE_BLUEPRINT_ROOT_RADIUS * 2.0)
	body.set_meta("blueprint_body_height", TREE_BLUEPRINT_BODY_HEIGHT)
	body.set_meta("blueprint_doorway_width", TREE_BLUEPRINT_DOOR_WIDTH)
	body.set_meta("blueprint_doorway_height", TREE_BLUEPRINT_DOOR_HEIGHT)
	tree.add_child(body)

	var wood := _create_reference_tree_wood_palette()
	_build_old_growth_root_system(body, wood)
	_build_blueprint_doorway_backdrop(body)
	var left_path := [
		Vector3(-27.5, 4.5, -22.0), Vector3(-27.0, 11.5, -20.0),
		Vector3(-24.5, 18.0, -16.0), Vector3(-19.5, 27.0, -10.5),
		Vector3(-11.5, 36.0, -5.5), Vector3(-4.0, 44.0, -2.0),
	]
	var right_path := [
		Vector3(27.5, 4.5, -21.0), Vector3(27.0, 12.0, -19.0),
		Vector3(24.0, 18.5, -15.0), Vector3(19.0, 27.5, -10.0),
		Vector3(11.0, 36.5, -5.0), Vector3(3.0, 44.5, -1.5),
	]
	var buttress_radii := [15.2, 14.1, 12.5, 10.4, 8.0, 6.0]
	for stem_index in 2:
		var stem := MeshInstance3D.new()
		stem.name = "OldGrowthButtressStem_%02d" % (stem_index + 1)
		stem.mesh = _build_poly_tube_mesh(
			left_path if stem_index == 0 else right_path, buttress_radii, 11)
		stem.material_override = wood[2 + stem_index]
		stem.set_meta("load_path", "root_flare_to_central_leader")
		body.add_child(stem)
	var depth_buttress := MeshInstance3D.new()
	depth_buttress.name = "OldGrowthDepthButtressStem"
	depth_buttress.mesh = _build_poly_tube_mesh([
		Vector3(0.0, 4.5, 25.0), Vector3(0.8, 11.5, 23.0),
		Vector3(-0.6, 18.0, 18.0), Vector3(0.7, 27.0, 11.0),
		Vector3(-0.4, 36.0, 5.0), Vector3(0.0, 44.0, 0.0),
	], buttress_radii, 11)
	depth_buttress.material_override = wood[1]
	depth_buttress.set_meta("load_path", "rear_root_flare_to_central_leader")
	body.add_child(depth_buttress)
	_build_old_growth_buttress_energy_network(body, left_path, right_path, buttress_radii)

	var heights := [TREE_BLUEPRINT_HEART_HEIGHT, 68.0, 88.0, 110.0, 133.0, 155.0,
		176.0, TREE_BLUEPRINT_BODY_HEIGHT, 205.0, 220.0,
		TREE_BLUEPRINT_ORIGINAL_CROWN_HEIGHT, 275.0, 320.0, 365.0, 410.0,
		TREE_BLUEPRINT_CROWN_HEIGHT]
	var leader_points: Array[Vector3] = []
	var leader_radii: Array[float] = []
	for height in heights:
		var point := _old_growth_trunk_center(height)
		point.y = height
		leader_points.append(point)
		leader_radii.append(_old_growth_trunk_radius(height))
	var leader := MeshInstance3D.new()
	leader.name = "OldGrowthCentralLeader"
	leader.mesh = _build_poly_tube_mesh(leader_points, leader_radii, 12)
	leader.material_override = wood[2]
	leader.set_meta("load_path", "doorway_arch_to_gold_star")
	leader.set_meta("supports_all_canopy_tiers", true)
	body.add_child(leader)

	# Three co-dominant wood flows wrap the leader like the fused stems of an old
	# tree. They overlap the main body at every height, so they add mass and bark
	# complexity without becoming separate poles.
	for flow_index in 3:
		var flow_points: Array[Vector3] = []
		var flow_radii: Array[float] = []
		for height in heights:
			var angle := TAU * float(flow_index) / 3.0 + float(height) * 0.012
			var centre := _old_growth_trunk_center(height)
			centre.y = height
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			flow_points.append(centre + radial * _old_growth_trunk_radius(height) * 0.43)
			flow_radii.append(maxf(1.0, _old_growth_trunk_radius(height) * 0.34))
		var flow := MeshInstance3D.new()
		flow.name = "OldGrowthCoDominantStem_%02d" % (flow_index + 1)
		flow.mesh = _build_poly_tube_mesh(flow_points, flow_radii, 9)
		flow.material_override = wood[1 + flow_index]
		flow.set_meta("fused_into_central_leader", true)
		body.add_child(flow)

	for ridge_index in 4:
		var ridge_points: Array[Vector3] = []
		var ridge_radii: Array[float] = []
		for height in heights:
			var angle: float = TAU * float(ridge_index) / 4.0 + float(height) * 0.018
			var centre := _old_growth_trunk_center(height)
			centre.y = height
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			ridge_points.append(centre + radial * _old_growth_trunk_radius(height) * 0.88)
			ridge_radii.append(maxf(0.45, _old_growth_trunk_radius(height) * 0.13))
		var ridge := MeshInstance3D.new()
		ridge.name = "OldGrowthBarkRidge_%02d" % (ridge_index + 1)
		ridge.mesh = _build_poly_tube_mesh(ridge_points, ridge_radii, 7)
		ridge.material_override = wood[3 if ridge_index % 2 == 0 else 1]
		body.add_child(ridge)

	# Broad knot bosses interrupt the otherwise clean leader silhouette. They are
	# deliberately sparse: old trees have recognisable scars, not repeated beads.
	for knot_spec in [
		{"height": 76.0, "angle": 0.35, "scale": Vector3(5.8, 3.8, 2.0)},
		{"height": 108.0, "angle": 2.45, "scale": Vector3(4.5, 3.0, 1.7)},
		{"height": 139.0, "angle": 4.70, "scale": Vector3(3.2, 2.2, 1.3)},
	]:
		var height := float(knot_spec.height)
		var angle := float(knot_spec.angle)
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var knot := MeshInstance3D.new()
		knot.name = "OldGrowthKnot_%03d" % int(height)
		var knot_mesh := SphereMesh.new()
		knot_mesh.radius = 1.0
		knot_mesh.height = 2.0
		knot_mesh.radial_segments = 8
		knot_mesh.rings = 4
		knot.mesh = knot_mesh
		var centre := _old_growth_trunk_center(height)
		centre.y = height
		knot.position = centre + radial * _old_growth_trunk_radius(height) * 0.92
		knot.scale = knot_spec.scale
		knot.material_override = wood[3]
		knot.set_meta("bark_detail", "aged_branch_scar")
		body.add_child(knot)


func _build_blueprint_doorway_backdrop(body: Node3D) -> void:
	# Recessed darkness at the north end of the open passage makes the exact
	# 6 m x 8 m south doorway legible without adding collision to the corridor.
	var half_width := TREE_BLUEPRINT_DOOR_WIDTH * 0.5
	var spring_y := TREE_BLUEPRINT_DOOR_HEIGHT * 0.62
	var vertices := PackedVector3Array([
		Vector3(0.0, TREE_BLUEPRINT_DOOR_HEIGHT * 0.46, 0.0),
		Vector3(-half_width, 0.0, 0.0),
		Vector3(half_width, 0.0, 0.0),
		Vector3(half_width, spring_y, 0.0),
	])
	for arc_index in 7:
		var angle := float(arc_index) / 6.0 * PI
		vertices.append(Vector3(cos(angle) * half_width,
			spring_y + sin(angle) * (TREE_BLUEPRINT_DOOR_HEIGHT - spring_y), 0.0))
	vertices.append(Vector3(-half_width, spring_y, 0.0))
	var normals := PackedVector3Array()
	for _vertex in vertices:
		normals.append(Vector3(0.0, 0.0, -1.0))
	var indices := PackedInt32Array()
	for boundary_index in range(1, vertices.size() - 1):
		indices.append_array(PackedInt32Array([0, boundary_index, boundary_index + 1]))
	indices.append_array(PackedInt32Array([0, vertices.size() - 1, 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var arch_mesh := ArrayMesh.new()
	arch_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var backdrop := MeshInstance3D.new()
	backdrop.name = "BlueprintDoorwayInterior"
	backdrop.mesh = arch_mesh
	backdrop.position = Vector3(0.0, 0.0, 7.0)
	var darkness := StandardMaterial3D.new()
	darkness.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	darkness.albedo_color = Color("07131c")
	darkness.cull_mode = BaseMaterial3D.CULL_DISABLED
	backdrop.material_override = darkness
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop.set_meta("visual_only", true)
	backdrop.set_meta("doorway_width", TREE_BLUEPRINT_DOOR_WIDTH)
	backdrop.set_meta("doorway_height", TREE_BLUEPRINT_DOOR_HEIGHT)
	body.add_child(backdrop)


func _build_old_growth_root_system(
		body: Node3D, wood: Array[StandardMaterial3D]) -> void:
	var roots := Node3D.new()
	roots.name = "OldGrowthRootSystem"
	roots.set_meta("architecture", "twelve_buttress_roots_with_two_rootlets_each")
	roots.set_meta("primary_roots", 12)
	roots.set_meta("secondary_rootlets", 24)
	roots.set_meta("max_attachment_gap", 0.0)
	roots.set_meta("doorway_corridor_preserved", true)
	body.add_child(roots)

	var energy_flow := _create_tree_sap_flow_material()
	var root_gold := _make_glow(Color("d6a43f"), 0.30)
	root_gold.metallic = 0.78
	root_gold.roughness = 0.30
	var root_gold_collar_transforms: Array[Transform3D] = []
	var root_gold_slash_paths: Array = []
	# No root points directly down the south doorway axis. The nearest front roots
	# divide left and right like the toes of a real buttress, preserving passage.
	var root_angles := [20.0, 45.0, 70.0, 110.0, 135.0, 160.0,
		200.0, 225.0, 240.0, 300.0, 315.0, 340.0]
	var minimum_south_clearance := INF
	var minimum_ground_clearance := INF
	var maximum_primary_attachment_gap := 0.0
	var maximum_rootlet_attachment_gap := 0.0
	for root_index in root_angles.size():
		var angle := deg_to_rad(float(root_angles[root_index]))
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := Vector3(-radial.z, 0.0, radial.x)
		var base_center := _old_growth_trunk_center(0.0)
		base_center.y = 0.0
		var sway := sin(float(root_index) * 2.17) * 2.1
		var primary_points := [
			base_center + radial * 20.0 + Vector3.UP * 6.0,
			base_center + radial * 29.0 + tangent * sway * 0.25 + Vector3.UP * 3.8,
			base_center + radial * 40.0 + tangent * sway * 0.55 + Vector3.UP * 1.8,
			base_center + radial * 49.0 + tangent * sway * 0.85 + Vector3.UP * 0.55,
			base_center + radial * 55.0 + tangent * sway + Vector3.UP * 0.10,
		]
		var primary_radii := [10.0, 8.6, 6.4, 3.7, 1.15]
		for point_index in primary_points.size():
			var grounded_point := primary_points[point_index] as Vector3
			grounded_point.y = maxf(grounded_point.y,
				float(primary_radii[point_index]) * 1.02)
			primary_points[point_index] = grounded_point
			minimum_ground_clearance = minf(minimum_ground_clearance,
				grounded_point.y - float(primary_radii[point_index]))
		maximum_primary_attachment_gap = maxf(maximum_primary_attachment_gap,
			maxf(0.0, (primary_points[0] as Vector3).distance_to(base_center)
				- _old_growth_trunk_radius(0.0) - float(primary_radii[0])))
		if radial.z < -0.5:
			var corridor_side := -1.0 if radial.x < 0.0 else 1.0
			for point_index in primary_points.size():
				var point := primary_points[point_index] as Vector3
				var minimum_x := TREE_BLUEPRINT_DOOR_WIDTH * 0.5 \
					+ float(primary_radii[point_index]) + 2.0
				point.x = corridor_side * maxf(absf(point.x), minimum_x)
				primary_points[point_index] = point
				minimum_south_clearance = minf(minimum_south_clearance,
					absf(point.x) - float(primary_radii[point_index]))
		var primary := MeshInstance3D.new()
		primary.name = "OldGrowthPrimaryRoot_%02d" % (root_index + 1)
		primary.mesh = _build_poly_tube_mesh(primary_points, primary_radii, 9)
		primary.material_override = wood[2 + root_index % 2]
		primary.set_meta("attached_to", "buttress_stem")
		roots.add_child(primary)
		var collar_tangent := ((primary_points[2] as Vector3)
			- (primary_points[0] as Vector3)).normalized()
		root_gold_collar_transforms.append(Transform3D(
			_blueprint_y_basis(collar_tangent).scaled(
				Vector3.ONE * float(primary_radii[1]) * 1.04),
			primary_points[1] as Vector3))

		# Exactly two smaller rootlets fork from a seated point on every main root.
		for fork_side_value in [-1.0, 1.0]:
			var fork_side := float(fork_side_value)
			var fork_origin: Vector3 = primary_points[2]
			var fork_direction := (radial * 0.72 + tangent * fork_side * 0.68).normalized()
			var rootlet_points := [
				fork_origin,
				fork_origin + fork_direction * 15.0 + Vector3.DOWN * 1.15,
				fork_origin + fork_direction * 32.0 + tangent * fork_side * 2.0
					+ Vector3.DOWN * 1.75,
			]
			var rootlet_radii := [3.5, 1.8, 0.48]
			for point_index in rootlet_points.size():
				var point := rootlet_points[point_index] as Vector3
				point.y = maxf(point.y, float(rootlet_radii[point_index]) * 1.02)
				if point.z < base_center.z:
					var corridor_side := -1.0 if fork_origin.x < 0.0 else 1.0
					var minimum_x := TREE_BLUEPRINT_DOOR_WIDTH * 0.5 \
						+ float(rootlet_radii[point_index]) + 2.0
					point.x = corridor_side * maxf(absf(point.x), minimum_x)
					rootlet_points[point_index] = point
					minimum_south_clearance = minf(minimum_south_clearance,
						absf(point.x) - float(rootlet_radii[point_index]))
				rootlet_points[point_index] = point
				minimum_ground_clearance = minf(minimum_ground_clearance,
					point.y - float(rootlet_radii[point_index]))
			maximum_rootlet_attachment_gap = maxf(maximum_rootlet_attachment_gap,
				(rootlet_points[0] as Vector3).distance_to(fork_origin))
			var rootlet := MeshInstance3D.new()
			rootlet.name = "OldGrowthRootlet_%02d_%s" % [
				root_index + 1, "L" if fork_side < 0.0 else "R"]
			rootlet.mesh = _build_poly_tube_mesh(rootlet_points, rootlet_radii, 8)
			rootlet.material_override = wood[2 + root_index % 2]
			rootlet.set_meta("attached_to", primary.name)
			roots.add_child(rootlet)
			var rootlet_channel_points: Array[Vector3] = []
			for point_index in rootlet_points.size():
				rootlet_channel_points.append(rootlet_points[point_index]
					+ Vector3.UP * rootlet_radii[point_index] * 1.04)
			var rootlet_channel := MeshInstance3D.new()
			rootlet_channel.name = "OldGrowthRootletEnergy_%02d_%s" % [
				root_index + 1, "L" if fork_side < 0.0 else "R"]
			rootlet_channel.mesh = _build_poly_tube_mesh(
				rootlet_channel_points, [0.44, 0.28, 0.10], 5)
			rootlet_channel.material_override = energy_flow
			rootlet_channel.set_meta("flow_direction", "rootlet_tip_to_primary_root")
			rootlet_channel.set_meta("pinned_to_bark", true)
			roots.add_child(rootlet_channel)

		# Every primary root now carries a continuous intake channel; the former
		# every-third-root treatment could not describe a functioning circulation.
		var channel_points: Array[Vector3] = []
		for point_index in primary_points.size():
			channel_points.append(primary_points[point_index]
				+ Vector3.UP * primary_radii[point_index] * 1.04)
		var channel := MeshInstance3D.new()
		channel.name = "OldGrowthRootSapSeam_%02d" % (root_index + 1)
		channel.mesh = _build_poly_tube_mesh(
			channel_points, [1.05, 0.90, 0.68, 0.40, 0.14], 6)
		channel.material_override = energy_flow
		channel.set_meta("flow_direction", "root_tip_to_buttress_collector")
		channel.set_meta("pinned_to_bark", true)
		roots.add_child(channel)
		var gold_slash_points: Array[Vector3] = []
		var gold_slash_side := -1.0 if root_index % 2 == 0 else 1.0
		for point_index in 3:
			gold_slash_points.append((primary_points[point_index] as Vector3)
				+ Vector3.UP * float(primary_radii[point_index]) * 1.055
				+ tangent * gold_slash_side * 1.15)
		root_gold_slash_paths.append(gold_slash_points)
	var root_collar_mesh := TorusMesh.new()
	root_collar_mesh.inner_radius = 0.88
	root_collar_mesh.outer_radius = 1.04
	root_collar_mesh.rings = 12
	root_collar_mesh.ring_segments = 4
	var root_collar_batch := _blueprint_add_multimesh(roots,
		"OldGrowthRootGoldGrowthCollarBatch", root_collar_mesh,
		root_gold_collar_transforms, root_gold, false)
	root_collar_batch.set_meta("collars", root_gold_collar_transforms.size())
	root_collar_batch.set_meta("seated_around_root_tangent", true)
	root_collar_batch.set_meta("design", "antique_gold_growth_rings")
	var root_gold_slashes := MeshInstance3D.new()
	root_gold_slashes.name = "OldGrowthRootGoldSlashInlayBundle"
	root_gold_slashes.mesh = _build_poly_tube_bundle_mesh(
		root_gold_slash_paths, [0.48, 0.36, 0.18], 5)
	root_gold_slashes.material_override = root_gold
	root_gold_slashes.set_meta("slash_paths", root_gold_slash_paths.size())
	root_gold_slashes.set_meta("pinned_beside_cyan_root_seams", true)
	roots.add_child(root_gold_slashes)
	roots.set_meta("gold_growth_collars", root_gold_collar_transforms.size())
	roots.set_meta("gold_root_slash_inlays", root_gold_slash_paths.size())
	roots.set_meta("south_corridor_half_width", TREE_BLUEPRINT_DOOR_WIDTH * 0.5)
	roots.set_meta("minimum_south_corridor_clearance", minimum_south_clearance)
	roots.set_meta("minimum_ground_clearance", minimum_ground_clearance)
	roots.set_meta("maximum_primary_attachment_gap", maximum_primary_attachment_gap)
	roots.set_meta("maximum_rootlet_attachment_gap", maximum_rootlet_attachment_gap)


func _build_old_growth_buttress_energy_network(body: Node3D,
		left_path: Array, right_path: Array, buttress_radii: Array) -> void:
	var network := Node3D.new()
	network.name = "OldGrowthEnergyNetwork"
	network.set_meta("flow_model", "rootlets_to_roots_to_buttress_to_heart_to_crown")
	network.set_meta("buttress_feeders", 6)
	network.set_meta("heart_feeders", 2)
	network.set_meta("buttress_collectors", 6)
	network.set_meta("continuous_to_crown", true)
	body.add_child(network)
	var energy_flow := _create_tree_sap_flow_material()
	for side_index in 2:
		var stem_path: Array = left_path if side_index == 0 else right_path
		var side := -1.0 if side_index == 0 else 1.0
		for feeder_index in 3:
			var feeder_points: Array[Vector3] = []
			var feeder_radii: Array[float] = []
			for point_index in stem_path.size():
				var point := stem_path[point_index] as Vector3
				var bark_offset: float = float(buttress_radii[point_index]) * 0.82
				feeder_points.append(point + Vector3(
					side * (float(feeder_index) - 1.0) * 1.25,
					0.0, -bark_offset))
				feeder_radii.append(0.68 - float(point_index) * 0.07)
			var feeder := MeshInstance3D.new()
			feeder.name = "OldGrowthButtressFeeder_%s_%02d" % [
				"L" if side < 0.0 else "R", feeder_index + 1]
			feeder.mesh = _build_poly_tube_mesh(feeder_points, feeder_radii, 6)
			feeder.material_override = energy_flow
			feeder.set_meta("flow_direction", "root_collector_to_trunk")
			feeder.set_meta("pinned_to_bark", true)
			network.add_child(feeder)

	var tree := body.get_parent() as Node3D
	var heart_y := _heart_shrine_height(tree)
	var heart_depth := -HEART_SHRINE_DEPTH * TREE_OF_LIFE_BODY_RATIO * HEART_SHRINE_HUG
	for side_value in [-1.0, 1.0]:
		var side := float(side_value)
		var heart_feeder := MeshInstance3D.new()
		heart_feeder.name = "OldGrowthHeartFeeder_%s" % ("L" if side < 0.0 else "R")
		heart_feeder.mesh = _build_poly_tube_mesh([
			Vector3(side * 13.0, heart_y - 17.0, -18.0),
			Vector3(side * 11.0, heart_y - 8.0, -24.0),
			Vector3(side * 6.0, heart_y, heart_depth + 2.0),
		], [0.72, 0.55, 0.26], 7)
		heart_feeder.material_override = energy_flow
		heart_feeder.set_meta("flow_direction", "trunk_to_wisdom_heart")
		network.add_child(heart_feeder)

	for side_index in 2:
		var side := -1.0 if side_index == 0 else 1.0
		var stem_path: Array = left_path if side_index == 0 else right_path
		for collector_index in 3:
			var collector := MeshInstance3D.new()
			collector.name = "OldGrowthButtressCollector_%s_%02d" % [
				"L" if side < 0.0 else "R", collector_index + 1]
			var collector_mesh := SphereMesh.new()
			collector_mesh.radius = 1.45
			collector_mesh.height = 2.9
			collector_mesh.radial_segments = 8
			collector_mesh.rings = 4
			collector.mesh = collector_mesh
			collector.position = (stem_path[0] as Vector3) + Vector3(
				side * (float(collector_index) - 1.0) * 1.25,
				0.0, -float(buttress_radii[0]) * 0.82)
			collector.material_override = energy_flow
			collector.set_meta("flow_role", "paired_root_energy_merger")
			network.add_child(collector)


func _build_reference_trunk_root_facade(tree: Node3D) -> void:
	# The original Blender body remains authoritative for silhouette and collision.
	# These visual-only ribs give its south entrance the reference's readable
	# hierarchy: two braided load-bearing trunks, a dark open arch, spreading root
	# toes, bronze restraint bands and cyan sap nested inside the bark.
	var facade := Node3D.new()
	facade.name = "ReferenceTrunkRootFacade"
	# Reuse the authored braided detail inside the corrected 36 m root envelope.
	# Its former failure was an oversized footprint, not the rib architecture.
	facade.visible = true
	facade.scale = Vector3(0.72, 1.0, 0.72)
	facade.position.y = 3.5
	facade.set_meta("reference", "user_supplied_dark_braided_heart_tree")
	facade.set_meta("visual_only", true)
	facade.set_meta("player_passage_preserved", true)
	facade.set_meta("primary_trunk_ribs", REFERENCE_TRUNK_RIB_COUNT)
	facade.set_meta("root_flares", REFERENCE_ROOT_FLARE_COUNT)
	facade.set_meta("bronze_bands", REFERENCE_TRUNK_BAND_COUNT)
	tree.add_child(facade)

	var wood := _create_reference_tree_wood_palette()
	var cyan := _create_tree_sap_flow_material()
	var bronze := _make_glow(Color("d6a43f"), 0.34)
	bronze.metallic = 0.78
	bronze.metallic_specular = 0.95
	bronze.roughness = 0.27
	var heart_y := _heart_shrine_height(tree)
	var upper_y := heart_y + 24.0

	var trunk_paths := [
		[Vector3(-58.0, 1.0, -43.0), Vector3(-48.0, 17.0, -46.0),
			Vector3(-45.0, 36.0, -48.0), Vector3(-35.0, heart_y - 10.0, -50.0),
			Vector3(-19.0, upper_y, -48.0)],
		[Vector3(-25.0, 1.0, -51.0), Vector3(-34.0, 18.0, -53.0),
			Vector3(-31.0, 37.0, -54.0), Vector3(-20.0, heart_y - 7.0, -55.0),
			Vector3(-8.0, upper_y - 2.0, -52.0)],
		[Vector3(25.0, 1.0, -51.0), Vector3(34.0, 18.0, -53.0),
			Vector3(31.0, 37.0, -54.0), Vector3(20.0, heart_y - 7.0, -55.0),
			Vector3(8.0, upper_y - 2.0, -52.0)],
		[Vector3(58.0, 1.0, -43.0), Vector3(48.0, 17.0, -46.0),
			Vector3(45.0, 36.0, -48.0), Vector3(35.0, heart_y - 10.0, -50.0),
			Vector3(19.0, upper_y, -48.0)],
	]
	var trunk_gold_inlay_paths: Array = []
	for rib_index in trunk_paths.size():
		var rib := MeshInstance3D.new()
		rib.name = "ReferenceBraidedTrunkRib_%02d" % (rib_index + 1)
		rib.mesh = _build_poly_tube_mesh(trunk_paths[rib_index],
			[8.8, 8.1, 7.2, 6.0, 3.8], 10)
		rib.material_override = wood[1 + rib_index % 3]
		facade.add_child(rib)

		var channel_points: Array = []
		for point_value in trunk_paths[rib_index]:
			var point := point_value as Vector3
			channel_points.append(point + Vector3(0.0, 0.0, -8.3))
		var channel := MeshInstance3D.new()
		channel.name = "ReferenceTrunkSapChannel_%02d" % (rib_index + 1)
		channel.mesh = _build_poly_tube_mesh(channel_points,
			[0.72, 0.66, 0.58, 0.50, 0.34], 6)
		channel.material_override = cyan
		facade.add_child(channel)
		var gold_inlay_points: Array[Vector3] = []
		var gold_side := -1.0 if rib_index < 2 else 1.0
		for point_value in trunk_paths[rib_index]:
			var point := point_value as Vector3
			gold_inlay_points.append(point + Vector3(gold_side * 1.35, 0.0, -8.05))
		trunk_gold_inlay_paths.append(gold_inlay_points)

	var trunk_gold_inlay := MeshInstance3D.new()
	trunk_gold_inlay.name = "ReferenceTrunkGoldSlashInlayBundle"
	trunk_gold_inlay.mesh = _build_poly_tube_bundle_mesh(
		trunk_gold_inlay_paths, [0.34, 0.31, 0.27, 0.23, 0.16], 5)
	trunk_gold_inlay.material_override = bronze
	trunk_gold_inlay.set_meta("inlay_paths", trunk_gold_inlay_paths.size())
	trunk_gold_inlay.set_meta("braided_beside_cyan_energy", true)
	trunk_gold_inlay.set_meta("pinned_to_trunk_ribs", true)
	facade.add_child(trunk_gold_inlay)

	var root_paths := [
		[Vector3(-29.0, 5.0, -49.0), Vector3(-43.0, 0.0, -49.0), Vector3(-67.0, -2.0, -43.0), Vector3(-91.0, -3.0, -31.0)],
		[Vector3(-34.0, 5.0, -43.0), Vector3(-48.0, 0.0, -34.0), Vector3(-65.0, -2.0, -16.0), Vector3(-76.0, -3.0, 5.0)],
		[Vector3(-39.0, 5.0, -38.0), Vector3(-50.0, 0.0, -18.0), Vector3(-57.0, -2.0, 7.0), Vector3(-57.0, -3.0, 31.0)],
		[Vector3(-23.0, 4.0, -53.0), Vector3(-27.0, 0.0, -66.0), Vector3(-38.0, -2.0, -81.0), Vector3(-55.0, -3.0, -93.0)],
		[Vector3(29.0, 5.0, -49.0), Vector3(43.0, 0.0, -49.0), Vector3(67.0, -2.0, -43.0), Vector3(91.0, -3.0, -31.0)],
		[Vector3(34.0, 5.0, -43.0), Vector3(48.0, 0.0, -34.0), Vector3(65.0, -2.0, -16.0), Vector3(76.0, -3.0, 5.0)],
		[Vector3(39.0, 5.0, -38.0), Vector3(50.0, 0.0, -18.0), Vector3(57.0, -2.0, 7.0), Vector3(57.0, -3.0, 31.0)],
		[Vector3(23.0, 4.0, -53.0), Vector3(27.0, 0.0, -66.0), Vector3(38.0, -2.0, -81.0), Vector3(55.0, -3.0, -93.0)],
	]
	var root_radii := [10.5, 8.4, 5.4, 1.8]
	var root_energy_paths: Array = []
	for root_index in root_paths.size():
		var root_rib := MeshInstance3D.new()
		root_rib.name = "ReferenceRootFlare_%02d" % (root_index + 1)
		root_rib.mesh = _build_poly_tube_mesh(root_paths[root_index],
			root_radii, 10)
		root_rib.material_override = wood[1 + root_index % 3]
		root_rib.set_meta("thick_braided_structural_root", true)
		root_rib.set_meta("radius_range_m", Vector2(1.8, 10.5))
		facade.add_child(root_rib)
		# Paired fibers sit in the visible surface of every thick root. Deriving
		# their normal from each bend prevents a straight cable floating beside it.
		for strand_side in [-1.0, 1.0]:
			var root_channel_points: Array = []
			for point_index in root_paths[root_index].size():
				var root_point := root_paths[root_index][point_index] as Vector3
				var previous := root_paths[root_index][maxi(0, point_index - 1)] as Vector3
				var following := root_paths[root_index][mini(
					root_paths[root_index].size() - 1, point_index + 1)] as Vector3
				var tangent := (following - previous).normalized()
				var front_normal := Vector3(0.0, 0.0, -1.0)
				var surface_normal := front_normal - tangent * tangent.dot(front_normal)
				if surface_normal.length_squared() < 0.001:
					surface_normal = Vector3.UP
				surface_normal = surface_normal.normalized()
				var cross_surface := tangent.cross(surface_normal).normalized()
				var braided_normal: Vector3 = (surface_normal
					+ cross_surface * strand_side * 0.11).normalized()
				root_channel_points.append(root_point + braided_normal
					* (float(root_radii[point_index]) + 0.22))
			root_energy_paths.append(root_channel_points)
	var root_energy_bundle := MeshInstance3D.new()
	root_energy_bundle.name = "ReferenceRootEmbeddedEnergyFiberBundle"
	root_energy_bundle.mesh = _build_poly_tube_bundle_mesh(
		root_energy_paths, [0.72, 0.58, 0.38, 0.16], 6)
	root_energy_bundle.material_override = cyan
	root_energy_bundle.set_meta("strand_count", 16)
	root_energy_bundle.set_meta("paired_strands_per_root", 2)
	root_energy_bundle.set_meta("maximum_surface_gap_m", 0.22)
	root_energy_bundle.set_meta("embedded_not_floating", true)
	facade.add_child(root_energy_bundle)
	var visible_root_gold_paths: Array = []
	for root_index in root_paths.size():
		var source_path := root_energy_paths[root_index * 2] as Array
		var gold_path: Array[Vector3] = []
		var gold_side := -1.0 if root_index % 2 == 0 else 1.0
		for point_index in 3:
			gold_path.append((source_path[point_index] as Vector3)
				+ Vector3(gold_side * 1.55, 0.10, -0.18))
		visible_root_gold_paths.append(gold_path)
	var visible_root_gold := MeshInstance3D.new()
	visible_root_gold.name = "ReferenceRootGoldSlashInlayBundle"
	visible_root_gold.mesh = _build_poly_tube_bundle_mesh(
		visible_root_gold_paths, [0.52, 0.38, 0.18], 5)
	visible_root_gold.material_override = bronze
	visible_root_gold.set_meta("slash_paths", visible_root_gold_paths.size())
	visible_root_gold.set_meta("pinned_beside_cyan_energy", true)
	facade.add_child(visible_root_gold)

	var band_specs := [
		Vector3(-45.0, 18.0, -55.0), Vector3(-42.0, 37.0, -57.0), Vector3(-31.0, heart_y - 8.0, -59.0),
		Vector3(45.0, 18.0, -55.0), Vector3(42.0, 37.0, -57.0), Vector3(31.0, heart_y - 8.0, -59.0),
	]
	for band_index in band_specs.size():
		var band := MeshInstance3D.new()
		band.name = "ReferenceBronzeTrunkBand_%02d" % (band_index + 1)
		var clamp_mesh := BoxMesh.new()
		clamp_mesh.size = Vector3(17.5 if band_index % 3 < 2 else 14.5, 3.1, 3.8)
		band.mesh = clamp_mesh
		band.position = band_specs[band_index]
		# Mirror the slight climb of the left/right braided load paths. Unlike a
		# front-facing torus, this reads as a strap biting into the wood rather than
		# a decorative hoop floating beside it.
		band.rotation_degrees.z = -9.0 if band_index < 3 else 9.0
		band.material_override = bronze
		band.set_meta("gold_slash_inlay", true)
		band.set_meta("seated_on_bark", true)
		facade.add_child(band)


# The wisdom heart shrine: the crystal the tree is named for, mounted on the
# trunk's south face where the player meets it, rather than lost in the canopy.
# Everything here is procedural - a few hundred triangles - so it costs nothing
# on Web and can be retuned without a Blender round trip.
# Clearance kept between the top of the root doorway and the bottom of the
# shrine frame, so the setting reads as a gateway keystone over the opening.
const HEART_SHRINE_DOOR_CLEARANCE := 1.5
# One factor for the whole setting. The frame has to clear the doorway, so a
# smaller shrine is what lets it sit down close to the gate instead of riding
# high in the canopy.
const HEART_SHRINE_SCALE := 0.62
const HEART_SHRINE_FALLBACK_HEIGHT := 64.0
const HEART_SHRINE_DEPTH := 44.0
const HEART_SHRINE_CRYSTAL_HEIGHT := 26.0
const HEART_SHRINE_CRYSTAL_RADIUS := 7.4
# The rings must clear the crystal at every tilt, so the ring radius is set from
# the gem's longest half-axis (height * 0.56 at the tips) plus this gap. A ring
# radius below that lets a tilted ring pass straight through the crystal.
const HEART_SHRINE_RING_GAP := 3.2
const HEART_SHRINE_FRAME_RADIUS := HEART_SHRINE_CRYSTAL_HEIGHT * 0.56 + HEART_SHRINE_RING_GAP
const HEART_SHRINE_OVAL_STRETCH := 1.5
const HEART_SHRINE_SPIN_SECONDS := 14.0
# How tightly the setting sits against the trunk: 1.0 would leave it standing
# off the bark, lower presses it into the body.
const HEART_SHRINE_HUG := 1.02
const HEART_GEAR_TEETH := 20
const HEART_GEAR_IDLER_TEETH := 9
const HEART_GEAR_SECONDS := 26.0
const HEART_FRAME_RUNE_COUNT := 8
const HEART_FRAME_SPOKE_COUNT := 8
const HEART_WOOD_CRADLE_RIB_COUNT := 6
const HEART_WOOD_CRADLE_MOUNT_COUNT := 8
# Boughs pointing south within this arc are skipped across the heart's own
# height band, so the setting sits in a clear niche. The band is derived from
# where the heart actually is, not from guessed heights.
const HEART_NICHE_ARC_DEGREES := 88.0
const HEART_NICHE_MARGIN := 3.0
# The coarse arc above removes whole boughs rooted in front of the shrine, but
# side and rear boughs can still project leaves across it. These dimensions cut
# a screen-facing opening around the complete gold frame when instances are
# batched. They are expressed in the powered-canopy's pre-ratio local space.
# The heart needs a readable silhouette from the arrival bridge. These values
# clear the full frame plus a calm ring of bark around it; the old tighter
# aperture technically exposed the gem but left compound leaf tips crowding its
# outline. The projection test intentionally removes foliage at every depth so
# distant boughs cannot visually close the opening again.
const HEART_NICHE_CLEAR_WIDTH_MARGIN := 3.45
const HEART_NICHE_CLEAR_HEIGHT_MARGIN := 2.55
const HEART_NICHE_LEAF_PADDING := 7.0
# Dyson-style orbital rings. They are the same ring as the mandorla - same
# radius, same tube, same oval stretch - and differ only in how they are tilted
# and how long they take to turn.
const HEART_SHRINE_ORBIT_RINGS := [
	{"tilt_x": 0.0, "tilt_z": 0.0, "seconds": 11.0},
	{"tilt_x": 62.0, "tilt_z": 0.0, "seconds": -14.5},
	{"tilt_x": 0.0, "tilt_z": 58.0, "seconds": 18.0},
]
const HEART_SHRINE_OUTLINE_GROW := 0.95




# Energy veins climbing the bark. They are pinned to the real surface: the
# trunk and root mesh is sampled into a height x angle table of bark radii, and
# every vein segment is placed on that surface. A guessed cylinder profile
# floats off the bark wherever the trunk is not round - which it never is.
#
# The authored CyanSapChannel meshes cannot be reused for this: they trace the
# old radial branch layout, so with those branches hidden they stick out past
# the canopy as loose horizontal streaks.
const VEIN_COUNT := 18
const VEIN_SEGMENTS := 64
const VEIN_BOTTOM := 72.0
const VEIN_TOP := TREE_BLUEPRINT_CROWN_HEIGHT
const VEIN_THICKNESS := 0.72
const VEIN_WANDER := 0.14
# Sampling resolution of the bark table, and how far off the surface a vein
# sits so it reads as lying on the bark rather than buried in it.
const VEIN_HEIGHT_BUCKETS := 34
const VEIN_ANGLE_BUCKETS := 48
const VEIN_SURFACE_OFFSET := 0.6
# A vein may only move this far off the bark radius per segment. Without the
# clamp a vein snaps from the trunk out to a root tip in one step and the span
# between crosses open air.
const VEIN_MAX_RADIUS_STEP := 2.6
const VEIN_VERTEX_STRIDE := 3


func _build_trunk_energy_veins(tree: Node3D) -> void:
	var veins := Node3D.new()
	veins.name = "TrunkEnergyVeins"
	tree.add_child(veins)

	var vein_paths: Array = []
	for vein in VEIN_COUNT:
		var phase := TAU * float(vein) / float(VEIN_COUNT)
		# The enlarged trunk and this circulation share one analytical centre/radius
		# profile. That is more exact than sampling the old imported hull and avoids
		# ladder-like spans wherever the buttress silhouette changes abruptly.
		var path := PackedVector3Array()
		for step in range(VEIN_SEGMENTS + 1):
			var walk := float(step) / float(VEIN_SEGMENTS)
			path.append(_old_growth_vein_point(phase, walk, vein))
		vein_paths.append(path)

	# One joined mesh preserves all 18 continuous routes while avoiding 1,152
	# individual segment instances on integrated-GPU laptops.
	var batch := MeshInstance3D.new()
	batch.name = "TrunkVeinBatch"
	batch.mesh = _build_poly_tube_bundle_mesh(vein_paths,
		[VEIN_THICKNESS * 0.5], 6)
	batch.material_override = _create_tree_sap_flow_material()
	batch.set_meta("veins", VEIN_COUNT)
	batch.set_meta("segments_per_vein", VEIN_SEGMENTS)
	batch.set_meta("flow_extent", "buttress_merge_to_crown")
	batch.set_meta("pinned_to_bark", true)
	batch.set_meta("joined_for_laptop_budget", true)
	veins.add_child(batch)

	# Eighteen bark veins converge through the final wood cap into the star's
	# bottom socket. Their endpoints all coincide with the 60 m crown mount.
	var convergence_paths: Array = []
	var crown_socket := Vector3(0.0, TREE_BLUEPRINT_CROWN_HEIGHT, 0.0)
	for vein in VEIN_COUNT:
		var phase := TAU * float(vein) / float(VEIN_COUNT)
		var start := _old_growth_vein_point(phase, 0.965, vein)
		convergence_paths.append([start, crown_socket])
	var convergence_batch := MeshInstance3D.new()
	convergence_batch.name = "CrownVeinConvergenceBatch"
	convergence_batch.mesh = _build_poly_tube_bundle_mesh(
		convergence_paths, [0.24], 5)
	convergence_batch.material_override = _create_tree_sap_flow_material()
	convergence_batch.set_meta("veins", VEIN_COUNT)
	convergence_batch.set_meta("crown_socket", crown_socket)
	convergence_batch.set_meta("maximum_endpoint_gap", 0.0)
	convergence_batch.set_meta("joined_for_laptop_budget", true)
	veins.add_child(convergence_batch)


func _old_growth_vein_point(phase: float, travel: float, vein: int) -> Vector3:
	var height := lerpf(VEIN_BOTTOM, VEIN_TOP, travel)
	var centre := _old_growth_trunk_center(height)
	centre.y = height
	var angle := phase + sin(travel * PI * 2.2 + float(vein) * 1.37) * VEIN_WANDER
	var radius := _old_growth_trunk_radius(height) * 0.94 + VEIN_SURFACE_OFFSET
	return centre + Vector3(cos(angle), 0.0, sin(angle)) * radius


func _sample_bark_profile(tree: Node3D) -> PackedFloat32Array:
	# Build a height x angle table of the furthest surface point, in tree space.
	# That outer hull is the bark: trunk where the trunk is widest, root flare
	# lower down, so veins laid on it follow both without any guessing.
	var table := PackedFloat32Array()
	table.resize(VEIN_HEIGHT_BUCKETS * VEIN_ANGLE_BUCKETS)
	table.fill(0.0)
	var visual := tree.get_node_or_null("BlenderTreeOfLifeVisual") as Node3D
	var old_growth := tree.get_node_or_null("OldGrowthTrunkBody") as Node3D
	if visual == null and old_growth == null:
		return PackedFloat32Array()
	var band := (VEIN_TOP - VEIN_BOTTOM) / float(VEIN_HEIGHT_BUCKETS)
	var samples := 0
	var bark_meshes: Array[Node] = []
	if visual != null:
		bark_meshes.append_array(visual.find_children("*", "MeshInstance3D", true, false))
	if old_growth != null:
		bark_meshes.append_array(old_growth.find_children("*", "MeshInstance3D", true, false))
	for node in bark_meshes:
		var mesh_node := node as MeshInstance3D
		# Branches and original foliage are visible again, but they are not bark.
		# Sampling them would pull the trunk veins out to canopy radius and recreate
		# exactly the floating-mechanics silhouette this pass removes.
		var authored_bark := mesh_node.name.begins_with("Trunk") \
			or mesh_node.name.begins_with("Roots")
		var rebuilt_bark := mesh_node.name.begins_with("OldGrowthButtressStem") \
			or mesh_node.name.begins_with("OldGrowthCentralLeader") \
			or mesh_node.name.begins_with("OldGrowthCoDominantStem") \
			or mesh_node.name.begins_with("OldGrowthBarkRidge")
		if not (authored_bark or rebuilt_bark) \
				or mesh_node.mesh == null or not mesh_node.is_visible_in_tree():
			continue
		var to_tree := tree.global_transform.affine_inverse() * mesh_node.global_transform
		for surface in mesh_node.mesh.get_surface_count():
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			if arrays.is_empty():
				continue
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var vertex_index := 0
			while vertex_index < vertices.size():
				var point := to_tree * vertices[vertex_index]
				vertex_index += VEIN_VERTEX_STRIDE
				if point.y < VEIN_BOTTOM or point.y > VEIN_TOP:
					continue
				var radius := Vector2(point.x, point.z).length()
				if radius < 1.0:
					continue
				var height_bucket := clampi(
					int((point.y - VEIN_BOTTOM) / band), 0, VEIN_HEIGHT_BUCKETS - 1)
				var angle := fposmod(atan2(point.z, point.x), TAU)
				var angle_bucket := clampi(
					int(angle / TAU * float(VEIN_ANGLE_BUCKETS)),
					0, VEIN_ANGLE_BUCKETS - 1)
				var slot := height_bucket * VEIN_ANGLE_BUCKETS + angle_bucket
				if radius > table[slot]:
					table[slot] = radius
				samples += 1
	if samples == 0:
		return PackedFloat32Array()

	# Fill gaps: a bucket with no vertices would drop a vein to the tree axis.
	for height_bucket in VEIN_HEIGHT_BUCKETS:
		var row_start := height_bucket * VEIN_ANGLE_BUCKETS
		var row_max := 0.0
		for angle_bucket in VEIN_ANGLE_BUCKETS:
			row_max = maxf(row_max, table[row_start + angle_bucket])
		for angle_bucket in VEIN_ANGLE_BUCKETS:
			if table[row_start + angle_bucket] <= 0.0:
				table[row_start + angle_bucket] = row_max
	return table


func _bark_radius(bark: PackedFloat32Array, height: float, angle: float) -> float:
	var band := (VEIN_TOP - VEIN_BOTTOM) / float(VEIN_HEIGHT_BUCKETS)
	var height_bucket := clampi(
		int((height - VEIN_BOTTOM) / band), 0, VEIN_HEIGHT_BUCKETS - 1)
	var angle_bucket := clampi(
		int(fposmod(angle, TAU) / TAU * float(VEIN_ANGLE_BUCKETS)),
		0, VEIN_ANGLE_BUCKETS - 1)
	return bark[height_bucket * VEIN_ANGLE_BUCKETS + angle_bucket]


func _vein_point(bark: PackedFloat32Array, phase: float, travel: float,
		vein: int) -> Vector3:
	var height := lerpf(VEIN_BOTTOM, VEIN_TOP, travel)
	# A slow wander so the veins read as grown rather than machined.
	var angle := phase + sin(travel * PI * 2.4 + float(vein) * 1.37) * VEIN_WANDER
	var radius := _bark_radius(bark, height, angle) + VEIN_SURFACE_OFFSET
	return Vector3(cos(angle) * radius, height, sin(angle) * radius)


func _build_wisdom_heart_shrine(tree: Node3D) -> void:
	var shrine := Node3D.new()
	shrine.name = "WisdomHeartShrine"
	# The doorway and the arrival bridge face world south, so the shrine faces
	# the same way - the player walks straight at it. It sits tight against the
	# trunk rather than standing off it: this is the tree's heart, not a sign.
	shrine.scale = Vector3.ONE * HEART_SHRINE_SCALE * TREE_OF_LIFE_BODY_RATIO
	var shrine_depth := HEART_SHRINE_DEPTH * TREE_OF_LIFE_BODY_RATIO * HEART_SHRINE_HUG
	shrine.position = Vector3(0.0, _heart_shrine_height(tree), -shrine_depth)
	tree.add_child(shrine)

	# A restrained antique-gold base preserves real shading across the teeth;
	# the former near-white emission flattened the mechanism in close views.
	var gold := _make_glow(Color("e2b347"), 0.46)
	gold.metallic = 0.62
	gold.metallic_specular = 0.95
	gold.roughness = 0.30
	var gold_dark := _make_glow(Color("8f6325"), 0.18)
	gold_dark.metallic = 0.48
	gold_dark.roughness = 0.42
	_build_living_heart_wood_cradle(shrine)
	_build_heart_tree_socket(shrine, gold, gold_dark)
	_build_heart_gear_frame(shrine, gold, gold_dark)
	var side_heart_ring := MeshInstance3D.new()
	side_heart_ring.name = "HeartSideElevationRing"
	var side_ring_mesh := TorusMesh.new()
	side_ring_mesh.inner_radius = HEART_SHRINE_FRAME_RADIUS * 0.88
	side_ring_mesh.outer_radius = HEART_SHRINE_FRAME_RADIUS * 1.03
	side_ring_mesh.rings = 18
	side_ring_mesh.ring_segments = 6
	side_heart_ring.mesh = side_ring_mesh
	side_heart_ring.rotation.z = PI * 0.5
	# The front mechanism sits on the south bark. Its side-profile ring is the
	# same heart's internal cross-section, centered on the trunk axis.
	side_heart_ring.position.z = shrine_depth / shrine.scale.z
	side_heart_ring.material_override = gold
	side_heart_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shrine.add_child(side_heart_ring)

	var spin_pivot := Node3D.new()
	spin_pivot.name = "HeartCrystalSpin"
	spin_pivot.rotation.y = deg_to_rad(4.0)
	spin_pivot.set_meta("outer_heart_locked_front", false)
	spin_pivot.set_meta("whole_crystal_rotates_about_itself", true)
	spin_pivot.set_meta("rotation_axis", "local_y")
	spin_pivot.set_meta("internal_core_rotates_with_shell", true)
	shrine.add_child(spin_pivot)

	var heart := BlenderHeartCrystalScene.instantiate() as Node3D
	heart.name = "HeartShrineCrystal"
	heart.set_meta("crystal_shape", "blender_cut_heart_diamond")
	heart.set_meta("diamond_taper", true)
	heart.set_meta("triangular_facet_geometry", true)
	heart.set_meta("blender_authored", true)
	heart.set_meta("source_blend",
		"res://assets3D/tree_of_life/heart_crystal/source/realistic_heart_crystal.blend")
	heart.set_meta("runtime_glb",
		"res://assets3D/tree_of_life/heart_crystal/glb/realistic_heart_crystal.glb")
	heart.set_meta("outer_triangular_facets", 24)
	heart.set_meta("girdle_facets", 12)
	heart.set_meta("internal_core_facets", 8)
	heart.set_meta("internal_inclusions", 6)
	heart.set_meta("closed_realistic_3d_shell", true)
	spin_pivot.add_child(heart)
	var crystal_meshes := heart.find_children("*", "MeshInstance3D", true, false)
	heart.set_meta("blender_mesh_objects", crystal_meshes.size())
	for mesh_node in crystal_meshes:
		(mesh_node as MeshInstance3D).cast_shadow = \
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# A heart-shaped antique-gold mandorla sits inside the circular gear. It gives
	# the organic crystal its own frame while the outer teeth remain mechanical.
	var heart_mandorla := MeshInstance3D.new()
	heart_mandorla.name = "HeartCrystalGoldMandorla"
	heart_mandorla.mesh = _build_heart_outline_tube_mesh(
		HEART_SHRINE_CRYSTAL_RADIUS * 2.72,
		HEART_SHRINE_CRYSTAL_HEIGHT * 1.16, 0.58, 7)
	heart_mandorla.position.z = 0.72
	heart_mandorla.material_override = gold
	heart_mandorla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	heart_mandorla.set_meta("seated_inside_main_gear", true)
	heart_mandorla.set_meta("frame_shape", "heart_mandorla")
	shrine.add_child(heart_mandorla)

	# The reference suspends the crystal in a clear aperture. Two restrained gold
	# terminals approach from above and below but stop short of the gemstone;
	# there are no bars crossing its face, so the rotating Blender cut remains
	# readable and genuinely appears to float inside the powered frame.
	var crystal_cage_paths: Array = []
	var upper_tip_y := HEART_SHRINE_CRYSTAL_HEIGHT * 0.50 + 1.15
	var lower_tip_y := -HEART_SHRINE_CRYSTAL_HEIGHT * 0.56 - 1.15
	crystal_cage_paths.append([
		Vector3(0.0, HEART_SHRINE_FRAME_RADIUS * 0.94, 0.82),
		Vector3(0.0, HEART_SHRINE_FRAME_RADIUS * 0.82, 0.50),
		Vector3(0.0, upper_tip_y, 0.18),
	])
	crystal_cage_paths.append([
		Vector3(0.0, -HEART_SHRINE_FRAME_RADIUS * 0.94, 0.82),
		Vector3(0.0, -HEART_SHRINE_FRAME_RADIUS * 0.84, 0.50),
		Vector3(0.0, lower_tip_y, 0.18),
	])
	var crystal_cage := MeshInstance3D.new()
	crystal_cage.name = "HeartCrystalFloatingSuspension"
	crystal_cage.mesh = _build_poly_tube_bundle_mesh(
		crystal_cage_paths, [0.72, 0.46, 0.18], 7)
	crystal_cage.material_override = gold_dark
	crystal_cage.set_meta("construction", "top_and_bottom_noncontact_suspension_terminals")
	crystal_cage.set_meta("terminal_count", 2)
	crystal_cage.set_meta("crystal_face_clear", true)
	crystal_cage.set_meta("minimum_crystal_clearance_m", 1.15)
	crystal_cage.set_meta("floating_crystal_supported_by_energy_field", true)
	shrine.add_child(crystal_cage)

	_spin_forever(spin_pivot, HEART_SHRINE_SPIN_SECONDS * 1.35)

	var shrine_light := OmniLight3D.new()
	shrine_light.name = "HeartShrineLight"
	shrine_light.light_color = Color("65b9ff")
	shrine_light.light_energy = 4.2
	shrine_light.omni_range = 90.0
	shrine_light.shadow_enabled = false
	shrine.add_child(shrine_light)


func _build_living_heart_wood_cradle(shrine: Node3D) -> void:
	# The gear is intentionally not buried. Six root-like ribs enlarge the trunk
	# silhouette behind and around it, while eight short wooden mounts terminate
	# at the gear rim. This leaves every tooth readable but gives every mechanical
	# component a visible load path back into living wood.
	var cradle := Node3D.new()
	cradle.name = "LivingHeartWoodCradle"
	cradle.set_meta("construction", "six_braided_wood_ribs_with_eight_gear_mounts")
	cradle.set_meta("wood_ribs", HEART_WOOD_CRADLE_RIB_COUNT)
	cradle.set_meta("gear_mounts", HEART_WOOD_CRADLE_MOUNT_COUNT)
	cradle.set_meta("gear_clear_aperture_radius", HEART_SHRINE_FRAME_RADIUS * 0.94)
	cradle.set_meta("mechanics_embedded_not_floating", true)
	shrine.add_child(cradle)

	var wood := _create_reference_tree_wood_palette()
	var rib_paths := [
		[Vector3(-15.0, -31.0, 3.1), Vector3(-25.0, -20.0, 3.3),
			Vector3(-29.0, -4.0, 3.6), Vector3(-26.0, 15.0, 3.5),
			Vector3(-13.0, 30.0, 3.2)],
		[Vector3(15.0, -31.0, 3.1), Vector3(25.0, -20.0, 3.3),
			Vector3(29.0, -4.0, 3.6), Vector3(26.0, 15.0, 3.5),
			Vector3(13.0, 30.0, 3.2)],
		[Vector3(-8.0, -34.0, 2.5), Vector3(-20.0, -20.0, 2.7),
			Vector3(-23.0, -2.0, 2.9), Vector3(-19.0, 17.0, 2.8),
			Vector3(-6.0, 33.0, 2.5)],
		[Vector3(8.0, -34.0, 2.5), Vector3(20.0, -20.0, 2.7),
			Vector3(23.0, -2.0, 2.9), Vector3(19.0, 17.0, 2.8),
			Vector3(6.0, 33.0, 2.5)],
		[Vector3(-17.0, 25.0, 3.0), Vector3(-8.0, 34.0, 3.1),
			Vector3(0.0, 37.0, 3.3), Vector3(8.0, 34.0, 3.1),
			Vector3(17.0, 25.0, 3.0)],
		[Vector3(-17.0, -25.0, 3.0), Vector3(-8.0, -35.0, 3.1),
			Vector3(0.0, -38.0, 3.3), Vector3(8.0, -35.0, 3.1),
			Vector3(17.0, -25.0, 3.0)],
	]
	for rib_index in rib_paths.size():
		var rib := MeshInstance3D.new()
		rib.name = "HeartWoodCradleRib_%02d" % (rib_index + 1)
		rib.mesh = _build_poly_tube_mesh(rib_paths[rib_index],
			[2.9, 2.55, 2.25, 1.95, 1.45], 8)
		rib.material_override = wood[1 + rib_index % 3]
		rib.set_meta("editable_component", true)
		cradle.add_child(rib)

	var inner_radius := HEART_SHRINE_FRAME_RADIUS * 1.03
	var outer_radius := HEART_SHRINE_FRAME_RADIUS * 1.42
	for mount_index in HEART_WOOD_CRADLE_MOUNT_COUNT:
		var angle := TAU * float(mount_index) / float(HEART_WOOD_CRADLE_MOUNT_COUNT)
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		var tangent := Vector3(-sin(angle), cos(angle), 0.0)
		var mount := MeshInstance3D.new()
		mount.name = "HeartWoodGearMount_%02d" % (mount_index + 1)
		mount.mesh = _build_poly_tube_mesh([
			radial * outer_radius + tangent * (1.2 if mount_index % 2 == 0 else -1.2)
				+ Vector3(0.0, 0.0, 3.0),
			radial * ((outer_radius + inner_radius) * 0.5)
				+ Vector3(0.0, 0.0, 2.5),
			radial * inner_radius + Vector3(0.0, 0.0, 1.8),
		], [1.35, 1.12, 0.82], 7)
		mount.material_override = wood[2 + mount_index % 2]
		mount.set_meta("terminates_at_gear_rim", true)
		cradle.add_child(mount)


func _build_heart_tree_socket(shrine: Node3D, gold: StandardMaterial3D,
		gold_dark: StandardMaterial3D) -> void:
	# This concentric socket is the missing structural transition between tree
	# and machine. Its dark cambium liner sits inside the bark, eight grown wood
	# anchors carry load to the rim, and paired bolts fasten every brass clamp.
	var socket := Node3D.new()
	socket.name = "HeartTreeGearSocket"
	socket.set_meta("embedded_in_living_tree", true)
	socket.set_meta("recess_fit", "concentric_tree_socket_to_gear_rim")
	socket.set_meta("wood_anchor_count", 8)
	socket.set_meta("brass_clamp_count", 8)
	socket.set_meta("brass_bolt_count", 16)
	socket.set_meta("gear_clearance_m", HEART_SHRINE_FRAME_RADIUS * 0.045)
	shrine.add_child(socket)

	var recess_material := _make_material(Color("160d0a"), 0.92)
	recess_material.metallic = 0.0
	var liner := MeshInstance3D.new()
	liner.name = "HeartTreeSocketLiner"
	var liner_mesh := TorusMesh.new()
	liner_mesh.inner_radius = HEART_SHRINE_FRAME_RADIUS * 1.02
	liner_mesh.outer_radius = HEART_SHRINE_FRAME_RADIUS * 1.34
	liner_mesh.rings = 36
	liner_mesh.ring_segments = 9
	liner.mesh = liner_mesh
	liner.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	liner.position.z = 4.15
	liner.material_override = recess_material
	liner.set_meta("purpose", "shadowed_cambium_recess_with_exact_gear_clearance")
	socket.add_child(liner)

	var wood := _create_reference_tree_wood_palette()
	var anchor_paths: Array = []
	var inner_radius := HEART_SHRINE_FRAME_RADIUS * 1.06
	var outer_radius := HEART_SHRINE_FRAME_RADIUS * 1.58
	for anchor_index in 8:
		var angle := TAU * float(anchor_index) / 8.0
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		var tangent := Vector3(-sin(angle), cos(angle), 0.0)
		var sway := 1.4 if anchor_index % 2 == 0 else -1.4
		anchor_paths.append([
			radial * outer_radius + tangent * sway + Vector3(0.0, 0.0, 4.7),
			radial * (outer_radius * 0.82) - tangent * sway * 0.45
				+ Vector3(0.0, 0.0, 3.5),
			radial * inner_radius + Vector3(0.0, 0.0, 1.85),
		])
	var anchors := MeshInstance3D.new()
	anchors.name = "HeartTreeSocketAnchorBundle"
	anchors.mesh = _build_poly_tube_bundle_mesh(anchor_paths, [2.35, 1.62, 0.82], 8)
	anchors.material_override = wood[1]
	anchors.set_meta("continuous_to_gear_rim", true)
	anchors.set_meta("natural_growth_sway", true)
	socket.add_child(anchors)

	var clamp_mesh := BoxMesh.new()
	clamp_mesh.size = Vector3(4.2, 1.45, 1.05)
	var clamp_transforms: Array[Transform3D] = []
	var bolt_mesh := CylinderMesh.new()
	bolt_mesh.top_radius = 0.36
	bolt_mesh.bottom_radius = 0.36
	bolt_mesh.height = 0.42
	bolt_mesh.radial_segments = 10
	var bolt_transforms: Array[Transform3D] = []
	for clamp_index in 8:
		var angle := TAU * float(clamp_index) / 8.0
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		var tangent := Vector3(-sin(angle), cos(angle), 0.0)
		var basis := Basis(Vector3.FORWARD, angle + PI * 0.5)
		clamp_transforms.append(Transform3D(
			basis, radial * inner_radius + Vector3(0.0, 0.0, 0.72)))
		for bolt_side in [-1.0, 1.0]:
			var bolt_basis := Basis(Vector3.RIGHT, PI * 0.5)
			bolt_transforms.append(Transform3D(bolt_basis,
				radial * (inner_radius - 0.10) + tangent * bolt_side * 1.34
					+ Vector3(0.0, 0.0, 0.08)))
	var clamps := _blueprint_add_joined_mesh(socket, "HeartTreeSocketClampBatch",
		clamp_mesh, clamp_transforms, gold_dark)
	clamps.set_meta("clamps_terminate_on_main_gear", true)
	var bolts := _blueprint_add_joined_mesh(socket, "HeartTreeSocketBoltBatch",
		bolt_mesh, bolt_transforms, gold)
	bolts.set_meta("paired_bolts_per_clamp", 2)


func _build_poly_tube_mesh(points: Array, radii: Array, sides: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for point_index in points.size():
		var point := points[point_index] as Vector3
		var previous := points[maxi(0, point_index - 1)] as Vector3
		var following := points[mini(points.size() - 1, point_index + 1)] as Vector3
		var tangent := (following - previous).normalized()
		var axis_a := tangent.cross(Vector3.FORWARD)
		if axis_a.length_squared() < 0.001:
			axis_a = tangent.cross(Vector3.UP)
		axis_a = axis_a.normalized()
		var axis_b := tangent.cross(axis_a).normalized()
		var radius := float(radii[mini(point_index, radii.size() - 1)])
		for side_index in sides:
			var angle := TAU * float(side_index) / float(sides)
			var normal := axis_a * cos(angle) + axis_b * sin(angle)
			vertices.append(point + normal * radius)
			normals.append(normal)
		if point_index > 0:
			var previous_ring := (point_index - 1) * sides
			var current_ring := point_index * sides
			for side_index in sides:
				var next_side := (side_index + 1) % sides
				indices.append_array(PackedInt32Array([
					previous_ring + side_index, current_ring + side_index,
					current_ring + next_side, previous_ring + side_index,
					current_ring + next_side, previous_ring + next_side,
				]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_poly_tube_bundle_mesh(paths: Array, radii: Array, sides: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for path_value in paths:
		var path := path_value as Array
		var tube := _build_poly_tube_mesh(path, radii, sides)
		var source := tube.surface_get_arrays(0)
		var vertex_offset := vertices.size()
		vertices.append_array(source[Mesh.ARRAY_VERTEX] as PackedVector3Array)
		normals.append_array(source[Mesh.ARRAY_NORMAL] as PackedVector3Array)
		for source_index in source[Mesh.ARRAY_INDEX] as PackedInt32Array:
			indices.append(vertex_offset + source_index)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _blueprint_add_joined_mesh(parent: Node3D, node_name: String,
		source_mesh: Mesh, transforms: Array[Transform3D], material: Material) -> MeshInstance3D:
	var source := source_mesh.surface_get_arrays(0)
	var source_vertices := source[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var source_normals := source[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var source_indices := PackedInt32Array()
	if source[Mesh.ARRAY_INDEX] is PackedInt32Array:
		source_indices = source[Mesh.ARRAY_INDEX] as PackedInt32Array
	# ArrayMesh sources created from explicit triangle vertices do not need an
	# index buffer. Generate the identity order so they can share this batching
	# path with indexed primitive meshes.
	if source_indices.is_empty():
		for source_index in source_vertices.size():
			source_indices.append(source_index)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for transform_value in transforms:
		var mesh_transform := transform_value as Transform3D
		var vertex_offset := vertices.size()
		for source_vertex in source_vertices:
			vertices.append(mesh_transform * source_vertex)
		for source_normal in source_normals:
			normals.append((mesh_transform.basis * source_normal).normalized())
		for source_index in source_indices:
			indices.append(vertex_offset + source_index)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var joined_mesh := ArrayMesh.new()
	joined_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = joined_mesh
	instance.material_override = material
	instance.set_meta("module_instances", transforms.size())
	instance.set_meta("joined_for_laptop_budget", true)
	parent.add_child(instance)
	return instance


func _build_heart_gear_frame(shrine: Node3D, gold: StandardMaterial3D,
		gold_dark: StandardMaterial3D) -> void:
	# A layered astrolabe around the gem: the toothed load-bearing rim reads as
	# engineering, the crossing orbits as science, and the eight luminous runes
	# bind it back into the tree's magical/natural energy system.
	_add_gear(shrine, "HeartGearMain", Vector3.ZERO, HEART_SHRINE_FRAME_RADIUS,
		HEART_GEAR_TEETH, 2.6, gold, HEART_GEAR_SECONDS, true)
	var dyson := Node3D.new()
	dyson.name = "HeartDysonSphereSystem"
	dyson.set_meta("runtime_system", true)
	dyson.set_meta("animated_orbital_axes", HEART_SHRINE_ORBIT_RINGS.size())
	dyson.set_meta("orbital_energy_collectors", 12)
	dyson.set_meta("inner_power_routes", 12)
	dyson.set_meta("secondary_concentric_rails", 2)
	dyson.set_meta("attached_to_tree_socket", true)
	shrine.add_child(dyson)
	_add_heart_orbit_rings(dyson, gold, gold_dark)
	_build_heart_dyson_sphere_detail(dyson, gold, gold_dark)
	_add_heart_frame_runes(shrine, gold, gold_dark)
	var mesh_radius := HEART_SHRINE_FRAME_RADIUS * 0.42
	for side in [-1.0, 1.0]:
		# Seated so their teeth meet the main cog's rim, and turning the other
		# way, which is what makes a gear train read as driven.
		var offset := Vector3(
			side * (HEART_SHRINE_FRAME_RADIUS + mesh_radius) * 0.86,
			(HEART_SHRINE_FRAME_RADIUS + mesh_radius) * 0.42 * side,
			1.2)
		_add_gear(shrine, "HeartGearIdler_%s" % ("L" if side < 0.0 else "R"),
			offset, mesh_radius, HEART_GEAR_IDLER_TEETH, 1.8, gold_dark,
			-HEART_GEAR_SECONDS * 0.42)

	var backing := MeshInstance3D.new()
	backing.name = "HeartGearBacking"
	var disc := CylinderMesh.new()
	disc.top_radius = HEART_SHRINE_FRAME_RADIUS * 0.86
	disc.bottom_radius = HEART_SHRINE_FRAME_RADIUS * 0.86
	disc.height = 1.4
	disc.radial_segments = 22
	backing.mesh = disc
	backing.material_override = _make_material(Color("15202f"), 0.6)
	backing.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	backing.position = Vector3(0.0, 0.0, 3.4)
	shrine.add_child(backing)


func _add_heart_orbit_rings(shrine: Node3D, gold: StandardMaterial3D,
		gold_dark: StandardMaterial3D) -> void:
	var collector_material := _make_glow(Color("45c9ff"), 0.74)
	collector_material.metallic = 0.18
	collector_material.roughness = 0.16
	for ring_index in HEART_SHRINE_ORBIT_RINGS.size():
		var specification: Dictionary = HEART_SHRINE_ORBIT_RINGS[ring_index]
		var pivot := Node3D.new()
		pivot.name = "HeartAstrolabeOrbit_%02d" % (ring_index + 1)
		pivot.rotation_degrees = Vector3(
			float(specification.tilt_x), 0.0, float(specification.tilt_z))
		shrine.add_child(pivot)

		var ring := MeshInstance3D.new()
		ring.name = "HeartAstrolabeOrbitRing_%02d" % (ring_index + 1)
		var torus := TorusMesh.new()
		torus.inner_radius = HEART_SHRINE_FRAME_RADIUS * (0.91 + ring_index * 0.045)
		torus.outer_radius = torus.inner_radius + 0.76
		torus.rings = 32
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = gold if ring_index != 1 else gold_dark
		ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		pivot.add_child(ring)

		# Four faceted collectors ride on each orbital axis. They are batched into
		# one mesh per ring and therefore add the Dyson-sphere silhouette without
		# twelve extra runtime draw calls.
		var collector_source := _build_faceted_crystal_mesh(0.54, 1.72, 6)
		var collector_transforms: Array[Transform3D] = []
		var collector_radius := HEART_SHRINE_FRAME_RADIUS * (0.945 + ring_index * 0.045)
		for collector_index in 4:
			var collector_angle := TAU * (float(collector_index) / 4.0
				+ float(ring_index) / 12.0)
			var collector_basis := Basis(Vector3.FORWARD, collector_angle - PI * 0.5)
			collector_transforms.append(Transform3D(
				collector_basis,
				Vector3(cos(collector_angle), sin(collector_angle), -0.28)
					* collector_radius))
		var collectors := _blueprint_add_joined_mesh(
			pivot, "HeartDysonOrbitCollectors_%02d" % (ring_index + 1),
			collector_source, collector_transforms, collector_material)
		collectors.set_meta("collector_count", 4)
		collectors.set_meta("rides_on_orbital_axis", true)
		_spin_forever(pivot, float(specification.seconds), "y")


func _build_heart_dyson_sphere_detail(dyson: Node3D,
		gold: StandardMaterial3D, gold_dark: StandardMaterial3D) -> void:
	# Two quiet inner rails and twelve cyan routes add machinery at close range
	# without competing with the crystal. All routes terminate on a rail, so the
	# energy pattern has no floating line ends.
	for rail_index in 2:
		var rail := MeshInstance3D.new()
		rail.name = "HeartDysonConcentricRail_%02d" % (rail_index + 1)
		var rail_mesh := TorusMesh.new()
		rail_mesh.inner_radius = HEART_SHRINE_FRAME_RADIUS * (0.52 + rail_index * 0.19)
		rail_mesh.outer_radius = rail_mesh.inner_radius + (0.46 if rail_index == 0 else 0.32)
		rail_mesh.rings = 30
		rail_mesh.ring_segments = 6
		rail.mesh = rail_mesh
		rail.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		rail.position.z = 1.35 + rail_index * 0.26
		rail.material_override = gold if rail_index == 0 else gold_dark
		rail.set_meta("concentric_with_blue_heart", true)
		dyson.add_child(rail)

	var lattice_paths: Array = []
	var inner_radius := HEART_SHRINE_FRAME_RADIUS * 0.54
	var outer_radius := HEART_SHRINE_FRAME_RADIUS * 0.72
	for route_index in 12:
		var angle := TAU * float(route_index) / 12.0
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		var tangent := Vector3(-sin(angle), cos(angle), 0.0)
		lattice_paths.append([
			radial * inner_radius + Vector3(0.0, 0.0, 1.10),
			radial * ((inner_radius + outer_radius) * 0.5)
				+ tangent * (0.58 if route_index % 2 == 0 else -0.58)
				+ Vector3(0.0, 0.0, 1.16),
			radial * outer_radius + Vector3(0.0, 0.0, 1.22),
		])
	var lattice := MeshInstance3D.new()
	lattice.name = "HeartDysonInnerPowerLattice"
	lattice.mesh = _build_poly_tube_bundle_mesh(lattice_paths, [0.18, 0.15, 0.11], 5)
	var lattice_material := _make_glow(Color("43c8ef"), 0.56)
	lattice_material.metallic = 0.12
	lattice_material.roughness = 0.22
	lattice.material_override = lattice_material
	lattice.set_meta("route_count", 12)
	lattice.set_meta("all_routes_terminate_on_rails", true)
	dyson.add_child(lattice)


func _add_heart_frame_runes(shrine: Node3D, gold: StandardMaterial3D,
		gold_dark: StandardMaterial3D) -> void:
	var rune_radius := HEART_SHRINE_FRAME_RADIUS * 1.18
	for rune_index in HEART_FRAME_RUNE_COUNT:
		var angle := TAU * float(rune_index) / float(HEART_FRAME_RUNE_COUNT)
		var rune_root := Node3D.new()
		rune_root.name = "HeartFrameRune_%02d" % (rune_index + 1)
		rune_root.position = Vector3(cos(angle) * rune_radius, sin(angle) * rune_radius, -0.4)
		rune_root.rotation.z = angle
		shrine.add_child(rune_root)

		var socket := MeshInstance3D.new()
		socket.name = "HeartFrameRuneSocket"
		var socket_mesh := TorusMesh.new()
		socket_mesh.inner_radius = 1.15
		socket_mesh.outer_radius = 1.82
		socket_mesh.rings = 14
		socket_mesh.ring_segments = 5
		socket.mesh = socket_mesh
		socket.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		socket.material_override = gold
		rune_root.add_child(socket)

		var jewel := MeshInstance3D.new()
		jewel.name = "HeartFrameRuneJewel"
		jewel.mesh = _build_faceted_crystal_mesh(0.68, 2.2, 6)
		jewel.material_override = _make_glow(
			Color("54dfff") if rune_index % 2 == 0 else Color("3f78ff"), 1.05)
		jewel.rotation.z = -angle
		rune_root.add_child(jewel)

	for spoke_index in HEART_FRAME_SPOKE_COUNT:
		var angle := TAU * float(spoke_index) / float(HEART_FRAME_SPOKE_COUNT)
		var spoke := MeshInstance3D.new()
		spoke.name = "HeartFrameRadialSpoke_%02d" % (spoke_index + 1)
		var spoke_mesh := BoxMesh.new()
		spoke_mesh.size = Vector3(HEART_SHRINE_FRAME_RADIUS * 0.31, 0.48, 0.60)
		spoke.mesh = spoke_mesh
		spoke.position = Vector3(cos(angle), sin(angle), 0.3) \
			* HEART_SHRINE_FRAME_RADIUS * 0.69
		spoke.rotation.z = angle
		spoke.material_override = gold_dark
		shrine.add_child(spoke)


func _add_gear(parent: Node3D, gear_name: String, offset: Vector3, radius: float,
		teeth: int, rim_depth: float, material: StandardMaterial3D,
		seconds: float, open_center := false) -> void:
	var pivot := Node3D.new()
	pivot.name = gear_name
	pivot.position = offset
	pivot.set_meta("continuous_load_bearing_rim", true)
	pivot.set_meta("teeth_connected_to_rim", true)
	pivot.set_meta("connected_tooth_count", teeth)
	pivot.set_meta("open_crystal_aperture", open_center)
	pivot.set_meta("tooth_root_overlap_m", rim_depth * 0.75)
	parent.add_child(pivot)

	var rim := MeshInstance3D.new()
	rim.name = "%s_Rim" % gear_name
	var torus := TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + rim_depth
	torus.rings = 26
	torus.ring_segments = 6
	rim.mesh = torus
	rim.material_override = material
	# TorusMesh lies flat; stand it up so the cog faces the player.
	rim.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	pivot.add_child(rim)

	# The main heart gear is an annular bearing with a completely open aperture.
	# Only the smaller idlers need hubs and spokes.
	if not open_center:
		var hub := MeshInstance3D.new()
		hub.name = "%s_Hub" % gear_name
		var hub_mesh := CylinderMesh.new()
		hub_mesh.top_radius = radius * 0.22
		hub_mesh.bottom_radius = radius * 0.22
		hub_mesh.height = rim_depth * 1.5
		hub_mesh.radial_segments = 10
		hub.mesh = hub_mesh
		hub.material_override = material
		hub.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		pivot.add_child(hub)

		for spoke_index in 4:
			var spoke := MeshInstance3D.new()
			spoke.name = "%s_Spoke_%02d" % [gear_name, spoke_index]
			var spoke_mesh := BoxMesh.new()
			spoke_mesh.size = Vector3(radius * 1.55, rim_depth * 0.5, rim_depth * 0.9)
			spoke.mesh = spoke_mesh
			spoke.material_override = material
			spoke.rotation.z = PI * float(spoke_index) / 4.0
			pivot.add_child(spoke)

	for tooth_index in teeth:
		var angle := TAU * float(tooth_index) / float(teeth)
		var tooth := MeshInstance3D.new()
		tooth.name = "%s_Tooth_%02d" % [gear_name, tooth_index]
		var tooth_mesh := BoxMesh.new()
		# A deep radial root overlaps three quarters of the continuous torus rim.
		# That overlap removes the visible air gap from the previous prototype.
		tooth_mesh.size = Vector3(rim_depth * 1.50, rim_depth * 1.42, rim_depth * 1.15)
		tooth.mesh = tooth_mesh
		tooth.material_override = material
		tooth.position = Vector3(
			cos(angle) * (radius + rim_depth),
			sin(angle) * (radius + rim_depth),
			0.0)
		tooth.rotation.z = angle
		tooth.set_meta("connected_to_continuous_rim", true)
		tooth.set_meta("radial_root_overlap_m", rim_depth * 0.75)
		pivot.add_child(tooth)

	_spin_forever(pivot, seconds, "z")


func _spin_forever(pivot: Node3D, seconds: float, axis: String = "y") -> void:
	# A looping tween rather than _process: the rotation keeps running without
	# this world script paying a per-frame callback for decoration.
	#
	# The axis matters: a cog faces the player, so it has to turn about Z. Turned
	# about Y it goes edge-on twice a revolution and disappears.
	var spin := pivot.create_tween().set_loops()
	spin.tween_property(pivot, "rotation:%s" % axis,
		TAU * signf(seconds), absf(seconds)).from(0.0)


func _make_crystal_outline_material() -> StandardMaterial3D:
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = Color("06103a")
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = HEART_SHRINE_OUTLINE_GROW
	return outline


func _heart_shrine_height(tree: Node3D) -> float:
	# The blueprint fixes the heart centre at 14 m. Deriving it from whichever
	# legacy doorway mesh happens to be visible caused the elevation to drift.
	return TREE_BLUEPRINT_HEART_HEIGHT


func _heart_outline_points(width: float, height: float, depth := 0.0) -> Array[Vector3]:
	# A restrained ten-point heart: the upper notch is shallow enough to remain a
	# sacred crystal rather than a cartoon icon, while the long lower taper keeps
	# the approved Tree-of-Life diamond character.
	var half_width := width * 0.5
	return [
		Vector3(0.0, height * 0.43, depth),
		Vector3(-half_width * 0.30, height * 0.50, depth),
		Vector3(-half_width * 0.78, height * 0.44, depth),
		Vector3(-half_width, height * 0.20, depth),
		Vector3(-half_width * 0.86, -height * 0.08, depth),
		Vector3(-half_width * 0.48, -height * 0.31, depth),
		Vector3(0.0, -height * 0.56, depth),
		Vector3(half_width * 0.48, -height * 0.31, depth),
		Vector3(half_width * 0.86, -height * 0.08, depth),
		Vector3(half_width, height * 0.20, depth),
		Vector3(half_width * 0.78, height * 0.44, depth),
		Vector3(half_width * 0.30, height * 0.50, depth),
	]


func _build_faceted_heart_crystal_mesh(
		width: float, height: float, depth: float) -> ArrayMesh:
	var outline := _heart_outline_points(width, height)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	# Front and rear centres project beyond the outline plane, producing broad
	# triangular facets that catch the blue core light at close player distance.
	for face_sign in [-1.0, 1.0]:
		for point_index in outline.size():
			var next_index := (point_index + 1) % outline.size()
			var centre := Vector3(0.0, -height * 0.01, face_sign * depth)
			var edge_a := Vector3(outline[point_index].x,
				outline[point_index].y, face_sign * depth * 0.42)
			var edge_b := Vector3(outline[next_index].x,
				outline[next_index].y, face_sign * depth * 0.42)
			var triangle := [centre, edge_b, edge_a] if face_sign < 0.0 \
				else [centre, edge_a, edge_b]
			var normal := ((triangle[1] as Vector3) - (triangle[0] as Vector3)).cross(
				(triangle[2] as Vector3) - (triangle[0] as Vector3)).normalized()
			for point in triangle:
				vertices.append(point)
				normals.append(normal)
	# Close the thickness with faceted side quads.
	for point_index in outline.size():
		var next_index := (point_index + 1) % outline.size()
		var front_a := Vector3(outline[point_index].x,
			outline[point_index].y, -depth * 0.42)
		var front_b := Vector3(outline[next_index].x,
			outline[next_index].y, -depth * 0.42)
		var back_a := Vector3(outline[point_index].x,
			outline[point_index].y, depth * 0.42)
		var back_b := Vector3(outline[next_index].x,
			outline[next_index].y, depth * 0.42)
		for triangle in [[front_a, back_b, front_b], [front_a, back_a, back_b]]:
			var corner_a := triangle[0] as Vector3
			var corner_b := triangle[1] as Vector3
			var corner_c := triangle[2] as Vector3
			var normal := (corner_b - corner_a).cross(corner_c - corner_a).normalized()
			for point in triangle:
				vertices.append(point)
				normals.append(normal)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.resource_name = "FacetedWisdomHeartCrystal"
	return mesh


func _build_heart_crystal_facet_lattice_mesh(
		width: float, height: float, depth: float, radius: float) -> ArrayMesh:
	var outline := _heart_outline_points(width, height)
	var paths: Array = []
	# Duplicate the complete perimeter and radial triangle fan on the front and
	# rear planes. When the heart turns edge-on, the side walls join both planes,
	# making its diamond thickness and angular construction readable in motion.
	for face_sign in [-1.0, 1.0]:
		var edge_z: float = float(face_sign) * (depth * 0.42 + radius * 0.70)
		var apex_z: float = float(face_sign) * (depth + radius * 0.70)
		var centre := Vector3(0.0, -height * 0.01, apex_z)
		for point_index in outline.size():
			var next_index := (point_index + 1) % outline.size()
			var edge_a := Vector3(outline[point_index].x,
				outline[point_index].y, edge_z)
			var edge_b := Vector3(outline[next_index].x,
				outline[next_index].y, edge_z)
			paths.append([edge_a, edge_b])
			paths.append([centre, edge_a])
	# Four longitudinal corner seams reveal the depth without turning the shell
	# into a wire cage. These are the left/right shoulders and upper/lower tips.
	for outline_index in [0, 3, 6, 9]:
		var corner := outline[outline_index] as Vector3
		paths.append([
			Vector3(corner.x, corner.y, -depth * 0.44),
			Vector3(corner.x, corner.y, depth * 0.44),
		])
	return _build_poly_tube_bundle_mesh(paths, [radius, radius], 5)


func _build_heart_outline_tube_mesh(width: float, height: float,
		radius: float, sides: int) -> ArrayMesh:
	var path: Array[Vector3] = _heart_outline_points(width, height)
	path.append(path[0])
	var radii: Array[float] = []
	for _point in path:
		radii.append(radius)
	return _build_poly_tube_mesh(path, radii, sides)


func _build_faceted_crystal_mesh(radius: float, height: float, sides: int) -> ArrayMesh:
	# A bipyramid, the same construction the Blender source uses for the heart
	# crystals, so the runtime shrine matches the authored faceting.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var top := Vector3(0.0, height * 0.56, 0.0)
	var bottom := Vector3(0.0, -height * 0.56, 0.0)
	for index in sides:
		var angle := TAU * float(index) / float(sides)
		var next_angle := TAU * float(index + 1) / float(sides)
		var a := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var b := Vector3(cos(next_angle) * radius, 0.0, sin(next_angle) * radius)
		for triangle in [[top, a, b], [bottom, b, a]]:
			var corner_a: Vector3 = triangle[0]
			var corner_b: Vector3 = triangle[1]
			var corner_c: Vector3 = triangle[2]
			var normal := (corner_b - corner_a).cross(corner_c - corner_a).normalized()
			for point in [corner_a, corner_b, corner_c]:
				vertices.append(point)
				normals.append(normal)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

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
	var unified_root_meshes := 0
	var root_wood := _create_reference_tree_wood_palette()
	var root_gold := _make_glow(Color("d2a94f"), 0.70)
	root_gold.metallic = 0.42
	root_gold.roughness = 0.48
	for mesh_node in previous_canopy.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_node as MeshInstance3D
		if mesh.name.begins_with("EditablePrimaryRootJoint_") \
				or mesh.name.begins_with("EditableSecondaryRootJoint_"):
			# Blender editing collars are useful authoring handles but read as
			# detached hoops in game, interrupting the continuous root silhouette.
			mesh.visible = false
		elif mesh.name.begins_with("LivingButtressRoot_") \
				or mesh.name.begins_with("SecondaryGroundRoot_"):
			# The old root skirt and new core are one biological structure. Sharing
			# the exact palette removes the former material boundary at their overlap.
			for surface_index in mesh.mesh.get_surface_count():
				mesh.set_surface_override_material(
					surface_index, root_wood[1 + surface_index % 3])
			unified_root_meshes += 1
		elif mesh.name.begins_with("RootMechanicalClamp_") \
				or mesh.name.begins_with("RootClampPowerBlock_"):
			mesh.material_override = root_gold
		# The sap channels trace the OLD radial branch layout, so showing them
		# once those branches are hidden leaves blue lines sticking out past the
		# new canopy - the horizontal streaks noted below.
		if mesh.name.begins_with("BioTechBranch_") \
				or mesh.name.begins_with("CyanSapChannel_") \
				or mesh.name.begins_with("BrassArticulationCollar_") \
				or mesh.name.begins_with("LeafSupportTwig_") \
				or mesh.name.begins_with("LeafSupportCyanChannel_") \
				or mesh.name.begins_with("DoorwayLivingRootJamb_") \
				or mesh.name.begins_with("DoorwayElectricFiber_") \
				or mesh.name.begins_with("EditableDoorwayRootJoint_"):
			mesh.visible = false
		if mesh.name.begins_with("RootCyanSapInlay_") \
				or mesh.name.begins_with("SecondaryRootCyanInlay_") \
				or mesh.name.begins_with("RootRadialPowerFeeder_") \
				or mesh.name.begins_with("RootCyanTributary_"):
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
	canopy.set_meta("runtime_leaf_scale", 1.34)
	canopy.set_meta("main_flow_streaks_removed", true)
	canopy.set_meta("leaf_twig_streaks_removed", true)
	canopy.set_meta("lateral_streaks_removed", true)
	canopy.set_meta("lateral_sap_streaks_removed", true)
	canopy.set_meta("visible_branch_energy", "three_strand_main_biofiber_braid")
	canopy.set_meta("floating_crystal_transfer_nodes_preserved", true)
	canopy.set_meta("powered_root_fiber_meshes", powered_root_fiber_meshes)
	canopy.set_meta("unified_reference_wood_root_meshes", unified_root_meshes)
	canopy.set_meta("root_core_radial_overlap_m", 2.0)
	canopy.set_meta("root_to_leaf_energy_continuity", true)
	canopy.set_meta("living_tree_silhouette", "six_irregular_root_to_crown_branch_layers")
	canopy.set_meta("age_language", "century_old_long_reaching_layered_boughs")
	canopy.set_meta("leaf_colour_semantics", {
		"technology": "electric_blue",
		"magic": "aether_violet",
		"nature": "living_green",
	})
	canopy.set_meta("gold_mechanical_branch_collars", true)
	canopy.set_meta("canopy_collision", false)
	canopy.set_meta("blueprint_total_height", TREE_BLUEPRINT_TOTAL_HEIGHT)
	canopy.set_meta("blueprint_max_width", TREE_BLUEPRINT_CANOPY_RADIUS * 2.0)
	canopy.scale = Vector3.ONE * TREE_OF_LIFE_BODY_RATIO
	tree.add_child(canopy)

	var module_transforms: Array[Transform3D] = []
	var cluster_index := 0
	var growth_per_cluster := WEB_BOUGH_GROWTH_PER_CLUSTER if _use_web_lod() \
		else BOUGH_GROWTH_PER_CLUSTER
	# Canopy modules are authored in pre-ratio units, so bring the heart's world
	# height back into the same space before comparing tier heights against it.
	var niche_centre := _heart_shrine_height(tree) / TREE_OF_LIFE_BODY_RATIO
	var niche_reach := HEART_SHRINE_FRAME_RADIUS * HEART_SHRINE_OVAL_STRETCH \
		* HEART_SHRINE_SCALE * HEART_NICHE_MARGIN
	var niche_low := niche_centre - niche_reach
	var niche_high := niche_centre + niche_reach
	# Published so the ornament pass keeps the same volume clear.
	canopy.set_meta("heart_niche_centre", niche_centre)
	canopy.set_meta("heart_niche_reach", niche_reach)
	canopy.set_meta("heart_niche_half_width",
		HEART_SHRINE_FRAME_RADIUS * HEART_SHRINE_SCALE * HEART_NICHE_CLEAR_WIDTH_MARGIN)
	canopy.set_meta("heart_niche_half_height", HEART_SHRINE_FRAME_RADIUS \
		* HEART_SHRINE_OVAL_STRETCH * HEART_SHRINE_SCALE \
		* HEART_NICHE_CLEAR_HEIGHT_MARGIN)
	# Christmas-tree silhouette: evenly spaced whorls tapering from a wide base to
	# the star, branch length shrinking with height, and pitch sweeping from a
	# droop at the bottom to a lift at the crown, which is what separates a fir
	# from a lollipop.
	for tier_spec in [
		{"count": 10, "height": 32.0, "radius": 11.8, "scale": 3.45, "pitch": -11.0, "phase": 0.10, "length": 1.22},
		{"count": 10, "height": 41.0, "radius": 10.8, "scale": 3.22, "pitch": -8.0, "phase": 0.42, "length": 1.25},
		{"count": 9, "height": 50.0, "radius": 9.8, "scale": 2.98, "pitch": -5.0, "phase": 0.74, "length": 1.28},
		{"count": 9, "height": 59.0, "radius": 8.9, "scale": 2.74, "pitch": -1.0, "phase": 0.16, "length": 1.31},
		{"count": 8, "height": 68.0, "radius": 7.9, "scale": 2.49, "pitch": 4.0, "phase": 0.55, "length": 1.35},
		{"count": 8, "height": 77.0, "radius": 7.0, "scale": 2.24, "pitch": 8.0, "phase": 0.28, "length": 1.40},
		{"count": 7, "height": 86.0, "radius": 6.1, "scale": 2.00, "pitch": 12.0, "phase": 0.66, "length": 1.47},
		{"count": 6, "height": 95.0, "radius": 5.2, "scale": 1.75, "pitch": 16.0, "phase": 0.34, "length": 1.55},
		{"count": 6, "height": 104.0, "radius": 4.4, "scale": 1.50, "pitch": 20.0, "phase": 0.71, "length": 1.64},
		{"count": 5, "height": 113.0, "radius": 3.6, "scale": 1.25, "pitch": 24.0, "phase": 0.20, "length": 1.74},
		{"count": 4, "height": 121.0, "radius": 2.8, "scale": 1.02, "pitch": 28.0, "phase": 0.60, "length": 1.84},
		{"count": 4, "height": 128.0, "radius": 2.2, "scale": 0.84, "pitch": 32.0, "phase": 0.38, "length": 1.94},
		{"count": 3, "height": 134.0, "radius": 1.6, "scale": 0.68, "pitch": 36.0, "phase": 0.80, "length": 2.04},
	]:
		var count := int(tier_spec.count)
		var tier_length := float(tier_spec.get("length", BOUGH_DEFAULT_LENGTH))
		for tier_index in count:
			var irregularity := sin(float(tier_index) * 2.17 + float(cluster_index) * 0.43)
			var yaw := TAU * float(tier_index) / float(count) + float(tier_spec.phase)
			yaw += irregularity * 0.095
			var cluster_root := Vector3(
				cos(yaw) * (float(tier_spec.radius) + irregularity * 0.65),
				float(tier_spec.height) + irregularity * 2.2,
				sin(yaw) * (float(tier_spec.radius) + irregularity * 0.65))
			# South is -Z, which is where the heart sits. Leave that arc clear
			# through the heart's own height band so nothing curtains it.
			var height_value := float(tier_spec.height)
			if height_value >= niche_low and height_value <= niche_high:
				var south_delta := absf(wrapf(yaw - PI * 1.5, -PI, PI))
				if south_delta < deg_to_rad(HEART_NICHE_ARC_DEGREES):
					cluster_index += 1
					continue
			var radial := Vector3(cos(yaw), 0.0, sin(yaw))
			var tangent := Vector3(-sin(yaw), 0.0, cos(yaw))
			for growth_index in growth_per_cluster:
				var growth_phase := TAU * float(growth_index) / float(growth_per_cluster)
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
				var scaled_basis := orientation * Basis.from_scale(
					Vector3(tier_length, 1.0, 1.0) * module_scale)
				var authored_root_socket := Vector3(-18.0, 1.0, 0.0)
				module_transforms.append(Transform3D(
					scaled_basis, root_target - scaled_basis * authored_root_socket))
			cluster_index += 1
	_batch_powered_bough_canopy(canopy, module_transforms, flow_material)
	_build_gold_branch_collars(canopy, module_transforms)
	canopy.set_meta("heart_niche_projection_clear",
		int(canopy.get_meta("heart_niche_culled_instances", 0)) > 0)
	_build_canopy_ornaments(canopy, module_transforms)

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



# Baubles hung along the whorls. Three colours ride the branches and every
# fitting - cap and hanger - is gold, matching the star and the shrine rings.
const ORNAMENT_COLOURS := [
	Color("d62839"),
	Color("1f6bd8"),
	Color("7a3bd6"),
]
const ORNAMENT_EVERY_NTH_BOUGH := 1
const ORNAMENT_RADIUS := 2.0
# Ornaments per bough, spaced along its length so they run from the lowest
# whorl to the crown rather than clustering at the branch tips.
const ORNAMENT_PER_BOUGH := 3
const ORNAMENT_ALONG_BOUGH := [11.0, 15.5, 19.5]
# Multiplied by the bough's own scale, so baubles clear the foliage on the big
# lower whorls as well as the small crown ones.
const ORNAMENT_DROP_FACTOR := 5.4


func _build_canopy_ornaments(
		canopy: Node3D, module_transforms: Array[Transform3D]) -> void:
	# One MultiMesh per colour plus one for the gold fittings, so the whole
	# decoration is four draws no matter how many baubles hang.
	var hang_points: Array[Transform3D] = []
	var niche_centre := canopy.get_meta("heart_niche_centre", 0.0) as float
	var niche_reach := canopy.get_meta("heart_niche_reach", 0.0) as float
	for module_index in module_transforms.size():
		if module_index % ORNAMENT_EVERY_NTH_BOUGH != 0:
			continue
		var module_transform := module_transforms[module_index]
		# Boughs run along local X, so step along that axis and let each bauble
		# drop straight down in world space, the way a real ornament hangs.
		# Boughs are scaled up to 3.3x, so their foliage is metres thick. A drop
		# measured in world units leaves every bauble buried inside the leaves;
		# it has to scale with the bough it hangs from.
		var bough_scale := module_transform.basis.get_scale().y
		for slot in ORNAMENT_PER_BOUGH:
			var along := float(ORNAMENT_ALONG_BOUGH[slot % ORNAMENT_ALONG_BOUGH.size()])
			var sway := float((module_index + slot) % 3) - 1.0
			var anchor := module_transform * Vector3(along, 0.0, sway * 1.6)
			var drop := bough_scale * (ORNAMENT_DROP_FACTOR
				+ float((module_index + slot) % 4) * 0.55)
			var placed_at := anchor + Vector3.DOWN * drop
			# Keep the heart's niche clear of hanging decoration too.
			if niche_reach > 0.0 and placed_at.z < 0.0 \
					and absf(placed_at.y - niche_centre) < niche_reach \
					and absf(placed_at.x) < niche_reach:
				continue
			hang_points.append(Transform3D(Basis.IDENTITY, placed_at))
	if hang_points.is_empty():
		return

	var sphere := SphereMesh.new()
	sphere.radius = ORNAMENT_RADIUS
	sphere.height = ORNAMENT_RADIUS * 2.0
	sphere.radial_segments = 10
	sphere.rings = 6

	for colour_index in ORNAMENT_COLOURS.size():
		var subset: Array[Transform3D] = []
		for point_index in hang_points.size():
			if point_index % ORNAMENT_COLOURS.size() == colour_index:
				subset.append(hang_points[point_index])
		if subset.is_empty():
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = sphere
		multimesh.instance_count = subset.size()
		for index in subset.size():
			multimesh.set_instance_transform(index, subset[index])
		var batch := MultiMeshInstance3D.new()
		batch.name = "CanopyOrnamentBatch_%02d" % colour_index
		batch.multimesh = multimesh
		batch.material_override = _make_glow(
			ORNAMENT_COLOURS[colour_index], 0.65)
		batch.set_meta("ornament_count", subset.size())
		canopy.add_child(batch)

	# Gold caps and hangers, one per bauble.
	var cap := CylinderMesh.new()
	cap.top_radius = ORNAMENT_RADIUS * 0.30
	cap.bottom_radius = ORNAMENT_RADIUS * 0.52
	cap.height = ORNAMENT_RADIUS * 1.55
	cap.radial_segments = 8
	var cap_multimesh := MultiMesh.new()
	cap_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	cap_multimesh.mesh = cap
	cap_multimesh.instance_count = hang_points.size()
	for index in hang_points.size():
		var fitting := hang_points[index]
		fitting.origin += Vector3.UP * (ORNAMENT_RADIUS * 1.35)
		cap_multimesh.set_instance_transform(index, fitting)
	var cap_batch := MultiMeshInstance3D.new()
	cap_batch.name = "CanopyOrnamentCapBatch"
	cap_batch.multimesh = cap_multimesh
	cap_batch.material_override = _make_glow(Color("e8bf63"), 0.45)
	canopy.add_child(cap_batch)
	canopy.set_meta("ornaments", hang_points.size())


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
		flow_material: ShaderMaterial, lightweight_lod := false) -> void:
	# The compact Blender runtime source contains one joined living-wood branch,
	# one joined biofiber network, four linked leaf meshes and crystal transfer
	# nodes.  Combining all 480 smaller bough placements into seven MultiMeshes
	# gives the requested tenfold population without 480 heavy scene hierarchies.
	var template := PoweredGravityBoughScene.instantiate() as Node3D
	_batch_powered_bough_meshes(
		parent, template, "GravityBough_CombinedStructure*",
		"PoweredBranchStructureBatch", module_transforms, null, 1, 1.0, lightweight_lod)
	_batch_powered_bough_meshes(
		parent, template, "Biofiber_CombinedFlow*",
		"PoweredBranchBiofiberBatch", module_transforms, flow_material, 1, 1.0, lightweight_lod)
	for family in [
		"living_leaf_fan", "magic_rune_leaf",
		"solar_glass_science_leaf", "emerald_sensor_leaf",
	]:
		_batch_powered_bough_meshes(
			parent, template, "GravityBough_SocketLeaf_%s_*" % family,
			"PoweredLeafBatch_%s" % family, module_transforms,
			_leaf_family_material(family), 1 if lightweight_lod else 2,
			0.34 if lightweight_lod else 1.34, lightweight_lod)
	_batch_powered_bough_meshes(
		parent, template, "Biofiber_LeafTransferNode_*",
		"PoweredLeafTransferNodeBatch", module_transforms, flow_material,
		1 if lightweight_lod else 2, 0.78, lightweight_lod)
	# Biofiber_MainFlowPulse geometry intentionally is not batched. Those pulses
	# were the unexplained horizontal white/cyan streaks above the crown. Floating
	# crystal transfer nodes remain in their dedicated batch.
	template.free()


func _leaf_family_material(family: String) -> StandardMaterial3D:
	# The palette is semantic, not random decoration: blue carries technology
	# and science, violet carries magic, and both greens carry living nature.
	var colour := Color("2cae64")
	var energy := 0.12
	match family:
		"magic_rune_leaf":
			colour = Color("a45cff")
			energy = 0.20
		"solar_glass_science_leaf":
			colour = Color("24bfff")
			energy = 0.24
		"emerald_sensor_leaf":
			colour = Color("62e68f")
			energy = 0.14
		_:
			colour = Color("2cae64")
	var material := _make_glow(colour, energy)
	material.roughness = 0.46 if family == "solar_glass_science_leaf" else 0.72
	material.metallic = 0.18 if family == "solar_glass_science_leaf" else 0.02
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _build_gold_branch_collars(
		canopy: Node3D, module_transforms: Array[Transform3D]) -> void:
	# One instanced collar at each living-bough graft makes gold read as a grown
	# mechanical skeleton rather than paint applied to the leaves.
	var collar_mesh := TorusMesh.new()
	collar_mesh.inner_radius = 1.28
	collar_mesh.outer_radius = 1.82
	collar_mesh.rings = 12
	collar_mesh.ring_segments = 5
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = collar_mesh
	multimesh.instance_count = module_transforms.size()
	var socket := Vector3(-18.0, 1.0, 0.0)
	for index in module_transforms.size():
		var module_transform := module_transforms[index]
		var thickness := module_transform.basis.get_scale().y
		var orientation := module_transform.basis.orthonormalized() \
			* Basis(Vector3.FORWARD, -PI * 0.5)
		var basis := orientation.scaled(Vector3.ONE * thickness)
		multimesh.set_instance_transform(index,
			Transform3D(basis, module_transform * socket))
	var batch := MultiMeshInstance3D.new()
	batch.name = "PoweredBranchGoldCollarBatch"
	batch.multimesh = multimesh
	var gold := _make_glow(Color("e3b84f"), 0.38)
	gold.metallic = 0.78
	gold.roughness = 0.24
	batch.material_override = gold
	batch.set_meta("collar_instances", module_transforms.size())
	batch.set_meta("meaning", "engineering_articulation_on_living_wood")
	canopy.add_child(batch)
	canopy.set_meta("gold_branch_collar_instances", module_transforms.size())


func _batch_powered_bough_meshes(
		parent: Node3D, template: Node3D, pattern: String, batch_name: String,
		module_transforms: Array[Transform3D], material_override: Material,
		growth_layers_arg: int, local_scale: float, lightweight_lod := false) -> void:
	var growth_layers := growth_layers_arg
	var meshes := template.find_children(pattern, "MeshInstance3D", true, false)
	if meshes.is_empty():
		push_warning("Powered bough runtime pattern has no meshes: %s" % pattern)
		return
	var is_leaf_batch := batch_name.begins_with("PoweredLeafBatch_")
	var web_lod := _use_web_lod()
	var leaf_lod := is_leaf_batch and (web_lod or lightweight_lod)
	if (web_lod or lightweight_lod) and batch_name == "PoweredLeafTransferNodeBatch":
		# 1.24 M instances of a 20 triangle node reads as nothing at web draw
		# distances while costing a full extra MultiMesh pass.
		return
	var first_mesh := meshes[0] as MeshInstance3D
	var source_transforms: Array[Transform3D] = []
	var stride := LAPTOP_TREE_LEAF_SOCKET_STRIDE if lightweight_lod and is_leaf_batch \
		else WEB_LEAF_SOCKET_STRIDE if web_lod and is_leaf_batch else 1
	for source_index in meshes.size():
		if source_index % stride != 0:
			continue
		source_transforms.append(_node_transform_relative_to(
			meshes[source_index] as Node3D, template))
	if leaf_lod:
		growth_layers = mini(growth_layers, WEB_LEAF_GROWTH_LAYERS)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _web_leaf_card(first_mesh) if leaf_lod \
		else first_mesh.mesh
	var source_count := source_transforms.size()
	multimesh.instance_count = module_transforms.size() * source_count * growth_layers
	var output_index := 0
	var niche_culled_instances := 0
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
				var placed := module_transform * local_transform
				if is_leaf_batch:
					# Keep the leaf's own shape: take its position from the
					# stretched branch, but rebuild the basis unstretched, using
					# the module's unscaled axis for size.
					var leaf_scale := module_transform.basis.get_scale().y
					placed.basis = placed.basis.orthonormalized().scaled(
						Vector3.ONE * leaf_scale * local_scale)
				if is_leaf_batch and _instance_overlaps_heart_niche(
						parent, placed, multimesh.mesh, true):
					# MultiMesh keeps a fixed allocation for predictable Web memory and
					# existing asset-count contracts. A zero basis culls only this visual
					# instance while preserving the rest of the authored canopy.
					placed.basis = Basis.from_scale(Vector3.ZERO)
					niche_culled_instances += 1
				multimesh.set_instance_transform(output_index, placed)
				output_index += 1
	var batch := MultiMeshInstance3D.new()
	batch.name = batch_name
	batch.multimesh = multimesh
	batch.material_override = material_override
	if lightweight_lod:
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.set_meta("source_meshes", source_count)
	batch.set_meta("module_instances", module_transforms.size())
	batch.set_meta("growth_layers", growth_layers)
	batch.set_meta("lightweight_lod", lightweight_lod)
	batch.set_meta("heart_niche_culled_instances", niche_culled_instances)
	parent.set_meta("heart_niche_culled_instances",
		int(parent.get_meta("heart_niche_culled_instances", 0)) + niche_culled_instances)
	parent.add_child(batch)


func _instance_overlaps_heart_niche(parent: Node3D, placed: Transform3D,
		mesh: Mesh, use_origin: bool) -> bool:
	var half_width := float(parent.get_meta("heart_niche_half_width", 0.0))
	var half_height := float(parent.get_meta("heart_niche_half_height", 0.0))
	if half_width <= 0.0 or half_height <= 0.0:
		return false
	var centre_y := float(parent.get_meta("heart_niche_centre", 0.0))
	if use_origin:
		# Leaves and their transfer crystals are small relative to the opening;
		# padding catches their tips without doing 1.2 million AABB transforms.
		return absf(placed.origin.x) < half_width + HEART_NICHE_LEAF_PADDING \
			and absf(placed.origin.y - centre_y) < half_height + HEART_NICHE_LEAF_PADDING
	if mesh == null:
		return false
	# A joined branch can cross the opening even when its root is well outside
	# it, which is the failure the former root-angle check could not detect.
	var bounds := placed * mesh.get_aabb()
	var bounds_end := bounds.position + bounds.size
	return bounds.position.x < half_width and bounds_end.x > -half_width \
		and bounds.position.y < centre_y + half_height \
		and bounds_end.y > centre_y - half_height


func _web_leaf_card(source: MeshInstance3D) -> Mesh:
	# Each authored leaf is a 6,336 triangle compound cluster. At canopy distance
	# on Web it reads as a coloured shape, so replace it with a single card of the
	# same footprint carrying the same material - two triangles instead of 6,336.
	var source_mesh := source.mesh
	if source_mesh == null:
		return null
	var bounds := source_mesh.get_aabb()
	var half_width := maxf(bounds.size.x, 0.05) * 0.5
	var half_length := maxf(bounds.size.z, 0.05) * 0.5
	# A tapered four-point silhouette still costs only two triangles, but reads as
	# an individual leaf instead of a rectangular panel.
	var vertices := PackedVector3Array([
		Vector3(0.0, 0.0, -half_length),
		Vector3(-half_width, 0.0, -half_length * 0.08),
		Vector3(0.0, 0.0, half_length),
		Vector3(half_width, 0.0, -half_length * 0.08),
	])
	var normals := PackedVector3Array([
		Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP,
	])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var card := ArrayMesh.new()
	card.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := source_mesh.surface_get_material(0)
	if material == null:
		material = source.material_override
	if material is StandardMaterial3D:
		# A card has no thickness, so it must not vanish when seen from beneath.
		var flat := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
		flat.cull_mode = BaseMaterial3D.CULL_DISABLED
		material = flat
	card.surface_set_material(0, material)
	return card

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
	// Blue, to match the heart crystal the fibers feed.
	// Bright enough to read as energy against a lit sky: a dark blue base with
	// modest emission just looks like painted trim.
	vec3 flow = mix(vec3(0.04, 0.24, 0.92), vec3(0.32, 0.66, 1.0), filament);
	ALBEDO = flow * 0.5;
	EMISSION = flow * (1.7 + filament * 3.1);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _create_tree_sap_flow_material() -> ShaderMaterial:
	# Bright energy packets travel inside a continuous darker cyan fiber. One
	# material from the smallest rootlet to the crown makes the circulation read
	# as a single biological system rather than unrelated glowing decorations.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
varying float sap_coordinate;
void vertex() {
	sap_coordinate = VERTEX.y + VERTEX.x * 0.18 + VERTEX.z * 0.22;
}
void fragment() {
	float packet = 0.5 + 0.5 * sin(sap_coordinate * 0.72 - TIME * 4.2);
	packet = smoothstep(0.54, 0.96, packet);
	vec3 base = vec3(0.015, 0.34, 0.48);
	vec3 pulse = vec3(0.24, 0.95, 1.0);
	vec3 colour = mix(base, pulse, packet);
	ALBEDO = colour;
	EMISSION = colour * mix(1.35, 3.2, packet);
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
	var minimum_clear_width := SIMPLE_TRUNK_DOOR_WIDTH_M * collision_scale \
		if bool(tree.get_meta("simple_trunk_core", false)) \
		else TREE_OF_LIFE_CLEAR_PATH_M * collision_scale
	collision_root.set_meta("minimum_clear_width_m", minimum_clear_width)
	collision_root.set_meta("collision_scale", collision_scale)
	tree.add_child(collision_root)

	if bool(tree.get_meta("simple_trunk_core", false)):
		_build_simple_trunk_collision(collision_root, collision_scale)
	else:
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


func _build_simple_trunk_collision(parent: Node3D, collision_scale: float) -> void:
	var root_radius := SIMPLE_TRUNK_ROOT_DIAMETER_M * collision_scale * 0.5
	var door_half_width := SIMPLE_TRUNK_DOOR_WIDTH_M * collision_scale * 0.5
	var door_height := SIMPLE_TRUNK_DOOR_HEIGHT_M * collision_scale
	var trunk_height := SIMPLE_TRUNK_HEIGHT_M * collision_scale
	var trunk_depth := SIMPLE_TRUNK_ROOT_DIAMETER_M * collision_scale
	var side_width := root_radius - door_half_width
	for side in [-1.0, 1.0]:
		_add_trunk_collision_box(parent,
			"SimpleTrunkDoorway%s" % ("Left" if side < 0.0 else "Right"),
			Vector3(side * (door_half_width + side_width * 0.5),
				door_height * 0.5, 0.0),
			Vector3(side_width, door_height, trunk_depth))
	_add_trunk_collision_box(parent, "SimpleTrunkDoorwayTop",
		Vector3(0.0, door_height + (trunk_height - door_height) * 0.5, 0.0),
		Vector3(root_radius * 2.0, trunk_height - door_height, trunk_depth))


func _add_trunk_collision_box(parent: Node3D, body_name: String,
		position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = position
	body.set_meta("tree_collision_role", "simple_trunk_shell")
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)


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
	label.no_depth_test = false
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
	label.no_depth_test = false
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


func _add_world_one_build_trigger(world_one: MindSparkWorldOne) -> void:
	## The world gate builds World One on travel, but the causeway is a second,
	## walkable way in. Without a trigger here a player who walks across it
	## arrives at empty space. This area covers the landing and builds the world
	## before they reach it.
	var trigger := Area3D.new()
	trigger.name = "MindSparkWorldOneBuildTrigger"
	trigger.position = MIND_WORLD_ONE_ORIGIN \
		+ world_one.get_zone_position("01_world_gate_landing")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	# Generous radius: building takes a moment, so it should start well before
	# the player can see that nothing is there.
	sphere.radius = 320.0
	shape.shape = sphere
	trigger.add_child(shape)
	trigger.body_entered.connect(func(body: Node3D) -> void:
		if body is CharacterBody3D:
			world_one.ensure_world_built())
	add_child(trigger)


func _exit_tree() -> void:
	for source in [_tree_christmas_melody, _tree_christmas_bells]:
		if is_instance_valid(source):
			source.stop()
			source.stream = null
