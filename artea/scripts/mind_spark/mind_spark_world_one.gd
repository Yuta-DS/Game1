class_name MindSparkWorldOne
extends Node3D

## The physical World One layer inside the Art Castle Galaxy. This scene owns
## geography, collision, architecture, placement and direct object use. Story,
## quest order and combat progression are deliberately separate controllers.

signal quest_object_used(save_id: String, result: Dictionary)
signal island_one_puzzle_solved(result: Dictionary)

const QuestObjectScene := preload("res://scenes/mind_spark/quest_objects/quest_object_base.tscn")
const QuestObjectCatalog := preload("res://scripts/mind_spark/quest_objects/quest_object_catalog.gd")
const QuestObjectDefinitionScript := preload("res://scripts/mind_spark/quest_objects/quest_object_definition.gd")
const EnemyScene := preload("res://scenes/mind_spark/combat/enemy_base.tscn")
const WardenScene := preload("res://scenes/mind_spark/combat/thought_storm_warden.tscn")
const SparkCollectibleScene := preload("res://scenes/mind_spark/quest_objects/thought_spark_collectible.tscn")
const MayorMiloScene := preload("res://scenes/mind_spark/cast/mayor_milo.tscn")
# Source of the crown station anchor reused by _bind_existing_station().
const HUB_SKYRAIL := preload("res://scripts/hub_skyrail.gd")
const MotherGuardianScene := preload("res://scenes/mind_spark/cast/guardian_angel.tscn")
const WorldGateScene := preload("res://scenes/mind_spark/world_gate.tscn")
const HeavenlyStarGateProductionScene := preload(
	"res://assets3D/mind_spark/heavenly_star_gate/glb/mind_spark_heavenly_star_gate.glb")
const PuzzleRegulatorProductionScene := preload(
	"res://assets3D/mind_spark/puzzle_control_kit/glb/mind_spark_puzzle_regulator.glb")
const PuzzleSelectorProductionScene := preload(
	"res://assets3D/mind_spark/puzzle_control_kit/glb/mind_spark_puzzle_selector.glb")
const PuzzleConfirmationProductionScene := preload(
	"res://assets3D/mind_spark/puzzle_control_kit/glb/mind_spark_puzzle_confirmation.glb")
const AetherAnalysisConsoleScene := preload(
	"res://assets3D/mind_spark/aether_analysis_console/glb/aether_analysis_console.glb")
# Procedural brick library: chamfered masonry, faceted crystals, bevelled
# boxes and drums. Used to give the props real cut geometry instead of raw
# BoxMesh/SphereMesh primitives.
const Bricks := preload("res://scripts/altar/AltarParts.gd")
const NetworkAmbience := preload("res://assets/audio/Atmospheric-instrumental-music.ogg")
const SanctuaryAmbience := preload("res://assets/audio/calm music.ogg")
const IslandDetailAnimator := preload("res://scripts/mind_spark/mind_spark_island_detail_animator.gd")
const IslandOnePuzzleScript := preload("res://scripts/mind_spark/mind_spark_island_one_puzzle.gd")
const ENEMY_DEFINITIONS := {
	"static_mite": preload("res://resources/mind_spark/enemies/static_mite.tres"),
	"glitch_sprout": preload("res://resources/mind_spark/enemies/glitch_sprout.tres"),
	"circuit_wisp": preload("res://resources/mind_spark/enemies/circuit_wisp.tres"),
	"root_stalker": preload("res://resources/mind_spark/enemies/root_stalker.tres"),
	"blight_sentinel": preload("res://resources/mind_spark/enemies/blight_sentinel.tres"),
}

const INTERACTION_RANGE := 18.0
const STATION_ISLAND_RADIUS := 72.0
## Empty space kept between the arena rim and the station island rim.
const STATION_SPUR_CLEARANCE := 40.0
## Thickness of the station island disc; its walking surface is half this up.
const STATION_ISLAND_HEIGHT := 6.0
## How far beyond the island rim the access flight lands, so the top step clears
## the rim face instead of ending buried inside the disc.
const STATION_STAIR_LANDING_INSET := 1.5
# A riser the production player controller can walk up without jumping.
const STATION_STAIR_MAX_RISER := 0.34
const STATION_STAIR_WIDTH := 18.0
const ZONE_FLOOR_HEIGHT := 4.0
const ZONE_FLOOR_CENTER_Y := -ZONE_FLOOR_HEIGHT * 0.5
const CIRCUIT_ROUTE_DECK_THICKNESS := 2.2
## Carry the route slightly over each island rim so the two collision surfaces
## overlap below the player's feet without sending the deck beneath the island.
const CIRCUIT_ROUTE_LANDING_OVERLAP := 1.5
## A level final run gives the capsule a floor-height bridge across the vertical
## island edge instead of asking it to climb that edge at the end of a slope.
const CIRCUIT_ROUTE_LANDING_LENGTH := 10.0
## Fast travel complements the six-island bridge ring without replacing it.
## Opposite islands are paired, reducing long return trips while keeping the
## physical story route readable. The portals unlock only after world restore.
const TRANSIT_PORTAL_PAIRS := [[0, 3], [1, 4], [2, 5]]
const TRANSIT_PORTAL_EDGE_INSET := 30.0
const TRANSIT_PORTAL_ARRIVAL_CLEARANCE := 18.0
static var GREYBOX_BUILD_SEQUENCE: PackedStringArray = [
	"three_fused_super_island_foundations",
	"main_story_route",
	"world_gate_checkpoints_boss_sanctuary",
	"optional_station_spur",
]
const ZONES := [
	# Six gameplay districts remain, but adjacent pairs now overlap and share a
	# continuous foundation. This preserves every quest anchor while presenting
	# the world as the approved three-island machine.
	{"id": "01_world_gate_landing", "title": "01 • WORLD GATE LANDING", "position": Vector3(-860, 2, 170), "radius": 125.0, "super_island": 1},
	{"id": "02_living_network_forest", "title": "02 • LIVING NETWORK FOREST", "position": Vector3(-670, 2, 85), "radius": 155.0, "super_island": 1},
	{"id": "03_constellation_court", "title": "03 • CONSTELLATION COURT", "position": Vector3(-215, 10, -80), "radius": 150.0, "super_island": 2},
	{"id": "04_hope_path_ridge", "title": "04 • HOPE PATH RIDGE", "position": Vector3(-15, 10, 15), "radius": 122.0, "super_island": 2},
	{"id": "05_thought_storm_arena", "title": "05 • THOUGHT STORM ARENA", "position": Vector3(430, 18, 25), "radius": 175.0, "super_island": 3},
	{"id": "06_oldest_tree_sanctuary", "title": "06 • OLDEST TREE SANCTUARY", "position": Vector3(655, 18, -75), "radius": 145.0, "super_island": 3},
]
const SUPER_ISLAND_PAIRS := [[0, 1], [2, 3], [4, 5]]
const ORGANIZED_TREE_LAYOUTS := [
	{"id": "01_world_gate_landing", "total": 10, "pattern": "paired ceremonial arrival rows"},
	{"id": "02_living_network_forest", "total": 30, "pattern": "two ordered living-network rings"},
	{"id": "03_constellation_court", "total": 14, "pattern": "fourteen-point constellation perimeter"},
	{"id": "04_hope_path_ridge", "total": 14, "pattern": "ascending hope-tree arc"},
	{"id": "05_thought_storm_arena", "total": 8, "pattern": "eight perimeter storm sentinels"},
	{"id": "06_oldest_tree_sanctuary", "total": 24, "pattern": "hero tree with twenty-three guardian trees"},
]
const NATIVE_ROUTE_POINTS := {
	"01_world_gate_landing": Vector3(-960, 2, 420),
	"02_living_network_forest": Vector3(-800, 12, 100),
	"03_constellation_court": Vector3(-300, 24, -220),
	"03_fear_gate": Vector3(-120, 30, -90),
	"03_proof_gate": Vector3(20, 35, 20),
	"04_hope_path_ridge": Vector3(170, 40, 120),
	"05_thought_storm_arena": Vector3(620, 58, 20),
	"06_oldest_tree_sanctuary": Vector3(940, 84, -420),
}
const DISTRICT_ROUTE_POINTS := {
	# Compact local coordinates on the authored cyan-grid Mind Spark island.
	# The controller itself is positioned at MIND (-600, 0, 1640).
	"01_world_gate_landing": Vector3(142, 2, 0),
	"02_living_network_forest": Vector3(82, 2, 72),
	"03_constellation_court": Vector3(0, 2, 18),
	"03_fear_gate": Vector3(-118, 2, 24),
	"03_proof_gate": Vector3(-40, 2, -118),
	"04_hope_path_ridge": Vector3(72, 2, -105),
	"05_thought_storm_arena": Vector3(-38, 2, 70),
	"06_oldest_tree_sanctuary": Vector3(118, 2, 45),
}

@export var build_hud := true
@export var object_state_store_path := "user://mind_spark_walkable_world_one_objects.json"
@export var force_standalone_blueprint := false
@export var return_destination_world_local := Vector3(-650, 7, 1575)

var _materials: Dictionary = {}
var _objects: Array[QuestObjectBase] = []
var _enemies: Array[MindSparkEnemyBase] = []
var _enemy_waves: Dictionary = {}
var _warden: Node
var _collectibles: Array[MindSparkCollectible] = []
var _quest_gates: Array[AnimatableBody3D] = []
var _cast: Dictionary = {}
var _world_state := "sleeping"
var _station_spur: Node3D
var _return_gate: MindSparkWorldGate
var _transit_portals: Array[MindSparkWorldGate] = []
var _zone_nodes: Dictionary = {}
var _player: CharacterBody3D
var _prompt: Label
var _status: Label
var _last_safe_position := Vector3(-960, 8, 420)
var _island_one_puzzle: MindSparkIslandOnePuzzle
var _island_one_star_gate_leaves: Array[AnimatableBody3D] = []
var _island_one_star_gate_tween: Tween


## When true, build_world() is not run on _ready and must be triggered by
## calling ensure_world_built(). World One is by far the heaviest construction
## in the game - measured at ~27,000 mesh nodes, 82% of every mesh in the art
## gallery scene - and building it up front is what pushed the gallery past the
## web export's memory ceiling. Deferring it until the player actually travels
## here keeps the gallery affordable in a browser.
@export var defer_world_build := false

var _world_built := false


func _ready() -> void:
	if not defer_world_build:
		ensure_world_built()
	_last_safe_position = to_global(get_zone_position("01_world_gate_landing") + Vector3(0, 7, 0))
	_find_player.call_deferred()
	if build_hud:
		_build_hud()


## Build the world if it has not been built yet. Safe to call repeatedly; the
## work happens once. get_zone_position() falls back to the authored ZONES
## table, so gates and routes can be positioned before this runs.
func ensure_world_built() -> void:
	if _world_built:
		return
	_world_built = true
	build_world()


func build_world() -> void:
	if has_node("WorldOneGeometry"):
		return
	_build_materials()
	var geometry := Node3D.new()
	geometry.name = "WorldOneGeometry"
	add_child(geometry)
	if _uses_existing_mind_district():
		_bind_district_route_anchors(geometry)
		_build_district_foundation_content(geometry)
		_build_district_progression_gates(geometry)
		_bind_existing_station(geometry)
	elif _uses_galaxy_foundation():
		_bind_galaxy_route_anchors(geometry)
		_build_galaxy_foundation_content(geometry)
		_build_native_progression_gates(geometry)
		_bind_existing_station(geometry)
	else:
		_build_six_zones(geometry)
		_build_three_fused_super_islands(geometry)
		_build_main_route(geometry)
		# The completed three-island route uses its authored gates and connected
		# walkways. Do not add the retired cyan pads or violet/cyan shortcut rings:
		# they are not a quest mechanic and visually conflict with the campus.
		_build_zone_landmarks()
		_build_progression_gates(geometry)
	_build_organized_bio_tree_world(geometry)
	if not _uses_existing_mind_district() and not _uses_galaxy_foundation():
		_repair_island_one_legacy_openings(geometry)
		_repair_island_one_legacy_openings(geometry, 4)
	_place_functional_objects()
	_place_collectibles()
	_place_cast()
	_place_combat_population()
	if not _uses_existing_mind_district() and not _uses_galaxy_foundation():
		load("res://scripts/mind_spark/island_one_research_campus.gd").apply(self)
		load("res://scripts/mind_spark/island_two_memory_campus.gd").apply(self)
		_finalize_quest_object_story_layout()
		_redesign_island_three(geometry)
	if not _uses_existing_mind_district() and not _uses_galaxy_foundation():
		# The optional station is deliberately the final standalone construction
		# phase. It branches from Zone 05 and never participates in story routing.
		_build_station_spur(geometry)
	_refine_island_one_surroundings()
	_install_island_one_static_collisions(geometry)
	_batch_static_geometry(self)
	set_meta("world_identity", "living computer forest")
	set_meta("lead_force", "technology_science")
	set_meta("zone_count", 6)
	set_meta("physical_island_count", 3)
	set_meta("districts_per_island", 2)
	set_meta("legacy_fusion_pairs", PackedStringArray(["01+02", "03+04", "05+06"]))
	set_meta("story_route_required", true)
	set_meta("greybox_build_sequence", GREYBOX_BUILD_SEQUENCE)
	var foundation_mode := "standalone_preview"
	if _uses_existing_mind_district():
		foundation_mode = "walkable_mind_district"
	elif _uses_galaxy_foundation():
		foundation_mode = "authored_galaxy_land"
	set_meta("foundation_mode", foundation_mode)
	set_world_state("sleeping")


func _refine_island_one_surroundings() -> void:
	# Clone only scenery overrides before batching. Shared world materials and
	# imported instruments must retain their own state/finish contracts.
	var finishes := {}
	for zone_id in ["01_world_gate_landing", "02_living_network_forest", "03_constellation_court", "04_hope_path_ridge"]:
		var zone := _zone_nodes.get(zone_id) as Node3D
		if zone != null:
			_refine_island_one_scenery_node(zone, finishes)
	for name in ["FusedSuperIsland_01_02", "FusedSuperIsland_03_04", "IslandOnePerimeterRepairs", "IslandOneResearchCampus"]:
		var assembly := find_child(name,true,false)
		if assembly != null:
			_refine_island_one_scenery_node(assembly,finishes)
	var lighting := {
		"HighHeavenlyArrivalLight": [0.95, 82.0],
		"HighPuzzleCompositionLight": [0.85, 52.0],
		"ElevatedTreeCrownLight": [1.15, 54.0],
	}
	for light_name in lighting:
		var light := find_child(light_name, true, false) as OmniLight3D
		if light != null:
			light.light_energy = lighting[light_name][0]
			light.omni_range = lighting[light_name][1]
			light.light_color = Color("ffe8c9")
	# Keep nearby operating instructions; suppress distant title clutter rather
	# than deleting labels or hiding the real evidence/question panels.
	if _island_one_puzzle != null:
		var profile := Node3D.new()
		profile.name = "IslandOneLightingProfile"
		profile.set_script(preload("res://scripts/mind_spark/island_one_lighting_profile.gd"))
		_island_one_puzzle.add_child(profile)
		for label in _island_one_puzzle.find_children("QuestPurposeLabel", "Label3D", true, false):
			label.visibility_range_end = 24.0
			label.visibility_range_end_margin = 4.0
	set_meta("island_one_environment_revision", "warm_scenery_01")


func _refine_island_one_scenery_node(node: Node, finishes: Dictionary) -> void:
	if node.name == "PuzzleControls":
		return
	if node is MeshInstance3D:
		var original := (node as MeshInstance3D).material_override as StandardMaterial3D
		if original != null:
			var key := original.get_instance_id()
			if not finishes.has(key):
				var finish := original.duplicate() as StandardMaterial3D
				# Architecture reflects light; only small energy accents emit it.
				finish.emission_energy_multiplier = minf(finish.emission_energy_multiplier, 0.24)
				if finish.metallic > 0.5:
					finish.roughness = maxf(finish.roughness, 0.48)
					finish.metallic_specular = minf(finish.metallic_specular, 0.55)
					finish.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				if original == _materials.gold:
					finish.albedo_color = Color("c5a366")
					finish.emission_enabled = false
				elif original == _materials.cyan:
					finish.albedo_color = Color("8fd6c8")
					finish.emission = Color("8fd6c8")
				finishes[key] = finish
			(node as MeshInstance3D).material_override = finishes[key]
		# Imported GLBs keep materials on surfaces, so the old override-only
		# pass never reached their highly reflective gold trim and paving inlays.
		var imported := node as MeshInstance3D
		if imported.mesh != null and imported.material_override == null:
			for surface in imported.mesh.get_surface_count():
				var source := imported.get_active_material(surface) as StandardMaterial3D
				if source == null or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					continue
				var key := source.get_instance_id()
				if not finishes.has(key):
					var finish := source.duplicate() as StandardMaterial3D
					finish.metallic = minf(source.metallic,.45)
					finish.roughness = maxf(source.roughness,.62)
					finish.metallic_specular = .0
					# Decorative gilding uses diffuse colour at tiny grazing angles;
					# native Mobile's specular path produced blue/black edge pixels.
					finish.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
					finishes[key] = finish
				imported.set_surface_override_material(surface,finishes[key])
	for child in node.get_children():
		_refine_island_one_scenery_node(child, finishes)


func _uses_galaxy_foundation() -> bool:
	return get_parent() != null and get_parent().name == "MindKingdom3000m"


func _uses_existing_mind_district() -> bool:
	return not force_standalone_blueprint and get_parent() != null \
		and get_parent().name == "ArtCastleFloatingWorld"


func _bind_district_route_anchors(parent: Node3D) -> void:
	var anchors := Node3D.new()
	anchors.name = "AuthoredMindDistrictRouteAnchors"
	parent.add_child(anchors)
	for route_id in DISTRICT_ROUTE_POINTS:
		var anchor := Node3D.new()
		anchor.name = str(route_id).to_pascal_case()
		anchor.position = DISTRICT_ROUTE_POINTS[route_id]
		anchor.set_meta("uses_existing_mind_district", true)
		anchors.add_child(anchor)
		_zone_nodes[route_id] = anchor


func _build_district_foundation_content(parent: Node3D) -> void:
	var content := Node3D.new()
	content.name = "ProductionContentOnWalkableMindDistrict"
	content.set_meta("architecture_source", "World One Mind Spark DOCX birdseye blueprint")
	content.set_meta("structural_system", "six static courts on authored floating-island deck")
	content.set_meta("static_mass_class", "infinite_static_mass")
	content.set_meta("design_gravity_m_s2", 9.8)
	content.set_meta("player_jump_height_m", 1.4)
	parent.add_child(content)
	# The user's island already supplies the grid, gates, tower forest, storm and
	# Oldest Tree. Add readable gameplay accents without covering that land.
	_build_district_engineered_courts(content)
	_build_district_story_route(content)
	_build_native_landing(_zone_nodes["01_world_gate_landing"])
	_build_district_network_accents(_zone_nodes["02_living_network_forest"])
	_build_district_constellation_accents(_zone_nodes["03_constellation_court"])
	_build_district_hope_accents(_zone_nodes["04_hope_path_ridge"])
	_build_district_storm_accents(_zone_nodes["05_thought_storm_arena"])
	_build_district_sanctuary_accents(_zone_nodes["06_oldest_tree_sanctuary"])
	_build_district_jump_course(_zone_nodes["04_hope_path_ridge"])
	_build_weighted_memory_props(_zone_nodes["03_constellation_court"])


func _build_district_engineered_courts(parent: Node3D) -> void:
	var courts := Node3D.new()
	courts.name = "SixEngineeredZoneCourts"
	parent.add_child(courts)
	var specs := [
		["01_world_gate_landing", "ArrivalCourt", 22.0, 12, _materials.floor_grid],
		["02_living_network_forest", "LivingNetworkCourt", 28.0, 8, _materials.floor_dark],
		["03_constellation_court", "ConstellationCourt", 25.0, 16, _materials.constellation_floor],
		["04_hope_path_ridge", "HopePathCourt", 24.0, 8, _materials.hope_floor],
		["05_thought_storm_arena", "StormArenaCourt", 31.0, 20, _materials.storm],
		["06_oldest_tree_sanctuary", "OldestTreeCourt", 25.0, 12, _materials.sanctuary_floor],
	]
	for index in specs.size():
		var spec: Array = specs[index]
		var center: Vector3 = DISTRICT_ROUTE_POINTS[spec[0]]
		# Existing rune tiles top out at y=1.9. A 0.32 m court raised only 0.16 m
		# above that surface is walkable by floor snapping and does not require a jump.
		center.y = 2.06
		_add_cylinder(courts, str(spec[1]), center, float(spec[2]), 0.32,
			spec[4] as Material, true, int(spec[3]), 0.94, 0.0)
		_add_torus(courts, "%sCircuitKerb" % spec[1], center + Vector3(0, 0.22, 0),
			float(spec[2]) - 1.8, float(spec[2]), _materials.cyan)
		var court_collision := courts.get_node("%sCollision" % spec[1]) as StaticBody3D
		court_collision.set_meta("zone_order", index + 1)
		court_collision.set_meta("load_class", "walkable_static_architecture")


func _build_district_story_route(parent: Node3D) -> void:
	# The production district compresses the blueprint's six floating islands
	# onto the player's existing cyan-grid foundation. Keep the same authored
	# land, but draw the one approved story route across it so the zones remain
	# legible from normal third-person height as well as from the minimap.
	var route := Node3D.new()
	route.name = "SixZoneStoryCircuitRoute"
	route.set_meta("uses_existing_mind_district", true)
	route.set_meta("story_route_required", true)
	parent.add_child(route)
	var route_ids := [
		"01_world_gate_landing",
		"02_living_network_forest",
		"03_constellation_court",
		"03_fear_gate",
		"03_proof_gate",
		"04_hope_path_ridge",
		"05_thought_storm_arena",
		"06_oldest_tree_sanctuary",
	]
	for segment_index in route_ids.size() - 1:
		var start: Vector3 = DISTRICT_ROUTE_POINTS[route_ids[segment_index]]
		var finish: Vector3 = DISTRICT_ROUTE_POINTS[route_ids[segment_index + 1]]
		_add_district_route_pips(route, start, finish, segment_index)
	var numbered_zones := [
		["01_world_gate_landing", "01 • ARRIVAL"],
		["02_living_network_forest", "02 • LIVING NETWORK"],
		["03_constellation_court", "03 • CONSTELLATION"],
		["04_hope_path_ridge", "04 • HOPE PATH"],
		["05_thought_storm_arena", "05 • STORM ARENA"],
		["06_oldest_tree_sanctuary", "06 • OLDEST TREE"],
	]
	for zone_data in numbered_zones:
		var zone_position: Vector3 = DISTRICT_ROUTE_POINTS[zone_data[0]]
		_add_torus(route, "%sRouteRing" % str(zone_data[0]).to_pascal_case(),
			zone_position + Vector3(0, 2.15, 0), 12.0, 14.0, _materials.cyan)
		_add_label(route, str(zone_data[1]), zone_position + Vector3(0, 15, 0),
			Color("d8fbff"), 23)


func _add_district_route_pips(parent: Node3D, start: Vector3, finish: Vector3,
		segment_index: int) -> void:
	var direction := finish - start
	var distance := direction.length()
	var count := maxi(1, int(distance / 13.0))
	var yaw := atan2(direction.x, direction.z)
	for pip_index in count + 1:
		var progress := float(pip_index) / float(count)
		var at := start.lerp(finish, progress)
		# Rune tiles top out at y=1.9, so the guide line must sit just above
		# them instead of disappearing inside the existing floor mesh.
		at.y = 2.08
		_add_box(parent, "StoryRoute_%02d_%02d" % [segment_index, pip_index], at,
			Vector3(5.5, 0.12, 1.25), _materials.gold if pip_index % 4 == 0 else _materials.cyan,
			false, yaw)


func _build_district_network_accents(zone: Node3D) -> void:
	zone.set_meta("legacy_random_server_trees_replaced", true)
	_add_zone_light(zone, Vector3(0, 22, 0), Color("45e4d1"), 48.0, 2.6)
	_add_zone_ambience(zone, "LivingNetworkAmbience", NetworkAmbience, -22.0, 260.0)


func _build_district_constellation_accents(zone: Node3D) -> void:
	for index in 8:
		var angle := TAU * float(index) / 8.0
		_add_sphere(zone, "MemorySignal_%02d" % index,
			Vector3(cos(angle) * 31, 7 + index % 3 * 4, sin(angle) * 31),
			Vector3.ONE * 1.8, _materials.violet if index % 2 else _materials.cyan)
	_add_torus(zone, "ConstellationFocusRing", Vector3(0, 8, 0), 27, 29, _materials.violet)
	_add_zone_light(zone, Vector3(0, 22, 0), Color("8e78ff"), 48.0, 2.5)


func _build_district_hope_accents(zone: Node3D) -> void:
	for index in 4:
		_add_box(zone, "HopeCircuit_%02d" % index, Vector3(-18 + index * 12, 0.8, 8),
			Vector3(10, 0.35, 18), _materials.gold if index % 2 == 0 else _materials.cyan)
	_add_zone_light(zone, Vector3(0, 18, 0), Color("ffd761"), 42.0, 2.3)


func _build_district_jump_course(zone: Node3D) -> void:
	var course := Node3D.new()
	course.name = "HopePathPhysicalTraversal"
	course.set_meta("maximum_obstacle_height_m", 1.2)
	course.set_meta("verified_player_jump_height_m", 1.4)
	course.set_meta("minimum_landing_depth_m", 3.8)
	zone.add_child(course)
	var heights := [0.40, 0.68, 0.92, 1.20]
	for index in heights.size():
		var height: float = heights[index]
		var at := Vector3(-18.0 + index * 12.0, height * 0.5 - 0.10, -15.0)
		_add_box(course, "JumpableDataBlock_%02d" % (index + 1), at,
			Vector3(5.0, height, 3.8), _materials.hope_floor, true, 0.0, 0.96, 0.02)
		var body := course.get_node("JumpableDataBlock_%02dCollision" % (index + 1)) as StaticBody3D
		body.set_meta("jumpable", true)
		body.set_meta("height_m", height)
	# The alternate side lane stays flat and 4 m wide, so jumping is expressive
	# rather than mandatory and accessibility never blocks story progress.
	_add_box(course, "AccessibleWalkLane", Vector3(0, 0.02, -21.0),
		Vector3(48.0, 0.14, 4.0), _materials.cyan, true, 0.0, 0.96, 0.0)


func _build_weighted_memory_props(zone: Node3D) -> void:
	var props := Node3D.new()
	props.name = "FiniteMassMemoryProps"
	props.set_meta("physics_purpose", "pushable optional spatial reasoning props")
	zone.add_child(props)
	for index in 3:
		var body := RigidBody3D.new()
		body.name = "WeightedMemoryOrb_%02d" % (index + 1)
		body.position = Vector3(-10.0 + index * 10.0, 1.25, -8.0)
		body.mass = 12.0 + index * 6.0
		body.gravity_scale = 1.0
		body.linear_damp = 0.38
		body.angular_damp = 0.52
		body.continuous_cd = true
		body.set_meta("mass_kg", body.mass)
		body.set_meta("gravity_m_s2", 9.8)
		var physics_material := PhysicsMaterial.new()
		physics_material.friction = 0.48
		physics_material.bounce = 0.12
		body.physics_material_override = physics_material
		var collision := CollisionShape3D.new()
		var sphere_shape := SphereShape3D.new()
		sphere_shape.radius = 1.25
		collision.shape = sphere_shape
		body.add_child(collision)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MemoryOrbMesh"
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 1.25
		sphere_mesh.height = 2.5
		sphere_mesh.radial_segments = 12
		sphere_mesh.rings = 6
		mesh_instance.mesh = sphere_mesh
		mesh_instance.material_override = _materials.constellation_floor if index % 2 == 0 else _materials.gold
		body.add_child(mesh_instance)
		props.add_child(body)


func _build_district_storm_accents(zone: Node3D) -> void:
	for index in 3:
		_add_torus(zone, "QuestStormRing_%02d" % index, Vector3(0, 18 + index * 9, 0),
			18 + index * 7, 20 + index * 7, _materials.violet)
	_add_zone_light(zone, Vector3(0, 30, 0), Color("9a64ff"), 62.0, 3.2)


func _build_district_sanctuary_accents(zone: Node3D) -> void:
	_build_bio_data_tree(zone, Vector3(0, 0, 0), 0.58, 6)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		_add_sphere(zone, "SanctuaryFirefly_%02d" % index,
			Vector3(cos(angle) * 22, 12 + index % 3 * 6, sin(angle) * 22),
			Vector3.ONE, _materials.gold)
	_add_cylinder(zone, "WisdomRewardPedestal", Vector3(-18, 2.5, -18), 7, 5,
		_materials.stone, true, 16)
	_add_star(zone, Vector3(-18, 12, -18), 4.5)
	_add_zone_light(zone, Vector3(0, 28, 0), Color("8dffc5"), 52.0, 2.8)
	_add_zone_ambience(zone, "SanctuaryCalmAmbience", SanctuaryAmbience, -21.0, 240.0)


func _bind_galaxy_route_anchors(parent: Node3D) -> void:
	var anchors := Node3D.new()
	anchors.name = "AuthoredGalaxyRouteAnchors"
	parent.add_child(anchors)
	for route_id in NATIVE_ROUTE_POINTS:
		var anchor := Node3D.new()
		anchor.name = str(route_id).to_pascal_case()
		anchor.position = NATIVE_ROUTE_POINTS[route_id]
		anchor.set_meta("uses_existing_story_court", true)
		anchors.add_child(anchor)
		_zone_nodes[route_id] = anchor


func _build_galaxy_foundation_content(parent: Node3D) -> void:
	var content := Node3D.new()
	content.name = "ProductionContentOnAuthoredLand"
	parent.add_child(content)
	_build_native_landing(_zone_nodes["01_world_gate_landing"])
	_build_native_network_forest(_zone_nodes["02_living_network_forest"])
	_build_native_constellation(_zone_nodes["03_constellation_court"])
	_build_native_evidence_gate(_zone_nodes["03_fear_gate"], "FACT / FEAR SCANNER", _materials.violet)
	_build_native_evidence_gate(_zone_nodes["03_proof_gate"], "LOGIC PROOF GATE", _materials.cyan)
	_build_native_hope_ridge(_zone_nodes["04_hope_path_ridge"])
	_build_native_storm_arena(_zone_nodes["05_thought_storm_arena"])
	_build_native_sanctuary(_zone_nodes["06_oldest_tree_sanctuary"])


func _build_native_landing(zone: Node3D) -> void:
	# The compact in-castle district reuses this landmark at roughly one-third
	# scale, while the authored galaxy land receives the full arrival station.
	# Keeping both variants in one assembly prevents the visual language from
	# drifting between the playable map and the six-island presentation.
	_build_celestial_world_gate_arrival(zone, 0.32 if _uses_existing_mind_district() else 1.0)
	_add_torus(zone, "LandingCircuitRing", Vector3(0, 1.2, 0), 34, 37, _materials.cyan)
	for side in [-1.0, 1.0]:
		for index in 4:
			var at := Vector3(float(side) * 28, 5, -36 + index * 24)
			_add_tapered_cylinder(zone, "LivingRootLamp", at, 0.62, 0.90, 10,
				_materials.celestial_floor, 12)
			_add_torus(zone, "RootLampGiltCollar", at + Vector3.UP * 5.0,
				0.72, 1.05, _materials.astral_brass)
			_add_sphere(zone, "RootLampCrown", at + Vector3.UP * 6,
				Vector3(1.25, 1.8, 1.25), _materials.arrival_glass)
	_add_label(zone, "WORLD ONE • MIND SPARK", Vector3(0, 28, 0), Color("c9fbff"), 36)
	_add_zone_light(zone, Vector3(0, 18, 0), Color("5cecff"), 26.0, 4.2)


func _build_native_network_forest(zone: Node3D) -> void:
	# The shared 100-tree authored layout owns this forest in every runtime mode.
	zone.set_meta("legacy_random_server_trees_replaced", true)
	for index in 12:
		var angle := TAU * float(index) / 12.0
		_add_nature_asset(zone, "NetworkRock_%02d" % index,
			"res://assets3D/stylizedNature/Rock_Medium_%d.gltf" % (index % 3 + 1),
			Vector3(cos(angle) * 150, 1.0, sin(angle) * 150), Vector3.ONE * (3.5 + index % 3))
	_add_zone_light(zone, Vector3(0, 46, 0), Color("45e4d1"), 110.0, 3.4)
	_add_zone_ambience(zone, "LivingNetworkAmbience", NetworkAmbience, -20.0, 520.0)


func _build_native_constellation(zone: Node3D) -> void:
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var node_position := Vector3(cos(angle) * (48 + index % 3 * 12), 10 + index % 4 * 7,
			sin(angle) * (48 + index % 3 * 12))
		_add_sphere(zone, "SavedMemoryStar_%02d" % index, node_position, Vector3.ONE * 2.8, _materials.cyan)
		if index % 2 == 0:
			_add_box(zone, "ConstellationBeam_%02d" % index, node_position * 0.5,
				Vector3(1.0, 0.65, node_position.length()), _materials.violet, false,
				atan2(node_position.x, node_position.z))
	_add_torus(zone, "MemoryHalo", Vector3(0, 18, 0), 42, 45, _materials.violet)
	_add_zone_light(zone, Vector3(0, 35, 0), Color("8e78ff"), 90.0, 3.8)


func _build_native_evidence_gate(zone: Node3D, title: String, accent: Material) -> void:
	for side in [-1.0, 1.0]:
		_add_box(zone, "EvidenceObelisk", Vector3(float(side) * 28, 15, 0),
			Vector3(8, 30, 8), _materials.floor_grid, true)
		_add_torus(zone, "EvidenceSignal", Vector3(float(side) * 28, 30, 0), 5, 7, accent,
			Vector3(90, 0, 0))
	_add_label(zone, title, Vector3(0, 38, 0), Color("e8fbff"), 31)
	_add_zone_light(zone, Vector3(0, 28, 0), Color("72eaff"), 70.0, 2.8)


func _build_native_hope_ridge(zone: Node3D) -> void:
	for index in 7:
		var at := Vector3(-72 + index * 24, 2.0 + sin(index * 0.8) * 2.0, -18 + index % 2 * 28)
		_add_box(zone, "TruthCircuitTile_%02d" % index, at, Vector3(19, 1.0, 38),
			_materials.gold if index % 2 == 0 else _materials.cyan)
		for petal in 3:
			_add_sphere(zone, "HopeBloom", at + Vector3(-6 + petal * 6, 3.0, 13),
				Vector3(1.7, 0.8, 1.7), _materials.green_glow)
	for index in 3:
		_add_torus(zone, "PerspectiveRing_%02d" % index, Vector3(-45 + index * 45, 20, 42),
			10, 13, _materials.gold if index == 2 else _materials.cyan, Vector3(90, 0, 0))
	_add_zone_light(zone, Vector3(0, 30, 0), Color("ffd761"), 90.0, 3.4)


func _build_native_storm_arena(zone: Node3D) -> void:
	for index in 6:
		_add_torus(zone, "AuthoredStormLayer_%02d" % index, Vector3(0, 28 + index * 12, 0),
			38 + index * 12, 42 + index * 12, _materials.violet)
	for index in 12:
		var angle := TAU * float(index) / 12.0
		_add_box(zone, "StormConductor_%02d" % index,
			Vector3(cos(angle) * 112, 18, sin(angle) * 112), Vector3(3, 36, 3), _materials.cyan)
	_add_label(zone, "THOUGHT STORM WARDEN", Vector3(0, 72, 0), Color("ffe4a0"), 38)
	_add_zone_light(zone, Vector3(0, 55, 0), Color("9a64ff"), 155.0, 4.5)


func _build_native_sanctuary(zone: Node3D) -> void:
	# The approved Bio-Data Tree replaces the former blocky root/trunk accents.
	_build_bio_data_tree(zone, Vector3(0, 0, 18), 1.0, 6)
	for index in 12:
		var angle := TAU * float(index) / 12.0
		_add_sphere(zone, "SanctuaryFirefly_%02d" % index,
			Vector3(cos(angle) * 58, 24 + index % 4 * 9, 18 + sin(angle) * 58),
			Vector3.ONE * 1.4, _materials.gold)
	_add_cylinder(zone, "WisdomRewardPedestal", Vector3(0, 4, -48), 16, 8, _materials.stone, true, 24)
	_add_star(zone, Vector3(0, 22, -48), 9.0)
	_build_arch(zone, Vector3(76, 0, 50), 40, 52, _materials.gold, "RETURN WORLD GATE")
	_return_gate = WorldGateScene.instantiate() as MindSparkWorldGate
	_return_gate.name = "ReturnToArtCastleWorldGate"
	_return_gate.position = Vector3(76, 1, 50)
	_return_gate.destination_world_local = return_destination_world_local
	_return_gate.prompt_text = "Q • RETURN TO ART CASTLE"
	_return_gate.gate_enabled = false
	zone.add_child(_return_gate)
	_add_zone_light(zone, Vector3(0, 58, 18), Color("8dffc5"), 145.0, 4.2)
	_add_zone_ambience(zone, "SanctuaryCalmAmbience", SanctuaryAmbience, -19.0, 460.0)


func _build_native_progression_gates(parent: Node3D) -> void:
	var gates := Node3D.new()
	gates.name = "SavedQuestProgressionGates"
	parent.add_child(gates)
	var placements := [
		[Vector3(490, 20, -870), Vector3(-1, 0, -0.2)],
		[Vector3(-420, 62, 250), Vector3(0.35, 0, 1)],
		[Vector3(-560, 80, 690), Vector3(-1, 0, 0.7)],
		[Vector3(-1030, 106, 680), Vector3(-1, 0, -0.8)],
	]
	for quest_index in placements.size():
		var gate := AnimatableBody3D.new()
		var at: Vector3 = placements[quest_index][0]
		var direction: Vector3 = placements[quest_index][1]
		gate.name = "QuestGate_%d" % (quest_index + 1)
		gate.position = at
		gate.rotation.y = atan2(direction.x, direction.z)
		gate.set_meta("closed_position", at)
		gate.set_meta("open", false)
		gates.add_child(gate)
		_add_box(gate, "Barrier", Vector3(0, 7, 0), Vector3(25, 14, 1.6), _materials.violet)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = Vector3(25, 14, 1.6)
		collision.shape = shape
		collision.position.y = 7
		gate.add_child(collision)
		_add_label(gate, "QUEST %d • SAVED PATH" % (quest_index + 1), Vector3(0, 18, 0), Color("dffcff"), 25)
		_quest_gates.append(gate)


func _build_district_progression_gates(parent: Node3D) -> void:
	var gates := Node3D.new()
	gates.name = "SavedQuestProgressionGates"
	parent.add_child(gates)
	var placements := [
		[Vector3(104, 2, 38), 0.7],
		[Vector3(-76, 2, -48), -0.55],
		[Vector3(18, 2, -103), 1.2],
		[Vector3(18, 2, 66), 0.0],
	]
	for quest_index in placements.size():
		var gate := AnimatableBody3D.new()
		var at: Vector3 = placements[quest_index][0]
		gate.name = "QuestGate_%d" % (quest_index + 1)
		gate.position = at
		gate.rotation.y = float(placements[quest_index][1])
		gate.set_meta("closed_position", at)
		gate.set_meta("open", false)
		gates.add_child(gate)
		_add_box(gate, "Barrier", Vector3(0, 4.5, 0), Vector3(12, 9, 0.7), _materials.violet)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = Vector3(12, 9, 0.7)
		collision.shape = shape
		collision.position.y = 4.5
		gate.add_child(collision)
		_quest_gates.append(gate)


## Quest save gates for the standalone greybox layout.
##
## Sits between story zones and stays closed until its quest is complete, so the
## SAVE RULE ("Save after each quest and before the boss") has a physical
## barrier to enforce. Mirrors _build_native_progression_gates, sized for the
## wider greybox spacing.
func _build_progression_gates(parent: Node3D) -> void:
	var gates := Node3D.new()
	gates.name = "SavedQuestProgressionGates"
	parent.add_child(gates)
	# Quest One uses both districts of Super-Island One, so its gate belongs on
	# 02>03, not 01>02. Every later gate follows the same rule: finish the
	# activities behind it, save, then unlock the next district. This avoids the
	# former circular dependency where a player could be blocked from the very
	# objects required to open the barrier.
	for quest_index in mini(4, ZONES.size() - 1):
		var route_start_index := quest_index + 1
		var from: Vector3 = ZONES[route_start_index].position
		var to: Vector3 = ZONES[route_start_index + 1].position
		var at := from.lerp(to, 0.5)
		var direction := to - from
		var gate := AnimatableBody3D.new()
		gate.name = "QuestGate_%d" % (quest_index + 1)
		gate.position = at
		gate.rotation.y = atan2(direction.x, direction.z)
		gate.set_meta("closed_position", at)
		gate.set_meta("open", false)
		gate.set_meta("gated_connection", "%s>%s" % [
			ZONES[route_start_index].id, ZONES[route_start_index + 1].id])
		gates.add_child(gate)
		var remove_bridge_barrier := quest_index == 0
		if not remove_bridge_barrier:
			_add_box(gate, "Barrier", Vector3(0, 7, 0), Vector3(25, 14, 1.6), _materials.violet)
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = Vector3(25, 14, 1.6)
		collision.shape = shape
		collision.position.y = 7
		collision.disabled = remove_bridge_barrier
		gate.add_child(collision)
		if remove_bridge_barrier:
			# Keep the saved quest-state slot stable after removing the physical
			# fixture at the former Island One bridge entrance.
			gate.set_meta("physical_barrier_removed", true)
		else:
			_add_label(gate, "QUEST %d SAVE GATE • LOCKED" % (quest_index + 1),
				Vector3(0, 17, 0), Color("ffd8f8"), 27)
		_quest_gates.append(gate)


## The optional completed-world station, built as the final greybox phase.
##
## Per the GREYBOX RULE the spur is added last and "must never block the story
## route", so it branches off Zone 05 rather than sitting on the path, and stays
## hidden with its collision disabled until the world is finished (see
## set_station_spur_available).
func _build_station_spur(parent: Node3D) -> void:
	_station_spur = Node3D.new()
	_station_spur.name = "OptionalCompletedWorldStationSpur"
	_station_spur.set_meta("optional_after_completion", true)
	_station_spur.set_meta("blocks_story_route", false)
	parent.add_child(_station_spur)

	# Branch sideways off the arena so the spur never overlaps the story route.
	# The island must clear the arena floor entirely: its own radius plus the
	# arena's, and then a margin so the two rims never visually touch. A fixed
	# offset silently overlapped once the arena radius grew to 210 m.
	var arena: Vector3 = ZONES[4].position
	var arena_radius: float = float(ZONES[4].radius)
	var spur_distance: float = arena_radius + STATION_ISLAND_RADIUS + STATION_SPUR_CLEARANCE
	var island_centre := arena + Vector3(0, 26, spur_distance)
	_station_spur.position = island_centre

	_add_cylinder(_station_spur, "StationIsland", Vector3.ZERO,
		STATION_ISLAND_RADIUS, STATION_ISLAND_HEIGHT, _materials.stone, true, 26)
	_add_cylinder(_station_spur, "StationPlatform", Vector3(0, 4.0, 0),
		STATION_ISLAND_RADIUS * 0.55, 2.4, _materials.floor_grid, true, 22)
	_add_label(_station_spur, "MIND SPARK STATION • OPTIONAL",
		Vector3(0, 22, 0), Color("bff8ff"), 34)
	_add_zone_light(_station_spur, Vector3(0, 16, 0), Color("5cecff"), 70.0, 2.6)

	# Stairs from the arena rim up to the spur, reusing the shared builder so
	# the risers stay inside the player's step height.
	#
	# The flight must finish AT the island rim, level with its walking surface.
	# Landing short of the rim (inside the 72 m disc) buries the last few metres
	# of the climb in the island body, and the player walks into that inner face
	# and stalls part way up instead of stepping out onto the platform.
	var island_top_y := STATION_ISLAND_HEIGHT * 0.5
	var stair_top := island_centre \
		+ Vector3(0, island_top_y, -(STATION_ISLAND_RADIUS + STATION_STAIR_LANDING_INSET))
	var stair_bottom := stair_top \
		+ Vector3(0, -(island_centre.y - arena.y) - island_top_y, -46.0)
	# Build the flight under the spur, not under the shared geometry root, so it
	# hides and unhides with the rest of the optional station. The endpoints are
	# world-local, so rebase them onto the spur's own origin.
	_build_station_access_stairs(_station_spur,
		stair_bottom - island_centre, stair_top - island_centre)

	# The minimap and the routing tests read these to draw and validate the spur.
	# They are world-local, matching ZONES[].position, because every consumer
	# offsets them by the MindSpark world's own position.
	_station_spur.set_meta("station_center", island_centre)
	_station_spur.set_meta("branch_start", stair_bottom)
	_station_spur.set_meta("station_island_radius", STATION_ISLAND_RADIUS)
	_station_spur.set_meta("branches_from_zone", str(ZONES[4].id))

	set_station_spur_available(false)


func _bind_existing_station(parent: Node3D) -> void:
	_station_spur = Node3D.new()
	_station_spur.name = "OptionalCompletedWorldStationSpur"
	_station_spur.set_meta("uses_existing_crown_station", true)
	_station_spur.set_meta("optional_after_completion", true)
	_station_spur.set_meta("blocks_story_route", false)
	parent.add_child(_station_spur)

	# This path reuses the skyrail's Grand Station instead of building a spur, so
	# the anchors come from that station rather than from local geometry.
	# GRAND_STATION_CENTER is hub-world space; the consumers offset these metas by
	# this world's own position, so store them world-local.
	var crown_center: Vector3 = HUB_SKYRAIL.GRAND_STATION_CENTER - position
	_station_spur.set_meta("station_center", crown_center)
	# The bound station has no separate access spur; the branch starts at the
	# final story zone, so the minimap draws the link from there.
	_station_spur.set_meta("branch_start", get_zone_position(str(ZONES[ZONES.size() - 1].id)))

	set_station_spur_available(false)


func get_zone_ids() -> PackedStringArray:
	var result := PackedStringArray()
	for zone in ZONES:
		result.append(str(zone.id))
	return result


func get_zone_position(zone_id: String) -> Vector3:
	if _zone_nodes.has(zone_id):
		return (_zone_nodes[zone_id] as Node3D).position
	for zone in ZONES:
		if str(zone.id) == zone_id:
			return zone.position
	return Vector3.ZERO


func get_zone_radius(zone_id: String) -> float:
	for zone in ZONES:
		if str(zone.id) == zone_id:
			return float(zone.radius)
	return 0.0


func get_quest_objects() -> Array[QuestObjectBase]:
	return _objects.duplicate()


func get_enemies() -> Array[MindSparkEnemyBase]:
	return _enemies.duplicate()


func get_warden() -> Node:
	return _warden


func get_collectibles() -> Array[MindSparkCollectible]:
	return _collectibles.duplicate()


func get_cast_member(member_id: String) -> Node3D:
	return _cast.get(member_id) as Node3D


func get_world_state() -> String:
	return _world_state


func set_world_state(next_state: String) -> void:
	if next_state not in ["sleeping", "waking", "gentle_rain"]:
		return
	_world_state = next_state
	var energy: float = {"sleeping": 0.28, "waking": 1.05, "gentle_rain": 1.45}[next_state]
	for key in ["cyan", "violet", "green_glow", "gold"]:
		var material := _materials.get(key) as StandardMaterial3D
		if material != null and material.emission_enabled:
			material.emission_energy_multiplier = energy
	_set_transit_enabled(next_state == "gentle_rain")
	set_meta("world_state", next_state)
	set_meta("transit_portals_enabled", next_state == "gentle_rain")
	_refresh_island_three_completion_visuals()


func get_transit_portals() -> Array[MindSparkWorldGate]:
	return _transit_portals.duplicate()


func _set_transit_enabled(enabled: bool) -> void:
	for portal in _transit_portals:
		if is_instance_valid(portal):
			portal.set_gate_enabled(enabled)


func set_station_spur_available(available: bool) -> void:
	if _station_spur == null:
		return
	_station_spur.visible = available
	_station_spur.set_meta("available", available)
	for body in _station_spur.find_children("*", "StaticBody3D", true, false):
		(body as StaticBody3D).collision_layer = 1 if available else 0


func set_return_gate_enabled(available: bool) -> void:
	if _return_gate != null:
		_return_gate.set_gate_enabled(available)


func set_support_target_position(target_local: Vector3, target_label: String) -> void:
	var target_global := to_global(target_local)
	for kind in [
		QuestObjectDefinitionScript.ObjectKind.FOCUS_BELL_BEACON,
		QuestObjectDefinitionScript.ObjectKind.CLEAR_PATH_PROJECTOR,
	]:
		var support := get_object_by_kind(kind)
		if support == null:
			continue
		support.set_meta("current_required_target", target_label)
		support.set_meta("current_required_position", target_local)
		if support.status != null:
			support.status.text = "TARGET • %s" % target_label.to_upper()
		var flat_target := Vector3(target_global.x, support.global_position.y, target_global.z)
		if support.global_position.distance_squared_to(flat_target) > 1.0:
			support.look_at(flat_target, Vector3.UP, true)


func set_quest_gate_open(quest_index: int, open: bool) -> void:
	if quest_index < 0 or quest_index >= _quest_gates.size():
		return
	var gate := _quest_gates[quest_index]
	if str(gate.get_meta("custom_gate_motion", "")) == "island_two_memory_hinges":
		var motion := gate.get_node_or_null("IslandTwoMemoryGate/SafeMemoryGateMotion")
		if motion != null:
			# Physical leaves now guard the opening throughout movement. The old
			# central slab must not intersect their sampled sweep.
			gate.get_node("CollisionShape3D").set_deferred("disabled", true)
			motion.call("request", open, true)
			gate.set_meta("open", open)
			return
		var west_leaf := gate.get_node_or_null("IslandTwoMemoryGate/WestMemoryLeaf") as Node3D
		var east_leaf := gate.get_node_or_null("IslandTwoMemoryGate/EastMemoryLeaf") as Node3D
		if west_leaf != null:
			west_leaf.rotation.y = -PI * 0.5 if open else 0.0
		if east_leaf != null:
			east_leaf.rotation.y = PI * 0.5 if open else 0.0
		gate.get_node("CollisionShape3D").disabled = open
		gate.set_meta("open", open)
		return
	var closed_position: Vector3 = gate.get_meta("closed_position")
	gate.position = closed_position + (Vector3.UP * 22.0 if open else Vector3.ZERO)
	gate.get_node("CollisionShape3D").disabled = open
	gate.set_meta("open", open)


func is_quest_gate_open(quest_index: int) -> bool:
	return quest_index >= 0 and quest_index < _quest_gates.size() and bool(_quest_gates[quest_index].get_meta("open", false))


func set_island_two_story_state(state: String) -> void:
	var valid_states := ["dormant", "invited", "received", "evidence_sorted",
		"memory_woven", "archive_open", "hope_reframed", "truth_materialised",
		"guardian_freed"]
	if state not in valid_states:
		return
	set_meta("island_two_story_state", state)
	var receiver := get_node_or_null("IslandTwoMemoryCampus/EchoSeedArrivalReceiver") as Node3D
	if receiver == null:
		return
	var dormant := receiver.get_node_or_null("DormantHalo") as MeshInstance3D
	var invited := receiver.get_node_or_null("InvitedHalo") as MeshInstance3D
	var seed := receiver.get_node_or_null("ReceivedEchoSeed") as MeshInstance3D
	if dormant != null:
		dormant.visible = state == "dormant"
	if invited != null:
		invited.visible = state != "dormant"
	if seed != null:
		seed.visible = state not in ["dormant", "invited"]
	var label := receiver.get_node_or_null("ReceiverStateLabel") as Label3D
	if label != null:
		var receiver_text: String = {
			"dormant": "DORMANT", "invited": "AWAITING ECHO SEED",
			"received": "THREE FRAGMENTS RECEIVED",
			"evidence_sorted": "EVIDENCE PLATES VERIFIED",
			"memory_woven": "FAIR MEMORY WOVEN", "archive_open": "ARCHIVE ROUTE OPEN",
			"hope_reframed": "THREE VIEWPOINTS ALIGNED",
			"truth_materialised": "GROUNDED HOPE FORMED",
			"guardian_freed": "UNDERSTANDING RESTORED",
		}.get(state, "DORMANT")
		label.text = "ECHO SEED RECEIVER • %s" % receiver_text
	var state_order := valid_states.find(state)
	var evidence_bus := get_node_or_null("IslandTwoMemoryCampus/EvidenceAetherBus") as Node3D
	if evidence_bus != null:
		var active_readings: int = {"received": 1, "evidence_sorted": 3,
			"memory_woven": 5, "archive_open": 7, "hope_reframed": 7,
			"truth_materialised": 7, "guardian_freed": 7}.get(state, 0)
		for index in 7:
			var reading := evidence_bus.get_node_or_null("ArchiveBusReading_%02d" % (index + 1)) as Node3D
			if reading != null:
				reading.scale = Vector3.ONE if index < active_readings else Vector3.ONE * 0.32
	var hope_conduit := get_node_or_null("IslandTwoMemoryCampus/HopeMaterialisationConduit") as Node3D
	if hope_conduit != null:
		var active_segments := 0
		if state_order >= valid_states.find("hope_reframed"):
			active_segments = 3
		if state_order >= valid_states.find("truth_materialised"):
			active_segments = 5
		for index in 5:
			var segment := hope_conduit.get_node_or_null("HopeSignalSegment_%02d" % (index + 1)) as Node3D
			if segment != null:
				segment.visible = index < active_segments
	var reward := get_node_or_null("IslandTwoMemoryCampus/EliteGuardianCourt/GuardianRewardSocket/RewardHopeCrystal") as Node3D
	if reward != null:
		reward.visible = state == "guardian_freed"


func activate_enemy_wave(encounter_id: String) -> int:
	for enemy in _enemies:
		enemy.set_active(false)
	var wave: Array = _enemy_waves.get(encounter_id, [])
	for index in mini(4, wave.size()):
		(wave[index] as MindSparkEnemyBase).set_active(true)
	return mini(4, wave.size())


func active_enemy_count() -> int:
	var count := 0
	for enemy in _enemies:
		if enemy.active and enemy.state != MindSparkEnemyBase.State.DEFEATED:
			count += 1
	return count


func get_object_by_kind(kind: int) -> QuestObjectBase:
	for object in _objects:
		if object.definition != null and object.definition.object_kind == kind:
			return object
	return null


func interact_object_for_test(kind: int, action: StringName = &"primary", value: Variant = null) -> Dictionary:
	var object := get_object_by_kind(kind)
	return object.interact(action, value) if object != null else {"accepted": false, "reason": "missing_object"}


func _process(_delta: float) -> void:
	if _player == null:
		return
	var nearest_zone := _nearest_zone()
	if not nearest_zone.is_empty():
		_last_safe_position = to_global(nearest_zone.position + Vector3(0, 7, 0))
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	var quest_controller := get_node_or_null("QuestController")
	if quest_controller != null and quest_controller.has_method("has_open_identity_reflection") \
			and bool(quest_controller.call("has_open_identity_reflection")):
		return
	if event.keycode == KEY_Q and _island_one_puzzle != null \
			and _island_one_puzzle.nearest_control(_player) != null:
		if not has_node("QuestStationPanel"):
			var panel := preload("res://scripts/mind_spark/quest_station_panel.gd").new()
			panel.name = "QuestStationPanel"
			add_child(panel)
			panel.open(_island_one_puzzle,_player,str(_island_one_puzzle.nearest_control(_player).get_meta("control_id")))
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		return
	var object := _nearest_object()
	if object == null:
		return
	if event.keycode == KEY_Q and not has_node("QuestStationPanel"):
		var panel := preload("res://scripts/mind_spark/world_one_object_minigame_panel.gd").new()
		panel.name = "QuestStationPanel"
		add_child(panel)
		panel.open_object(object, _player)
		get_viewport().set_input_as_handled()
		return


func _handle_object_result(object: QuestObjectBase, result: Dictionary) -> void:
	quest_object_used.emit(object.save_id, result)
	if _status != null:
		_status.text = "%s • %s" % [object.definition.display_name.to_upper(),
			str(result.get("reason", "ready")).replace("_", " ").to_upper()]


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if not players.is_empty():
		_player = players[0] as CharacterBody3D
	if _player == null:
		_player = get_node_or_null("../../../Player3D") as CharacterBody3D


func _nearest_object() -> QuestObjectBase:
	if _player == null:
		return null
	var best: QuestObjectBase
	var best_distance := INTERACTION_RANGE
	for object in _objects:
		if not is_instance_valid(object):
			continue
		var distance := _player.global_position.distance_to(object.global_position)
		if distance < best_distance:
			best = object
			best_distance = distance
	return best


func _nearest_zone() -> Dictionary:
	if _player == null:
		return {}
	var local_player := to_local(_player.global_position)
	var best: Dictionary = {}
	var distance := INF
	for zone in ZONES:
		var zone_position := get_zone_position(str(zone.id))
		var current := Vector2(local_player.x, local_player.z).distance_to(Vector2(zone_position.x, zone_position.z))
		var active_radius := 62.0 if _uses_existing_mind_district() else float(zone.radius)
		if current < active_radius and current < distance:
			best = zone.duplicate()
			best.position = zone_position
			distance = current
	return best


func _build_six_zones(parent: Node3D) -> void:
	parent.set_meta("phase_01", "three_fused_super_island_foundations")
	for index in ZONES.size():
		var info: Dictionary = ZONES[index]
		var zone := Node3D.new()
		zone.name = str(info.id).to_pascal_case()
		zone.position = info.position
		zone.set_meta("zone_id", info.id)
		zone.set_meta("route_order", index + 1)
		parent.add_child(zone)
		_zone_nodes[info.id] = zone
		var floor_shell := _add_cylinder(zone, "WalkableZoneFloor", Vector3(0, ZONE_FLOOR_CENTER_Y, 0),
			float(info.radius), ZONE_FLOOR_HEIGHT,
			_materials.celestial_floor, true, 48)
		# The imported paving owns the visible top. Drawing the old cylinder cap
		# through its bevels produces triangular overlap patches at game scale.
		# This affects only the visual mesh, never the cylinder collision shape.
		(floor_shell.mesh as CylinderMesh).cap_top = false
		_build_modular_floating_foundation(zone, info, index)
		_add_label(zone, str(info.title), Vector3(0, 34, 0), Color("bff8ff"), 42)
		_build_recovery_volume(zone, float(info.radius))
	# Standalone preview collapses the two additional evidence courts into the
	# constellation platform. The live Galaxy integration binds them separately.
	_zone_nodes["03_fear_gate"] = _zone_nodes["03_constellation_court"]
	_zone_nodes["03_proof_gate"] = _zone_nodes["03_constellation_court"]


func _build_three_fused_super_islands(parent: Node3D) -> void:
	## Converts the six retained gameplay courts into three physical islands.
	## Each pair keeps its own landmark and local puzzle space, but the broad
	## saddle, continuous collision deck and shared engine hull make it one
	## believable load-bearing landmass rather than two discs touching in space.
	var fusions := Node3D.new()
	fusions.name = "ThreeFusedSuperIslands"
	fusions.set_meta("physical_island_count", 3)
	fusions.set_meta("district_count", 6)
	fusions.set_meta("external_bridge_count", 2)
	fusions.set_meta("fusion_rule", "two legacy districts share one deck, engine hall and rock keel")
	parent.add_child(fusions)
	for pair_index in SUPER_ISLAND_PAIRS.size():
		var pair: Array = SUPER_ISLAND_PAIRS[pair_index]
		var first: Dictionary = ZONES[int(pair[0])]
		var second: Dictionary = ZONES[int(pair[1])]
		_build_super_island_fusion(fusions, pair_index, first, second)


func _build_super_island_fusion(parent: Node3D, pair_index: int,
		first: Dictionary, second: Dictionary) -> void:
	var fusion := Node3D.new()
	fusion.name = "FusedSuperIsland_%02d_%02d" % [pair_index * 2 + 1, pair_index * 2 + 2]
	fusion.set_meta("super_island_index", pair_index + 1)
	fusion.set_meta("legacy_zone_ids", PackedStringArray([str(first.id), str(second.id)]))
	fusion.set_meta("continuous_foundation", true)
	fusion.set_meta("shared_power_source", true)
	fusion.set_meta("internal_promenade_link", "%s>%s" % [first.id, second.id])
	fusion.set_meta("blender_module_language", "bevelled wedges, cylinders, torus gears, curve pipes and faceted triangular keels")
	parent.add_child(fusion)

	var start: Vector3 = first.position
	var finish: Vector3 = second.position
	var flat_direction := Vector3(finish.x - start.x, 0.0, finish.z - start.z).normalized()
	var distance := Vector2(finish.x - start.x, finish.z - start.z).length()
	var yaw := atan2(flat_direction.x, flat_direction.z)
	var center := start.lerp(finish, 0.5)
	var shared_surface_y := minf(_zone_floor_surface_y(start), _zone_floor_surface_y(finish))
	var saddle_length := distance * 0.72
	var saddle_width: float = [82.0, 76.0, 92.0][pair_index]

	# Island One keeps the already-authored Sun Gate and Verdant foundations.
	# The 3,000-part Blender study is used only as an additive upper-architecture
	# reference layer: conservatory framing, glass, garden dressing, railings and
	# wayfinding. Its replacement deck, keel and underside engines are hidden so
	# this pass never replaces or doubles the existing island foundation.
	if pair_index == 0:
		var island_scene := load(
			"res://assets3D/mind_spark/super_island_one_3000/super_island_one.glb"
		) as PackedScene
		var island_visual := island_scene.instantiate() as Node3D
		island_visual.name = "BlenderAuthoredIslandOneTopOverlay"
		island_visual.position = Vector3(center.x, shared_surface_y, center.z)
		island_visual.set_meta("editable_source_parts", 3000)
		island_visual.set_meta("runtime_batches", 9)
		island_visual.set_meta("visible_overlay_batches", 1)
		island_visual.set_meta("application_mode", "additive_above_ground_only")
		island_visual.set_meta("existing_foundation_preserved", true)
		island_visual.set_meta("legacy_districts", PackedStringArray([
			"01_world_gate_landing", "02_living_network_forest"
		]))
		island_visual.set_meta("mini_game_support", PackedStringArray([
			"aether_compass", "checkpoint_roots", "thought_sparks", "spark_socket"
		]))
		fusion.add_child(island_visual)
		# The imported Glass batch contains broad vertical panes across the player
		# route. At runtime they wash out consoles and the star-gate reveal; the
		# detailed brass/ivory conservatory ribs retain the glasshouse silhouette.
		# The broad Architecture batch duplicates this runtime scene's authored
		# conservatory and placed a fence-like wall through the Thought Sanctum.
		# Keep only the segmented puzzle architecture. The separate live Quest One
		# controls own interaction; the imported Gameplay overlay is decoration
		# only and contains the unwanted raised green line, solid rings and gold
		# floor tracks.
		var visible_roles := PackedStringArray([
			"GameplayArchitecture"
		])
		for mesh in island_visual.find_children("MSI1_Runtime_*", "MeshInstance3D", true, false):
			var role := str((mesh as MeshInstance3D).get_meta("runtime_role", ""))
			if role.is_empty():
				role = str((mesh as MeshInstance3D).name).trim_prefix("MSI1_Runtime_")
			(mesh as MeshInstance3D).visible = role in visible_roles
			(mesh as MeshInstance3D).set_meta("additive_overlay_visible", role in visible_roles)
			if role == "Nature":
				# Replace the entire old tree/loose-planter layer, not the teaching
				# tree or any of the puzzle's state-driven geometry.
				mesh.visible = false
				mesh.set_meta("preserve_authored_nodes", true)
				mesh.set_meta("additive_overlay_visible", false)
		var garden_scene := preload("res://assets3D/mind_spark/echo_garden_benchmark/export/echo_garden.glb")
		var garden := garden_scene.instantiate() as Node3D
		garden.name = "EchoGardenHeroBenchmark"
		# Original Blender crown garden origin: (95, 42.5, 0), Z-up.
		garden.position = Vector3(95, 0, -42.5)
		garden.set_meta("preserve_authored_nodes", true)
		garden.set_meta("replaces_role", "Nature")
		island_visual.add_child(garden)
		# The benchmark batches every visible trunk into one WarmBark mesh. Give
		# that exact static mesh collision so the white garden trees beside the
		# former bridge entrance are solid at player height.
		var garden_trunks := garden.find_child("WarmBark", true, false) as MeshInstance3D
		if garden_trunks != null and garden_trunks.mesh != null:
			var trunk_body := StaticBody3D.new()
			trunk_body.name = "WarmBarkCollision"
			trunk_body.collision_layer = 1
			trunk_body.collision_mask = 1
			trunk_body.set_meta("collision_role", "island_one_echo_garden_tree_trunks")
			var trunk_shape := CollisionShape3D.new()
			trunk_shape.name = "CollisionShape3D"
			trunk_shape.shape = garden_trunks.mesh.create_trimesh_shape()
			trunk_body.add_child(trunk_shape)
			garden_trunks.add_child(trunk_body)
			garden.set_meta("solid_tree_trunk_mesh", "WarmBark")

		# The visible saddle lives in the GLB. This collision-only bridge closes
		# the seam between the two retained circular gameplay floor colliders.
		var saddle_body := StaticBody3D.new()
		saddle_body.name = "SharedIvorySaddleCollision"
		saddle_body.position = Vector3(center.x, shared_surface_y - 1.4, center.z)
		saddle_body.rotation.y = yaw
		var saddle_shape := CollisionShape3D.new()
		var saddle_box := BoxShape3D.new()
		saddle_box.size = Vector3(saddle_width, 2.8, saddle_length)
		saddle_shape.shape = saddle_box
		saddle_body.add_child(saddle_shape)
		fusion.add_child(saddle_body)
		fusion.set_meta("gameplay_purpose",
			"arrival guidance and living-root power exchange")
		fusion.set_meta("foundation_machine_parts", 0)
		fusion.set_meta("exact_editable_part_count", 3000)
		fusion.set_meta("runtime_render_batch_count", 9)
		fusion.set_meta("visible_overlay_batch_count", 4)
		fusion.set_meta("existing_foundations_preserved", true)
		return

	# A wide collision-backed civic saddle seals the overlap between the two old
	# decks. Its restrained inlays leave the clear player route visually obvious.
	_add_box(fusion, "SharedIvorySaddle", Vector3(center.x,
		shared_surface_y - 1.4, center.z), Vector3(saddle_width, 2.8, saddle_length),
		_materials.celestial_floor, true, yaw)
	_add_box(fusion, "InternalPromenadeInlay", Vector3(center.x,
		shared_surface_y + 0.10, center.z), Vector3(10.0, 0.20, saddle_length - 12.0),
		_materials.astral_brass, false, yaw)
	_add_box(fusion, "AetherFlowChannel", Vector3(center.x,
		shared_surface_y + 0.23, center.z), Vector3(2.2, 0.16, saddle_length - 18.0),
		_materials.arrival_glass, false, yaw)

	# Mirrored safety rails and lamp pylons make the fused waist fully walkable.
	var side_axis := Vector3(cos(yaw), 0.0, -sin(yaw))
	for side in [-1.0, 1.0]:
		var side_name := "Left" if side < 0 else "Right"
		var rail_at: Vector3 = center + side_axis * float(side) * (saddle_width * 0.5 - 1.4)
		rail_at.y = shared_surface_y + 1.8
		_add_box(fusion, "%sPromenadeRail" % side_name, rail_at,
			Vector3(1.1, 2.6, saddle_length), _materials.astral_brass, true, yaw)
		for lamp_index in 4:
			var along := lerpf(-saddle_length * 0.38, saddle_length * 0.38,
				float(lamp_index) / 3.0)
			var lamp_at: Vector3 = center + flat_direction * along \
				+ side_axis * float(side) * (saddle_width * 0.5 - 4.2)
			lamp_at.y = shared_surface_y + 4.5
			_add_tapered_cylinder(fusion, "%sPromenadeLamp_%02d" % [side_name, lamp_index + 1],
				lamp_at, 0.55, 0.82, 8.0, _materials.celestial_floor, 12)
			_add_sphere(fusion, "%sPromenadeGlow_%02d" % [side_name, lamp_index + 1],
				lamp_at + Vector3.UP * 5.0, Vector3(1.15, 1.55, 1.15), _materials.arrival_glass)

	# The shared engine hall hangs under both districts. Large components are
	# readable from the exterior and have an explicit foundation/power purpose.
	var service_y := shared_surface_y - 17.0
	_add_box(fusion, "SharedEngineHallBackplate", Vector3(center.x, service_y, center.z),
		Vector3(saddle_width * 0.82, 24.0, saddle_length * 0.78),
		_materials.island_underside, false, yaw)
	for engine_index in 4:
		var along := lerpf(-saddle_length * 0.27, saddle_length * 0.27,
			float(engine_index) / 3.0)
		var side := -1.0 if engine_index % 2 == 0 else 1.0
		var tank_at: Vector3 = center + flat_direction * along + side_axis * side * saddle_width * 0.23
		tank_at.y = service_y
		_add_cylinder(fusion, "FoundationPressureTank_%02d" % (engine_index + 1), tank_at,
			5.2 + pair_index, 19.0, _materials.astral_glass if engine_index % 2 == 0 else _materials.astral_brass,
			false, 20)
		_add_torus(fusion, "PressureTankCollar_%02d" % (engine_index + 1),
			tank_at + Vector3.UP * 5.2, 4.8 + pair_index, 6.2 + pair_index,
			_materials.astral_brass)
		_add_torus(fusion, "PressureTankFoot_%02d" % (engine_index + 1),
			tank_at - Vector3.UP * 5.2, 4.8 + pair_index, 6.2 + pair_index,
			_materials.astral_brass)

	for gear_index in 2:
		var gear_at := center + flat_direction * (-saddle_length * 0.18 + gear_index * saddle_length * 0.36)
		gear_at.y = service_y - 1.0
		_add_torus(fusion, "FoundationFlywheel_%02d" % (gear_index + 1), gear_at,
			10.0 + pair_index * 2.0, 13.0 + pair_index * 2.0, _materials.astral_brass,
			Vector3(90, rad_to_deg(yaw), 0))
		_add_cylinder(fusion, "FoundationFlywheelHub_%02d" % (gear_index + 1), gear_at,
			3.2, 5.0, _materials.island_cyan, false, 16)

	# Triangulated keel ribs visually carry both old rock masses into one central
	# spine. These are individual, editable beams rather than a solid blob.
	var keel_tip := Vector3(center.x, shared_surface_y - 62.0 - pair_index * 8.0, center.z)
	for rib_index in 12:
		var phase := float(rib_index) / 11.0
		var along := lerpf(-saddle_length * 0.42, saddle_length * 0.42, phase)
		var crown := center + flat_direction * along
		crown.y = shared_surface_y - 4.0
		var tip := keel_tip + side_axis * sin(phase * PI * 3.0) * (8.0 + pair_index * 2.0)
		_add_cable_between(fusion, "TriangulatedKeelRib_%02d" % (rib_index + 1),
			crown, tip, 2.3, 0.8, _materials.island_underside, 6)
		if rib_index < 11:
			var next_phase := float(rib_index + 1) / 11.0
			var next_crown := center + flat_direction * lerpf(-saddle_length * 0.42,
				saddle_length * 0.42, next_phase)
			next_crown.y = shared_surface_y - 4.0
			_add_cable_between(fusion, "KeelCrossBrace_%02d" % (rib_index + 1),
				crown, next_crown.lerp(keel_tip, 0.55), 1.25, 0.65,
				_materials.astral_brass, 6)

	# Large supply lines explain how the paired districts share lift and power.
	for pipe_index in 3:
		var offset := side_axis * (float(pipe_index) - 1.0) * 9.0
		_add_cable_between(fusion, "SharedLiftMain_%02d" % (pipe_index + 1),
			start.lerp(center, 0.55) + offset + Vector3.DOWN * 10.0,
			finish.lerp(center, 0.55) + offset + Vector3.DOWN * 10.0,
			1.5, 1.5, _materials.astral_brass if pipe_index != 1 else _materials.island_cyan, 12)

	var purposes := [
		"arrival guidance and living-root power exchange",
		"astral interpretation and hope-path transformation",
		"storm regulation and wisdom sanctuary restoration",
	]
	fusion.set_meta("gameplay_purpose", purposes[pair_index])
	fusion.set_meta("foundation_machine_parts", 96)


func _build_modular_floating_foundation(zone: Node3D, info: Dictionary, zone_index: int) -> void:
	# Selected v07 reference: recessed enginehouses and ornate ivory/brass rails.
	# v11 retains six rock profiles and shared paving, with route-sized openings.
	# Island two uses v12 gardens; island three uses v16; island four uses the
	# winged Dawn v17 revision. Walking discs and authored routes stay put.
	var variant_names := ["Sun Gate", "Verdant Engine Gardens", "Astral Observatory",
		"Dawn Viaduct", "Stormworks Bastion", "Crownroot Sanctuary"]
	var foundation := Node3D.new()
	foundation.name = "ModularFloatingFoundation"
	foundation.scale = Vector3.ONE * float(info.radius)
	foundation.position.y = 0.01
	foundation.set_meta("assembly_style", "reference ivory arches, recessed steam enginehouses and brass balustrades")
	foundation.set_meta("source_revision", "v17" if zone_index == 3 else ("v16" if zone_index == 2 else ("v12" if zone_index == 1 else "v11")))
	if zone_index == 1:
		foundation.set_meta("silhouette", "split asymmetric hanging-garden keels")
		foundation.set_meta("scenic_terraces", 4)
	elif zone_index == 2:
		foundation.set_meta("silhouette", "astral crown citadel with crystalline needle keel")
		foundation.set_meta("observation_turrets", 2)
		foundation.set_meta("lateral_flywheel_engines", 2)
		foundation.set_meta("rear_condenser_vessels", 2)
		foundation.set_meta("lower_service_gallery", true)
		foundation.set_meta("enclosed_side_bays", 2)
		foundation.set_meta("ground_barrier_completion", true)
		foundation.set_meta("player_scale_barrier", true)
		foundation.set_meta("outboard_turret_clearance", 1.03)
	elif zone_index == 3:
		foundation.set_meta("silhouette", "celestial oval engine arcades with split keels")
		foundation.set_meta("player_scale_barrier", true)
		foundation.set_meta("winged_load_ribs", 14)
		foundation.set_meta("moving_gear_assemblies", 4)
	foundation.set_meta("style_reference_revision", "v07")
	foundation.set_meta("reference_enginehouses", 2)
	foundation.set_meta("reference_arch_bays", 4)
	foundation.set_meta("machinery_simulation", "paired kinematic 20:12 lift gears" if zone_index == 3 else ("kinematic piston and geared generator" if zone_index == 2 else "static fictional steam machinery"))
	foundation.set_meta("source_master_part_count", 3000)
	foundation.set_meta("editable_island_part_count", 3000)
	foundation.set_meta("variant_index", zone_index + 1)
	foundation.set_meta("variant_design", variant_names[zone_index])
	foundation.set_meta("gameplay_floor_radius", float(info.radius))
	foundation.set_meta("gameplay_collision_preserved", true)
	zone.add_child(foundation)
	var paving_scene := load("res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb") as PackedScene
	var paving := paving_scene.instantiate() as Node3D
	paving.name = "SharedCelestialPaving"
	foundation.add_child(paving)
	var variant_path := "res://assets3D/mind_spark/celestial_islands_v11/island_%02d.glb" % (zone_index + 1)
	if zone_index == 1:
		variant_path = "res://assets3D/mind_spark/celestial_verdant_v12/island_02.glb"
	elif zone_index == 2:
		variant_path = "res://assets3D/mind_spark/celestial_astral_v16/island_03.glb"
	elif zone_index == 3:
		variant_path = "res://assets3D/mind_spark/celestial_dawn_v17/island_04.glb"
	var variant_scene := load(variant_path) as PackedScene
	var architecture := variant_scene.instantiate() as Node3D
	architecture.name = "IslandArchitecture"
	foundation.add_child(architecture)
	if zone_index == 2:
		var controller := preload("res://scripts/mind_spark/astral_refinement.gd").new()
		foundation.add_child(controller)
		controller.configure(zone, foundation)
	elif zone_index == 3:
		var controller := preload("res://scripts/mind_spark/dawn_viaduct.gd").new()
		foundation.add_child(controller)
		controller.configure(zone, foundation)


func _build_surface_detail_network(parent: Node3D, radius: float, sector_count: int,
		zone_index: int, accent: Material) -> void:
	var network := Node3D.new()
	network.name = "AnimatedSurfaceDetailNetwork"
	network.set_meta("detail_method", "geometry, not baked texture")
	network.set_meta("animated", true)
	parent.add_child(network)
	var lane_count := 8 + zone_index
	for lane_index in lane_count:
		var angle := TAU * float(lane_index) / float(lane_count) + float(zone_index) * 0.13
		var lane_material: Material = _materials.island_cyan
		if lane_index % 4 == 1:
			lane_material = _materials.island_gold
		elif lane_index % 4 == 2:
			lane_material = _materials.island_root
		elif lane_index % 4 == 3:
			lane_material = accent
		var lane_start := Vector3(sin(angle) * radius * 0.34, 0.43, cos(angle) * radius * 0.34)
		var lane_end := Vector3(sin(angle) * radius * 0.79, 0.43, cos(angle) * radius * 0.79)
		for segment_index in 5:
			var progress := (float(segment_index) + 0.5) / 5.0
			var segment_at := lane_start.lerp(lane_end, progress)
			var segment := _add_box(network, "CircuitLane_%02d_%02d" % [lane_index + 1, segment_index + 1],
				segment_at, Vector3(maxf(0.72, radius * 0.0065), 0.16, radius * 0.074),
				lane_material, false, angle)
			segment.set_meta("micro_component", "raised circuit pipeline")
		var node_at := lane_start.lerp(lane_end, 0.55)
		_add_cylinder(network, "DataNodeBase_%02d" % (lane_index + 1), node_at,
			radius * 0.014, 0.18, _materials.island_rim, false, 8)
		_add_sphere(network, "DataNodeLight_%02d" % (lane_index + 1),
			node_at + Vector3.UP * 0.18, Vector3.ONE * radius * 0.0065, lane_material)
		for packet_index in 2:
			var packet := _add_sphere(network, "AnimatedDataPacket_%02d_%02d" % [lane_index + 1, packet_index + 1],
				lane_start, Vector3.ONE * radius * 0.009, lane_material)
			packet.set_meta("detail_packet", true)
			packet.set_meta("packet_base_scale", Vector3.ONE * radius * 0.009)
			packet.set_meta("path_start", lane_start)
			packet.set_meta("path_end", lane_end)
			packet.set_meta("packet_phase", fposmod(float(packet_index) * 0.5 + float(lane_index) * 0.071, 1.0))
			packet.set_meta("packet_speed", 0.16 + float((lane_index + zone_index) % 4) * 0.035)

	var crosslink_count := lane_count * 3
	for link_index in crosslink_count:
		var angle := TAU * float(link_index) / float(crosslink_count)
		var link_radius := radius * (0.50 if link_index % 2 == 0 else 0.68)
		var link_at := Vector3(sin(angle) * link_radius, 0.425, cos(angle) * link_radius)
		_add_box(network, "CircuitCrosslink_%03d" % (link_index + 1), link_at,
			Vector3(radius * 0.0055, 0.13, radius * 0.11),
			_materials.island_gold if link_index % 5 == 0 else _materials.island_cyan,
			false, angle + PI * 0.5)

	for detail_index in sector_count * 2:
		var angle := TAU * float(detail_index) / float(sector_count * 2) + float(zone_index) * 0.07
		var rivet_at := Vector3(sin(angle) * radius * 0.875, 0.43, cos(angle) * radius * 0.875)
		_add_cylinder(network, "DeckRivet_%03d" % (detail_index + 1), rivet_at,
			maxf(0.45, radius * 0.0045), 0.20, _materials.island_gold, false, 8)
		if detail_index % 2 == 0:
			var panel_at := Vector3(sin(angle) * radius * 0.91, 0.39,
				cos(angle) * radius * 0.91)
			_add_box(network, "RaisedServicePanel_%03d" % (detail_index + 1), panel_at,
				Vector3(radius * 0.026, 0.18, radius * 0.060), _materials.island_rim,
				false, angle)
			var tangent := Vector3(cos(angle), 0, -sin(angle))
			for slit_index in 3:
				_add_box(network, "TechPanelSlit_%03d_%02d" % [detail_index + 1, slit_index + 1],
					panel_at + tangent * radius * 0.007 * float(slit_index - 1) + Vector3.UP * 0.11,
					Vector3(radius * 0.003, 0.055, radius * 0.035),
					_materials.island_cyan if slit_index != 1 else _materials.island_gold,
					false, angle)


func _build_surface_engraved_dials(parent: Node3D, radius: float, zone_index: int) -> void:
	var dials := Node3D.new()
	dials.name = "EditableConstellationAndCalibrationDials"
	dials.set_meta("reference_layer", "constellation blue and engraved gold concept panels")
	parent.add_child(dials)
	for dial_index in 4:
		var angle := TAU * float(dial_index) / 4.0 + float(zone_index) * 0.17
		var center := Vector3(sin(angle) * radius * 0.45, 0.48,
			cos(angle) * radius * 0.45)
		_add_torus(dials, "ConstellationDial_%02d" % (dial_index + 1), center,
			radius * 0.024, radius * 0.034,
			_materials.island_cyan if dial_index % 2 == 0 else _materials.island_gold)
		_add_cylinder(dials, "DialSocket_%02d" % (dial_index + 1), center,
			radius * 0.010, 0.16, _materials.island_rim, false, 10)
		var tangent := Vector3(cos(angle), 0, -sin(angle))
		var radial := Vector3(sin(angle), 0, cos(angle))
		_add_beam_between(dials, "DialAxisA_%02d" % (dial_index + 1),
			center - tangent * radius * 0.040, center + tangent * radius * 0.040,
			maxf(0.22, radius * 0.0022), _materials.island_gold)
		_add_beam_between(dials, "DialAxisB_%02d" % (dial_index + 1),
			center - radial * radius * 0.040, center + radial * radius * 0.040,
			maxf(0.18, radius * 0.0018), _materials.island_cyan)


func _build_living_root_shell_lattice(parent: Node3D, radius: float, depth: float,
		zone_index: int) -> void:
	var lattice := Node3D.new()
	lattice.name = "EditableLivingRootShellLattice"
	lattice.set_meta("reference_layer", "bark roots with independent emerald data veins")
	parent.add_child(lattice)
	var root_count := 6 + zone_index
	for root_index in root_count:
		var start_angle := TAU * float(root_index) / float(root_count) + zone_index * 0.09
		var start_progress := 0.13
		var start_radius := lerpf(radius * 0.91,
			radius * (0.34 + zone_index * 0.012), start_progress / 0.84) + radius * 0.045
		var previous := Vector3(sin(start_angle) * start_radius, -depth * start_progress,
			cos(start_angle) * start_radius)
		for segment_index in 8:
			var progress := float(segment_index + 1) / 8.0
			var curl_angle := start_angle + sin(progress * PI + root_index * 0.7) * 0.22
			var vertical_progress := 0.13 + progress * 0.68
			var shell_radius := lerpf(radius * 0.91,
				radius * (0.34 + zone_index * 0.012), vertical_progress / 0.84) + radius * 0.045
			var next := Vector3(sin(curl_angle) * shell_radius,
				-depth * vertical_progress, cos(curl_angle) * shell_radius)
			var width := radius * lerpf(0.0075, 0.0030, progress)
			_add_cable_between(lattice, "RootBarkSegment_%02d_%02d" % [root_index + 1, segment_index + 1],
				previous, next, width, width * 0.86, _materials.island_bark_root)
			var outward := Vector3(next.x, 0, next.z).normalized() * width * 0.88
			var sideways := Vector3(-outward.z, 0, outward.x).normalized() * width * 0.62
			_add_cable_between(lattice, "RootEnergyVein_%02d_%02d" % [root_index + 1, segment_index + 1],
				previous + outward, next + outward, width * 0.22, width * 0.17,
				_materials.island_root)
			_add_cable_between(lattice, "RootCyanFiber_%02d_%02d" % [root_index + 1, segment_index + 1],
				previous + outward + sideways, next + outward + sideways,
				width * 0.13, width * 0.10, _materials.island_cyan)
			var packet_material: Material = _materials.island_cyan if (root_index + segment_index) % 3 == 0 else _materials.island_root
			var packet_scale := Vector3.ONE * width * 0.32
			var packet := _add_sphere(lattice,
				"RootNutrientPacket_%02d_%02d" % [root_index + 1, segment_index + 1],
				next + outward, packet_scale, packet_material)
			packet.set_meta("detail_packet", true)
			packet.set_meta("packet_base_scale", packet_scale)
			packet.set_meta("path_start", next + outward)
			packet.set_meta("path_end", previous + outward)
			packet.set_meta("packet_phase", fposmod(float(root_index) * 0.113 + float(segment_index) * 0.19, 1.0))
			packet.set_meta("packet_speed", 0.34 + float((root_index + segment_index) % 3) * 0.05)
			if segment_index == 2 or segment_index == 4:
				_add_sphere(lattice, "RootDataNode_%02d_%02d" % [root_index + 1, segment_index + 1],
					next + outward, Vector3.ONE * width * 0.38, _materials.island_root)
			previous = next


func _build_underbody_data_orbits(parent: Node3D, radius: float, depth: float,
		zone_index: int) -> void:
	for orbit_index in 2:
		var layer := Node3D.new()
		layer.name = "AnimatedUnderbodyOrbit_%02d" % (orbit_index + 1)
		layer.position.y = -depth * (0.31 + orbit_index * 0.22)
		layer.set_meta("detail_orbit_speed", (0.18 + orbit_index * 0.07) * (-1.0 if orbit_index else 1.0))
		parent.add_child(layer)
		var packet_count := 7 + zone_index + orbit_index
		var orbit_radius := radius * (0.54 - orbit_index * 0.13)
		for packet_index in packet_count:
			var angle := TAU * float(packet_index) / float(packet_count)
			var material: Material = _materials.island_root if packet_index % 3 == 0 else _materials.island_cyan
			_add_sphere(layer, "FieldPacket_%02d" % (packet_index + 1),
				Vector3(sin(angle) * orbit_radius, 0, cos(angle) * orbit_radius),
				Vector3.ONE * radius * 0.009, material)


func _build_underbody_service_modules(parent: Node3D, radius: float, depth: float,
		zone_index: int) -> void:
	# These are real, separately editable shell parts. Three counter-rotating
	# service belts make the levitation mechanism readable even without a UV map.
	for belt_index in 3:
		var progress := 0.18 + float(belt_index) * 0.22
		var belt := Node3D.new()
		belt.name = "AnimatedShellServiceBelt_%02d" % (belt_index + 1)
		belt.position.y = -2.0 - depth * progress
		belt.set_meta("detail_orbit_speed", (0.045 + belt_index * 0.025) * (-1.0 if belt_index == 1 else 1.0))
		parent.add_child(belt)
		var shell_radius := lerpf(radius * 0.91,
			radius * (0.34 + zone_index * 0.012), progress / 0.84) + radius * 0.018
		var module_count := 10 + zone_index + belt_index * 2
		for module_index in module_count:
			var angle := TAU * float(module_index) / float(module_count) + belt_index * 0.12
			var module_at := Vector3(sin(angle) * shell_radius, 0, cos(angle) * shell_radius)
			var shell_module := _add_box(belt,
				"EditableShellModule_%02d" % (module_index + 1), module_at,
				Vector3(radius * 0.055, maxf(0.65, depth * 0.025), radius * 0.026),
				_materials.island_rim, false, angle)
			shell_module.set_meta("micro_component", "underbody armour and field controller")
			var signal_material: Material = _materials.island_cyan
			if module_index % 4 == 1:
				signal_material = _materials.island_gold
			elif module_index % 4 == 2:
				signal_material = _materials.island_root
			elif module_index % 4 == 3:
				signal_material = _materials.island_violet_energy
			_add_sphere(belt, "ShellSignalNode_%02d" % (module_index + 1),
				Vector3(sin(angle) * (shell_radius + radius * 0.018), 0,
					cos(angle) * (shell_radius + radius * 0.018)),
				Vector3.ONE * radius * 0.008, signal_material)


func _build_levitation_crystal(parent: Node3D, crystal_index: int, at: Vector3,
		crystal_radius: float, crystal_length: float, accent: Material,
		is_central := false) -> void:
	var assembly := Node3D.new()
	assembly.name = "CentralLiftCrystalAssembly" if is_central else "TrimCrystalAssembly_%02d" % (crystal_index + 1)
	assembly.position = at
	assembly.set_meta("editable_component", true)
	assembly.set_meta("field_role", "primary lift" if is_central else "pitch and roll trim")
	parent.add_child(assembly)
	var body_length := crystal_length * 0.42
	var point_length := crystal_length * 0.58
	_add_cylinder(assembly, "OctagonalCrystalBody", Vector3(0, body_length * 0.21, 0),
		crystal_radius, body_length, _materials.island_crystal, false, 8)
	_build_crystal_facet_cells(assembly, crystal_radius, body_length, crystal_index)
	_add_tapered_cylinder(assembly, "FacetedCrystalPoint",
		Vector3(0, -body_length * 0.50 - point_length * 0.50, 0),
		crystal_radius, 0.0, point_length, _materials.island_crystal, 8)
	_add_tapered_cylinder(assembly, "CrystalCrown",
		Vector3(0, body_length * 0.50 + crystal_radius * 0.45, 0),
		0.0, crystal_radius, crystal_radius * 0.90, _materials.island_crystal, 8)
	_add_cylinder(assembly, "MechanicalCrystalSocket",
		Vector3(0, body_length * 0.62 + crystal_radius * 1.05, 0),
		crystal_radius * 1.38, crystal_radius * 0.72, _materials.island_rim, false, 10)
	_add_torus(assembly, "GoldCalibrationCollar", Vector3(0, body_length * 0.18, 0),
		crystal_radius * 1.06, crystal_radius * 1.34, _materials.island_gold)
	_add_torus(assembly, "LivingRootCoupler", Vector3(0, body_length * 0.39, 0),
		crystal_radius * 0.86, crystal_radius * 1.10, _materials.island_root,
		Vector3(4.0, 0, 0))
	var cyan_halo := _add_torus(assembly, "CyanFluxHalo", Vector3(0, -body_length * 0.22, 0),
		crystal_radius * 1.28, crystal_radius * 1.58, _materials.island_cyan)
	cyan_halo.set_meta("detail_orbit_speed", 0.42 if is_central else 0.30)
	for edge_index in 4:
		var edge_angle := TAU * float(edge_index) / 4.0
		var edge := _add_box(assembly, "CrystalFacetEdge_%02d" % (edge_index + 1),
			Vector3(sin(edge_angle) * crystal_radius * 0.72, -body_length * 0.06,
				cos(edge_angle) * crystal_radius * 0.72),
			Vector3(crystal_radius * 0.16, body_length * 0.88, crystal_radius * 0.16),
			_materials.island_gold if edge_index % 2 == 0 else _materials.island_cyan,
			false, edge_angle)
		edge.rotation.z = 0.07 * (-1.0 if edge_index % 2 else 1.0)
		for node_index in 2:
			_add_sphere(assembly, "FacetJoint_%02d_%02d" % [edge_index + 1, node_index + 1],
				Vector3(sin(edge_angle) * crystal_radius * 0.72,
					body_length * (0.36 if node_index == 0 else -0.45),
					cos(edge_angle) * crystal_radius * 0.72),
				Vector3.ONE * crystal_radius * 0.16,
				_materials.island_gold if node_index == 0 else _materials.island_cyan)
	for band_index in 2:
		_add_torus(assembly, "PhysicalFacetBand_%02d" % (band_index + 1),
			Vector3(0, body_length * (0.29 - band_index * 0.48), 0),
			crystal_radius * 0.91, crystal_radius * 1.03,
			_materials.island_gold if band_index == 0 else _materials.island_cyan)
	for trace_index in 8:
		var side_angle := TAU * float(trace_index % 4) / 4.0
		var radial := Vector3(sin(side_angle), 0, cos(side_angle))
		var tangent := Vector3(cos(side_angle), 0, -sin(side_angle))
		var surface_center := radial * crystal_radius * 0.96
		var start := surface_center - tangent * crystal_radius * 0.34
		var finish := surface_center + tangent * crystal_radius * 0.34
		start.y = body_length * (0.28 - float(trace_index % 2) * 0.38)
		finish.y = body_length * (-0.04 + float(trace_index % 2) * 0.22)
		_add_beam_between(assembly, "PhysicalFacetTrace_%02d" % (trace_index + 1),
			start, finish, crystal_radius * 0.075,
			_materials.island_cyan if trace_index % 3 else _materials.island_gold)
	if not is_central:
		var magic_halo := _add_torus(assembly, "MagicPhaseHalo", Vector3(0, -body_length * 0.58, 0),
			crystal_radius * 1.46, crystal_radius * 1.68, accent,
			Vector3(7.0 * float((crystal_index % 3) - 1), 0, 0))
		magic_halo.set_meta("detail_orbit_speed", -0.24 - float(crystal_index % 3) * 0.04)


func _build_crystal_facet_cells(parent: Node3D, crystal_radius: float,
		body_length: float, crystal_index: int) -> void:
	# Eight octagonal sides × eight irregular vertical cells × two triangles.
	# The 128 physical patches reproduce the fractured-glass reference while
	# remaining individually editable instead of baking the fracture map.
	var row_count := 8
	var side_count := 8
	var y_min := -body_length * 0.29
	for side_index in side_count:
		var angle_a := TAU * float(side_index) / float(side_count)
		var angle_b := TAU * float(side_index + 1) / float(side_count)
		for row_index in row_count:
			var y_a0 := y_min + body_length * float(row_index) / float(row_count)
			var y_a1 := y_min + body_length * float(row_index + 1) / float(row_count)
			var jitter_a := sin(float(side_index * 13 + row_index * 7 + crystal_index)) * body_length * 0.018
			var jitter_b := sin(float((side_index + 1) * 13 + row_index * 7 + crystal_index)) * body_length * 0.018
			var jitter_c := sin(float((side_index + 1) * 13 + (row_index + 1) * 7 + crystal_index)) * body_length * 0.018
			var jitter_d := sin(float(side_index * 13 + (row_index + 1) * 7 + crystal_index)) * body_length * 0.018
			# The patch shell stands proud of the octagonal core. This avoids the
			# cylinder's face-angle offset swallowing the individually modelled cells.
			var surface_radius := crystal_radius * (1.10 + float((side_index + row_index) % 3) * 0.004)
			var p00 := Vector3(sin(angle_a) * surface_radius, y_a0 + jitter_a,
				cos(angle_a) * surface_radius)
			var p10 := Vector3(sin(angle_b) * surface_radius, y_a0 + jitter_b,
				cos(angle_b) * surface_radius)
			var p11 := Vector3(sin(angle_b) * surface_radius, y_a1 + jitter_c,
				cos(angle_b) * surface_radius)
			var p01 := Vector3(sin(angle_a) * surface_radius, y_a1 + jitter_d,
				cos(angle_a) * surface_radius)
			var first_material: Material = _materials.island_crystal_facet_mid
			var second_material: Material = _materials.island_crystal_facet_dark
			if (side_index + row_index) % 5 == 0:
				first_material = _materials.island_crystal_facet_bright
			if (side_index * 3 + row_index) % 7 == 0:
				second_material = _materials.island_crystal_facet_bright
			var flip_diagonal := (side_index + row_index + crystal_index) % 2 == 0
			if flip_diagonal:
				_add_triangle_patch(parent, "CrystalFacetCell_%02d_%02d_A" % [side_index + 1, row_index + 1],
					p00, p10, p01, first_material)
				_add_triangle_patch(parent, "CrystalFacetCell_%02d_%02d_B" % [side_index + 1, row_index + 1],
					p10, p11, p01, second_material)
			else:
				_add_triangle_patch(parent, "CrystalFacetCell_%02d_%02d_A" % [side_index + 1, row_index + 1],
					p00, p10, p11, first_material)
				_add_triangle_patch(parent, "CrystalFacetCell_%02d_%02d_B" % [side_index + 1, row_index + 1],
					p00, p11, p01, second_material)


func _add_radial_plate(parent: Node3D, node_name: String, angle_start: float, angle_end: float,
		inner_radius: float, outer_radius: float, bottom_y: float, top_y: float,
		material: Material) -> MeshInstance3D:
	var points := PackedVector3Array([
		Vector3(sin(angle_start) * inner_radius, bottom_y, cos(angle_start) * inner_radius),
		Vector3(sin(angle_start) * outer_radius, bottom_y, cos(angle_start) * outer_radius),
		Vector3(sin(angle_end) * outer_radius, bottom_y, cos(angle_end) * outer_radius),
		Vector3(sin(angle_end) * inner_radius, bottom_y, cos(angle_end) * inner_radius),
		Vector3(sin(angle_start) * inner_radius, top_y, cos(angle_start) * inner_radius),
		Vector3(sin(angle_start) * outer_radius, top_y, cos(angle_start) * outer_radius),
		Vector3(sin(angle_end) * outer_radius, top_y, cos(angle_end) * outer_radius),
		Vector3(sin(angle_end) * inner_radius, top_y, cos(angle_end) * inner_radius),
	])
	var triangle_indices := PackedInt32Array([
		4, 5, 6, 4, 6, 7, 0, 2, 1, 0, 3, 2,
		0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5,
		2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7,
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point_index in triangle_indices:
		var point := points[point_index]
		surface.set_uv(Vector2(point.x / maxf(outer_radius, 0.001) * 0.5 + 0.5,
			point.z / maxf(outer_radius, 0.001) * 0.5 + 0.5))
		surface.add_vertex(point)
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_tapered_cylinder(parent: Node3D, node_name: String, at: Vector3,
		top_radius: float, bottom_radius: float, height: float, material: Material,
		segments: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	instance.set_meta("editable_component", true)
	parent.add_child(instance)
	return instance


func _build_zone_landmarks() -> void:
	# Phase 03 begins only after every floor and the complete story route exist.
	# This keeps future landmark iteration from changing the navigation topology.
	_build_landing(_zone_nodes["01_world_gate_landing"])
	# The former FibreRoot landmark was eight raised green rectangular bars.
	# They read as stray lines across the finished ivory garden deck, rather than
	# as living roots, and are not part of a quest, collision route, or power
	# system. The authored trees and garden assemblies below now own this space.
	_build_constellation_court(_zone_nodes["03_constellation_court"])
	_build_hope_ridge(_zone_nodes["04_hope_path_ridge"])
	_build_storm_arena(_zone_nodes["05_thought_storm_arena"])
	_build_oldest_tree(_zone_nodes["06_oldest_tree_sanctuary"])
	_build_greybox_checkpoints()


func _build_greybox_checkpoints() -> void:
	var checkpoint_specs := [
		["01_world_gate_landing", "ArrivalCheckpoint", Vector3(-48, 3, 34)],
		["02_living_network_forest", "NetworkCheckpoint", Vector3(-52, 3, -38)],
		["03_constellation_court", "ConstellationCheckpoint", Vector3(0, 3, 92)],
		["04_hope_path_ridge", "HopePathCheckpoint", Vector3(0, 3, 72)],
	]
	for spec in checkpoint_specs:
		var checkpoint := Marker3D.new()
		checkpoint.name = str(spec[1])
		checkpoint.position = spec[2]
		checkpoint.set_meta("story_route_checkpoint", true)
		(_zone_nodes[str(spec[0])] as Node3D).add_child(checkpoint)
		_add_cylinder(_zone_nodes[str(spec[0])], "%sPad" % str(spec[1]), spec[2] - Vector3(0, 2.75, 0),
			10.0, 0.5, _materials.cyan, true, 20)


func _build_main_route(parent: Node3D) -> void:
	var route := Node3D.new()
	route.name = "MainStoryCircuitRoute"
	route.set_meta("phase_02", "main_story_route")
	route.set_meta("route_zone_ids", PackedStringArray([
		"01_world_gate_landing",
		"02_living_network_forest",
		"03_constellation_court",
		"04_hope_path_ridge",
		"05_thought_storm_arena",
		"06_oldest_tree_sanctuary",
	]))
	route.set_meta("connection_pairs", PackedStringArray([
		"01_world_gate_landing>02_living_network_forest",
		"02_living_network_forest>03_constellation_court",
		"03_constellation_court>04_hope_path_ridge",
		"04_hope_path_ridge>05_thought_storm_arena",
		"05_thought_storm_arena>06_oldest_tree_sanctuary",
	]))
	route.set_meta("internal_promenade_pairs", PackedStringArray([
		"01_world_gate_landing>02_living_network_forest",
		"03_constellation_court>04_hope_path_ridge",
		"05_thought_storm_arena>06_oldest_tree_sanctuary",
	]))
	route.set_meta("external_bridge_pairs", PackedStringArray([
		"02_living_network_forest>03_constellation_court",
		"04_hope_path_ridge>05_thought_storm_arena",
	]))
	route.set_meta("physical_island_count", 3)
	route.set_meta("external_bridge_count", 2)
	route.set_meta("route_01_surface_source",
		"ThreeFusedSuperIslands/FusedSuperIsland_01_02/SharedIvorySaddleCollision")
	route.set_meta("route_01_access_control", "IslandOneHeavenlyStarGate")
	route.set_meta("ring_closed", false)
	parent.add_child(route)
	for index in ZONES.size() - 1:
		var start_center: Vector3 = ZONES[index].position
		var finish_center: Vector3 = ZONES[index + 1].position
		var horizontal := Vector3(
			finish_center.x - start_center.x, 0.0,
			finish_center.z - start_center.z).normalized()
		# Island floors are solid cylinders. Sending a bridge to a zone centre
		# puts the deck inside that cylinder; at Living Network this left the slab
		# at fox-head height for almost 80 m. Land at each outer rim instead, where
		# the bridge top can meet the island ground as one continuous surface.
		var is_internal_promenade := index % 2 == 0
		var start_inset := float(ZONES[index].radius) - CIRCUIT_ROUTE_LANDING_OVERLAP
		var finish_inset := float(ZONES[index + 1].radius) - CIRCUIT_ROUTE_LANDING_OVERLAP
		if is_internal_promenade:
			# The paired decks overlap. Keep the visible promenade near the shared
			# waist instead of calculating two rim points that cross each other.
			start_inset = float(ZONES[index].radius) * 0.42
			finish_inset = float(ZONES[index + 1].radius) * 0.42
		var start := start_center + horizontal * start_inset
		var finish := finish_center - horizontal * finish_inset
		# Derive both deck centrelines from the exact top faces of the same floor
		# geometry built above. This keeps the landing mathematically coplanar even
		# if the island slab thickness or centre offset changes later.
		var start_surface_y := _zone_floor_surface_y(start_center)
		var finish_surface_y := _zone_floor_surface_y(finish_center)
		start.y = start_surface_y - CIRCUIT_ROUTE_DECK_THICKNESS * 0.5
		finish.y = finish_surface_y - CIRCUIT_ROUTE_DECK_THICKNESS * 0.5
		# The second half is a level landing at the destination floor datum. This
		# crosses the cylinder's outer face with ground already beneath the player,
		# while retaining the authored ten-deck structural rhythm.
		var clear_span := Vector2(finish.x - start.x, finish.z - start.z).length()
		var landing_length := minf(CIRCUIT_ROUTE_LANDING_LENGTH, clear_span * 0.45)
		var bend := finish - horizontal * landing_length
		bend.y = finish.y
		if index == 0:
			# Districts 01 and 02 already occupy one continuous Blender-authored
			# foundation. Route 01 therefore owns no duplicate bridge or deck: its
			# progression is a physical threshold across the existing promenade.
			_build_island_one_heavenly_star_gate(route, start, finish, horizontal)
			continue
		_add_circuit_walkway(route, "CircuitRoute_%02d_A" % (index + 1), start, bend, 28.0)
		_add_circuit_walkway(route, "CircuitRoute_%02d_B" % (index + 1), bend, finish, 28.0)
		var route_kind := "internal_promenade" if is_internal_promenade else "external_sky_bridge"
		(route.get_node("CircuitRoute_%02d_A" % (index + 1)) as MeshInstance3D).set_meta("route_kind", route_kind)
		(route.get_node("CircuitRoute_%02d_B" % (index + 1)) as MeshInstance3D).set_meta("route_kind", route_kind)


func _build_island_one_heavenly_star_gate(route: Node3D, start: Vector3,
		finish: Vector3, direction: Vector3) -> void:
	var gate := Node3D.new()
	gate.name = "IslandOneHeavenlyStarGate"
	gate.position = start.lerp(finish, 0.52) + Vector3.UP * 0.1
	gate.rotation.y = atan2(direction.x, direction.z)
	gate.set_meta("preserve_authored_nodes", true)
	gate.set_meta("purpose", "locks the existing fused-island promenade until the Thought Constellation is understood")
	gate.set_meta("architectural_style", "heavenly civic portal; ivory, gilded brass, warm starlight and teal aether")
	gate.set_meta("gate_open", false)
	gate.set_meta("route_surface_is_existing_foundation", true)
	route.add_child(gate)

	# Blender production asset: 365 independently editable modules are reduced
	# to ten semantic meshes for runtime. The left leaf, right leaf and power
	# star stay separate so puzzle completion can animate real authored parts.
	var production_visual := HeavenlyStarGateProductionScene.instantiate() as Node3D
	production_visual.name = "HeavenlyStarGateProductionVisual"
	# Blender's authored facade looks toward -Y, which maps to the opposite side
	# of this route after glTF's Y-up conversion. Turn the complete production
	# hierarchy so arriving players see the framed leaves and recessed engines,
	# not the intentionally quiet service back.
	production_visual.rotation.y = PI
	production_visual.set_meta("editable_source_modules", 365)
	production_visual.set_meta("triangles", 57292)
	production_visual.set_meta("all_faces_triangulated", true)
	gate.add_child(production_visual)
	var halo := Node3D.new()
	halo.name = "HeavenlyStarHalo"
	halo.set_meta("design_revision", "v41_integrated_astrolabe_filigree_gate")
	halo.set_meta("design_origin", "earlier ivory conservatory arch and aether focal-point language")
	gate.add_child(halo)
	var detailed_star := production_visual.find_child("MSHG_PowerStar", true, false) as MeshInstance3D
	if detailed_star != null:
		detailed_star.reparent(halo, true)
		detailed_star.visible = false
		detailed_star.set_meta("retired_visual", "pastel star replaced by mechanical astrolabe crest")
	_build_gate_astrolabe_crest(halo, gate)
	# Compatibility feedback node retained for the existing state contract; the
	# visible core belongs to the production star mesh above.
	var core := _add_sphere(gate, "HeavenlyGatePowerCore", Vector3(0, 27.65, -1.7),
		Vector3.ONE * 0.05, _materials.astral_lavender)
	core.visible = false
	core.set_meta("power_feedback", true)
	_add_label(gate, "THE WAY OPENS WHEN UNDERSTANDING BECOMES LIGHT", Vector3(0, 34.0, 0),
		Color("ffe5a4"), 23)
	_add_zone_light(gate, Vector3(0, 27.0, -4.0), Color("ffd77f"), 34.0, 1.35)
	_build_heavenly_gate_surroundings(gate)

	_island_one_star_gate_leaves.clear()
	for side in [-1.0, 1.0]:
		var leaf := AnimatableBody3D.new()
		leaf.name = "WestGoldenStarLeaf" if side < 0 else "EastGoldenStarLeaf"
		leaf.sync_to_physics = true
		# The body origin is the outer hinge pin, not the centre of the artwork.
		# This makes both visible geometry and collision sweep around a real support
		# axis without passing through the classical piers.
		leaf.position = Vector3(side * 5.70, 0, -1.32)
		leaf.set_meta("closed_position", leaf.position)
		leaf.set_meta("open_position", leaf.position)
		leaf.set_meta("closed_rotation_y", 0.0)
		leaf.set_meta("open_rotation_y", side * deg_to_rad(96.0))
		leaf.set_meta("opening_mechanism", "three-bearing classical hinge leaf swinging inward around its outer pier")
		leaf.set_meta("mass_clearance", "leaf sweeps through a reserved semicircle behind the threshold and never crosses either pier")
		gate.add_child(leaf)
		var runtime_leaf_name := "MSHG_GateLeafLeft" if side < 0 else "MSHG_GateLeafRight"
		var authored_leaf := production_visual.find_child(runtime_leaf_name, true, false) as MeshInstance3D
		if authored_leaf != null:
			authored_leaf.reparent(leaf, true)
			authored_leaf.visible = false
			authored_leaf.set_meta("retired_visual", "rectangular shutter replaced by celestial filigree wing")
		_build_heavenly_gate_leaf_visual(leaf, side)
		var shape_node := CollisionShape3D.new()
		shape_node.name = "GateLeafCollision"
		shape_node.position = Vector3(-side * 2.68, 10.5, 0)
		var shape := BoxShape3D.new()
		shape.size = Vector3(5.9, 17.2, 1.10)
		shape_node.shape = shape
		leaf.add_child(shape_node)
		_island_one_star_gate_leaves.append(leaf)
	_set_island_one_star_gate_open(false, false)


func _build_gate_astrolabe_crest(halo: Node3D, gate: Node3D) -> void:
	# The crown is now architecture first and mechanism second. Its fixed ivory
	# sweeps carry the rotating astrolabe into both pylons, so the silhouette reads
	# as a celestial threshold rather than a machine badge floating above a wall.
	var architecture := Node3D.new()
	architecture.name = "HeavenlyCrownArchitecture"
	architecture.set_meta("purpose", "carries the celestial crown into the gate pylons")
	architecture.set_meta("visual_hierarchy", "ivory structure, warm gold ribs, aether glass, emerald accent")
	gate.add_child(architecture)
	var crest_at := Vector3(0, 25.0, -2.15)
	for side in [-1.0, 1.0]:
		var suffix := "West" if side < 0.0 else "East"
		var shoulder := Vector3(side * 13.3, 19.5, -1.25)
		var spring := Vector3(side * 7.5, 23.6, -1.80)
		var crown_join := crest_at + Vector3(side * 3.25, -1.15, 0.25)
		_add_cable_between(architecture, "%sIvoryCrownSweepLower" % suffix,
			shoulder, spring, 0.72, 0.48, _materials.sanctum_ivory, 12)
		_add_cable_between(architecture, "%sIvoryCrownSweepUpper" % suffix,
			spring, crown_join, 0.54, 0.34, _materials.sanctum_ivory, 12)
		_add_cable_between(architecture, "%sGiltCrownRib" % suffix,
			shoulder + Vector3(0, 0.35, -0.55), crown_join + Vector3(0, 0.25, -0.55),
			0.19, 0.12, _materials.gold, 10)
		_add_triangle_patch(architecture, "CrownAetherWing_%s" % suffix,
			shoulder + Vector3(0, 0.65, 0.35), spring + Vector3(0, 0.55, 0.35),
			crown_join + Vector3(0, 0.35, 0.35), _materials.arrival_glass)
		for pearl_index in 3:
			var pearl_at := shoulder.lerp(crown_join, (float(pearl_index) + 1.0) / 4.0)
			_add_sphere(architecture, "%sCrownPearl_%02d" % [suffix, pearl_index + 1],
				pearl_at + Vector3(0, 0.45, -0.42), Vector3.ONE * 0.27,
				_materials.sanctum_ivory)
	_add_brick(architecture, "HeavenlyCrownKeystone", crest_at + Vector3(0, -3.65, 0.35),
		Bricks.build_crystal(1.25, 3.2, 0.26, 8), _materials.sanctum_ivory)
	_add_brick(architecture, "HeavenlyCrownKeystoneInlay", crest_at + Vector3(0, -3.6, -0.35),
		Bricks.build_crystal(0.58, 2.0, 0.20, 8), _materials.gold)
	_add_zone_light(architecture, crest_at + Vector3(0, 0, -1.8), Color("fff0bd"), 18.0, 1.1)

	# The central instrument remains animated feedback, but emerald is confined to
	# the wisdom crystal and a slim inner order. Ivory and warm gold lead the read.
	_add_torus(halo, "AstrolabeIvoryBearingRing", crest_at, 2.95, 3.48,
		_materials.sanctum_ivory, Vector3(90, 0, 0))
	_add_torus(halo, "AstrolabeOuterBrassRing", crest_at + Vector3(0, 0, -0.14), 2.46, 2.92,
		_materials.astral_brass, Vector3(90, 0, 0))
	_add_torus(halo, "AstrolabeAetherHalo", crest_at + Vector3(0, 0, -0.22), 1.95, 2.30,
		_materials.arrival_glass, Vector3(90, 0, 0))
	_add_torus(halo, "AstrolabeInnerEmeraldRing", crest_at + Vector3(0, 0, -0.28),
		1.43, 1.67, _materials.green_glow, Vector3(90, 0, 0))
	for tooth_index in 12:
		var tooth_angle := TAU * float(tooth_index) / 12.0
		_add_box(halo, "AstrolabeGearTooth_%02d" % (tooth_index + 1),
			crest_at + Vector3(sin(tooth_angle) * 3.28, cos(tooth_angle) * 3.28, 0.04),
			Vector3(0.26, 0.58, 0.30),
			_materials.sanctum_ivory if tooth_index % 2 == 0 else _materials.gold,
			false, -tooth_angle)
	for spoke_index in 8:
		var spoke_angle := TAU * float(spoke_index) / 8.0
		_add_cable_between(halo, "AstrolabeSpoke_%02d" % (spoke_index + 1), crest_at,
			crest_at + Vector3(sin(spoke_angle) * 2.40, cos(spoke_angle) * 2.40, -0.10),
			0.13, 0.08, _materials.astral_brass, 8)
	_add_brick(halo, "AstrolabeEmeraldWisdomCrystal", crest_at + Vector3(0, 0, -0.48),
		Bricks.build_crystal(0.72, 3.25, 0.25, 8), _materials.green_glow)
	_add_sphere(halo, "AstrolabeWisdomPearl", crest_at + Vector3(0, 0, -0.72),
		Vector3.ONE * 0.48, _materials.arrival_glass)
	for orbit_index in 3:
		var orbit_angle := -PI * 0.42 + float(orbit_index) * PI * 0.42
		var jewel_at := crest_at + Vector3(sin(orbit_angle) * 3.82,
			cos(orbit_angle) * 1.65 - 0.22, -0.22)
		_add_sphere(halo, "AstrolabeEmeraldJewel_%02d" % (orbit_index + 1), jewel_at,
			Vector3.ONE * 0.30, _materials.arrival_glass)
		_add_cable_between(halo, "AstrolabeOrbitBrace_%02d" % (orbit_index + 1),
			crest_at, jewel_at, 0.10, 0.07, _materials.gold, 6)
	_add_box(halo, "AstrolabeCrownFinial", crest_at + Vector3(0, 3.95, 0),
		Vector3(0.30, 1.30, 0.30), _materials.astral_brass)
	_add_sphere(halo, "AstrolabeCrownPearl", crest_at + Vector3(0, 4.72, 0),
		Vector3.ONE * 0.38, _materials.arrival_glass)
	# Move the animation pivot to the bearing centre while preserving every
	# child's world-space placement. Rotation and pulse now happen in place.
	for child in halo.get_children():
		if child is Node3D:
			(child as Node3D).position -= crest_at
	halo.position = crest_at


func _build_heavenly_gate_surroundings(gate: Node3D) -> void:
	# A complete threshold court gives every previously empty area a job: the
	# centre remains circulation, the lintel carries the celestial arch, and the
	# side bays power the two classical hinge shafts.
	var court := Node3D.new()
	court.name = "HeavenlyThresholdCourt"
	court.set_meta("clear_walkway_width_m", 11.8)
	court.set_meta("mechanical_story", "aether motors turn two vertical hinge shafts so the grille leaves swing inward")
	court.set_meta("mass_clearance_rule", "each moving leaf stays inside its reserved inward swing envelope and outside the stone piers")
	court.set_meta("door_configuration", "two opposed inward-swinging hinged leaves")
	gate.add_child(court)
	_add_brick(court, "CelestialThresholdSlab", Vector3(0, 0.20, 0.45),
		Bricks.build_bevel_box(Vector3(14.2, 0.42, 5.4), 0.18), _materials.sanctum_ivory)
	_add_brick(court, "ThresholdGiltLeadingEdge", Vector3(0, 0.46, -2.18),
		Bricks.build_bevel_box(Vector3(14.0, 0.20, 0.26), 0.08), _materials.gold)
	for ray_index in 7:
		var ray_x := -5.4 + float(ray_index) * 1.8
		_add_cable_between(court, "ThresholdLightRay_%02d" % (ray_index + 1),
			Vector3(0, 0.48, 1.65), Vector3(ray_x, 0.48, -1.75),
			0.07, 0.055, _materials.arrival_glass, 6)
	_build_reference_heavenly_slide_portal(court)
	# Fixed lintel and threshold bands visually anchor the arch without suggesting
	# that the doors travel horizontally.
	_add_brick(court, "HeavenlyGateLintelBand", Vector3(0, 20.06, -1.28),
		Bricks.build_bevel_box(Vector3(27.4, 0.54, 0.82), 0.12), _materials.astral_brass)
	_add_brick(court, "HeavenlyGateThresholdBand", Vector3(0, 1.18, -1.18),
		Bricks.build_bevel_box(Vector3(27.0, 0.28, 0.62), 0.08), _materials.gold)
	_add_cable_between(court, "WestHingePowerConduit", Vector3(-0.35, 19.52, -1.62),
		Vector3(-13.25, 19.52, -1.62), 0.10, 0.08, _materials.gold, 8)
	_add_cable_between(court, "EastHingePowerConduit", Vector3(0.35, 19.52, -1.62),
		Vector3(13.25, 19.52, -1.62), 0.10, 0.08, _materials.gold, 8)

	for side in [-1.0, 1.0]:
		var suffix := "West" if side < 0.0 else "East"
		var bay_x: float = float(side) * 10.18
		# These side housings are fixed drive rooms for the hinge shafts. They no
		# longer pretend to be empty pockets for a sliding leaf.
		var pocket := Node3D.new()
		pocket.name = "%sHingeDriveHousing" % suffix
		pocket.set_meta("hinge_axis_x", side * 5.70)
		pocket.set_meta("reserved_swing_degrees", 96.0)
		pocket.set_meta("leaf_width_m", 5.85)
		court.add_child(pocket)
		_add_brick(pocket, "HingeHousingAetherLiner", Vector3(bay_x, 10.5, -0.38),
			Bricks.build_bevel_box(Vector3(6.55, 17.7, 0.28), 0.12), _materials.sanctum_lavender_glass)
		for jamb_offset in [-3.34, 3.34]:
			_add_brick(pocket, "HingeHousingIvoryJamb_%s" % str(jamb_offset),
				Vector3(bay_x + jamb_offset, 10.5, -2.18),
				Bricks.build_bevel_box(Vector3(0.62, 18.5, 0.36), 0.14), _materials.sanctum_ivory)
		_add_brick(pocket, "HingeHousingGiltCanopy", Vector3(bay_x, 19.70, -2.18),
			Bricks.build_bevel_box(Vector3(7.25, 0.60, 0.40), 0.14), _materials.astral_brass)
		_add_brick(pocket, "HingeHousingGiltSill", Vector3(bay_x, 1.00, -2.18),
			Bricks.build_bevel_box(Vector3(7.25, 0.35, 0.40), 0.12), _materials.astral_brass)
		for locator_index in 3:
			_add_sphere(pocket, "HingeTorqueLight_%02d" % (locator_index + 1),
				Vector3(bay_x - float(side) * 3.08, 5.0 + float(locator_index) * 5.2, -1.72),
				Vector3.ONE * 0.24, _materials.green_glow)
		var motor_x: float = bay_x + float(side) * 2.25
		# Keep the gear, teeth and aether core under one bearing pivot. This makes
		# the visible drive train rotate as a rigid assembly during the opening
		# stroke instead of reading as static ornament attached to a moving door.
		var drive_rotor := Node3D.new()
		drive_rotor.name = "%sHingeDriveRotor" % suffix
		drive_rotor.position = Vector3(motor_x, 17.15, -1.82)
		drive_rotor.set_meta("purpose", "turns the door chain and roller carriage")
		pocket.add_child(drive_rotor)
		_add_torus(drive_rotor, "HingeDriveGear", Vector3.ZERO,
			1.12, 1.62, _materials.astral_brass, Vector3(90, 0, 0))
		var motor_core := _add_cylinder(drive_rotor, "%sHingeMotorCore" % suffix,
			Vector3(0, 0, -0.20), 0.74, 0.42,
			_materials.arrival_glass, false, 20)
		motor_core.rotation_degrees.x = 90.0
		for tooth_index in 10:
			var tooth_angle := TAU * float(tooth_index) / 10.0
			_add_box(drive_rotor, "HingeDriveTooth_%02d" % (tooth_index + 1),
				Vector3(sin(tooth_angle) * 1.82, cos(tooth_angle) * 1.82, 0.04),
				Vector3(0.26, 0.58, 0.28), _materials.gold, false, -tooth_angle)
		# Graduated marks make the receiving bay read as a measured machine cavity
		# and provide a visual indication of how far each leaf has travelled.
		for gauge_index in 7:
			var gauge_x := bay_x - float(side) * (2.55 - float(gauge_index) * 0.82)
			_add_brick(pocket, "HingeAngleGauge_%02d" % (gauge_index + 1),
				Vector3(gauge_x, 2.05, -2.40),
				Bricks.build_bevel_box(Vector3(0.10, 0.56 if gauge_index % 2 == 0 else 0.34, 0.12), 0.03),
				_materials.gold)
		_add_brick(pocket, "HingeCelestialNameplate", Vector3(bay_x, 18.35, -2.42),
			Bricks.build_bevel_box(Vector3(2.8, 0.62, 0.16), 0.10), _materials.sanctum_ivory)
		_add_brick(pocket, "HingeNameplateInlay", Vector3(bay_x, 18.35, -2.54),
			Bricks.build_crystal(0.34, 1.12, 0.10, 8), _materials.green_glow)

		# The rear power bay supplies the chain motor while remaining behind the
		# swing envelope and outside the clear central walking corridor.
		var bay := Node3D.new()
		bay.name = "%sHingeDrivePowerBay" % suffix
		bay.set_meta("service_clearance_m", 1.2)
		court.add_child(bay)
		_add_brick(bay, "IvoryBayPlinth", Vector3(bay_x, 1.05, 1.20),
			Bricks.build_bevel_box(Vector3(5.6, 1.55, 4.8), 0.30), _materials.sanctum_ivory)
		_add_brick(bay, "IvoryBayCanopy", Vector3(bay_x, 17.9, 1.20),
			Bricks.build_bevel_box(Vector3(5.9, 1.0, 4.9), 0.26), _materials.sanctum_ivory)
		for post_offset in [-2.05, 2.05]:
			_add_brick(bay, "BayPost_%s" % str(post_offset),
				Vector3(bay_x + post_offset, 9.4, 1.20),
				Bricks.build_bevel_box(Vector3(0.64, 16.4, 0.72), 0.16), _materials.celestial_floor)
		var reservoir := _add_cylinder(bay, "AetherLiftReservoir",
			Vector3(bay_x, 7.2, 1.20), 1.52, 9.8,
			_materials.arrival_glass, false, 24)
		reservoir.set_meta("purpose", "stores puzzle energy for the gate opening stroke")
		for band_index in 4:
			_add_torus(bay, "ReservoirGiltBand_%02d" % (band_index + 1),
				Vector3(bay_x, 3.7 + float(band_index) * 2.35, 1.20),
				1.48, 1.72, _materials.gold)
		var weight_x: float = bay_x - float(side) * 1.75
		_add_brick(bay, "GuidedChainTensioner", Vector3(weight_x, 12.5, 1.18),
			Bricks.build_bevel_box(Vector3(1.15, 4.4, 1.35), 0.20), _materials.astral_brass)
		_add_cable_between(bay, "TensionerGuideA",
			Vector3(weight_x - 0.58, 2.1, 1.20), Vector3(weight_x - 0.58, 17.3, 1.20),
			0.11, 0.08, _materials.gold, 8)
		_add_cable_between(bay, "TensionerGuideB",
			Vector3(weight_x + 0.58, 2.1, 1.20), Vector3(weight_x + 0.58, 17.3, 1.20),
			0.11, 0.08, _materials.gold, 8)
		_add_torus(bay, "ChainReturnPulley", Vector3(weight_x, 16.2, 0.55),
			0.82, 1.20, _materials.astral_brass, Vector3(90, 0, 0))
		_add_cable_between(bay, "HingeMotorPowerConduit",
			Vector3(bay_x, 14.6, 0.25), Vector3(motor_x, 17.15, -1.55),
			0.24, 0.16, _materials.gold, 10)

		# Low luminous gardens soften the machinery and occupy the outer corners
		# without hiding the door or creating collision in the approach lane.
		var garden_x: float = float(side) * 13.6
		_add_brick(court, "%sCelestialPlanter" % suffix, Vector3(garden_x, 1.0, -3.6),
			Bricks.build_bevel_box(Vector3(5.0, 1.6, 3.4), 0.34), _materials.sanctum_ivory)
		for stem_index in 5:
			var stem_x: float = garden_x - 1.55 + float(stem_index) * 0.78
			var stem_top := Vector3(stem_x, 3.0 + float(stem_index % 2) * 0.55, -3.6)
			_add_cable_between(court, "%sGardenStem_%02d" % [suffix, stem_index + 1],
				Vector3(stem_x, 1.75, -3.6), stem_top, 0.10, 0.06,
				_materials.astral_brass, 6)
			_add_sphere(court, "%sAetherBlossom_%02d" % [suffix, stem_index + 1],
				stem_top, Vector3(0.42, 0.28, 0.42),
				_materials.arrival_glass if stem_index % 2 == 0 else _materials.sanctum_ivory)
		_add_zone_light(court, Vector3(garden_x, 4.0, -3.4), Color("dffcff"), 8.0, 0.65)


func _build_reference_heavenly_slide_portal(court: Node3D) -> void:
	# The reference silhouette is a classical arch floating in warm cloud light.
	# This outer order is fixed architecture: only the two filigree leaves move.
	# Keeping structure and moving mass separate also makes the slide physically
	# readable from the player's approach.
	var portal := Node3D.new()
	portal.name = "ClassicalHeavenlyHingedPortal"
	portal.set_meta("reference_language", "semicircular ivory arch, gold reveal, paired pilasters and symmetrical filigree")
	portal.set_meta("moving_parts", "WestGoldenStarLeaf and EastGoldenStarLeaf rotate around outer hinge pins")
	court.add_child(portal)
	var spring_y := 17.55
	var outer_radius := 7.42
	var inner_radius := 6.72
	for side in [-1.0, 1.0]:
		var side_value: float = float(side)
		var suffix := "West" if side_value < 0.0 else "East"
		var pier_x: float = side_value * outer_radius
		_add_brick(portal, "%sCloudstonePlinth" % suffix, Vector3(pier_x, 1.35, -2.62),
			Bricks.build_bevel_box(Vector3(2.35, 2.15, 2.45), 0.28), _materials.sanctum_ivory)
		_add_brick(portal, "%sClassicalPilaster" % suffix, Vector3(pier_x, 9.55, -2.55),
			Bricks.build_bevel_box(Vector3(1.42, 15.1, 1.65), 0.22), _materials.celestial_floor)
		_add_brick(portal, "%sGiltPilasterInset" % suffix, Vector3(pier_x, 9.70, -3.43),
			Bricks.build_bevel_box(Vector3(0.44, 11.9, 0.16), 0.06), _materials.gold)
		_add_brick(portal, "%sCorinthianCapital" % suffix, Vector3(pier_x, spring_y, -2.58),
			Bricks.build_bevel_box(Vector3(2.55, 1.38, 2.25), 0.25), _materials.sanctum_ivory)
		_add_brick(portal, "%sCapitalGoldBand" % suffix, Vector3(pier_x, spring_y + 0.28, -3.76),
			Bricks.build_bevel_box(Vector3(2.72, 0.24, 0.16), 0.05), _materials.astral_brass)
		for flute_index in 3:
			var flute_x: float = pier_x + (-0.36 + float(flute_index) * 0.36)
			_add_cable_between(portal, "%sPilasterFlute_%02d" % [suffix, flute_index + 1],
				Vector3(flute_x, 3.1, -3.43), Vector3(flute_x, 15.8, -3.43),
				0.055, 0.035, _materials.astral_brass, 8)
	# Three concentric segmented orders create carved depth without a solid wall.
	var arch_orders := [
		[outer_radius, 0.54, _materials.sanctum_ivory],
		[7.05, 0.22, _materials.gold],
		[inner_radius, 0.26, _materials.sanctum_ivory],
	]
	for order_index in arch_orders.size():
		var order: Array = arch_orders[order_index]
		var radius: float = float(order[0])
		var thickness: float = float(order[1])
		var material: Material = order[2] as Material
		for segment_index in 24:
			var angle_a := PI * float(segment_index) / 24.0
			var angle_b := PI * float(segment_index + 1) / 24.0
			_add_cable_between(portal, "HeavenlyArchOrder_%02d_%02d" % [order_index + 1, segment_index + 1],
				Vector3(cos(angle_a) * radius, spring_y + sin(angle_a) * radius, -2.68 - float(order_index) * 0.12),
				Vector3(cos(angle_b) * radius, spring_y + sin(angle_b) * radius, -2.68 - float(order_index) * 0.12),
				thickness, thickness * 0.72, material, 8)
	# A restrained sunrise and paired scrolls fill the tympanum like the reference
	# while leaving the crown astrolabe as the highest-level puzzle feedback.
	var dawn_center := Vector3(0, 20.45, -3.15)
	_add_torus(portal, "TympanumDawnRose", dawn_center, 0.48, 0.82,
		_materials.astral_brass, Vector3(90, 0, 0))
	_add_sphere(portal, "TympanumWisdomPearl", dawn_center + Vector3(0, 0, -0.20),
		Vector3.ONE * 0.34, _materials.arrival_glass)
	for ray_index in 9:
		var ray_angle := PI * float(ray_index) / 8.0
		_add_cable_between(portal, "TympanumSunRay_%02d" % (ray_index + 1), dawn_center,
			dawn_center + Vector3(cos(ray_angle) * 3.75, sin(ray_angle) * 3.25, 0),
			0.085, 0.045, _materials.gold, 6)
	_add_heavenly_gate_scroll(portal, "WestTympanumScroll", Vector3(-3.75, 21.05, -3.18), 1.0, 1.18)
	_add_heavenly_gate_scroll(portal, "EastTympanumScroll", Vector3(3.75, 21.05, -3.18), -1.0, 1.18)
	_add_brick(portal, "HeavenlyArchKeystone", Vector3(0, spring_y + outer_radius, -3.06),
		Bricks.build_crystal(0.70, 2.10, 0.18, 8), _materials.sanctum_ivory)


func _build_heavenly_gate_pylon(gate: Node3D, suffix: String, side: float) -> void:
	var x := side * 17.0
	_add_box(gate, "%sIvoryPylonCollisionVisual" % suffix, Vector3(x, 9.5, 0),
		Vector3(6.0, 19.0, 6.2), _materials.celestial_floor, true)
	_add_brick(gate, "%sSteppedPlinth" % suffix, Vector3(x, 1.0, 0),
		Bricks.build_bevel_box(Vector3(9.0, 2.0, 9.2), 0.45), _materials.celestial_floor)
	_add_brick(gate, "%sPylonShoulder" % suffix, Vector3(x, 17.5, 0),
		Bricks.build_bevel_box(Vector3(8.0, 3.0, 8.0), 0.40), _materials.celestial_floor)
	_add_box(gate, "%sGiltPylonInlay" % suffix, Vector3(x, 10.0, -3.2),
		Vector3(1.7, 11.0, 0.45), _materials.gold)
	_add_torus(gate, "%sHingeEngine" % suffix, Vector3(side * 13.7, 9.5, -3.4),
		3.0, 4.2, _materials.astral_brass, Vector3(90, 0, 0))
	_add_cylinder(gate, "%sHingeAetherCore" % suffix, Vector3(side * 13.7, 9.5, -3.7),
		2.1, 0.65, _materials.arrival_glass, false, 24).rotation_degrees.x = 90
	for tooth_index in 12:
		var tooth_angle := TAU * float(tooth_index) / 12.0
		_add_box(gate, "%sHingeTooth_%02d" % [suffix, tooth_index + 1],
			Vector3(side * 13.7 + sin(tooth_angle) * 4.6,
				9.5 + cos(tooth_angle) * 4.6, -3.4),
			Vector3(0.55, 1.15, 0.48), _materials.gold, false, tooth_angle)
	_add_torus(gate, "%sAetherCrown" % suffix, Vector3(x, 21.0, 0),
		2.3, 3.3, _materials.astral_brass, Vector3(90, 0, 0))
	_add_sphere(gate, "%sCrownStar" % suffix, Vector3(x, 21.0, 0),
		Vector3.ONE * 1.45, _materials.arrival_glass)


func _build_heavenly_gate_leaf_visual(leaf: AnimatableBody3D, side: float) -> void:
	# A symmetric framed carriage keeps its centre on the rail. Every ornamental
	# component belongs to the moving body; rollers and guide shoes make the means
	# of support readable at player distance.
	var leaf_center_y := 10.5
	_add_brick(leaf, "IvoryLeafSpine", Vector3(0, leaf_center_y, 0),
		Bricks.build_bevel_box(Vector3(0.30, 15.8, 0.70), 0.10), _materials.sanctum_ivory)
	_add_brick(leaf, "IvoryMeetingStile", Vector3(-side * 2.68, leaf_center_y, 0),
		Bricks.build_bevel_box(Vector3(0.38, 16.5, 0.78), 0.13), _materials.celestial_floor)
	_add_brick(leaf, "IvoryOuterStile", Vector3(side * 2.68, leaf_center_y, 0),
		Bricks.build_bevel_box(Vector3(0.38, 16.5, 0.78), 0.13), _materials.celestial_floor)
	_add_brick(leaf, "GiltLeafBase", Vector3(0, 2.25, 0),
		Bricks.build_bevel_box(Vector3(5.85, 0.62, 0.88), 0.18), _materials.astral_brass)
	_add_cable_between(leaf, "GiltLeafCrown",
		Vector3(side * 2.55, 14.25, -0.42), Vector3(-side * 2.55, 18.35, -0.42),
		0.22, 0.14, _materials.astral_brass, 10)
	# The perimeter is assembled from stepped structural orders, matching the
	# layered ivory-and-gold language of the surrounding civic architecture.
	for frame_level in 3:
		var inset := float(frame_level) * 0.22
		var frame_material: Material = _materials.gold if frame_level == 1 else _materials.sanctum_ivory
		_add_brick(leaf, "CelestialFrameWest_%02d" % (frame_level + 1),
			Vector3(-2.34 + inset, leaf_center_y, -0.74 - float(frame_level) * 0.08),
			Bricks.build_bevel_box(Vector3(0.18, 14.95 - inset * 2.0, 0.20), 0.05), frame_material)
		_add_brick(leaf, "CelestialFrameEast_%02d" % (frame_level + 1),
			Vector3(2.34 - inset, leaf_center_y, -0.74 - float(frame_level) * 0.08),
			Bricks.build_bevel_box(Vector3(0.18, 14.95 - inset * 2.0, 0.20), 0.05), frame_material)
	# Narrow translucent channels preserve the aether identity without turning the
	# leaf into a heavy glass shutter.
	for pane_index in 3:
		var pane_x := -1.65 + float(pane_index) * 1.65
		_add_brick(leaf, "AetherDoorPane_%02d" % (pane_index + 1),
			Vector3(pane_x, 10.15, 0.18),
			Bricks.build_bevel_box(Vector3(0.26, 13.9, 0.14), 0.06),
			_materials.arrival_glass if pane_index != 1 else _materials.sanctum_lavender_glass)
	# Seven fine grille bars rise toward the meeting seam, producing one complete
	# arched composition only when both hinged leaves are sealed together.
	for bar_index in 7:
		var bar_x := -2.16 + float(bar_index) * 0.72
		var inward_progress := clampf((-side * bar_x + 2.16) / 4.32, 0.0, 1.0)
		var bar_top := 14.35 + inward_progress * 3.75
		var bar_bottom := 2.65
		_add_cable_between(leaf, "CelestialGrilleBar_%02d" % (bar_index + 1),
			Vector3(bar_x, bar_bottom, -0.94), Vector3(bar_x, bar_top, -0.94),
			0.105, 0.065, _materials.gold, 10)
		_add_sphere(leaf, "GrilleSpearPearl_%02d" % (bar_index + 1),
			Vector3(bar_x, bar_top + 0.16, -0.94), Vector3(0.12, 0.30, 0.12),
			_materials.sanctum_ivory)
	var medallion_at := Vector3(-side * 1.52, leaf_center_y + 0.15, -1.12)
	# Six radial braces transfer visual load from the medallion into the perimeter.
	for rib_index in 6:
		var progress := float(rib_index) / 5.0
		var feather_tip := Vector3(
			(-2.35 if rib_index % 2 == 0 else 2.35),
			leaf_center_y - 6.0 + progress * 12.0, -0.86)
		_add_cable_between(leaf, "GiltWingRib_%02d" % (rib_index + 1),
			medallion_at + Vector3(0, 0, 0.18), feather_tip,
			0.12, 0.075, _materials.gold, 8)
	# Four fine aether braces form a calm diamond around the central seal.
	var lattice_targets := [
		Vector3(-2.20, 5.0, -0.98), Vector3(2.20, 5.0, -0.98),
		Vector3(-2.20, 16.0, -0.98), Vector3(2.20, 16.0, -0.98),
	]
	for lattice_index in 4:
		_add_cable_between(leaf, "AetherLattice_%02d" % (lattice_index + 1),
			medallion_at + Vector3(0, 0, 0.08), lattice_targets[lattice_index],
			0.16, 0.10, _materials.arrival_glass, 8)
	for pearl_index in 5:
		_add_sphere(leaf, "LeafFeatherPearl_%02d" % (pearl_index + 1),
			Vector3(-2.28 + float(pearl_index) * 1.14, 17.75, -1.12),
			Vector3.ONE * 0.23, _materials.sanctum_ivory)
	_add_torus(leaf, "LeafAstrolabeMedallion",
		medallion_at,
		0.52, 0.88, _materials.gold, Vector3(90, 0, 0))
	_add_sphere(leaf, "LeafAetherJewel",
		medallion_at + Vector3(0, 0, -0.22),
		Vector3.ONE * 0.30, _materials.green_glow)
	# Mirrored scrollwork is the signature detail from the reference. It occupies
	# the negative space between bars but stays thin enough to preserve visibility.
	_add_heavenly_gate_scroll(leaf, "UpperFiligreeScroll", Vector3(-side * 0.92, 15.55, -1.04), side, 0.72)
	_add_heavenly_gate_scroll(leaf, "LowerFiligreeScroll", Vector3(-side * 0.92, 7.10, -1.04), side, 0.62)
	# Each half of the celestial lock remains attached to its own leaf. When the
	# doors meet, the tongue nests between the receiver forks without overlapping
	# solid geometry; when they open, the complete seal visibly separates.
	var meeting_x := -side * 2.78
	var lock := Node3D.new()
	lock.name = "WestCelestialInterlock" if side < 0.0 else "EastCelestialInterlock"
	lock.position = Vector3(meeting_x, leaf_center_y, -1.28)
	lock.set_meta("mechanism", "paired tongue and fork seam lock")
	leaf.add_child(lock)
	_add_brick(lock, "InterlockBackplate", Vector3.ZERO,
		Bricks.build_bevel_box(Vector3(0.44, 3.65, 0.32), 0.10), _materials.astral_brass)
	for lock_band in [-1.20, 1.20]:
		_add_brick(lock, "InterlockFork_%s" % str(lock_band), Vector3(0, lock_band, -0.24),
			Bricks.build_bevel_box(Vector3(0.62, 0.34, 0.42), 0.08), _materials.gold)
	_add_brick(lock, "InterlockWisdomKey", Vector3(0, 0, -0.34),
		Bricks.build_crystal(0.40, 1.65, 0.16, 8), _materials.green_glow)
	# Fine fasteners and circuit pearls give close-range scale without competing
	# with the medallion, which remains the dominant player-facing focal point.
	for fastener_index in 8:
		var fastener_y := 3.45 + float(fastener_index) * 2.02
		for fastener_side in [-1.0, 1.0]:
			_add_sphere(leaf, "FrameRivet_%s_%02d" % ["W" if fastener_side < 0 else "E", fastener_index + 1],
				Vector3(fastener_side * 2.50, fastener_y, -0.98), Vector3.ONE * 0.115,
				_materials.gold)
	for circuit_index in 4:
		var circuit_y := 4.4 + float(circuit_index) * 3.85
		_add_cable_between(leaf, "AetherCircuit_%02d" % (circuit_index + 1),
			Vector3(-1.95, circuit_y, -0.90), Vector3(1.95, circuit_y, -0.90),
			0.075, 0.05, _materials.arrival_glass, 6)
	_add_brick(leaf, "DoorStateCrystal", Vector3(0, 17.55, -1.20),
		Bricks.build_crystal(0.34, 1.20, 0.12, 8), _materials.arrival_glass)
	# Three separated bearing knuckles carry the leaf around the outer pier. Their
	# common axis becomes the AnimatableBody origin after the pivot correction.
	for hinge_index in 3:
		var hinge_y := 4.35 + float(hinge_index) * 6.05
		var hinge_x := side * 2.68
		var barrel := _add_cylinder(leaf, "DoorHingeBarrel_%02d" % (hinge_index + 1),
			Vector3(hinge_x, hinge_y, -0.18), 0.34, 1.62,
			_materials.astral_brass, false, 18)
		barrel.set_meta("load_role", "supports rotating leaf on outer pier")
		_add_torus(leaf, "DoorHingeCollarTop_%02d" % (hinge_index + 1),
			Vector3(hinge_x, hinge_y + 0.72, -0.18), 0.30, 0.46, _materials.gold)
		_add_torus(leaf, "DoorHingeCollarBottom_%02d" % (hinge_index + 1),
			Vector3(hinge_x, hinge_y - 0.72, -0.18), 0.30, 0.46, _materials.gold)
	_add_brick(leaf, "DoorHingeSpine", Vector3(side * 2.68, 10.5, 0.02),
		Bricks.build_bevel_box(Vector3(0.26, 16.8, 0.30), 0.07), _materials.gold)
	# Rebase every authored component around the outside stile. The parent body's
	# origin is now a true hinge axis rather than the former leaf centre.
	for visual_child in leaf.get_children():
		if visual_child is Node3D:
			(visual_child as Node3D).position += Vector3(-side * 2.68, 0, 0)


func _add_heavenly_gate_scroll(parent: Node3D, node_name: String, center: Vector3,
		mirror: float, scale_value: float) -> void:
	# A segmented logarithmic curl exports as ordinary Web-safe mesh pieces and
	# remains individually editable, unlike a shader-only decorative line.
	var scroll := Node3D.new()
	scroll.name = node_name
	scroll.set_meta("editable_segments", 14)
	parent.add_child(scroll)
	var previous := center + Vector3(mirror * scale_value * 1.65, 0, 0)
	for segment_index in 14:
		var progress := float(segment_index + 1) / 14.0
		var angle := progress * TAU * 1.18
		var radius := scale_value * lerpf(1.65, 0.18, progress)
		var current := center + Vector3(mirror * cos(angle) * radius, sin(angle) * radius, 0)
		_add_cable_between(scroll, "ScrollSegment_%02d" % (segment_index + 1),
			previous, current, 0.075, 0.045, _materials.gold, 6)
		previous = current
	_add_sphere(scroll, "ScrollPearl", previous + Vector3(0, 0, -0.04),
		Vector3.ONE * 0.13, _materials.sanctum_ivory)


func get_island_one_heavenly_star_gate() -> Node3D:
	return get_node_or_null("WorldOneGeometry/MainStoryCircuitRoute/IslandOneHeavenlyStarGate") as Node3D


func is_island_one_star_gate_open() -> bool:
	var gate := get_island_one_heavenly_star_gate()
	return gate != null and bool(gate.get_meta("gate_open", false))


func _set_island_one_star_gate_open(open: bool, animate: bool) -> void:
	var gate := get_island_one_heavenly_star_gate()
	if gate == null or _island_one_star_gate_leaves.is_empty():
		return
	if _island_one_star_gate_tween != null and _island_one_star_gate_tween.is_valid():
		_island_one_star_gate_tween.kill()
	gate.set_meta("gate_open", open)
	gate.set_meta("gate_state", "opening" if open and animate else ("open" if open else "sealed"))
	var motion := gate.get_node_or_null("SafeGateMotion")
	if motion == null:
		motion = preload("res://scripts/mind_spark/safe_gate_motion.gd").new()
		motion.name = "SafeGateMotion"
		gate.add_child(motion)
	motion.request(open,animate)
	var core := gate.get_node_or_null("HeavenlyGatePowerCore") as MeshInstance3D
	if core != null:
		core.material_override = _materials.gold if open else _materials.astral_lavender
	for engine_core in gate.find_children("*HingeMotorCore", "MeshInstance3D", true, false):
		(engine_core as MeshInstance3D).material_override = _materials.gold if open else _materials.arrival_glass
	for state_crystal in gate.find_children("DoorStateCrystal", "MeshInstance3D", true, false):
		(state_crystal as MeshInstance3D).material_override = _materials.green_glow if open else _materials.arrival_glass
	if not animate:
		for leaf in _island_one_star_gate_leaves:
			leaf.position = leaf.get_meta("open_position") if open else leaf.get_meta("closed_position")
			leaf.rotation.y = float(leaf.get_meta("open_rotation_y")) if open \
				else float(leaf.get_meta("closed_rotation_y"))
		return
	_island_one_star_gate_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	var halo := gate.get_node_or_null("HeavenlyStarHalo") as Node3D
	if halo != null:
		_island_one_star_gate_tween.tween_property(halo, "rotation:z",
			halo.rotation.z + (TAU if open else -TAU), 1.65) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
		halo.scale = Vector3.ONE * 0.82
		_island_one_star_gate_tween.tween_property(halo, "scale", Vector3.ONE * 1.12, 0.52) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_island_one_star_gate_tween.tween_property(halo, "scale", Vector3.ONE, 0.58).set_delay(0.52)
	if core != null:
		core.scale = Vector3.ONE * 0.72
		_island_one_star_gate_tween.tween_property(core, "scale", Vector3.ONE * 1.28, 0.48) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_island_one_star_gate_tween.tween_property(core, "scale", Vector3.ONE, 0.46).set_delay(0.48)
	for drive_rotor in gate.find_children("*HingeDriveRotor", "Node3D", true, false):
		var rotor := drive_rotor as Node3D
		_island_one_star_gate_tween.tween_property(rotor, "rotation:z",
			rotor.rotation.z + (TAU * 2.0 if open else -TAU * 2.0), 2.03) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	# Leaf transforms and completion state belong to obstruction-aware physics motion.


func _zone_floor_surface_y(zone_center: Vector3) -> float:
	return zone_center.y + ZONE_FLOOR_CENTER_Y + ZONE_FLOOR_HEIGHT * 0.5


func _build_world_one_ring_closure(route: Node3D) -> void:
	# The original five links formed a chain, leaving the final sanctuary with
	# only one physical way out. This sixth link closes the islands into a ring.
	# Level landings at both ends keep either travel direction free of a riser.
	var start_info: Dictionary = ZONES[ZONES.size() - 1]
	var finish_info: Dictionary = ZONES[0]
	var start_center: Vector3 = start_info.position
	var finish_center: Vector3 = finish_info.position
	var horizontal := Vector3(
		finish_center.x - start_center.x, 0.0,
		finish_center.z - start_center.z).normalized()
	var start := start_center + horizontal * (
		float(start_info.radius) - CIRCUIT_ROUTE_LANDING_OVERLAP)
	var finish := finish_center - horizontal * (
		float(finish_info.radius) - CIRCUIT_ROUTE_LANDING_OVERLAP)
	start.y = _zone_floor_surface_y(start_center) - CIRCUIT_ROUTE_DECK_THICKNESS * 0.5
	finish.y = _zone_floor_surface_y(finish_center) - CIRCUIT_ROUTE_DECK_THICKNESS * 0.5
	var start_landing_end := start + horizontal * CIRCUIT_ROUTE_LANDING_LENGTH
	start_landing_end.y = start.y
	var finish_landing_start := finish - horizontal * CIRCUIT_ROUTE_LANDING_LENGTH
	finish_landing_start.y = finish.y
	_add_circuit_walkway(route, "CircuitRoute_06_A", start, start_landing_end, 28.0)
	_add_circuit_walkway(route, "CircuitRoute_06_B", start_landing_end, finish_landing_start, 28.0)
	_add_circuit_walkway(route, "CircuitRoute_06_C", finish_landing_start, finish, 28.0)
	route.set_meta("ring_closed", true)


func _build_island_transit_network(parent: Node3D) -> void:
	var network := Node3D.new()
	network.name = "MindSparkTransitNetwork"
	network.set_meta("travel_model", "three reciprocal opposite-island portal pairs")
	network.set_meta("unlocks_on_world_state", "gentle_rain")
	network.set_meta("portal_count", ZONES.size())
	network.set_meta("physical_bridge_degree_per_island", 2)
	parent.add_child(network)

	var centroid := Vector3.ZERO
	for zone_info in ZONES:
		centroid += zone_info.position as Vector3
	centroid /= float(ZONES.size())
	var portal_positions: Array[Vector3] = []
	var outward_directions: Array[Vector3] = []
	for zone_info in ZONES:
		var center: Vector3 = zone_info.position
		var outward := Vector3(center.x - centroid.x, 0.0, center.z - centroid.z).normalized()
		var portal_position := center + outward * (
			float(zone_info.radius) - TRANSIT_PORTAL_EDGE_INSET)
		portal_position.y = _zone_floor_surface_y(center)
		portal_positions.append(portal_position)
		outward_directions.append(outward)

	var encoded_pairs := PackedStringArray()
	for pair_index in TRANSIT_PORTAL_PAIRS.size():
		var pair: Array = TRANSIT_PORTAL_PAIRS[pair_index]
		var first_index := int(pair[0])
		var second_index := int(pair[1])
		_add_island_transit_portal(network, first_index, second_index, pair_index,
			portal_positions, outward_directions)
		_add_island_transit_portal(network, second_index, first_index, pair_index,
			portal_positions, outward_directions)
		encoded_pairs.append("%s<->%s" % [ZONES[first_index].id, ZONES[second_index].id])
	network.set_meta("reciprocal_pairs", encoded_pairs)


func _add_island_transit_portal(network: Node3D, source_index: int, target_index: int,
		pair_index: int, portal_positions: Array[Vector3],
		outward_directions: Array[Vector3]) -> void:
	var source_info: Dictionary = ZONES[source_index]
	var target_info: Dictionary = ZONES[target_index]
	var source_position := portal_positions[source_index]
	var target_position := portal_positions[target_index]
	var target_outward := outward_directions[target_index]
	var arrival := target_position - target_outward * TRANSIT_PORTAL_ARRIVAL_CLEARANCE
	arrival.y = _zone_floor_surface_y(target_info.position) + 7.0

	_add_cylinder(network, "TransitPad_%02d" % (source_index + 1),
		source_position + Vector3.UP * 0.12, 11.0, 0.24,
		_materials.violet if pair_index % 2 == 0 else _materials.cyan, false, 28)
	_add_torus(network, "TransitGuideRing_%02d" % (source_index + 1),
		source_position + Vector3.UP * 0.35, 12.0, 14.0, _materials.cyan)

	var portal := WorldGateScene.instantiate() as MindSparkWorldGate
	portal.name = "Transit_%02d_to_%02d" % [source_index + 1, target_index + 1]
	portal.position = source_position
	portal.destination_world_local = to_global(arrival)
	# MindSparkWorldGate resolves destinations in ArtCastleFloatingWorld-local
	# coordinates, even though this world is itself offset inside that scene.
	var floating_world := get_parent() as Node3D
	if floating_world != null and floating_world.name == "ArtCastleFloatingWorld":
		portal.destination_world_local = floating_world.to_local(to_global(arrival))
	else:
		portal.destination_world_local = arrival
	portal.prompt_text = "Q • WARP TO %s" % _zone_short_title(target_info)
	portal.gate_enabled = false
	portal.set_meta("source_zone_id", str(source_info.id))
	portal.set_meta("destination_zone_id", str(target_info.id))
	portal.set_meta("reciprocal_portal", "Transit_%02d_to_%02d" % [target_index + 1, source_index + 1])
	portal.set_meta("pair_index", pair_index)
	portal.set_meta("approach_world_one_local",
		source_position - outward_directions[source_index] * TRANSIT_PORTAL_ARRIVAL_CLEARANCE)
	portal.set_meta("arrival_world_one_local", arrival)
	network.add_child(portal)
	_transit_portals.append(portal)


func _zone_short_title(zone_info: Dictionary) -> String:
	var title := str(zone_info.title)
	var separator := title.find("•")
	return title.substr(separator + 1).strip_edges() if separator >= 0 else title


func _build_station_access_stairs(parent: Node3D, bottom: Vector3, top: Vector3) -> Node3D:
	## A visibly stepped climb whose risers stay inside the player's step height.
	## Each tread carries its own flat collision, and one continuous ramp body
	## underneath keeps the walk smooth instead of catching on every riser edge.
	var stairs := Node3D.new()
	stairs.name = "StationAccessStairs"
	# Traversal validation and accessibility tooling inspect each visible tread;
	# keep this small functional assembly out of the global visual batch.
	stairs.set_meta("preserve_authored_nodes", true)
	parent.add_child(stairs)
	var rise := top.y - bottom.y
	# Horizontal run only. The ramp below is sized as the hypotenuse of span and
	# rise, so using the 3D distance here counts the rise twice and builds a ramp
	# that overshoots the landing — the climb then stalls short of the top.
	var span := Vector2(top.x - bottom.x, top.z - bottom.z).length()
	var step_count := maxi(1, int(ceil(rise / STATION_STAIR_MAX_RISER)))
	var yaw := atan2(top.x - bottom.x, top.z - bottom.z)
	var tread_depth := span / float(step_count)
	for index in step_count:
		var progress := float(index + 1) / float(step_count)
		var tread_center := bottom.lerp(top, progress - 0.5 / float(step_count))
		tread_center.y = bottom.y + rise * progress
		# Treads are deliberately visual only. Giving each one its own collision
		# box turns every riser edge into a wall the player walks straight into,
		# because the box is centred on the ramp surface rather than resting on
		# it. The continuous ramp below carries all of the walking collision.
		_add_box(stairs, "StationStep_%02d" % (index + 1), tread_center,
			Vector3(STATION_STAIR_WIDTH, 0.14, tread_depth), _materials.stone, false, yaw)
	# The continuous under-ramp is the only walking surface, so the climb stays
	# smooth while the treads above it still read as a flight of stairs.
	var ramp_middle := bottom.lerp(top, 0.5)
	ramp_middle.y = bottom.y + rise * 0.5
	# Sit the ramp so its top face meets the treads; the player then walks level
	# with the visible steps instead of on a surface sunk below them.
	var ramp_thickness := 1.6
	var ramp := _add_box(stairs, "StationStairRamp",
		ramp_middle - Vector3(0, ramp_thickness * 0.5, 0),
		Vector3(STATION_STAIR_WIDTH, ramp_thickness, sqrt(span * span + rise * rise)),
		_materials.floor_grid, true, yaw)
	ramp.rotation.x = -atan2(rise, span)
	(stairs.get_node("StationStairRampCollision") as StaticBody3D).rotation = ramp.rotation
	# Low kerbs mark the edges without blocking the view down to the arena.
	var side_axis := Vector3(cos(yaw), 0, -sin(yaw))
	for side in [-1.0, 1.0]:
		var kerb_center: Vector3 = ramp_middle \
			+ side_axis * float(side) * (STATION_STAIR_WIDTH * 0.5 - 0.6) + Vector3(0, 0.6, 0)
		var kerb := _add_box(stairs, "StationStairKerb%s" % ("Left" if side < 0 else "Right"),
			kerb_center, Vector3(1.1, 0.9, sqrt(span * span + rise * rise)),
			_materials.cyan, false, yaw)
		kerb.rotation.x = ramp.rotation.x
	stairs.set_meta("step_count", step_count)
	stairs.set_meta("max_riser", rise / float(step_count))
	return stairs


func _build_landing(zone: Node3D) -> void:
	_build_celestial_world_gate_arrival(zone, 1.0)
	var entry_gate := WorldGateScene.instantiate() as MindSparkWorldGate
	entry_gate.name = "EntryWorldGate"
	entry_gate.position = Vector3(0, 1, -38)
	entry_gate.destination_world_local = return_destination_world_local
	entry_gate.prompt_text = "Q • RETURN TO ART CASTLE"
	zone.add_child(entry_gate)
	# The former ArrivalRootBridge permanently occupied the gate's centre and
	# made the puzzle reward meaningless. The processional court is already a
	# walkable floor; the only bridge now is the powered Route 01 deployment.
	for side in [-1.0, 1.0]:
		for index in 5:
			var lamp_at := Vector3(side * 13, 5, 65 - index * 20)
			_add_tapered_cylinder(zone, "RootLamp", lamp_at, 0.62, 0.92, 10,
				_materials.celestial_floor, 12)
			_add_torus(zone, "RootLampGiltCollar", lamp_at + Vector3.UP * 5.0,
				0.72, 1.05, _materials.astral_brass)
			_add_sphere(zone, "RootLampGlassCrown", lamp_at + Vector3.UP * 6.0,
				Vector3(1.25, 1.8, 1.25), _materials.arrival_glass)
	_add_label(zone, "Q • USE OBJECTS     1–5 • CHOOSE", Vector3(0, 17, 54), Color("fff1aa"), 31)


func _build_celestial_world_gate_arrival(zone: Node3D, scale_factor: float) -> Node3D:
	## Reusable Island One landmark: a warm ivory-and-brass arrival conservatory
	## derived from the user's bird's-eye reference. Every roof pane is an
	## independent triangle and every rib/column/tower remains separately editable.
	var arrival := IslandOnePuzzleScript.new() as MindSparkIslandOnePuzzle
	arrival.name = "CelestialWorldGateArrival"
	arrival.scale = Vector3.ONE * scale_factor
	arrival.set_meta("island_focus", "01_world_gate_landing")
	arrival.set_meta("above_ground_revision", "v21_reusable_gate_kit")
	arrival.set_meta("design_style", "luxurious warm heavenly Piltover industrial conservatory")
	arrival.set_meta("structural_purpose", "arrival station, return gate shelter and aether navigation beacon")
	arrival.set_meta("route_axis", Vector3.FORWARD)
	arrival.set_meta("clear_processional_width_m", 40.0)
	arrival.set_meta("triangulated_glass_panels", 144)
	arrival.set_meta("editable_above_ground_components", 1080)
	zone.add_child(arrival)
	var gate_kit := _create_island_one_gate_architecture_kit(arrival)
	var terrace := gate_kit.get_node("01_CivicTerraceKit") as Node3D
	var pavilion := gate_kit.get_node("02_AetherConservatoryKit") as Node3D
	var threshold := gate_kit.get_node("03_ThresholdStructureKit") as Node3D
	var beacons := gate_kit.get_node("04_BeaconTowerKit") as Node3D
	var landscape := gate_kit.get_node("05_LandscapeTrimKit") as Node3D

	# Layered civic court: ivory shell, restrained gilt reveals and an illuminated
	# compass rose. These low visual pieces do not add obstacles to the route.
	_add_cylinder(terrace, "ArrivalIvoryCourt", Vector3(0, 0.26, 8), 73.0, 0.52,
		_materials.celestial_floor, false, 64)
	_add_torus(terrace, "ArrivalCourtOuterGiltRing", Vector3(0, 0.58, 8),
		66.0, 67.0, _materials.astral_brass)
	_add_torus(terrace, "ArrivalCourtInnerAetherRing", Vector3(0, 0.60, 8),
		39.0, 40.0, _materials.arrival_glass)
	_add_box(terrace, "ProcessionalIvoryAxis", Vector3(0, 0.61, 20),
		Vector3(19.0, 0.18, 112.0), _materials.celestial_floor, false)
	_add_box(terrace, "ProcessionalGiltInlay", Vector3(0, 0.72, 20),
		Vector3(1.2, 0.12, 109.0), _materials.astral_brass, false)

	pavilion.set_meta("roof_type", "faceted barrel vault with open axial ends")
	pavilion.set_meta("roof_triangle_count", 144)
	pavilion.set_meta("vault_rib_count", 7)
	var roof_z_start := -42.0
	var roof_z_finish := 42.0
	var rib_count := 7
	var arc_segments := 12
	var half_span := 31.0
	var spring_height := 17.0
	var crown_rise := 19.0
	for rib_index in rib_count:
		var z := lerpf(roof_z_start, roof_z_finish, float(rib_index) / float(rib_count - 1))
		for arc_index in arc_segments:
			var angle_a := PI - PI * float(arc_index) / float(arc_segments)
			var angle_b := PI - PI * float(arc_index + 1) / float(arc_segments)
			var point_a := Vector3(cos(angle_a) * half_span,
				spring_height + sin(angle_a) * crown_rise, z)
			var point_b := Vector3(cos(angle_b) * half_span,
				spring_height + sin(angle_b) * crown_rise, z)
			_add_cable_between(pavilion, "IvoryVaultRib_%02d_%02d" % [rib_index + 1, arc_index + 1],
				point_a, point_b, 0.58, 0.58, _materials.celestial_floor, 12)
			_add_cable_between(pavilion, "GiltVaultReveal_%02d_%02d" % [rib_index + 1, arc_index + 1],
				point_a + Vector3(0, 0.34, 0), point_b + Vector3(0, 0.34, 0),
				0.15, 0.15, _materials.astral_brass, 10)

	# Six longitudinal bays x twelve curved bays x two triangles = 144 small,
	# editable glass panels. Their real triangle seams make the roof read clearly
	# at both bird's-eye and player scale.
	for longitudinal_index in rib_count - 1:
		var z_a := lerpf(roof_z_start, roof_z_finish,
			float(longitudinal_index) / float(rib_count - 1))
		var z_b := lerpf(roof_z_start, roof_z_finish,
			float(longitudinal_index + 1) / float(rib_count - 1))
		for arc_index in arc_segments:
			var angle_a := PI - PI * float(arc_index) / float(arc_segments)
			var angle_b := PI - PI * float(arc_index + 1) / float(arc_segments)
			var a0 := Vector3(cos(angle_a) * half_span,
				spring_height + sin(angle_a) * crown_rise, z_a)
			var a1 := Vector3(cos(angle_b) * half_span,
				spring_height + sin(angle_b) * crown_rise, z_a)
			var b0 := Vector3(cos(angle_a) * half_span,
				spring_height + sin(angle_a) * crown_rise, z_b)
			var b1 := Vector3(cos(angle_b) * half_span,
				spring_height + sin(angle_b) * crown_rise, z_b)
			var panel_id := longitudinal_index * arc_segments + arc_index
			_add_triangle_patch(pavilion, "CanopyGlassTriangle_%03d_A" % (panel_id + 1),
				a0, b0, b1, _materials.arrival_glass)
			_add_triangle_patch(pavilion, "CanopyGlassTriangle_%03d_B" % (panel_id + 1),
				a0, b1, a1, _materials.arrival_glass)

	# The triangular glass seams and seven transverse ribs already describe the
	# complete vault. Thirteen additional longitudinal mullions terminated behind
	# the puzzle gateway and read as a fence from player height, so only the two
	# eave rails remain. This keeps a credible glass load path without visual noise.
	for arc_index in [0, arc_segments]:
		var angle := PI - PI * float(arc_index) / float(arc_segments)
		var start := Vector3(cos(angle) * half_span,
			spring_height + sin(angle) * crown_rise, roof_z_start)
		var finish := Vector3(cos(angle) * half_span,
			spring_height + sin(angle) * crown_rise, roof_z_finish)
		_add_cable_between(pavilion, "LongitudinalGlassMullion_%02d" % (arc_index + 1),
			start, finish, 0.20, 0.20, _materials.astral_brass, 10)
	for rib_index in rib_count:
		var z := lerpf(roof_z_start, roof_z_finish, float(rib_index) / float(rib_count - 1))
		_add_sphere(pavilion, "VaultRidgeKeystone_%02d" % (rib_index + 1),
			Vector3(0, spring_height + crown_rise + 0.7, z), Vector3(0.85, 1.15, 0.85),
			_materials.celestial_floor)
		_add_torus(pavilion, "VaultRidgeGiltCollar_%02d" % (rib_index + 1),
			Vector3(0, spring_height + crown_rise + 0.7, z), 0.72, 1.02,
			_materials.astral_brass, Vector3(90, 0, 0))

	# Ten paired columns support the spring line without entering the forty-metre
	# processional clearance. Bases and capitals make the hierarchy legible.
	for side in [-1.0, 1.0]:
		for column_index in 5:
			var column_at := Vector3(float(side) * 31.0, 8.5, -38.0 + column_index * 19.0)
			_add_tapered_cylinder(pavilion,
				"%sIvoryColumn_%02d" % ["West" if side < 0 else "East", column_index + 1],
				column_at, 0.90, 1.35, 16.0, _materials.celestial_floor, 16)
			_add_torus(pavilion, "ColumnGiltFoot", column_at - Vector3.UP * 7.75,
				1.05, 1.52, _materials.astral_brass)
			_add_torus(pavilion, "ColumnGiltCapital", column_at + Vector3.UP * 7.75,
				1.05, 1.58, _materials.astral_brass)
			# The transverse vault ribs already land directly on these capitals.
			# Earlier diagonal spring braces repeated that load path twenty times and
			# crossed the puzzle camera corridor, so the clean sanctum revision omits
			# them in favour of the legible column → capital → rib hierarchy.

	# The portal facade uses a true segmented curve instead of the previous
	# rectangular clock-like frame. It frames the existing functional gate.
	_build_celestial_arrival_arch(threshold)
	for side in [-1.0, 1.0]:
		_build_arrival_lantern_tower(beacons, side)
		for garden_index in 2:
			_build_arrival_garden_planter(landscape, side, garden_index)
	_build_island_one_compass_gameplay(arrival)
	_build_island_one_science_art_garden(arrival)
	_island_one_puzzle = arrival
	arrival.puzzle_solved.connect(_on_island_one_puzzle_solved)
	arrival.configure(object_state_store_path, scale_factor)
	_set_island_one_star_gate_open(arrival.is_powered(), false)
	var arrival_light := _add_zone_light(arrival, Vector3(0, 42, -2), Color("ffe3ad"), 112.0, 3.15)
	arrival_light.name = "HighHeavenlyArrivalLight"
	return arrival


func _create_island_one_gate_architecture_kit(arrival: Node3D) -> Node3D:
	var kit := Node3D.new()
	kit.name = "GateArchitectureKit"
	kit.set_meta("kit_revision", "v21")
	kit.set_meta("component_family_count", 22)
	kit.set_meta("reusable_variant_count", 39)
	kit.set_meta("unique_landmark_count", 1)
	kit.set_meta("application_mode", "additive_on_existing_island")
	kit.set_meta("processional_clearance_m", 40.0)
	arrival.add_child(kit)
	var definitions := [
		["01_CivicTerraceKit", 3, 8, "radial paving, inlays and processional axis"],
		["02_AetherConservatoryKit", 6, 9, "ribs, panes, mullions, columns and braces"],
		["03_ThresholdStructureKit", 5, 9, "portal piers, curved arch, reveals and keystone"],
		["04_BeaconTowerKit", 3, 5, "plinth, pressure drum and glass beacon crown"],
		["05_LandscapeTrimKit", 5, 8, "planters, soil beds, blooms and route trim"],
	]
	for definition in definitions:
		var assembly := Node3D.new()
		assembly.name = str(definition[0])
		assembly.set_meta("component_family_count", int(definition[1]))
		assembly.set_meta("reusable_variant_count", int(definition[2]))
		assembly.set_meta("contents", str(definition[3]))
		assembly.set_meta("reusable_kit_assembly", true)
		kit.add_child(assembly)
	return kit


func get_island_one_puzzle() -> MindSparkIslandOnePuzzle:
	return _island_one_puzzle


func _on_island_one_puzzle_solved(result: Dictionary) -> void:
	set_world_state("waking")
	set_meta("island_one_bearing_sigil", true)
	_set_island_one_star_gate_open(true, true)
	island_one_puzzle_solved.emit(result)


func _build_island_one_compass_gameplay(arrival: MindSparkIslandOnePuzzle) -> void:
	# The compass is deliberately split into independently named rings, teeth,
	# rune plaques and operator stations. Dynamic subtrees are excluded from the
	# static batching pass so state feedback and replay remain visible in-game.
	var machine := Node3D.new()
	machine.name = "CompassMachine"
	machine.set_meta("preserve_authored_nodes", true)
	machine.set_meta("purpose", "route aether power from Island One to Island Two")
	arrival.add_child(machine)
	_add_cylinder(machine, "CompassIvoryDais", Vector3(0, 1.05, 8), 24.0, 1.55,
		_materials.celestial_floor, false, 48)
	_add_torus(machine, "CompassOuterBrassKerb", Vector3(0, 1.88, 8), 22.0, 23.7,
		_materials.astral_brass)
	_add_cylinder(machine, "CompassAetherLens", Vector3(0, 1.94, 8), 18.2, 0.20,
		_materials.arrival_glass, false, 48)
	_build_compass_ring(machine, "OuterCompassRing", 18.2, 20.4, 36, 0)
	_build_compass_ring(machine, "MiddleCompassRing", 12.4, 14.3, 28, 1)
	_build_compass_ring(machine, "InnerCompassRing", 6.8, 8.5, 20, 2)
	_add_cylinder(machine, "CompassHeartIvory", Vector3(0, 2.55, 8), 4.9, 1.25,
		_materials.celestial_floor, false, 24)
	_add_torus(machine, "CompassHeartGiltCollar", Vector3(0, 3.22, 8), 3.8, 4.9,
		_materials.astral_brass)
	_add_sphere(machine, "CompassHeartAetherCore", Vector3(0, 5.3, 8),
		Vector3(3.2, 4.0, 3.2), _materials.arrival_glass)
	# A celestial lotus collar and nested wisdom halos make the heart read as a
	# sacred thinking instrument rather than a sphere placed on a platform.
	for petal_index in 16:
		var petal_angle := TAU * float(petal_index) / 16.0
		var petal_at := Vector3(sin(petal_angle) * 5.35, 3.15,
			8 + cos(petal_angle) * 5.35)
		_add_box(machine, "CompassHeartLotusPetal_%02d" % (petal_index + 1), petal_at,
			Vector3(0.72, 0.34, 2.25),
			_materials.gold if petal_index % 2 == 0 else _materials.celestial_floor,
			false, petal_angle)
		_add_sphere(machine, "CompassHeartPearl_%02d" % (petal_index + 1),
			petal_at + Vector3.UP * 0.48, Vector3.ONE * 0.18, _materials.arrival_glass)
	_add_torus(machine, "CompassHeartMeridianA", Vector3(0, 5.3, 8), 3.65, 4.05,
		_materials.gold, Vector3(90, 0, 0))
	_add_torus(machine, "CompassHeartMeridianB", Vector3(0, 5.3, 8), 3.65, 4.05,
		_materials.astral_brass, Vector3(0, 0, 90))
	_add_torus(machine, "CompassHeartMeridianC", Vector3(0, 5.3, 8), 4.10, 4.45,
		_materials.arrival_glass, Vector3(0, 90, 0))
	_build_thought_witness(machine)
	_build_constellation_target_instrument(machine)
	var puzzle_light := _add_zone_light(arrival, Vector3(0, 36.0, 42.0), Color("ffe9bd"), 68.0, 2.85)
	puzzle_light.name = "HighPuzzleCompositionLight"
	for spoke_index in 12:
		var angle := TAU * float(spoke_index) / 12.0
		var start := Vector3(sin(angle) * 5.0, 2.42, 8 + cos(angle) * 5.0)
		var finish := Vector3(sin(angle) * 21.6, 2.42, 8 + cos(angle) * 21.6)
		_add_cable_between(machine, "CompassGiltSpoke_%02d" % (spoke_index + 1),
			start, finish, 0.18, 0.10, _materials.astral_brass, 8)

	var controls := Node3D.new()
	controls.name = "PuzzleControls"
	controls.set_meta("preserve_authored_nodes", true)
	arrival.add_child(controls)
	_build_light_prism_control(controls, "colour_prism", Vector3(-39.5, 3.2, 16.0),
		"COLOUR • ROUTE A SEED")
	_build_light_prism_control(controls, "rhythm_prism", Vector3(-37.5, 3.2, 30.0),
		"RHYTHM • ROUTE A SEED")
	_build_light_prism_control(controls, "weight_prism", Vector3(-66.0, 3.2, 24.0),
		"WEIGHT • ROUTE A SEED")
	_build_compass_control(controls, "west_regulator", Vector3(-24, 3.0, -22), "NOTICE SIGNAL", 0)
	_build_compass_control(controls, "east_regulator", Vector3(24, 3.0, -22), "MAKE SPACE", 0)
	_build_compass_control(controls, "outer_ring", Vector3(-22, 3.0, 58), "NOTICE + UNDERSTAND", 1)
	_build_compass_control(controls, "middle_ring", Vector3(0, 3.0, 64), "UNDERSTAND + CHOOSE", 1)
	_build_compass_control(controls, "inner_ring", Vector3(22, 3.0, 58), "CHOOSE + NOTICE", 1)
	_build_compass_control(controls, "confirm", Vector3(0, 3.0, 76), "SEND FORWARD", 2)
	_build_living_light_routes(arrival)
	_build_aether_analysis_console(controls)

	_build_pressure_gauge(arrival, "WestPressureGauge", Vector3(-24.0, 12.5, -22.0), -0.18)
	_build_pressure_gauge(arrival, "EastPressureGauge", Vector3(24.0, 12.5, -22.0), 0.18)
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0 else "East"
		var governor := Node3D.new()
		governor.name = "%sGovernorRotor" % side_name
		governor.position = Vector3(side * 16.0, 8.0, -16.0)
		governor.set_meta("preserve_authored_nodes", true)
		arrival.add_child(governor)
		_add_cylinder(governor, "GovernorAxle", Vector3.ZERO, 0.65, 7.0,
			_materials.astral_brass, false, 12)
		for arm_index in 4:
			var arm_angle := TAU * float(arm_index) / 4.0
			var arm_finish := Vector3(sin(arm_angle) * 4.2, 0, cos(arm_angle) * 4.2)
			_add_cable_between(governor, "GovernorArm_%02d" % arm_index, Vector3.ZERO,
				arm_finish, 0.25, 0.18, _materials.astral_brass, 8)
			_add_sphere(governor, "GovernorWeight_%02d" % arm_index, arm_finish,
				Vector3.ONE * 0.85, _materials.arrival_glass)

	var conduits := Node3D.new()
	conduits.name = "PuzzlePowerConduits"
	arrival.add_child(conduits)
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 24.0
		_add_cable_between(conduits, "PuzzlePowerConduitTower", Vector3(x, 4.0, -22),
			Vector3(side * 22.0, 2.7, 8), 0.48, 0.30, _materials.astral_brass, 12)
		_add_cable_between(conduits, "PuzzleAetherTubeTower", Vector3(x, 4.5, -20),
			Vector3(side * 18.0, 2.9, 8), 0.25, 0.18, _materials.arrival_glass, 10)
	# Paired floor circuits explain the coupling without relying on HUD text.
	var selector_positions := [Vector3(-22, 3.3, 58), Vector3(0, 3.3, 64), Vector3(22, 3.3, 58)]
	var coupled_ring_points := [
		[Vector3(-18, 2.8, 22), Vector3(-9, 2.9, 18)],
		[Vector3(-6, 2.9, 18), Vector3(6, 3.0, 15)],
		[Vector3(18, 3.0, 22), Vector3(9, 2.8, 18)],
	]
	for selector_index in 3:
		for link_index in 2:
			_add_cable_between(conduits,
				"CoupledOrbit_%02d_%02d" % [selector_index + 1, link_index + 1],
				selector_positions[selector_index], coupled_ring_points[selector_index][link_index],
				0.25, 0.13, _materials.arrival_glass if link_index == 0 else _materials.gold, 10)
	_add_cable_between(conduits, "PuzzlePowerConduitBridge", Vector3(0, 3.0, 28),
		Vector3(0, 3.0, 73), 0.56, 0.38, _materials.astral_brass, 12)
	_add_cable_between(conduits, "PuzzleAetherTubeBridge", Vector3(0, 3.4, 28),
		Vector3(0, 3.4, 73), 0.28, 0.18, _materials.arrival_glass, 10)

	var projection := Node3D.new()
	projection.name = "SolvedRouteProjection"
	projection.visible = false
	projection.set_meta("preserve_authored_nodes", true)
	arrival.add_child(projection)
	for index in 15:
		var z := 29.0 + float(index) * 3.0
		var beacon := _add_sphere(projection, "RouteLight_%02d" % (index + 1),
			Vector3(0, 4.1, z), Vector3(0.44, 0.20, 0.95), _materials.gold)
		beacon.rotation.y = float(index) * 0.42
	var socket_glow := Node3D.new()
	socket_glow.name = "BridgePowerSocketGlow"
	socket_glow.position = Vector3(0, 4.0, 73)
	socket_glow.visible = false
	socket_glow.set_meta("preserve_authored_nodes", true)
	arrival.add_child(socket_glow)
	_add_torus(socket_glow, "BridgeSocketHalo", Vector3.ZERO, 2.2, 3.2,
		_materials.gold, Vector3(90, 0, 0))
	_add_sphere(socket_glow, "BridgeSocketCore", Vector3.ZERO, Vector3.ONE * 1.55,
		_materials.arrival_glass)
	for packet_index in 10:
		var packet := _add_sphere(arrival, "BridgeEnergyPacket_%02d" % packet_index,
			Vector3(0, 3.7, 28), Vector3.ONE * 0.38, _materials.gold)
		packet.set_meta("path_start", Vector3(0, 3.7, 28))
		packet.set_meta("path_end", Vector3(0, 3.7, 73))
		packet.set_meta("packet_phase", float(packet_index) / 10.0)
		packet.set_meta("editable_component", true)

	var sigil := Node3D.new()
	sigil.name = "BearingSigilReward"
	sigil.position = Vector3(0, -2, 8)
	sigil.visible = false
	sigil.set_meta("preserve_authored_nodes", true)
	arrival.add_child(sigil)
	_add_torus(sigil, "BearingSigilHalo", Vector3.ZERO, 2.6, 3.5, _materials.gold,
		Vector3(90, 0, 0))
	for ray_index in 8:
		var ray := _add_box(sigil, "BearingSigilRay_%02d" % ray_index, Vector3.ZERO,
			Vector3(0.55, 0.28, 8.0), _materials.gold, false, TAU * float(ray_index) / 8.0)
		ray.set_meta("editable_component", true)
	_add_sphere(sigil, "BearingSigilCore", Vector3.ZERO, Vector3.ONE * 1.5, _materials.arrival_glass)
	var display := _add_label(arrival, "NOTICE • HOLD THE THOUGHT WITHOUT OBEYING IT",
		Vector3(0, 10.5, 34), Color("d9fff8"), 24)
	display.name = "CompassInstructionDisplay"


func _build_constellation_target_instrument(parent: Node3D) -> void:
	var instrument := Node3D.new()
	instrument.name = "ThoughtConstellationTarget"
	instrument.set_meta("preserve_authored_nodes", true)
	instrument.set_meta("purpose", "sanctum gateway and physical goal display for the linked-ring puzzle")
	instrument.set_meta("design_revision", "v31_science_art_harmony_sanctum")
	instrument.set_meta("clear_opening_width_m", 20.0)
	instrument.set_meta("reusable_component_families", 8)
	parent.add_child(instrument)
	# This is the entrance to the puzzle itself, not the gate to Island Two.  The
	# old full circular halo occupied the same silhouette as the thought, rings and
	# conservatory, so first-person views collapsed into overlapping gold lines.
	# A shallow, processional arch now frames the machine from z=30 while keeping
	# the central route and the thought core visibly separate.
	var gateway_z := 42.0
	var pier_x := 15.5
	for side in [-1.0, 1.0]:
		var frame_side := "West" if side < 0 else "East"
		var x: float = float(side) * pier_x
		# Six separately editable pieces make each pylon read as a supported
		# industrial assembly instead of a plain column.
		_add_brick(instrument, "SanctumFoundation_%s" % frame_side,
			Vector3(x, 3.3, gateway_z),
			Bricks.build_bevel_box(Vector3(6.0, 1.0, 6.8), 0.34), _materials.sanctum_ivory)
		_add_brick(instrument, "SanctumSteppedPlinth_%s" % frame_side,
			Vector3(x, 4.25, gateway_z),
			Bricks.build_bevel_box(Vector3(4.9, 0.9, 5.6), 0.28), _materials.sanctum_ivory)
		_add_tapered_cylinder(instrument, "SanctumFlutedPylon_%s" % frame_side,
			Vector3(x, 10.2, gateway_z), 1.55, 2.10, 10.8,
			_materials.sanctum_ivory, 24)
		_add_torus(instrument, "SanctumPylonFoot_%s" % frame_side,
			Vector3(x, 5.2, gateway_z), 1.75, 2.32,
			_materials.astral_brass, Vector3(90, 0, 0))
		# The former torus capital wrapped around the arch spring and produced a
		# heavy intersecting ring in first-person views. The crown pearl and stepped
		# beam now finish this joint without an overlapping circular silhouette.
		_add_box(instrument, "SanctumAetherChannel_%s" % frame_side,
			Vector3(x, 10.5, gateway_z - 2.0), Vector3(0.52, 7.2, 0.28),
			_materials.arrival_glass)
		# One enclosed governor per pylon communicates mechanical purpose without
		# filling the player's path with spokes and cables.
		_add_torus(instrument, "SanctumGovernorCase_%s" % frame_side,
			Vector3(x, 9.7, gateway_z - 2.35), 2.45, 3.15,
			_materials.astral_brass, Vector3(90, 0, 0))
		_add_sphere(instrument, "SanctumGovernorLens_%s" % frame_side,
			Vector3(x, 9.7, gateway_z - 2.48), Vector3(2.15, 2.15, 0.42),
			_materials.arrival_glass)
		for spoke_index in 6:
			var spoke_angle := TAU * float(spoke_index) / 6.0
			var spoke_finish := Vector3(x + sin(spoke_angle) * 2.05,
				9.7 + cos(spoke_angle) * 2.05, gateway_z - 2.78)
			_add_cable_between(instrument,
				"SanctumGovernorSpoke_%s_%02d" % [frame_side, spoke_index + 1],
				Vector3(x, 9.7, gateway_z - 2.78), spoke_finish,
				0.15, 0.10, _materials.gold, 6)
		_add_sphere(instrument, "SanctumGovernorHub_%s" % frame_side,
			Vector3(x, 9.7, gateway_z - 2.85), Vector3.ONE * 0.52, _materials.gold)
		# Repeated collars and a crowned aether pearl finish the pylon and expose
		# the mechanical load path from governor to the dial crown.
		for collar_index in 3:
			_add_torus(instrument, "SanctumPylonCollar_%s_%02d" % [frame_side, collar_index + 1],
				Vector3(x, 7.0 + float(collar_index) * 3.0, gateway_z), 1.52, 1.82,
				_materials.gold, Vector3(90, 0, 0))
		_add_sphere(instrument, "SanctumPylonCrownPearl_%s" % frame_side,
			Vector3(x, 16.6, gateway_z), Vector3(0.82, 1.15, 0.82),
			_materials.arrival_glass)
		_add_cable_between(instrument, "SanctumPistonLink_%s" % frame_side,
			Vector3(x, 9.7, gateway_z - 2.95),
			Vector3(side * 11.0, 17.0, gateway_z - 1.15),
			0.24, 0.16, _materials.astral_brass, 10)

	# Two nested segmented curves give the gateway a heavenly silhouette while
	# retaining a genuine 20 m x 14 m clear opening. Unlike the removed torus,
	# the arch stops cleanly at its capitals and does not cross the puzzle heart.
	var arch_segments := 20
	for segment_index in arch_segments:
		var angle_a := PI - PI * float(segment_index) / float(arch_segments)
		var angle_b := PI - PI * float(segment_index + 1) / float(arch_segments)
		var outer_a := Vector3(cos(angle_a) * pier_x,
			15.5 + sin(angle_a) * 11.5, gateway_z)
		var outer_b := Vector3(cos(angle_b) * pier_x,
			15.5 + sin(angle_b) * 11.5, gateway_z)
		_add_cable_between(instrument, "SanctumIvoryVoussoir_%02d" % (segment_index + 1),
			outer_a, outer_b, 0.78, 0.78, _materials.sanctum_ivory, 12)
		var light_a := Vector3(cos(angle_a) * 13.6,
			15.5 + sin(angle_a) * 9.9, gateway_z - 0.62)
		var light_b := Vector3(cos(angle_b) * 13.6,
			15.5 + sin(angle_b) * 9.9, gateway_z - 0.62)
		_add_cable_between(instrument, "SanctumAetherReveal_%02d" % (segment_index + 1),
			light_a, light_b, 0.20, 0.20, _materials.arrival_glass, 8)
		if segment_index % 2 == 0:
			_add_brick(instrument, "SanctumGiltKey_%02d" % (segment_index + 1),
				outer_a + Vector3(0, 0, -0.72),
				Bricks.build_bevel_box(Vector3(0.62, 0.82, 0.34), 0.08), _materials.gold)

	# The Wisdom Crown beam physically carries all three state instruments.
	_add_brick(instrument, "WisdomCrownMainBeam", Vector3(0, 18.9, gateway_z + 0.18),
		Bricks.build_bevel_box(Vector3(23.8, 1.45, 1.25), 0.30), _materials.sanctum_ivory)
	_add_box(instrument, "WisdomCrownUpperGiltOrder", Vector3(0, 19.72, gateway_z - 0.05),
		Vector3(24.8, 0.20, 1.48), _materials.gold)
	_add_box(instrument, "WisdomCrownLowerAetherOrder", Vector3(0, 18.08, gateway_z - 0.08),
		Vector3(22.8, 0.16, 1.44), _materials.arrival_glass)
	for boss_index in 7:
		_add_sphere(instrument, "WisdomCrownBoss_%02d" % (boss_index + 1),
			Vector3(-10.5 + float(boss_index) * 3.5, 19.74, gateway_z - 0.88),
			Vector3.ONE * (0.25 if boss_index != 3 else 0.38),
			_materials.gold if boss_index % 2 == 0 else _materials.arrival_glass)

	# Six triangular stained-aether panes form a restrained fanlight above the
	# console. The panes are independently editable and echo the glass roof.
	var fanlight_points := [
		Vector3(-12.0, 20.0, gateway_z + 0.52), Vector3(-8.0, 23.5, gateway_z + 0.52),
		Vector3(-4.0, 25.7, gateway_z + 0.52), Vector3(0, 26.6, gateway_z + 0.52),
		Vector3(4.0, 25.7, gateway_z + 0.52), Vector3(8.0, 23.5, gateway_z + 0.52),
		Vector3(12.0, 20.0, gateway_z + 0.52),
	]
	for pane_index in 6:
		_add_triangle_patch(instrument, "WisdomFanlightPane_%02d" % (pane_index + 1),
			Vector3(0, 20.0, gateway_z + 0.52), fanlight_points[pane_index],
			fanlight_points[pane_index + 1],
			_materials.arrival_glass if pane_index % 2 == 0 else _materials.sanctum_lavender_glass)
		_add_cable_between(instrument, "WisdomFanlightRib_%02d" % (pane_index + 1),
			Vector3(0, 20.0, gateway_z - 0.18),
			fanlight_points[pane_index + 1] - Vector3(0, 0, 0.70),
			0.12, 0.09, _materials.gold, 6)

	# A restrained star keystone is the sole crown ornament. Its vertical finial
	# marks the puzzle threshold without copying the inter-island gate's sunburst.
	_add_sphere(instrument, "SanctumWisdomKeystone",
		Vector3(0, 28.2, gateway_z - 0.45), Vector3(1.45, 1.85, 0.82),
		_materials.gold)
	for ray_index in 4:
		var ray_angle := TAU * float(ray_index) / 4.0
		_add_box(instrument, "SanctumWisdomRay_%02d" % (ray_index + 1),
			Vector3(sin(ray_angle) * 2.05, 28.2 + cos(ray_angle) * 2.05, gateway_z - 0.6),
			Vector3(0.28, 2.0, 0.26), _materials.astral_brass, false, -ray_angle)

	# The three animated puzzle states are grouped into a single crown console.
	# Their repeated bezel/needle/jewel assembly is reusable elsewhere, and the
	# spatial order matches the three concentric floor rings seen through the arch.
	var target_names := ["NOTICE", "UNDERSTAND", "CHOOSE"]
	var target_angles := [-PI * 0.25, 0.0, -PI * 1.25]
	for index in 3:
		var x := -7.0 + float(index) * 7.0
		# Positive Z faces the selector gallery where the player reads the goal.
		var socket_at := Vector3(x, 19.2, gateway_z + 0.65)
		var indicator_case := _add_cylinder(instrument,
			"SanctumIndicatorCase_%s" % target_names[index],
			socket_at + Vector3(0, 0, -0.28), 2.72, 0.52,
			_materials.sanctum_ivory, false, 24)
		indicator_case.rotation_degrees.x = 90.0
		var indicator_face := _add_cylinder(instrument,
			"SanctumIndicatorFace_%s" % target_names[index],
			socket_at + Vector3(0, 0, 0.18), 1.72, 0.18,
			_materials.green_glow, false, 24)
		indicator_face.rotation_degrees.x = 90.0
		_add_torus(instrument, "ConstellationSocket_%s" % target_names[index], socket_at,
			1.75, 2.48, _materials.sanctum_ivory, Vector3(90, 0, 0))
		_add_torus(instrument, "ConstellationGiltBezel_%s" % target_names[index],
			socket_at + Vector3(0, 0, 0.16), 1.95, 2.45, _materials.gold,
			Vector3(90, 0, 0))
		var pointer := Node3D.new()
		pointer.name = "ConstellationActual_%s" % target_names[index]
		pointer.position = socket_at + Vector3(0, 0, 0.42)
		instrument.add_child(pointer)
		_add_box(pointer, "ActualNeedle", Vector3(0, 0.88, 0),
			Vector3(0.30, 1.76, 0.24), _materials.green_glow)
		_add_sphere(pointer, "ActualJewel", Vector3(0, 1.82, 0),
			Vector3.ONE * 0.34, _materials.green_glow)
		var target := Node3D.new()
		target.name = "ConstellationTarget_%s" % target_names[index]
		target.position = socket_at + Vector3(0, 0, 0.50)
		target.rotation.z = target_angles[index]
		instrument.add_child(target)
		_add_box(target, "TargetRay", Vector3(0, 1.56, 0),
			Vector3(0.14, 0.94, 0.14), _materials.gold)
		for tick_index in 8:
			var tick_angle := TAU * float(tick_index) / 8.0
			var tick_at := socket_at + Vector3(sin(tick_angle) * 2.05,
				cos(tick_angle) * 2.05, 0.48)
			_add_box(instrument,
				"SanctumDialTick_%s_%02d" % [target_names[index], tick_index + 1],
				tick_at, Vector3(0.15 if tick_index % 3 else 0.23,
					0.62 if tick_index % 3 else 0.82, 0.12),
				_materials.gold if tick_index % 3 == 0 else _materials.arrival_glass,
				false, -tick_angle)
		_add_label(instrument, target_names[index],
			socket_at + Vector3(0, -3.65, -0.18), Color("ffe5a4"), 14)
	var harmony_display := _add_label(instrument,
		"SEEK A HARMONY\nLIGHT • RHYTHM • VISUAL WEIGHT",
		Vector3(0, 13.8, gateway_z - 0.9), Color("d9fff8"), 15)
	harmony_display.name = "HarmonyReadingDisplay"
	harmony_display.set_meta("teaching_role", "science of art and non-diagnostic psychology feedback")

	# One contained floor seam carries power under the threshold. It replaces the
	# former visual tangle of overhead braces and gives the player a clear line to
	# follow from the selectors into the central instrument.
	_add_box(instrument, "SanctumThresholdIvory",
		Vector3(0, 2.73, gateway_z), Vector3(20.0, 0.22, 5.2),
		_materials.sanctum_ivory)
	_add_brick(instrument, "SanctumThresholdFrontStep",
		Vector3(0, 2.58, gateway_z + 2.45),
		Bricks.build_bevel_box(Vector3(17.5, 0.28, 1.1), 0.12), _materials.sanctum_ivory)
	_add_brick(instrument, "SanctumThresholdInnerStep",
		Vector3(0, 2.64, gateway_z - 2.25),
		Bricks.build_bevel_box(Vector3(17.5, 0.34, 1.0), 0.12), _materials.sanctum_ivory)
	_add_box(instrument, "SanctumThresholdPowerSeam",
		Vector3(0, 2.87, gateway_z), Vector3(1.0, 0.12, 5.5),
		_materials.arrival_glass)
	_add_label(instrument, "THOUGHT SANCTUM  •  ALIGN THREE STATES",
		Vector3(0, 31.8, gateway_z), Color("fff1bf"), 18)


func _build_thought_witness(parent: Node3D) -> void:
	# The machine now has a visible emotional subject. It holds an authored
	# fictional thought above the Compass so the player is examining something,
	# not solving disconnected dials. The warm transformed aura appears only
	# after the player has noticed, understood and chosen a grounded response.
	var witness := Node3D.new()
	witness.name = "AuthoredThoughtWitness"
	witness.set_meta("preserve_authored_nodes", true)
	witness.set_meta("privacy", "curated offline text; no personal disclosure")
	parent.add_child(witness)
	_add_sphere(witness, "LavenderThoughtCloud", Vector3(0, 10.2, 8),
		Vector3(6.2, 3.4, 3.6), _materials.astral_lavender)
	_add_torus(witness, "AwarenessOrbit", Vector3(0, 10.2, 8), 6.8, 7.25,
		_materials.astral_brass, Vector3(90, 0, 0))
	_add_torus(witness, "AwarenessInnerOrbit", Vector3(0, 10.2, 8), 5.6, 5.92,
		_materials.arrival_glass, Vector3(90, 0, 0))
	for petal_index in 12:
		var petal_angle := TAU * float(petal_index) / 12.0
		var petal_start := Vector3(sin(petal_angle) * 6.1, 10.2,
			8 + cos(petal_angle) * 6.1)
		var petal_end := Vector3(sin(petal_angle) * 7.8, 10.2,
			8 + cos(petal_angle) * 7.8)
		_add_cable_between(witness, "AwarenessPetal_%02d" % (petal_index + 1),
			petal_start, petal_end, 0.20, 0.13,
			_materials.gold if petal_index % 2 == 0 else _materials.arrival_glass, 8)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var mote_at := Vector3(sin(angle) * 8.2, 10.2 + sin(angle * 2.0) * 1.2,
			8 + cos(angle) * 8.2)
		_add_sphere(witness, "ThoughtSignalMote_%02d" % (index + 1), mote_at,
			Vector3.ONE * (0.44 if index % 2 == 0 else 0.30), _materials.violet)
	var thought := _add_label(witness, "A THOUGHT IS VISITING\n“What if I get it wrong?”",
		Vector3(0, 16.2, 8), Color("f4e4ff"), 30)
	thought.name = "AuthoredThoughtText"
	var journey := _add_label(witness, "UNREAD  →  UNNAMED  →  UNSET",
		Vector3(0, 5.7, 8), Color("9fe8e3"), 19)
	journey.name = "ThoughtJourneyDisplay"
	var transformed := Node3D.new()
	transformed.name = "TransformedThoughtGlow"
	transformed.visible = false
	witness.add_child(transformed)
	_add_torus(transformed, "IntegratedWisdomHalo", Vector3(0, 10.2, 8), 8.0, 9.2,
		_materials.gold, Vector3(90, 0, 0))
	for ray_index in 8:
		var ray_angle := TAU * float(ray_index) / 8.0
		var ray_start := Vector3(sin(ray_angle) * 9.5, 10.2, 8 + cos(ray_angle) * 9.5)
		var ray_end := Vector3(sin(ray_angle) * 13.0, 10.2, 8 + cos(ray_angle) * 13.0)
		_add_cable_between(transformed, "WisdomRay_%02d" % (ray_index + 1),
			ray_start, ray_end, 0.34, 0.18, _materials.gold, 8)


func _build_compass_ring(parent: Node3D, ring_name: String, inner_radius: float,
		outer_radius: float, segment_count: int, layer: int) -> void:
	var ring := Node3D.new()
	ring.name = ring_name
	ring.set_meta("preserve_authored_nodes", true)
	parent.add_child(ring)
	_add_torus(ring, "%sBody" % ring_name, Vector3(0, 2.30 + layer * 0.12, 8),
		inner_radius, outer_radius, _materials.celestial_floor)
	_add_torus(ring, "%sInnerChampagneOrder" % ring_name,
		Vector3(0, 2.48 + layer * 0.12, 8), inner_radius - 0.20, inner_radius + 0.18,
		_materials.gold)
	_add_torus(ring, "%sOuterChampagneOrder" % ring_name,
		Vector3(0, 2.48 + layer * 0.12, 8), outer_radius - 0.20, outer_radius + 0.18,
		_materials.astral_brass)
	var marker_radius := (inner_radius + outer_radius) * 0.5
	for segment_index in segment_count:
		var angle := TAU * float(segment_index) / float(segment_count)
		var is_cardinal := segment_index % maxi(1, segment_count / 4) == 0
		var marker_at := Vector3(sin(angle) * marker_radius, 2.72 + layer * 0.12,
			8 + cos(angle) * marker_radius)
		var marker := _add_box(ring, "%sRune_%02d" % [ring_name, segment_index + 1], marker_at,
			Vector3(0.48 if not is_cardinal else 1.15, 0.34, 1.55 if not is_cardinal else 2.6),
			_materials.arrival_glass, false, angle)
		marker.set_meta("editable_component", true)
		if segment_index % 3 == 0:
			_add_sphere(ring, "%sWisdomPearl_%02d" % [ring_name, segment_index + 1],
				marker_at + Vector3.UP * 0.34, Vector3.ONE * 0.22,
				_materials.gold if segment_index % 2 == 0 else _materials.arrival_glass)
		if segment_index % 2 == 0:
			var tooth_at := Vector3(sin(angle) * outer_radius, 2.16 + layer * 0.12,
				8 + cos(angle) * outer_radius)
			var tooth := _add_box(ring, "%sTooth_%02d" % [ring_name, segment_index + 1], tooth_at,
				Vector3(0.62, 0.52, 1.12), _materials.celestial_floor, false, angle)
			tooth.set_meta("editable_component", true)


func _build_compass_control(parent: Node3D, control_id: String, at: Vector3,
		title: String, _control_kind: int) -> void:
	_build_heavenly_quest_instrument(parent, control_id, at, title)

func _build_light_prism_control(parent: Node3D, control_id: String, at: Vector3,
		title: String) -> void:
	if control_id == "weight_prism":
		_build_weight_benchmark(parent, at, title)
	else:
		_build_heavenly_quest_instrument(parent, control_id, at, title)

func _build_heavenly_quest_instrument(parent: Node3D, control_id: String,
		at: Vector3, title: String) -> void:
	var control := Node3D.new()
	control.name = "PuzzleControl_%s" % control_id
	control.position = at
	control.set_meta("control_id", control_id)
	control.set_meta("purpose", title)
	control.set_meta("preserve_authored_nodes", true)
	control.set_meta("production_visual", true)
	control.set_meta("design_revision", "heavenly_kit_02")
	parent.add_child(control)
	var path := "res://assets3D/mind_spark/quest_kit/%s/export/%s.glb" % [control_id, control_id]
	var model := (load(path) as PackedScene).instantiate() as Node3D
	model.name = "HeavenlyQuestInstrument"
	model.set_script(load("res://scripts/mind_spark/heavenly_quest_instrument.gd"))
	model.set("control_id", control_id)
	# Face the established west-side instrument approach; no station is relocated.
	model.rotation.y = -PI / 2.0
	control.add_child(model)
	if control_id.begins_with("echo_signal_") or control_id == "analysis_console":
		var headings := ["FACT", "POSSIBILITY", "UNSURE"] if control_id.begins_with("echo_signal_") else ["THOUGHT", "FEELING", "CHOICE"]
		for i in 3:
			var card := model.find_child("Card%d" % i, true, false) as Node3D
			var heading := Label3D.new()
			heading.name = "CardMeaning"
			heading.text = headings[i]
			heading.font_size = 22
			heading.pixel_size = .003
			heading.position = Vector3(0, .30, .11)
			heading.modulate = Color("fff2d9")
			card.add_child(heading)
	var identity := Node3D.new()
	identity.name = "QuestIdentityCrown"
	identity.set_meta("graphic_role", _quest_control_role(control_id))
	identity.set_meta("control_id", control_id)
	identity.set_meta("design_revision", "heavenly_kit_02")
	identity.set_meta("preserve_authored_nodes", true)
	control.add_child(identity)
	var lens := model.find_child("StateLens", true, false) as MeshInstance3D
	assert(lens != null, "Quest kit export requires its state lens: " + control_id)
	lens.reparent(identity, true)
	lens.name = "QuestStateCore"
	lens.set_meta("authored_scale", lens.scale)
	lens.set_meta("feedback_states", ["inactive", "current", "complete", "powered"])
	var label := _add_label(control, title, Vector3(-1.55, 1.65, 0), Color("fff2d9"), 24)
	label.name = "QuestPurposeLabel"
	label.pixel_size = 0.0045
	label.set_meta("interaction_verb", "OBSERVE • OPERATE")
	var body := StaticBody3D.new()
	body.name = "InstrumentPlinthCollision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.65, 1.95, 5.4 if control_id in ["analysis_console", "echo_question"] else 4.4)
	shape.shape = box
	shape.position.y = 0.975
	body.add_child(shape)
	control.add_child(body)
	var anchor := Marker3D.new()
	anchor.name = "InspectionAnchor"
	anchor.position = Vector3(-8, 3.2, 0)
	control.add_child(anchor)
	if control_id.ends_with("_prism"):
		_attach_quest_output(control, -1.0)


func _attach_quest_output(control: Node3D, direction: float) -> void:
	var port := _add_cylinder(control, "OutputPort", Vector3(direction * 1.12, .72, 0),
		.20, .34, _materials.astral_brass, false, 12)
	port.rotation.z = PI / 2.0
	var anchor := Marker3D.new()
	anchor.name = "EnergyOutputAnchor"
	anchor.position = Vector3(direction * 1.30, .72, 0)
	control.add_child(anchor)


func _build_weight_benchmark(parent: Node3D, at: Vector3, title: String) -> void:
	var control := Node3D.new()
	control.name = "PuzzleControl_weight_prism"
	control.position = at
	control.set_meta("preserve_authored_nodes", true)
	control.set_meta("control_id", "weight_prism")
	control.set_meta("purpose", "route one unique light seed through visual weight")
	control.set_meta("interaction_model", "walk, observe, rotate, compare live beam")
	control.set_meta("design_revision", "weight_benchmark_01")
	parent.add_child(control)
	var packed := load("res://assets3D/mind_spark/quest_kit/weight_prism/export/weight_prism.glb") as PackedScene
	var model := packed.instantiate() as Node3D
	model.name = "WeightPrismBenchmark"
	model.set_script(load("res://scripts/mind_spark/weight_prism_benchmark.gd"))
	# Blender's -Y front exports as Godot +Z. Face the western approach aisle.
	model.rotation.y = -PI / 2.0
	control.add_child(model)
	var identity := Node3D.new()
	identity.name = "QuestIdentityCrown"
	identity.set_meta("graphic_role", _quest_control_role("weight_prism"))
	identity.set_meta("control_id", "weight_prism")
	identity.set_meta("design_revision", "weight_benchmark_01")
	identity.set_meta("preserve_authored_nodes", true)
	control.add_child(identity)
	var lens := model.find_child("StateLens", true, false) as MeshInstance3D
	if lens != null:
		lens.reparent(identity, true)
		lens.name = "QuestStateCore"
		lens.set_meta("authored_scale", lens.scale)
		lens.set_meta("feedback_states", ["inactive", "current", "complete", "powered"])
	var label := _add_label(control, "%s\nROTATE • BALANCE" % title,
		Vector3(-1.35, 1.28, 0), Color("fff2d9"), 24)
	label.name = "QuestPurposeLabel"
	label.pixel_size = 0.005
	label.set_meta("interaction_verb", "ROTATE • BALANCE")
	# A simple plinth collider keeps physical collision independent of art.
	var body := StaticBody3D.new()
	body.name = "WeightPlinthCollision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.65, 2.1, 5.8)
	shape.shape = box
	shape.position.y = 1.05
	body.add_child(shape)
	control.add_child(body)
	var camera_anchor := Marker3D.new()
	camera_anchor.name = "InspectionAnchor"
	camera_anchor.position = Vector3(-9, 3.2, 0)
	control.add_child(camera_anchor)
	_attach_quest_output(control, 1.0)


func _build_quest_control_identity(control: Node3D, control_id: String, title: String) -> void:
	# The production pedestals deliberately share one mechanical language. This
	# crown gives every quest object a different, readable silhouette, while the
	# shared frame, action plaque and state jewel remain reusable across quests.
	var cluster_center := Vector3(-52, control.position.y, 24) if control.position.x < -30.0 \
		else Vector3(0, control.position.y, 20)
	var outward := Vector3(control.position.x - cluster_center.x, 0,
		control.position.z - cluster_center.z).normalized()
	if outward.length_squared() < 0.1:
		outward = Vector3(0, 0, -1)
	var crown := Node3D.new()
	crown.name = "QuestIdentityCrown"
	# The send console occupies the middle dial's former approach ray.
	# Face this instrument into the open western aisle instead.
	if control_id == "middle_ring":
		outward = Vector3.LEFT
	# Mount the emblem on the player-facing shoulder of the machine. The old
	# centre placement was frequently hidden behind the tall production rotor.
	crown.position = outward * 3.15 + Vector3.UP * 6.65
	crown.set_meta("control_id", control_id)
	crown.set_meta("graphic_role", _quest_control_role(control_id))
	crown.set_meta("reusable_component_family", "heavenly quest identity crown")
	crown.set_meta("design_revision", "v41_textured_low_poly_final")
	crown.set_meta("material_system", "procedural albedo + roughness + normal")
	crown.set_meta("final_art_asset", true)
	crown.set_meta("preserve_authored_nodes", true)
	control.add_child(crown)
	# `look_at()` expects a global target; the controls are authored under a
	# translated puzzle root. A local looking basis keeps every badge facing its
	# matching approach path instead of randomly exposing its blank back plate.
	crown.basis = Basis.looking_at(outward, Vector3.UP)
	var ivory: Material = _materials.quest_ivory
	var ivory_inset: Material = _materials.quest_ivory_inset
	var brass: Material = _materials.quest_brass
	var gold: Material = _materials.quest_gold_leaf
	var teal: Material = _materials.quest_teal_enamel
	var lavender: Material = _materials.quest_lavender_enamel
	# Five readable depth layers replace the old single disc. Twelve radial sides
	# give a deliberate low-poly silhouette; the inset, bezel and clamps catch
	# warm light separately and make the construction believable from first person.
	_add_cylinder(crown, "QuestIdentityRearHousing", Vector3(0, 0, 0.18), 1.82, 0.24,
		brass, false, 12).rotation_degrees.x = 90.0
	_add_cylinder(crown, "QuestIdentityIvoryMedallion", Vector3(0, 0, 0), 1.68, 0.34,
		ivory, false, 12).rotation_degrees.x = 90.0
	_add_cylinder(crown, "QuestIdentityRecessedFace", Vector3(0, 0, -0.25), 1.38, 0.10,
		ivory_inset, false, 12).rotation_degrees.x = 90.0
	_add_torus(crown, "QuestIdentityGiltBezel", Vector3(0, 0, -0.22), 1.42, 1.72,
		brass, Vector3(90, 0, 0))
	var state_core := _add_sphere(crown, "QuestStateCore", Vector3(0, 0, -0.42),
		Vector3(0.24, 0.24, 0.10), ivory)
	state_core.set_meta("feedback_states", ["inactive", "current", "complete", "powered"])
	state_core.set_meta("authored_scale", state_core.scale)
	for clamp_index in 8:
		var clamp_angle := TAU * float(clamp_index) / 8.0
		var clamp := _add_box(crown, "QuestHousingClamp_%02d" % (clamp_index + 1),
			Vector3(sin(clamp_angle) * 1.72, cos(clamp_angle) * 1.72, -0.30),
			Vector3(0.18, 0.42, 0.18), brass)
		clamp.rotation.z = -clamp_angle
		_add_cylinder(crown, "QuestHousingRivet_%02d" % (clamp_index + 1),
			Vector3(sin(clamp_angle) * 1.72, cos(clamp_angle) * 1.72, -0.42),
			0.085, 0.08, gold, false, 8).rotation_degrees.x = 90.0
	# Paired aether crystals are a shared quality signature and provide a clear
	# top/bottom orientation even when the icon itself is rotationally symmetric.
	_add_brick(crown, "QuestAetherFinialTop", Vector3(0, 2.08, -0.20),
		Bricks.build_crystal(0.18, 0.64, 0.08, 6), teal)
	var lower_finial := _add_brick(crown, "QuestAetherFinialBottom", Vector3(0, -2.08, -0.20),
		Bricks.build_crystal(0.18, 0.64, 0.08, 6), lavender)
	lower_finial.rotation.z = PI

	match control_id:
		"colour_prism":
			# Three dichroic jewels arranged as a colour-mixing triangle.
			var colours := [teal, lavender, gold]
			for index in 3:
				var angle := TAU * float(index) / 3.0
				_add_sphere(crown, "ColourSpectrumJewel_%02d" % (index + 1),
					Vector3(sin(angle) * 0.92, cos(angle) * 0.92, -0.56),
					Vector3(0.34, 0.34, 0.16), colours[index])
				_add_cable_between(crown, "ColourMixingEdge_%02d" % (index + 1),
					Vector3(sin(angle) * 0.92, cos(angle) * 0.92, -0.48),
					Vector3(sin(angle + TAU / 3.0) * 0.92,
						cos(angle + TAU / 3.0) * 0.92, -0.48),
					0.07, 0.07, gold, 6)
		"rhythm_prism":
			# A rising 3:4:5 rhythm can be read without relying on the title.
			for index in 3:
				var bar_height := 0.68 + float(index) * 0.34
				_add_box(crown, "RhythmMeasure_%02d" % (index + 1),
					Vector3(-0.78 + float(index) * 0.78, -0.28 + bar_height * 0.5, -0.54),
					Vector3(0.24, bar_height, 0.18),
					teal if index != 1 else gold)
			for beat_index in 5:
				_add_sphere(crown, "RhythmBeat_%02d" % (beat_index + 1),
					Vector3(-1.0 + float(beat_index) * 0.5, -1.06, -0.54),
					Vector3.ONE * (0.13 if beat_index % 2 else 0.20), brass)
		"weight_prism":
			# A literal balance reads immediately as visual-weight experimentation.
			_add_cable_between(crown, "WeightBalanceBeam", Vector3(-1.12, 0.38, -0.52),
				Vector3(1.12, -0.12, -0.52), 0.10, 0.10, brass, 8)
			_add_triangle_patch(crown, "WeightFulcrum",
				Vector3(-0.42, -0.92, -0.50), Vector3(0.42, -0.92, -0.50),
				Vector3(0, 0.25, -0.50), ivory)
			_add_sphere(crown, "WeightLightMass", Vector3(-1.06, 0.08, -0.54),
				Vector3.ONE * 0.28, teal)
			_add_sphere(crown, "WeightHeavyMass", Vector3(1.02, -0.55, -0.54),
				Vector3.ONE * 0.46, gold)
		"analysis_console":
			_add_torus(crown, "AnalysisLens", Vector3(0, 0.12, -0.48), 0.62, 0.88,
				teal, Vector3(90, 0, 0))
			for index in 3:
				var angle := TAU * float(index) / 3.0
				_add_sphere(crown, "AnalysisEvidence_%02d" % (index + 1),
					Vector3(sin(angle) * 1.18, cos(angle) * 1.18, -0.54),
					Vector3.ONE * 0.22,
					[teal, lavender, gold][index])
		"west_regulator", "east_regulator":
			# Paired pressure chambers identify these as balancing controls.
			for side in [-1.0, 1.0]:
				_add_cylinder(crown, "PressureChamber_%s" % ("L" if side < 0 else "R"),
					Vector3(side * 0.62, -0.08, -0.54), 0.30, 1.55,
					teal if side < 0 else gold, false, 12)
				_add_torus(crown, "PressureCollar_%s" % ("L" if side < 0 else "R"),
					Vector3(side * 0.62, 0.50, -0.54), 0.28, 0.39,
					brass)
			_add_cable_between(crown, "PressureEqualizer",
				Vector3(-0.62, 0.72, -0.52), Vector3(0.62, 0.72, -0.52),
				0.10, 0.10, brass, 8)
		"outer_ring", "middle_ring", "inner_ring":
			var selected_ring := ["outer_ring", "middle_ring", "inner_ring"].find(control_id)
			for index in 3:
				var radius := 1.14 - float(index) * 0.34
				_add_torus(crown, "OrbitGraphic_%02d" % (index + 1), Vector3(0, 0, -0.56 - index * 0.04),
					radius, radius + (0.16 if index == selected_ring else 0.09),
					gold if index == selected_ring else teal,
					Vector3(90, 0, 0))
				_add_box(crown, "OrbitIndex_%02d" % (index + 1),
					Vector3(0, radius, -0.80), Vector3(0.16, 0.24, 0.12), gold)
		"confirm":
			# A vertical launch key communicates that this sends the composed signal.
			_add_triangle_patch(crown, "SendForwardArrowHead",
				Vector3(-0.72, 0.08, -0.52), Vector3(0.72, 0.08, -0.52),
				Vector3(0, 1.18, -0.52), gold)
			_add_box(crown, "SendForwardStem", Vector3(0, -0.54, -0.52),
				Vector3(0.30, 1.25, 0.18), teal)
		"echo_collector":
			# Three descending resonance orbs feed one receiving cup.
			for index in 3:
				_add_sphere(crown, "CollectorEcho_%02d" % (index + 1),
					Vector3(-0.72 + float(index) * 0.72, 0.62, -0.54),
					Vector3.ONE * (0.24 + float(index) * 0.05),
					[teal, lavender, gold][index])
			_add_triangle_patch(crown, "CollectorFunnel",
				Vector3(-1.05, 0.06, -0.50), Vector3(1.05, 0.06, -0.50),
				Vector3(0, -1.08, -0.50), ivory)
		"echo_signal_1", "echo_signal_2", "echo_signal_3":
			var echo_count := int(control_id.right(1))
			for index in echo_count:
				var y := -0.54 + float(index) * 0.54
				_add_torus(crown, "EchoWave_%02d" % (index + 1),
					Vector3(0, y, -0.52), 0.48 + float(index) * 0.12,
					0.62 + float(index) * 0.12,
					[teal, lavender, gold][index], Vector3(90, 0, 0))
			for category_index in 3:
				_add_sphere(crown, "EchoCategoryKey_%02d" % (category_index + 1),
					Vector3(-0.68 + float(category_index) * 0.68, -1.16, -0.54),
					Vector3.ONE * 0.18,
					[gold, lavender, teal][category_index])
		"echo_question":
			# Four framed cards identify a choice of perspectives; each sits in a
			# physical socket with an engraved line and a numbered tab.
			for index in 4:
				var finish := Vector3(-0.52 + (index % 2) * 1.04, 0.60 - int(index / 2) * 1.20, -0.52)
				_add_box(crown, "QuestionSocket_%02d" % index, finish,
					Vector3(0.92, 1.08, 0.18), brass)
				_add_box(crown, "QuestionChoice_%02d" % (index + 1), finish + Vector3(0, 0, -0.12),
					Vector3(0.76, 0.92, 0.12), teal if index == 2 else ivory)
				for line_index in 3:
					_add_box(crown, "CardEngraving_%d_%d" % [index, line_index],
						finish + Vector3(0, 0.20 - line_index * 0.20, -0.20),
						Vector3(0.48 - line_index * 0.08, 0.035, 0.025), brass)
		"echo_beacon":
			_add_brick(crown, "BeaconWisdomCrystal", Vector3(0, 0, -0.52),
				Bricks.build_crystal(0.50, 1.85, 0.20, 8), teal)
			for index in 8:
				var angle := TAU * float(index) / 8.0
				_add_cable_between(crown, "BeaconRay_%02d" % (index + 1),
					Vector3(sin(angle) * 0.72, cos(angle) * 0.72, -0.50),
					Vector3(sin(angle) * 1.28, cos(angle) * 1.28, -0.50),
					0.07, 0.04, gold, 6)

	var verb := _quest_control_verb(control_id)
	var purpose_label := _add_label(control, "%s\n%s" % [title, verb],
		crown.position + Vector3.UP * 3.3, Color("fff2c0"), 28)
	purpose_label.pixel_size = 0.008
	purpose_label.name = "QuestPurposeLabel"
	purpose_label.set_meta("interaction_verb", verb)
	_finish_quest_instrument(crown, control_id)


func _finish_quest_instrument(crown: Node3D, control_id: String) -> void:
	# Put one-sided reliefs on both faces, with depth, so they survive the
	# reversed viewing direction of controls on opposite sides of the court.
	for child in crown.get_children():
		if child is MeshInstance3D:
			var mesh_instance := child as MeshInstance3D
			if mesh_instance.material_override is StandardMaterial3D:
				var finish := mesh_instance.material_override.duplicate() as StandardMaterial3D
				finish.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh_instance.material_override = finish
			if mesh_instance.mesh is SphereMesh:
				var sphere := mesh_instance.mesh.duplicate() as SphereMesh
				sphere.radial_segments = 12
				sphere.rings = 6
				mesh_instance.mesh = sphere
	# Clearly supported housing and accessible grip, shared across the kit.
	for side in [-1.0, 1.0]:
		_add_box(crown, "MountFoot_%s" % side, Vector3(side * 1.20, -2.30, 0.08),
			Vector3(0.38, 1.08, 0.48), _materials.quest_ivory)
		_add_box(crown, "MountInlay_%s" % side, Vector3(side * 1.20, -2.30, -0.18),
			Vector3(0.09, 0.82, 0.06), _materials.quest_brass)
	if control_id in ["west_regulator", "east_regulator"]:
		var sign_value := 1.0 if control_id == "west_regulator" else -1.0
		_add_box(crown, "PressureDirection", Vector3(0, sign_value * 1.02, -0.72),
			Vector3(0.20, 0.36, 0.14), _materials.quest_teal_enamel)
		var arrow := _add_brick(crown, "PressureFlowArrow", Vector3(0, sign_value * 1.22, -0.72),
			Bricks.build_crystal(0.18, 0.36, 0.05, 4), _materials.quest_gold_leaf)
		arrow.rotation.z = 0.0 if sign_value > 0 else PI
	if control_id == "echo_collector":
		for index in 3:
			_add_cable_between(crown, "CollectorConduit_%d" % index,
				Vector3(-0.72 + index * 0.72, 0.48, -0.72), Vector3(0, -0.85, -0.72),
				0.04, 0.04, _materials.quest_gold_leaf, 6)
		_add_box(crown, "CollectorReservoir", Vector3(0, -1.06, -0.72),
			Vector3(0.54, 0.26, 0.24), _materials.quest_teal_enamel)


func _quest_control_role(control_id: String) -> String:
	var roles := {
		"colour_prism": "mix colour relationships", "rhythm_prism": "measure visual rhythm",
		"weight_prism": "balance visual weight", "analysis_console": "compare gathered evidence",
		"west_regulator": "notice pressure", "east_regulator": "make space",
		"outer_ring": "align notice", "middle_ring": "align understanding",
		"inner_ring": "align choice", "confirm": "send the composed signal",
		"echo_collector": "collect three thought echoes", "echo_signal_1": "classify certainty",
		"echo_signal_2": "classify possibility", "echo_signal_3": "classify the unknown",
		"echo_question": "choose a protective question", "echo_beacon": "verify and broadcast hope",
	}
	return str(roles.get(control_id, "quest interaction"))


func _quest_control_verb(control_id: String) -> String:
	var verbs := {
		"colour_prism": "ROTATE • MIX", "rhythm_prism": "ROTATE • COUNT",
		"weight_prism": "ROTATE • BALANCE", "analysis_console": "COMPARE • ANALYSE",
		"west_regulator": "TURN • NOTICE", "east_regulator": "TURN • RELEASE",
		"outer_ring": "ALIGN • NOTICE", "middle_ring": "ALIGN • UNDERSTAND",
		"inner_ring": "ALIGN • CHOOSE", "confirm": "PRESS • SEND",
		"echo_collector": "CHARGE ×3 • LISTEN", "echo_signal_1": "SORT • CERTAINTY",
		"echo_signal_2": "SORT • POSSIBILITY", "echo_signal_3": "SORT • UNKNOWN",
		"echo_question": "TURN • REFRAME", "echo_beacon": "PRESS • VERIFY",
	}
	return str(verbs.get(control_id, "INTERACT"))


func _build_prism_science_instrument(parent: Node3D, station_kind: String) -> void:
	var assembly := Node3D.new()
	assembly.name = "%sScienceInstrument" % station_kind.capitalize()
	assembly.position = Vector3(0, 3.0, -2.55)
	parent.add_child(assembly)
	if station_kind == "colour":
		# Three dichroic sample lenses demonstrate complementary light mixing.
		var samples := [_materials.arrival_glass, _materials.sanctum_lavender_glass, _materials.gold]
		for sample_index in 3:
			var sample_x := -0.82 + float(sample_index) * 0.82
			_add_cylinder(assembly, "DichroicSample_%02d" % (sample_index + 1),
				Vector3(sample_x, 0, 0), 0.34, 0.14, samples[sample_index], false, 16) \
				.rotation_degrees.x = 90.0
			_add_torus(assembly, "DichroicSampleBezel_%02d" % (sample_index + 1),
				Vector3(sample_x, 0, -0.10), 0.34, 0.46, _materials.astral_brass,
				Vector3(90, 0, 0))
	elif station_kind == "rhythm":
		# A 3:4:5 gear progression makes visual rhythm a countable mechanism.
		for gear_index in 3:
			var tooth_count := 3 + gear_index
			var gear_x := -0.95 + float(gear_index) * 0.95
			_add_torus(assembly, "RhythmGear_%02d" % (gear_index + 1),
				Vector3(gear_x, 0, 0), 0.42 + gear_index * 0.08,
				0.60 + gear_index * 0.08, _materials.astral_brass, Vector3(90, 0, 0))
			for tooth_index in tooth_count:
				var tooth_angle := TAU * float(tooth_index) / float(tooth_count)
				_add_box(assembly, "RhythmMark_%02d_%02d" % [gear_index + 1, tooth_index + 1],
					Vector3(gear_x + sin(tooth_angle) * (0.67 + gear_index * 0.08),
						cos(tooth_angle) * (0.67 + gear_index * 0.08), -0.10),
					Vector3(0.11, 0.24, 0.12), _materials.arrival_glass, false, -tooth_angle)
	else:
		# A beam balance exposes the visual-weight principle as physical leverage.
		_add_cable_between(assembly, "BalanceBeam", Vector3(-1.55, 0.20, 0),
			Vector3(1.55, -0.20, 0), 0.12, 0.12, _materials.astral_brass, 8)
		_add_tapered_cylinder(assembly, "BalanceFulcrum", Vector3(0, -0.45, 0),
			0.12, 0.48, 1.05, _materials.sanctum_ivory, 12)
		_add_sphere(assembly, "SmallCounterweight", Vector3(-1.42, -0.05, 0),
			Vector3.ONE * 0.34, _materials.arrival_glass)
		_add_sphere(assembly, "LargeCounterweight", Vector3(1.36, -0.42, 0),
			Vector3.ONE * 0.52, _materials.gold)


func _build_living_light_routes(parent: Node3D) -> void:
	var routes := Node3D.new()
	routes.name = "LivingLightLaboratoryRoutes"
	routes.set_meta("preserve_authored_nodes", true)
	routes.set_meta("valid_compositions", 3)
	routes.set_meta("beam_feedback", "continuous physical cause-and-effect")
	parent.add_child(routes)
	var prism_names := ["colour", "rhythm", "weight"]
	var starts: Array[Vector3] = []
	for prism_name in prism_names:
		var source := parent.get_node("PuzzleControls/PuzzleControl_%s_prism/EnergyOutputAnchor" % prism_name) as Node3D
		starts.append(parent.to_local(source.global_position))
	var receivers := [Vector3(-52.0, 39.0, 24.0), Vector3(0, 20.0, 42.0),
		Vector3(0, 7.0, 8.0)]
	var seed_materials := [_materials.arrival_glass, _materials.sanctum_lavender_glass,
		_materials.gold]
	for prism_index in 3:
		for seed_index in 3:
			var beam_start: Vector3 = starts[prism_index]
			var beam_finish: Vector3 = receivers[seed_index]
			# Every route enters the shared root-light well before the Wisdom Tree
			# interprets it. Keeping this relay low preserves the sacred tree silhouette
			# and gives every experiment a physically legible source and destination.
			var midpoint := Vector3(-52.0 + float(prism_index - 1) * 0.32,
				4.0 + float(seed_index) * 0.16, 24.0)
			var beam_a := _add_cable_between(routes,
				"LightBeam_%s_%d_A" % [prism_names[prism_index], seed_index],
				beam_start, midpoint, 0.15, 0.10, seed_materials[seed_index], 8)
			var beam_b := _add_cable_between(routes,
				"LightBeam_%s_%d_B" % [prism_names[prism_index], seed_index],
				midpoint, beam_finish, 0.10, 0.17, seed_materials[seed_index], 8)
			beam_a.visible = false
			beam_b.visible = false
			var pulse_a := _add_sphere(routes,
				"LightBeamPulse_%s_%d_A" % [prism_names[prism_index], seed_index],
				beam_start, Vector3.ONE * 0.30, seed_materials[seed_index])
			pulse_a.visible = false
			pulse_a.set_meta("source_prism", prism_names[prism_index])
			pulse_a.set_meta("seed_index", seed_index)
			pulse_a.set_meta("path_start", beam_start)
			pulse_a.set_meta("path_end", midpoint)
			pulse_a.set_meta("pulse_offset", float(prism_index) * 0.19)
			var pulse_b := _add_sphere(routes,
				"LightBeamPulse_%s_%d_B" % [prism_names[prism_index], seed_index],
				midpoint, Vector3.ONE * 0.30, seed_materials[seed_index])
			pulse_b.visible = false
			pulse_b.set_meta("source_prism", prism_names[prism_index])
			pulse_b.set_meta("seed_index", seed_index)
			pulse_b.set_meta("path_start", midpoint)
			pulse_b.set_meta("path_end", beam_finish)
			pulse_b.set_meta("pulse_offset", 0.5 + float(prism_index) * 0.19)
	for receiver_index in 3:
		var receiver_name: String = ["ThoughtTreeReceiver", "FeelingConstellationReceiver",
			"ChoiceCompassReceiver"][receiver_index]
		var receiver := Node3D.new()
		receiver.name = receiver_name
		receiver.position = receivers[receiver_index]
		routes.add_child(receiver)
		_add_cylinder(receiver, "ReceiverIvoryBackplate", Vector3(0, 0, 0),
			1.46, 0.34, _materials.sanctum_ivory, false, 24)
		_add_torus(receiver, "ReceiverAetherBezel", Vector3(0, 0.22, 0),
			0.95, 1.34, seed_materials[receiver_index])
		_add_sphere(receiver, "ReceiverLens", Vector3(0, 0.45, 0),
			Vector3(0.76, 0.34, 0.76), seed_materials[receiver_index])
		for clamp_index in 8:
			var clamp_angle := TAU * float(clamp_index) / 8.0
			_add_box(receiver, "ReceiverClamp_%02d" % (clamp_index + 1),
				Vector3(sin(clamp_angle) * 1.38, 0.38, cos(clamp_angle) * 1.38),
				Vector3(0.18, 0.32, 0.48), _materials.astral_brass, false, clamp_angle)
	var ready_halo := Node3D.new()
	ready_halo.name = "LivingLightCompositionReadyHalo"
	ready_halo.position = Vector3(-52.0, 4.0, 24.0)
	ready_halo.visible = false
	routes.add_child(ready_halo)
	for halo_index in 3:
		_add_torus(ready_halo, "CompositionOrbit_%02d" % (halo_index + 1), Vector3.ZERO,
			2.8 + halo_index * 0.75, 3.05 + halo_index * 0.75,
			seed_materials[halo_index], Vector3(90 - halo_index * 24, halo_index * 31, 0))
	_add_sphere(ready_halo, "CompositionHeart", Vector3.ZERO, Vector3.ONE * 1.05,
		_materials.gold)


func _build_aether_analysis_console(controls: Node3D) -> void:
	_build_heavenly_quest_instrument(controls, "analysis_console",
		Vector3(-57.0, 3.0, 11.0), "ANALYSIS • COMPARE EVIDENCE")

func _build_pressure_gauge(parent: Node3D, gauge_name: String, at: Vector3, yaw: float) -> void:
	var gauge := Node3D.new()
	gauge.name = gauge_name
	gauge.position = at
	gauge.rotation.y = yaw
	gauge.set_meta("preserve_authored_nodes", true)
	parent.add_child(gauge)
	_add_cylinder(gauge, "GaugeIvoryCase", Vector3.ZERO, 3.5, 0.85,
		_materials.celestial_floor, false, 24).rotation_degrees.x = 90
	_add_torus(gauge, "GaugeGiltBezel", Vector3(0, 0, -0.52), 2.8, 3.5,
		_materials.astral_brass, Vector3(90, 0, 0))
	# Eleven separately editable tick marks and a teal target bracket turn the
	# tower face into a readable instrument rather than a blank decorative disc.
	for tick_index in 11:
		var tick_angle := deg_to_rad(-55.0 + float(tick_index) * 11.0)
		var tick_start := Vector3(sin(tick_angle) * 2.2, cos(tick_angle) * 2.2, -1.03)
		var tick_finish := Vector3(sin(tick_angle) * 2.75, cos(tick_angle) * 2.75, -1.03)
		_add_cable_between(gauge, "GaugeTick_%02d" % (tick_index + 1), tick_start,
			tick_finish, 0.10, 0.07,
			_materials.arrival_glass if tick_index in [5, 6] else _materials.astral_brass, 6)
	for target_index in 2:
		var target_angle := deg_to_rad(float(target_index) * 11.0 - 2.5)
		var target_start := Vector3(sin(target_angle) * 2.85, cos(target_angle) * 2.85, -1.06)
		var target_finish := Vector3(sin(target_angle) * 3.15, cos(target_angle) * 3.15, -1.06)
		_add_cable_between(gauge, "GaugeTargetBracket_%02d" % target_index, target_start,
			target_finish, 0.18, 0.15, _materials.arrival_glass, 8)
	_add_sphere(gauge, "GaugeStateLamp", Vector3(0, -4.3, -0.7), Vector3.ONE * 0.85,
		_materials.arrival_glass)
	var needle := Node3D.new()
	needle.name = "PressureNeedle"
	needle.position = Vector3(0, 0, -1.0)
	gauge.add_child(needle)
	_add_box(needle, "NeedleBlade", Vector3(0, 1.15, 0), Vector3(0.28, 2.8, 0.24),
		_materials.gold, false)
	_add_sphere(needle, "NeedleHub", Vector3.ZERO, Vector3.ONE * 0.55, _materials.astral_brass)


func _build_celestial_arrival_arch(parent: Node3D) -> void:
	var arch := Node3D.new()
	arch.name = "WorldGateCelestialArch"
	arch.position = Vector3(0, 0, -39)
	arch.set_meta("opening_width_m", 40.0)
	arch.set_meta("opening_height_m", 24.0)
	parent.add_child(arch)
	for side in [-1.0, 1.0]:
		var x := float(side) * 22.0
		_add_box(arch, "IvoryPortalPier", Vector3(x, 10.5, 0),
			Vector3(5.2, 21.0, 6.2), _materials.celestial_floor, false)
		_add_box(arch, "GiltPortalPierInset", Vector3(x, 11.0, -3.15),
			Vector3(1.1, 15.5, 0.25), _materials.astral_brass, false)
		_add_box(arch, "IvoryPortalCapital", Vector3(x, 21.5, 0),
			Vector3(8.0, 1.8, 8.0), _materials.celestial_floor, false)
	for segment_index in 18:
		var angle_a := PI - PI * float(segment_index) / 18.0
		var angle_b := PI - PI * float(segment_index + 1) / 18.0
		var start := Vector3(cos(angle_a) * 22.0, 21.5 + sin(angle_a) * 13.0, 0)
		var finish := Vector3(cos(angle_b) * 22.0, 21.5 + sin(angle_b) * 13.0, 0)
		_add_cable_between(arch, "IvoryCurvedVoussoir_%02d" % (segment_index + 1),
			start, finish, 1.55, 1.55, _materials.celestial_floor, 12)
		_add_cable_between(arch, "GiltCurvedReveal_%02d" % (segment_index + 1),
			start + Vector3(0, 0, -1.62), finish + Vector3(0, 0, -1.62),
			0.28, 0.28, _materials.astral_brass, 10)
	_add_sphere(arch, "AetherGateKeystone", Vector3(0, 36.0, -1.4),
		Vector3(2.6, 3.2, 1.6), _materials.arrival_glass)
	_add_label(arch, "WORLD GATE • ISLAND ONE", Vector3(0, 41.0, 0), Color("f8e9c7"), 28)


func _build_arrival_lantern_tower(parent: Node3D, side: float) -> void:
	var tower := Node3D.new()
	tower.name = "%sAetherLanternTower" % ("West" if side < 0 else "East")
	tower.position = Vector3(side * 52.0, 0, -24.0)
	tower.set_meta("purpose", "arrival beacon and levitation-pressure regulator")
	parent.add_child(tower)
	_add_cylinder(tower, "TowerIvoryPlinth", Vector3(0, 1.0, 0), 8.8, 2.0,
		_materials.celestial_floor, false, 20)
	_add_torus(tower, "TowerPlinthGiltBand", Vector3(0, 2.05, 0), 7.4, 8.5,
		_materials.astral_brass)
	_add_tapered_cylinder(tower, "TowerIvoryDrum", Vector3(0, 12.0, 0),
		6.1, 7.2, 20.0, _materials.celestial_floor, 20)
	for band_y in [4.2, 10.0, 16.0, 21.5]:
		_add_torus(tower, "TowerGiltCompressionBand", Vector3(0, band_y, 0),
			6.1, 6.7, _materials.astral_brass)
	for vane_index in 8:
		var angle := TAU * float(vane_index) / 8.0
		_add_box(tower, "TowerTealEnamelVane_%02d" % (vane_index + 1),
			Vector3(sin(angle) * 6.32, 12.0, cos(angle) * 6.32),
			Vector3(1.3, 13.0, 0.30), _materials.arrival_glass, false, angle)
	_add_sphere(tower, "TowerFacetedGlassDome", Vector3(0, 24.0, 0),
		Vector3(7.3, 4.7, 7.3), _materials.arrival_glass)
	_add_torus(tower, "TowerDomeGiltEquator", Vector3(0, 24.0, 0),
		6.7, 7.3, _materials.astral_brass)
	_add_tapered_cylinder(tower, "TowerGiltFinial", Vector3(0, 31.2, 0),
		0.20, 1.0, 8.0, _materials.astral_brass, 12)
	_add_sphere(tower, "TowerBeaconPearl", Vector3(0, 35.3, 0),
		Vector3.ONE * 1.15, _materials.gold)


func _build_arrival_garden_planter(parent: Node3D, side: float, garden_index: int) -> void:
	var garden := Node3D.new()
	garden.name = "%sArrivalGarden_%02d" % ["West" if side < 0 else "East", garden_index + 1]
	garden.position = Vector3(side * (52.0 + garden_index * 11.0), 0, 24.0 + garden_index * 27.0)
	parent.add_child(garden)
	_add_cylinder(garden, "IvoryPlanterBasin", Vector3(0, 1.0, 0),
		10.0 - garden_index * 1.2, 2.0, _materials.celestial_floor, false, 24)
	_add_torus(garden, "GiltPlanterLip", Vector3(0, 2.05, 0),
		8.0 - garden_index, 9.2 - garden_index, _materials.astral_brass)
	_add_cylinder(garden, "LivingSoilBed", Vector3(0, 2.12, 0),
		7.6 - garden_index, 0.26, _materials.hope_floor, false, 20)
	for bloom_index in 7:
		var angle := TAU * float(bloom_index) / 7.0 + garden_index * 0.3
		var radius := 4.6 if bloom_index > 0 else 0.0
		var bloom_at := Vector3(sin(angle) * radius, 3.0 + bloom_index % 2 * 0.7,
			cos(angle) * radius)
		_add_sphere(garden, "HeavenlyBloom_%02d" % (bloom_index + 1), bloom_at,
			Vector3(1.6, 0.72, 1.6),
			_materials.astral_lavender if bloom_index % 2 else _materials.green_glow)


func _build_island_one_science_art_garden(parent: Node3D) -> void:
	# This garden is a physical hint system. Phyllotaxis teaches ordered growth,
	# the three instruments teach colour, rhythm and visual weight, and the crown
	# light gives the puzzle a high heavenly key without blocking its central axis.
	var garden := Node3D.new()
	garden.name = "ScienceArtGarden"
	garden.position = Vector3(-52.0, 2.15, 24.0)
	garden.set_meta("preserve_authored_nodes", true)
	garden.set_meta("purpose", "environmental tutorial for creative harmony puzzle")
	garden.set_meta("science_principles", ["golden-angle phyllotaxis", "colour opposition", "rhythmic grouping", "visual-weight balance"])
	garden.set_meta("psychology_principles", ["cognitive defusion", "attentional flexibility", "cognitive reappraisal"])
	garden.set_meta("central_route_clear", true)
	parent.add_child(garden)

	# A Fibonacci pavement makes the growth rule readable from the upper deck.
	var golden_angle := deg_to_rad(137.507764)
	for pip_index in 34:
		var pip_radius := 1.52 * sqrt(float(pip_index + 1))
		var pip_angle := golden_angle * float(pip_index)
		_add_sphere(garden, "GoldenAnglePavementPip_%02d" % (pip_index + 1),
			Vector3(sin(pip_angle) * pip_radius, 0.22, cos(pip_angle) * pip_radius),
			Vector3(0.22, 0.10, 0.22),
			_materials.gold if pip_index % 5 == 0 else _materials.arrival_glass)

	var tree := Node3D.new()
	tree.name = "CognitiveLightTree"
	tree.set_meta("preserve_authored_nodes", true)
	tree.set_meta("reusable_component_family", "heavenly science-art teaching tree")
	tree.set_meta("leaf_distribution", "137.507764 degree golden-angle phyllotaxis")
	tree.set_meta("editable_parts", 140)
	garden.add_child(tree)
	_add_cylinder(tree, "TreeRootIvoryBasin", Vector3(0, 0.30, 0), 7.8, 0.60,
		_materials.celestial_floor, false, 32)
	_add_torus(tree, "TreeRootGoldenCollar", Vector3(0, 0.68, 0), 6.3, 7.5,
		_materials.astral_brass)
	for root_index in 12:
		var root_angle := TAU * float(root_index) / 12.0
		_add_cable_between(tree, "TreeStructuralRoot_%02d" % (root_index + 1),
			Vector3(sin(root_angle) * 1.2, 0.72, cos(root_angle) * 1.2),
			Vector3(sin(root_angle) * 7.0, 0.34, cos(root_angle) * 7.0),
			0.42, 0.16, _materials.astral_brass, 10)

	# Twelve tapered pieces form a gentle living curve; parallel cyan and
	# lavender fibres make nutrient/data flow legible at first-person distance.
	var trunk_points: Array[Vector3] = []
	for point_index in 13:
		var progress := float(point_index) / 12.0
		trunk_points.append(Vector3(sin(progress * PI * 1.3) * 1.35,
			1.0 + progress * 25.0, cos(progress * PI * 1.05) * 0.75))
	if trunk_points.size() == 13:
		for segment_index in 12:
			var start_radius := lerpf(1.55, 0.58, float(segment_index) / 12.0)
			var end_radius := lerpf(1.48, 0.48, float(segment_index + 1) / 12.0)
			_add_cable_between(tree, "TreeIvoryTrunk_%02d" % (segment_index + 1),
				trunk_points[segment_index], trunk_points[segment_index + 1],
				start_radius, end_radius, _materials.sanctum_ivory, 16)
			for fibre_index in 3:
				var fibre_angle := TAU * float(fibre_index) / 3.0 + float(segment_index) * 0.28
				var offset := Vector3(sin(fibre_angle), 0, cos(fibre_angle)) * start_radius * 0.94
				var next_angle := fibre_angle + 0.28
				var next_offset := Vector3(sin(next_angle), 0, cos(next_angle)) * end_radius * 0.94
				_add_cable_between(tree,
					"TreeSignalFibre_%02d_%02d" % [fibre_index + 1, segment_index + 1],
					trunk_points[segment_index] + offset,
					trunk_points[segment_index + 1] + next_offset, 0.17, 0.11,
					_materials.arrival_glass if fibre_index < 2 else _materials.sanctum_lavender_glass, 8)

	for branch_index in 10:
		var branch_angle := golden_angle * float(branch_index)
		var branch_start := trunk_points[6 + branch_index % 7]
		var branch_length := 9.0 + float(branch_index % 4) * 1.5
		var branch_mid := branch_start.lerp(Vector3(sin(branch_angle) * branch_length,
			20.0 + float(branch_index % 5) * 2.0, cos(branch_angle) * branch_length), 0.55)
		branch_mid += Vector3.UP * 2.2
		var branch_end := Vector3(sin(branch_angle) * branch_length,
			20.0 + float(branch_index % 5) * 2.0, cos(branch_angle) * branch_length)
		_add_cable_between(tree, "TreeIvoryBranchA_%02d" % (branch_index + 1),
			branch_start, branch_mid, 0.42, 0.25, _materials.sanctum_ivory, 12)
		_add_cable_between(tree, "TreeIvoryBranchB_%02d" % (branch_index + 1),
			branch_mid, branch_end, 0.25, 0.10, _materials.sanctum_ivory, 10)
		_add_cable_between(tree, "TreeGoldenBranchVeinA_%02d" % (branch_index + 1),
			branch_start + Vector3.UP * 0.16, branch_mid + Vector3.UP * 0.16,
			0.11, 0.07, _materials.gold, 8)
		_add_cable_between(tree, "TreeGoldenBranchVeinB_%02d" % (branch_index + 1),
			branch_mid + Vector3.UP * 0.16, branch_end + Vector3.UP * 0.16,
			0.07, 0.04, _materials.gold, 8)

	# Fifty-five luminous leaves use sunflower phyllotaxis on an ellipsoidal
	# crown: an artistic silhouette generated from a real growth model.
	for leaf_index in 55:
		var normalized_height := (float(leaf_index) + 0.5) / 55.0
		var leaf_y := lerpf(-1.0, 1.0, normalized_height)
		var radial := sqrt(maxf(0.0, 1.0 - leaf_y * leaf_y))
		var leaf_angle := golden_angle * float(leaf_index)
		var leaf_at := Vector3(sin(leaf_angle) * radial * 14.0,
			27.0 + leaf_y * 8.2, cos(leaf_angle) * radial * 10.5)
		_add_sphere(tree, "PhyllotaxisLightLeaf_%02d" % (leaf_index + 1), leaf_at,
			Vector3(1.45, 0.58, 0.92),
			_materials.gold if leaf_index % 7 == 0 else (
				_materials.sanctum_lavender_glass if leaf_index % 3 == 0 else _materials.arrival_glass))
		if leaf_index % 9 == 0:
			_add_sphere(tree, "SynapsePearl_%02d" % (leaf_index + 1),
				leaf_at + Vector3.UP * 0.65, Vector3.ONE * 0.34, _materials.gold)
	# Thirteen opal blossom rosettes bind the dispersed mathematical leaves into
	# a soft heavenly canopy. Each rosette remains an editable seven-part module.
	for blossom_index in 13:
		var blossom_height := lerpf(-0.82, 0.82, float(blossom_index) / 12.0)
		var blossom_radius := sqrt(maxf(0.0, 1.0 - blossom_height * blossom_height))
		var blossom_angle := golden_angle * float(blossom_index) * 2.0
		var blossom_at := Vector3(sin(blossom_angle) * blossom_radius * 12.5,
			28.0 + blossom_height * 7.5, cos(blossom_angle) * blossom_radius * 9.2)
		_add_sphere(tree, "WisdomBlossomHeart_%02d" % (blossom_index + 1), blossom_at,
			Vector3.ONE * 0.72, _materials.gold)
		for petal_index in 6:
			var petal_angle := TAU * float(petal_index) / 6.0 + blossom_angle
			var petal_at := blossom_at + Vector3(sin(petal_angle) * 1.35,
				cos(petal_angle) * 0.78, cos(petal_angle) * 0.42)
			_add_sphere(tree, "WisdomBlossom_%02d_Petal_%02d" % [blossom_index + 1, petal_index + 1],
				petal_at, Vector3(0.92, 0.52, 0.68),
				_materials.arrival_glass if blossom_index % 2 == 0 else _materials.sanctum_lavender_glass)
	# Nested tilted orbits visually connect the scientific leaf field and lift the
	# silhouette toward the same celestial language as the puzzle architecture.
	_add_torus(tree, "CanopyObservationOrbitA", Vector3(0, 29.0, 0), 12.2, 12.45,
		_materials.astral_brass, Vector3(18, 0, 8))
	_add_torus(tree, "CanopyObservationOrbitB", Vector3(0, 31.0, 0), 10.4, 10.65,
		_materials.arrival_glass, Vector3(-14, 0, 26))
	_add_torus(tree, "CanopyObservationOrbitC", Vector3(0, 33.0, 0), 8.2, 8.42,
		_materials.gold, Vector3(24, 0, -18))
	_add_torus(tree, "TreeWisdomCrownHalo", Vector3(0, 37.0, 0), 4.8, 5.5,
		_materials.astral_brass, Vector3(90, 0, 0))
	_add_sphere(tree, "TreeWisdomCrownCore", Vector3(0, 37.0, 0),
		Vector3.ONE * 1.45, _materials.arrival_glass)
	for ray_index in 8:
		var ray_angle := TAU * float(ray_index) / 8.0
		_add_cable_between(tree, "TreeCrownRay_%02d" % (ray_index + 1),
			Vector3(0, 37.0, 0),
			Vector3(sin(ray_angle) * 7.2, 37.0 + cos(ray_angle) * 7.2, 0),
			0.15, 0.08, _materials.gold, 8)
	var crown_light := _add_zone_light(tree, Vector3(0, 43.0, 0),
		Color("fff0c4"), 70.0, 3.5)
	crown_light.name = "ElevatedTreeCrownLight"
	# The production instruments now own these three lessons. The former circular
	# prototype pedestals were removed because they doubled every station and made
	# the garden read as scattered props rather than one coherent institution.
	_build_living_light_atelier_architecture(parent)
	_build_echo_garden_quest(parent)


func _build_echo_garden_quest(parent: MindSparkIslandOnePuzzle) -> void:
	var controls := parent.get_node("PuzzleControls") as Node3D
	var quest := Node3D.new()
	quest.name = "EchoGardenQuestArchitecture"
	quest.set_meta("preserve_authored_nodes", true)
	quest.set_meta("quest_id", "quest.echo_forest")
	quest.set_meta("design_revision", "v39_signal_prism_echo_garden")
	quest.set_meta("gameplay_sequence", ["collect", "classify", "question", "verify"])
	quest.set_meta("untimed", true)
	quest.set_meta("mandatory_jump", false)
	parent.add_child(quest)

	# A six-station outer crescent keeps the mature Wisdom Tree as the landmark.
	# Detailed production controls are reused, but each receives a distinct
	# instrument face and a visible conduit to the root chamber.
	var station_specs := [
		["echo_collector", Vector3(-68, 3.0, 48), "INSTALL PRISM • LISTEN", 0],
		["echo_signal_1", Vector3(-80, 3.0, 12), "ECHO I • EXAMINE", 1],
		["echo_signal_2", Vector3(-84, 3.0, 25), "ECHO II • EXAMINE", 1],
		["echo_signal_3", Vector3(-80, 3.0, 38), "ECHO III • EXAMINE", 1],
		["echo_question", Vector3(-53, 3.0, 54), "SHAPE THE HELPFUL QUESTION", 1],
		["echo_beacon", Vector3(-36, 3.0, 48), "TEST THE CAUTION BEACON", 2],
	]
	for spec in station_specs:
		_build_compass_control(controls, str(spec[0]), spec[1], str(spec[2]), int(spec[3]))
		var control := controls.get_node("PuzzleControl_%s" % str(spec[0])) as Node3D
		control.set_meta("quest_id", "quest.echo_forest")
		control.set_meta("interaction_model", "walk, observe, classify, revise")
		control.set_meta("reusable_component_family", "echo garden instrument")

	# Quest 1's reward becomes a physical key rather than an inventory-only flag.
	var prism_socket := Node3D.new()
	prism_socket.name = "SignalPrismTransferSocket"
	prism_socket.position = Vector3(-64, 4.4, 52)
	quest.add_child(prism_socket)
	_add_cylinder(prism_socket, "PrismSocketIvoryBody", Vector3.ZERO, 2.15, 1.4,
		_materials.sanctum_ivory, false, 24)
	_add_torus(prism_socket, "PrismSocketGiltBezel", Vector3(0, 0.78, 0), 1.52, 2.12,
		_materials.astral_brass)
	_add_brick(prism_socket, "InstalledSignalPrism", Vector3(0, 2.35, 0),
		Bricks.build_crystal(1.18, 4.1, 0.30, 8), _materials.arrival_glass)
	for clamp_index in 8:
		var clamp_angle := TAU * float(clamp_index) / 8.0
		_add_box(prism_socket, "PrismSocketClamp_%02d" % (clamp_index + 1),
			Vector3(sin(clamp_angle) * 1.92, 1.05, cos(clamp_angle) * 1.92),
			Vector3(0.28, 0.72, 0.46), _materials.gold, false, clamp_angle)

	# Three slow signal orbs rest in branch cradles. They disappear from the
	# listening canopy one at a time and reappear at the classifier rail.
	var orb_positions := [Vector3(-72, 12.0, 18), Vector3(-75, 15.0, 28), Vector3(-70, 18.0, 38)]
	for orb_index in 3:
		var orb_at: Vector3 = orb_positions[orb_index]
		_add_cable_between(quest, "EchoListeningBranch_%02d" % (orb_index + 1),
			Vector3(-52, 7.0 + orb_index * 1.6, 24), orb_at,
			0.24, 0.10, _materials.astral_brass, 10)
		var orb := _add_sphere(quest, "EchoListeningOrb_%02d" % (orb_index + 1), orb_at,
			Vector3.ONE * 1.25,
			_materials.arrival_glass if orb_index == 0 else (
				_materials.sanctum_lavender_glass if orb_index == 1 else _materials.gold))
		orb.set_meta("echo_index", orb_index)
		_add_torus(quest, "EchoOrbCradle_%02d" % (orb_index + 1), orb_at,
			1.45, 1.82, _materials.astral_brass, Vector3(90, 0, 0))
		var resting := _add_sphere(quest, "RestingEchoOrb_%02d" % (orb_index + 1),
			Vector3(-78.0, 5.9, 12.0 + orb_index * 13.0), Vector3.ONE * 0.72,
			_materials.arrival_glass)
		resting.visible = false

	# Statement and category readings stay attached to the new classifier desks.
	for station_index in 3:
		var control := controls.get_node("PuzzleControl_echo_signal_%d" % (station_index + 1)) as Node3D
		var signal_label := _add_label(control, "ECHO %d" % (station_index + 1),
			Vector3(-1.4, 5.3, 0), Color("fff2d9"), 20)
		signal_label.name = "EchoSignalText_%02d" % (station_index + 1)
		signal_label.pixel_size = 0.007
		var category_label := _add_label(control, "UNCLASSIFIED",
			Vector3(-1.4, 4.3, 0), Color("d9fff4"), 20)
		category_label.name = "EchoCategoryReading_%02d" % (station_index + 1)
		category_label.pixel_size = 0.006
	var question_reading := _add_label(quest, "CHOOSE A USEFUL QUESTION",
		Vector3(-54.5, 8.5, 54), Color("fff2d9"), 20)
	question_reading.name = "ProtectiveQuestionReading"
	question_reading.pixel_size = 0.007

	# The new cradled crystal replaces the old tower and radial-ray overlay.
	var beacon := controls.get_node("PuzzleControl_echo_beacon") as Node3D
	var beacon_light := _add_zone_light(beacon, Vector3(0, 4.0, 0), Color("8fe8dc"), 8.0, 0.15)
	beacon_light.name = "CautionBeaconLight"
	var reward := Node3D.new()
	reward.name = "EchoSeedReward"
	reward.position = Vector3(-36, -3.0, 48)
	reward.visible = false
	quest.add_child(reward)
	_add_sphere(reward, "EchoSeedHeart", Vector3.ZERO, Vector3(1.25, 1.75, 1.25),
		_materials.gold)
	for petal_index in 8:
		var petal_angle := TAU * float(petal_index) / 8.0
		_add_sphere(reward, "EchoSeedPetal_%02d" % (petal_index + 1),
			Vector3(sin(petal_angle) * 1.55, cos(petal_angle) * 1.15, 0),
			Vector3(0.72, 0.38, 0.28), _materials.arrival_glass)

	# Every station terminates at the root well; this is the visible explanation
	# for why solving the garden wakes the island rather than an arbitrary gate.
	var route_points := [Vector3(-68, 3.8, 48), Vector3(-80, 3.8, 12),
		Vector3(-84, 3.8, 25), Vector3(-80, 3.8, 38), Vector3(-53, 3.8, 54),
		Vector3(-36, 3.8, 48)]
	for route_index in route_points.size():
		_add_cable_between(quest, "EchoRootConduit_%02d" % (route_index + 1),
			route_points[route_index], Vector3(-52, 3.8, 24), 0.18, 0.09,
			_materials.arrival_glass if route_index % 2 == 0 else _materials.astral_brass, 8)
		for pulse_index in 3:
			var pulse := _add_sphere(quest,
				"EchoRootPulse_%02d_%02d" % [route_index + 1, pulse_index + 1],
				route_points[route_index], Vector3.ONE * 0.26, _materials.arrival_glass)
			pulse.visible = false
			pulse.set_meta("route_index", route_index)
			pulse.set_meta("path_start", route_points[route_index])
			pulse.set_meta("path_end", Vector3(-52, 3.8, 24))
			pulse.set_meta("pulse_offset", float(pulse_index) / 3.0)

	# Four restrained floor-light chapters form one readable walking path. Each
	# chapter appears only when its destination is the next meaningful action.
	var guidance := Node3D.new()
	guidance.name = "EchoGardenGuidancePath"
	guidance.set_meta("clear_width_m", 5.5)
	guidance.set_meta("mandatory_jump", false)
	quest.add_child(guidance)
	var guidance_points := [Vector3(0, 3.05, 72), Vector3(-68, 3.05, 48),
		Vector3(-82, 3.05, 25), Vector3(-53, 3.05, 54), Vector3(-36, 3.05, 48)]
	for chapter_index in 4:
		for marker_index in 8:
			var progress := float(marker_index + 1) / 8.0
			var marker_at: Vector3 = guidance_points[chapter_index].lerp(
				guidance_points[chapter_index + 1], progress)
			var marker := _add_sphere(guidance,
				"GuidanceLight_%02d_%02d" % [chapter_index + 1, marker_index + 1],
				marker_at, Vector3(0.30, 0.07, 0.46),
				_materials.gold if chapter_index == 3 else _materials.arrival_glass)
			marker.visible = false
			marker.set_meta("guidance_chapter", chapter_index)
	var objective_display := _add_label(quest, "SIGNAL PRISM REQUIRED",
		Vector3(-52, 18.0, 24), Color("fff2c0"), 14)
	objective_display.name = "EchoGardenObjectiveDisplay"


func _build_living_light_atelier_architecture(parent: Node3D) -> void:
	var atelier := Node3D.new()
	atelier.name = "LivingLightAtelierArchitecture"
	atelier.position = Vector3(-52.0, 2.05, 24.0)
	atelier.set_meta("preserve_authored_nodes", true)
	atelier.set_meta("design_revision", "v36_crescent_root_light_atelier")
	atelier.set_meta("architectural_order", "one crescent terrace, three instrument bays, one shared optical crown")
	atelier.set_meta("duplicate_prototype_stations_removed", true)
	atelier.set_meta("clear_access_width_m", 5.5)
	parent.add_child(atelier)

	# A continuous crescent makes all three experiments parts of one civic room.
	# Twenty-four independent radial plates retain small seams and editability.
	var sector_count := 24
	var start_angle := deg_to_rad(-112.0)
	var finish_angle := deg_to_rad(136.0)
	for sector_index in sector_count:
		var angle_a := lerpf(start_angle, finish_angle,
			float(sector_index) / float(sector_count))
		var angle_b := lerpf(start_angle, finish_angle,
			float(sector_index + 1) / float(sector_count))
		_add_radial_plate(atelier, "AtelierFoundationSector_%02d" % (sector_index + 1),
			angle_a, angle_b, 8.5, 21.2, -0.35, 0.08, _materials.sanctum_ivory)
		_add_radial_plate(atelier, "AtelierFloorSector_%02d" % (sector_index + 1),
			angle_a + 0.006, angle_b - 0.006, 9.2, 20.4, 0.10, 0.34,
			_materials.celestial_floor if sector_index % 3 else _materials.sanctum_ivory)
		if sector_index % 3 == 0:
			var seam_angle := (angle_a + angle_b) * 0.5
			_add_cable_between(atelier, "AtelierRadialInlay_%02d" % (sector_index + 1),
				Vector3(sin(seam_angle) * 9.5, 0.42, cos(seam_angle) * 9.5),
				Vector3(sin(seam_angle) * 20.0, 0.42, cos(seam_angle) * 20.0),
				0.10, 0.10, _materials.arrival_glass, 8)
	# Two continuous orders finish the terrace without adding another full ring.
	for edge_index in 32:
		var edge_a := lerpf(start_angle, finish_angle, float(edge_index) / 32.0)
		var edge_b := lerpf(start_angle, finish_angle, float(edge_index + 1) / 32.0)
		_add_cable_between(atelier, "AtelierOuterGiltOrder_%02d" % (edge_index + 1),
			Vector3(sin(edge_a) * 20.6, 0.48, cos(edge_a) * 20.6),
			Vector3(sin(edge_b) * 20.6, 0.48, cos(edge_b) * 20.6),
			0.20, 0.20, _materials.astral_brass, 10)
		_add_cable_between(atelier, "AtelierInnerAetherOrder_%02d" % (edge_index + 1),
			Vector3(sin(edge_a) * 8.9, 0.46, cos(edge_a) * 8.9),
			Vector3(sin(edge_b) * 8.9, 0.46, cos(edge_b) * 8.9),
			0.11, 0.11, _materials.arrival_glass, 8)

	# Three intentionally different bay medallions organize the machines while
	# sharing the same structural vocabulary and dimensions.
	var bay_positions := [Vector3(12.5, 0, -8.0), Vector3(14.5, 0, 6.0),
		Vector3(-14.0, 0, 0)]
	var bay_names := ["ColourBay", "RhythmBay", "WeightBay"]
	var bay_materials := [_materials.arrival_glass, _materials.sanctum_lavender_glass,
		_materials.gold]
	for bay_index in 3:
		var bay_at: Vector3 = bay_positions[bay_index]
		_add_cylinder(atelier, "%sIvoryMedallion" % bay_names[bay_index],
			bay_at + Vector3.UP * 0.48, 4.4, 0.34, _materials.sanctum_ivory, false, 32)
		_add_torus(atelier, "%sGiltBoundary" % bay_names[bay_index],
			bay_at + Vector3.UP * 0.68, 3.7, 4.25, _materials.astral_brass)
		for marker_index in 8:
			var marker_angle := TAU * float(marker_index) / 8.0
			_add_box(atelier, "%sScienceMarker_%02d" % [bay_names[bay_index], marker_index + 1],
				bay_at + Vector3(sin(marker_angle) * 3.15, 0.82, cos(marker_angle) * 3.15),
				Vector3(0.16, 0.14 + float(marker_index % (bay_index + 2)) * 0.09, 0.42),
				bay_materials[bay_index], false, marker_angle)

	# Low balustrades protect the sky edge but stop around the eastern approach.
	# Their restrained height avoids the former forest of full-size columns.
	for post_index in 15:
		var post_angle := lerpf(deg_to_rad(-105.0), deg_to_rad(55.0),
			float(post_index) / 14.0)
		var post_at := Vector3(sin(post_angle) * 20.9, 1.65, cos(post_angle) * 20.9)
		_add_tapered_cylinder(atelier, "AtelierBaluster_%02d" % (post_index + 1),
			post_at, 0.24, 0.38, 2.35, _materials.sanctum_ivory, 12)
		_add_sphere(atelier, "AtelierBalusterPearl_%02d" % (post_index + 1),
			post_at + Vector3.UP * 1.32, Vector3.ONE * 0.30,
			_materials.arrival_glass if post_index % 2 == 0 else _materials.gold)
		if post_index > 0:
			var previous_angle := lerpf(deg_to_rad(-105.0), deg_to_rad(55.0),
				float(post_index - 1) / 14.0)
			_add_cable_between(atelier, "AtelierBalustradeRail_%02d" % post_index,
				Vector3(sin(previous_angle) * 20.9, 2.70, cos(previous_angle) * 20.9),
				Vector3(sin(post_angle) * 20.9, 2.70, cos(post_angle) * 20.9),
				0.12, 0.12, _materials.astral_brass, 8)

	# The optical relay is integrated into the Wisdom Tree's root plinth. It is a
	# piece of civic infrastructure—not another floating ornament—and explains how
	# Colour, Rhythm and Weight become one coherent living-light composition.
	var root_well := Node3D.new()
	root_well.name = "AtelierRootLightWell"
	root_well.position = Vector3(0, 0.72, 0)
	root_well.set_meta("architectural_role", "shared optical and aether relay")
	root_well.set_meta("narrative_role", "thoughts become insight at the roots of wisdom")
	atelier.add_child(root_well)
	_add_cylinder(root_well, "RootWellIvoryFoundation", Vector3(0, -0.24, 0),
		4.85, 0.42, _materials.sanctum_ivory, false, 32)
	_add_torus(root_well, "RootWellGiltOuterOrder", Vector3.ZERO, 4.15, 4.65,
		_materials.astral_brass)
	_add_torus(root_well, "RootWellAetherBezel", Vector3(0, 0.12, 0), 3.18, 3.72,
		_materials.arrival_glass)
	_add_sphere(root_well, "RootWellLens", Vector3(0, 0.18, 0),
		Vector3(2.85, 0.22, 2.85), _materials.arrival_glass)
	for iris_index in 8:
		var iris_angle := TAU * float(iris_index) / 8.0
		_add_cable_between(root_well, "RootWellIris_%02d" % (iris_index + 1),
			Vector3(0, 0.46, 0),
			Vector3(sin(iris_angle) * 2.72, 0.46, cos(iris_angle) * 2.72),
			0.09, 0.05, _materials.gold, 6)
	for lesson_index in 3:
		var lesson_angle := TAU * float(lesson_index) / 3.0
		var lesson_at := Vector3(sin(lesson_angle) * 3.55, 0.58,
			cos(lesson_angle) * 3.55)
		_add_torus(root_well, "RootWellLessonPort_%02d" % (lesson_index + 1),
			lesson_at, 0.44, 0.72, bay_materials[lesson_index])
		_add_tapered_cylinder(root_well, "RootWellLessonCrystal_%02d" % (lesson_index + 1),
			lesson_at + Vector3.UP * 0.58, 0.12, 0.38, 1.05,
			bay_materials[lesson_index], 10)
		_add_cable_between(atelier, "AtelierBuriedAetherConduit_%02d" % (lesson_index + 1),
			bay_positions[lesson_index] + Vector3.UP * 0.54,
			Vector3(sin(lesson_angle) * 4.15, 0.54, cos(lesson_angle) * 4.15),
			0.13, 0.10, bay_materials[lesson_index], 8)
	# Four broad, low steps provide an explicit accessible approach from the main
	# conservatory lane without creating a new collision wall.
	for step_index in 4:
		_add_brick(atelier, "AtelierApproachStep_%02d" % (step_index + 1),
			Vector3(19.0 + float(step_index) * 1.15, 0.08 + float(step_index) * 0.10,
				-10.0 - float(step_index) * 0.55),
			Bricks.build_bevel_box(Vector3(7.0 - float(step_index) * 0.55, 0.20, 2.8), 0.12),
			_materials.sanctum_ivory)


func _build_network_forest(zone: Node3D) -> void:
	zone.set_meta("legacy_random_server_trees_replaced", true)
	for index in 8:
		_add_box(zone, "FibreRoot", Vector3(-75 + index * 22, 0.7, sin(index * 1.7) * 40),
			Vector3(44, 1.3, 2.2), _materials.green_glow, false, float(index) * 0.31)


func _build_constellation_court(zone: Node3D) -> void:
	_add_cylinder(zone, "ConstellationDais", Vector3(0, 1.2, 0), 82, 2.4, _materials.celestial_floor, true, 40)
	for radius in [24.0, 48.0, 76.0]:
		var ring := _add_torus(zone, "AstralCourtGiltInlay", Vector3(0, 2.43, 0), radius - 0.10, radius + 0.10, _materials.astral_brass)
		ring.scale.y = 0.22
	for index in 8:
		var angle := TAU * float(index) / 8.0
		_add_sphere(zone, "MemoryNode", Vector3(cos(angle) * 62, 8 + index % 3 * 5, sin(angle) * 62),
			Vector3.ONE * 4.0, _materials.astral_glass)
	_build_astral_gate(zone, Vector3(-92, 0, 20), "FEAR GATE", _materials.astral_lavender)
	_build_astral_gate(zone, Vector3(92, 0, 20), "PROOF / LOGIC GATE", _materials.astral_glass)


func _build_astral_gate(zone: Node3D, at: Vector3, title: String, accent: Material) -> void:
	# Keep original opening, collision and label, changing only the visual finish.
	var arch := _build_arch(zone, at, 34, 44, _materials.celestial_floor, title)
	for x in [-17.0, 17.0]:
		_add_box(arch, "GiltPilaster", Vector3(x, 22, -3.55), Vector3(2.4, 36, 0.18), _materials.astral_brass)
		_add_box(arch, "EnamelInset", Vector3(x, 23, -3.70), Vector3(1.5, 27, 0.12), accent)
		_add_box(arch, "CarvedCapital", Vector3(x, 40, 0), Vector3(6.5, 1.4, 8.5), _materials.celestial_floor)
		_add_box(arch, "GoldCapitalReveal", Vector3(x, 40.8, 0), Vector3(6.8, 0.25, 8.8), _materials.astral_brass)
	_add_box(arch, "IvoryCornice", Vector3(0, 47, 0), Vector3(43, 1.6, 9), _materials.celestial_floor)
	_add_box(arch, "GiltCrown", Vector3(0, 48, 0), Vector3(44, 0.35, 9.5), _materials.astral_brass)
	for i in 32:
		var a := PI * float(i) / 32.0
		var b := PI * float(i + 1) / 32.0
		_add_cable_between(arch, "CurvedGiltReveal", Vector3(cos(a) * 14.4, 32 + sin(a) * 9.1, -3.65),
			Vector3(cos(b) * 14.4, 32 + sin(b) * 9.1, -3.65), 0.22, 0.22, _materials.astral_brass)


func _build_hope_ridge(zone: Node3D) -> void:
	var upper_district := Node3D.new()
	upper_district.name = "CelestialHopeUpperDistrict"
	upper_district.set_meta("design_style", "warm heavenly Piltover industrial civic garden")
	upper_district.set_meta("landmark", "Aether Lift Pavilion and Hall of Hope")
	upper_district.set_meta("gameplay_clearance_policy", "existing jump course, accessible lane and bridge corridors retained")
	upper_district.set_meta("above_ground_revision", "v18")
	zone.add_child(upper_district)

	# Preserve the authored five-step Hope Path, but give every slab an ivory
	# plinth, gilt reveal and readable progression toward the pavilion.
	for index in 5:
		var at := Vector3(-82 + index * 41, 1 + index * 2, -28)
		_add_box(zone, "HopePathIvoryPlinth_%02d" % index,
			at - Vector3(0, 0.75, 0), Vector3(36, 0.50, 56),
			_materials.celestial_floor, false)
		_add_box(zone, "HopePathTile_%02d" % index, at, Vector3(34, 2, 54),
			_materials.celestial_floor, true)
		_add_box(zone, "HopePathGiltReveal_%02d" % index,
			at + Vector3(0, 1.08, 0), Vector3(31, 0.18, 49),
			_materials.gold if index == 4 else _materials.arrival_glass, false)
		# Quiet low-poly measures communicate progress without turning the full
		# walking surface into a saturated prototype panel. Gold appears only on
		# the final verified stage.
		for measure in 3:
			_add_box(zone,"HopePathMeasure_%02d_%02d"%[index,measure],
				at+Vector3(-9+measure*9,1.22,-15+index*2),Vector3(3.6,.12,8.0),
				_materials.gold if index==4 else _materials.astral_glass,false)
		for flower in 3:
			_add_sphere(zone, "ThoughtFlower", at + Vector3(-10 + flower * 10, 4, 20),
				Vector3(2.5, 1.4, 2.5), _materials.green_glow)
	_build_hope_aether_pavilion(upper_district)
	_build_hope_engine_towers(upper_district)
	_build_hope_garden_terraces(upper_district)


func _build_hope_aether_pavilion(parent: Node3D) -> void:
	var pavilion := Node3D.new()
	pavilion.name = "AetherLiftPavilion"
	pavilion.set_meta("structural_purpose", "upper lift manifold, quest landmark and weather canopy")
	pavilion.set_meta("clear_span_m", 36.0)
	parent.add_child(pavilion)
	var center := Vector3(0, 0, 42)
	_add_cylinder(pavilion, "PavilionIvoryDais", center + Vector3.UP * 0.28,
		31.0, 0.56, _materials.celestial_floor, false, 48)
	_add_torus(pavilion, "PavilionOuterGiltFloorRing", center + Vector3.UP * 0.62,
		27.0, 28.0, _materials.astral_brass)
	_add_torus(pavilion, "PavilionInnerEnergyFloorRing", center + Vector3.UP * 0.64,
		17.0, 18.0, _materials.astral_glass)

	# Eight slender columns make the pavilion civic and luxurious while leaving
	# broad walk-through openings on every approach.
	for column_index in 8:
		var angle := TAU * float(column_index) / 8.0
		var column_at := center + Vector3(sin(angle) * 25.0, 8.0, cos(angle) * 17.0)
		_add_tapered_cylinder(pavilion, "PavilionIvoryColumn_%02d" % (column_index + 1),
			column_at, 0.88, 1.28, 14.6, _materials.celestial_floor, 16)
		_add_torus(pavilion, "PavilionColumnFoot_%02d" % (column_index + 1),
			column_at - Vector3.UP * 7.0, 1.10, 1.48, _materials.astral_brass)
		_add_torus(pavilion, "PavilionColumnCapital_%02d" % (column_index + 1),
			column_at + Vector3.UP * 7.0, 1.05, 1.52, _materials.astral_brass)

	# The oval cornice is assembled from editable curved beam segments rather
	# than a single heavy roof, keeping the silhouette heavenly and open.
	for segment_index in 32:
		var angle_a := TAU * float(segment_index) / 32.0
		var angle_b := TAU * float(segment_index + 1) / 32.0
		var crown_a := center + Vector3(sin(angle_a) * 27.2, 16.1, cos(angle_a) * 19.2)
		var crown_b := center + Vector3(sin(angle_b) * 27.2, 16.1, cos(angle_b) * 19.2)
		_add_cable_between(pavilion, "PavilionIvoryCornice_%02d" % (segment_index + 1),
			crown_a, crown_b, 0.72, 0.72, _materials.celestial_floor, 12)
		_add_cable_between(pavilion, "PavilionGiltCornice_%02d" % (segment_index + 1),
			crown_a + Vector3.UP * 0.55, crown_b + Vector3.UP * 0.55,
			0.17, 0.17, _materials.astral_brass, 10)
	# A faceted sunrise canopy gives the pavilion an architectural crown while
	# retaining a generous central oculus for the lift halo.
	var canopy := Node3D.new()
	canopy.name = "SegmentedSunriseCanopy"
	canopy.position = center
	canopy.set_meta("editable_roof_panels", 24)
	pavilion.add_child(canopy)
	for panel_index in 24:
		var panel_step := TAU / 24.0
		var panel_start := panel_step * panel_index + panel_step * 0.07
		var panel_end := panel_step * (panel_index + 1) - panel_step * 0.07
		_add_radial_plate(canopy, "SunCanopyPanel_%02d" % (panel_index + 1),
			panel_start, panel_end, 10.8, 26.3, 15.82, 16.10,
			_materials.celestial_floor if panel_index % 4 else _materials.astral_brass)
		var midpoint := (panel_start + panel_end) * 0.5
		_add_cable_between(canopy, "SunCanopyGiltRib_%02d" % (panel_index + 1),
			Vector3(sin(midpoint) * 10.5, 16.28, cos(midpoint) * 10.5),
			Vector3(sin(midpoint) * 26.5, 16.28, cos(midpoint) * 26.5),
			0.15, 0.11, _materials.astral_brass, 8)
	_add_torus(canopy, "SunCanopyOculus", Vector3(0, 16.30, 0),
		9.6, 11.0, _materials.astral_brass)
	_add_sphere(canopy, "SunCanopyOpalLantern", Vector3(0, 18.0, 0),
		Vector3(7.8, 2.0, 7.8), _materials.astral_glass)

	# A luminous lift core explains how the machinery below reaches the deck.
	_add_cylinder(pavilion, "AetherLiftCore", center + Vector3.UP * 7.0,
		4.6, 12.0, _materials.astral_glass, false, 32)
	for height in [1.5, 6.5, 12.0]:
		_add_torus(pavilion, "AetherLiftCoreBand", center + Vector3.UP * height,
			4.5, 5.2, _materials.astral_brass)
	_add_sphere(pavilion, "AetherLiftCrown", center + Vector3.UP * 16.8,
		Vector3.ONE * 3.6, _materials.cyan)
	_add_torus(pavilion, "AetherLiftHalo", center + Vector3.UP * 23.0,
		10.0, 12.0, _materials.astral_brass, Vector3(90, 0, 0))
	for ray_index in 12:
		var ray_angle := TAU * float(ray_index) / 12.0
		_add_cable_between(pavilion, "AetherLiftHaloRay_%02d" % (ray_index + 1),
			center + Vector3(0, 23.0, 0),
			center + Vector3(cos(ray_angle) * 9.4, 23.0 + sin(ray_angle) * 9.4, 0),
			0.16, 0.10, _materials.gold, 8)
	for rib_index in 8:
		var rib_angle := TAU * float(rib_index) / 8.0
		var rib_start := center + Vector3(sin(rib_angle) * 25.0, 15.4, cos(rib_angle) * 17.0)
		_add_cable_between(pavilion, "PavilionCanopyRib_%02d" % (rib_index + 1),
			rib_start, center + Vector3(0, 21.0, 0), 0.28, 0.18,
			_materials.astral_brass, 10)

	# Three vertical truth portals now form a processional Hall of Hope instead
	# of disconnected horizontal rings floating over the paving.
	for portal_index in 3:
		var portal_x := -44.0 + float(portal_index) * 44.0
		var portal_height := 16.0 + (4.0 if portal_index == 1 else 0.0)
		var portal_at := Vector3(portal_x, portal_height, 76)
		_add_torus(pavilion, "TruthPortal_%02d" % (portal_index + 1), portal_at,
			10.5, 13.2, _materials.gold if portal_index == 2 else _materials.cyan,
			Vector3(90, 0, 0))
		for side in [-1.0, 1.0]:
			var pier_x := portal_x + float(side) * 11.8
			_add_tapered_cylinder(pavilion,
				"TruthPortalPier_%02d" % (portal_index * 2 + (1 if side < 0 else 2)),
				Vector3(pier_x, 7.0, 76), 0.9, 1.35, 13.5,
				_materials.celestial_floor, 14)
			_add_box(pavilion, "TruthPortalPierInlay", Vector3(pier_x, 7.4, 74.9),
				Vector3(0.65, 8.0, 0.22), _materials.astral_brass, false)
	_add_zone_light(pavilion, center + Vector3.UP * 20.0, Color("ffd88b"), 74.0, 2.8)


func _build_hope_engine_towers(parent: Node3D) -> void:
	var machinery := Node3D.new()
	machinery.name = "TwinUpperPressureCondenserHouses"
	machinery.set_meta("structural_purpose", "condense aether exhaust and feed the foundation lift manifold")
	parent.add_child(machinery)
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		var tower_x := float(side) * 67.0
		var tower_z := 18.0
		# Each machine is recessed in a monumental oval engine-house frame. The
		# dark teal backing gives the ivory and brass enough depth at game scale.
		_add_box(machinery, "UpperEngineHouseTealRecess",
			Vector3(tower_x, 12.0, tower_z + 6.6), Vector3(22.0, 24.0, 1.2),
			_materials.astral_glass, false)
		_add_torus(machinery, "UpperEngineHouseIvoryArch", Vector3(tower_x, 12.0, tower_z + 5.8),
			11.0, 13.0, _materials.celestial_floor, Vector3(90, 0, 0))
		_add_torus(machinery, "UpperEngineHouseGiltReveal", Vector3(tower_x, 12.0, tower_z + 5.0),
			10.4, 11.0, _materials.astral_brass, Vector3(90, 0, 0))
		for pier_side in [-1.0, 1.0]:
			var frame_x := tower_x + float(pier_side) * 11.7
			_add_tapered_cylinder(machinery, "UpperEngineHousePier", Vector3(frame_x, 8.0, tower_z + 5.8),
				1.05, 1.55, 15.0, _materials.celestial_floor, 16)
			_add_box(machinery, "UpperEngineHousePierInlay", Vector3(frame_x, 8.0, tower_z + 4.7),
				Vector3(0.7, 9.5, 0.24), _materials.astral_brass, false)
		_add_box(machinery, "UpperEngineHouseCornice", Vector3(tower_x, 24.8, tower_z + 5.8),
			Vector3(27.0, 1.6, 4.0), _materials.celestial_floor, false)
		_add_box(machinery, "UpperEngineHouseCrownLine", Vector3(tower_x, 25.7, tower_z + 5.4),
			Vector3(28.0, 0.35, 4.4), _materials.astral_brass, false)
		_add_cylinder(machinery, "%sUpperCondenserIvoryDrum" % side_name, Vector3(tower_x, 11.0, tower_z),
			7.2, 21.0, _materials.celestial_floor, false, 32)
		for band_y in [1.2, 7.0, 14.0, 21.2]:
			_add_torus(machinery, "UpperCondenserGiltBand", Vector3(tower_x, band_y, tower_z),
				6.9, 7.7, _materials.astral_brass)
		_add_box(machinery, "UpperCondenserSightGlass",
			Vector3(tower_x, 11.2, tower_z - 7.15), Vector3(3.0, 13.5, 0.50),
			_materials.astral_glass, false)
		for fin_index in 11:
			_add_box(machinery, "UpperCondenserCoolingFin_%02d" % (fin_index + 1),
				Vector3(tower_x + float(side) * 9.3, 3.0 + fin_index * 1.62, tower_z),
				Vector3(9.8, 0.42, 8.5), _materials.astral_brass, false)
		_add_cable_between(machinery, "UpperCondenserCrownPipe",
			Vector3(tower_x, 21.7, tower_z), Vector3(float(side) * 28.0, 15.6, 42),
			0.65, 0.42, _materials.astral_brass, 12)
		_add_cable_between(machinery, "UpperCondenserDeckFeed",
			Vector3(tower_x, 1.2, tower_z), Vector3(float(side) * 8.0, 1.2, 42),
			0.48, 0.30, _materials.astral_brass, 10)
		_add_torus(machinery, "UpperCondenserServiceValve",
			Vector3(tower_x - float(side) * 6.2, 8.5, tower_z), 2.1, 2.7,
			_materials.gold, Vector3(0, 90, 0))


func _build_hope_garden_terraces(parent: Node3D) -> void:
	var gardens := Node3D.new()
	gardens.name = "CurvedSunriseGardenTerraces"
	gardens.set_meta("purpose", "warm civic rest garden framing the quest deck")
	gardens.set_meta("bridge_openings_retained", true)
	parent.add_child(gardens)
	# The terraces occupy the quiet southern arc; the two bridge bearings and
	# the Hope Path course remain visually open.
	for terrace_index in 12:
		var angle_start := deg_to_rad(126.0 + terrace_index * 10.0)
		var angle_end := deg_to_rad(134.0 + terrace_index * 10.0)
		_add_radial_plate(gardens, "SunriseIvoryPlanter_%02d" % (terrace_index + 1),
			angle_start, angle_end, 78.0, 99.0, 0.12, 1.25,
			_materials.celestial_floor)
		_add_radial_plate(gardens, "SunriseGiltPlanterCap_%02d" % (terrace_index + 1),
			angle_start + 0.01, angle_end - 0.01, 79.0, 98.0, 1.27, 1.52,
			_materials.astral_brass)
		var middle_angle := (angle_start + angle_end) * 0.5
		var flower_at := Vector3(sin(middle_angle) * 88.5, 3.2, cos(middle_angle) * 88.5)
		_add_sphere(gardens, "SunriseGardenCrown_%02d" % (terrace_index + 1),
			flower_at, Vector3(3.2, 1.8, 3.2),
			_materials.green_glow if terrace_index % 2 == 0 else _materials.astral_glass)
		_add_sphere(gardens, "SunriseGardenBloom_%02d" % (terrace_index + 1),
			flower_at + Vector3.UP * 2.2, Vector3.ONE * 0.85,
			_materials.gold if terrace_index % 3 == 0 else _materials.cyan)


func _build_storm_arena(zone: Node3D) -> void:
	_add_cylinder(zone, "BossArenaCollision", Vector3(0, 1.0, 0), 155, 2.0, _materials.storm, true, 48)
	for index in 5:
		_add_torus(zone, "LayeredStormRing_%02d" % index, Vector3(0, 24 + index * 12, 0),
			42 + index * 13, 47 + index * 13, _materials.violet)
	var checkpoint := Marker3D.new()
	checkpoint.name = "BossRetryCheckpoint"
	checkpoint.position = Vector3(0, 5, -168)
	zone.add_child(checkpoint)
	_add_label(zone, "BREAK THE SHELL • FREE THE STORM", Vector3(0, 68, 0), Color("ffd687"), 38)


func _build_bio_data_tree(parent: Node3D, at: Vector3, tree_scale: float,
		variant: int) -> Node3D:
	var tree := Node3D.new()
	tree.name = "MindSparkBioDataTree"
	# This authored assembly exposes editable named parts and owns animations.
	# It is not anonymous static scenery eligible for destructive batching.
	tree.set_meta("preserve_authored_nodes", true)
	tree.position = at
	tree.scale = Vector3.ONE * tree_scale
	tree.set_script(IslandDetailAnimator)
	tree.set("variant_index", variant)
	tree.set_meta("blueprint", "approved MindSpark Bio-Data Tree")
	tree.set_meta("design_height_m", 9.8)
	tree.set_meta("modular", true)
	tree.set_meta("nature_system", "bark transports nutrients through green fibres")
	tree.set_meta("technology_system", "cyan data fibres distribute MindSpark energy")
	parent.add_child(tree)

	_build_bio_tree_base_socket(tree)

	# The trunk is a genuinely curved assembly rather than a decorated pole.
	# Twenty-four collision-backed core slices follow an S-shaped centreline;
	# eight bark ribbons then spiral around it as 192 independently editable
	# components. Small gaps between the ribbons expose the living core.
	const TRUNK_SLICES := 24
	const BARK_RIBBONS := 8
	for segment_index in TRUNK_SLICES:
		var start_progress := float(segment_index) / float(TRUNK_SLICES)
		var finish_progress := float(segment_index + 1) / float(TRUNK_SLICES)
		var core_start := _bio_trunk_center(start_progress, variant)
		var core_finish := _bio_trunk_center(finish_progress, variant)
		_add_bio_collision_segment(tree, segment_index, core_start, core_finish,
			lerpf(3.85, 2.30, start_progress), lerpf(3.75, 2.20, finish_progress))
	for strand_index in BARK_RIBBONS:
		var previous_progress := 0.0
		var previous_angle := TAU * float(strand_index) / float(BARK_RIBBONS)
		var previous_center := _bio_trunk_center(0.0, variant)
		var previous_radius := 4.05
		var previous := previous_center + Vector3(sin(previous_angle) * previous_radius,
			0.0, cos(previous_angle) * previous_radius)
		for segment_index in TRUNK_SLICES:
			var progress := float(segment_index + 1) / float(TRUNK_SLICES)
			var angle := TAU * float(strand_index) / float(BARK_RIBBONS) \
				+ progress * TAU * 0.62 \
				+ sin(float(segment_index + strand_index * 2) * 0.41) * 0.055
			var strand_radius := lerpf(4.05, 2.45, progress)
			var center := _bio_trunk_center(progress, variant)
			var next := center + Vector3(sin(angle) * strand_radius, 0.0,
				cos(angle) * strand_radius)
			_add_cable_between(tree,
				"BioTrunkBarkCable_%02d_%02d" % [strand_index + 1, segment_index + 1],
				previous, next, lerpf(0.82, 0.44, previous_progress),
				lerpf(0.78, 0.40, progress), _materials.bio_bark_highlight \
				if strand_index % 4 == 1 else _materials.bio_bark)
			previous = next
			previous_progress = progress
	# Fine wood-grain ridges follow the same bend but use a slower twist than the
	# structural bark ribbons. Knots interrupt the repeated lines and keep the
	# trunk organic at close range.
	for grain_index in 6:
		var grain_angle_base := TAU * (float(grain_index) + 0.35) / 6.0
		var previous_center := _bio_trunk_center(0.0, variant)
		var previous_angle := grain_angle_base
		var previous := previous_center + Vector3(sin(previous_angle) * 4.92, 0.0,
			cos(previous_angle) * 4.92)
		for segment_index in TRUNK_SLICES:
			var progress := float(segment_index + 1) / float(TRUNK_SLICES)
			var angle := grain_angle_base + progress * TAU * 0.34
			var radius := lerpf(4.92, 2.90, progress)
			var next := _bio_trunk_center(progress, variant) \
				+ Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)
			_add_cable_between(tree,
				"BioBarkGrain_%02d_%02d" % [grain_index + 1, segment_index + 1],
				previous, next, 0.20, 0.14, _materials.bio_bark_highlight)
			previous = next
	for knot_index in 18:
		var progress := 0.08 + float(knot_index) / 20.0
		var angle := float(knot_index) * 2.17
		var center := _bio_trunk_center(progress, variant)
		var radius := lerpf(4.78, 2.78, progress)
		var knot_at := center + Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)
		_add_sphere(tree, "BioBarkKnot_%02d" % (knot_index + 1), knot_at,
			Vector3(0.42, 0.68, 0.22) * lerpf(1.0, 0.68, progress),
			_materials.bio_bark_highlight)

	# Cyan data and green nutrient conduits occupy deliberate cutaway grooves in
	# the bark. Each groove, fibre, and travelling packet follows the same curved
	# centreline, so the energy never detaches from the organic trunk.
	for fibre_index in 2:
		var fibre_material: Material = _materials.bio_nutrient_glow if fibre_index == 0 \
			else _materials.bio_data_glow
		var fibre_angle_base := -0.98 if fibre_index == 0 else -0.48
		var previous_angle := fibre_angle_base
		var previous_radius := 4.30
		var previous_center := _bio_trunk_center(0.0, variant)
		var previous := previous_center + Vector3(sin(previous_angle) * previous_radius,
			0.0, cos(previous_angle) * previous_radius)
		var previous_surface := previous + Vector3(sin(previous_angle) * 0.72,
			0.0, cos(previous_angle) * 0.72)
		for segment_index in TRUNK_SLICES:
			var progress := float(segment_index + 1) / float(TRUNK_SLICES)
			var angle := fibre_angle_base + progress * TAU * 0.10
			var channel_radius := lerpf(4.30, 2.62, progress)
			var center := _bio_trunk_center(progress, variant)
			var next := center + Vector3(sin(angle) * channel_radius, 0.0,
				cos(angle) * channel_radius)
			var next_surface := next + Vector3(sin(angle) * 0.72, 0.0,
				cos(angle) * 0.72)
			_add_cable_between(tree,
				("BioNutrientChannelCutaway" if fibre_index == 0 else "BioDataChannelCutaway") \
				+ "_%02d" % (segment_index + 1), previous, next, 0.46, 0.40,
				_materials.bio_gunmetal)
			_add_cable_between(tree,
				("BioNutrientFiber" if fibre_index == 0 else "BioDataFiber") \
				+ "_%02d" % (segment_index + 1), previous_surface, next_surface,
				0.18 if fibre_index == 0 else 0.16,
				0.14 if fibre_index == 0 else 0.13, fibre_material)
			_add_cable_between(tree,
				("BioNutrientPulseCell" if fibre_index == 0 else "BioDataPulseCell") \
				+ "_%02d" % (segment_index + 1),
				previous_surface.lerp(next_surface, 0.36),
				previous_surface.lerp(next_surface, 0.64),
				0.22 if fibre_index == 0 else 0.20,
				0.18 if fibre_index == 0 else 0.17, fibre_material)
			var packet_scale := Vector3(0.18, 0.28, 0.11) if fibre_index == 0 \
				else Vector3(0.15, 0.24, 0.14)
			var packet := _add_sphere(tree,
				("BioNutrientPacket" if fibre_index == 0 else "BioDataPacket") \
				+ "_%02d" % (segment_index + 1), previous_surface, packet_scale, fibre_material)
			packet.set_meta("detail_packet", true)
			packet.set_meta("packet_base_scale", packet_scale)
			packet.set_meta("path_start", previous_surface)
			packet.set_meta("path_end", next_surface)
			packet.set_meta("packet_phase", fposmod(float(segment_index) * 0.089 + fibre_index * 0.5, 1.0))
			packet.set_meta("packet_speed", 0.34 + fibre_index * 0.07)
			previous = next
			previous_surface = next_surface
	# A third, deliberately finer filament represents the arcane/mathematical
	# field binding the organic nutrient flow to the cyan technology channel.
	# It occupies its own shallow groove and never shares geometry with either.
	var magic_angle_base := 0.04
	var magic_previous_angle := magic_angle_base
	var magic_previous_center := _bio_trunk_center(0.0, variant)
	var magic_previous := magic_previous_center + Vector3(
		sin(magic_previous_angle) * 4.30, 0.0,
		cos(magic_previous_angle) * 4.30)
	var magic_previous_surface := magic_previous + Vector3(
		sin(magic_previous_angle) * 0.72, 0.0,
		cos(magic_previous_angle) * 0.72)
	for segment_index in TRUNK_SLICES:
		var progress := float(segment_index + 1) / float(TRUNK_SLICES)
		var magic_angle := magic_angle_base + progress * TAU * 0.10
		var magic_channel_radius := lerpf(4.30, 2.62, progress)
		var magic_center := _bio_trunk_center(progress, variant)
		var magic_next := magic_center + Vector3(
			sin(magic_angle) * magic_channel_radius, 0.0,
			cos(magic_angle) * magic_channel_radius)
		var magic_next_surface := magic_next + Vector3(
			sin(magic_angle) * 0.72, 0.0,
			cos(magic_angle) * 0.72)
		_add_cable_between(tree, "BioMagicChannelCutaway_%02d" % (segment_index + 1),
			magic_previous, magic_next, 0.30, 0.24, _materials.bio_gunmetal)
		_add_cable_between(tree, "BioMagicFiber_%02d" % (segment_index + 1),
			magic_previous_surface, magic_next_surface, 0.11, 0.085,
			_materials.island_violet_energy)
		_add_cable_between(tree, "BioMagicRuneCell_%02d" % (segment_index + 1),
			magic_previous_surface.lerp(magic_next_surface, 0.42),
			magic_previous_surface.lerp(magic_next_surface, 0.58),
			0.14, 0.12, _materials.island_violet_energy)
		magic_previous = magic_next
		magic_previous_surface = magic_next_surface
	# Small green capillaries leave the primary nutrient conduit and disappear
	# beneath nearby bark scales, mirroring a living tree's transport network.
	for capillary_index in 16:
		var progress := 0.10 + float(capillary_index) / 19.0
		var source_angle := -0.98 + progress * TAU * 0.10
		var center := _bio_trunk_center(progress, variant)
		var trunk_radius := lerpf(5.22, 3.54, progress)
		var source := center + Vector3(sin(source_angle) * trunk_radius, 0.0,
			cos(source_angle) * trunk_radius)
		var target_angle := source_angle + (-0.42 if capillary_index % 2 == 0 else 0.46)
		var target := center + Vector3(sin(target_angle) * (trunk_radius - 0.18),
			1.1 + float(capillary_index % 3) * 0.35,
			cos(target_angle) * (trunk_radius - 0.18))
		_add_cable_between(tree, "BioNutrientCapillary_%02d" % (capillary_index + 1),
			source, target, 0.07, 0.035, _materials.bio_nutrient_glow)

	# Eight buildable leaf-petal panels form the technological lower canopy.
	var canopy_height := 68.0
	_add_cylinder(tree, "BioCanopyHub", Vector3(0, canopy_height, 0), 6.4, 2.4,
		_materials.bio_gunmetal, false, 16)
	_add_torus(tree, "BioCanopyGoldRing", Vector3(0, canopy_height + 1.3, 0),
		5.0, 6.4, _materials.island_gold)
	_add_torus(tree, "BioCanopyEnergyRing", Vector3(0, canopy_height - 1.0, 0),
		4.4, 5.4, _materials.island_cyan)
	for leaf_index in 8:
		var leaf_angle := TAU * float(leaf_index) / 8.0 + PI * 0.125
		_add_bio_leaf_panel(tree, leaf_index, leaf_angle, canopy_height - 1.0)

	# Eight multi-segment branches build the broad, tiered crown from the new
	# reference. Every branch tapers, bends upward, carries a cyan data fibre,
	# supports two smaller leaves, and terminates inside a mushroom stem socket.
	const CROWN_BRANCHES := 8
	# Alternate clean lower/upper tiers around the leaf plane at y=67.
	var branch_heights := [58.5, 72.5, 60.0, 73.5, 59.0, 74.0, 60.5, 72.8]
	var branch_lengths := [29.0, 34.0, 31.0, 35.0, 30.0, 36.0, 32.0, 34.0]
	var branch_cap_radii := [8.0, 7.2, 8.6, 7.6, 8.2, 7.4, 8.8, 7.8]
	var branch_angle_offsets := [-0.08, 0.05, -0.04, 0.07, -0.06, 0.04, -0.07, 0.06]
	for branch_index in CROWN_BRANCHES:
		# Branches grow midway between the eight leaf-petal axes, leaving a clear
		# radial lane for each hanging node instead of layering props together.
		var branch_angle := TAU * float(branch_index) / float(CROWN_BRANCHES) \
			+ float(branch_angle_offsets[branch_index])
		var radial := Vector3(sin(branch_angle), 0, cos(branch_angle))
		var tangent := Vector3(cos(branch_angle), 0, -sin(branch_angle))
		var branch_progress := 0.58 + float(branch_index % 4) * 0.055
		var branch_start := _bio_trunk_center(branch_progress, variant)
		var cap_height: float = branch_heights[branch_index]
		var cap_radius: float = branch_cap_radii[branch_index]
		var cap_bubble_height := maxf(cap_radius * 0.30, cap_radius * 0.27)
		var cap_position := radial * float(branch_lengths[branch_index]) \
			+ Vector3.UP * cap_height
		var branch_finish := cap_position - Vector3.UP * (cap_bubble_height + 2.0)
		var control_a := branch_start + radial * (float(branch_lengths[branch_index]) * 0.34) \
			+ tangent * (2.6 if branch_index % 2 == 0 else -2.2) + Vector3.UP * 5.2
		var control_b := branch_finish - radial * (float(branch_lengths[branch_index]) * 0.24) \
			+ tangent * (-1.8 if branch_index % 2 == 0 else 2.1) + Vector3.UP * 2.0
		var branch_points: Array[Vector3] = [branch_start]
		var previous := branch_start
		for branch_segment in 10:
			var progress := float(branch_segment + 1) / 10.0
			var inverse := 1.0 - progress
			var next := branch_start * (inverse * inverse * inverse) \
				+ control_a * (3.0 * inverse * inverse * progress) \
				+ control_b * (3.0 * inverse * progress * progress) \
				+ branch_finish * (progress * progress * progress)
			var start_width := lerpf(1.42, 0.46, float(branch_segment) / 10.0)
			var end_width := lerpf(1.42, 0.46, progress)
			_add_cable_between(tree,
				"BioCanopyBranch_%02d_%02d" % [branch_index + 1, branch_segment + 1],
				previous, next, start_width, end_width, _materials.bio_bark, 14)
			_add_cable_between(tree,
				"BioCanopyBranchFiber_%02d_%02d" % [branch_index + 1, branch_segment + 1],
				previous + Vector3.UP * start_width * 0.52,
				next + Vector3.UP * end_width * 0.52,
				start_width * 0.10, end_width * 0.10, _materials.bio_data_glow, 10)
			_add_cable_between(tree,
				"BioCanopyBranchGrain_%02d_%02d" % [branch_index + 1, branch_segment + 1],
				previous + Vector3.UP * start_width * 0.78,
				next + Vector3.UP * end_width * 0.78,
				0.060, 0.035, _materials.bio_bark_highlight, 8)
			_add_cable_between(tree,
				"BioCanopyBranchNutrient_%02d_%02d" % [branch_index + 1, branch_segment + 1],
				previous + tangent * start_width * 0.42 + Vector3.UP * start_width * 0.18,
				next + tangent * end_width * 0.42 + Vector3.UP * end_width * 0.18,
				0.052, 0.030, _materials.bio_nutrient_glow, 8)
			branch_points.append(next)
			previous = next
		for leaf_slot in 2:
			var leaf_base: Vector3 = branch_points[4 + leaf_slot * 3]
			var leaf_direction := (radial.rotated(Vector3.UP,
				(-0.52 if leaf_slot == 0 else 0.52)) + Vector3.UP * 0.34).normalized()
			_add_bio_branch_leaf(tree, branch_index, leaf_slot, leaf_base,
				leaf_direction, 9.6 - float(leaf_slot) * 0.8)
		_add_bio_mushroom_cap(tree, "%02d" % (branch_index + 1), cap_position,
			cap_radius, cap_radius * 0.27)
	# The large five-lobed crown sits above the branch tiers instead of replacing
	# them, creating the full, mature silhouette visible in the reference.
	_add_bio_mushroom_cap(tree, "Main", Vector3(0, 78.0, 0), 15.5, 4.6)
	# Crown crystal and a subtle local light complete the approved silhouette.
	var crown_crystal := _add_brick(tree, "BioCrownCrystal", Vector3(0, 90.0, 0),
		_build_sharp_crown_crystal_mesh(3.60, 10.4, 6), _materials.bio_crown_crystal)
	crown_crystal.set_meta("crystal_form", "sharp_double_point_faceted")
	crown_crystal.set_meta("facet_sides", 6)
	crown_crystal.set_meta("outline_geometry", "six upper, six lower, six girdle edges")
	_add_brick(tree, "BioCrownInnerCore", Vector3(0, 90.0, 0),
		_build_sharp_crown_crystal_mesh(0.70, 8.4, 6), _materials.bio_data_glow)
	for facet_index in 6:
		var facet_angle := TAU * float(facet_index) / 6.0
		var next_angle := TAU * float(facet_index + 1) / 6.0
		var belt := Vector3(sin(facet_angle) * 3.82, 89.20,
			cos(facet_angle) * 3.82)
		var next_belt := Vector3(sin(next_angle) * 3.82, 89.20,
			cos(next_angle) * 3.82)
		_add_cable_between(tree, "CrownCrystalOutlineUpper_%02d" % (facet_index + 1),
			Vector3(0, 95.45, 0), belt, 0.085, 0.070, _materials.bio_crown_outline)
		_add_cable_between(tree, "CrownCrystalOutlineLower_%02d" % (facet_index + 1),
			belt, Vector3(0, 84.55, 0), 0.070, 0.085, _materials.bio_crown_outline)
		_add_cable_between(tree, "CrownCrystalOutlineGirdle_%02d" % (facet_index + 1),
			belt, next_belt, 0.070, 0.070, _materials.bio_crown_outline)
	_add_cable_between(tree, "CrownCrystalInnerSpine",
		Vector3(0, 95.05, 0), Vector3(0, 84.95, 0),
		0.050, 0.050, _materials.bio_crown_outline)
	_add_cylinder(tree, "BioCrownSocket", Vector3(0, 84.8, 0), 4.2, 2.4,
		_materials.bio_gunmetal, false, 12)
	_add_torus(tree, "BioCrownGoldCollar", Vector3(0, 86.0, 0), 3.3, 4.3,
		_materials.island_gold)
	_add_torus(tree, "BioCrownEnergyCoupler", Vector3(0, 83.8, 0), 2.5, 3.4,
		_materials.bio_data_glow)
	_add_zone_light(tree, Vector3(0, 78.0, 0), Color("52e8ff"), 72.0, 2.8)
	return tree


func _build_bio_tree_base_socket(tree: Node3D) -> void:
	# A compact magitech root coupler: segmented alloy carries the load while
	# separate cyan data and green nutrient feeds visibly enter the living trunk.
	var socket := Node3D.new()
	socket.name = "BioTreeBaseSocketAssembly"
	socket.set_meta("editable_component", true)
	socket.set_meta("assembly_role", "structural root lock and dual-flow transfer socket")
	socket.set_meta("armor_sector_count", 12)
	socket.set_meta("trunk_lock_count", 6)
	socket.set_meta("editable_piece_count", 280)
	socket.set_meta("construction_method", "nested Lego-like replaceable subassemblies")
	socket.set_meta("trunk_outer_envelope_radius", 5.24)
	socket.set_meta("gold_collar_inner_radius", 5.55)
	socket.set_meta("minimum_collar_clearance", 0.31)
	socket.set_meta("flow_routing", "surface feeds terminate at collar ports without intersections")
	tree.add_child(socket)
	var structural_core := _add_cylinder(socket, "BioBaseStructuralCore",
		Vector3(0, 1.15, 0), 8.7, 2.3,
		_materials.island_rim, true, 24)
	structural_core.set_meta("editable_component", true)
	var inner_cradle := _add_cylinder(socket, "BioBaseInnerCradle",
		Vector3(0, 2.65, 0), 6.7, 1.5,
		_materials.bio_gunmetal, false, 24)
	inner_cradle.set_meta("editable_component", true)
	var lower_seal := _add_torus(socket, "BioBaseLowerEnergySeal",
		Vector3(0, 0.82, 0), 7.95, 8.42,
		_materials.island_cyan)
	lower_seal.set_meta("editable_component", true)
	var data_seal := _add_torus(socket, "BioBaseInnerDataSeal",
		Vector3(0, 3.38, 0), 5.30, 5.60,
		_materials.bio_data_glow)
	data_seal.set_meta("editable_component", true)
	const SOCKET_SECTORS := 12
	for socket_index in SOCKET_SECTORS:
		var angle_step := TAU / float(SOCKET_SECTORS)
		var center_angle := angle_step * float(socket_index)
		var gap := angle_step * 0.075
		var outward := Vector3(sin(center_angle), 0, cos(center_angle))
		var armor := _add_radial_plate(socket,
			"BioBaseArmorSector_%02d" % (socket_index + 1),
			center_angle - angle_step * 0.5 + gap,
			center_angle + angle_step * 0.5 - gap,
			6.15, 9.35, 0.18, 1.42,
			_materials.island_rim if socket_index % 2 == 0 else _materials.bio_gunmetal)
		armor.set_meta("editable_component", true)
		armor.set_meta("socket_piece", "load-bearing radial armor")
		var shoulder := _add_radial_plate(socket,
			"BioBaseShoulderPlate_%02d" % (socket_index + 1),
			center_angle - angle_step * 0.5 + gap * 1.45,
			center_angle + angle_step * 0.5 - gap * 1.45,
			4.75, 7.55, 1.46, 2.35, _materials.bio_gunmetal)
		shoulder.set_meta("editable_component", true)
		shoulder.set_meta("socket_piece", "replaceable trunk shoulder plate")
		var bezel := _add_radial_plate(socket,
			"BioBaseUpperBezel_%02d" % (socket_index + 1),
			center_angle - angle_step * 0.5 + gap * 1.15,
			center_angle + angle_step * 0.5 - gap * 1.15,
			5.15, 7.18, 2.38, 3.13,
			_materials.island_rim if socket_index % 3 else _materials.bio_gunmetal)
		bezel.set_meta("editable_component", true)
		bezel.set_meta("socket_piece", "upper segmented machinery bezel")
		var gold_collar := _add_radial_plate(socket,
			"BioBaseGoldCollarSegment_%02d" % (socket_index + 1),
			center_angle - angle_step * 0.5 + gap * 0.70,
			center_angle + angle_step * 0.5 - gap * 0.70,
			5.55, 7.05, 3.58, 4.30, _materials.bio_socket_gold)
		gold_collar.set_meta("editable_component", true)
		gold_collar.set_meta("socket_piece", "independent gold trunk collar brick")
		var collar_seam := _add_box(socket,
			"BioBaseGoldCollarSeam_%02d" % (socket_index + 1),
			outward * 6.30 + Vector3.UP * 4.33, Vector3(0.26, 0.16, 0.72),
				_materials.bio_gunmetal, false, center_angle)
		collar_seam.set_meta("editable_component", true)
		# Four independent top-surface cells per armor sector make the lower ring
		# genuinely reconfigurable instead of one wedge with decorative paint.
		for micro_index in 4:
			var micro_angle_start := lerpf(center_angle - angle_step * 0.5 + gap * 1.35,
				center_angle + angle_step * 0.5 - gap * 1.35, float(micro_index) / 4.0)
			var micro_angle_end := lerpf(center_angle - angle_step * 0.5 + gap * 1.35,
				center_angle + angle_step * 0.5 - gap * 1.35, float(micro_index + 1) / 4.0)
			var top_cell := _add_radial_plate(socket,
				"BioBaseArmorMicroCell_%02d_%02d" % [socket_index + 1, micro_index + 1],
				micro_angle_start, micro_angle_end, 6.28, 9.18, 1.425, 1.505,
				_materials.island_deck_panel_a if micro_index % 2 == 0 else _materials.island_rim)
			top_cell.set_meta("editable_component", true)
			top_cell.set_meta("micro_component", "quarter-sector armor surface brick")
		# Three nested circuit inserts break each shoulder down again into small,
		# removable radial cells like the supplied socket reference.
		for circuit_index in 3:
			var circuit_inner := 4.95 + float(circuit_index) * 0.78
			var circuit_cell := _add_radial_plate(socket,
				"BioBaseShoulderCircuitCell_%02d_%02d" % [socket_index + 1, circuit_index + 1],
				center_angle - angle_step * 0.29,
				center_angle + angle_step * 0.29,
				circuit_inner, circuit_inner + 0.58, 2.355, 2.445,
				_materials.bio_socket_gold if circuit_index == 0 else \
					(_materials.island_cyan if circuit_index == 2 else _materials.island_deck_panel_b))
			circuit_cell.set_meta("editable_component", true)
			circuit_cell.set_meta("micro_component", "recessed socket circuit insert")
		var service_at := outward * 8.55 + Vector3.UP * 1.12
		var service_cell := _add_box(socket,
			"BioBaseServiceCell_%02d" % (socket_index + 1), service_at,
			Vector3(3.12, 1.32, 0.82), _materials.bio_gunmetal, false, center_angle)
		service_cell.set_meta("editable_component", true)
		service_cell.set_meta("socket_piece", "removable outer service housing")
		for cheek_side in [-1.0, 1.0]:
			var tangent := Vector3(cos(center_angle), 0, -sin(center_angle))
			var cheek := _add_box(socket,
				"BioBaseServiceCheek_%02d_%s" % [socket_index + 1, "L" if cheek_side < 0 else "R"],
				service_at + tangent * cheek_side * 1.48 + outward * 0.12,
				Vector3(0.34, 1.46, 0.48), _materials.island_rim, false, center_angle)
			cheek.set_meta("editable_component", true)
		var status_window := _add_box(socket,
			"BioBaseStatusWindow_%02d" % (socket_index + 1),
			outward * 9.01 + Vector3.UP * 1.47, Vector3(0.78, 0.32, 0.16),
			_materials.island_cyan if socket_index % 3 else _materials.island_root,
			false, center_angle)
		status_window.set_meta("editable_component", true)
		var gold_indicator := _add_box(socket,
			"BioBaseGoldIndicator_%02d" % (socket_index + 1),
			outward * 9.02 + Vector3.UP * 0.77, Vector3(1.08, 0.25, 0.17),
			_materials.bio_socket_gold, false, center_angle)
		gold_indicator.set_meta("editable_component", true)
		var face_seam := _add_box(socket,
			"BioBaseFaceDivider_%02d" % (socket_index + 1),
			outward * 9.04 + Vector3.UP * 1.10, Vector3(0.16, 1.14, 0.15),
			_materials.island_rim, false, center_angle)
		face_seam.set_meta("editable_component", true)
		var top_fastener := _add_cylinder(socket, "BioBaseFastener_%02d" % (socket_index + 1),
			outward * 6.70 + Vector3.UP * 2.49, 0.25, 0.20,
			_materials.bio_socket_gold, false, 8)
		top_fastener.set_meta("editable_component", true)
		var tangent := Vector3(cos(center_angle), 0, -sin(center_angle))
		for bolt_index in 2:
			var bolt_side := -1.0 if bolt_index == 0 else 1.0
			var face_bolt := _add_sphere(socket,
				"BioBaseFaceBolt_%02d_%02d" % [socket_index + 1, bolt_index + 1],
				outward * 9.08 + tangent * bolt_side * 1.15 + Vector3.UP * 1.07,
				Vector3.ONE * 0.12, _materials.bio_socket_gold)
			face_bolt.set_meta("editable_component", true)
		var feed_material: Material = _materials.bio_data_glow \
			if socket_index % 2 == 0 else _materials.bio_nutrient_glow
		var feed_start := outward * 8.15 + Vector3.UP * 2.44
		var feed_finish := outward * 7.12 + Vector3.UP * 3.34
		var flow_feed := _add_cable_between(socket,
			"BioBaseFlowFeed_%02d" % (socket_index + 1),
			feed_start, feed_finish, 0.040, 0.026, feed_material)
		flow_feed.set_meta("path_start", feed_start)
		flow_feed.set_meta("path_end", feed_finish)
		flow_feed.set_meta("collar_safe_route", true)
		if socket_index % 2 == 0:
			var brace_start := outward * 7.10 + Vector3.UP * 2.30
			var brace_finish := outward * 5.62 + Vector3.UP * 3.30
			_add_cable_between(socket,
				"BioBaseTrunkLock_%02d" % (socket_index / 2 + 1),
				brace_start, brace_finish, 0.28, 0.20, _materials.bio_gunmetal)
			_add_cable_between(socket,
				"BioBaseTrunkLockInlay_%02d" % (socket_index / 2 + 1),
				brace_start + Vector3.UP * 0.04, brace_finish + Vector3.UP * 0.04,
				0.045, 0.032, _materials.bio_socket_gold)


func _bio_trunk_center(progress: float, variant: int) -> Vector3:
	var clamped := clampf(progress, 0.0, 1.0)
	var variant_phase := float(variant % 5) * 0.11
	# Both waves return to zero at the canopy socket, keeping the crown aligned
	# while allowing a pronounced, natural S-curve through the living trunk.
	var x := sin(clamped * TAU) * (5.2 + sin(clamped * PI) * 1.4)
	var z := sin(clamped * TAU * 1.5) * 2.4 \
		+ sin(clamped * TAU) * variant_phase
	return Vector3(x, 4.0 + clamped * 64.0, z)


func _add_bio_collision_segment(parent: Node3D, segment_index: int,
		start: Vector3, finish: Vector3, start_radius: float,
		end_radius: float) -> void:
	_add_cable_between(parent, "BioLivingCoreSlice_%02d" % (segment_index + 1),
		start, finish, start_radius, end_radius, _materials.bio_bark)
	var direction := finish - start
	var body := StaticBody3D.new()
	body.name = "BioLivingCoreSlice_%02dCollision" % (segment_index + 1)
	body.position = start.lerp(finish, 0.5)
	if not direction.is_zero_approx():
		body.quaternion = Quaternion(Vector3.UP, direction.normalized())
	var shape_node := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = minf(start_radius, end_radius)
	shape.height = maxf(0.01, direction.length())
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)


func _add_bio_mushroom_cap(parent: Node3D, cap_id: String, at: Vector3,
		radius: float, height: float) -> void:
	# One complete biconvex bubble: the full ellipsoid curves above and below its
	# widest edge. The underside is never cut, flattened or replaced by a disc.
	var bubble_height := maxf(height, radius * 0.30)
	_add_cable_between(parent, "MushroomStemSocket_%s" % cap_id,
		at + Vector3.DOWN * (bubble_height + 2.0),
		at + Vector3.DOWN * (bubble_height * 0.62),
		maxf(0.55, radius * 0.085), maxf(0.40, radius * 0.060),
		_materials.bio_gunmetal, 14)
	_add_torus(parent, "MushroomGoldCollar_%s" % cap_id,
		at + Vector3.DOWN * (bubble_height + 1.25), radius * 0.055,
		radius * 0.095, _materials.island_gold)
	const SHELL_COLUMNS := 24
	var ring_radius := [0.12, 0.25, 0.39, 0.54, 0.68, 0.81, 0.92, 1.0]
	var upper_rings: Array[Array] = []
	var lower_rings: Array[Array] = []
	var phase := float(cap_id.hash() % 17) * 0.019
	var leaf_lobes := 5 if cap_id == "Main" else 4
	var leaf_amplitude := 0.10 if cap_id == "Main" else 0.06
	for ring_index in ring_radius.size():
		var upper_ring: Array[Vector3] = []
		var lower_ring: Array[Vector3] = []
		var radial_progress: float = ring_radius[ring_index]
		var surface_height := bubble_height * sqrt(maxf(0.0,
			1.0 - radial_progress * radial_progress))
		for cell_index in SHELL_COLUMNS:
			var angle := TAU * float(cell_index) / float(SHELL_COLUMNS) + phase \
				+ sin(float(cell_index * 5 + ring_index * 7)) * 0.038
			var wobble := 1.0 + sin(float(cell_index * 7 + ring_index * 13)) * 0.018
			var leaf_shape := 1.0 + leaf_amplitude * pow(radial_progress, 1.35) \
				* cos(float(leaf_lobes) * (angle - phase))
			var x := sin(angle) * radius * radial_progress * wobble * leaf_shape
			var z := cos(angle) * radius * radial_progress * wobble * leaf_shape
			upper_ring.append(at + Vector3(x, surface_height, z))
			lower_ring.append(at + Vector3(x, -surface_height, z))
		upper_rings.append(upper_ring)
		lower_rings.append(lower_ring)
	# Follow the organic leaf-lobed perimeter with short solid seal segments;
	# a circular torus would float outside valleys and cut through leaf tips.
	for cell_index in SHELL_COLUMNS:
		_add_cable_between(parent,
			"MushroomEquatorSeal_%s_%02d" % [cap_id, cell_index + 1],
			upper_rings[-1][cell_index],
			upper_rings[-1][(cell_index + 1) % SHELL_COLUMNS],
			radius * 0.018, radius * 0.018, _materials.bio_mushroom_dark)
	var upper_crown := at + Vector3.UP * bubble_height
	var lower_crown := at + Vector3.DOWN * bubble_height
	var bubble: MeshInstance3D
	for cell_index in SHELL_COLUMNS:
		_add_mushroom_triangle_cell(parent,
			"MushroomFacetUpper_%s_R00_%02d" % [cap_id, cell_index + 1], upper_crown,
			upper_rings[0][cell_index], upper_rings[0][(cell_index + 1) % SHELL_COLUMNS],
			_mushroom_bubble_material(0, cell_index))
		var lower_name := "BioMushroomCap_%s" % cap_id if cell_index == 0 else \
			"MushroomFacetLower_%s_R00_%02d" % [cap_id, cell_index + 1]
		var lower_cell := _add_mushroom_triangle_cell(parent, lower_name, lower_crown,
			lower_rings[0][cell_index], lower_rings[0][(cell_index + 1) % SHELL_COLUMNS],
			_mushroom_bubble_material(0, cell_index), true)
		if cell_index == 0:
			bubble = lower_cell
	for ring_index in ring_radius.size() - 1:
		for cell_index in SHELL_COLUMNS:
			_add_mushroom_quad_cell(parent,
				"MushroomFacetUpper_%s_R%02d_%02d" % [cap_id, ring_index + 1, cell_index + 1],
				upper_rings[ring_index][cell_index], upper_rings[ring_index + 1][cell_index],
				upper_rings[ring_index + 1][(cell_index + 1) % SHELL_COLUMNS],
				upper_rings[ring_index][(cell_index + 1) % SHELL_COLUMNS],
				_mushroom_bubble_material(ring_index + 1, cell_index))
			_add_mushroom_quad_cell(parent,
				"MushroomFacetLower_%s_R%02d_%02d" % [cap_id, ring_index + 1, cell_index + 1],
				lower_rings[ring_index][cell_index], lower_rings[ring_index + 1][cell_index],
				lower_rings[ring_index + 1][(cell_index + 1) % SHELL_COLUMNS],
				lower_rings[ring_index][(cell_index + 1) % SHELL_COLUMNS],
				_mushroom_bubble_material(ring_index + 1, cell_index), true)
	bubble.set_meta("editable_component", true)
	bubble.set_meta("mushroom_cap_form", "full_biconvex_bubble")
	bubble.set_meta("upper_curve", bubble_height)
	bubble.set_meta("lower_curve", bubble_height)
	bubble.set_meta("seamless_shell", true)
	bubble.set_meta("leaf_lobe_count", leaf_lobes)
	bubble.set_meta("cap_center_y", at.y)
	bubble.set_meta("cap_center", at)
	bubble.set_meta("cap_radius", radius)
	bubble.set_meta("cap_half_height", bubble_height)
	bubble.set_meta("canopy_tier", "below_leaf" if at.y + bubble_height < 65.0 \
		else "above_leaf")
	# Raised branch-like veins explain the organic cap structure while keeping
	# every vein independently editable and mirrored on both faces.
	for lobe_index in leaf_lobes:
		var vein_angle := phase + TAU * float(lobe_index) / float(leaf_lobes)
		for vein_segment in 3:
			var start_progress := 0.16 + float(vein_segment) * 0.25
			var end_progress := start_progress + 0.25
			var upper_start := _mushroom_leaf_surface_point(at, radius, bubble_height,
				start_progress, vein_angle, phase, leaf_lobes, leaf_amplitude, true)
			var upper_end := _mushroom_leaf_surface_point(at, radius, bubble_height,
				end_progress, vein_angle, phase, leaf_lobes, leaf_amplitude, true)
			var lower_start := _mushroom_leaf_surface_point(at, radius, bubble_height,
				start_progress, vein_angle, phase, leaf_lobes, leaf_amplitude, false)
			var lower_end := _mushroom_leaf_surface_point(at, radius, bubble_height,
				end_progress, vein_angle, phase, leaf_lobes, leaf_amplitude, false)
			_add_cable_between(parent,
				"MushroomLeafVeinUpper_%s_%02d_%02d" % [cap_id, lobe_index + 1, vein_segment + 1],
				upper_start + Vector3.UP * 0.10, upper_end + Vector3.UP * 0.10,
				radius * 0.009, radius * 0.006, _materials.bio_mushroom_mid)
			_add_cable_between(parent,
				"MushroomLeafVeinLower_%s_%02d_%02d" % [cap_id, lobe_index + 1, vein_segment + 1],
				lower_start + Vector3.DOWN * 0.10, lower_end + Vector3.DOWN * 0.10,
				radius * 0.009, radius * 0.006, _materials.bio_mushroom_mid)
	for stone_index in 8:
		var angle := float(stone_index) * 2.37 + phase
		var progress := 0.16 + float((stone_index * 3) % 5) * 0.11
		var distance := radius * progress
		var stone_at := at + Vector3(sin(angle) * distance,
			bubble_height * sqrt(maxf(0.0, 1.0 - progress * progress)) + 0.14,
			cos(angle) * distance)
		_add_sphere(parent, "MushroomGlowStone_%s_%02d" % [cap_id, stone_index + 1],
			stone_at, Vector3(radius * 0.034, bubble_height * 0.045, radius * 0.027),
			_materials.bio_mushroom_spot)
		_add_sphere(parent, "MushroomGlowStoneBottom_%s_%02d" % [cap_id, stone_index + 1],
			Vector3(stone_at.x, at.y - (stone_at.y - at.y), stone_at.z),
			Vector3(radius * 0.034, bubble_height * 0.045, radius * 0.027),
			_materials.bio_mushroom_spot)


func _mushroom_leaf_surface_point(at: Vector3, radius: float, bubble_height: float,
		radial_progress: float, angle: float, phase: float, leaf_lobes: int,
		leaf_amplitude: float, upper: bool) -> Vector3:
	var leaf_shape := 1.0 + leaf_amplitude * pow(radial_progress, 1.35) \
		* cos(float(leaf_lobes) * (angle - phase))
	var height_sign := 1.0 if upper else -1.0
	return at + Vector3(
		sin(angle) * radius * radial_progress * leaf_shape,
		height_sign * bubble_height * sqrt(maxf(0.0, 1.0 - radial_progress * radial_progress)),
		cos(angle) * radius * radial_progress * leaf_shape)


func _build_sharp_crown_crystal_mesh(radius: float, height: float,
		sides: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side_count := maxi(4, sides)
	var step := TAU / float(side_count)
	var lower_tip := Vector3(0, -height * 0.5, 0)
	var upper_tip := Vector3(0, height * 0.5, 0)
	var belt_y := -height * 0.08
	for side_index in side_count:
		var angle_a := step * float(side_index)
		var angle_b := step * float(side_index + 1)
		var light_mix := 0.72 + 0.28 * (cos((angle_a + angle_b) * 0.5) * 0.5 + 0.5)
		light_mix *= 1.10 if side_index % 2 == 0 else 0.76
		var lower_color := Color(0.05 * light_mix, 0.40 * light_mix,
			0.68 * light_mix, 1.0)
		var upper_color := Color(0.14 * light_mix, 0.68 * light_mix,
			0.96 * light_mix, 1.0)
		var girdle_a := Vector3(sin(angle_a) * radius, belt_y,
			cos(angle_a) * radius)
		var girdle_b := Vector3(sin(angle_b) * radius, belt_y,
			cos(angle_b) * radius)
		_add_colored_crystal_triangle(surface, girdle_a, girdle_b, upper_tip, upper_color)
		_add_colored_crystal_triangle(surface, lower_tip, girdle_b, girdle_a, lower_color)
	surface.generate_normals()
	return surface.commit()


func _add_colored_crystal_triangle(surface: SurfaceTool, a: Vector3, b: Vector3,
		c: Vector3, color: Color) -> void:
	for point in [a, b, c]:
		surface.set_color(color)
		surface.add_vertex(point)


func _mushroom_bubble_material(ring_index: int, cell_index: int) -> Material:
	# Keep the shell visually continuous: most cells share the base violet, with
	# sparse highlights that reveal curvature without a checkerboard prototype look.
	var selector := (ring_index * 5 + cell_index * 3) % 17
	if selector == 0:
		return _materials.bio_mushroom_light
	if selector in [4, 10]:
		return _materials.bio_mushroom_mid
	return _materials.bio_mushroom


func _add_mushroom_triangle_cell(parent: Node3D, node_name: String, a: Vector3,
		b: Vector3, c: Vector3, material: Material,
		flip_winding := false) -> MeshInstance3D:
	var center := (a + b + c) / 3.0
	# Adjacent cells share their exact boundary vertices. Do not inset them: an
	# inset creates literal holes that read as an unfinished exploded prototype.
	var inset := 1.0
	a = center + (a - center) * inset
	b = center + (b - center) * inset
	c = center + (c - center) * inset
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := [a, c, b] if flip_winding else [a, b, c]
	for point in vertices:
		surface.add_vertex(point)
	surface.generate_normals()
	var cell := MeshInstance3D.new()
	cell.name = node_name
	cell.mesh = surface.commit()
	cell.material_override = material
	cell.set_meta("editable_component", true)
	parent.add_child(cell)
	return cell


func _add_mushroom_quad_cell(parent: Node3D, node_name: String, a: Vector3,
		b: Vector3, c: Vector3, d: Vector3, material: Material,
		flip_winding := false) -> MeshInstance3D:
	var center := (a + b + c + d) * 0.25
	var inset := 1.0
	a = center + (a - center) * inset
	b = center + (b - center) * inset
	c = center + (c - center) * inset
	d = center + (d - center) * inset
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := [a, d, c, a, c, b] if flip_winding else [a, b, c, a, c, d]
	for point in vertices:
		surface.add_vertex(point)
	surface.generate_normals()
	var cell := MeshInstance3D.new()
	cell.name = node_name
	cell.mesh = surface.commit()
	cell.material_override = material
	cell.set_meta("editable_component", true)
	parent.add_child(cell)
	return cell


func _add_bio_branch_leaf(parent: Node3D, branch_index: int, leaf_slot: int,
		base: Vector3, direction: Vector3, size: float) -> void:
	var forward := direction.normalized()
	var horizontal := Vector3(forward.x, 0, forward.z).normalized()
	if horizontal.is_zero_approx():
		horizontal = Vector3.FORWARD
	var tangent := Vector3.UP.cross(horizontal).normalized()
	var shoulder := base + forward * size * 0.22
	var left_base := shoulder + tangent * size * 0.20
	var left := base + forward * size * 0.58 + tangent * size * 0.34
	var tip := base + forward * size
	var right := base + forward * size * 0.58 - tangent * size * 0.34
	var right_base := shoulder - tangent * size * 0.20
	var center := base + forward * size * 0.52 + Vector3.UP * size * 0.035
	var boundary := [base, left_base, left, tip, right, right_base]
	for cell_index in boundary.size():
		_add_mushroom_triangle_cell(parent,
			"BioBranchLeaf_%02d_%02d_Cell_%02d" % \
				[branch_index + 1, leaf_slot + 1, cell_index + 1],
			center, boundary[cell_index], boundary[(cell_index + 1) % boundary.size()],
			_materials.bio_leaf_panel_alt if cell_index % 2 == 0 \
			else _materials.bio_leaf_panel)
	for edge_index in boundary.size():
		_add_cable_between(parent,
			"BioBranchLeafGoldEdge_%02d_%02d_%02d" % \
				[branch_index + 1, leaf_slot + 1, edge_index + 1],
			boundary[edge_index], boundary[(edge_index + 1) % boundary.size()],
			0.13, 0.10, _materials.island_gold)
	_add_cable_between(parent,
		"BioBranchLeafDataVein_%02d_%02d" % [branch_index + 1, leaf_slot + 1],
		base + Vector3.UP * 0.10, tip + Vector3.UP * 0.10,
		0.12, 0.07, _materials.bio_data_glow)


func _add_bio_leaf_panel(parent: Node3D, leaf_index: int, angle: float,
		height: float) -> void:
	var radial := Vector3(sin(angle), 0, cos(angle))
	var tangent := Vector3(cos(angle), 0, -sin(angle))
	var inner := radial * 6.5 + Vector3.UP * height
	var left_base := radial * 11.0 - tangent * 3.0 + Vector3.UP * (height + 0.25)
	var left := radial * 21.0 - tangent * 7.0 + Vector3.UP * (height + 0.7)
	var tip := radial * 34.0 + Vector3.UP * (height - 0.6)
	var right := radial * 21.0 + tangent * 7.0 + Vector3.UP * (height + 0.7)
	var right_base := radial * 11.0 + tangent * 3.0 + Vector3.UP * (height + 0.25)
	var center := radial * 20.0 + Vector3.UP * (height + 0.35)
	var points := [inner, left_base, left, tip, right, right_base]
	for cell_index in 6:
		_add_triangle_patch(parent,
			"BioLeafPanel_%02d_Cell_%02d" % [leaf_index + 1, cell_index + 1],
			center, points[cell_index], points[(cell_index + 1) % 6],
			_materials.bio_leaf_panel_alt if cell_index % 2 == 0 \
			else _materials.bio_leaf_panel)
	for edge_index in 6:
		_add_cable_between(parent,
			"BioLeafGoldEdge_%02d_%02d" % [leaf_index + 1, edge_index + 1],
			points[edge_index], points[(edge_index + 1) % 6], 0.30, 0.24,
			_materials.island_gold)
	_add_cable_between(parent, "BioLeafCyanVein_%02d" % (leaf_index + 1),
		inner + Vector3.UP * 0.16, tip + Vector3.UP * 0.16, 0.18, 0.12,
		_materials.island_cyan)
	for vein_index in 4:
		var side_point: Vector3 = [left_base, left, right, right_base][vein_index]
		_add_cable_between(parent,
			"BioLeafBranchVein_%02d_%02d" % [leaf_index + 1, vein_index + 1],
			center + Vector3.UP * 0.16,
			side_point + Vector3.UP * 0.16, 0.12, 0.08, _materials.island_cyan)
	_add_cable_between(parent, "BioLeafBaseSocket_%02d" % (leaf_index + 1),
		radial * 4.8 + Vector3.UP * height, inner, 0.72, 0.44,
		_materials.bio_gunmetal)
	var drop_lengths := [6.2, 7.8, 6.8, 8.4, 6.5, 8.0, 7.1, 8.6]
	var drop_finish := tip + Vector3.DOWN * float(drop_lengths[leaf_index])
	_add_bio_hanging_node(parent, leaf_index, tip, drop_finish)


func _add_bio_hanging_node(parent: Node3D, node_index: int, start: Vector3,
		finish: Vector3) -> void:
	var previous := start
	var horizontal := Vector3(start.x, 0, start.z).normalized()
	var tangent := Vector3.UP.cross(horizontal).normalized()
	var sway := (0.44 if node_index % 2 == 0 else -0.44)
	for segment_index in 8:
		var progress := float(segment_index + 1) / 8.0
		var next := start.lerp(finish, progress) \
			+ tangent * sin(progress * PI) * sway
		_add_cable_between(parent,
			"HangingFilament_%02d_%02d" % [node_index + 1, segment_index + 1],
			previous, next, 0.065, 0.040, _materials.bio_data_glow, 10)
		if segment_index % 2 == 1:
			var bead := _add_sphere(parent,
				"HangingFlowBead_%02d_%02d" % [node_index + 1, segment_index + 1],
				previous.lerp(next, 0.5), Vector3.ONE * 0.105,
				_materials.bio_data_glow)
			bead.set_meta("editable_component", true)
		previous = next
	_add_torus(parent, "HangingGoldCollarUpper_%02d" % (node_index + 1),
		finish + Vector3.UP * 0.64, 0.22, 0.42, _materials.bio_socket_gold)
	_add_cylinder(parent, "HangingNodeSocket_%02d" % (node_index + 1),
		finish + Vector3.UP * 0.38, 0.36, 0.56, _materials.bio_gunmetal, false, 12)
	_add_torus(parent, "HangingGoldCollarLower_%02d" % (node_index + 1),
		finish + Vector3.UP * 0.08, 0.20, 0.38, _materials.bio_socket_gold)
	var node_center := finish + Vector3.DOWN * 0.58
	var node := _add_sphere(parent, "BioHangingNode_%02d" % (node_index + 1),
		node_center, Vector3(0.56, 0.82, 0.56),
		_materials.bio_data_glow)
	node.set_meta("editable_component", true)
	node.set_meta("node_center", node_center)
	node.set_meta("node_radius", 0.82)
	node.set_meta("radial_lane", node_index)
	_add_torus(parent, "HangingNodeHalo_%02d" % (node_index + 1),
		node_center, 0.68, 0.82, _materials.bio_crown_outline, Vector3(90, 0, 0))
	_add_brick(parent, "HangingNodeTip_%02d" % (node_index + 1),
		finish + Vector3.DOWN * 1.32, Bricks.build_crystal(0.24, 0.62, 0.22, 6),
		_materials.bio_data_glow)


func _build_oldest_tree(zone: Node3D) -> void:
	_build_bio_data_tree(zone, Vector3(0, 0, 18), 1.0, 6)
	# Preserve the original gameplay node contract while the visible tree is now
	# assembled from the modular Bio-Data Tree pieces above.
	var legacy_trunk_collision := StaticBody3D.new()
	legacy_trunk_collision.name = "OldestTreeTrunkCollision"
	legacy_trunk_collision.position = Vector3(0, 36.0, 18)
	legacy_trunk_collision.collision_layer = 0
	legacy_trunk_collision.set_meta("compatibility_alias", "MindSparkBioDataTree/BioDataLivingCoreCollision")
	var legacy_trunk_shape := CollisionShape3D.new()
	var legacy_cylinder := CylinderShape3D.new()
	legacy_cylinder.radius = 3.9
	legacy_cylinder.height = 64.0
	legacy_trunk_shape.shape = legacy_cylinder
	legacy_trunk_collision.add_child(legacy_trunk_shape)
	zone.add_child(legacy_trunk_collision)
	_add_cylinder(zone, "StarPedestal", Vector3(0, 5, -32), 18, 10, _materials.stone, true, 24)
	_add_star(zone, Vector3(0, 24, -32), 10.0)
	_build_arch(zone, Vector3(78, 0, 48), 40, 52, _materials.gold, "RETURN WORLD GATE")
	_return_gate = WorldGateScene.instantiate() as MindSparkWorldGate
	_return_gate.name = "ReturnToArtCastleWorldGate"
	_return_gate.position = Vector3(78, 1, 48)
	_return_gate.destination_world_local = return_destination_world_local
	_return_gate.prompt_text = "Q • RETURN TO ART CASTLE"
	_return_gate.gate_enabled = false
	zone.add_child(_return_gate)


func _place_functional_objects() -> void:
	# Every type from the approved object sheet is represented. Checkpoints and
	# anchors intentionally repeat because the world design calls for two safe
	# roots and three boss shield layers.
	var specs := [
		# Keep the wider authored station cabinets outside canopy rails and tree roots.
		[10, "world_one.checkpoint.landing", "01_world_gate_landing", Vector3(-75, 2, 60)],
		[11, "world_one.path_projector", "01_world_gate_landing", Vector3(75, 2, 60)],
		[0, "world_one.spark_socket", "02_living_network_forest", Vector3(0, 2, 32)],
		[10, "world_one.checkpoint.network", "02_living_network_forest", Vector3(-52, 2, -38)],
		[1, "world_one.evidence_scanner", "03_fear_gate", Vector3(-38, 4, -12)],
		[3, "world_one.memory_board", "03_constellation_court", Vector3(0, 4, 10)],
		[4, "world_one.logic_gate", "03_proof_gate", Vector3(38, 4, -12)],
		[6, "world_one.focus_bell", "03_constellation_court", Vector3(12, 4, -48)],
		[2, "world_one.perspective_lens", "04_hope_path_ridge", Vector3(-45, 3, 10)],
		[5, "world_one.truth_bridge", "04_hope_path_ridge", Vector3(45, 3, 10)],
		[7, "world_one.warden_anchor.1", "05_thought_storm_arena", Vector3(-90, 3, 38)],
		[7, "world_one.warden_anchor.2", "05_thought_storm_arena", Vector3(0, 3, -105)],
		[7, "world_one.warden_anchor.3", "05_thought_storm_arena", Vector3(90, 3, 38)],
		[8, "world_one.calm_rain_basin", "05_thought_storm_arena", Vector3(0, 3, 105)],
		[9, "world_one.identity_reflection", "06_oldest_tree_sanctuary", Vector3(-72, 3, 32)],
	]
	if _uses_existing_mind_district():
		specs = [
			[10, "world_one.checkpoint.landing", "01_world_gate_landing", Vector3(-14, 1, -9)],
			[11, "world_one.path_projector", "01_world_gate_landing", Vector3(12, 1, -9)],
			[0, "world_one.spark_socket", "02_living_network_forest", Vector3(0, 1, 7)],
			[10, "world_one.checkpoint.network", "02_living_network_forest", Vector3(-17, 1, -11)],
			[1, "world_one.evidence_scanner", "03_fear_gate", Vector3.ZERO],
			[3, "world_one.memory_board", "03_constellation_court", Vector3(0, 1, 0)],
			[4, "world_one.logic_gate", "03_proof_gate", Vector3.ZERO],
			[6, "world_one.focus_bell", "03_constellation_court", Vector3(0, 1, -24)],
			[2, "world_one.perspective_lens", "04_hope_path_ridge", Vector3(-12, 1, 0)],
			[5, "world_one.truth_bridge", "04_hope_path_ridge", Vector3(12, 1, 0)],
			[7, "world_one.warden_anchor.1", "05_thought_storm_arena", Vector3(-28, 1, 12)],
			[7, "world_one.warden_anchor.2", "05_thought_storm_arena", Vector3(0, 1, -28)],
			[7, "world_one.warden_anchor.3", "05_thought_storm_arena", Vector3(28, 1, 12)],
			[8, "world_one.calm_rain_basin", "05_thought_storm_arena", Vector3(0, 1, 22)],
			[9, "world_one.identity_reflection", "06_oldest_tree_sanctuary", Vector3(-22, 1, -6)],
		]
	for spec in specs:
		var definition := QuestObjectCatalog.definition_at(int(spec[0]))
		var object := QuestObjectScene.instantiate() as QuestObjectBase
		object.name = str(spec[1]).get_slice(".", str(spec[1]).get_slice_count(".") - 1).to_pascal_case()
		object.position = spec[3]
		object.scale = Vector3.ONE * (2.4 if _uses_existing_mind_district() else 5.0)
		object.definition = definition
		object.save_id = str(spec[1])
		object.state_store_path = object_state_store_path
		object.add_to_group("mind_spark_world_one_object")
		(_zone_nodes[str(spec[2])] as Node3D).add_child(object)
		_objects.append(object)


func _finalize_quest_object_story_layout() -> void:
	# Every station receives one canonical chapter/order and a reachable operator
	# point on its presentation side. The two campus builders own the first ten
	# positions; this pass finishes their contract and authors the arena/sanctuary
	# stations around the actual story approach.
	var route_contract := {
		"world_one.checkpoint.landing": [0, "arrival_support", 1],
		"world_one.path_projector": [0, "arrival_support", 1],
		"world_one.spark_socket": [1, "living_network", 1],
		"world_one.checkpoint.network": [1, "living_network", 1],
		"world_one.focus_bell": [0, "optional_help", 1],
		"world_one.evidence_scanner": [2, "evidence", 2],
		"world_one.memory_board": [3, "evidence", 2],
		"world_one.logic_gate": [4, "evidence", 2],
		"world_one.perspective_lens": [5, "hope", 2],
		"world_one.truth_bridge": [6, "hope", 2],
		"world_one.warden_anchor.1": [7, "storm_combat", 3],
		"world_one.warden_anchor.2": [8, "storm_combat", 3],
		"world_one.warden_anchor.3": [9, "storm_combat", 3],
		"world_one.calm_rain_basin": [10, "storm_resolution", 3],
		"world_one.identity_reflection": [11, "identity_epilogue", 3],
	}
	var arena := _zone_nodes["05_thought_storm_arena"] as Node3D
	var sanctuary := _zone_nodes["06_oldest_tree_sanctuary"] as Node3D
	var sanctuary_incoming := (ZONES[4].position - ZONES[5].position) * Vector3(1, 0, 1)
	sanctuary_incoming = sanctuary_incoming.normalized()
	for object in _objects:
		if route_contract.has(object.save_id):
			var contract: Array = route_contract[object.save_id]
			object.set_meta("story_route_order", int(contract[0]))
			object.set_meta("story_chapter", str(contract[1]))
			object.set_meta("physical_island", int(contract[2]))
			object.set_meta("canonical_story_placement", true)
		if object.save_id.begins_with("world_one.warden_anchor."):
			var outward := Vector3(object.position.x, 0, object.position.z).normalized()
			var approach := object.position + outward * 12.0
			object.look_at(arena.to_global(approach), Vector3.UP, true)
			object.set_meta("operator_approach_local", approach)
			object.set_meta("formation_role", "outward-facing triangular shield pylon")
		elif object.save_id == "world_one.calm_rain_basin":
			var approach := object.position + Vector3(0, 0, -12)
			object.look_at(arena.to_global(approach), Vector3.UP, true)
			object.set_meta("operator_approach_local", approach)
			object.set_meta("formation_role", "safe resolution station beyond the boss ring")
		elif object.save_id == "world_one.identity_reflection":
			object.position = sanctuary_incoming * 79.0 + Vector3.UP * 3.0
			var approach := object.position + sanctuary_incoming * 12.0
			object.look_at(sanctuary.to_global(approach), Vector3.UP, true)
			object.set_meta("operator_approach_local", approach)
			object.set_meta("formation_role", "epilogue threshold between bridge landing and Oldest Tree")
	set_meta("quest_object_layout", "canonical_story_route_v2")
	set_meta("quest_object_count", _objects.size())


func _redesign_island_three(geometry: Node3D) -> void:
	## Island Three now uses the same celestial civic architecture as Islands One
	## and Two: ivory masonry, brass structure, cyan aether, solid courts and
	## human-scale pavilions. Its storm-to-wisdom gameplay sequence is preserved.
	var campus := Node3D.new()
	campus.name = "IslandThreeCivicSanctuary"
	campus.set_meta("design_revision", "low_poly_prototype_v6")
	campus.set_meta("architectural_language",
		"faceted ivory quest monuments, charcoal structure, cyan glass and a living tree cathedral")
	campus.set_meta("matches_previous_islands", true)
	campus.set_meta("physical_island", 3)
	campus.set_meta("story_sequence", PackedStringArray([
		"enter the Stormworks portico",
		"stabilise the lens tower, resonance forge and lightning archive",
		"restore the rain-harvesting observatory",
		"cross the wisdom basilica",
		"reflect beneath the Oldest Tree living cathedral",
	]))
	geometry.add_child(campus)
	var storm_zone := _zone_nodes["05_thought_storm_arena"] as Node3D
	var sanctuary_zone := _zone_nodes["06_oldest_tree_sanctuary"] as Node3D
	var legacy_oldest_tree := sanctuary_zone.get_node_or_null("MindSparkBioDataTree") as Node3D
	if legacy_oldest_tree != null:
		legacy_oldest_tree.visible = false
		legacy_oldest_tree.set_meta("retired_by", "OldestTreeLivingCathedral")
	# Retire the old five-storey violet vortex. It belonged to the earlier effect
	# study and visually overwhelmed the civic architecture and quest stations.
	for legacy_ring in storm_zone.find_children("LayeredStormRing_*", "MeshInstance3D", true, false):
		legacy_ring.visible = false
		legacy_ring.set_meta("retired_by", "IslandThreeCivicSanctuary")
	var legacy_arena := storm_zone.get_node_or_null("BossArenaCollision") as MeshInstance3D
	if legacy_arena != null:
		legacy_arena.material_override = _materials.celestial_floor
		legacy_arena.set_meta("restyled_as", "IvoryStormworksCourt")

	var arena_origin: Vector3 = ZONES[4].position
	var sanctuary_origin: Vector3 = ZONES[5].position
	var arena_y: float = _zone_floor_surface_y(arena_origin) + 0.18
	var sanctuary_y: float = _zone_floor_surface_y(sanctuary_origin) + 0.18
	var arena_center := Vector3(arena_origin.x, arena_y, arena_origin.z)
	# Clean low-poly deck plates cover the former imported gold route graphics
	# while retaining the proven floor collision directly beneath them.
	_add_cylinder(campus, "IslandThreeStormDeck",
		arena_center - Vector3.UP * .11, 165.0, .18,
		_materials.celestial_floor, false, 48)
	_add_cylinder(campus, "IslandThreeSanctuaryDeck",
		Vector3(sanctuary_origin.x, sanctuary_y - .11, sanctuary_origin.z),
		136.0, .18, _materials.celestial_floor, false, 48)
	var perimeter_repair := geometry.get_node_or_null("IslandThreePerimeterRepairs") as Node3D
	if perimeter_repair != null:
		for imported_railing in perimeter_repair.find_children("*", "MeshInstance3D", true, false):
			(imported_railing as MeshInstance3D).material_override = _materials.celestial_floor
			(imported_railing as MeshInstance3D).set_meta("island_three_rail_restyled", "ivory")
	var return_arch := sanctuary_zone.get_node_or_null("ReturnWorldGate") as Node3D
	if return_arch != null:
		for arch_piece in return_arch.find_children("*", "MeshInstance3D", true, false):
			(arch_piece as MeshInstance3D).material_override = _materials.celestial_floor
			(arch_piece as MeshInstance3D).set_meta("island_three_gold_removed", true)
	var return_ring := sanctuary_zone.get_node_or_null(
		"ReturnToArtCastleWorldGate/Portal/Ring") as MeshInstance3D
	if return_ring != null:
		return_ring.material_override = _materials.island_cyan
	var arrival_direction := Vector3(1, 0, 0)
	var arrival_center := arena_center - arrival_direction * 135.0
	_build_island_three_arrival_portico(campus, arrival_center, arrival_direction)

	# The low-poly prototype uses one open navigation court.  Keep its centre clear
	# for the Warden and put all scenery on the perimeter where it also points to
	# the five playable landmarks.
	var stormworks := Node3D.new()
	stormworks.name = "StormworksGrandCourt"
	stormworks.set_meta("purpose", "open low-poly navigation and boss court")
	stormworks.set_meta("clear_center_radius_m", 34.0)
	campus.add_child(stormworks)
	_add_cylinder(stormworks, "IvoryStormCourt", arena_center - Vector3.UP * .16,
		48.0, .32, _materials.celestial_floor, true, 48)
	_build_island_three_compass(stormworks, arena_center)
	var garden_angles_degrees := [20.0, 45.0, 120.0, 150.0, 210.0, 240.0, 315.0, 340.0]
	for garden_index in garden_angles_degrees.size():
		var angle := deg_to_rad(float(garden_angles_degrees[garden_index]))
		var garden_at := arena_center + Vector3(sin(angle) * 57.0, 0,
			cos(angle) * 57.0)
		_build_island_three_perimeter_garden(stormworks, garden_index, garden_at,
			angle + PI)

	# Each Warden anchor gets a different silhouette and spatial puzzle language.
	var anchor_offsets := [Vector3(-90, 0, 38), Vector3(0, 0, -105), Vector3(90, 0, 38)]
	for anchor_index in anchor_offsets.size():
		var anchor_at: Vector3 = arena_center + anchor_offsets[anchor_index]
		_add_island_three_lane(stormworks, "ShieldProcessional_%02d" % (anchor_index + 1),
			arena_center, anchor_at, 11.0, _materials.celestial_floor)
		_build_island_three_quest_landmark(stormworks, anchor_index, anchor_at)

	# The recovery quest remains playable, but the Calm-Rain Cloister is removed.
	# An angular weather instrument now makes the basin read as an active quest.
	var basin_at := arena_center + Vector3(0, 0, 105)
	_build_rain_harvesting_observatory(campus, basin_at)
	_add_island_three_lane(campus.get_node("RainHarvestObservatory") as Node3D,
		"IvoryRainApproach", arena_center, basin_at,
		14.0, _materials.celestial_floor)

	# The final route becomes an open-air basilica with repeated ivory frames and
	# living-root rails, ending in a circular apse around the reflection object.
	var basilica := Node3D.new()
	basilica.name = "WisdomBasilicaPromenade"
	basilica.set_meta("purpose", "architectural epilogue from storm court to Oldest Tree")
	campus.add_child(basilica)
	var to_sanctuary := Vector3(sanctuary_origin.x - arena_origin.x, 0,
		sanctuary_origin.z - arena_origin.z)
	var direction: Vector3 = to_sanctuary.normalized()
	var side_axis := Vector3(direction.z, 0, -direction.x)
	var promenade_start := arena_center + direction * 60.0
	var promenade_end := Vector3(sanctuary_origin.x, sanctuary_y, sanctuary_origin.z + 18.0)
	_add_island_three_lane(basilica, "IvoryWisdomNave", promenade_start,
		promenade_end, 14.0, _materials.celestial_floor)
	for bay_index in 7:
		var progress := float(bay_index + 1) / 8.0
		var bay_center := promenade_start.lerp(promenade_end, progress)
		for side in [-1.0, 1.0]:
			var pier_at := bay_center + side_axis * float(side) * 9.0
			_add_island_three_civic_column(basilica,
				"BasilicaPier_%02d_%s" % [bay_index + 1, "L" if side < 0 else "R"],
				pier_at, 8.5)
		var left_capital := bay_center - side_axis * 9.0 + Vector3.UP * 8.8
		var right_capital := bay_center + side_axis * 9.0 + Vector3.UP * 8.8
		var vault_apex := bay_center + Vector3.UP * 13.8
		_add_cable_between(basilica, "BasilicaVaultLeft_%02d" % (bay_index + 1),
			left_capital, vault_apex, .62, .42, _materials.astral_brass, 10)
		_add_cable_between(basilica, "BasilicaVaultRight_%02d" % (bay_index + 1),
			right_capital, vault_apex, .62, .42, _materials.astral_brass, 10)
		_add_sphere(basilica, "BasilicaVaultLight_%02d" % (bay_index + 1),
			vault_apex, Vector3.ONE * .72, _materials.island_cyan)
	_add_cable_between(basilica, "LeftBasilicaCornice",
		promenade_start - side_axis * 9.0 + Vector3.UP * 9.1,
		promenade_end - side_axis * 9.0 + Vector3.UP * 9.1,
		.58, .58, _materials.astral_brass, 10)
	_add_cable_between(basilica, "RightBasilicaCornice",
		promenade_start + side_axis * 9.0 + Vector3.UP * 9.1,
		promenade_end + side_axis * 9.0 + Vector3.UP * 9.1,
		.58, .58, _materials.astral_brass, 10)
	_add_cable_between(basilica, "CyanBasilicaRidge",
		promenade_start + Vector3.UP * 13.8,
		promenade_end + Vector3.UP * 13.8,
		.38, .38, _materials.island_cyan, 10)
	_add_cable_between(basilica, "LeftLivingRootRail",
		promenade_start - side_axis * 7.2 + Vector3.UP * .8,
		promenade_end - side_axis * 7.2 + Vector3.UP * .8,
		.55, .80, _materials.island_bark_root, 12)
	_add_cable_between(basilica, "RightLivingRootRail",
		promenade_start + side_axis * 7.2 + Vector3.UP * .8,
		promenade_end + side_axis * 7.2 + Vector3.UP * .8,
		.55, .80, _materials.island_bark_root, 12)

	var mirror: QuestObjectBase
	for object in _objects:
		if object.save_id == "world_one.identity_reflection":
			mirror = object
			break
	if mirror != null:
		var mirror_at := geometry.to_local((mirror.get_parent() as Node3D).to_global(mirror.position))
		mirror_at.y = sanctuary_y
		_add_cylinder(basilica, "OldestTreeReflectionApse", mirror_at - Vector3.UP * .14,
			27.0, .28, _materials.celestial_floor, true, 36)
		var reflection_court := Node3D.new()
		reflection_court.name = "RootboundReflectionCourt"
		reflection_court.set_meta("quest_architecture", "living root oratory")
		reflection_court.set_meta("low_poly_landmark", true)
		basilica.add_child(reflection_court)
		_add_cylinder(reflection_court, "ReflectionPool", mirror_at + Vector3.UP * .04,
			13.0, .12, _materials.island_crystal_facet_dark, false, 12)
		for apse_index in 8:
			var apse_angle := TAU * float(apse_index) / 8.0
			var apse_at := mirror_at + Vector3(sin(apse_angle) * 30.0, 0,
				cos(apse_angle) * 30.0)
			var root_apex := mirror_at + Vector3.UP * (15.0 + float(apse_index % 2) * 2.0)
			_add_cable_between(reflection_court,
				"ReflectionRootRib_%02d" % (apse_index + 1), apse_at, root_apex,
				1.15, .34, _materials.island_bark_root, 12)
			_add_cable_between(reflection_court,
				"ReflectionCyanVein_%02d" % (apse_index + 1),
				apse_at + Vector3.UP * .5, root_apex, .20, .10,
				_materials.island_cyan, 8)
			_add_brick(reflection_court, "ReflectionMarker_%02d" % (apse_index + 1),
				mirror_at + Vector3(sin(apse_angle) * 17.0, 2.2,
					cos(apse_angle) * 17.0),
				Bricks.build_crystal(.75, 4.4, .2, 6),
				_materials.arrival_glass if apse_index % 2 == 0 \
				else _materials.sanctum_lavender_glass)
		_add_sphere(reflection_court, "ReflectionMemorySeed",
			mirror_at + Vector3.UP * 16.8, Vector3(1.6, 2.8, 1.6),
			_materials.sanctum_lavender_glass)
		var reflection_completion := Node3D.new()
		reflection_completion.name = "CompletionStateVisuals"
		reflection_completion.set_meta("preserve_authored_nodes", true)
		reflection_court.add_child(reflection_completion)
		_add_cylinder(reflection_completion, "AwakenedReflectionWater",
			mirror_at + Vector3.UP * .13, 11.5, .10, _materials.arrival_glass, false, 12)

	_build_oldest_tree_living_cathedral(campus,
		Vector3(sanctuary_origin.x, sanctuary_y, sanctuary_origin.z + 18.0))
	_build_island_three_underside_accents(campus, arena_center, sanctuary_origin)

	# Retain proven route collision while bringing its materials into the same kit.
	var route := geometry.get_node("MainStoryCircuitRoute") as Node3D
	for leg in ["A", "B"]:
		var deck := route.get_node_or_null("CircuitRoute_05_%s" % leg) as MeshInstance3D
		if deck != null:
			deck.material_override = _materials.celestial_floor
			deck.set_meta("redesigned_as", "WisdomBasilicaPromenade")
		var seam := route.get_node_or_null("CircuitRoute_05_%sCyanSeam" % leg) as MeshInstance3D
		if seam != null:
			seam.material_override = _materials.island_cyan
	_remove_island_three_gold_rings(geometry, campus, storm_zone,
		sanctuary_zone)
	_remove_island_three_gold_lines(geometry, campus, storm_zone,
		sanctuary_zone)
	for object in _objects:
		if int(object.get_meta("physical_island", 0)) != 3:
			continue
		if not object.completed.is_connected(_on_island_three_object_completed):
			object.completed.connect(_on_island_three_object_completed)
	_refresh_island_three_completion_visuals()
	set_meta("island_three_design", "approved low-poly prototype with five distinct quest landmarks")
	set_meta("island_three_masterplan",
		"arrival portico > three unique storm instruments > rain observatory > wisdom basilica > living tree cathedral")


func _build_island_three_arrival_portico(parent: Node3D, center: Vector3,
		forward: Vector3) -> void:
	var portico := Node3D.new()
	portico.name = "StormworksArrivalPortico"
	portico.set_meta("purpose", "low-poly cyan-glass threshold from Island Two")
	portico.set_meta("clear_opening_m", 24.0)
	portico.set_meta("prototype_fidelity", "gameplay_adapted")
	parent.add_child(portico)
	var yaw := atan2(forward.x, forward.z)
	var side := Vector3(forward.z, 0, -forward.x)
	_add_box(portico, "IvoryArrivalTerrace", center - Vector3.UP * .12,
		Vector3(38.0, .28, 34.0), _materials.celestial_floor, true, yaw)
	_add_box(portico, "CharcoalArrivalAxis", center + Vector3.UP * .10,
		Vector3(2.4, .10, 30.0), _materials.floor_dark, false, yaw)
	for lateral_side in [-1.0, 1.0]:
		var side_name := "South" if lateral_side < 0 else "North"
		var tower_height := 17.0 if lateral_side < 0 else 21.0
		var tower_at := center + side * float(lateral_side) * 15.5
		_add_box(portico, "ArrivalTower%s" % side_name,
			tower_at + Vector3.UP * (tower_height * .5), Vector3(7.0, tower_height, 8.0),
			_materials.celestial_floor, true, yaw)
		_add_box(portico, "ArrivalGlass%s" % side_name,
			tower_at - side * float(lateral_side) * 3.56 + Vector3.UP * (tower_height * .54),
			Vector3(.28, tower_height * .55, 4.2), _materials.arrival_glass, false, yaw)
		for spire_index in 2:
			var spire_at := tower_at + forward * (-2.1 if spire_index == 0 else 2.1) \
				+ Vector3.UP * (tower_height + 3.1)
			_add_tapered_cylinder(portico,
				"ArrivalSpire%s_%02d" % [side_name, spire_index + 1], spire_at,
				.10, 1.3, 6.0, _materials.arrival_glass, 6)
	# The named arch remains a lintel rather than a torus so the portal has no
	# decorative ring and the full 24 m opening stays walkable.
	_add_box(portico, "AetherArrivalArch", center + Vector3.UP * 18.0,
		Vector3(24.0, 1.3, 2.0), _materials.island_cyan, false, yaw)
	_add_brick(portico, "PorticoAetherCrown", center + Vector3.UP * 22.0,
		Bricks.build_crystal(1.8, 5.5, .4, 6), _materials.island_cyan)


func _build_island_three_compass(parent: Node3D, center: Vector3) -> void:
	var compass := Node3D.new()
	compass.name = "StormCourtCompass"
	compass.set_meta("floor_motif", "faceted ivory charcoal and cyan wedges; no rings")
	parent.add_child(compass)
	_add_cylinder(compass, "CompassHub", center + Vector3.UP * .18,
		4.2, .10, _materials.floor_dark, false, 8)
	for point_index in 8:
		var angle := TAU * float(point_index) / 8.0
		var length := 14.0 if point_index % 2 == 0 else 9.0
		var material: Material = _materials.island_cyan if point_index % 2 == 0 \
			else _materials.floor_dark
		var point_at := center + Vector3(sin(angle) * length * .52, .20,
			cos(angle) * length * .52)
		_add_box(compass, "CompassWedge_%02d" % (point_index + 1), point_at,
			Vector3(2.4, .10, length), material, false, angle)


func _build_island_three_perimeter_garden(parent: Node3D, index: int,
		center: Vector3, facing: float) -> void:
	var garden := Node3D.new()
	garden.name = "StormCourtGarden_%02d" % (index + 1)
	parent.add_child(garden)
	_add_box(garden, "IvoryPlanter", center + Vector3.UP * .45,
		Vector3(9.0, .9, 4.2), _materials.celestial_floor, true, facing)
	var tree_at := center + Vector3.UP * 3.0
	_add_cylinder(garden, "TreeTrunk", tree_at, .55, 5.0,
		_materials.island_bark_root, true, 7)
	var canopy := _add_sphere(garden, "FacetedCanopy", center + Vector3.UP * 7.1,
		Vector3(3.1, 2.1, 3.1), _materials.bio_nutrient_glow)
	(canopy.mesh as SphereMesh).radial_segments = 7
	(canopy.mesh as SphereMesh).rings = 4
	for shrub_index in 2:
		var shrub_side := -1.0 if shrub_index == 0 else 1.0
		_add_brick(garden, "VioletShrub_%02d" % (shrub_index + 1),
			center + Vector3(shrub_side * 2.7, 1.3, 0),
			Bricks.build_crystal(.65, 1.8, .2, 6), _materials.sanctum_lavender_glass)


func _add_island_three_lane(parent: Node3D, node_name: String, start: Vector3,
		finish: Vector3, width: float, material: Material) -> MeshInstance3D:
	var flat := Vector3(finish.x - start.x, 0, finish.z - start.z)
	var length: float = flat.length()
	var center := start.lerp(finish, .5)
	center.y = minf(start.y, finish.y)
	var lane := _add_box(parent, node_name, center, Vector3(width, .18, length),
		material, true, atan2(flat.x, flat.z))
	lane.set_meta("clear_walkway_width_m", width)
	return lane


func _add_island_three_civic_column(parent: Node3D, node_name: String,
		at: Vector3, height: float) -> void:
	_add_cylinder(parent, "%sIvoryPlinth" % node_name, at + Vector3.UP * .28,
		1.65, .56, _materials.celestial_floor, true, 12)
	_add_cylinder(parent, "%sIvoryShaft" % node_name, at + Vector3.UP * (height * .5 + .55),
		.78, height, _materials.celestial_floor, true, 12)
	_add_cylinder(parent, "%sBrassBase" % node_name, at + Vector3.UP * .68,
		1.08, .24, _materials.floor_dark, false, 8)
	_add_box(parent, "%sBrassCapital" % node_name, at + Vector3.UP * (height + .48),
		Vector3(2.5, .34, 2.5), _materials.floor_dark)
	_add_sphere(parent, "%sAetherLamp" % node_name, at + Vector3.UP * (height + 1.35),
		Vector3.ONE * .62, _materials.island_cyan)


func _build_island_three_quest_landmark(parent: Node3D, landmark_index: int,
		center: Vector3) -> void:
	var landmark := Node3D.new()
	var landmark_names := ["StormLensTower", "ResonanceForge", "LightningArchive"]
	landmark.name = landmark_names[landmark_index]
	landmark.set_meta("quest_architecture", landmark.name)
	landmark.set_meta("warden_anchor_index", landmark_index + 1)
	landmark.set_meta("low_poly_landmark", true)
	parent.add_child(landmark)
	_add_box(landmark, "SolidQuestTerrace", center - Vector3.UP * .12,
		Vector3(32.0, .28, 28.0), _materials.celestial_floor, true)
	_add_box(landmark, "CharcoalTerraceFoot", center - Vector3.UP * .42,
		Vector3(28.0, .34, 24.0), _materials.floor_dark, true)
	if landmark_index == 0:
		# A tall open survey instrument with one suspended lens crystal.
		var apex := center + Vector3.UP * 26.0
		for leg_index in 3:
			var angle := TAU * float(leg_index) / 3.0
			var foot := center + Vector3(sin(angle) * 10.5, 0, cos(angle) * 10.5)
			_add_island_three_civic_column(landmark,
				"LensTripod_%02d" % (leg_index + 1), foot, 11.0)
			_add_cable_between(landmark, "LensStrut_%02d" % (leg_index + 1),
				foot + Vector3.UP * 11.8, apex, .72, .24,
				_materials.floor_dark, 8)
		_add_brick(landmark, "StormLensPrism", center + Vector3.UP * 18.0,
			Bricks.build_crystal(3.2, 9.0, .8, 6), _materials.arrival_glass)
		for sight_index in 3:
			var sight_angle := TAU * float(sight_index) / 3.0
			var sight_center := center + Vector3.UP * (15.0 + sight_index * 2.5)
			var sight := _add_cylinder(landmark, "LensSightFrame_%02d" % (sight_index + 1),
				sight_center, 4.8 + sight_index * .8, .34, _materials.floor_dark, false, 8)
			sight.rotation = Vector3(PI * .5, sight_angle, 0)
			sight.set_meta("rotating_instrument", true)
	elif landmark_index == 1:
		# The forge is low and muscular: paired buttresses and tuned crystal pylons.
		for side in [-1.0, 1.0]:
			var pylon_at := center + Vector3(float(side) * 10.0, 0, 0)
			_add_box(landmark, "ForgeButtress_%s" % ("L" if side < 0 else "R"),
				pylon_at + Vector3.UP * 5.0, Vector3(4.2, 10.0, 7.0),
				_materials.celestial_floor, true)
			_add_tapered_cylinder(landmark,
				"ForgeConductor_%s" % ("L" if side < 0 else "R"),
				pylon_at + Vector3.UP * 12.0, .2, 1.2, 5.0,
				_materials.island_cyan, 8)
		_add_cable_between(landmark, "ForgeLintel",
			center + Vector3(-10, 10.5, 0), center + Vector3(10, 10.5, 0),
			.9, .9, _materials.floor_dark, 8)
		_add_sphere(landmark, "SuspendedResonanceCore", center + Vector3.UP * 7.0,
			Vector3(2.6, 3.6, 2.6), _materials.island_violet_energy)
		for pylon_index in 4:
			var pylon_angle := TAU * float(pylon_index) / 4.0 + PI * .25
			var tuned_at := center + Vector3(sin(pylon_angle) * 8.0, 2.3,
				cos(pylon_angle) * 8.0)
			_add_brick(landmark, "TunedCrystalPylon_%02d" % (pylon_index + 1), tuned_at,
				Bricks.build_crystal(1.0, 4.6, .3, 6),
				_materials.island_cyan if pylon_index % 2 == 0 else _materials.sanctum_lavender_glass)
	else:
		# The archive uses staggered vertical fins like open illuminated pages.
		for fin_index in 7:
			var side := -1.0 if fin_index % 2 == 0 else 1.0
			var depth := -12.0 + float(fin_index) * 4.0
			var fin_at := center + Vector3(side * (7.0 + absf(depth) * .25), 6.0, depth)
			_add_box(landmark, "ArchiveFin_%02d" % (fin_index + 1), fin_at,
				Vector3(1.5, 12.0 + fin_index, 3.2), _materials.celestial_floor, true)
			_add_box(landmark, "ArchiveCharcoalBase_%02d" % (fin_index + 1),
				fin_at - Vector3.UP * 5.4, Vector3(2.4, 1.1, 4.2),
				_materials.floor_dark, true)
			_add_box(landmark, "ArchiveGlyph_%02d" % (fin_index + 1),
				fin_at + Vector3(-side * .78, 0, 0), Vector3(.12, 7.0, 1.2),
				_materials.arrival_glass)
		_add_cable_between(landmark, "ArchiveLightningBridge",
			center + Vector3(-9, 14, -8), center + Vector3(9, 17, 8),
			.42, .20, _materials.island_cyan, 6)
		_add_brick(landmark, "ArchiveMemoryShard", center + Vector3.UP * 9.0,
			Bricks.build_crystal(2.2, 6.0, .5, 6), _materials.island_cyan)
	var completion_visuals := Node3D.new()
	completion_visuals.name = "CompletionStateVisuals"
	completion_visuals.set_meta("preserve_authored_nodes", true)
	landmark.add_child(completion_visuals)
	_add_brick(completion_visuals, "ActivatedQuestCrystal", center + Vector3.UP * 3.5,
		Bricks.build_crystal(1.1, 4.2, .3, 6), _materials.green_glow)


func _build_rain_harvesting_observatory(parent: Node3D, center: Vector3) -> void:
	var observatory := Node3D.new()
	observatory.name = "RainHarvestObservatory"
	observatory.set_meta("quest_architecture", "open weather instrument")
	observatory.set_meta("replaces", "CalmRainCloister")
	observatory.set_meta("low_poly_landmark", true)
	parent.add_child(observatory)
	_add_box(observatory, "RainCollectorTerrace", center - Vector3.UP * .12,
		Vector3(42.0, .28, 34.0), _materials.celestial_floor, true)
	_add_box(observatory, "RainCollectorUndercroft", center - Vector3.UP * .54,
		Vector3(37.0, .60, 29.0), _materials.floor_dark, true)
	_add_cylinder(observatory, "RainPool", center + Vector3.UP * .12,
		10.0, .12, _materials.island_crystal_facet_dark, false, 12)
	var mast_top := center + Vector3.UP * 22.0
	for corner_index in 4:
		var x := -15.0 if corner_index % 2 == 0 else 15.0
		var z := -11.0 if corner_index < 2 else 11.0
		var corner := center + Vector3(x, 0, z)
		_add_island_three_civic_column(observatory,
			"RainGaugeMast_%02d" % (corner_index + 1), corner, 10.0)
		_add_cable_between(observatory,
			"RainCollectorRib_%02d" % (corner_index + 1),
			corner + Vector3.UP * 10.8, mast_top, .70, .20,
			_materials.arrival_glass, 10)
		_add_box(observatory, "RainVane_%02d" % (corner_index + 1),
			corner + Vector3.UP * 12.6, Vector3(5.0, .28, 2.0),
			_materials.island_cyan, false, float(corner_index) * PI * .25)
	_add_tapered_cylinder(observatory, "CentralRainNeedle",
		center + Vector3.UP * 14.0, .15, 1.0, 20.0,
		_materials.floor_dark, 8)
	_add_brick(observatory, "RainCrystalReservoir", center + Vector3.UP * 6.0,
		Bricks.build_crystal(3.3, 8.0, .8, 8), _materials.arrival_glass)
	var dome := _add_sphere(observatory, "FacetedRainDome", center + Vector3.UP * 8.0,
		Vector3(10.5, 6.0, 10.5), _materials.arrival_glass)
	var dome_mesh := dome.mesh as SphereMesh
	dome_mesh.radial_segments = 12
	dome_mesh.rings = 6
	for channel_index in 4:
		var channel_angle := TAU * float(channel_index) / 4.0
		var channel_center := center + Vector3(sin(channel_angle) * 14.5, .19,
			cos(channel_angle) * 14.5)
		_add_box(observatory, "RainChannel_%02d" % (channel_index + 1), channel_center,
			Vector3(2.1, .10, 19.0), _materials.island_cyan, false, channel_angle)
	var completion_visuals := Node3D.new()
	completion_visuals.name = "CompletionStateVisuals"
	completion_visuals.set_meta("preserve_authored_nodes", true)
	observatory.add_child(completion_visuals)
	_add_cylinder(completion_visuals, "HarvestedRainWater", center + Vector3.UP * .22,
		8.2, .14, _materials.arrival_glass, false, 12)
	for stream_index in 6:
		var angle := TAU * float(stream_index) / 6.0
		_add_cable_between(completion_visuals, "CapturedRainStream_%02d" % (stream_index + 1),
			center + Vector3(sin(angle) * 9.0, 13.0, cos(angle) * 9.0),
			center + Vector3(sin(angle) * 2.8, 7.0, cos(angle) * 2.8),
			.18, .10, _materials.island_cyan, 8)
	for fall_index in 2:
		var fall_at := center + Vector3(-8.0 if fall_index == 0 else 8.0, -8.0, 19.0)
		_add_tapered_cylinder(completion_visuals, "ObservatoryWaterfall_%02d" % (fall_index + 1),
			fall_at, .22, 1.25, 18.0, _materials.arrival_glass, 6)


func _build_oldest_tree_living_cathedral(parent: Node3D, base: Vector3) -> void:
	var cathedral := Node3D.new()
	cathedral.name = "OldestTreeLivingCathedral"
	cathedral.set_meta("design_revision", "root_crown_cathedral_v1")
	cathedral.set_meta("quest_architecture", "walkable living landmark")
	cathedral.set_meta("asymmetric_canopy", true)
	cathedral.set_meta("camera_clearance_m", 38.0)
	cathedral.set_meta("low_poly_landmark", true)
	parent.add_child(cathedral)
	# A square ivory clearing covers the obsolete concentric gold floor ornament
	# and gives the roots a calm architectural foreground.
	_add_box(cathedral, "LivingCathedralTerrace", base + Vector3.UP * .12,
		Vector3(62.0, .26, 58.0), _materials.celestial_floor, true)
	for inlay_index in 5:
		var z_offset := -18.0 + float(inlay_index) * 9.0
		_add_box(cathedral, "RootNaveInlay_%02d" % (inlay_index + 1),
			base + Vector3(0, .28, z_offset), Vector3(38.0, .08, .55),
			_materials.island_cyan)
	# This collision-backed heartwood makes the redesigned hero tree physically solid.
	_add_cylinder(cathedral, "LivingHeartwood", base + Vector3.UP * 26.0,
		6.8, 52.0, _materials.bio_bark, true, 14)
	for ribbon_index in 8:
		var ribbon_angle := TAU * float(ribbon_index) / 8.0
		var ribbon_start := base + Vector3(sin(ribbon_angle) * 6.9, 1.0,
			cos(ribbon_angle) * 6.9)
		var ribbon_finish_angle := ribbon_angle + .72
		var ribbon_finish := base + Vector3(sin(ribbon_finish_angle) * 6.3, 50.0,
			cos(ribbon_finish_angle) * 6.3)
		_add_cable_between(cathedral, "HeartwoodBarkRibbon_%02d" % (ribbon_index + 1),
			ribbon_start, ribbon_finish, .72, .38,
			_materials.bio_bark_highlight if ribbon_index % 3 == 0 else _materials.island_bark_root,
			10)
	for root_index in 10:
		var angle := TAU * float(root_index) / 10.0 + sin(float(root_index)) * .10
		var radial := Vector3(sin(angle), 0, cos(angle))
		var start := base + radial * 4.2 + Vector3.UP * 5.5
		var finish := base + radial * (22.0 + float(root_index % 3) * 3.0)
		_add_cable_between(cathedral, "CathedralRoot_%02d" % (root_index + 1),
			start, finish, 2.4, .45, _materials.island_bark_root, 12)
		_add_cable_between(cathedral, "CathedralRootVein_%02d" % (root_index + 1),
			start + Vector3.UP * .8, finish + Vector3.UP * .35,
			.26, .09, _materials.green_glow, 8)
	# Five great boughs form an uneven nave and pull the silhouette toward the basilica.
	var bough_lengths := [30.0, 38.0, 33.0, 42.0, 29.0]
	var bough_heights := [67.0, 74.0, 70.0, 78.0, 72.0]
	for bough_index in 5:
		var angle := -1.1 + float(bough_index) * .58
		var radial := Vector3(sin(angle), 0, cos(angle))
		var branch_start := base + Vector3(0, 43.0 + bough_index * 1.8, 0)
		var branch_mid := base + radial * (float(bough_lengths[bough_index]) * .48) \
			+ Vector3.UP * (55.0 + bough_index * 2.2)
		var branch_end := base + radial * float(bough_lengths[bough_index]) \
			+ Vector3.UP * float(bough_heights[bough_index])
		_add_cable_between(cathedral, "GreatBough_%02dA" % (bough_index + 1),
			branch_start, branch_mid, 2.7, 1.4, _materials.bio_bark, 14)
		_add_cable_between(cathedral, "GreatBough_%02dB" % (bough_index + 1),
			branch_mid, branch_end, 1.4, .55, _materials.bio_bark, 12)
		_add_cable_between(cathedral, "GreatBoughDataVein_%02d" % (bough_index + 1),
			branch_start + Vector3.UP * 1.0, branch_end + Vector3.UP * .5,
			.22, .08, _materials.island_cyan, 8)
		for leaf_cluster_index in 7:
			var leaf_angle := TAU * float(leaf_cluster_index) / 7.0 + bough_index * .29
			var leaf_offset := Vector3(sin(leaf_angle) * (7.0 + leaf_cluster_index % 2 * 3.0),
				float(leaf_cluster_index % 3) * 2.2 - 2.0,
				cos(leaf_angle) * (6.0 + (leaf_cluster_index + 1) % 2 * 3.0))
			var canopy := _add_sphere(cathedral,
				"CanopyLeafMass_%02d_%02d" % [bough_index + 1, leaf_cluster_index + 1],
				branch_end + leaf_offset,
				Vector3(6.8 + float(leaf_cluster_index % 2) * 1.8,
					2.8 + float((leaf_cluster_index + bough_index) % 3),
					5.6 + float((leaf_cluster_index + 1) % 3)),
				_materials.green_glow if (leaf_cluster_index + bough_index) % 2 == 0 \
				else _materials.bio_nutrient_glow)
			var canopy_mesh := canopy.mesh as SphereMesh
			canopy_mesh.radial_segments = 8
			canopy_mesh.rings = 4
		for fruit_index in 3:
			var fruit_offset := Vector3(float(fruit_index - 1) * 4.0,
				-6.0 - float(fruit_index % 2) * 2.0, float((fruit_index + bough_index) % 2) * 3.0)
			_add_brick(cathedral,
				"MemoryFruit_%02d_%02d" % [bough_index + 1, fruit_index + 1],
				branch_end + fruit_offset, Bricks.build_crystal(.7, 2.4, .2, 6),
				_materials.island_cyan)
	_add_brick(cathedral, "LivingCathedralCrown", base + Vector3.UP * 91.0,
		Bricks.build_crystal(3.8, 11.0, .8, 6), _materials.bio_crown_crystal)


func _build_island_three_underside_accents(parent: Node3D, arena_center: Vector3,
		sanctuary_origin: Vector3) -> void:
	var underside := Node3D.new()
	underside.name = "LowPolyUndersideAccents"
	underside.set_meta("collision_policy", "decorative and unreachable")
	underside.set_meta("render_budget", "24 faceted accents")
	parent.add_child(underside)
	for support_index in 6:
		var angle := TAU * float(support_index) / 6.0
		var support_at := arena_center + Vector3(sin(angle) * 62.0, -18.0,
			cos(angle) * 62.0)
		_add_tapered_cylinder(underside, "IvoryUndersidePier_%02d" % (support_index + 1),
			support_at, 1.2, 3.3, 28.0, _materials.celestial_floor, 8)
		_add_brick(underside, "EmbeddedAetherCrystal_%02d" % (support_index + 1),
			support_at + Vector3.UP * (-15.0 - float(support_index % 2) * 4.0),
			Bricks.build_crystal(1.4, 6.5, .4, 6), _materials.island_cyan)
	for rock_index in 8:
		var angle := TAU * float(rock_index) / 8.0 + .23
		var rock_at := arena_center + Vector3(sin(angle) * (76.0 + rock_index % 3 * 5.0),
			-25.0 - float(rock_index % 3) * 7.0,
			cos(angle) * (76.0 + rock_index % 3 * 5.0))
		_add_tapered_cylinder(underside, "FacetedFloatingRock_%02d" % (rock_index + 1),
			rock_at, .35, 3.4 + float(rock_index % 2), 8.0 + rock_index % 3 * 3.0,
			_materials.floor_dark, 6)
	var tree_under_at := Vector3(sanctuary_origin.x, arena_center.y - 22.0,
		sanctuary_origin.z + 18.0)
	for brace_index in 4:
		var brace_angle := TAU * float(brace_index) / 4.0 + PI * .25
		_add_tapered_cylinder(underside, "TreeUndercroftBrace_%02d" % (brace_index + 1),
			tree_under_at + Vector3(sin(brace_angle) * 20.0, 0,
				cos(brace_angle) * 20.0), .9, 2.8, 30.0,
			_materials.floor_dark, 8)


func _on_island_three_object_completed(_save_id: String, _result: Dictionary) -> void:
	_refresh_island_three_completion_visuals.call_deferred()


func _refresh_island_three_completion_visuals() -> void:
	var geometry := get_node_or_null("WorldOneGeometry") as Node3D
	if geometry == null:
		return
	var campus := geometry.get_node_or_null("IslandThreeCivicSanctuary") as Node3D
	if campus == null:
		return
	var object_states := {}
	for object in _objects:
		if int(object.get_meta("physical_island", 0)) == 3:
			object_states[object.save_id] = bool(object.current_state.get("completed", false))
	var anchor_ids := [
		"world_one.warden_anchor.1",
		"world_one.warden_anchor.2",
		"world_one.warden_anchor.3",
	]
	var landmark_names := ["StormLensTower", "ResonanceForge", "LightningArchive"]
	var completed_anchors := 0
	for index in 3:
		var completed := bool(object_states.get(anchor_ids[index], false))
		if completed:
			completed_anchors += 1
		var state_node := campus.get_node_or_null(
			"StormworksGrandCourt/%s/CompletionStateVisuals" % landmark_names[index]) as Node3D
		if state_node != null:
			state_node.visible = completed
	var rain_complete := bool(object_states.get("world_one.calm_rain_basin", false))
	var rain_state := campus.get_node_or_null("RainHarvestObservatory/CompletionStateVisuals") as Node3D
	if rain_state != null:
		rain_state.visible = rain_complete
	var reflection_complete := bool(object_states.get("world_one.identity_reflection", false))
	var reflection_state := campus.get_node_or_null(
		"WisdomBasilicaPromenade/RootboundReflectionCourt/CompletionStateVisuals") as Node3D
	if reflection_state != null:
		reflection_state.visible = reflection_complete
	var tree := campus.get_node_or_null("OldestTreeLivingCathedral") as Node3D
	if tree != null:
		for root_index in 10:
			var vein := tree.get_node_or_null("CathedralRootVein_%02d" % (root_index + 1)) as Node3D
			if vein != null:
				vein.visible = root_index % 3 < completed_anchors
		for fruit in tree.find_children("MemoryFruit_*", "MeshInstance3D", true, false):
			(fruit as MeshInstance3D).visible = reflection_complete
		var crown := tree.get_node_or_null("LivingCathedralCrown") as MeshInstance3D
		if crown != null:
			crown.visible = reflection_complete
	campus.set_meta("completed_storm_landmarks", completed_anchors)
	campus.set_meta("rain_observatory_active", rain_complete)
	campus.set_meta("oldest_tree_awake", reflection_complete)


func _remove_island_three_gold_rings(geometry: Node3D, campus: Node3D,
		storm_zone: Node3D, sanctuary_zone: Node3D) -> void:
	var roots: Array[Node3D] = [campus, storm_zone, sanctuary_zone]
	var fusions := geometry.get_node_or_null("ThreeFusedSuperIslands") as Node3D
	if fusions != null and fusions.get_child_count() >= 3:
		roots.append(fusions.get_child(2) as Node3D)
	var removed_count := 0
	var visited: Dictionary = {}
	for search_root in roots:
		for candidate in search_root.find_children("*", "MeshInstance3D", true, false):
			var ring := candidate as MeshInstance3D
			if visited.has(ring.get_instance_id()):
				continue
			visited[ring.get_instance_id()] = true
			if ring.mesh is TorusMesh and _is_island_three_gold_material(
					_effective_mesh_material(ring)):
				ring.visible = false
				ring.set_meta("island_three_gold_ring_removed", true)
				removed_count += 1
	var visible_gold_ring_count := 0
	for search_root in roots:
		for candidate in search_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if mesh_instance.visible and mesh_instance.mesh is TorusMesh \
					and _is_island_three_gold_material(_effective_mesh_material(mesh_instance)):
				visible_gold_ring_count += 1
	campus.set_meta("gold_ring_policy", "no visible gold torus geometry")
	campus.set_meta("gold_rings_removed", removed_count)
	campus.set_meta("visible_gold_ring_count", visible_gold_ring_count)


func _remove_island_three_gold_lines(geometry: Node3D, campus: Node3D,
		storm_zone: Node3D, sanctuary_zone: Node3D) -> void:
	# Remove the long procedural brass strips and rods that crossed the quest
	# courts in the previous revision. Compact capitals, plinths and quest bodies
	# remain, so the architecture keeps its form without loose lines on the floor.
	var roots: Array[Node3D] = [campus, storm_zone, sanctuary_zone]
	var fusions := geometry.get_node_or_null("ThreeFusedSuperIslands") as Node3D
	if fusions != null and fusions.get_child_count() >= 3:
		roots.append(fusions.get_child(2) as Node3D)
	var removed_count := 0
	var visited: Dictionary = {}
	for search_root in roots:
		for candidate in search_root.find_children("*", "MeshInstance3D", true, false):
			var line := candidate as MeshInstance3D
			if visited.has(line.get_instance_id()):
				continue
			visited[line.get_instance_id()] = true
			var is_long_line := false
			if line.mesh is CylinderMesh:
				var cylinder := line.mesh as CylinderMesh
				var widest_radius := maxf(cylinder.top_radius, cylinder.bottom_radius)
				is_long_line = cylinder.height > 1.5 \
					and cylinder.height > widest_radius * 3.0
			elif line.mesh is BoxMesh:
				var size := (line.mesh as BoxMesh).size
				var dimensions := [size.x, size.y, size.z]
				dimensions.sort()
				is_long_line = float(dimensions[2]) > 2.5 \
					and float(dimensions[1]) < 4.0
			var is_obsolete_root_rail := line.name in [
				&"LeftLivingRootRail", &"RightLivingRootRail",
			]
			if (is_long_line and _is_island_three_gold_material(
					_effective_mesh_material(line))) \
					or is_obsolete_root_rail:
				line.visible = false
				line.set_meta("island_three_gold_line_removed", true)
				removed_count += 1
	var visible_gold_line_count := 0
	for search_root in roots:
		for candidate in search_root.find_children("*", "MeshInstance3D", true, false):
			var line := candidate as MeshInstance3D
			if not line.visible or not _is_island_three_gold_material(
					_effective_mesh_material(line)):
				continue
			if line.mesh is CylinderMesh:
				var cylinder := line.mesh as CylinderMesh
				var widest_radius := maxf(cylinder.top_radius, cylinder.bottom_radius)
				if cylinder.height > 1.5 and cylinder.height > widest_radius * 3.0:
					visible_gold_line_count += 1
			elif line.mesh is BoxMesh:
				var size := (line.mesh as BoxMesh).size
				var dimensions := [size.x, size.y, size.z]
				dimensions.sort()
				if float(dimensions[2]) > 2.5 and float(dimensions[1]) < 4.0:
					visible_gold_line_count += 1
	campus.set_meta("gold_line_policy", "no visible elongated gold geometry")
	campus.set_meta("gold_lines_removed", removed_count)
	campus.set_meta("visible_gold_line_count", visible_gold_line_count)


func _effective_mesh_material(mesh_instance: MeshInstance3D) -> Material:
	if mesh_instance.material_override != null:
		return mesh_instance.material_override
	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		return mesh_instance.get_active_material(0)
	return null


func _is_island_three_gold_material(material: Material) -> bool:
	if material in [
		_materials.astral_brass,
		_materials.gold,
		_materials.island_gold,
		_materials.bio_socket_gold,
		_materials.quest_brass,
		_materials.quest_gold_leaf,
	]:
		return true
	if not material is StandardMaterial3D:
		return false
	var colour := (material as StandardMaterial3D).albedo_color
	return colour.r > .45 and colour.r > colour.b * 1.35 \
		and colour.g > colour.b * 1.15


func _place_combat_population() -> void:
	_enemy_waves = {"network": [], "constellation": [], "ridge": [], "boss_adds": []}
	var specs := [
		["static_mite", "network", "02_living_network_forest", Vector3(-28, 3, 44)],
		["static_mite", "network", "02_living_network_forest", Vector3(35, 3, 62)],
		["glitch_sprout", "network", "02_living_network_forest", Vector3(-52, 3, -4)],
		["glitch_sprout", "network", "02_living_network_forest", Vector3(58, 3, -18)],
		["circuit_wisp", "constellation", "03_constellation_court", Vector3(-62, 4, 46)],
		["circuit_wisp", "constellation", "03_constellation_court", Vector3(0, 4, 66)],
		["circuit_wisp", "constellation", "03_constellation_court", Vector3(62, 4, 46)],
		["root_stalker", "ridge", "04_hope_path_ridge", Vector3(-14, 4, 72)],
		["blight_sentinel", "ridge", "04_hope_path_ridge", Vector3(14, 4, 72)],
		["circuit_wisp", "boss_adds", "05_thought_storm_arena", Vector3(-48, 4, -54)],
		["static_mite", "boss_adds", "05_thought_storm_arena", Vector3(48, 4, -54)],
	]
	if _uses_existing_mind_district():
		specs = [
			["static_mite", "network", "02_living_network_forest", Vector3(-18, 1, 16)],
			["static_mite", "network", "02_living_network_forest", Vector3(19, 1, 19)],
			["glitch_sprout", "network", "02_living_network_forest", Vector3(-22, 1, -14)],
			["glitch_sprout", "network", "02_living_network_forest", Vector3(24, 1, -12)],
			["circuit_wisp", "constellation", "03_constellation_court", Vector3(-28, 2, 24)],
			["circuit_wisp", "constellation", "03_constellation_court", Vector3(0, 2, 31)],
			["circuit_wisp", "constellation", "03_constellation_court", Vector3(28, 2, 24)],
			["root_stalker", "ridge", "04_hope_path_ridge", Vector3(-10, 1, 24)],
			["blight_sentinel", "ridge", "04_hope_path_ridge", Vector3(10, 1, 24)],
			["circuit_wisp", "boss_adds", "05_thought_storm_arena", Vector3(-20, 2, -18)],
			["static_mite", "boss_adds", "05_thought_storm_arena", Vector3(20, 1, -18)],
		]
	for index in specs.size():
		var spec: Array = specs[index]
		var enemy := EnemyScene.instantiate() as MindSparkEnemyBase
		enemy.name = "%s_%02d" % [str(spec[0]).to_pascal_case(), index + 1]
		enemy.definition = ENEMY_DEFINITIONS[str(spec[0])]
		enemy.encounter_id = str(spec[1])
		enemy.position = spec[3]
		enemy.active = false
		(_zone_nodes[str(spec[2])] as Node3D).add_child(enemy)
		_enemies.append(enemy)
		(_enemy_waves[str(spec[1])] as Array).append(enemy)
	_warden = WardenScene.instantiate()
	_warden.name = "ThoughtStormWardenBoss"
	_warden.position = Vector3(0, 3, 0)
	(_zone_nodes["05_thought_storm_arena"] as Node3D).add_child(_warden)
	var anchor_objects: Array[QuestObjectBase] = []
	for object in _objects:
		if object.definition.object_kind == QuestObjectDefinitionScript.ObjectKind.WARDEN_ANCHOR:
			anchor_objects.append(object)
	_warden.bind_anchors(anchor_objects)


func _place_collectibles() -> void:
	var forest := _zone_nodes["02_living_network_forest"] as Node3D
	for index in 2:
		var collectible := SparkCollectibleScene.instantiate() as MindSparkCollectible
		collectible.name = "ThoughtSpark_%d" % (index + 1)
		collectible.collectible_id = "world_one.spark.%d" % (index + 1)
		var collectible_positions := [Vector3(-72, 2, 72), Vector3(74, 2, -68)]
		if _uses_existing_mind_district():
			collectible_positions = [Vector3(-25, 1, 24), Vector3(27, 1, -21)]
		collectible.position = collectible_positions[index]
		forest.add_child(collectible)
		_collectibles.append(collectible)


func _place_cast() -> void:
	var cast_root := Node3D.new()
	cast_root.name = "SharedWorldOneCast"
	add_child(cast_root)
	var milo := MayorMiloScene.instantiate() as Node3D
	milo.position = get_zone_position("01_world_gate_landing") + Vector3(-12, 1, -10)
	milo.set_meta("role", "wise elder mayor and non-combat guide")
	cast_root.add_child(milo)
	_cast["milo"] = milo
	var guardian := MotherGuardianScene.instantiate() as Node3D
	guardian.position = get_zone_position("03_constellation_court") + Vector3(0, 2, -34)
	guardian.set_meta("role", "female Mother Guardian; hints and protection only")
	guardian.set_meta("never_attacks", true)
	cast_root.add_child(guardian)
	_cast["guardian"] = guardian


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "MindSparkWorldHUD"
	canvas.layer = 32
	add_child(canvas)
	var panel := ColorRect.new()
	panel.name = "ObjectPromptPanel"
	panel.color = Color(0.025, 0.06, 0.12, 0.88)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-360, -122)
	panel.size = Vector2(720, 96)
	panel.visible = false
	canvas.add_child(panel)
	_prompt = Label.new()
	_prompt.position = Vector2(18, 10)
	_prompt.size = Vector2(684, 34)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	panel.add_child(_prompt)
	_status = Label.new()
	_status.position = Vector2(18, 49)
	_status.size = Vector2(684, 32)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.modulate = Color("bff8ff")
	_status.add_theme_font_size_override("font_size", 17)
	panel.add_child(_status)


func _update_hud() -> void:
	if _prompt == null:
		return
	var panel := _prompt.get_parent() as Control
	if _island_one_puzzle != null:
		var puzzle_prompt := _island_one_puzzle.prompt_for_player(_player)
		if not puzzle_prompt.is_empty():
			panel.visible = true
			_prompt.text = str(puzzle_prompt.prompt)
			_status.text = str(puzzle_prompt.status)
			return
	var object := _nearest_object()
	panel.visible = object != null
	if object == null:
		return
	if object.save_id in ["world_one.evidence_scanner", "world_one.memory_board",
			"world_one.logic_gate", "world_one.perspective_lens", "world_one.truth_bridge"]:
		_prompt.text = "Q • OPEN " + object.definition.display_name.to_upper()
		var count := int(object.current_state.get("evidence_index", 0)) if object.save_id.ends_with("evidence_scanner") else int(object.current_state.get("progress", 0))
		var total := 3 if object.save_id.ends_with("evidence_scanner") else object.definition.validated_total()
		_status.text = "STATION COMPLETE" if bool(object.current_state.get("completed", false)) else "%d/%d • READ, EXPERIMENT, REVISE" % [count, total]
		return
	var actions := object.available_actions()
	var choices := PackedStringArray()
	for index in mini(actions.size(), 5):
		choices.append("%d %s" % [index + 1, str(actions[index]).replace("_", " ").to_upper()])
	_prompt.text = "Q • %s     %s" % [object.definition.action_prompt.replace("\n", " "), "   ".join(choices)]
	_status.text = "%s • %d/%d" % [object.definition.display_name.to_upper(),
		int(object.current_state.get("progress", 0)), object.definition.validated_total()]


func _build_recovery_volume(zone: Node3D, radius: float) -> void:
	var recovery := Area3D.new()
	recovery.name = "PerimeterRecoveryVolume"
	recovery.position.y = -42
	recovery.collision_layer = 0
	recovery.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(radius * 2.2, 36, radius * 2.2)
	collision.shape = shape
	recovery.add_child(collision)
	zone.add_child(recovery)
	recovery.body_entered.connect(_on_recovery_body_entered)


func _on_recovery_body_entered(body: Node3D) -> void:
	if body == _player and _player != null:
		var regions := get_parent().get_parent() if get_parent() != null and get_parent().get_parent() != null else null
		var floating_world := regions.get_parent() if regions != null else null
		if regions != null and floating_world != null and regions.has_method("get_safe_respawn"):
			var safe_local: Vector3 = regions.call("get_safe_respawn", floating_world.to_local(_player.global_position))
			_player.global_position = floating_world.to_global(safe_local)
		else:
			_player.global_position = _last_safe_position
		_player.velocity = Vector3.ZERO


func _build_organized_bio_tree_world(geometry: Node3D) -> void:
	var layout_root := Node3D.new()
	layout_root.name = "OrganizedMindSparkBioTreeWorld"
	layout_root.set_meta("planned_tree_total", 100)
	layout_root.set_meta("placement_policy", "authored deterministic rows, rings and arcs; no randomness")
	layout_root.set_meta("size_policy", "seeded random small-to-large scale; stable between game loads")
	layout_root.set_meta("hero_tree_count", 1)
	layout_root.set_meta("optimized_grove_tree_count", 99)
	geometry.add_child(layout_root)
	# Keep the optional station spur as the final authored geometry phase. The
	# organizer is metadata-only; the actual groves live under their six zones.
	geometry.move_child(layout_root, 0)
	var compact := _uses_existing_mind_district()
	var world_tree_index := 1
	for zone_layout in ORGANIZED_TREE_LAYOUTS:
		var zone_id := str(zone_layout.id)
		var zone := _zone_nodes[zone_id] as Node3D
		var grove := Node3D.new()
		grove.name = "%sDesignedBioTreeGrove" % zone_id.to_pascal_case()
		grove.set_meta("zone_id", zone_id)
		grove.set_meta("design_pattern", str(zone_layout.pattern))
		grove.set_meta("planned_total", int(zone_layout.total))
		grove.set_meta("randomized", false)
		grove.set_meta("size_randomized", true)
		zone.add_child(grove)
		var hero_count := 1 if zone_id == "06_oldest_tree_sanctuary" else 0
		var grove_count := int(zone_layout.total) - hero_count
		var positions := _designed_grove_positions(zone_id, grove_count, compact)
		for local_index in positions.size():
			# Keep the ceremonial star-gate silhouette readable. Trees still frame
			# the threshold, but none may occupy its opening or first-person reveal.
			if not compact and zone_id in ["01_world_gate_landing", "02_living_network_forest"]:
				var star_gate := get_island_one_heavenly_star_gate()
				if star_gate != null:
					var candidate_global := zone.to_global(positions[local_index])
					var separation := Vector2(candidate_global.x - star_gate.global_position.x,
						candidate_global.z - star_gate.global_position.z)
					if separation.length() < 58.0:
						var side := -1.0 if local_index % 2 == 0 else 1.0
						var depth := -18.0 + float(local_index % 3) * 18.0
						var shifted_global := star_gate.to_global(Vector3(side * 76.0, 0.0, depth))
						shifted_global.y = candidate_global.y
						positions[local_index] = zone.to_local(shifted_global)
			var tree_scale := _designed_grove_tree_scale(zone_id, local_index, compact)
			if not compact and zone_id in ["01_world_gate_landing", "02_living_network_forest"]:
				positions[local_index] = _clear_garden_position(zone, positions[local_index], tree_scale)
			var grove_tree := _build_grove_bio_tree(grove, positions[local_index],
				tree_scale, world_tree_index, local_index)
			grove_tree.set_meta("zone_id", zone_id)
			grove_tree.set_meta("zone_tree_index", local_index + 1)
			grove_tree.set_meta("layout_pattern", str(zone_layout.pattern))
			world_tree_index += 1
		if hero_count == 1:
			var hero := zone.find_child("MindSparkBioDataTree", true, false) as Node3D
			if hero != null:
				hero.add_to_group("mind_spark_organized_tree")
				hero.set_meta("world_tree_index", world_tree_index)
				hero.set_meta("zone_id", zone_id)
				hero.set_meta("zone_tree_index", int(zone_layout.total))
				hero.set_meta("tree_lod", "hero_full_detail")
				world_tree_index += 1
	set_meta("organized_tree_count", world_tree_index - 1)
	set_meta("organized_tree_distribution", "10/30/14/14/8/24")


func _clear_garden_position(zone: Node3D, preferred: Vector3, tree_scale: float) -> Vector3:
	# Whole canopy envelopes, not just trunk centers. Preserve authored station
	# positions and two-lobe circulation while finding the nearest planting pocket.
	var zone_index := 0 if str(zone.get_meta("zone_id")) == "01_world_gate_landing" else 1
	var radius := float(ZONES[zone_index].radius)
	var canopy := 18.0 * tree_scale + 2.0
	var initial := atan2(preferred.x, preferred.z)
	for attempt in 720:
		var ring := mini(attempt / 144, 4)
		var angle := initial + float(attempt % 144) * TAU / 144.0
		var distance := minf(Vector2(preferred.x, preferred.z).length(), radius - canopy - 14.0) - float(ring) * 9.0
		var candidate := Vector3(sin(angle)*distance, preferred.y, cos(angle)*distance)
		var global_at := zone.to_global(candidate)
		var clear := true
		var gate := get_island_one_heavenly_star_gate()
		if gate != null and Vector2(global_at.x-gate.global_position.x, global_at.z-gate.global_position.z).length() < 58.0 + canopy:
			continue
		for tree in get_tree().get_nodes_in_group("mind_spark_organized_tree"):
			if tree is Node3D and tree.has_meta("garden_canopy_radius"):
				if Vector2(global_at.x-tree.global_position.x, global_at.z-tree.global_position.z).length() < canopy + float(tree.get_meta("garden_canopy_radius")) + 3.0:
					clear = false
		if _island_one_puzzle != null:
			for control in _island_one_puzzle.get_node("PuzzleControls").get_children():
				if control is Node3D and Vector2(global_at.x-control.global_position.x, global_at.z-control.global_position.z).length() < canopy + 12.0:
					clear = false
		# A clear promenade through the joined courts and to both bridge ends.
		for target_index in [1-zone_index, 5 if zone_index == 0 else 2]:
			var delta: Vector3 = ZONES[target_index].position - ZONES[zone_index].position
			var direction := Vector2(delta.x,delta.z).normalized()
			var point := Vector2(candidate.x,candidate.z)
			if point.dot(direction) > 0 and absf(point.cross(direction)) < 12.0 + canopy:
				clear = false
		if clear:
			return candidate
	push_error("No clear planting pocket for " + str(zone.name))
	return preferred


func _is_exposed_garden_edge(zone_index: int, angle: float) -> bool:
	var center: Vector3 = ZONES[zone_index].position
	var radius := float(ZONES[zone_index].radius) * .985
	var radial := Vector2(sin(angle),cos(angle))
	var at := Vector2(center.x,center.z) + radial * radius
	var paired_index := zone_index ^ 1
	var other: Vector3 = ZONES[paired_index].position
	if at.distance_to(Vector2(other.x,other.z)) < float(ZONES[paired_index].radius) + 2.0:
		return false
	if zone_index == 5:
		return true # Sanctuary is the terminal district, with no sixth sky bridge.
	var exit_index := (5 if zone_index == 0 else 2) if zone_index < 2 else (zone_index - 1 if zone_index % 2 == 0 else zone_index + 1)
	var exit: Vector3 = ZONES[exit_index].position - center
	var direction := Vector2(exit.x,exit.z).normalized()
	var opening_half_width := 30.0 if zone_index < 2 else 18.0
	return not (radial.dot(direction) > 0 and absf(radial.cross(direction))*radius < opening_half_width)


func _repair_island_one_legacy_openings(parent: Node3D, first_zone := 0) -> void:
	var repairs := Node3D.new()
	repairs.name = ["IslandOnePerimeterRepairs", "IslandTwoPerimeterRepairs", "IslandThreePerimeterRepairs"][first_zone / 2]
	repairs.set_meta("preserve_authored_nodes", true)
	parent.add_child(repairs)
	for zone_index in range(first_zone, first_zone + 2):
		var center: Vector3 = ZONES[zone_index].position
		var radius := float(ZONES[zone_index].radius) * 0.985
		var zone: Node3D = _zone_nodes[ZONES[zone_index].id]
		# Replace, never stack over, the old incomplete reference rail batch.
		for old in zone.find_children("Railing_*", "MeshInstance3D", true, false):
			old.visible = false
			old.set_meta("preserve_authored_nodes",true)
		for bay in 24:
			var start := TAU * float(bay) / 24.0
			# Split at exact current route/interior boundaries. Map the reference
			# module onto contiguous exposed sub-arcs rather than omit whole bays.
			var run_start := -1
			for step in 7:
				var exposed := step < 6 and _is_exposed_garden_edge(zone_index,start + (float(step)+.5)*TAU/144.0)
				if exposed and run_start < 0:
					run_start = step
				if not exposed and run_start >= 0:
					var a := start + float(run_start)*TAU/144.0
					var b := start + float(step)*TAU/144.0
					var panel := preload("res://assets3D/mind_spark/echo_garden_benchmark/export/rail_bay.glb").instantiate() as Node3D
					panel.name = "ReferenceScrollwork_%d_%d" % [zone_index,bay]
					panel.position = center
					panel.rotation.y = (a+b)*.5
					panel.scale = Vector3.ONE * float(ZONES[zone_index].radius)
					# Short terminal bays are regenerated in polar coordinates, so
					# their scrollwork follows the same curvature without shear.
					if step-run_start != 6:
						_compress_railing_arc(panel,float(step-run_start)/6.0)
					repairs.add_child(panel)
					for end in [a,b]:
						var key := "ReferencePost_%d_%d" % [zone_index,roundi(fposmod(end,TAU)*144.0/TAU)%144]
						if repairs.has_node(key):
							continue
						var post := preload("res://assets3D/mind_spark/echo_garden_benchmark/export/rail_post.glb").instantiate() as Node3D
						post.name = key
						post.position = center
						post.rotation.y = end
						post.scale = Vector3.ONE * float(ZONES[zone_index].radius)
						repairs.add_child(post)
					run_start = -1
		for segment in 144:
			var angle := TAU * (float(segment) + .5) / 144.0
			var radial := Vector2(sin(angle), cos(angle))
			var at := center + Vector3(radial.x * radius, 0, radial.y * radius)
			if not _is_exposed_garden_edge(zone_index,angle):
				continue
			at.y = _zone_floor_surface_y(center)
			var length := TAU * radius / 144.0 + .12
			var yaw := atan2(radial.x, radial.y)
			var name := "RepairedBay_%d_%03d" % [zone_index, segment]
			var collision := _add_box(repairs, name, at + Vector3.UP * 5.0,
				Vector3(length, 10.0, .8), _materials.sanctum_ivory, true, yaw)
			collision.visible = false
	if first_zone == 2:
		_consolidate_perimeter_posts(repairs)


func _consolidate_perimeter_posts(repairs: Node3D) -> void:
	# Arc endpoints are unique by angle, but endpoints on short runs or on the
	# other fused lobe can still occupy the same physical pier footprint.
	# Consolidate connected spatial clusters, not just identical node names.
	var pending: Array[Node3D] = []
	for child in repairs.get_children():
		if str(child.name).begins_with("ReferencePost_"):
			pending.append(child)
	var merged := 0
	while not pending.is_empty():
		var cluster: Array[Node3D] = [pending.pop_front()]
		var cursor := 0
		while cursor < cluster.size():
			var source := _perimeter_post_anchor(cluster[cursor])
			for i in range(pending.size() - 1, -1, -1):
				var candidate := _perimeter_post_anchor(pending[i])
				if Vector2(source.x-candidate.x, source.z-candidate.z).length() < 14.0:
					cluster.append(pending[i])
					pending.remove_at(i)
			cursor += 1
		if cluster.size() < 2: continue
		var average := Vector3.ZERO
		for post in cluster: average += _perimeter_post_anchor(post)
		average /= cluster.size()
		var keeper := cluster[0]
		var shift := average - _perimeter_post_anchor(keeper)
		shift.y = 0
		keeper.global_position += shift
		keeper.set_meta("consolidated_post_count", cluster.size())
		for i in range(1, cluster.size()):
			cluster[i].visible = false
			cluster[i].set_meta("replaced_by_shared_pier", keeper.name)
			merged += 1
	repairs.set_meta("consolidated_duplicate_posts", merged)


func _perimeter_post_anchor(post: Node3D) -> Vector3:
	# GLB vertices are authored around the island rim, not the root origin.
	var mesh := post.get_child(0) as MeshInstance3D
	return mesh.to_global(mesh.get_aabb().get_center())


func _compress_railing_arc(root_node: Node, factor: float) -> void:
	for child in root_node.get_children():
		_compress_railing_arc(child,factor)
	if root_node is MeshInstance3D:
		var instance := root_node as MeshInstance3D
		var source := instance.mesh
		var mesh := ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for index in vertices.size():
				var v := vertices[index]
				var angle := atan2(v.x,v.z)*factor
				var radius := Vector2(v.x,v.z).length()
				vertices[index] = Vector3(sin(angle)*radius,v.y,cos(angle)*radius)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			var temporary := ArrayMesh.new()
			temporary.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var builder := SurfaceTool.new()
			builder.create_from(temporary,0)
			builder.generate_normals()
			builder.set_material(source.surface_get_material(surface))
			builder.commit(mesh)
		instance.mesh = mesh


func _designed_grove_positions(zone_id: String, count: int,
		compact: bool) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	match zone_id:
		"01_world_gate_landing":
			var side_distance := 30.0 if compact else 70.0
			var row_extent := 24.0 if compact else 58.0
			for row_index in 5:
				var row_z := lerpf(-row_extent, row_extent, float(row_index) / 4.0)
				positions.append(Vector3(-side_distance, 0, row_z))
				positions.append(Vector3(side_distance, 0, row_z))
		"02_living_network_forest":
			_append_designed_tree_ring(positions, 10, 34.0 if compact else 92.0, PI * 0.10)
			_append_designed_tree_ring(positions, 20, 50.0 if compact else 148.0, PI * 0.05)
		"03_constellation_court":
			_append_designed_tree_ring(positions, count, 34.0 if compact else 134.0,
				PI / float(count))
		"04_hope_path_ridge":
			var arc_radius := 32.0 if compact else 86.0
			for tree_index in count:
				var progress := float(tree_index) / float(count - 1)
				var angle := lerpf(-PI * 0.82, PI * 0.82, progress)
				positions.append(Vector3(sin(angle) * arc_radius, 0,
					cos(angle) * arc_radius))
		"05_thought_storm_arena":
			_append_designed_tree_ring(positions, count, 45.0 if compact else 166.0,
				PI / 8.0)
		"06_oldest_tree_sanctuary":
			_append_designed_tree_ring(positions, count, 40.0 if compact else 136.0,
				PI / float(count))
	return positions


func _append_designed_tree_ring(positions: Array[Vector3], count: int,
		radius: float, phase: float) -> void:
	for tree_index in count:
		var angle := phase + TAU * float(tree_index) / float(count)
		positions.append(Vector3(sin(angle) * radius, 0, cos(angle) * radius))


func _designed_grove_tree_scale(zone_id: String, local_index: int,
		compact: bool) -> float:
	# Seeded variation reads as natural growth while remaining reproducible for
	# level design, screenshots and collision audits. Position is still authored.
	var random_size := RandomNumberGenerator.new()
	random_size.seed = 260317 + zone_id.hash() * 1009 + local_index * 7919
	var scale_value := random_size.randf_range(0.10, 0.22) \
		if compact else random_size.randf_range(0.28, 0.68)
	if zone_id == "02_living_network_forest":
		scale_value *= 1.05
	elif zone_id == "05_thought_storm_arena":
		scale_value *= 0.95
	elif zone_id == "06_oldest_tree_sanctuary":
		scale_value *= 0.90
	return scale_value


func _build_grove_bio_tree(parent: Node3D, at: Vector3, tree_scale: float,
		world_index: int, variant: int) -> Node3D:
	var tree := Node3D.new()
	tree.name = "MindSparkGroveTree_%03d" % world_index
	tree.position = at
	tree.scale = Vector3.ONE * tree_scale
	tree.rotation.y = atan2(at.x, at.z) + PI
	tree.add_to_group("mind_spark_organized_tree")
	tree.set_meta("world_tree_index", world_index)
	tree.set_meta("tree_lod", "gameplay_grove_editable")
	tree.set_meta("randomized", false)
	tree.set_meta("placement_randomized", false)
	tree.set_meta("size_randomized", true)
	tree.set_meta("growth_scale", tree_scale)
	tree.set_meta("visual_system", "nature bark + green nutrients + cyan data + violet magic")
	parent.add_child(tree)
	if str(parent.get_meta("zone_id", "")) in ["01_world_gate_landing", "02_living_network_forest"]:
		var sapling_models := [
			preload("res://assets3D/mind_spark/echo_garden_benchmark/export/echo_sapling.glb"),
			preload("res://assets3D/mind_spark/echo_garden_benchmark/export/echo_sapling_1.glb"),
			preload("res://assets3D/mind_spark/echo_garden_benchmark/export/echo_sapling_2.glb")]
		var sapling := sapling_models[variant % 3].instantiate() as Node3D
		sapling.name = "HeavenlySapling"
		tree.add_child(sapling)
		tree.set_meta("visual_system", "pale clustered canopy matching Echo Garden hero")
		tree.set_meta("preserve_authored_nodes", true)
		tree.set_meta("garden_canopy_radius", 18.0 * tree_scale + 2.0)
		tree.set_meta("garden_variant", variant % 3)
		var bed_collision := _add_cylinder(tree,"ContainedPlantingCollision",Vector3(0,.5,0),11.25,1.0,_materials.sanctum_ivory,true,16)
		bed_collision.visible = false
		var trunk_collision := _add_cylinder(tree,"SaplingTrunkCollision",Vector3(0,8,0),2.0,16.0,_materials.sanctum_ivory,true,10)
		trunk_collision.visible = false
		return tree
	var socket := _add_cylinder(tree, "GroveSocketCore", Vector3(0, 0.70, 0),
		4.8, 1.4, _materials.bio_gunmetal, false, 16)
	socket.set_meta("editable_component", true)
	_add_torus(tree, "GroveSocketGoldRing", Vector3(0, 1.35, 0), 3.30, 4.45,
		_materials.bio_socket_gold)
	_add_torus(tree, "GroveSocketDataRing", Vector3(0, 0.32, 0), 4.18, 4.65,
		_materials.island_cyan)
	var trunk_points: Array[Vector3] = []
	var bend_sign := -1.0 if variant % 2 == 0 else 1.0
	for point_index in 6:
		var progress := float(point_index) / 5.0
		trunk_points.append(Vector3(
			bend_sign * sin(progress * PI) * (2.1 + float(variant % 3) * 0.28),
			1.8 + progress * (28.0 + float(variant % 4) * 1.4),
			sin(progress * TAU) * (0.85 + float(variant % 2) * 0.22)))
	for segment_index in 5:
		var start: Vector3 = trunk_points[segment_index]
		var finish: Vector3 = trunk_points[segment_index + 1]
		var start_radius := lerpf(2.35, 1.18, float(segment_index) / 5.0)
		var end_radius := lerpf(2.35, 1.18, float(segment_index + 1) / 5.0)
		_add_cable_between(tree, "GroveTrunk_%02d" % (segment_index + 1),
			start, finish, start_radius, end_radius, _materials.bio_bark, 12)
		_add_cable_between(tree, "GroveNutrientFiber_%02d" % (segment_index + 1),
			start + Vector3(-0.62, 0, 1.55), finish + Vector3(-0.42, 0, 0.92),
			0.10, 0.07, _materials.bio_nutrient_glow, 8)
		_add_cable_between(tree, "GroveDataFiber_%02d" % (segment_index + 1),
			start + Vector3(0.0, 0, 1.72), finish + Vector3(0.0, 0, 1.02),
			0.085, 0.055, _materials.bio_data_glow, 8)
		_add_cable_between(tree, "GroveMagicFiber_%02d" % (segment_index + 1),
			start + Vector3(0.60, 0, 1.48), finish + Vector3(0.40, 0, 0.88),
			0.060, 0.040, _materials.island_violet_energy, 8)
	var canopy_center: Vector3 = trunk_points[-1]
	for branch_index in 4:
		var angle := TAU * float(branch_index) / 4.0 + float(variant % 5) * 0.07
		var radial := Vector3(sin(angle), 0, cos(angle))
		var tangent := Vector3(cos(angle), 0, -sin(angle))
		var branch_start := trunk_points[3 + branch_index % 2]
		var branch_middle := branch_start + radial * (5.2 + float(branch_index % 2)) \
			+ tangent * (0.8 if branch_index % 2 == 0 else -0.7) + Vector3.UP * 2.6
		var branch_finish := branch_start + radial * (10.4 + float((variant + branch_index) % 3)) \
			+ Vector3.UP * (4.2 + float(branch_index % 2) * 1.2)
		_add_cable_between(tree, "GroveBranch_%02d_A" % (branch_index + 1),
			branch_start, branch_middle, 1.05, 0.66, _materials.bio_bark, 12)
		_add_cable_between(tree, "GroveBranch_%02d_B" % (branch_index + 1),
			branch_middle, branch_finish, 0.66, 0.34, _materials.bio_bark, 12)
		_add_cable_between(tree, "GroveBranchData_%02d" % (branch_index + 1),
			branch_start + Vector3.UP * 0.48, branch_finish + Vector3.UP * 0.20,
			0.065, 0.035, _materials.bio_data_glow, 8)
		var cap_radius := 3.6 + float((variant + branch_index) % 3) * 0.34
		var cap_height := cap_radius * 0.34
		var cap_at := branch_finish + Vector3.UP * (cap_height + 0.65)
		_add_cable_between(tree, "GroveMushroomStem_%02d" % (branch_index + 1),
			branch_finish, cap_at + Vector3.DOWN * cap_height,
			0.34, 0.24, _materials.bio_gunmetal, 10)
		var cap := _add_brick(tree, "GroveMushroomCap_%02d" % (branch_index + 1),
			Vector3.ZERO, _build_grove_mushroom_mesh(cap_at, cap_radius, cap_height,
				4, float(variant + branch_index) * 0.17), _materials.bio_mushroom)
		cap.set_meta("editable_component", true)
		if branch_index in [1, 3]:
			var node_start := cap_at + radial * cap_radius * 0.72 + Vector3.DOWN * 0.28
			var node_finish := node_start + Vector3.DOWN * (3.2 + float(variant % 3) * 0.35)
			_add_cable_between(tree, "GroveHangingFilament_%02d" % (branch_index + 1),
				node_start, node_finish, 0.050, 0.030, _materials.bio_data_glow, 8)
			var node := _add_sphere(tree, "GroveHangingNode_%02d" % (branch_index + 1),
				node_finish + Vector3.DOWN * 0.42, Vector3(0.34, 0.52, 0.34),
				_materials.bio_data_glow)
			node.set_meta("editable_component", true)
	var crown_radius := 4.6 + float(variant % 3) * 0.22
	var crown_height := crown_radius * 0.34
	var crown_at := canopy_center + Vector3.UP * 4.3
	var crown := _add_brick(tree, "GroveCrownMushroom", Vector3.ZERO,
		_build_grove_mushroom_mesh(crown_at, crown_radius, crown_height, 5,
			float(variant) * 0.11), _materials.bio_mushroom_mid)
	crown.set_meta("editable_component", true)
	_add_torus(tree, "GroveCrownCrystalSocket", crown_at + Vector3.UP * (crown_height + 0.42),
		0.72, 1.06, _materials.bio_socket_gold)
	var crystal := _add_brick(tree, "GroveCrownCrystal",
		crown_at + Vector3.UP * (crown_height + 2.0),
		Bricks.build_crystal(1.15, 3.2, 0.30, 6), _materials.bio_crown_crystal)
	crystal.set_meta("editable_component", true)
	return tree


func _build_grove_mushroom_mesh(at: Vector3, radius: float, height: float,
		lobes: int, phase: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const COLUMNS := 16
	const ROWS := 8
	for row_index in ROWS:
		var latitude_a := -PI * 0.5 + PI * float(row_index) / float(ROWS)
		var latitude_b := -PI * 0.5 + PI * float(row_index + 1) / float(ROWS)
		for column_index in COLUMNS:
			var angle_a := TAU * float(column_index) / float(COLUMNS) + phase
			var angle_b := TAU * float(column_index + 1) / float(COLUMNS) + phase
			var p00 := _grove_mushroom_point(at, radius, height, latitude_a,
				angle_a, lobes, phase)
			var p01 := _grove_mushroom_point(at, radius, height, latitude_a,
				angle_b, lobes, phase)
			var p10 := _grove_mushroom_point(at, radius, height, latitude_b,
				angle_a, lobes, phase)
			var p11 := _grove_mushroom_point(at, radius, height, latitude_b,
				angle_b, lobes, phase)
			for point in [p00, p11, p10, p00, p01, p11]:
				surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()


func _grove_mushroom_point(at: Vector3, radius: float, height: float,
		latitude: float, angle: float, lobes: int, phase: float) -> Vector3:
	var radial_progress := cos(latitude)
	var lobe_shape := 1.0 + 0.055 * pow(maxf(0.0, radial_progress), 1.4) \
		* cos(float(lobes) * (angle - phase))
	return at + Vector3(sin(angle) * radius * radial_progress * lobe_shape,
		sin(latitude) * height, cos(angle) * radius * radial_progress * lobe_shape)


func _build_server_tree(parent: Node3D, at: Vector3, height: float, variant: int) -> void:
	var tree := Node3D.new()
	tree.name = "ServerTree_%02d" % variant
	tree.position = at
	parent.add_child(tree)
	# Root flare, so the trunk meets the deck instead of intersecting it.
	_add_brick(tree, "RootFlare", Vector3(0, 0, 0),
		Bricks.build_drum(9.0, 6.0, 4.2, 7), _materials.floor_dark)
	_build_tree_root_outlayer(tree, Vector3(0, 0.45, 0), 5 + variant % 3,
		11.0 + float(variant % 4) * 1.4, 0.48, variant)
	# Tapered faceted trunk rather than a straight box: it keeps a readable
	# silhouette from any angle and catches the light face by face.
	_add_brick(tree, "DarkGlassTrunk", Vector3(0, 3.4, 0),
		Bricks.build_drum(6.0, 3.4, height, 7), _materials.floor_dark)
	var trunk_body := StaticBody3D.new()
	trunk_body.name = "DarkGlassTrunkCollision"
	trunk_body.position = Vector3(0, height * 0.5, 0)
	var trunk_shape := CollisionShape3D.new()
	var trunk_cyl := CylinderShape3D.new()
	trunk_cyl.radius = 6.0
	trunk_cyl.height = height
	trunk_shape.shape = trunk_cyl
	trunk_body.add_child(trunk_shape)
	tree.add_child(trunk_body)

	_add_brick(tree, "CyanDataSeam", Vector3(0, height * 0.52, 4.6),
		Bricks.build_bevel_box(Vector3(1.0, height * 0.72, 0.5), 0.18), _materials.cyan)

	# Canopy as stacked tiers, widest at the bottom. Sphere blobs read as
	# floating balls once the camera is close; tiers keep a tree silhouette.
	for leaf in 3:
		var t := float(leaf) / 2.0
		var wide: float = lerpf(15.0, 7.0, t)
		_add_brick(tree, "VioletCanopy_%d" % leaf, Vector3(0, height * 0.72 + float(leaf) * 5.0, 0),
			Bricks.build_drum(wide, wide * 0.55, 3.4, 9), _materials.violet,
			float(leaf) * 0.7)
	_add_brick(tree, "CanopyTip", Vector3(0, height + 8.0, 0),
		Bricks.build_crystal(2.2, 7.0, 0.45, 6), _materials.cyan)


func _add_circuit_walkway(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, width: float) -> void:
	var direction := finish - start
	var length := direction.length()
	var middle := start.lerp(finish, 0.5)
	var yaw := atan2(direction.x, direction.z)
	var slope := -atan2(direction.y, Vector2(direction.x, direction.z).length())
	var deck := _add_box(parent, node_name, middle,
		Vector3(width, CIRCUIT_ROUTE_DECK_THICKNESS, length), _materials.stone, true, yaw)
	deck.set_meta("walk_surface_start_y", start.y + CIRCUIT_ROUTE_DECK_THICKNESS * 0.5)
	deck.set_meta("walk_surface_finish_y", finish.y + CIRCUIT_ROUTE_DECK_THICKNESS * 0.5)
	deck.set_meta("symmetry_axis", direction.normalized())
	deck.rotation.x = slope
	var body := parent.get_node("%sCollision" % node_name) as StaticBody3D
	body.rotation = deck.rotation
	var seam := _add_box(parent, "%sCyanSeam" % node_name, middle + Vector3(0, 1.3, 0),
		Vector3(2.4, 0.28, length - 3), _materials.cyan, false, yaw)
	seam.rotation.x = slope
	var side_axis := Vector3(cos(yaw), 0, -sin(yaw))
	for side in [-1.0, 1.0]:
		var rail_name := "%s%sRail" % [node_name, "Left" if side < 0.0 else "Right"]
		var rail_pos: Vector3 = middle + side_axis * float(side) * (width * 0.5 - 0.7) + Vector3(0, 2.0, 0)
		var rail := _add_box(parent, rail_name, rail_pos,
			Vector3(1.1, 2.2, length), _materials.floor_grid, true, yaw)
		rail.rotation.x = slope
		(parent.get_node("%sCollision" % rail_name) as StaticBody3D).rotation = rail.rotation


func _build_arch(parent: Node3D, at: Vector3, width: float, height: float, material: Material, text: String) -> Node3D:
	var arch := Node3D.new()
	arch.name = text.get_slice("•", 0).strip_edges().to_pascal_case()
	arch.position = at
	parent.add_child(arch)
	_add_box(arch, "Left", Vector3(-width * 0.5, height * 0.5, 0), Vector3(5, height, 7), material, true)
	_add_box(arch, "Right", Vector3(width * 0.5, height * 0.5, 0), Vector3(5, height, 7), material, true)
	_add_box(arch, "Top", Vector3(0, height, 0), Vector3(width + 5, 5, 7), material, true)
	_add_label(arch, text, Vector3(0, height + 12, 0), Color("e8fbff"), 30)
	return arch


func _build_materials() -> void:
	_materials.floor_dark = _textured_material(Color("10172b"), Color("17243b"), Color("244d68"), 0.72, 16)
	_materials.floor_grid = _textured_material(Color("263852"), Color("334b67"), Color("2cd7e8"), 0.55, 12)
	_materials.stone = _material(Color("aeb6ca"), 0.86)
	_materials.astral_brass = _material(Color("c49a45"), 0.24, Color("805d22"), 0.10)
	_materials.astral_brass.metallic = 0.82
	_materials.astral_brass.metallic_specular = 0.86
	_materials.astral_glass = _material(Color("5eaaa8"), 0.30, Color("8ad4c8"), 0.12)
	_materials.arrival_glass = _material(Color("70b9b5", 0.46), 0.24, Color("a5e7da"), 0.38)
	var arrival_glass := _materials.arrival_glass as StandardMaterial3D
	arrival_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	arrival_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	arrival_glass.metallic = 0.18
	arrival_glass.metallic_specular = 0.72
	_materials.astral_lavender = _material(Color("82788e"), 0.42, Color("ad9cbe"), 0.08)
	_materials.cyan = _material(Color("2cd7e8"), 0.28, Color("27def2"), 1.7)
	_materials.violet = _material(Color("7755b8"), 0.55, Color("8d63e0"), 0.8)
	_materials.green_glow = _material(Color("4f9f73"), 0.76, Color("48c47a"), 0.72)
	_materials.gold = _material(Color("f0c85a"), 0.22, Color("ffd56b"), 1.60)
	_materials.gold.metallic = 0.78
	_materials.gold.metallic_specular = 0.90
	_materials.storm = _textured_material(
		Color("28203c"), Color("3d3057"), Color("9b74e2"), 0.46, 10)
	_materials.trunk = _material(Color("654735"), 0.92)
	_materials.constellation_floor = _textured_material(
		Color("202746"), Color("34315e"), Color("8d63e0"), 0.52, 16)
	_materials.hope_floor = _textured_material(
		Color("355747"), Color("4f7257"), Color("e5bd55"), 0.76, 12)
	_materials.sanctuary_floor = _textured_material(
		Color("2e4f42"), Color("476a52"), Color("8dffc5"), 0.82, 16)
	# Base surfaces stay restrained. The approved concept artwork is rebuilt as
	# editable raised geometry by _build_surface_detail_network() instead of UV
	# projection, preventing stretching and keeping the island visually alive.
	_materials.island_deck = _textured_material(
		Color("58677c"), Color("647389"), Color("7d8da2"), 0.66, 32)
	# Only the six land-floor backing shells change palette. The original
	# island_deck material remains available to existing Bio-Data Tree parts.
	_materials.celestial_floor = _textured_material(
		Color("eee5d2"), Color("fff8e9"), Color("c6aa72"), 0.58, 32)
	_materials.celestial_floor.metallic_specular = 0.44
	# A warmer, softly luminous finish keeps the Thought Sanctum distinct and
	# readable beneath the glass conservatory without turning it into neon.
	_materials.sanctum_ivory = _material(
		Color("fff1d7"), 0.30, Color("ffdf9d"), 0.16)
	_materials.sanctum_ivory.metallic_specular = 0.58
	_materials.sanctum_dial = _material(
		Color("214f5c"), 0.22, Color("70e3db"), 0.52)
	_materials.sanctum_dial.metallic = 0.36
	_materials.sanctum_lavender_glass = _material(
		Color("b89ad8", 0.38), 0.24, Color("d8b8ff"), 0.30)
	_materials.sanctum_lavender_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials.sanctum_lavender_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Production quest props use a compact procedural PBR library. The albedo,
	# roughness and normal maps are generated once at world build time, keeping
	# the low-poly assets self-contained and Web-export safe while giving every
	# bevel and facet a material response instead of a flat prototype colour.
	_materials.quest_ivory = _low_poly_surface_material(
		Color("eadfc8"), Color("fff4dc"), Color("b99d72"), 0.68, 0.04, 11, 16)
	_materials.quest_ivory_inset = _low_poly_surface_material(
		Color("c8b99d"), Color("e8dcc4"), Color("927958"), 0.76, 0.02, 17, 12)
	_materials.quest_brass = _low_poly_surface_material(
		Color("9f6b24"), Color("e0b961"), Color("664015"), 0.34, 0.84, 23, 10)
	_materials.quest_gold_leaf = _low_poly_surface_material(
		Color("d6a638"), Color("ffe68b"), Color("8f5f17"), 0.28, 0.78, 31, 12,
		Color("ffce58"), 0.20)
	_materials.quest_teal_enamel = _low_poly_surface_material(
		Color("176b70"), Color("54b9ad"), Color("0b414b"), 0.38, 0.44, 41, 14,
		Color("54d9ca"), 0.12)
	_materials.quest_lavender_enamel = _low_poly_surface_material(
		Color("665080"), Color("b397c5"), Color("3b294d"), 0.42, 0.34, 53, 14,
		Color("c6a2e5"), 0.10)
	_materials.island_deck_panel_a = _material(Color("65758c"), 0.62)
	_materials.island_deck_panel_b = _material(Color("4b596e"), 0.72)
	_materials.island_rim = _material(Color("172238"), 0.68)
	_materials.island_underside = _material(Color("0d1729"), 0.76)
	# A darker glass body leaves enough contrast for the separately modelled
	# cyan/gold fracture rails to read, while retaining an internal crystal glow.
	_materials.island_crystal = _material(Color("1595b0"), 0.15, Color("45e4f5"), 0.42)
	_materials.island_crystal_facet_dark = _material(Color("063f59"), 0.27, Color("087f99"), 0.05)
	_materials.island_crystal_facet_mid = _material(Color("0e7895"), 0.20, Color("16afc7"), 0.11)
	_materials.island_crystal_facet_bright = _material(Color("25a9bf"), 0.16, Color("32d5e7"), 0.22)
	for facet_material in [_materials.island_crystal_facet_dark,
		_materials.island_crystal_facet_mid, _materials.island_crystal_facet_bright]:
		(facet_material as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials.island_cyan = _material(Color("1cb9d0"), 0.24, Color("26e0f2"), 1.45)
	_materials.island_violet_energy = _material(Color("7e5bc2"), 0.32, Color("a675f3"), 1.10)
	_materials.island_gold = _material(Color("c69d3e"), 0.38, Color("e5b84c"), 0.70)
	_materials.bio_socket_gold = _material(Color("8f6727"), 0.44, Color("c99132"), 0.18)
	var socket_gold := _materials.bio_socket_gold as StandardMaterial3D
	socket_gold.metallic = 0.62
	socket_gold.metallic_specular = 0.58
	_materials.island_root = _material(Color("254d39"), 0.72, Color("3bd78a"), 0.72)
	_materials.island_bark_root = _material(Color("241b19"), 0.92)
	_materials.bio_bark = _material(Color("3b2724"), 0.88)
	_materials.bio_bark_highlight = _material(Color("825542"), 0.78,
		Color("5a3428"), 0.12)
	_materials.bio_gunmetal = _material(Color("152238"), 0.58)
	_materials.bio_nutrient_glow = _material(Color("2abf68"), 0.18,
		Color("55ff91"), 2.10)
	_materials.bio_data_glow = _material(Color("0a9fd4"), 0.14,
		Color("31e8ff"), 2.45)
	_materials.bio_crown_crystal = _material(Color("1479ad"), 0.34,
		Color("2ac9f4"), 0.34)
	var crown_crystal_material := _materials.bio_crown_crystal as StandardMaterial3D
	crown_crystal_material.vertex_color_use_as_albedo = true
	crown_crystal_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	crown_crystal_material.metallic = 0.08
	crown_crystal_material.metallic_specular = 0.38
	crown_crystal_material.rim_enabled = true
	crown_crystal_material.rim = 0.32
	crown_crystal_material.rim_tint = 0.30
	_materials.bio_crown_outline = _material(Color("8feaff"), 0.10,
		Color("73e7ff"), 0.62)
	var crown_outline_material := _materials.bio_crown_outline as StandardMaterial3D
	crown_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crown_outline_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	crown_outline_material.no_depth_test = false
	_materials.bio_mushroom = _material(Color("56328f"), 0.32, Color("7146ad"), 0.20)
	_materials.bio_mushroom_highlight = _material(Color("a57bd7"), 0.22, Color("c09bea"), 0.34)
	_materials.bio_mushroom_dark = _material(Color("291b49"), 0.40,
		Color("513075"), 0.16)
	_materials.bio_mushroom_mid = _material(Color("754daf"), 0.28,
		Color("9467c9"), 0.28)
	_materials.bio_mushroom_light = _material(Color("a075cf"), 0.24,
		Color("bd96e2"), 0.40)
	_materials.bio_mushroom_spot = _material(Color("d39acb"), 0.24,
		Color("f2b4db"), 0.78)
	for mushroom_surface in [_materials.bio_mushroom, _materials.bio_mushroom_mid,
		_materials.bio_mushroom_light, _materials.bio_mushroom_highlight,
		_materials.bio_mushroom_dark]:
		var mushroom_material := mushroom_surface as StandardMaterial3D
		mushroom_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mushroom_material.metallic = 0.14
		mushroom_material.metallic_specular = 0.72
		mushroom_material.rim_enabled = true
		mushroom_material.rim = 0.34
		mushroom_material.rim_tint = 0.48
	_materials.bio_leaf_panel = _material(Color("183954"), 0.36, Color("1b6f91"), 0.16)
	_materials.bio_leaf_panel_alt = _material(Color("245678"), 0.31,
		Color("2384a5"), 0.22)
	(_materials.bio_leaf_panel as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	(_materials.bio_leaf_panel_alt as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED


func _material(color: Color, roughness: float, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.22 if roughness < 0.7 else 0.0
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material


func _textured_material(base: Color, panel: Color, circuit: Color,
		roughness: float, cell_size: int) -> StandardMaterial3D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var joint := x % cell_size <= 1 or y % cell_size <= 1
			var trace := (x % (cell_size * 2) == cell_size / 2 and y % cell_size > 3) \
				or (y % (cell_size * 2) == cell_size / 2 and x % cell_size > 3)
			image.set_pixel(x, y, circuit if trace else (panel if joint else base))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.roughness = roughness
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.uv1_scale = Vector3(2.5, 2.5, 2.5)
	return material


func _low_poly_surface_material(base: Color, highlight: Color, edge: Color,
		roughness: float, metallic: float, seed: int, cell_size: int,
		emission := Color.BLACK, emission_energy := 0.0) -> StandardMaterial3D:
	# Each triangular cell receives a slightly different value, while narrow
	# diagonal seams and a derived normal map make the finish read at player
	# distance. This is intentionally subtle: geometry carries the silhouette;
	# texture supplies stone grain, brushed metal and edge variation.
	const TEXTURE_SIZE := 128
	var albedo_image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var roughness_image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var normal_image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var heights := PackedFloat32Array()
	heights.resize(TEXTURE_SIZE * TEXTURE_SIZE)
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var cell_x := int(x / cell_size)
			var cell_y := int(y / cell_size)
			var local_x := x % cell_size
			var local_y := y % cell_size
			var uses_rising_diagonal := (cell_x + cell_y + seed) % 2 == 0
			var diagonal_distance: int = absi(local_x - local_y) if uses_rising_diagonal \
				else absi((local_x + local_y) - (cell_size - 1))
			var seam: bool = diagonal_distance <= 1 or local_x <= 1 or local_y <= 1
			var facet_hash: int = posmod(cell_x * 37 + cell_y * 61 + seed * 19, 101)
			var facet_value := 0.20 + float(facet_hash) / 101.0 * 0.58
			var grain_hash: int = posmod(x * 17 + y * 43 + seed * 29, 97)
			var grain := (float(grain_hash) / 96.0 - 0.5) * 0.075
			var colour := base.lerp(highlight, clampf(0.42 + facet_value * 0.24 + grain * 0.20, 0.0, 1.0))
			if seam:
				colour = colour.lerp(edge, 0.08)
			albedo_image.set_pixel(x, y, colour)
			var height := 0.48 if seam else 0.52 + facet_value * 0.05 + grain * 0.12
			heights[y * TEXTURE_SIZE + x] = height
			var local_roughness := clampf(roughness + grain * 0.85 + (0.10 if seam else 0.0), 0.08, 0.96)
			roughness_image.set_pixel(x, y, Color(local_roughness, local_roughness,
				local_roughness, 1.0))
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var left := heights[y * TEXTURE_SIZE + maxi(0, x - 1)]
			var right := heights[y * TEXTURE_SIZE + mini(TEXTURE_SIZE - 1, x + 1)]
			var down := heights[maxi(0, y - 1) * TEXTURE_SIZE + x]
			var up := heights[mini(TEXTURE_SIZE - 1, y + 1) * TEXTURE_SIZE + x]
			var normal := Vector3((left - right) * 1.8, (down - up) * 1.8, 1.0).normalized()
			normal_image.set_pixel(x, y, Color(normal.x * 0.5 + 0.5,
				normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5, 1.0))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.albedo_texture = ImageTexture.create_from_image(albedo_image)
	material.roughness = roughness
	material.roughness_texture = ImageTexture.create_from_image(roughness_image)
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.metallic = metallic
	if metallic > 0.5:
		material.metallic = minf(metallic, 0.55)
	material.metallic_specular = 0.82 if metallic > 0.5 else 0.46
	material.normal_enabled = true
	material.normal_texture = ImageTexture.create_from_image(normal_image)
	material.normal_scale = 0.16
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3(1.8, 1.8, 1.8)
	albedo_image.generate_mipmaps()
	roughness_image.generate_mipmaps()
	normal_image.generate_mipmaps()
	material.albedo_texture = ImageTexture.create_from_image(albedo_image)
	material.roughness_texture = ImageTexture.create_from_image(roughness_image)
	material.normal_texture = ImageTexture.create_from_image(normal_image)
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_texture = material.albedo_texture
		material.emission_energy_multiplier = emission_energy
	return material


func _image_material(texture_path: String, tint: Color, roughness: float, metallic: float,
		emission := Color.BLACK, emission_energy := 0.0, uv_scale := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.albedo_texture = load(texture_path) as Texture2D
	material.roughness = roughness
	material.metallic = metallic
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3.ONE * uv_scale
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_texture = load(texture_path) as Texture2D
		material.emission_energy_multiplier = emission_energy
	return material


func _add_box(parent: Node3D, node_name: String, at: Vector3, size: Vector3, material: Material,
		collision := false, yaw := 0.0, friction := 0.88, bounce := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.rotation.y = yaw
	instance.material_override = material
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		var physics_material := PhysicsMaterial.new()
		physics_material.friction = friction
		physics_material.bounce = bounce
		body.physics_material_override = physics_material
		body.set_meta("mass_class", "infinite_static_mass")
		body.set_meta("friction", friction)
		body.set_meta("bounce", bounce)
		body.position = at
		body.rotation.y = yaw
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		parent.add_child(body)
	return instance


func _add_beam_between(parent: Node3D, node_name: String, start: Vector3, finish: Vector3,
		width: float, material: Material) -> MeshInstance3D:
	var direction := finish - start
	var horizontal_length := Vector2(direction.x, direction.z).length()
	var beam := _add_box(parent, node_name, start.lerp(finish, 0.5),
		Vector3(width, width, direction.length()), material, false,
		atan2(direction.x, direction.z))
	beam.rotation.x = -atan2(direction.y, horizontal_length)
	beam.set_meta("editable_component", true)
	return beam


func _add_cable_between(parent: Node3D, node_name: String, start: Vector3, finish: Vector3,
		start_radius: float, end_radius: float, material: Material,
		radial_segments := 8) -> MeshInstance3D:
	var direction := finish - start
	var cable := MeshInstance3D.new()
	cable.name = node_name
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = start_radius
	mesh.top_radius = end_radius
	mesh.height = maxf(0.01, direction.length())
	mesh.radial_segments = radial_segments
	mesh.rings = 1
	cable.mesh = mesh
	cable.position = start.lerp(finish, 0.5)
	if not direction.is_zero_approx():
		cable.quaternion = Quaternion(Vector3.UP, direction.normalized())
	cable.material_override = material
	cable.set_meta("editable_component", true)
	cable.set_meta("micro_component", "slim modular nature-technology root cable")
	cable.set_meta("path_start", start)
	cable.set_meta("path_end", finish)
	parent.add_child(cable)
	return cable


func _add_triangle_patch(parent: Node3D, node_name: String, a: Vector3, b: Vector3,
		c: Vector3, material: Material) -> MeshInstance3D:
	# Pull each triangle away from its neighbours. The luminous core visible in
	# the resulting gaps becomes a real fracture seam rather than a painted line.
	var center := (a + b + c) / 3.0
	var inset := 0.90
	a = center + (a - center) * inset
	b = center + (b - center) * inset
	c = center + (c - center) * inset
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.generate_normals()
	var patch := MeshInstance3D.new()
	patch.name = node_name
	patch.mesh = surface.commit()
	patch.material_override = material
	patch.set_meta("editable_component", true)
	patch.set_meta("micro_component", "independent triangular crystal facet")
	parent.add_child(patch)
	return patch


func _build_tree_root_outlayer(parent: Node3D, origin: Vector3, root_count: int,
		root_length: float, root_width: float, variant: int) -> void:
	var root_layer := Node3D.new()
	root_layer.name = "EditableTreeRootOutlayer_%02d" % variant
	root_layer.set_script(IslandDetailAnimator)
	root_layer.set("variant_index", variant)
	root_layer.set_meta("reference_layer", "twisted bark roots with emerald technology veins")
	parent.add_child(root_layer)
	for root_index in root_count:
		var angle := TAU * float(root_index) / float(root_count) + variant * 0.11
		var previous := origin + Vector3(sin(angle) * root_width, 0, cos(angle) * root_width)
		for segment_index in 9:
			var progress := float(segment_index + 1) / 9.0
			var bend_angle := angle + sin(float(segment_index) * 1.4 + root_index) * 0.17
			var next := origin + Vector3(sin(bend_angle) * root_length * progress,
				maxf(-0.35, sin(progress * PI) * root_width * 0.42),
				cos(bend_angle) * root_length * progress)
			var width := lerpf(root_width, root_width * 0.26, progress)
			_add_cable_between(root_layer,
				"TreeRootBark_%02d_%02d" % [root_index + 1, segment_index + 1],
				previous, next, width, width * 0.82, _materials.island_bark_root)
			_add_cable_between(root_layer,
				"TreeRootEnergyVein_%02d_%02d" % [root_index + 1, segment_index + 1],
				previous + Vector3.UP * width * 0.62, next + Vector3.UP * width * 0.62,
				width * 0.18, width * 0.13, _materials.island_root)
			var side_offset := Vector3(cos(bend_angle), 0, -sin(bend_angle)) * width * 0.38
			_add_cable_between(root_layer,
				"TreeRootCyanFiber_%02d_%02d" % [root_index + 1, segment_index + 1],
				previous + Vector3.UP * width * 0.44 + side_offset,
				next + Vector3.UP * width * 0.44 + side_offset,
				width * 0.10, width * 0.075, _materials.island_cyan)
			var packet_material: Material = _materials.island_cyan if (root_index + segment_index) % 4 == 0 else _materials.island_root
			var packet_scale := Vector3.ONE * width * 0.28
			var packet_start := next + Vector3.UP * width * 0.62
			var packet_finish := previous + Vector3.UP * width * 0.62
			var packet := _add_sphere(root_layer,
				"TreeNutrientPacket_%02d_%02d" % [root_index + 1, segment_index + 1],
				packet_start, packet_scale, packet_material)
			packet.set_meta("detail_packet", true)
			packet.set_meta("packet_base_scale", packet_scale)
			packet.set_meta("path_start", packet_start)
			packet.set_meta("path_end", packet_finish)
			packet.set_meta("packet_phase", fposmod(float(root_index) * 0.097 + float(segment_index) * 0.17, 1.0))
			packet.set_meta("packet_speed", 0.42 + float((root_index + segment_index) % 3) * 0.06)
			if segment_index == 2:
				_add_sphere(root_layer, "TreeRootSocket_%02d" % (root_index + 1),
					next + Vector3.UP * width * 0.64, Vector3.ONE * width * 0.34,
					_materials.island_cyan if root_index % 3 == 0 else _materials.island_root)
			previous = next


func _add_cylinder(parent: Node3D, node_name: String, at: Vector3, radius: float, height: float,
		material: Material, collision: bool, segments: int,
		friction := 0.90, bounce := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = "%sCollision" % node_name
		var physics_material := PhysicsMaterial.new()
		physics_material.friction = friction
		physics_material.bounce = bounce
		body.physics_material_override = physics_material
		body.set_meta("mass_class", "infinite_static_mass")
		body.set_meta("friction", friction)
		body.set_meta("bounce", bounce)
		body.position = at
		var shape_node := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		shape_node.shape = shape
		body.add_child(shape_node)
		parent.add_child(body)
	return instance


func _add_sphere(parent: Node3D, node_name: String, at: Vector3, scale_value: Vector3,
		material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = SphereMesh.new()
	instance.position = at
	instance.scale = scale_value
	instance.material_override = material
	parent.add_child(instance)
	return instance


## Places a prebuilt ArrayMesh (from the Bricks library) the same way the
## primitive helpers place their meshes, so procedural geometry and the existing
## _add_box/_add_sphere props can be mixed freely inside one zone.
func _add_brick(parent: Node3D, node_name: String, at: Vector3, mesh: Mesh,
		material: Material, yaw := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = at
	instance.rotation.y = yaw
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_torus(parent: Node3D, node_name: String, at: Vector3, inner: float, outer: float,
		material: Material, rotation_degrees_value := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 36
	mesh.ring_segments = 8
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees = rotation_degrees_value
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_zone_light(parent: Node3D, at: Vector3, color: Color, range_value: float,
		energy: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "AuthoredZoneGlow"
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	parent.add_child(light)
	return light


func _add_zone_ambience(parent: Node3D, node_name: String, stream: AudioStream,
		volume_db_value: float, max_distance_value: float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.name = node_name
	audio.stream = stream
	audio.volume_db = volume_db_value
	audio.max_distance = max_distance_value
	audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	audio.autoplay = true
	parent.add_child(audio)
	return audio


func _add_nature_asset(parent: Node3D, node_name: String, resource_path: String,
		at: Vector3, scale_value: Vector3) -> Node3D:
	var packed := load(resource_path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return null
	instance.name = node_name
	instance.position = at
	instance.scale = scale_value
	instance.rotation.y = float(node_name.hash() % 628) / 100.0
	parent.add_child(instance)
	return instance


func _add_label(parent: Node3D, text: String, at: Vector3, color: Color, size: int) -> Label3D:
	var label := Label3D.new()
	label.name = "%sLabel" % text.get_slice("•", 0).strip_edges().to_pascal_case()
	label.text = text
	label.position = at
	label.font_size = size
	label.outline_size = 10
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	parent.add_child(label)
	return label


func _add_star(parent: Node3D, at: Vector3, radius: float) -> void:
	var star := Node3D.new()
	star.name = "StarOfWisdomReward"
	star.position = at
	parent.add_child(star)
	for index in 8:
		var ray := _add_box(star, "StarRay", Vector3.ZERO, Vector3(radius * 2, 1.5, 3), _materials.gold)
		ray.rotation.y = TAU * float(index) / 8.0
	_add_sphere(star, "StarCore", Vector3.ZERO, Vector3.ONE * 5, _materials.gold)


# --- Island One physical geometry --------------------------------------------


func _install_island_one_static_collisions(geometry: Node3D) -> void:
	# Imported art and the research-campus kit contain visible meshes which were
	# authored as decoration only. Consolidate their collision into one static
	# body before visual batching retires the individual MeshInstance3D nodes.
	# StaticBody3D represents infinite mass, so the player cannot push or pass
	# through these structures.
	var collision_body := StaticBody3D.new()
	collision_body.name = "IslandOneVisibleObjectCollisions"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 1
	collision_body.set_meta("mass_class", "infinite_static_mass")
	collision_body.set_meta("collision_role", "island_one_visible_objects")
	geometry.add_child(collision_body)
	var station_spur := geometry.get_node_or_null("OptionalCompletedWorldStationSpur")
	if station_spur != null:
		geometry.move_child(collision_body, station_spur.get_index())

	var roots: Array[Node] = []
	for path in [
		"01WorldGateLanding",
		"02LivingNetworkForest",
		"ThreeFusedSuperIslands/FusedSuperIsland_01_02",
		"IslandOnePerimeterRepairs",
	]:
		var root_node := geometry.get_node_or_null(path)
		if root_node != null:
			roots.append(root_node)
	var campus_root := get_node_or_null("IslandOneResearchCampus")
	if campus_root != null:
		roots.append(campus_root)

	var seen := {}
	var collision_count := 0
	for collision_root in roots:
		for candidate in collision_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if mesh_instance == null or seen.has(mesh_instance.get_instance_id()):
				continue
			seen[mesh_instance.get_instance_id()] = true
			if not _is_solid_island_one_mesh(mesh_instance, collision_root):
				continue
			var collision_shape := mesh_instance.mesh.create_trimesh_shape()
			if collision_shape == null:
				continue
			var shape_node := CollisionShape3D.new()
			shape_node.name = "VisibleObjectShape_%04d" % collision_count
			shape_node.shape = collision_shape
			shape_node.transform = collision_body.global_transform.affine_inverse() \
				* mesh_instance.global_transform
			shape_node.set_meta("source_mesh", str(mesh_instance.get_path()))
			collision_body.add_child(shape_node)
			collision_count += 1

	collision_body.set_meta("collision_shape_count", collision_count)
	set_meta("island_one_visible_object_collision_count", collision_count)


func _is_solid_island_one_mesh(mesh_instance: MeshInstance3D, collision_root: Node) -> bool:
	if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
		return false
	if mesh_instance.has_meta("detail_packet") or mesh_instance.has_meta("detail_orbit_speed"):
		return false
	# A physics-owned ancestor already resolves player contact. Area3D ancestors
	# are interaction sensors rather than solid bodies, so their visible cabinets
	# and instruments still need the Island One static collision layer.
	var ancestor := mesh_instance.get_parent()
	while ancestor != null and ancestor != collision_root.get_parent():
		if ancestor is PhysicsBody3D:
			return false
		ancestor = ancestor.get_parent()
	# Primitive builders put an optimized body beside the visible mesh.
	if mesh_instance.get_node_or_null("%sCollision" % mesh_instance.name) != null:
		return false
	var parent := mesh_instance.get_parent()
	if parent != null and parent.get_node_or_null("%sCollision" % mesh_instance.name) != null:
		return false
	for child in mesh_instance.get_children():
		if child is CollisionObject3D:
			return false
	# Ignore sub-centimetre light filaments and shader accents. They have no
	# meaningful player-facing volume and would create snag points on walkways.
	var bounds := mesh_instance.mesh.get_aabb().size * mesh_instance.scale.abs()
	if maxf(bounds.x, maxf(bounds.y, bounds.z)) < 0.12:
		return false
	return mesh_instance.mesh.get_surface_count() > 0


# --- Static geometry batching -------------------------------------------------
#
# This world is authored as ~27,000 individual MeshInstance3D nodes, which is
# 82% of every mesh in the art gallery scene. Measured, the gallery allocates
# 1,161 MB and 104,096 objects against the hub's 348 MB and 26,058 - and the web
# export is a wasm32 build with a hard 4 GB address space that also holds the
# pack in memory, so the browser runs out and the world never appears. It builds
# fine on desktop, which is why this looked like a rendering bug rather than a
# budget one.
#
# Every generator here creates a fresh mesh resource per call, so identical
# shapes are never shared. Rather than rewrite thousands of lines of authored
# generators, this pass runs afterwards: it groups finished MeshInstance3D nodes
# by what they actually draw and collapses each group into one
# MultiMeshInstance3D. The result is visually identical - same meshes, same
# materials, same transforms - at a fraction of the node and object count.
#
# Nodes are left alone when collapsing them would change behaviour: anything
# with children, a script, collision, or group membership stays a real node so
# gameplay code that looks them up still finds them.

const BATCH_MIN_GROUP := 8


func _batch_static_geometry(root: Node3D) -> void:
	if root == null:
		return
	var groups := {}
	_collect_batchable(root, groups)
	var collapsed := 0
	var removed := 0
	for key in groups:
		var members: Array = groups[key]
		if members.size() < BATCH_MIN_GROUP:
			continue
		var first: MeshInstance3D = members[0]
		# Batch against the geometry root rather than each node's own parent.
		# Grouping per-parent left 18,363 batchable nodes untouched simply
		# because identical pieces were scattered across many parents.
		var parent := root
		if parent == null:
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = first.mesh
		multi.instance_count = members.size()
		for index in members.size():
			var member: MeshInstance3D = members[index]
			# Transforms are taken relative to the shared parent so the batch can
			# sit in the same place in the tree without moving anything.
			multi.set_instance_transform(index,
				parent.global_transform.affine_inverse() * member.global_transform)
		var batch := MultiMeshInstance3D.new()
		batch.name = "BatchedGeometry_%d" % collapsed
		batch.multimesh = multi
		batch.material_override = first.material_override
		parent.add_child(batch)
		for member in members:
			member.queue_free()
			removed += 1
		collapsed += 1
	if collapsed > 0:
		set_meta("batched_geometry_groups", collapsed)
		set_meta("batched_geometry_nodes_removed", removed)


func _collect_batchable(node: Node, groups: Dictionary) -> void:
	# A root-level MultiMesh cannot inherit a retired assembly's visibility.
	# Leave hidden source nodes untouched instead of resurrecting their geometry.
	if node is Node3D and not (node as Node3D).is_visible_in_tree():
		return
	# Actor descendants are owned by scripts that toggle/animate individual meshes.
	# Moving them into the world batch frees those references and breaks combat.
	if node is MindSparkEnemyBase or node.get_meta("preserve_authored_nodes", false):
		return
	for child in node.get_children():
		_collect_batchable(child, groups)
	if not (node is MeshInstance3D):
		return
	var instance := node as MeshInstance3D
	if instance.get_meta("editable_component", false) or instance.has_meta("detail_packet") or instance.has_meta("detail_orbit_speed"):
		return
	# Keep anything gameplay code may reach for, or whose behaviour depends on
	# being a real node in the tree.
	if instance.get_child_count() > 0:
		return
	if instance.get_script() != null:
		return
	if instance.get_groups().size() > 0:
		return
	if instance.mesh == null:
		return
	# Group by what is actually drawn: identical primitive parameters and the
	# same material can share one MultiMesh.
	var key := "%s|%s|%s" % [
		instance.mesh.get_class(),
		_mesh_signature(instance.mesh),
		_material_signature(instance.material_override),
	]
	if not groups.has(key):
		groups[key] = []
	groups[key].append(instance)


func _mesh_signature(mesh: Mesh) -> String:
	# Primitive meshes are equivalent when their defining dimensions match.
	if mesh is BoxMesh:
		return str((mesh as BoxMesh).size)
	if mesh is CylinderMesh:
		var cylinder := mesh as CylinderMesh
		return "%f,%f,%f,%d" % [cylinder.top_radius, cylinder.bottom_radius,
			cylinder.height, cylinder.radial_segments]
	if mesh is SphereMesh:
		var sphere := mesh as SphereMesh
		return "%f,%f,%d,%d" % [sphere.radius, sphere.height,
			sphere.radial_segments, sphere.rings]
	if mesh is TorusMesh:
		var torus := mesh as TorusMesh
		return "%f,%f" % [torus.inner_radius, torus.outer_radius]
	if mesh is PlaneMesh:
		return str((mesh as PlaneMesh).size)
	# Unknown mesh types are only ever batched with themselves.
	return str(mesh.get_instance_id())


func _material_signature(material: Material) -> String:
	# Materials are generated per call site, so comparing instance IDs would put
	# every visually identical surface in its own group and batch almost nothing.
	# Compare what actually determines appearance instead.
	if material == null:
		return "none"
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		return "std|%s|%f|%f|%d|%d|%s" % [
			str(standard.albedo_color), standard.roughness, standard.metallic,
			standard.shading_mode, standard.transparency,
			str(standard.emission if standard.emission_enabled else Color(0, 0, 0)),
		]
	return str(material.get_instance_id())
