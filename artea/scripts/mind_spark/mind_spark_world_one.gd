class_name MindSparkWorldOne
extends Node3D

## The physical World One layer inside the Art Castle Galaxy. This scene owns
## geography, collision, architecture, placement and direct object use. Story,
## quest order and combat progression are deliberately separate controllers.

signal quest_object_used(save_id: String, result: Dictionary)

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
# Procedural brick library: chamfered masonry, faceted crystals, bevelled
# boxes and drums. Used to give the props real cut geometry instead of raw
# BoxMesh/SphereMesh primitives.
const Bricks := preload("res://scripts/altar/AltarParts.gd")
const NetworkAmbience := preload("res://assets/audio/Atmospheric-instrumental-music.mp3")
const SanctuaryAmbience := preload("res://assets/audio/calm music.mp3")
const IslandDetailAnimator := preload("res://scripts/mind_spark/mind_spark_island_detail_animator.gd")
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
	"six_zone_floors",
	"main_story_route",
	"world_gate_checkpoints_boss_sanctuary",
	"optional_station_spur",
]
const ZONES := [
	{"id": "01_world_gate_landing", "title": "01 • WORLD GATE LANDING", "position": Vector3(-960, 2, 420), "radius": 125.0},
	{"id": "02_living_network_forest", "title": "02 • LIVING NETWORK FOREST", "position": Vector3(-800, 12, 100), "radius": 190.0},
	{"id": "03_constellation_court", "title": "03 • CONSTELLATION COURT", "position": Vector3(-300, 24, -220), "radius": 175.0},
	{"id": "04_hope_path_ridge", "title": "04 • HOPE PATH RIDGE", "position": Vector3(170, 40, 120), "radius": 120.0},
	{"id": "05_thought_storm_arena", "title": "05 • THOUGHT STORM ARENA", "position": Vector3(620, 58, 20), "radius": 210.0},
	{"id": "06_oldest_tree_sanctuary", "title": "06 • OLDEST TREE SANCTUARY", "position": Vector3(940, 84, -420), "radius": 180.0},
]
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


func _ready() -> void:
	build_world()
	_last_safe_position = to_global(get_zone_position("01_world_gate_landing") + Vector3(0, 7, 0))
	_find_player.call_deferred()
	if build_hud:
		_build_hud()


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
		_build_main_route(geometry)
		_build_island_transit_network(geometry)
		_build_zone_landmarks()
		_build_progression_gates(geometry)
	_build_organized_bio_tree_world(geometry)
	_place_functional_objects()
	_place_collectibles()
	_place_cast()
	_place_combat_population()
	if not _uses_existing_mind_district() and not _uses_galaxy_foundation():
		# The optional station is deliberately the final standalone construction
		# phase. It branches from Zone 05 and never participates in story routing.
		_build_station_spur(geometry)
	set_meta("world_identity", "living computer forest")
	set_meta("lead_force", "technology_science")
	set_meta("zone_count", 6)
	set_meta("story_route_required", true)
	set_meta("greybox_build_sequence", GREYBOX_BUILD_SEQUENCE)
	var foundation_mode := "standalone_preview"
	if _uses_existing_mind_district():
		foundation_mode = "walkable_mind_district"
	elif _uses_galaxy_foundation():
		foundation_mode = "authored_galaxy_land"
	set_meta("foundation_mode", foundation_mode)
	set_world_state("sleeping")


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
	_add_torus(zone, "LandingCircuitRing", Vector3(0, 1.2, 0), 34, 37, _materials.cyan)
	for side in [-1.0, 1.0]:
		for index in 4:
			var at := Vector3(float(side) * 28, 5, -36 + index * 24)
			_add_cylinder(zone, "LivingRootLamp", at, 1.2, 10, _materials.green_glow, false, 8)
			_add_sphere(zone, "RootLampCrown", at + Vector3.UP * 6, Vector3.ONE * 1.8, _materials.cyan)
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
	# One gate on the approach to each quest boundary, placed on the route
	# between consecutive zone centres so it cannot be walked around.
	for quest_index in mini(4, ZONES.size() - 1):
		var from: Vector3 = ZONES[quest_index].position
		var to: Vector3 = ZONES[quest_index + 1].position
		var at := from.lerp(to, 0.72)
		var direction := to - from
		var gate := AnimatableBody3D.new()
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
	var closed_position: Vector3 = gate.get_meta("closed_position")
	gate.position = closed_position + (Vector3.UP * 22.0 if open else Vector3.ZERO)
	gate.get_node("CollisionShape3D").disabled = open
	gate.set_meta("open", open)


func is_quest_gate_open(quest_index: int) -> bool:
	return quest_index >= 0 and quest_index < _quest_gates.size() and bool(_quest_gates[quest_index].get_meta("open", false))


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
	var object := _nearest_object()
	if object == null:
		return
	var handled := false
	if event.keycode == KEY_Q:
		_handle_object_result(object, object.interact())
		handled = true
	elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
		var actions := object.available_actions()
		var index := int(event.keycode - KEY_1)
		if index < actions.size():
			var action: StringName = actions[index]
			var value: Variant = null
			if action == &"answer_a": value = "outward"
			elif action == &"answer_b": value = "inward"
			_handle_object_result(object, object.interact(action, value))
			handled = true
	if handled and get_viewport() != null:
		get_viewport().set_input_as_handled()


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
	parent.set_meta("phase_01", "six_zone_floors")
	for index in ZONES.size():
		var info: Dictionary = ZONES[index]
		var zone := Node3D.new()
		zone.name = str(info.id).to_pascal_case()
		zone.position = info.position
		zone.set_meta("zone_id", info.id)
		zone.set_meta("route_order", index + 1)
		parent.add_child(zone)
		_zone_nodes[info.id] = zone
		_add_cylinder(zone, "WalkableZoneFloor", Vector3(0, ZONE_FLOOR_CENTER_Y, 0),
			float(info.radius), ZONE_FLOOR_HEIGHT,
			_materials.island_deck, true, 48)
		_build_modular_floating_foundation(zone, info, index)
		_add_label(zone, str(info.title), Vector3(0, 34, 0), Color("bff8ff"), 42)
		_build_recovery_volume(zone, float(info.radius))
	# Standalone preview collapses the two additional evidence courts into the
	# constellation platform. The live Galaxy integration binds them separately.
	_zone_nodes["03_fear_gate"] = _zone_nodes["03_constellation_court"]
	_zone_nodes["03_proof_gate"] = _zone_nodes["03_constellation_court"]


func _build_modular_floating_foundation(zone: Node3D, info: Dictionary, zone_index: int) -> void:
	var radius := float(info.radius)
	var styles := [
		{"sectors": 16, "depth": 42.0, "crystals": 6, "inner": 0.25, "pulse": 0.025, "accent": _materials.island_cyan},
		{"sectors": 18, "depth": 58.0, "crystals": 8, "inner": 0.30, "pulse": 0.055, "accent": _materials.island_root},
		{"sectors": 20, "depth": 52.0, "crystals": 7, "inner": 0.28, "pulse": 0.035, "accent": _materials.island_violet_energy},
		{"sectors": 15, "depth": 46.0, "crystals": 5, "inner": 0.22, "pulse": 0.085, "accent": _materials.island_gold},
		{"sectors": 24, "depth": 72.0, "crystals": 9, "inner": 0.32, "pulse": 0.045, "accent": _materials.island_violet_energy},
		{"sectors": 21, "depth": 62.0, "crystals": 7, "inner": 0.27, "pulse": 0.065, "accent": _materials.island_gold},
	]
	var style: Dictionary = styles[zone_index]
	var foundation := Node3D.new()
	foundation.name = "ModularFloatingFoundation"
	foundation.set_script(IslandDetailAnimator)
	foundation.set("variant_index", zone_index)
	foundation.set_meta("assembly_style", "Mind Spark reference-matched modular floating island")
	foundation.set_meta("editable_surface_count", int(style.sectors) + int(style.crystals) * 3 + 8)
	foundation.set_meta("variant_index", zone_index + 1)
	zone.add_child(foundation)

	# Each top plate is a separate mesh and material slot, so the game island can
	# be rearranged like a radial construction kit without touching collision.
	var sector_count := int(style.sectors)
	for sector_index in sector_count:
		var angle_step := TAU / float(sector_count)
		var center_angle := angle_step * float(sector_index) + float(zone_index) * 0.07
		var gap := angle_step * 0.075
		# Every radial module terminates on one shared circle. A per-sector wave
		# previously made neighbouring plates step inward or outward and appear
		# misaligned even after the overhang itself was clamped.
		var outer_radius := radius * 0.945
		var plate := _add_radial_plate(foundation, "DeckPlate_%02d" % (sector_index + 1),
			center_angle - angle_step * 0.5 + gap, center_angle + angle_step * 0.5 - gap,
			radius * float(style.inner), outer_radius, -0.02, 0.22, _materials.island_deck)
		plate.set_meta("editable_component", true)
		plate.set_meta("surface_role", "walkable painted alloy deck plate")
		plate.set_meta("outer_radius", outer_radius)
		plate.set_meta("rim_clearance", radius - outer_radius)
		# Rebuild the reference's nested alloy slabs as separate inset cells rather
		# than one painted wedge. Each cell can be selected and recoloured alone.
		for cell_index in 8:
			var cell_inner := lerpf(radius * float(style.inner), radius * 0.945,
				float(cell_index) / 8.0) + radius * 0.0025
			var cell_outer := lerpf(radius * float(style.inner), radius * 0.945,
				float(cell_index + 1) / 8.0) - radius * 0.0025
			var cell := _add_radial_plate(foundation,
				"DeckMicroCell_%02d_%02d" % [sector_index + 1, cell_index + 1],
				center_angle - angle_step * 0.5 + gap * 1.35,
				center_angle + angle_step * 0.5 - gap * 1.35,
				cell_inner, cell_outer, 0.225, 0.275,
				_materials.island_deck_panel_a if (sector_index + cell_index) % 3 else _materials.island_deck_panel_b)
			cell.set_meta("editable_component", true)
			cell.set_meta("micro_component", "nested radial alloy surface cell")
		# Perimeter armour blocks make the edge read as assembled machinery rather
		# than one smooth cylinder, matching the supplied component blueprint.
		var block_radius := radius * 0.93
		var block_size := Vector3(maxf(5.0, TAU * block_radius / sector_count * 0.78), 3.2,
			radius * 0.075)
		var block := _add_box(foundation, "RimArmour_%02d" % (sector_index + 1),
			Vector3(sin(center_angle) * block_radius, -1.35, cos(center_angle) * block_radius),
			block_size, _materials.island_rim, false, center_angle)
		block.set_meta("editable_component", true)
		block.set_meta("aligned_rim_radius", block_radius)

	_add_torus(foundation, "OuterGoldGuidanceRing", Vector3(0, 0.25, 0), radius * 0.76,
		radius * 0.775, _materials.island_gold)
	_add_torus(foundation, "InnerCyanEnergyRing", Vector3(0, 0.31, 0), radius * 0.315,
		radius * 0.34, _materials.island_cyan)
	_add_cylinder(foundation, "CentralDataPlate", Vector3(0, 0.08, 0), radius * 0.27, 0.16,
		_materials.island_deck, false, sector_count)
	_add_torus(foundation, "ZoneIdentityRing", Vector3(0, 0.38, 0), radius * 0.56,
		radius * 0.575, style.accent as Material)
	_build_surface_detail_network(foundation, radius, sector_count, zone_index, style.accent as Material)
	_build_surface_engraved_dials(foundation, radius, zone_index)

	var underside_depth := float(style.depth)
	var levitation_system := Node3D.new()
	levitation_system.name = "MagitechLevitationSystem"
	levitation_system.set_meta("visual_physics_model", "radial load transfer plus phase-locked crystal lift")
	levitation_system.set_meta("science_layer", "gold radial braces and cyan field stabilizers")
	levitation_system.set_meta("magic_layer", "faceted aether crystals and concentric resonance halos")
	levitation_system.set_meta("nature_layer", "green living-root energy distribution lattice")
	levitation_system.set_meta("editable_component", true)
	foundation.add_child(levitation_system)
	_add_tapered_cylinder(foundation, "CharcoalFloatingUnderbody", Vector3(0, -2.0 - underside_depth * 0.42, 0),
		radius * 0.91, radius * (0.34 + zone_index * 0.012), underside_depth * 0.84,
		_materials.island_underside, 48)
	_add_tapered_cylinder(foundation, "LowerLevitationCore", Vector3(0, -2.0 - underside_depth * 0.88, 0),
		radius * (0.34 + zone_index * 0.012), radius * 0.105, underside_depth * 0.28,
		_materials.island_rim, 24)
	_add_torus(foundation, "UnderbodyCyanBand", Vector3(0, -5.2, 0), radius * 0.84,
		radius * 0.865, _materials.island_cyan)

	# Three field bands make the fake physics legible: the wide upper ring carries
	# deck load, the middle ring balances roll, and the lower ring trims pitch.
	for band_index in 3:
		var band_progress := 0.20 + float(band_index) * 0.22
		var band_y := -2.0 - underside_depth * band_progress
		var band_radius := lerpf(radius * 0.91,
			radius * (0.34 + zone_index * 0.012), band_progress / 0.84)
		var field_band := _add_torus(levitation_system, "FieldStabilizerBand_%02d" % (band_index + 1),
			Vector3(0, band_y, 0), band_radius * 0.965, band_radius,
			_materials.island_cyan if band_index != 1 else _materials.island_gold)
		field_band.set_meta("detail_orbit_speed", (0.08 + band_index * 0.035) * (-1.0 if band_index == 1 else 1.0))

	# External braces and living-root conduits sit on the tapered shell. Their
	# angles deliberately interleave so science and nature appear co-dependent.
	var brace_count := 8 + zone_index
	for brace_index in brace_count:
		var brace_angle := TAU * float(brace_index) / float(brace_count) + float(zone_index) * 0.11
		var brace_radius := radius * 0.57
		var brace := _add_box(levitation_system, "RadialLoadBrace_%02d" % (brace_index + 1),
			Vector3(sin(brace_angle) * brace_radius, -2.0 - underside_depth * 0.20,
				cos(brace_angle) * brace_radius),
			Vector3(radius * 0.026, 1.35, radius * 0.64),
			_materials.island_gold if brace_index % 3 == 0 else _materials.island_cyan,
			false, brace_angle)
		brace.rotation.x = -0.24
		brace.set_meta("force_role", "radial compression brace")
		if brace_index % 2 == 0:
			var root_angle := brace_angle + TAU / float(brace_count) * 0.32
			var root := _add_box(levitation_system, "LivingRootConduit_%02d" % (brace_index + 1),
				Vector3(sin(root_angle) * radius * 0.53, -2.3 - underside_depth * 0.24,
					cos(root_angle) * radius * 0.53),
				Vector3(radius * 0.018, 0.78, radius * 0.54), _materials.island_root,
				false, root_angle)
			root.rotation.x = -0.31
			_add_sphere(levitation_system, "RootFluxNode_%02d" % (brace_index + 1),
				Vector3(sin(root_angle) * radius * 0.73, -3.0 - underside_depth * 0.13,
					cos(root_angle) * radius * 0.73),
				Vector3.ONE * radius * 0.022, _materials.island_root)

	var crystal_count := int(style.crystals)
	for crystal_index in crystal_count:
		var crystal_angle := TAU * float(crystal_index) / float(crystal_count) + float(zone_index) * 0.19
		var crystal_radius := radius * (0.62 + 0.105 * float(crystal_index % 2))
		var crystal_length := underside_depth * (0.50 + 0.10 * float((crystal_index + zone_index) % 3))
		var crystal_center := Vector3(sin(crystal_angle) * crystal_radius,
			-5.0 - crystal_length * 0.42, cos(crystal_angle) * crystal_radius)
		_build_levitation_crystal(levitation_system, crystal_index, crystal_center,
			radius * (0.060 + 0.010 * float(crystal_index % 3)), crystal_length,
			style.accent as Material)

	var core_length := underside_depth * 0.82
	_build_levitation_crystal(levitation_system, 99,
		Vector3(0, -5.0 - core_length * 0.42, 0), radius * 0.13, core_length,
		_materials.island_gold, true)
	for core_ring_index in 3:
		var core_ring_y := -underside_depth * (0.28 + float(core_ring_index) * 0.14)
		var core_ring_radius := radius * (0.19 - float(core_ring_index) * 0.025)
		_add_torus(levitation_system, "CentralGyroscopeRing_%02d" % (core_ring_index + 1),
			Vector3(0, core_ring_y, 0), core_ring_radius * 0.78, core_ring_radius,
			_materials.island_gold if core_ring_index == 1 else _materials.island_cyan,
			Vector3(0, 0, -8.0 + float(core_ring_index) * 8.0))
	_add_zone_light(levitation_system, Vector3(0, -underside_depth * 0.38, 0),
		Color("43eaff"), radius * 1.25, 2.4)
	_build_underbody_data_orbits(levitation_system, radius, underside_depth, zone_index)
	_build_underbody_service_modules(levitation_system, radius, underside_depth, zone_index)
	_build_living_root_shell_lattice(levitation_system, radius, underside_depth, zone_index)


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
	_build_network_forest(_zone_nodes["02_living_network_forest"])
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
		"06_oldest_tree_sanctuary>01_world_gate_landing",
	]))
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
		var start := start_center + horizontal * (
			float(ZONES[index].radius) - CIRCUIT_ROUTE_LANDING_OVERLAP)
		var finish := finish_center - horizontal * (
			float(ZONES[index + 1].radius) - CIRCUIT_ROUTE_LANDING_OVERLAP)
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
		_add_circuit_walkway(route, "CircuitRoute_%02d_A" % (index + 1), start, bend, 28.0)
		_add_circuit_walkway(route, "CircuitRoute_%02d_B" % (index + 1), bend, finish, 28.0)
	_build_world_one_ring_closure(route)


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
	_build_arch(zone, Vector3(0, 0, -38), 54, 62, _materials.violet, "WORLD GATE • MIND SPARK")
	var entry_gate := WorldGateScene.instantiate() as MindSparkWorldGate
	entry_gate.name = "EntryWorldGate"
	entry_gate.position = Vector3(0, 1, -38)
	entry_gate.destination_world_local = return_destination_world_local
	entry_gate.prompt_text = "Q • RETURN TO ART CASTLE"
	zone.add_child(entry_gate)
	_add_circuit_walkway(zone, "ArrivalRootBridge", Vector3(0, 1, 92), Vector3(0, 1, -15), 20)
	for side in [-1.0, 1.0]:
		for index in 5:
			_add_cylinder(zone, "RootLamp", Vector3(side * 13, 5, 65 - index * 20), 1.3, 10,
				_materials.green_glow, false, 7)
	_add_label(zone, "Q • USE OBJECTS     1–5 • CHOOSE", Vector3(0, 17, 54), Color("fff1aa"), 31)


func _build_network_forest(zone: Node3D) -> void:
	zone.set_meta("legacy_random_server_trees_replaced", true)
	for index in 8:
		_add_box(zone, "FibreRoot", Vector3(-75 + index * 22, 0.7, sin(index * 1.7) * 40),
			Vector3(44, 1.3, 2.2), _materials.green_glow, false, float(index) * 0.31)


func _build_constellation_court(zone: Node3D) -> void:
	_add_cylinder(zone, "ConstellationDais", Vector3(0, 1.2, 0), 82, 2.4, _materials.stone, true, 40)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		_add_sphere(zone, "MemoryNode", Vector3(cos(angle) * 62, 8 + index % 3 * 5, sin(angle) * 62),
			Vector3.ONE * 4.0, _materials.violet)
	_build_arch(zone, Vector3(-92, 0, 20), 34, 44, _materials.violet, "FEAR GATE")
	_build_arch(zone, Vector3(92, 0, 20), 34, 44, _materials.cyan, "PROOF / LOGIC GATE")


func _build_hope_ridge(zone: Node3D) -> void:
	for index in 5:
		var at := Vector3(-82 + index * 41, 1 + index * 2, -28)
		_add_box(zone, "HopePathTile_%02d" % index, at, Vector3(34, 2, 54),
			_materials.gold if index % 2 == 0 else _materials.cyan, true)
		for flower in 3:
			_add_sphere(zone, "ThoughtFlower", at + Vector3(-10 + flower * 10, 4, 20),
				Vector3(2.5, 1.4, 2.5), _materials.green_glow)
	for index in 3:
		_add_torus(zone, "TruthRing_%02d" % index, Vector3(-48 + index * 48, 18, 48), 12, 15,
			_materials.gold if index == 2 else _materials.cyan)


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
		[10, "world_one.checkpoint.landing", "01_world_gate_landing", Vector3(-48, 2, 34)],
		[11, "world_one.path_projector", "01_world_gate_landing", Vector3(48, 2, 34)],
		[0, "world_one.spark_socket", "02_living_network_forest", Vector3(0, 2, 16)],
		[10, "world_one.checkpoint.network", "02_living_network_forest", Vector3(-52, 2, -38)],
		[1, "world_one.evidence_scanner", "03_fear_gate", Vector3(-38, 4, -12)],
		[3, "world_one.memory_board", "03_constellation_court", Vector3(0, 4, 10)],
		[4, "world_one.logic_gate", "03_proof_gate", Vector3(38, 4, -12)],
		[6, "world_one.focus_bell", "03_constellation_court", Vector3(0, 4, -62)],
		[2, "world_one.perspective_lens", "04_hope_path_ridge", Vector3(-45, 3, 0)],
		[5, "world_one.truth_bridge", "04_hope_path_ridge", Vector3(45, 3, 0)],
		[7, "world_one.warden_anchor.1", "05_thought_storm_arena", Vector3(-82, 3, 28)],
		[7, "world_one.warden_anchor.2", "05_thought_storm_arena", Vector3(0, 3, -88)],
		[7, "world_one.warden_anchor.3", "05_thought_storm_arena", Vector3(82, 3, 28)],
		[8, "world_one.calm_rain_basin", "05_thought_storm_arena", Vector3(0, 3, 58)],
		[9, "world_one.identity_reflection", "06_oldest_tree_sanctuary", Vector3(-52, 3, -28)],
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
		["root_stalker", "ridge", "04_hope_path_ridge", Vector3(-48, 4, 72)],
		["blight_sentinel", "ridge", "04_hope_path_ridge", Vector3(48, 4, 72)],
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
			["root_stalker", "ridge", "04_hope_path_ridge", Vector3(-22, 1, 24)],
			["blight_sentinel", "ridge", "04_hope_path_ridge", Vector3(22, 1, 24)],
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
	var object := _nearest_object()
	panel.visible = object != null
	if object == null:
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
			var tree_scale := _designed_grove_tree_scale(zone_id, local_index, compact)
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


func _build_arch(parent: Node3D, at: Vector3, width: float, height: float, material: Material, text: String) -> void:
	var arch := Node3D.new()
	arch.name = text.get_slice("•", 0).strip_edges().to_pascal_case()
	arch.position = at
	parent.add_child(arch)
	_add_box(arch, "Left", Vector3(-width * 0.5, height * 0.5, 0), Vector3(5, height, 7), material, true)
	_add_box(arch, "Right", Vector3(width * 0.5, height * 0.5, 0), Vector3(5, height, 7), material, true)
	_add_box(arch, "Top", Vector3(0, height, 0), Vector3(width + 5, 5, 7), material, true)
	_add_label(arch, text, Vector3(0, height + 12, 0), Color("e8fbff"), 30)


func _build_materials() -> void:
	_materials.floor_dark = _textured_material(Color("10172b"), Color("17243b"), Color("244d68"), 0.72, 16)
	_materials.floor_grid = _textured_material(Color("263852"), Color("334b67"), Color("2cd7e8"), 0.55, 12)
	_materials.stone = _material(Color("aeb6ca"), 0.86)
	_materials.cyan = _material(Color("2cd7e8"), 0.28, Color("27def2"), 1.7)
	_materials.violet = _material(Color("7755b8"), 0.55, Color("8d63e0"), 0.8)
	_materials.green_glow = _material(Color("4f9f73"), 0.76, Color("48c47a"), 0.72)
	_materials.gold = _material(Color("e5bd55"), 0.38, Color("f0bb35"), 1.35)
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
	label.no_depth_test = true
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
