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
const AetherPowerAmbience := preload("res://assets/audio/world_objects/aether_power_loop.ogg")
const TreeWindAmbience := preload("res://assets/audio/world_objects/tree_wind_loop.ogg")
const RainWaterAmbience := preload("res://assets/audio/waterfall_ambient_loop.ogg")
const IslandDetailAnimator := preload("res://scripts/mind_spark/mind_spark_island_detail_animator.gd")
const IslandOnePuzzleScript := preload("res://scripts/mind_spark/mind_spark_island_one_puzzle.gd")
const WebPerfProbeScript := preload("res://scripts/mind_spark/world_one_web_perf_probe.gd")
const WebQualityProbeScript := preload("res://scripts/mind_spark/world_one_web_quality_probe.gd")
const WebStoryProbeScript := preload("res://scripts/mind_spark/world_one_web_story_probe.gd")
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
## Keep the first sloped stair surface beyond the arena cylinder's vertical
## rim. A short level deck bridges this clearance so the player crosses above
## the rim instead of driving the capsule into its side wall.
const STATION_STAIR_BOTTOM_CLEARANCE := 4.0
const STATION_APPROACH_OVERLAP := 14.0
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
const PLAYER_ARRIVAL_CLEARANCE := 2.5
## The Island Three camera arrives almost tangent to the storm arena rim. Give
## that processional route a broad architectural threshold so circular parapet
## facets never clip into disconnected foreground fragments during the bridge
## handoff. The arrival portico narrows the playable axis again inside the court.
const ISLAND_THREE_ARRIVAL_EDGE_OPENING_HALF_WIDTH := 42.0
## The standalone World One opens on the broad south aisle of the Signal
## Laboratory. Keeping this separate from the checkpoint operator position
## prevents the character, Mayor Milo and the station cabinet from stacking in
## one cramped focal point while leaving the first objective clearly ahead.
const STANDALONE_PLAYER_ARRIVAL := Vector3(-10.0, 0.05, -28.0)
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
	{"id": "05_thought_storm_arena", "total": 4, "pattern": "four perimeter storm sentinels"},
	{"id": "06_oldest_tree_sanctuary", "total": 12, "pattern": "hero tree with eleven guardian trees"},
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
var _active_encounter_id := ""
var _warden: Node
var _collectibles: Array[MindSparkCollectible] = []
var _quest_gates: Array[AnimatableBody3D] = []
var _cast: Dictionary = {}
var _world_state := "sleeping"
var _gentle_rain_ambience: AudioStreamPlayer3D
var _gentle_rain_fade_tween: Tween
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
var _gate_interaction_buttons: Array[Node3D] = []
var _web_island_detail_roots: Dictionary = {}
var _web_visible_detail_islands := PackedInt32Array()
var _web_last_detail_focus := Vector3.INF
var _web_last_far_focus := Vector3.INF
var _web_far_camera: Camera3D
var _last_runtime_player_position := Vector3.INF
var _hud_update_elapsed := 0.1


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
		_standardize_world_one_gate_family(geometry)
		_build_gate_interaction_buttons(geometry)
		_unify_island_one_tree_and_quest_style()
		_install_three_island_environment_audio(geometry)
	_install_player_spawn_marker(geometry)
	if not _uses_existing_mind_district() and not _uses_galaxy_foundation():
		# The optional station is deliberately the final standalone construction
		# phase. It branches from Zone 05 and never participates in story routing.
		_build_station_spur(geometry)
	_refine_island_one_surroundings()
	_install_three_island_static_collisions(geometry)
	_batch_static_geometry(self)
	_batch_repeated_static_render_geometry(self)
	_merge_static_render_geometry(self)
	_configure_world_one_visibility_ranges(self)
	_configure_web_island_detail_streaming()
	_install_web_perf_probe()
	_install_web_quality_probe()
	_install_web_story_probe()
	set_meta("world_identity", "living computer forest")
	set_meta("lead_force", "technology_science")
	set_meta("zone_count", 6)
	set_meta("physical_island_count", 3)
	set_meta("districts_per_island", 2)
	set_meta("legacy_fusion_pairs", PackedStringArray(["01+02", "03+04", "05+06"]))
	set_meta("story_route_required", true)
	set_meta("greybox_build_sequence", GREYBOX_BUILD_SEQUENCE)
	# Courts and landmark builders may replace the surface beneath a station
	# after its initial authored placement. Resolve every live quest object
	# against the final physics world so none of the fifteen instruments retain a
	# legacy vertical offset and appear to float above its Island 1–3 support.
	_ground_all_quest_objects.call_deferred()
	var foundation_mode := "standalone_preview"
	if _uses_existing_mind_district():
		foundation_mode = "walkable_mind_district"
	elif _uses_galaxy_foundation():
		foundation_mode = "authored_galaxy_land"
	set_meta("foundation_mode", foundation_mode)
	set_world_state("sleeping")


func _install_web_perf_probe() -> void:
	# Production diagnostics are opt-in and have no normal-player cost. The
	# browser probe uses the same four review cameras as the native benchmark so
	# WebGL results can be compared directly without automating the canvas.
	var requested := OS.get_environment("ARTEA_WORLD_ONE_WEB_PERF") == "1"
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		requested = "world_one_perf=1" in query
	if not requested or has_node("WorldOneWebPerfProbe"):
		return
	var probe := Node.new()
	probe.name = "WorldOneWebPerfProbe"
	probe.set_script(WebPerfProbeScript)
	add_child(probe)
	probe.call("configure", self)
	set_meta("web_perf_probe_enabled", true)


func _install_web_quality_probe() -> void:
	# This production-safe diagnostic is dormant unless explicitly requested.
	# It verifies real mini-game input and temporary browser persistence without
	# retaining any changes to the player's quest or identity saves.
	var requested := OS.get_environment("ARTEA_WORLD_ONE_WEB_QUALITY") == "1"
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		requested = "world_one_quality=1" in query
	if not requested or has_node("WorldOneWebQualityProbe"):
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"window.__ARTEA_WORLD_ONE_QUALITY__ = {status: 'running'};", true)
	var probe := Node.new()
	probe.name = "WorldOneWebQualityProbe"
	probe.set_script(WebQualityProbeScript)
	add_child(probe)
	probe.call("configure", self)
	set_meta("web_quality_probe_enabled", true)


func _install_web_story_probe() -> void:
	# This diagnostic exercises the connected production story with every save
	# writer redirected to temporary files. It is intentionally separate from
	# the isolated mini-game input probe so each failure has one clear cause.
	var requested := OS.get_environment("ARTEA_WORLD_ONE_WEB_STORY") == "1"
	if OS.has_feature("web"):
		var query := str(JavaScriptBridge.eval("window.location.search", true))
		requested = "world_one_story=1" in query
	if not requested or has_node("WorldOneWebStoryProbe"):
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"window.__ARTEA_WORLD_ONE_STORY__ = {status: 'running'};", true)
	var probe := Node.new()
	probe.name = "WorldOneWebStoryProbe"
	probe.set_script(WebStoryProbeScript)
	add_child(probe)
	probe.call("configure", self)
	set_meta("web_story_probe_enabled", true)


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
			# The original labels were technically present but only a few pixels
			# high from the production third-person camera.  Render the nearby
			# instruction at a larger font atlas and a consistent physical size,
			# then fade it before neighbouring stations enter the same view.  This
			# keeps the campus readable without filling the horizon with text.
			label.font_size = 42
			label.pixel_size = 0.008
			label.outline_size = 14
			label.outline_modulate = Color("172c35")
			label.visibility_range_end = 28.0
			label.visibility_range_end_margin = 3.0
			label.set_meta("player_camera_readable", true)
			label.set_meta("readability_revision", "island_one_near_field_02")
	set_meta("island_one_environment_revision", "warm_scenery_readable_controls_02")


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
	_return_gate.prompt_text = "Q • RETURN TO MIND SPARK TRAIN STATION"
	_return_gate.gate_enabled = true
	_return_gate.set_meta("travel_role", "island_three_to_mind_spark_train_station")
	_return_gate.set_meta("destination_landmark", "Mind Spark Train Station")
	_return_gate.set_meta("always_available_return", true)
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
			gate.set_meta("physical_barrier_removed", true)
		else:
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
	# This assembly is hidden until the epilogue, so the world-level static pass
	# cannot see its repeated stair treads. Batch its inert render leaves while it
	# is still visible; authored nodes and the continuous collision ramp remain.
	_station_spur.set_meta("static_render_merge_min_group", 2)
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
	var stair_bottom := Vector3(
		stair_top.x,
		arena.y + 0.4,
		arena.z + arena_radius + STATION_STAIR_BOTTOM_CLEARANCE)
	# Meet the arena on a slightly raised level deck. Its inner end overlaps the
	# floor by 14 m, giving the capsule enough support to step above the curved
	# cylinder rim before it reaches the sloped flight.
	var approach_start := Vector3(
		stair_bottom.x,
		stair_bottom.y,
		arena.z + arena_radius - STATION_APPROACH_OVERLAP)
	var approach_length := stair_bottom.z - approach_start.z
	_add_box(_station_spur, "StationApproachDeck",
		approach_start.lerp(stair_bottom, 0.5) - island_centre + Vector3.DOWN * 0.6,
		Vector3(STATION_STAIR_WIDTH, 1.2, approach_length + 1.0),
		_materials.floor_grid, true)
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
	_station_spur.set_meta("approach_start", approach_start)
	_station_spur.set_meta("station_island_radius", STATION_ISLAND_RADIUS)
	_station_spur.set_meta("branches_from_zone", str(ZONES[4].id))

	_merge_static_render_geometry(_station_spur)
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


func get_player_arrival_local() -> Vector3:
	## Return a supported arrival point at the beginning of the first route.
	## The historical zone centre contains raised observatory architecture and
	## the checkpoint operator apron is intentionally compact. The standalone
	## world therefore starts on the broad aisle just south of both, where the
	## player, guide and first objective remain readable as separate silhouettes.
	ensure_world_built()
	var marker := get_node_or_null("WorldOneGeometry/PlayerSpawn") as Marker3D
	if marker != null:
		return marker.position
	return _authored_player_arrival_local()


func owns_horizontal_position(global_position: Vector3) -> bool:
	## Identify falls that belong to World One even after the player's vertical
	## coordinate has dropped below every island. The six district centres span
	## the three fused islands and their two bridges; the same 500 m envelope is
	## used by Web camera streaming, so recovery and presentation agree about
	## when the player is inside this world.
	var local_position := to_local(global_position)
	var flat_position := Vector2(local_position.x, local_position.z)
	for zone_info in ZONES:
		var zone_position := get_zone_position(str(zone_info.id))
		if flat_position.distance_to(Vector2(zone_position.x, zone_position.z)) <= 500.0:
			return true
	return false


func get_safe_respawn_global() -> Vector3:
	## Return the most recent supported World One district, falling back to the
	## authored Island One arrival before the first movement sample.
	return _last_safe_position


func _authored_player_arrival_local() -> Vector3:
	if not _uses_existing_mind_district():
		var arrival_zone := _zone_nodes["01_world_gate_landing"] as Node3D
		return to_local(arrival_zone.to_global(STANDALONE_PLAYER_ARRIVAL)) \
			+ Vector3.UP * PLAYER_ARRIVAL_CLEARANCE
	for object in _objects:
		if object.save_id != "world_one.checkpoint.landing":
			continue
		var parent := object.get_parent() as Node3D
		var approach: Vector3 = object.get_meta("operator_approach_local")
		return to_local(parent.to_global(approach)) + Vector3.UP * PLAYER_ARRIVAL_CLEARANCE
	return get_zone_position("01_world_gate_landing") + Vector3.UP * 7.0


func _install_player_spawn_marker(geometry: Node3D) -> void:
	## Keep the live character spawn as an inspectable part of World One instead
	## of leaving the only authored marker behind in the gallery. Runtime entry,
	## traversal tests and future checkpoints can now share the same location.
	var marker := Marker3D.new()
	marker.name = "PlayerSpawn"
	marker.position = _authored_player_arrival_local()
	marker.set_meta("world", "world_one")
	marker.set_meta("physical_island", 1)
	marker.set_meta("district", "01_world_gate_landing")
	marker.set_meta("supported_spawn", true)
	geometry.add_child(marker)


func get_quest_objects() -> Array[QuestObjectBase]:
	return _objects.duplicate()


func _ground_all_quest_objects() -> void:
	# StaticBody3D additions become queryable on the next physics step. Waiting
	# here also ensures the final Island Three decks and both research campuses
	# have finished replacing their prototype floors.
	await get_tree().physics_frame
	var grounded_count := 0
	for object in _objects:
		if not is_instance_valid(object) or not object.is_inside_tree():
			continue
		var excluded_rids: Array[RID] = []
		for collision_object in object.find_children("*", "CollisionObject3D", true, false):
			excluded_rids.append((collision_object as CollisionObject3D).get_rid())
		# Probe the clear operator apron instead of the model centre. Large quest
		# machines often overlap decorative stages, canopies or railings at their
		# centre; those secondary colliders previously lifted the entire object up
		# to 8 m above the walkable court. The operator point is authored on the
		# intended floor and therefore supplies the correct common ground datum.
		var support_probe := object.global_position
		if object.has_meta("operator_approach_local"):
			var parent := object.get_parent() as Node3D
			support_probe = parent.to_global(object.get_meta("operator_approach_local"))
		var query := PhysicsRayQueryParameters3D.create(
			support_probe + Vector3.UP * 20.0,
			support_probe + Vector3.DOWN * 60.0)
		query.collision_mask = 1
		query.exclude = excluded_rids
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			object.set_meta("ground_snap_status", "missing_support")
			continue
		var previous_local_y := object.position.y
		var grounded_global := object.global_position
		grounded_global.y = (hit.position as Vector3).y + 0.005
		object.global_position = grounded_global
		_install_quest_object_contact_plinth(object)
		var local_delta_y := object.position.y - previous_local_y
		if object.has_meta("operator_approach_local"):
			var approach: Vector3 = object.get_meta("operator_approach_local")
			approach.y += local_delta_y
			object.set_meta("operator_approach_local", approach)
		object.set_meta("ground_snap_status", "grounded")
		object.set_meta("ground_clearance_m", 0.005)
		object.set_meta("ground_support", str((hit.collider as Node).get_path()))
		object.set_meta("ground_support_probe", "operator_apron")
		object.set_meta("grounded_after_final_architecture", true)
		grounded_count += 1
	set_meta("grounded_quest_object_count", grounded_count)
	set_meta("quest_object_grounding_revision", "visible_contact_plinth_v2")


func _install_quest_object_contact_plinth(object: QuestObjectBase) -> void:
	# Imported quest models start exactly at their scene origin. A ray-aligned
	# origin is physically correct but, against pale terraces and low camera
	# angles, the first visible pixel can still read as a floating cabinet. Give
	# every instrument a shallow faceted shoe that overlaps the supporting floor
	# by 7.5 cm. It makes contact explicit without changing the interaction or
	# adding another collision lip across the walking route.
	if object.has_node("GroundContactPlinth"):
		return
	var plinth := Node3D.new()
	plinth.name = "GroundContactPlinth"
	plinth.scale = Vector3(
		1.0 / maxf(absf(object.scale.x), 0.001),
		1.0 / maxf(absf(object.scale.y), 0.001),
		1.0 / maxf(absf(object.scale.z), 0.001))
	plinth.set_meta("ground_contact_overlap_m", 0.075)
	plinth.set_meta("purpose", "visible structural contact between quest instrument and final island surface")
	object.add_child(plinth)
	_add_cylinder(plinth, "IvoryContactShoe", Vector3(0, 0.045, 0),
		3.45, 0.24, _materials.sanctum_ivory, false, 10)
	_add_cylinder(plinth, "CharcoalContactShadow", Vector3(0, -0.055, 0),
		3.20, 0.14, _materials.shared_style_charcoal, false, 10)
	object.set_meta("visible_ground_contact", true)


func get_quest_review_camera_pose(object: QuestObjectBase) -> Dictionary:
	## Return the production third-person review pose for a quest instrument.
	## Quest models are intentionally scaled up for readability, so camera offsets
	## must be based on the unscaled operator point stored in the district parent.
	if object == null or not object.has_meta("operator_approach_local"):
		return {}
	var parent := object.get_parent() as Node3D
	if parent == null:
		return {}
	var approach: Vector3 = object.get_meta("operator_approach_local")
	var operator := parent.to_global(approach)
	var outward := operator - object.global_position
	outward.y = 0.0
	if outward.length_squared() < .001:
		outward = object.global_basis.z
		outward.y = 0.0
	outward = outward.normalized()
	var island_three := int(object.get_meta("physical_island", 0)) == 3
	var camera_back := 16.0 if island_three else 8.0
	var camera_height := 8.5 if island_three else 6.5
	return {
		"operator": operator,
		"eye": operator + outward * camera_back + Vector3.UP * camera_height,
		"target": object.global_position + Vector3.UP * 5.0,
	}


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
	_refresh_environment_audio(next_state)
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
	gate.set_meta("gate_interaction_unlocked", open)
	_apply_quest_gate_motion(gate, open)


func _apply_quest_gate_motion(gate: AnimatableBody3D, open: bool) -> void:
	if bool(gate.get_meta("physical_barrier_removed", false)):
		gate.get_node("CollisionShape3D").set_deferred("disabled", true)
		gate.set_meta("open", open)
		return
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
	if str(gate.get_meta("custom_gate_motion", "")) == "heavenly_star_hinges":
		gate.get_node("CollisionShape3D").set_deferred("disabled", true)
		var leaves := gate.get_node_or_null("HeavenlyStarGateFamilyFacade/SharedHeavenlyGateLeaves")
		if leaves != null:
			var west := leaves.get_node_or_null("WestCelestialLeaf") as AnimatableBody3D
			var east := leaves.get_node_or_null("EastCelestialLeaf") as AnimatableBody3D
			if west != null:
				west.rotation.y = -deg_to_rad(96.0) if open else 0.0
			if east != null:
				east.rotation.y = deg_to_rad(96.0) if open else 0.0
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
	var synthesis_table := get_node_or_null(
		"IslandTwoMemoryCampus/EvidenceObservatory/EvidenceSynthesisTable") as Node3D
	if synthesis_table != null:
		var verified_signals := 0
		if state_order >= valid_states.find("received"):
			verified_signals = 1
		if state_order >= valid_states.find("evidence_sorted"):
			verified_signals = 3
		for index in 3:
			var evidence_signal := synthesis_table.get_node_or_null(
				"EvidenceSignal_%02d" % (index + 1)) as MeshInstance3D
			if evidence_signal != null:
				evidence_signal.visible = index < verified_signals
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
	var reward := get_node_or_null(
		"IslandTwoMemoryCampus/HopeMaterialisationConduit/GuardianRewardSocket/RewardHopeCrystal") as Node3D
	if reward != null:
		reward.visible = state == "guardian_freed"


func activate_enemy_wave(encounter_id: String) -> int:
	_active_encounter_id = encounter_id
	for enemy in _enemies:
		enemy.set_active(false)
	var wave: Array = _enemy_waves.get(encounter_id, [])
	for index in mini(4, wave.size()):
		(wave[index] as MindSparkEnemyBase).set_active(true)
	return mini(4, wave.size())


func restart_active_encounter() -> int:
	## A defeat restarts only the current bounded wave. One-time reward receipts
	## remain in WorldOneProgression, so a retry cannot duplicate its economy.
	if _active_encounter_id.is_empty():
		return 0
	var wave: Array = _enemy_waves.get(_active_encounter_id, [])
	for enemy_value in wave:
		var enemy := enemy_value as MindSparkEnemyBase
		enemy.reset_enemy()
		enemy.set_active(true)
	return wave.size()


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


func _process(delta: float) -> void:
	_update_web_island_detail_streaming()
	_update_web_camera_far_plane()
	if _player == null:
		return
	if _last_runtime_player_position == Vector3.INF \
			or _last_runtime_player_position.distance_squared_to(_player.global_position) >= 1.0:
		_last_runtime_player_position = _player.global_position
		var nearest_zone := _nearest_zone()
		if not nearest_zone.is_empty():
			_last_safe_position = to_global(nearest_zone.position + Vector3(0, 7, 0))
	_hud_update_elapsed += delta
	if _hud_update_elapsed >= 0.1:
		_hud_update_elapsed = fmod(_hud_update_elapsed, 0.1)
		_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _player == null or not event is InputEventKey or not event.pressed or event.echo:
		return
	var quest_controller := get_node_or_null("QuestController")
	if quest_controller != null and quest_controller.has_method("has_open_identity_reflection") \
			and bool(quest_controller.call("has_open_identity_reflection")):
		return
	if event.keycode == KEY_Q:
		var gate_button := _nearest_gate_interaction_button()
		if gate_button != null:
			_operate_gate_interaction_button(gate_button)
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
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
	if bool(object.current_state.get("completed", false)):
		var progression := get_node_or_null("/root/WorldOneProgression")
		if progression != null and progression.has_method("grant_quest_reward"):
			progression.call("grant_quest_reward", object.save_id)
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


func _nearest_gate_interaction_button() -> Node3D:
	if _player == null:
		return null
	var nearest: Node3D
	var nearest_distance := 8.5
	for button in _gate_interaction_buttons:
		if not is_instance_valid(button) or not button.is_inside_tree():
			continue
		var distance := _player.global_position.distance_to(button.global_position)
		if distance < nearest_distance:
			nearest = button
			nearest_distance = distance
	return nearest


func _operate_gate_interaction_button(button: Node3D) -> bool:
	var gate_kind := str(button.get_meta("gate_kind", "quest"))
	if gate_kind == "island_one":
		var island_gate := get_island_one_heavenly_star_gate()
		if island_gate == null or not bool(island_gate.get_meta("gate_interaction_unlocked", false)):
			button.set_meta("last_interaction_result", "locked")
			return false
		_set_island_one_star_gate_open(not is_island_one_star_gate_open(), true)
		button.set_meta("last_interaction_result", "opened" if is_island_one_star_gate_open() else "closed")
		return true
	var gate_index := int(button.get_meta("quest_gate_index", -1))
	if gate_index < 0 or gate_index >= _quest_gates.size():
		return false
	var gate := _quest_gates[gate_index]
	if not bool(gate.get_meta("gate_interaction_unlocked", false)):
		button.set_meta("last_interaction_result", "locked")
		return false
	_apply_quest_gate_motion(gate, not bool(gate.get_meta("open", false)))
	button.set_meta("last_interaction_result", "opened" if bool(gate.get_meta("open", false)) else "closed")
	return true


func operate_gate_button_for_test(button: Node3D) -> bool:
	return _operate_gate_interaction_button(button)


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
		# A district is always viewed as one court on Web. Consolidate its inert
		# masonry at district scale; island streaming and the 900 m camera horizon
		# still retire courts outside the active route.
		zone.set_meta("static_render_merge_cell_size", 384.0)
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
	# Fusion hulls repeat paired ribs, arches and engine braces in groups of two
	# and three. Those pieces are static and can share a draw without changing
	# their independently authored collision or inspection paths.
	fusions.set_meta("static_render_merge_min_group", 2)
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
		# This imported batch combined every low shrub across a roughly 149 m
		# square. Several masses sat directly between the production player
		# approach and the Echo Question instrument, filling the camera with sage
		# polygons. Individual shrubs cannot be relocated because they are one
		# mesh, so retire this ground-cover layer and keep the benchmark's hero
		# tree, pearl canopy trees, bark, soil and ivory stone. The controlled
		# campus saplings and listening pavilions still supply the lower landscape.
		var broad_ground_cover := garden.find_child("SageFoliage", true, false) as MeshInstance3D
		if broad_ground_cover != null:
			broad_ground_cover.visible = false
			broad_ground_cover.set_meta("retired_by", "quest_approach_sightline_cleanup")
			broad_ground_cover.set_meta("retired_reason",
				"single broad batch occluded multiple Island One instrument cameras")
		garden.set_meta("broad_ground_cover_retired", broad_ground_cover != null)
		# Join the compass district to the teaching tree with one broad sequence of
		# flush stone leaves. The original uninterrupted ivory slab made the two
		# landmarks read as unrelated rooms even though they share one fused island.
		# These are low, collision-free paving insets over the existing solid deck:
		# no rail, route line, ring, or invisible obstacle is introduced.
		var learning_walk := Node3D.new()
		learning_walk.name = "CompassToEchoTreeLearningPromenade"
		learning_walk.set_meta("design_revision", "broad_ivory_sage_processional_walk_v1")
		learning_walk.set_meta("clear_width_m", 12.0)
		learning_walk.set_meta("collision_free_paving", true)
		learning_walk.set_meta("connects_landmarks", PackedStringArray([
			"Aether Compass", "Echo Garden Teaching Tree"
		]))
		island_visual.add_child(learning_walk)
		var walk_start := Vector3(-65.0, 0.09, 32.5)
		var walk_finish := Vector3(66.0, 0.09, -27.5)
		var walk_direction := walk_start.direction_to(walk_finish)
		var walk_yaw := atan2(walk_direction.x, walk_direction.z)
		var walk_piece_count := 11
		var walk_piece_length := walk_start.distance_to(walk_finish) / float(walk_piece_count) - 0.7
		var promenade_surface := SurfaceTool.new()
		promenade_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var promenade_leaf_mesh := Bricks.build_bevel_box(
			Vector3(12.0, 0.14, walk_piece_length), 0.24)
		for piece_index in walk_piece_count:
			var progress := (float(piece_index) + 0.5) / float(walk_piece_count)
			var piece_transform := Transform3D(Basis(Vector3.UP, walk_yaw),
				walk_start.lerp(walk_finish, progress))
			promenade_surface.append_from(promenade_leaf_mesh, 0, piece_transform)
		var promenade_mesh := MeshInstance3D.new()
		promenade_mesh.name = "LearningPromenadeLeaves"
		promenade_mesh.mesh = promenade_surface.commit()
		promenade_mesh.material_override = _materials.island_three_sage
		promenade_mesh.set_meta("decorative_floor_inset", true)
		promenade_mesh.set_meta("authored_leaf_count", walk_piece_count)
		learning_walk.add_child(promenade_mesh)
		learning_walk.set_meta("paving_piece_count", walk_piece_count)
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
		# Give the open side of the teaching tree an actual place to gather. The
		# three seats sit beyond its 25 m compass ring and leave the western quest
		# instrument crescent and the central walking apron unobstructed.
		var listening_crescent := Node3D.new()
		listening_crescent.name = "EchoTreeListeningCrescent"
		listening_crescent.position = garden.position
		listening_crescent.set_meta("clear_tree_apron_m", 6.0)
		listening_crescent.set_meta("architectural_role",
			"three open listening pavilions frame the teaching tree without closing its apron")
		listening_crescent.set_meta("material_language", "ivory stone, pale sage and charcoal feet")
		island_visual.add_child(listening_crescent)
		for bench_index in 3:
			var angle := -0.52 + 0.52 * float(bench_index)
			var bench := Node3D.new()
			bench.name = "ListeningPavilion_%02d" % (bench_index + 1)
			bench.position = Vector3(cos(angle) * 31.5, 0, sin(angle) * 31.5)
			bench.rotation.y = -angle - PI / 2.0
			bench.set_meta("open_sightline", true)
			bench.set_meta("pavilion_index", bench_index + 1)
			listening_crescent.add_child(bench)
			_add_brick(bench, "IvorySeat", Vector3(0, 1.1, 0),
				Bricks.build_bevel_box(Vector3(9.6, 0.58, 1.9), 0.18),
				_materials.sanctum_ivory)
			_add_brick(bench, "SageBack", Vector3(0, 1.83, -0.68),
				Bricks.build_bevel_box(Vector3(9.1, 1.15, 0.48), 0.13),
				_materials.island_three_sage)
			for foot_index in 2:
				_add_brick(bench, "StoneFoot_%02d" % foot_index,
					Vector3(-3.6 if foot_index == 0 else 3.6, 0.51, 0),
					Bricks.build_bevel_box(Vector3(0.85, 0.92, 1.35), 0.12),
					_materials.bio_gunmetal)
			# Tall side piers and a shallow stepped crown make each place legible
			# from the normal player camera. They remain behind the seat, so the
			# tree-facing side and the entire circular apron stay open.
			for side_index in 2:
				var side := -1.0 if side_index == 0 else 1.0
				_add_brick(bench, "IvoryPavilionPier_%02d" % (side_index + 1),
					Vector3(side * 4.45, 2.55, -0.92),
					Bricks.build_bevel_box(Vector3(0.72, 4.7, 0.72), 0.16),
					_materials.sanctum_ivory)
				_add_brick(bench, "SageFinial_%02d" % (side_index + 1),
					Vector3(side * 4.45, 5.16, -0.92),
					Bricks.build_bevel_box(Vector3(1.12, 0.72, 1.12), 0.24),
					_materials.island_three_sage)
			_add_brick(bench, "IvoryPavilionLintel", Vector3(0, 4.68, -0.92),
				Bricks.build_bevel_box(Vector3(9.62, 0.55, 0.72), 0.17),
				_materials.sanctum_ivory)
			_add_brick(bench, "SageListeningCanopy", Vector3(0, 5.03, -0.38),
				Bricks.build_bevel_box(Vector3(9.85, 0.30, 3.25), 0.15),
				_materials.island_three_sage)
			_add_brick(bench, "IvoryCanopyCrown", Vector3(0, 5.27, -0.72),
				Bricks.build_bevel_box(Vector3(6.9, 0.22, 2.05), 0.11),
				_materials.sanctum_ivory)
			var bench_body := StaticBody3D.new()
			bench_body.name = "ListeningBenchCollision"
			bench_body.collision_layer = 1
			bench_body.collision_mask = 1
			var bench_shape := CollisionShape3D.new()
			bench_shape.name = "CollisionShape3D"
			var bench_box := BoxShape3D.new()
			bench_box.size = Vector3(9.6, 1.95, 1.9)
			bench_shape.shape = bench_box
			bench_shape.position.y = 1.0
			bench_body.add_child(bench_shape)
			for side_index in 2:
				var pier_shape := CollisionShape3D.new()
				pier_shape.name = "PavilionPierCollision_%02d" % (side_index + 1)
				var pier_box := BoxShape3D.new()
				pier_box.size = Vector3(0.72, 4.7, 0.72)
				pier_shape.shape = pier_box
				pier_shape.position = Vector3(-4.45 if side_index == 0 else 4.45, 2.55, -0.92)
				bench_body.add_child(pier_shape)
			bench.add_child(bench_body)

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
	if pair_index != 2:
		_add_box(fusion, "InternalPromenadeInlay", Vector3(center.x,
			shared_surface_y + 0.10, center.z), Vector3(10.0, 0.20, saddle_length - 12.0),
			_materials.astral_brass, false, yaw)
		_add_box(fusion, "AetherFlowChannel", Vector3(center.x,
			shared_surface_y + 0.23, center.z), Vector3(2.2, 0.16, saddle_length - 18.0),
			_materials.arrival_glass, false, yaw)

	# Island Three's saddle is wholly supported by its overlapping circular
	# decks. The old long rails bisected that walkable space like a barrier, and
	# their brass/cyan floor strips read as stray lines across the court.
	# Retain the rail kit only where it belongs to the first two island links.
	var side_axis := Vector3(cos(yaw), 0.0, -sin(yaw))
	for side in ([] if pair_index == 2 else [-1.0, 1.0]):
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
	var variant_path: String = [
		"res://assets3D/mind_spark/celestial_islands_v11/island_01.glb",
		"res://assets3D/mind_spark/celestial_verdant_v12/island_02.glb",
		"res://assets3D/mind_spark/celestial_astral_v16/island_03.glb",
		"res://assets3D/mind_spark/celestial_dawn_v17/island_04.glb",
		"res://assets3D/mind_spark/celestial_islands_v11/island_05.glb",
		"res://assets3D/mind_spark/celestial_islands_v11/island_06.glb",
	][zone_index]
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
	_build_story_route_checkpoints()


func _build_story_route_checkpoints() -> void:
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


func _build_main_route(parent: Node3D) -> void:
	var route := Node3D.new()
	route.name = "MainStoryCircuitRoute"
	route.set_meta("phase_02", "main_story_route")
	# Each crossing uses paired edge courses and supports. Merge these small
	# static families even when a 96 m render cell contains fewer than four.
	route.set_meta("static_render_merge_min_group", 2)
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
		_add_circuit_walkway(route, "CircuitRoute_%02d_A" % (index + 1), start, bend, 28.0,
			index != 4)
		_add_circuit_walkway(route, "CircuitRoute_%02d_B" % (index + 1), bend, finish, 28.0,
			index != 4)
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
	_build_heavenly_gate_perimeter_walls(court)
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


func _build_heavenly_gate_perimeter_walls(court: Node3D) -> void:
	# The gate used to stand as an isolated machine on the open promenade. These
	# solid, stepped wings make it a defended threshold while stopping well clear
	# of the moving leaves and the full 11.8 m player/camera opening.
	var walls := Node3D.new()
	walls.name = "CollisionBackedGatePerimeter"
	walls.set_meta("preserve_authored_nodes", true)
	walls.set_meta("clear_opening_width_m", 11.8)
	walls.set_meta("collision_backed", true)
	walls.set_meta("architectural_family", "heavenly_star_gate")
	walls.set_meta("purpose", "protective side walls around the Island One gate without narrowing its route")
	walls.set_meta("wall_coping_height_m", 13.72)
	walls.set_meta("gate_tower_connection", "continuous on west and east sides")
	walls.set_meta("wall_visual_family", "island_one_two_civic_railing")
	court.add_child(walls)
	for side in [-1.0, 1.0]:
		var suffix := "West" if side < 0.0 else "East"
		var yaw: float = 0.0
		var wing_x: float = float(side) * 13.7
		# Step the wings behind the leaf plane. The garden-side saddle crosses the
		# outer diagonal of this court and must remain continuously walkable.
		var wing_z: float = 7.0
		_add_box(walls, "%sWingFoundation" % suffix,
			Vector3(wing_x, 0.65, wing_z), Vector3(3.0, 1.30, 14.0),
			_materials.shared_style_charcoal, true, yaw)
		_add_box(walls, "%sIvoryDefenceWall" % suffix,
			Vector3(wing_x, 7.25, wing_z), Vector3(2.35, 12.0, 13.2),
			_materials.sanctum_ivory, true, yaw)
		_add_brick(walls, "%sWallCoping" % suffix,
			Vector3(wing_x, 13.52, wing_z),
			Bricks.build_bevel_box(Vector3(2.8, 0.55, 13.7), 0.16),
			_materials.sanctum_ivory, yaw)
		_add_box(walls, "%sAetherInset" % suffix,
			Vector3(wing_x - side * 1.22, 7.35, wing_z),
			Vector3(0.12, 7.2, 6.4), _materials.arrival_glass, false, yaw)
		for buttress_index in 2:
			var buttress_x: float = wing_x + float(side) * 1.25
			_add_box(walls, "%sWallButtress_%02d" % [suffix, buttress_index + 1],
				Vector3(buttress_x, 5.1, wing_z - 4.0 + float(buttress_index) * 8.0),
				Vector3(1.05, 9.0, 1.4),
				_materials.celestial_floor, true, yaw)
		_add_brick(walls, "%sBoundaryCrystal" % suffix,
			Vector3(side * 13.7, 15.25, 13.2), Bricks.build_crystal(0.9, 3.2, 0.28, 8),
			_materials.arrival_glass)
		# Form one uninterrupted wall from the gate tower to the outer edge of the
		# Island One court. The former short outer panel and covered side opening
		# still left most of the frontage visually open. This wider span makes the
		# main gate the single deliberate entrance and encloses the complete garden.
		const BOUNDARY_INNER_EDGE := 8.1
		const BOUNDARY_OUTER_EDGE := 66.0
		const GATE_OPENING_HALF_WIDTH := 5.9
		var connector_width: float = BOUNDARY_INNER_EDGE - GATE_OPENING_HALF_WIDTH
		var connector_x: float = float(side) * (
			GATE_OPENING_HALF_WIDTH + connector_width * 0.5)
		# Bridge the last seam between the perimeter and each gate tower. The
		# connector begins exactly at the authored 11.8 m opening, so the wall now
		# reads as one structure without stealing any player clearance.
		_add_box(walls, "%sGateTowerConnectorFoundation" % suffix,
			Vector3(connector_x, 0.72, 0.35), Vector3(connector_width, 1.44, 4.2),
			_materials.shared_style_charcoal, true)
		_add_box(walls, "%sGateTowerConnectorWall" % suffix,
			Vector3(connector_x, 7.37, 0.35), Vector3(connector_width, 11.86, 3.0),
			_materials.sanctum_ivory, true)
		_add_brick(walls, "%sGateTowerConnectorCoping" % suffix,
			Vector3(connector_x, 13.72, 0.35),
			Bricks.build_bevel_box(Vector3(connector_width + 0.45, 0.72, 3.65), 0.20),
			_materials.sanctum_ivory)
		var boundary_width: float = BOUNDARY_OUTER_EDGE - BOUNDARY_INNER_EDGE
		var boundary_x: float = float(side) * (
			BOUNDARY_INNER_EDGE + boundary_width * 0.5)
		_add_box(walls, "%sConnectedBoundaryOuterFoundation" % suffix,
			Vector3(boundary_x, 0.72, 0.35), Vector3(boundary_width, 1.44, 4.2),
			_materials.sanctum_ivory, true)
		var boundary_collision := _add_box(walls, "%sConnectedBoundaryOuterWall" % suffix,
			Vector3(boundary_x, 7.37, 0.35), Vector3(boundary_width, 11.86, 3.0),
			_materials.sanctum_ivory, true) as MeshInstance3D
		boundary_collision.visible = false
		# Open scrollwork bays reproduce the civic railing already used around the
		# rear garden: ivory lantern piers, dark rails, brass curls and a low curb.
		# The hidden wall behind them retains the required physical barrier.
		for bay_index in 7:
			var bay_distance := BOUNDARY_INNER_EDGE + 4.4 + float(bay_index) * 8.0
			var bay_x := float(side) * bay_distance
			_add_heavenly_civic_railing_pier(walls,
				"%sBoundaryPier_%02d" % [suffix, bay_index + 1],
				Vector3(bay_x, 0.0, 0.35))
			_add_heavenly_civic_railing_bay(walls,
				"%sBoundaryScrollwork_%02d" % [suffix, bay_index + 1],
				float(side) * (bay_distance + 3.5), 7.0, 0.35)
		_add_heavenly_civic_railing_pier(walls, "%sBoundaryEndPier" % suffix,
			Vector3(float(side) * BOUNDARY_OUTER_EDGE, 0.0, 0.35))
	walls.set_meta("connected_boundary_span_m", 132.0)
	walls.set_meta("covers_gate_flanks", true)
	walls.set_meta("continuous_ground_to_coping", true)
	walls.set_meta("full_frontage_enclosure", true)
	walls.set_meta("side_passages_removed", true)
	walls.set_meta("connected_to_both_gate_towers", true)
	walls.set_meta("height_matches_gate_tower_capitals", true)
	walls.set_meta("styled_to_match_gate_barrier", true)
	walls.set_meta("outer_end_returns_removed", true)


func _add_heavenly_civic_railing_bay(parent: Node3D, prefix: String,
		center_x: float, width: float, center_z: float) -> void:
	var half_width := width * 0.5
	_add_brick(parent, prefix + "IvoryCurb", Vector3(center_x, 1.05, center_z),
		Bricks.build_bevel_box(Vector3(width + 0.35, 2.10, 2.25), 0.16),
		_materials.sanctum_ivory)
	for rail_y in [3.0, 10.8]:
		_add_cable_between(parent, prefix + "DarkRail_%s" % str(rail_y),
			Vector3(center_x - half_width, rail_y, center_z),
			Vector3(center_x + half_width, rail_y, center_z),
			0.22, 0.22, _materials.bio_gunmetal, 8)
	_add_cable_between(parent, prefix + "WestScroll",
		Vector3(center_x - half_width + 0.35, 3.25, center_z),
		Vector3(center_x, 9.8, center_z), 0.16, 0.13,
		_materials.astral_brass, 8)
	_add_cable_between(parent, prefix + "EastScroll",
		Vector3(center_x + half_width - 0.35, 3.25, center_z),
		Vector3(center_x, 9.8, center_z), 0.16, 0.13,
		_materials.astral_brass, 8)
	_add_cable_between(parent, prefix + "CenterDrop",
		Vector3(center_x, 9.8, center_z), Vector3(center_x, 4.0, center_z),
		0.13, 0.11, _materials.bio_gunmetal, 8)
	_add_torus(parent, prefix + "BrassMedallion", Vector3(center_x, 6.4, center_z),
		0.48, 0.78, _materials.astral_brass, Vector3(90, 0, 0))
	_add_brick(parent, prefix + "WisdomDrop", Vector3(center_x, 6.4, center_z - 0.08),
		Bricks.build_crystal(0.26, 0.92, 0.10, 6), _materials.green_glow)


func _add_heavenly_civic_railing_pier(parent: Node3D, prefix: String,
		at: Vector3) -> void:
	_add_brick(parent, prefix + "Foot", at + Vector3.UP * 0.65,
		Bricks.build_bevel_box(Vector3(2.15, 1.30, 2.65), 0.18),
		_materials.sanctum_ivory)
	_add_brick(parent, prefix + "Shaft", at + Vector3.UP * 6.75,
		Bricks.build_bevel_box(Vector3(1.45, 11.0, 1.75), 0.14),
		_materials.sanctum_ivory)
	_add_brick(parent, prefix + "Capital", at + Vector3.UP * 12.35,
		Bricks.build_bevel_box(Vector3(2.35, 0.75, 2.75), 0.16),
		_materials.sanctum_ivory)
	_add_cylinder(parent, prefix + "LanternBase", at + Vector3.UP * 13.05,
		0.72, 0.42, _materials.bio_gunmetal, false, 10)
	_add_sphere(parent, prefix + "WarmLantern", at + Vector3.UP * 14.28,
		Vector3(0.72, 2.05, 0.72), _materials.sanctum_ivory)
	for cage_index in 4:
		var cage_angle := TAU * float(cage_index) / 4.0
		var cage_offset := Vector3(sin(cage_angle) * 0.72, 0,
			cos(cage_angle) * 0.72)
		_add_cable_between(parent, "%sLanternCage_%02d" % [prefix, cage_index + 1],
			at + cage_offset + Vector3.UP * 13.18,
			at + cage_offset + Vector3.UP * 15.38,
			0.09, 0.07, _materials.bio_gunmetal, 6)
	_add_cylinder(parent, prefix + "LanternCap", at + Vector3.UP * 15.52,
		0.76, 0.42, _materials.bio_gunmetal, false, 10)
	_add_cylinder(parent, prefix + "LanternFinial", at + Vector3.UP * 16.05,
		0.20, 0.65, _materials.astral_brass, false, 8)


func _build_island_two_styled_gate_walls(gate: AnimatableBody3D,
		facade: Node3D) -> void:
	var walls := Node3D.new()
	walls.name = "SharedStyledSideWalls"
	walls.set_meta("preserve_authored_nodes", true)
	walls.set_meta("architectural_family", "island_one_two_civic_railing")
	walls.set_meta("connected_to_gate_towers", true)
	walls.set_meta("wall_coping_height_m", 13.72)
	walls.set_meta("collision_backed", true)
	facade.add_child(walls)
	const WALL_INNER_EDGE := 13.25
	for side in [-1.0, 1.0]:
		var suffix := "West" if side < 0.0 else "East"
		var boundary := 40.0
		for zone_id in ["03_constellation_court", "04_hope_path_ridge"]:
			var center := gate.to_local(to_global(get_zone_position(zone_id)))
			var radius := get_zone_radius(zone_id)
			if absf(center.z) < radius:
				boundary = maxf(boundary,
					float(side) * center.x
					+ sqrt(radius * radius - center.z * center.z) + 1.0)
		var wall_width := maxf(24.0, boundary - WALL_INNER_EDGE)
		var wall_x := float(side) * (WALL_INNER_EDGE + wall_width * 0.5)
		_add_box(walls, "%sStyledWallFoundation" % suffix,
			Vector3(wall_x, 0.72, 0.0), Vector3(wall_width, 1.44, 4.2),
			_materials.sanctum_ivory, true)
		var wall_collision := _add_box(walls, "%sStyledWallMass" % suffix,
			Vector3(wall_x, 7.37, 0.0), Vector3(wall_width, 11.86, 3.0),
			_materials.sanctum_ivory, true) as MeshInstance3D
		wall_collision.visible = false
		var bay_count := maxi(3, floori(wall_width / 8.0))
		var bay_width := wall_width / float(bay_count)
		for bay_index in bay_count:
			var bay_x := float(side) * (
				WALL_INNER_EDGE + (float(bay_index) + 0.5) * bay_width)
			_add_heavenly_civic_railing_bay(walls,
				"%sGateTwoScrollwork_%02d" % [suffix, bay_index + 1],
				bay_x, bay_width - 0.70, 0.0)
			var pier_x := float(side) * (WALL_INNER_EDGE + float(bay_index) * bay_width)
			_add_heavenly_civic_railing_pier(walls,
				"%sGateTwoWallPier_%02d" % [suffix, bay_index + 1],
				Vector3(pier_x, 0.0, 0.0))
		_add_heavenly_civic_railing_pier(walls, "%sGateTwoEndPier" % suffix,
			Vector3(float(side) * (WALL_INNER_EDGE + wall_width), 0.0, 0.0))
	walls.set_meta("styled_wall_side_count", 2)
	walls.set_meta("solid_outer_end_returns_removed", true)


func _standardize_world_one_gate_family(geometry: Node3D) -> void:
	# Quest state and motion stay on the existing gate bodies. This pass gives the
	# Island Two thresholds the same complete ivory/gold/cyan family as Island
	# One. Island Three is intentionally an open sanctuary route with no gate.
	var standardized := 0
	for gate_number in [2, 3]:
		var gate := geometry.get_node_or_null(
			"SavedQuestProgressionGates/QuestGate_%d" % gate_number) as AnimatableBody3D
		if gate == null:
			continue
		_build_heavenly_star_gate_family_facade(gate, gate_number)
		standardized += 1
	set_meta("standardized_heavenly_star_gate_count", standardized)
	set_meta("world_one_gate_family_revision", "heavenly_star_gate_family_v2")
	set_meta("island_three_gate_removed", true)


func _build_heavenly_star_gate_family_facade(gate: AnimatableBody3D,
		gate_number: int) -> void:
	if gate.has_node("HeavenlyStarGateFamilyFacade"):
		return
	var facade := Node3D.new()
	facade.name = "HeavenlyStarGateFamilyFacade"
	facade.set_meta("preserve_authored_nodes", true)
	facade.set_meta("source_gate", "IslandOneHeavenlyStarGate")
	facade.set_meta("architectural_family", "heavenly_star_gate")
	facade.set_meta("preserves_gate_controller", true)
	facade.set_meta("clear_opening_width_m", 16.0)
	facade.set_meta("gate_number", gate_number)
	facade.set_meta("design_match", "complete Island One astrolabe, filigree leaves and hinged threshold")
	gate.add_child(facade)
	var old_memory_gate := gate.get_node_or_null("IslandTwoMemoryGate") as Node3D
	if old_memory_gate != null:
		old_memory_gate.visible = false
		old_memory_gate.set_meta("retired_for_island_one_gate_match", true)
		for old_collision in old_memory_gate.find_children("*", "CollisionShape3D", true, false):
			(old_collision as CollisionShape3D).disabled = true

	# Gate Two and Three already own physical hinged archive leaves. Gate Four is
	# an always-clear sanctuary threshold, so this shared frame adds no blocker.
	for side in [-1.0, 1.0]:
		var suffix := "West" if side < 0.0 else "East"
		var x: float = float(side) * 11.35
		_add_brick(facade, "%sHeavenlyPlinth" % suffix, Vector3(x, 0.68, 0.55),
			Bricks.build_bevel_box(Vector3(4.1, 1.35, 4.2), 0.24), _materials.sanctum_ivory)
		_add_box(facade, "%sCharcoalRecess" % suffix, Vector3(x, 7.15, 0.35),
			Vector3(3.0, 11.8, 2.25), _materials.shared_style_charcoal, false)
		_add_brick(facade, "%sIvoryTower" % suffix, Vector3(x, 7.2, 0.65),
			Bricks.build_bevel_box(Vector3(3.8, 12.4, 3.4), 0.28), _materials.sanctum_ivory)
		_add_box(facade, "%sAetherWindow" % suffix, Vector3(x, 7.4, -1.10),
			Vector3(0.65, 6.6, 0.12), _materials.arrival_glass, false)
		_add_brick(facade, "%sTowerCapital" % suffix, Vector3(x, 13.70, 0.55),
			Bricks.build_bevel_box(Vector3(4.7, 0.85, 4.0), 0.20), _materials.sanctum_ivory)
		_add_brick(facade, "%sTowerFinial" % suffix, Vector3(x, 15.25, 0.30),
			Bricks.build_crystal(0.62, 2.2, 0.22, 8),
			_materials.astral_lavender if side < 0.0 else _materials.arrival_glass)

	var arch_center := Vector3(0, 13.35, -0.25)
	for segment in 14:
		var a := PI - PI * float(segment) / 14.0
		var b := PI - PI * float(segment + 1) / 14.0
		var start := arch_center + Vector3(cos(a) * 10.7, sin(a) * 7.2, 0)
		var finish := arch_center + Vector3(cos(b) * 10.7, sin(b) * 7.2, 0)
		_add_cable_between(facade, "IvoryCrownArch_%02d" % (segment + 1),
			start, finish, 0.58, 0.58, _materials.sanctum_ivory, 8)
		if segment % 2 == 0:
			_add_cable_between(facade, "GiltCrownReveal_%02d" % (segment + 1),
				start + Vector3(0, 0, -0.38), finish + Vector3(0, 0, -0.38),
				0.14, 0.14, _materials.gold, 6)
	_add_brick(facade, "HeavenlyStarKeystone", Vector3(0, 21.35, -0.55),
		Bricks.build_crystal(1.15, 3.1, 0.24, 8), _materials.green_glow)
	_add_torus(facade, "HeavenlyStarBearing", Vector3(0, 19.85, -0.35),
		1.55, 1.92, _materials.astral_brass, Vector3(90, 0, 0))
	_add_brick(facade, "HeavenlyThresholdSill", Vector3(0, 0.30, 0.15),
		Bricks.build_bevel_box(Vector3(18.0, 0.32, 3.2), 0.12), _materials.sanctum_ivory)
	var halo := Node3D.new()
	halo.name = "SharedHeavenlyStarHalo"
	halo.set_meta("design_revision", "island_one_astrolabe_match_v2")
	facade.add_child(halo)
	_build_gate_astrolabe_crest(halo, facade)
	_build_shared_heavenly_gate_leaves(gate, facade)
	if gate_number == 2:
		_build_island_two_styled_gate_walls(gate, facade)
	gate.set_meta("gate_visual_family", "heavenly_star_gate")
	gate.set_meta("visual_standardized_from", "IslandOneHeavenlyStarGate")


func _build_shared_heavenly_gate_leaves(gate: AnimatableBody3D, facade: Node3D) -> void:
	var prototype_barrier := gate.get_node_or_null("Barrier") as MeshInstance3D
	if prototype_barrier != null:
		prototype_barrier.visible = false
		prototype_barrier.set_meta("retired_for_shared_heavenly_leaves", true)
	var leaves := Node3D.new()
	leaves.name = "SharedHeavenlyGateLeaves"
	leaves.set_meta("barrier_coverage_width_m", 16.0)
	leaves.set_meta("same_concept_as", "IslandOneHeavenlyStarGate")
	leaves.set_meta("preserve_authored_nodes", true)
	facade.add_child(leaves)
	for side in [-1.0, 1.0]:
		var leaf := AnimatableBody3D.new()
		leaf.name = "WestCelestialLeaf" if side < 0.0 else "EastCelestialLeaf"
		leaf.sync_to_physics = true
		leaf.position = Vector3(side * 5.70, 0.0, -0.75)
		leaves.add_child(leaf)
		_build_heavenly_gate_leaf_visual(leaf, side)
		var collision := CollisionShape3D.new()
		collision.name = "LeafCollision"
		collision.position = Vector3(-side * 2.68, 10.5, 0)
		var shape := BoxShape3D.new()
		shape.size = Vector3(5.9, 17.2, 1.10)
		collision.shape = shape
		leaf.add_child(collision)
	gate.get_node("CollisionShape3D").disabled = true
	gate.set_meta("custom_gate_motion", "heavenly_star_hinges")
	gate.set_meta("physical_barrier_removed", false)
	gate.set_meta("route_remains_open", false)
	gate.set_meta("barrier_covers_threshold", true)


func _build_gate_interaction_buttons(_geometry: Node3D) -> void:
	_gate_interaction_buttons.clear()
	var island_gate := get_island_one_heavenly_star_gate()
	if island_gate != null:
		_add_gate_interaction_button(island_gate, Vector3(15.3, 0.0, -5.0),
			"IslandOneGateControl", "island_one", -1)
	for gate_number in [2, 3]:
		if gate_number - 1 >= _quest_gates.size():
			continue
		_add_gate_interaction_button(_quest_gates[gate_number - 1],
			Vector3(14.6, 0.0, -4.8), "IslandGateControl_%d" % gate_number,
			"quest", gate_number - 1)
	set_meta("nearby_q_gate_control_count", _gate_interaction_buttons.size())


func _add_gate_interaction_button(parent: Node3D, at: Vector3, node_name: String,
		gate_kind: String, quest_gate_index: int) -> void:
	var button := Node3D.new()
	button.name = node_name
	button.position = at
	button.set_meta("preserve_authored_nodes", true)
	button.set_meta("gate_kind", gate_kind)
	button.set_meta("quest_gate_index", quest_gate_index)
	button.set_meta("interaction_key", "Q")
	button.set_meta("interaction_range_m", 8.5)
	button.set_meta("ground_contact", true)
	parent.add_child(button)
	_add_cylinder(button, "GroundedButtonPlinth", Vector3(0, 0.45, 0),
		1.65, 0.90, _materials.shared_style_charcoal, true, 10)
	_add_cylinder(button, "IvoryButtonPedestal", Vector3(0, 1.35, 0),
		1.10, 1.15, _materials.sanctum_ivory, true, 10)
	var key := _add_cylinder(button, "AetherQButton", Vector3(0, 2.05, 0),
		0.72, 0.24, _materials.arrival_glass, false, 10)
	key.rotation_degrees.x = 0.0
	_add_label(button, "Q", Vector3(0, 2.75, 0), Color("dffcff"), 23)
	_gate_interaction_buttons.append(button)


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
	if open:
		gate.set_meta("gate_interaction_unlocked", true)
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
		var tread := _add_box(stairs, "StationStep_%02d" % (index + 1), tread_center,
			Vector3(STATION_STAIR_WIDTH, 0.14, tread_depth), _materials.stone, false, yaw)
		# Tests and traversal diagnostics resolve every named tread at runtime.
		# Keep these real nodes while the repeated decorative geometry is batched.
		tread.set_meta("preserve_runtime_node", true)
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
	entry_gate.position = Vector3(0, 1, -64)
	# The live arrival is deliberately offset ten metres west of the centreline
	# to clear the first quest station. Aim the complete teleport instrument at
	# that real approach instead of leaving it on the zone's generic zero yaw;
	# the ring then meets the player squarely rather than reading as a skewed oval.
	var entry_approach := STANDALONE_PLAYER_ARRIVAL
	var approach_delta := entry_approach - entry_gate.position
	entry_gate.rotation.y = atan2(approach_delta.x, approach_delta.z)
	entry_gate.set_meta("faces_player_approach", true)
	entry_gate.set_meta("approach_yaw_degrees", rad_to_deg(entry_gate.rotation.y))
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
	# Matte stone joints define the court without the long gold/cyan rings that
	# previously read as temporary route guides from the gameplay camera.
	_add_torus(terrace, "ArrivalCourtOuterStoneJoint", Vector3(0, 0.58, 8),
		66.0, 66.55, _materials.quest_ivory_inset)
	_add_torus(terrace, "ArrivalCourtInnerSageJoint", Vector3(0, 0.60, 8),
		39.0, 39.42, _materials.island_three_sage_deep)
	_add_box(terrace, "ProcessionalIvoryAxis", Vector3(0, 0.61, 20),
		Vector3(19.0, 0.18, 112.0), _materials.celestial_floor, false)
	_add_box(terrace, "ProcessionalStoneJoint", Vector3(0, 0.70, 20),
		Vector3(0.62, 0.08, 109.0), _materials.quest_ivory_inset, false)

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
	_build_island_one_low_poly_environment_finish(arrival)
	_island_one_puzzle = arrival
	arrival.puzzle_solved.connect(_on_island_one_puzzle_solved)
	arrival.configure(object_state_store_path, scale_factor)
	_set_island_one_star_gate_open(arrival.is_powered(), false)
	var arrival_light := _add_zone_light(arrival, Vector3(0, 42, -2), Color("ffe3ad"), 112.0, 3.15)
	arrival_light.name = "HighHeavenlyArrivalLight"
	return arrival


func _build_island_one_low_poly_environment_finish(arrival: MindSparkIslandOnePuzzle) -> void:
	# One deliberate landscape layer ties the return threshold, quest court and
	# observatory skyline together.  It stays clear of every operator position and
	# uses collision only where a visible wall, planter or trunk occupies space.
	var environment := Node3D.new()
	environment.name = "LowPolyCelestialEnvironment"
	environment.set_meta("design_revision", "island_one_celestial_campus_v45")
	environment.set_meta("style", "faceted ivory observatory garden")
	environment.set_meta("clear_route_width_m", 18.0)
	environment.set_meta("player_height_authored", true)
	environment.set_meta("prototype_lines_retired", true)
	environment.set_meta("collision_readable", true)
	arrival.add_child(environment)

	var gateway := Node3D.new()
	gateway.name = "AstralReturnGatehouse"
	gateway.set_meta("purpose", "grounded return threshold and arrival landmark")
	gateway.set_meta("opening_width_m", 42.0)
	environment.add_child(gateway)
	_build_island_one_low_poly_gatehouse(gateway)

	var campus := Node3D.new()
	campus.name = "SignalObservatoryCampus"
	campus.set_meta("purpose", "frame the existing quest machinery without replacing it")
	campus.set_meta("operator_clearance_preserved", true)
	environment.add_child(campus)
	_build_island_one_low_poly_campus(campus)

	var landscape := Node3D.new()
	landscape.name = "PurposefulLandscape"
	landscape.set_meta("planting_rule", "frame routes and island edges; never occupy the aisle")
	landscape.set_meta("tree_count", 6)
	landscape.set_meta("canopy_cluster_count", 36)
	environment.add_child(landscape)
	var tree_positions := [
		Vector3(-50, 0.8, -42), Vector3(50, 0.8, -42),
		Vector3(-56, 0.8, -8), Vector3(56, 0.8, -8),
		Vector3(-54, 0.8, 52), Vector3(54, 0.8, 52),
	]
	for tree_index in tree_positions.size():
		_build_island_one_faceted_tree(landscape,
			"CampusTree_%02d" % (tree_index + 1), tree_positions[tree_index],
			0.82 + float(tree_index % 3) * 0.08, tree_index)

	_build_island_one_environment_status(environment)
	_apply_island_one_low_poly_architecture_palette(arrival)


func _build_island_one_low_poly_gatehouse(parent: Node3D) -> void:
	var gate_z := -64.0
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0 else "East"
		var x := float(side) * 27.0
		_add_box(parent, "%sGateFoundation" % side_name,
			Vector3(x, 1.0, gate_z), Vector3(11.0, 2.0, 12.0),
			_materials.shared_style_charcoal, true)
		_add_brick(parent, "%sGateButtress" % side_name,
			Vector3(x, 10.5, gate_z), Bricks.build_bevel_box(Vector3(8.4, 19.0, 8.4), 0.72),
			_materials.shared_style_ivory)
		_add_box(parent, "%sGateShoulder" % side_name,
			Vector3(x, 20.4, gate_z), Vector3(11.0, 1.8, 10.0),
			_materials.shared_style_ivory, false)
		_add_tapered_cylinder(parent, "%sGateSpire" % side_name,
			Vector3(x, 27.0, gate_z), 0.55, 3.2, 11.0,
			_materials.shared_style_ivory, 8)
		_add_brick(parent, "%sGateWindow" % side_name,
			Vector3(x, 12.0, gate_z - 4.25), Bricks.build_crystal(1.05, 5.5, 0.42, 6),
			_materials.shared_style_cyan)
	var west_arch := Vector3(-23.0, 20.0, gate_z)
	var crown := Vector3(0, 30.0, gate_z)
	var east_arch := Vector3(23.0, 20.0, gate_z)
	_add_cable_between(parent, "WestFacetedArch", west_arch, crown,
		1.45, 1.05, _materials.shared_style_ivory, 8)
	_add_cable_between(parent, "EastFacetedArch", crown, east_arch,
		1.05, 1.45, _materials.shared_style_ivory, 8)
	_add_brick(parent, "GateKeystoneCrystal", crown + Vector3(0, -1.0, -1.0),
		Bricks.build_crystal(1.35, 4.8, 0.52, 6), _materials.shared_style_cyan)

	# Short, grounded parapets define the void edge beside the threshold.  The
	# forty-two-metre opening remains completely unobstructed.
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0 else "East"
		var x := float(side) * 37.0
		_add_box(parent, "%sGateParapetFoundation" % side_name, Vector3(x, 0.7, -59.0),
			Vector3(2.0, 1.4, 26.0), _materials.shared_style_charcoal, true)
		_add_box(parent, "%sGateParapetCoping" % side_name, Vector3(x, 1.65, -59.0),
			Vector3(2.8, 0.55, 26.0), _materials.shared_style_ivory, false)


func _build_island_one_low_poly_campus(parent: Node3D) -> void:
	# Flush stone modules replace the single neon route stripe.  They are visual
	# paving over the already tested continuous collision floor.
	for paving_index in 7:
		var z := -43.0 + float(paving_index) * 17.0
		_add_brick(parent, "ProcessionalPaver_%02d" % (paving_index + 1),
			Vector3(0, 0.78, z), Bricks.build_bevel_box(Vector3(18.0, 0.16, 13.5), 0.34),
			_materials.shared_style_ivory)
		if paving_index in [0, 3, 6]:
			for marker_side in [-1.0, 1.0]:
				_add_box(parent, "ThresholdMarker_%02d" % (paving_index * 2 + (0 if marker_side < 0 else 1)),
					Vector3(float(marker_side) * 6.2, 0.90, z), Vector3(2.2, 0.08, 0.75),
					_materials.shared_style_cyan, false)

	# A high, simple crown gives the observatory a readable silhouette from the
	# spawn while the original compass and all sixteen controls remain untouched.
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0 else "East"
		var x := float(side) * 32.0
		_add_tapered_cylinder(parent, "%sObservatoryMast" % side_name,
			Vector3(x, 16.0, 8.0), 1.4, 2.6, 28.0,
			_materials.shared_style_ivory, 8)
		_add_box(parent, "%sMastFoot" % side_name,
			Vector3(x, 1.5, 8.0), Vector3(7.0, 3.0, 8.0),
			_materials.shared_style_charcoal, true)
		_add_brick(parent, "%sMastLens" % side_name,
			Vector3(x, 17.0, 5.9), Bricks.build_crystal(0.72, 3.8, 0.30, 6),
			_materials.shared_style_cyan)
	_add_cable_between(parent, "ObservatoryCrownWest",
		Vector3(-32, 28, 8), Vector3(0, 36, 8),
		0.72, 0.48, _materials.shared_style_ivory, 8)
	_add_cable_between(parent, "ObservatoryCrownEast",
		Vector3(0, 36, 8), Vector3(32, 28, 8),
		0.48, 0.72, _materials.shared_style_ivory, 8)
	_add_brick(parent, "ObservatoryCrownPrism", Vector3(0, 34.0, 8),
		Bricks.build_crystal(1.7, 6.8, 0.62, 6), _materials.shared_style_cyan)

	# The central apron remains open for movement and lets the three instrument
	# families read from the arrival threshold. A shallow faceted disc gives the
	# court a deliberate centre without adding a collision seam.
	var court := Node3D.new()
	court.name = "CentralObservatoryCourt"
	court.set_meta("preserve_authored_nodes", true)
	court.set_meta("clear_movement_diameter_m", 40.0)
	court.set_meta("station_clearance_m", 8.0)
	parent.add_child(court)
	_add_cylinder(court, "FacetedCourtApron", Vector3(0, 0.82, 22),
		20.0, 0.12, _materials.shared_style_ivory, false, 16)
	for wedge_index in 8:
		var wedge_angle := TAU * float(wedge_index) / 8.0
		_add_box(court, "CyanCompassWedge_%02d" % (wedge_index + 1),
			Vector3(sin(wedge_angle) * 16.8, 0.91, 22 + cos(wedge_angle) * 16.8),
			Vector3(0.55, 0.06, 2.3), _materials.shared_style_cyan, false, -wedge_angle)

	# Open instrument gardens replace the five flat backdrop walls. Each garden
	# uses two grounded outer posts, a low planter and a raised cyan name crystal;
	# player-facing and lateral sides remain open around every operator.
	var gardens := Node3D.new()
	gardens.name = "OpenInstrumentGardens"
	gardens.set_meta("preserve_authored_nodes", true)
	gardens.set_meta("garden_count", 5)
	gardens.set_meta("backdrop_walls_removed", true)
	gardens.set_meta("minimum_operator_clearance_m", 8.0)
	parent.add_child(gardens)
	var garden_specs := [
		["LightGarden", Vector3(-75, 0.8, 24), Vector3(1, 0, 0)],
		["PressureWestGarden", Vector3(-42, 0.8, -36), Vector3(0, 0, 1)],
		["PressureEastGarden", Vector3(42, 0.8, -36), Vector3(0, 0, 1)],
		["AlignmentWestGarden", Vector3(-42, 0.8, 82), Vector3(0, 0, 1)],
		["AlignmentEastGarden", Vector3(42, 0.8, 82), Vector3(0, 0, 1)],
	]
	for garden_spec in garden_specs:
		var garden_name := str(garden_spec[0])
		var centre := garden_spec[1] as Vector3
		var axis := garden_spec[2] as Vector3
		var garden := Node3D.new()
		garden.name = garden_name
		garden.set_meta("open_sides", 3)
		gardens.add_child(garden)
		var cross_axis := Vector3(axis.z, 0, axis.x)
		for post_side in [-1.0, 1.0]:
			var post_at := centre + cross_axis * float(post_side) * 8.0
			_add_box(garden, "GardenPost_%s" % ("L" if post_side < 0 else "R"),
				post_at + Vector3.UP * 3.2, Vector3(1.4, 6.4, 1.4),
				_materials.shared_style_ivory, true)
			_add_brick(garden, "GardenCrystal_%s" % ("L" if post_side < 0 else "R"),
				post_at + Vector3.UP * 7.0, Bricks.build_crystal(0.62, 2.4, 0.22, 6),
				_materials.shared_style_cyan if post_side < 0 else _materials.shared_style_lavender)
		var planter_at := centre - axis * 6.5
		_add_box(garden, "CharcoalPlanterFoundation", planter_at,
			Vector3(12.0, 1.6, 2.2) if absf(axis.z) > 0.5 else Vector3(2.2, 1.6, 12.0),
			_materials.shared_style_charcoal, true)
		_add_box(garden, "IvoryPlanterCoping", planter_at + Vector3.UP * 1.05,
			Vector3(12.8, 0.5, 3.0) if absf(axis.z) > 0.5 else Vector3(3.0, 0.5, 12.8),
			_materials.shared_style_ivory, false)


func _build_island_one_faceted_tree(parent: Node3D, tree_name: String,
		base: Vector3, tree_scale: float, variant: int) -> void:
	var tree := Node3D.new()
	tree.name = tree_name
	tree.set_meta("purpose", "frame the processional route")
	tree.set_meta("canopy_cluster_count", 6)
	parent.add_child(tree)
	var trunk_height := 8.2 * tree_scale
	_add_cylinder(tree, "FacetedTrunk", base + Vector3.UP * trunk_height * 0.5,
		0.72 * tree_scale, trunk_height, _materials.island_three_hero_bark, true, 7)
	for branch_index in 3:
		var angle := TAU * float(branch_index) / 3.0 + float(variant) * 0.37
		var start := base + Vector3.UP * trunk_height * 0.68
		var finish := base + Vector3(sin(angle) * 3.4 * tree_scale,
			trunk_height + 1.2 * tree_scale + float(branch_index % 2),
			cos(angle) * 3.4 * tree_scale)
		_add_cable_between(tree, "FacetedBranch_%02d" % (branch_index + 1),
			start, finish, 0.34 * tree_scale, 0.14 * tree_scale,
			_materials.island_three_hero_bark, 7)
		for crown_index in 2:
			var crown := _add_sphere(tree, "Canopy_%02d_%02d" % [branch_index + 1, crown_index + 1],
				finish + Vector3((float(crown_index) - 0.5) * 2.4 * tree_scale,
					float(crown_index) * 0.65, 0),
				Vector3(3.8, 2.3, 3.4) * tree_scale,
				_materials.island_three_sage_deep if (variant + branch_index + crown_index) % 3 \
					else _materials.shared_style_lavender)
			(crown.mesh as SphereMesh).radial_segments = 7
			(crown.mesh as SphereMesh).rings = 4


func _build_island_one_environment_status(parent: Node3D) -> void:
	var status := Node3D.new()
	status.name = "EnvironmentStatusSystem"
	status.set_meta("preserve_authored_nodes", true)
	status.set_meta("states", ["available", "analyzed", "complete"])
	parent.add_child(status)
	var available := Node3D.new()
	available.name = "StatusAvailable"
	available.set_meta("preserve_authored_nodes", true)
	status.add_child(available)
	for side in [-1.0, 1.0]:
		_add_brick(available, "AvailableGateBeacon",
			Vector3(float(side) * 27.0, 31.0, -64.0),
			Bricks.build_crystal(0.45, 1.9, 0.18, 6), _materials.shared_style_cyan)
	var analyzed := Node3D.new()
	analyzed.name = "StatusAnalyzed"
	analyzed.visible = false
	analyzed.set_meta("preserve_authored_nodes", true)
	status.add_child(analyzed)
	for side in [-1.0, 1.0]:
		_add_brick(analyzed, "AnalyzedMastBeacon",
			Vector3(float(side) * 32.0, 31.0, 8.0),
			Bricks.build_crystal(0.52, 2.3, 0.20, 6), _materials.shared_style_lavender)
	var complete := Node3D.new()
	complete.name = "StatusComplete"
	complete.visible = false
	complete.set_meta("preserve_authored_nodes", true)
	status.add_child(complete)
	_add_brick(complete, "CompletedCrownBeacon", Vector3(0, 39.0, 8.0),
		Bricks.build_crystal(0.70, 3.2, 0.28, 6), _materials.shared_style_cyan)


func _apply_island_one_low_poly_architecture_palette(arrival: Node3D) -> void:
	var hide_patterns := [
		"ArrivalCourtOuterStoneJoint", "ArrivalCourtInnerSageJoint",
		"VaultRidgeGiltCollar", "CanopyObservationOrbit", "TreeWisdomCrownHalo",
		"TreeGoldenBranchVein", "TreeCrownRay",
	]
	for candidate in arrival.find_children("*", "MeshInstance3D", true, false):
		var mesh := candidate as MeshInstance3D
		var should_hide := false
		for pattern in hide_patterns:
			if pattern in mesh.name:
				should_hide = true
				break
		if should_hide:
			mesh.visible = false
			mesh.set_meta("retired_for_low_poly_clarity", true)
			continue
		var key := mesh.name.to_lower()
		var legacy_metal: bool = mesh.material_override == _materials.gold \
			or mesh.material_override == _materials.astral_brass \
			or mesh.material_override == _materials.quest_brass \
			or mesh.material_override == _materials.quest_gold_leaf \
			or mesh.material_override == _materials.island_gold \
			or mesh.material_override == _materials.bio_socket_gold
		if legacy_metal or "gilt" in key or "brass" in key or "golden" in key:
			mesh.material_override = _materials.shared_style_charcoal
			mesh.set_meta("restyled_for_low_poly_clarity", true)



func _create_island_one_gate_architecture_kit(arrival: Node3D) -> Node3D:
	var kit := Node3D.new()
	kit.name = "GateArchitectureKit"
	# The arrival puzzle controller animates the separate CompassMachine branch;
	# this kit is inert architecture. Let the static render pass consolidate its
	# hundreds of editable ribs, panes and masonry pieces without treating them
	# as puzzle state. Source nodes remain mounted for tests and editor inspection.
	kit.set_meta("static_render_branch_independent", true)
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
	_build_thought_witness(machine)
	_build_constellation_target_instrument(machine)
	var puzzle_light := _add_zone_light(arrival, Vector3(0, 36.0, 42.0), Color("ffe9bd"), 68.0, 2.85)
	puzzle_light.name = "HighPuzzleCompositionLight"

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

	# Keep the two functional pressure readouts outside the processional aisle.
	# Their former eye-level placement at x=±24 crowded the opening view and made
	# the player appear to spawn inside machinery.
	_build_pressure_gauge(arrival, "WestPressureGauge", Vector3(-31.0, 9.2, -22.0), -0.18)
	_build_pressure_gauge(arrival, "EastPressureGauge", Vector3(31.0, 9.2, -22.0), 0.18)
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0 else "East"
		var governor := Node3D.new()
		governor.name = "%sGovernorRotor" % side_name
		governor.position = Vector3(side * 27.0, 5.6, -16.0)
		governor.set_meta("preserve_authored_nodes", true)
		arrival.add_child(governor)
		# The controller still rotates this node as live regulator feedback, but a
		# compact faceted pod replaces the long four-arm propeller that crossed the
		# player's sightline.
		_add_cylinder(governor, "GovernorCore", Vector3.ZERO, 1.45, 1.2,
			_materials.sanctum_ivory, false, 8)
		for arm_index in 4:
			var arm_angle := TAU * float(arm_index) / 4.0
			var facet_at := Vector3(sin(arm_angle) * 2.15, 0, cos(arm_angle) * 2.15)
			_add_box(governor, "GovernorFacet_%02d" % (arm_index + 1), facet_at,
				Vector3(0.72, 0.56, 1.35), _materials.arrival_glass, false, arm_angle)

	var conduits := Node3D.new()
	conduits.name = "PuzzlePowerConduits"
	conduits.set_meta("preserve_authored_nodes", true)
	arrival.add_child(conduits)
	# Keep every energy path on the floor as a sequence of short low-poly
	# markers. The former continuous brass/cyan pipes crossed the court at player
	# height and collapsed the observatory into a web of unsupported lines.
	for side in [-1.0, 1.0]:
		for marker_index in 6:
			var progress := float(marker_index + 1) / 7.0
			var marker_at := Vector3(side * 24.0, 2.62, -22.0).lerp(
				Vector3(side * 18.0, 2.62, 8.0), progress)
			_add_box(conduits,
				"RegulatorFloorLink_%s_%02d" % ["West" if side < 0 else "East", marker_index + 1],
				marker_at, Vector3(1.15, 0.10, 1.65), _materials.arrival_glass, false)
	# Paired floor circuits explain the coupling without relying on HUD text.
	var selector_positions := [Vector3(-22, 3.3, 58), Vector3(0, 3.3, 64), Vector3(22, 3.3, 58)]
	var coupled_ring_points := [
		[Vector3(-18, 2.8, 22), Vector3(-9, 2.9, 18)],
		[Vector3(-6, 2.9, 18), Vector3(6, 3.0, 15)],
		[Vector3(18, 3.0, 22), Vector3(9, 2.8, 18)],
	]
	for selector_index in 3:
		for link_index in 2:
			var link_start: Vector3 = selector_positions[selector_index]
			var link_finish: Vector3 = coupled_ring_points[selector_index][link_index]
			for marker_index in 4:
				var progress := float(marker_index + 1) / 5.0
				var marker_at := link_start.lerp(link_finish, progress)
				marker_at.y = 2.62
				_add_box(conduits,
					"SelectorFloorLink_%02d_%02d_%02d" % [selector_index + 1, link_index + 1, marker_index + 1],
					marker_at, Vector3(0.86, 0.10, 1.35), _materials.arrival_glass, false)
	for marker_index in 10:
		_add_box(conduits, "MainFloorLink_%02d" % (marker_index + 1),
			Vector3(0, 2.62, 31.0 + float(marker_index) * 4.2),
			Vector3(1.20, 0.10, 2.15), _materials.arrival_glass, false)

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
	instrument.set_meta("design_revision", "v33_low_poly_crown_instrument")
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

	# Compact shoulders transfer the crown into the two pylons without creating
	# another pair of broad panels behind the dial faces.
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0 else "East"
		_add_brick(instrument, "SanctumCrownShoulder_%s" % side_name,
			Vector3(side * 11.9, 19.25, gateway_z),
			Bricks.build_bevel_box(Vector3(4.8, 0.82, 1.55), 0.24), _materials.sanctum_ivory)
		_add_brick(instrument, "SanctumCrownAetherInset_%s" % side_name,
			Vector3(side * 11.9, 19.25, gateway_z - 0.83),
			Bricks.build_bevel_box(Vector3(3.1, 0.24, 0.16), 0.06), _materials.arrival_glass)

	# A narrow load beam and open triangular truss replace the old solid slab.
	# The opening below the dials keeps the central court and player readable.
	_add_brick(instrument, "WisdomCrownMainBeam", Vector3(0, 18.85, gateway_z + 0.12),
		Bricks.build_bevel_box(Vector3(23.4, 0.66, 0.82), 0.20), _materials.sanctum_ivory)
	_add_box(instrument, "WisdomCrownUpperCharcoalOrder", Vector3(0, 19.24, gateway_z - 0.03),
		Vector3(23.8, 0.14, 0.98), _materials.shared_style_charcoal)
	_add_box(instrument, "WisdomCrownLowerAetherOrder", Vector3(0, 18.47, gateway_z - 0.05),
		Vector3(21.8, 0.10, 0.94), _materials.arrival_glass)
	for truss_side in [-1.0, 1.0]:
		var truss_label := "West" if truss_side < 0 else "East"
		_add_cable_between(instrument, "WisdomCrownTruss_%s" % truss_label,
			Vector3(truss_side * 11.4, 19.25, gateway_z - 0.55),
			Vector3(truss_side * 4.0, 23.0, gateway_z - 0.55),
			0.22, 0.14, _materials.shared_style_charcoal, 8)
		_add_sphere(instrument, "WisdomCrownJoint_%s" % truss_label,
			Vector3(truss_side * 4.0, 23.0, gateway_z - 0.55),
			Vector3.ONE * 0.30, _materials.shared_style_cyan)
	for boss_index in 7:
		_add_sphere(instrument, "WisdomCrownBoss_%02d" % (boss_index + 1),
			Vector3(-10.5 + float(boss_index) * 3.5, 19.27, gateway_z - 0.58),
			Vector3.ONE * (0.18 if boss_index != 3 else 0.28),
			_materials.shared_style_charcoal if boss_index % 2 == 0 else _materials.shared_style_cyan)

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
			0.12, 0.09, _materials.shared_style_charcoal, 6)

	# Three raised, evenly spaced pods present the state target as a readable
	# instrument. Their lower edges clear the crown beam, and their restrained
	# cyan/lavender feedback remains legible against the ivory case.
	var dial_array := Node3D.new()
	dial_array.name = "StateDialArray"
	dial_array.set_meta("preserve_authored_nodes", true)
	dial_array.set_meta("dial_count", 3)
	dial_array.set_meta("equal_spacing_m", 7.6)
	dial_array.set_meta("beam_clearance_m", 1.35)
	dial_array.set_meta("collision_free", true)
	instrument.add_child(dial_array)
	var target_names := ["NOTICE", "UNDERSTAND", "CHOOSE"]
	var target_angles := [-PI * 0.25, 0.0, -PI * 1.25]
	for index in 3:
		var x := -7.6 + float(index) * 7.6
		var socket_at := Vector3(x, 23.85, gateway_z + 0.65)
		var pod := Node3D.new()
		pod.name = "%sInstrumentPod" % target_names[index]
		pod.position = socket_at
		dial_array.add_child(pod)
		_add_cable_between(pod, "PodMountSpine", Vector3(0, -4.34, -0.56),
			Vector3(0, -2.32, -0.56), 0.26, 0.18,
			_materials.shared_style_charcoal, 8)
		_add_brick(pod, "PodMountFoot", Vector3(0, -4.28, -0.50),
			Bricks.build_bevel_box(Vector3(1.45, 0.42, 0.70), 0.12),
			_materials.sanctum_ivory)
		var indicator_case := _add_cylinder(pod, "IvoryOuterCase", Vector3(0, 0, -0.30),
			2.56, 0.46, _materials.sanctum_ivory, false, 12)
		indicator_case.rotation_degrees.x = 90.0
		var indicator_face := _add_cylinder(pod, "MutedCyanFace", Vector3(0, 0, 0.14),
			2.08, 0.16, _materials.sanctum_dial, false, 12)
		indicator_face.rotation_degrees.x = 90.0
		_add_torus(pod, "CharcoalInnerBezel", Vector3(0, 0, 0.29),
			2.02, 2.30, _materials.shared_style_charcoal, Vector3(90, 0, 0))
		_add_torus(pod, "CyanFaceRegister", Vector3(0, 0, 0.34),
			1.77, 1.87, _materials.shared_style_cyan, Vector3(90, 0, 0))
		var pointer := Node3D.new()
		pointer.name = "ConstellationActual_%s" % target_names[index]
		pointer.position = Vector3(0, 0, 0.48)
		pod.add_child(pointer)
		_add_cable_between(pointer, "ActualNeedle", Vector3(0, 0.20, 0),
			Vector3(0, 1.66, 0), 0.22, 0.11, _materials.shared_style_cyan, 8)
		_add_brick(pointer, "ActualNeedleTip", Vector3(0, 1.77, 0),
			Bricks.build_crystal(0.22, 0.46, 0.06, 6), _materials.shared_style_cyan)
		_add_sphere(pointer, "ActualHub", Vector3.ZERO,
			Vector3.ONE * 0.42, _materials.shared_style_cyan)
		_add_sphere(pointer, "ActualHubCap", Vector3(0, 0, 0.11),
			Vector3.ONE * 0.18, _materials.sanctum_ivory)
		var target := Node3D.new()
		target.name = "ConstellationTarget_%s" % target_names[index]
		target.position = Vector3(0, 0, 0.56)
		target.rotation.z = target_angles[index]
		pod.add_child(target)
		_add_triangle_patch(target, "LavenderTargetWedge",
			Vector3(-0.26, 1.62, 0), Vector3(0.26, 1.62, 0),
			Vector3(0, 2.02, 0), _materials.shared_style_lavender)
		for tick_index in 8:
			var tick_angle := TAU * float(tick_index) / 8.0
			var tick_at := Vector3(sin(tick_angle) * 1.72,
				cos(tick_angle) * 1.72, 0.48)
			_add_sphere(pod, "DialTick_%02d" % (tick_index + 1), tick_at,
				Vector3.ONE * (0.14 if tick_index % 2 else 0.20),
				_materials.sanctum_ivory if tick_index % 2 else _materials.shared_style_cyan)
		_add_brick(pod, "IntegratedNameplate", Vector3(0, -3.02, 0.02),
			Bricks.build_bevel_box(Vector3(4.30, 0.56, 0.24), 0.10),
			_materials.sanctum_ivory)
		var nameplate := _add_label(pod, target_names[index],
			Vector3(0, -3.04, 0.22), Color("24313b"), 16)
		nameplate.name = "%sNameplateLabel" % target_names[index]
		nameplate.pixel_size = 0.024
		nameplate.outline_size = 2
		nameplate.no_depth_test = true

	# The completion crystal now grows from a visible central mast instead of
	# floating between unrelated roof ribs.
	_add_cable_between(instrument, "CrownCrystalMast",
		Vector3(0, 26.2, gateway_z - 0.45), Vector3(0, 28.15, gateway_z - 0.45),
		0.24, 0.16, _materials.shared_style_charcoal, 8)
	_add_brick(instrument, "CrownCrystalSocket", Vector3(0, 28.05, gateway_z - 0.44),
		Bricks.build_bevel_box(Vector3(1.30, 0.46, 0.62), 0.14), _materials.sanctum_ivory)
	_add_brick(instrument, "CrownDormantCrystal", Vector3(0, 28.28, gateway_z - 0.44),
		Bricks.build_crystal(0.82, 3.05, 0.30, 6), _materials.sanctum_lavender_glass)
	var completion_crystal := _add_brick(instrument, "CrownCompletionCrystal",
		Vector3(0, 28.28, gateway_z - 0.42),
		Bricks.build_crystal(1.05, 3.4, 0.34, 6), _materials.shared_style_cyan)
	completion_crystal.visible = false
	completion_crystal.set_meta("activation", "all three state dials match")
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
		Vector3(0, 33.0, gateway_z), Color("fff1bf"), 18)


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
	# A squared three-piece frame keeps the thought readable from the arrival
	# aisle without adding another full ring to the already circular floor game.
	_add_brick(witness, "ThoughtFrameLeft", Vector3(-7.0, 10.2, 8),
		Bricks.build_bevel_box(Vector3(0.85, 10.4, 1.1), 0.18), _materials.sanctum_ivory)
	_add_brick(witness, "ThoughtFrameRight", Vector3(7.0, 10.2, 8),
		Bricks.build_bevel_box(Vector3(0.85, 10.4, 1.1), 0.18), _materials.sanctum_ivory)
	_add_brick(witness, "ThoughtFrameCrown", Vector3(0, 15.35, 8),
		Bricks.build_bevel_box(Vector3(14.8, 0.85, 1.1), 0.18), _materials.sanctum_ivory)
	for anchor_index in 4:
		var anchor_angle := TAU * float(anchor_index) / 4.0
		_add_brick(witness, "ThoughtAnchorCrystal_%02d" % (anchor_index + 1),
			Vector3(sin(anchor_angle) * 7.3, 10.2 + cos(anchor_angle) * 4.0, 8),
			Bricks.build_crystal(0.48, 1.20, 0.18, 6), _materials.arrival_glass)
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
			heading.pixel_size = .0045
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
	label.pixel_size = 0.0065
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
	arch.position = Vector3(0, 0, -64)
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


func _unify_island_one_tree_and_quest_style() -> void:
	if _island_one_puzzle == null:
		return
	var style_ivory: Material = _materials.shared_style_ivory
	var style_charcoal: Material = _materials.shared_style_charcoal
	var style_cyan: Material = _materials.shared_style_cyan
	var style_lavender: Material = _materials.shared_style_lavender
	var tree := _island_one_puzzle.get_node_or_null(
		"ScienceArtGarden/CognitiveLightTree") as Node3D
	if tree != null:
		tree.set_meta("design_revision", "unified_low_poly_light_tree_v43")
		tree.set_meta("shared_style_family", "island_one_ivory_cyan_lavender")
		tree.set_meta("quest_object_style_matched", true)
		for candidate in tree.find_children("*", "MeshInstance3D", true, false):
			var part := candidate as MeshInstance3D
			var key := part.name.to_lower()
			if "canopyobservationorbit" in key or "wisdomcrownhalo" in key \
					or "rootgoldencollar" in key:
				part.visible = false
				part.set_meta("retired_for_low_poly_clarity", true)
				continue
			if part.mesh is SphereMesh:
				var faceted := part.mesh.duplicate() as SphereMesh
				faceted.radial_segments = 8
				faceted.rings = 4
				part.mesh = faceted
			if "trunk" in key or "branch" in key or "structuralroot" in key:
				part.material_override = style_ivory
			elif "leaf" in key:
				part.material_override = style_cyan \
					if part.get_index() % 3 != 0 else style_lavender
			elif "blossom" in key:
				part.material_override = style_lavender \
					if part.get_index() % 2 else style_cyan
			elif "signalfibre" in key or "vein" in key or "crownray" in key \
					or "crowncore" in key or "synapsepearl" in key:
				part.material_override = style_cyan
			elif "basin" in key:
				part.material_override = style_ivory

	var controls := _island_one_puzzle.get_node_or_null("PuzzleControls") as Node3D
	if controls == null:
		return
	var styled_count := 0
	for control_candidate in controls.get_children():
		if not control_candidate is Node3D:
			continue
		var control := control_candidate as Node3D
		var model := control.get_node_or_null("HeavenlyQuestInstrument") as Node3D
		if model == null:
			model = control.get_node_or_null("WeightPrismBenchmark") as Node3D
		if model == null:
			continue
		control.set_meta("shared_style_family", "island_one_ivory_cyan_lavender")
		model.set_meta("design_revision", "unified_low_poly_instrument_v43")
		model.set_meta("tree_style_matched", true)
		for mesh_candidate in model.find_children("*", "MeshInstance3D", true, false):
			var mesh_part := mesh_candidate as MeshInstance3D
			var style_key := mesh_part.name.to_lower()
			if "lens" in style_key or "crystal" in style_key or "screen" in style_key \
					or "light" in style_key or "energy" in style_key or "charge" in style_key \
					or "core" in style_key or "prism" in style_key:
				mesh_part.material_override = style_cyan
			elif "card" in style_key or "echo" in style_key or "question" in style_key:
				mesh_part.material_override = style_lavender
			elif "mechanism" in style_key or "valve" in style_key or "gear" in style_key \
					or "axle" in style_key or "pipe" in style_key:
				mesh_part.material_override = style_charcoal
			else:
				mesh_part.material_override = style_ivory
			mesh_part.set_meta("island_one_style_unified", true)
		styled_count += 1
	set_meta("island_one_styled_quest_object_count", styled_count)


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

	# Three signal orbs remain visible for the classifier. Their former long
	# brass supports and torus cradles crossed the tree court as loose gold
	# lines and rings, so the live orbs stand alone.
	var orb_positions := [Vector3(-72, 12.0, 18), Vector3(-75, 15.0, 28), Vector3(-70, 18.0, 38)]
	for orb_index in 3:
		var orb_at: Vector3 = orb_positions[orb_index]
		var orb := _add_sphere(quest, "EchoListeningOrb_%02d" % (orb_index + 1), orb_at,
			Vector3.ONE * 1.25,
			_materials.arrival_glass if orb_index == 0 else (
				_materials.sanctum_lavender_glass if orb_index == 1 else _materials.gold))
		orb.set_meta("echo_index", orb_index)
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

	# Short pulses reveal progress toward the root well without permanent lines
	# across the walking court.
	var route_points := [Vector3(-68, 3.8, 48), Vector3(-80, 3.8, 12),
		Vector3(-84, 3.8, 25), Vector3(-80, 3.8, 38), Vector3(-53, 3.8, 54),
		Vector3(-36, 3.8, 48)]
	for route_index in route_points.size():
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
	# The evidence stations live on the 2.4 m dais, but the former court had no
	# player-scale transition from the incoming bridge. A broad solid ramp now
	# provides a readable entrance beside the scanner without relying on the
	# character controller to climb vertical stair risers.
	var stair_outward := Vector3(-60, 0, -10).normalized()
	var stair_yaw := atan2(-stair_outward.x, -stair_outward.z)
	var ramp_rise := 2.4
	var ramp_span := 24.0
	var ramp_thickness := 1.2
	# The high end overlaps the dais rim at radius 81; centring the ramp on the
	# rim would leave its midpoint below the vertical court wall.
	var ramp_middle := stair_outward * 93.0 + Vector3.UP * ramp_rise * 0.5
	var ramp := _add_box(zone, "ConstellationAccessRamp",
		ramp_middle - Vector3.UP * ramp_thickness * 0.5,
		Vector3(18.0, ramp_thickness, sqrt(ramp_span * ramp_span + ramp_rise * ramp_rise)),
		_materials.celestial_floor, true, stair_yaw)
	ramp.rotation.x = -atan2(ramp_rise, ramp_span)
	(zone.get_node("ConstellationAccessRampCollision") as StaticBody3D).rotation = ramp.rotation
	for radius in [24.0, 48.0, 76.0]:
		var ring := _add_torus(zone, "AstralCourtGiltInlay", Vector3(0, 2.43, 0), radius - 0.10, radius + 0.10, _materials.astral_brass)
		ring.scale.y = 0.22
	for index in 8:
		var angle := TAU * float(index) / 8.0
		_add_sphere(zone, "MemoryNode_%02d" % (index + 1),
			Vector3(cos(angle) * 62, 8 + index % 3 * 5, sin(angle) * 62),
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
	machinery.set_meta("facade_revision", "open_condenser_houses_v2")
	machinery.set_meta("facade_depth_order", "rear recess, framed drum, front sight glass")
	parent.add_child(machinery)
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		var tower_x := float(side) * 67.0
		var tower_z := 18.0
		var rear_frame_z := tower_z - 7.8
		# Each machine is recessed in a monumental oval engine-house frame. The
		# dark teal backing gives the ivory and brass enough depth at game scale.
		# Keep the recess behind the drum.  The former +Z placement put a 22 x 24 m
		# teal sheet in front of the complete machine from the playable garden and
		# reduced both restored houses to flat prototype panels.
		_add_box(machinery, "UpperEngineHouseTealRecess",
			Vector3(tower_x, 12.0, rear_frame_z), Vector3(22.0, 24.0, 1.2),
			_materials.astral_glass, false)
		_add_torus(machinery, "UpperEngineHouseIvoryArch", Vector3(tower_x, 12.0, rear_frame_z + .7),
			11.0, 13.0, _materials.celestial_floor, Vector3(90, 0, 0))
		_add_torus(machinery, "UpperEngineHouseGiltReveal", Vector3(tower_x, 12.0, rear_frame_z + 1.4),
			10.4, 11.0, _materials.astral_brass, Vector3(90, 0, 0))
		for pier_side in [-1.0, 1.0]:
			var frame_x := tower_x + float(pier_side) * 11.7
			_add_tapered_cylinder(machinery, "UpperEngineHousePier", Vector3(frame_x, 8.0, rear_frame_z + .7),
				1.05, 1.55, 15.0, _materials.celestial_floor, 16)
			_add_box(machinery, "UpperEngineHousePierInlay", Vector3(frame_x, 8.0, rear_frame_z + 1.9),
				Vector3(0.7, 9.5, 0.24), _materials.astral_brass, false)
		_add_box(machinery, "UpperEngineHouseCornice", Vector3(tower_x, 24.8, rear_frame_z + .7),
			Vector3(27.0, 1.6, 4.0), _materials.celestial_floor, false)
		_add_box(machinery, "UpperEngineHouseCrownLine", Vector3(tower_x, 25.7, rear_frame_z + 1.1),
			Vector3(28.0, 0.35, 4.4), _materials.astral_brass, false)
		_add_cylinder(machinery, "%sUpperCondenserIvoryDrum" % side_name, Vector3(tower_x, 11.0, tower_z),
			7.2, 21.0, _materials.celestial_floor, false, 32)
		for band_y in [1.2, 7.0, 14.0, 21.2]:
			_add_torus(machinery, "UpperCondenserGiltBand", Vector3(tower_x, band_y, tower_z),
				6.9, 7.7, _materials.astral_brass)
		_add_box(machinery, "UpperCondenserSightGlass",
			Vector3(tower_x, 11.2, tower_z + 7.15), Vector3(3.0, 13.5, 0.50),
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
	# Keep the historical node name for save and organized-tree metadata. The
	# 6,000-part Bio-Data study is superseded by OldestTreeLivingCathedral and
	# must not be constructed just to hide it later in the fused world.
	var retired_tree := Node3D.new()
	retired_tree.name = "MindSparkBioDataTree"
	retired_tree.position = Vector3(0, 0, 18)
	retired_tree.set_meta("production_compatibility_shell", true)
	zone.add_child(retired_tree)
	# Preserve the original gameplay node contract while the active collision is
	# provided by the replacement living cathedral.
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
	_add_cylinder(zone, "StarPedestal", Vector3(0, .6, -32), 18, 1.2, _materials.shared_style_ivory, true, 12)
	_add_cylinder(zone, "StarShrineInset", Vector3(0, 1.24, -32), 14.5, .08,
		_materials.shared_style_charcoal, false, 12)
	_add_cylinder(zone, "StarShrineUpperStep", Vector3(0, 1.6, -32), 7.0, .7,
		_materials.shared_style_ivory, true, 12)
	for shrine_index in 4:
		var angle := PI * .25 + TAU * float(shrine_index) / 4.0
		var at := Vector3(sin(angle) * 13, 0, -32 + cos(angle) * 13)
		_add_cylinder(zone, "StarShrinePier_%02d" % shrine_index, at + Vector3.UP * 2.5,
			1.0, 5.0, _materials.shared_style_ivory, true, 8)
		_add_brick(zone, "StarShrineCrystal_%02d" % shrine_index, at + Vector3.UP * 6.2,
			Bricks.build_crystal(.7, 2.4, .25, 6), _materials.shared_style_cyan)
	# The legacy gold StarCore survived the ring/line cleanup as a bright sphere
	# and read as an unrelated pickup beside the final tree.  Finish this shrine
	# in Island Three's memory palette with one faceted lavender seed and four
	# small cyan satellites.
	var memory_star_at := Vector3(0, 7, -32)
	_add_brick(zone, "OldestTreeMemoryStar", memory_star_at,
		Bricks.build_crystal(2.2, 5.5, .55, 6), _materials.shared_style_lavender)
	for star_shard_index in 4:
		var shard_angle := PI * .25 + TAU * float(star_shard_index) / 4.0
		var shard := _add_brick(zone,
			"OldestTreeMemoryShard_%02d" % (star_shard_index + 1),
			memory_star_at + Vector3(sin(shard_angle) * 4.2,
				float(star_shard_index % 2) * .7 - .35,
				cos(shard_angle) * 4.2),
			Bricks.build_crystal(.48, 1.8, .14, 5), _materials.shared_style_cyan)
		shard.rotation_degrees.z = 28.0 if star_shard_index % 2 == 0 else -28.0
	zone.set_meta("oldest_tree_shrine_palette", "lavender memory seed with cyan satellites; no gold star")
	var return_gate_at := Vector3(78, 0, 48)
	var return_gate_yaw := atan2(return_gate_at.x, return_gate_at.z - 18.0)
	var return_arch := _build_arch(zone, return_gate_at, 30, 30,
		_materials.celestial_floor, "RETURN WORLD GATE")
	return_arch.rotation.y = return_gate_yaw
	return_arch.set_meta("design_revision", "sanctuary_portal_v2")
	return_arch.set_meta("clear_opening_width_m", 25.0)
	return_arch.set_meta("faces_oldest_tree_court", true)
	# The former 52-metre three-box rectangle looked like an unfinished editor
	# proxy beside the Oldest Tree. Layered feet, reveals and a faceted crown turn
	# the same functional threshold into a supported sanctuary portal while the
	# tree remains the district's tallest silhouette.
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0 else "East"
		var x: float = float(side) * 15.0
		_add_brick(return_arch, "ReturnGateSteppedFoot_%s" % side_name,
			Vector3(x, 1.0, 0), Bricks.build_bevel_box(Vector3(8.0, 2.0, 10.0), .35),
			_materials.shared_style_ivory)
		_add_brick(return_arch, "ReturnGateButtress_%s" % side_name,
			Vector3(side * 17.8, 9.0, 1.2),
			Bricks.build_bevel_box(Vector3(4.5, 16.0, 7.0), .42),
			_materials.shared_style_charcoal)
		_add_box(return_arch, "ReturnGateCyanReveal_%s" % side_name,
			Vector3(side * 12.35, 15.0, -3.62), Vector3(.38, 20.0, .22),
			_materials.shared_style_cyan)
		_add_brick(return_arch, "ReturnGateCrownShoulder_%s" % side_name,
			Vector3(side * 9.0, 32.0, 0),
			Bricks.build_bevel_box(Vector3(12.5, 2.6, 8.0), .38),
			_materials.shared_style_ivory)
	_add_box(return_arch, "ReturnGateThreshold", Vector3(0, .35, 0),
		Vector3(24.0, .7, 9.0), _materials.shared_style_charcoal, true)
	_add_brick(return_arch, "ReturnGateCrownCrystal", Vector3(0, 36.0, -.6),
		Bricks.build_crystal(1.6, 5.5, .45, 6), _materials.shared_style_cyan)
	_return_gate = WorldGateScene.instantiate() as MindSparkWorldGate
	_return_gate.name = "ReturnToArtCastleWorldGate"
	_return_gate.position = return_gate_at + Vector3.UP
	_return_gate.rotation.y = return_gate_yaw
	_return_gate.destination_world_local = return_destination_world_local
	_return_gate.prompt_text = "Q • RETURN TO MIND SPARK TRAIN STATION"
	_return_gate.gate_enabled = true
	_return_gate.set_meta("travel_role", "island_three_to_mind_spark_train_station")
	_return_gate.set_meta("destination_landmark", "Mind Spark Train Station")
	_return_gate.set_meta("always_available_return", true)
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
	# Align the epilogue station with the actual Oldest Tree base. The previous
	# direction targeted the sanctuary zone origin while the tree stands 18 m
	# north of it, so the operator camera cut diagonally through every right-hand
	# grove branch instead of looking down the open nave.
	var oldest_tree_local := Vector3(0, 3, 18)
	var tree_story_direction := (ZONES[5].position + oldest_tree_local
		- ZONES[4].position) * Vector3(1, 0, 1)
	tree_story_direction = tree_story_direction.normalized()
	var sanctuary_incoming := -tree_story_direction
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
			object.position = oldest_tree_local + sanctuary_incoming * 79.0
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
	campus.set_meta("design_revision", "landmark_hierarchy_v15_clear_reflection_skyline")
	campus.set_meta("architectural_language",
		"Island One and Two layered ivory terraces, garden arcades, charcoal machinery, cyan and lavender light, faceted living trees")
	campus.set_meta("matches_previous_islands", true)
	campus.set_meta("physical_island", 3)
	# Island Three contains many deliberate two- and three-piece repeating civic
	# details. They share compact court cells and can be merged safely at a lower
	# threshold without expanding the batching policy across Islands One or Two.
	campus.set_meta("static_render_merge_min_group", 2)
	# The complete civic sanctuary spans two adjoining districts but its static
	# architecture is viewed as one composition. One island-scale Web cell keeps
	# equivalent materials together instead of submitting four adjacent batches
	# that are all visible from either district. Island streaming still retires
	# the sanctuary as a unit when the player leaves it.
	campus.set_meta("static_render_merge_cell_size", 384.0)
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
		legacy_oldest_tree.process_mode = Node.PROCESS_MODE_DISABLED
		for old_body in legacy_oldest_tree.find_children("*", "CollisionObject3D", true, false):
			(old_body as CollisionObject3D).collision_layer = 0
			(old_body as CollisionObject3D).collision_mask = 0
		legacy_oldest_tree.set_meta("retired_by", "OldestTreeLivingCathedral")
	# Retire the old five-storey violet vortex. It belonged to the earlier effect
	# study and visually overwhelmed the civic architecture and quest stations.
	for legacy_ring in storm_zone.find_children("LayeredStormRing_*", "MeshInstance3D", true, false):
		legacy_ring.visible = false
		legacy_ring.set_meta("retired_by", "IslandThreeCivicSanctuary")
		legacy_ring.mesh = null
		legacy_ring.material_override = null
		legacy_ring.set_meta("retired_geometry_purged", true)
	var legacy_arena := storm_zone.get_node_or_null("BossArenaCollision") as MeshInstance3D
	if legacy_arena != null:
		legacy_arena.material_override = _materials.celestial_floor
		# The legacy boss disc stood two metres above the shared floor, burying
		# the new paths, planters and compass. Keep its mass level with the deck.
		legacy_arena.position.y = -1.0
		var arena_body := storm_zone.get_node_or_null("BossArenaCollisionCollision") as Node3D
		if arena_body != null:
			arena_body.position.y = -1.0
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
		_materials.island_three_paving_base, false, 48)
	_add_cylinder(campus, "IslandThreeSanctuaryDeck",
		Vector3(sanctuary_origin.x, sanctuary_y - .11, sanctuary_origin.z),
		136.0, .18, _materials.island_three_paving_base, false, 48)
	var perimeter_repair := geometry.get_node_or_null("IslandThreePerimeterRepairs") as Node3D
	if perimeter_repair != null:
		# Keep the authored ivory, gold-scrollwork and warm-lantern materials from
		# the same railing kit used on Islands One and Two. Earlier code flattened
		# every surface to ivory, which erased the shared architectural language.
		for imported_railing in perimeter_repair.find_children("*", "MeshInstance3D", true, false):
			(imported_railing as MeshInstance3D).set_meta(
				"island_three_rail_restyled", "shared_ivory_gold_lantern_kit")
		perimeter_repair.set_meta("barrier_style", "island_one_two_civic_railing")
		perimeter_repair.set_meta("continuous_exposed_edge_coverage", true)
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
	_build_island_three_arrival_processional(campus, arrival_center,
		arrival_direction)

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
	var garden_angles_degrees := [45.0, 150.0, 240.0, 340.0]
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
	basilica.set_meta("design_revision", "living_grove_processional_v6_crowned_arcade")
	basilica.set_meta("open_arrival_fraction", .40)
	basilica.set_meta("paired_canopy_count", 8)
	basilica.set_meta("visible_fork_count", 8)
	campus.add_child(basilica)
	var oldest_tree_base := Vector3(
		sanctuary_origin.x, sanctuary_y, sanctuary_origin.z + 18.0)
	var to_sanctuary := oldest_tree_base - arena_center
	to_sanctuary.y = 0.0
	var direction: Vector3 = to_sanctuary.normalized()
	var side_axis := Vector3(direction.z, 0, -direction.x)
	var promenade_start := arena_center + direction * 60.0
	var promenade_end := oldest_tree_base
	basilica.set_meta("story_axis_start", promenade_start)
	basilica.set_meta("story_axis_end", promenade_end)
	basilica.set_meta("reflection_camera_axis_clear", true)
	_add_island_three_lane(basilica, "IvoryWisdomNave", promenade_start,
		promenade_end, 14.0, _materials.celestial_floor)
	# Four broad living bays replace the former line of thin white poles and long
	# brass cornices. Thick bark trunks frame an 18 m clear nave without placing a
	# twelve-trunk screen in front of the reflection quest and Oldest Tree.
	for bay_index in 4:
		# Start beyond the normal player camera instead of placing the first crown
		# directly above it; the four bays then lead evenly into the apse.
		var progress := .42 + float(bay_index) * .14
		var bay_center := promenade_start.lerp(promenade_end, progress)
		for side in [-1.0, 1.0]:
			var side_name := "Left" if side < 0 else "Right"
			var trunk_at := bay_center + side_axis * float(side) * 14.0
			_add_cylinder(basilica,
				"WisdomGroveTrunk_%02d_%s" % [bay_index + 1, side_name],
				trunk_at + Vector3.UP * 4.8, 1.05, 9.6,
				_materials.island_three_hero_bark, true, 9)
			_add_tapered_cylinder(basilica,
				"WisdomGroveBarkFlare_%02d_%s" % [bay_index + 1, side_name],
				trunk_at + Vector3.UP * 1.9, .62, 1.28, 3.8,
				_materials.island_three_hero_bark_highlight, 9)
			_add_cylinder(basilica,
				"WisdomGroveIvoryCollar_%02d_%s" % [bay_index + 1, side_name],
				trunk_at + Vector3.UP * .65, 1.48, .48,
				_materials.shared_style_ivory, false, 10)
			var crown_at := trunk_at + Vector3.UP * (9.8 + float(bay_index % 2) * .6)
			var canopy := _add_sphere(basilica,
				"WisdomGroveCanopy_%02d_%s" % [bay_index + 1, side_name],
				crown_at + side_axis * float(side) * 1.0,
				Vector3(7.6, 3.8, 6.6),
				_island_three_canopy_material(bay_index + (0 if side < 0 else 2)))
			(canopy.mesh as SphereMesh).radial_segments = 7
			(canopy.mesh as SphereMesh).rings = 4
			_add_cable_between(basilica,
				"WisdomGroveBranch_%02d_%s" % [bay_index + 1, side_name],
				trunk_at + Vector3.UP * 6.6,
				crown_at - side_axis * float(side) * 1.2,
				.68, .28, _materials.island_three_hero_bark, 9)
			var secondary_at := crown_at + direction \
				* (-3.4 if (bay_index + (0 if side < 0 else 1)) % 2 == 0 else 3.4) \
				- side_axis * float(side) * 1.4 + Vector3.UP * .6
			_add_cable_between(basilica,
				"WisdomGroveFork_%02d_%s" % [bay_index + 1, side_name],
				trunk_at + Vector3.UP * 7.0, secondary_at - Vector3.UP * 1.0,
				.56, .22, _materials.island_three_hero_bark_highlight, 8)
			var secondary_canopy := _add_sphere(basilica,
				"WisdomGroveCanopySecondary_%02d_%s" % [bay_index + 1, side_name],
				secondary_at, Vector3(5.2, 2.8, 4.8),
				_island_three_canopy_material(bay_index + (1 if side < 0 else 3)))
			(secondary_canopy.mesh as SphereMesh).radial_segments = 7
			(secondary_canopy.mesh as SphereMesh).rings = 4
		_add_brick(basilica, "WisdomGroveMemoryLight_%02d" % (bay_index + 1),
			bay_center + Vector3.UP * 12.8,
			Bricks.build_crystal(.48, 1.8, .12, 6),
			_materials.shared_style_cyan if bay_index % 2 == 0 \
			else _materials.shared_style_lavender)
	basilica.set_meta("living_grove_bay_count", 4)
	basilica.set_meta("clear_nave_width_m", 25.0)

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
		reflection_court.set_meta("quest_architecture", "open living-root oratory")
		reflection_court.set_meta("design_revision", "rootbound_grove_pavilion_v6_wide_aperture")
		reflection_court.set_meta("clear_story_entrance_m", 38.0)
		reflection_court.set_meta("entry_aperture_degrees", 120.0)
		reflection_court.set_meta("clear_inner_court_radius_m", 24.0)
		reflection_court.set_meta("low_poly_landmark", true)
		basilica.add_child(reflection_court)
		_build_island_three_shared_instrument(reflection_court, mirror_at, -direction,
			_materials.shared_style_lavender, "route")
		_add_cylinder(reflection_court, "ReflectionPool", mirror_at + Vector3.UP * .04,
			13.0, .12, _materials.island_crystal_facet_dark, false, 12)
		var entry_direction := -direction
		var entry_angle := atan2(entry_direction.x, entry_direction.z)
		for apse_index in 6:
			# Six roots occupy a 240-degree rear arc, leaving a deliberate 120-degree
			# aperture toward the promenade. The former evenly spaced ring technically
			# left a route, but its two front crowns visually pinched the quest object.
			var rear_arc_step := deg_to_rad(240.0) / 5.0
			var apse_angle := entry_angle + PI / 3.0 \
				+ rear_arc_step * float(apse_index)
			var radial := Vector3(sin(apse_angle), 0, cos(apse_angle))
			var tangent := Vector3(radial.z, 0, -radial.x)
			var apse_at := mirror_at + radial * 29.0
			var root_shoulder := mirror_at + radial * 27.0 \
				+ tangent * (-.8 if apse_index % 2 == 0 else .8) \
				+ Vector3.UP * (8.5 + float(apse_index % 2))
			var root_tip := mirror_at + radial * 24.5 \
				+ tangent * (-1.4 if apse_index % 2 == 0 else 1.4) \
				+ Vector3.UP * (14.5 + float(apse_index % 2))
			# The former straight dark cylinders read as six loose rectangular
			# prototype blocks from the promenade camera. A broad faceted root flare
			# catches the warm light and flows into the rib, while a slightly slimmer
			# primitive collider keeps the same solid player boundary.
			_add_tapered_cylinder(reflection_court,
				"ReflectionRootFoot_%02d" % (apse_index + 1),
				apse_at + Vector3.UP * .42, .62, 1.50, .84,
				_materials.island_three_hero_bark_highlight, 9)
			var root_body := StaticBody3D.new()
			root_body.name = "ReflectionRootFoot_%02dCollision" % (apse_index + 1)
			root_body.position = apse_at + Vector3.UP * .35
			root_body.set_meta("mass_class", "infinite_static_mass")
			root_body.set_meta("collision_role", "simplified tapered root flare")
			var root_shape_node := CollisionShape3D.new()
			var root_shape := CylinderShape3D.new()
			root_shape.radius = .95
			root_shape.height = .7
			root_shape_node.shape = root_shape
			root_body.add_child(root_shape_node)
			reflection_court.add_child(root_body)
			_add_cable_between(reflection_court,
				"ReflectionRootRib_%02d" % (apse_index + 1), apse_at, root_shoulder,
				1.05, .55, _materials.island_three_hero_bark, 10)
			_add_cable_between(reflection_court,
				"ReflectionRootCrown_%02d" % (apse_index + 1), root_shoulder, root_tip,
				.55, .24, _materials.island_three_hero_bark_highlight, 8)
			var root_shoulder_joint := _add_sphere(reflection_court,
				"ReflectionRootShoulder_%02d" % (apse_index + 1), root_shoulder,
				Vector3(.55, .62, .55), _materials.shared_style_ivory)
			root_shoulder_joint.set_meta("editable_component", true)
			_add_cable_between(reflection_court,
				"ReflectionCyanVein_%02d" % (apse_index + 1),
				root_shoulder + radial * .30, root_tip + radial * .18, .16, .08,
				_materials.island_cyan, 8)
			var reflection_canopy := _add_sphere(reflection_court,
				"ReflectionCanopyMass_%02d" % (apse_index + 1),
				root_tip + radial * 2.5 + Vector3.UP * 1.8,
				Vector3(5.2, 2.8, 4.6),
				_island_three_canopy_material(apse_index + 2))
			# Preserve each authored crown as a named pavilion component.  Without
			# this marker the global Web geometry batcher folds the two sage crowns
			# into a shared MultiMesh and removes their semantic scene nodes.
			reflection_canopy.set_meta("editable_component", true)
			(reflection_canopy.mesh as SphereMesh).radial_segments = 7
			(reflection_canopy.mesh as SphereMesh).rings = 4
			_add_brick(reflection_court, "ReflectionMarker_%02d" % (apse_index + 1),
				mirror_at + Vector3(sin(apse_angle) * 17.0, 2.2,
					cos(apse_angle) * 17.0),
				Bricks.build_crystal(.75, 4.4, .2, 6),
				_materials.arrival_glass if apse_index % 2 == 0 \
				else _materials.sanctum_lavender_glass)
		_add_sphere(reflection_court, "ReflectionMemorySeed",
			mirror_at + Vector3.UP * 16.8, Vector3(1.6, 2.8, 1.6),
			_materials.sanctum_lavender_glass)
		reflection_court.set_meta("root_pavilion_bay_count", 6)
		var reflection_completion := Node3D.new()
		reflection_completion.name = "CompletionStateVisuals"
		reflection_completion.set_meta("preserve_authored_nodes", true)
		reflection_court.add_child(reflection_completion)
		_add_cylinder(reflection_completion, "AwakenedReflectionWater",
			mirror_at + Vector3.UP * .13, 11.5, .10, _materials.arrival_glass, false, 12)
		var retired_overlap_trees := _retire_legacy_reflection_apron_trees(
			mirror.global_position, 24.0)
		reflection_court.set_meta("clear_apron_radius_m", 24.0)
		reflection_court.set_meta("retired_overlapping_legacy_trees", retired_overlap_trees)

	_build_oldest_tree_living_cathedral(campus,
		Vector3(sanctuary_origin.x, sanctuary_y, sanctuary_origin.z + 18.0))
	_build_island_three_matched_environment(campus, arena_center,
		Vector3(sanctuary_origin.x, sanctuary_y, sanctuary_origin.z),
		arrival_center, anchor_offsets, basin_at)
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
	_remove_island_three_route_barrier(geometry)
	_unify_island_three_tree_and_quest_style(campus)
	_finish_island_three_masonry(campus, geometry)
	for object in _objects:
		if int(object.get_meta("physical_island", 0)) != 3:
			continue
		if not object.completed.is_connected(_on_island_three_object_completed):
			object.completed.connect(_on_island_three_object_completed)
	_refresh_island_three_completion_visuals()
	set_meta("island_three_design", "Island One and Two-matched layered low-poly sanctuary with five distinct quest landmarks")
	set_meta("island_three_masterplan",
		"arrival portico > arcaded storm gardens > three unique storm instruments > rain observatory > wisdom basilica > terraced living tree cathedral")


func _retire_legacy_reflection_apron_trees(center_global: Vector3,
		clear_radius: float) -> int:
	# The organized biome is built before the civic sanctuary. One of its generic
	# saplings previously landed inside the authored Reflection Court, hiding the
	# route instrument behind an unrelated trunk and adding invisible collision to
	# the promised clear apron. Keep the wider grove, but retire any legacy tree
	# whose root is actually inside this court.
	var retired := 0
	for candidate in find_children("MindSparkGroveTree_*", "Node3D", true, false):
		var tree := candidate as Node3D
		var offset := tree.global_position - center_global
		if Vector2(offset.x, offset.z).length() > clear_radius:
			continue
		tree.visible = false
		tree.process_mode = Node.PROCESS_MODE_DISABLED
		tree.set_meta("retired_for_reflection_apron", true)
		for body_value in tree.find_children("*", "CollisionObject3D", true, false):
			var body := body_value as CollisionObject3D
			body.collision_layer = 0
			body.collision_mask = 0
			body.set_meta("retired_for_reflection_apron", true)
		retired += 1
	return retired


func _remove_island_three_route_barrier(geometry: Node3D) -> void:
	# Island Three is an open sanctuary transition. Retain the save-state controller
	# node for compatibility, but remove every visible and physical gate component.
	var removed_count := 0
	for candidate in geometry.find_children("QuestGate_4", "AnimatableBody3D", true, false):
		var gate := candidate as AnimatableBody3D
		var barrier := gate.get_node_or_null("Barrier") as MeshInstance3D
		if barrier != null:
			barrier.visible = false
			barrier.set_meta("island_three_purple_barrier_removed", true)
			removed_count += 1
		var collision := gate.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision != null:
			collision.disabled = true
		gate.visible = false
		gate.set_meta("physical_barrier_removed", true)
		gate.set_meta("prototype_violet_barrier_retired", true)
		gate.set_meta("route_remains_open", true)
		gate.set_meta("island_three_gate_removed", true)
	set_meta("island_three_route_barriers_removed", removed_count)


func _unify_island_three_tree_and_quest_style(campus: Node3D) -> void:
	# Apply the same classification used by Island One's production instruments
	# to the complete Island Three kit and its five authoritative quest objects.
	for candidate in campus.find_children("*", "MeshInstance3D", true, false):
		var part := candidate as MeshInstance3D
		var key := part.name.to_lower()
		if "centralrainneedle" in key:
			part.material_override = _materials.shared_style_charcoal
		elif "raincollectorrib" in key:
			part.material_override = _materials.shared_style_ivory
		elif "raincatchmentbed" in key:
			part.material_override = _materials.celestial_floor
		elif "raincatchmentsoil" in key:
			part.material_override = _materials.island_three_earth
		elif "raingardenstem" in key:
			part.material_override = _materials.island_three_hero_bark
		elif "raingardenplanting" in key:
			# Keep the deliberately varied sage/moss material assigned at build time.
			pass
		elif "lenscitadelpodium" in key or "lenscivicbuttress" in key \
				or "lensinstrumentsupport" in key:
			# The lens name identifies the instrument, not its structural material.
			# Keep its plinths, buttresses and load-bearing uprights in the shared
			# ivory masonry kit instead of turning them into cyan arrival barriers.
			part.material_override = _materials.shared_style_ivory
		elif "lenssupportjoint" in key or "lenssightbrace" in key:
			part.material_override = _materials.shared_style_charcoal
		elif key in ["rainpool", "raincrystalreservoir", "facetedraindome"] \
				or "rainvane" in key or "rainchannel" in key \
				or "harvestedrainwater" in key or "capturedrainstream" in key \
				or "observatorywaterfall" in key:
			part.material_override = _materials.rain_glass
		elif "terrace" in key or "ivory" in key or "tower" in key \
				or "buttress" in key or "archivefin" in key or "pier" in key:
			part.material_override = _materials.shared_style_ivory
		elif "charcoal" in key or "mechanism" in key or "strut" in key \
				or "lintel" in key or "undercroft" in key or "foot" in key:
			part.material_override = _materials.shared_style_charcoal
		elif "lavender" in key or "resonance" in key or "reflectionmemory" in key:
			part.material_override = _materials.shared_style_lavender
		elif "cyan" in key or "crystal" in key or "glass" in key or "lens" in key \
				or "glyph" in key or "light" in key or "channel" in key \
				or "vane" in key or "vein" in key or "rain" in key:
			part.material_override = _materials.shared_style_cyan
		part.set_meta("island_one_style_unified", true)

	var styled_objects := 0
	for object in _objects:
		if int(object.get_meta("physical_island", 0)) != 3:
			continue
		var visual_root := object.get_node_or_null("VisualRoot") as Node3D
		if visual_root == null:
			continue
		visual_root.scale = Vector3.ONE * 1.25
		object.set_meta("shared_style_family", "island_one_ivory_cyan_lavender")
		object.set_meta("island_one_scale_matched", true)
		for mesh_candidate in visual_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_part := mesh_candidate as MeshInstance3D
			var style_key := mesh_part.name.to_lower()
			if "crystal" in style_key or "energy" in style_key or "light" in style_key \
					or "core" in style_key or "rain" in style_key or "water" in style_key:
				mesh_part.material_override = _materials.shared_style_cyan
			elif "storm" in style_key or "shield" in style_key or "echo" in style_key \
					or "reflection" in style_key \
					or "memory" in style_key:
				mesh_part.material_override = _materials.shared_style_lavender
			elif "mechanism" in style_key or "axle" in style_key or "strut" in style_key \
					or "pipe" in style_key or "base" in style_key:
				mesh_part.material_override = _materials.shared_style_charcoal
			else:
				mesh_part.material_override = _materials.shared_style_ivory
			mesh_part.set_meta("island_one_style_unified", true)
		styled_objects += 1
	campus.set_meta("island_one_style_matched_quest_objects", styled_objects)


func _build_island_three_arrival_portico(parent: Node3D, center: Vector3,
		forward: Vector3) -> void:
	var portico := Node3D.new()
	portico.name = "StormworksArrivalPortico"
	portico.set_meta("purpose", "low-poly cyan-glass threshold from Island Two")
	portico.set_meta("clear_opening_m", 24.0)
	portico.set_meta("prototype_fidelity", "gameplay_adapted")
	portico.set_meta("architectural_finish", "layered_ivory_gatehouse_with_inset_aether_glass")
	portico.set_meta("shared_detail_language", "island_one_plinths_island_two_clerestory")
	portico.set_meta("design_revision", "faceted_pointed_gateway_v3_broad_paving")
	portico.set_meta("arrival_silhouette", "asymmetric_towers_with_segmented_ivory_arch")
	portico.set_meta("route_surface", "three broad flush ivory paving courses; no centre stripe")
	parent.add_child(portico)
	var yaw := atan2(forward.x, forward.z)
	var side := Vector3(forward.z, 0, -forward.x)
	_add_box(portico, "IvoryArrivalTerrace", center - Vector3.UP * .12,
		Vector3(38.0, .28, 34.0), _materials.celestial_floor, true, yaw)
	# The former narrow charcoal strip stopped abruptly at both ends of the
	# terrace and read as unfinished guide geometry from the production arrival
	# camera. Three broad flush courses now continue the masonry rhythm through
	# the opening without drawing a route line across the player's path.
	for paving_index in 3:
		_add_box(portico, "ArrivalPavingCourse_%02d" % (paving_index + 1),
			center + forward * float(paving_index - 1) * 9.0 + Vector3.UP * .045,
			Vector3(18.0, .045, 7.2), _materials.shared_style_ivory, false, yaw)
	for lateral_side in [-1.0, 1.0]:
		var side_name := "South" if lateral_side < 0 else "North"
		var tower_height := 17.0 if lateral_side < 0 else 21.0
		var tower_at := center + side * float(lateral_side) * 15.5
		_add_box(portico, "ArrivalTower%s" % side_name,
			tower_at + Vector3.UP * (tower_height * .5), Vector3(7.0, tower_height, 8.0),
			_materials.celestial_floor, true, yaw)
		# Layer the collision-backed tower mass with the same readable plinth,
		# reveal and crown hierarchy used by the first two islands. These trims are
		# shallow, non-colliding facade pieces, so the 24 m route remains exact.
		_add_box(portico, "ArrivalPlinth%s" % side_name,
			tower_at + Vector3.UP * .65, Vector3(8.8, 1.3, 9.8),
			_materials.shared_style_charcoal, false, yaw)
		_add_box(portico, "ArrivalLowerCourse%s" % side_name,
			tower_at + Vector3.UP * 1.55, Vector3(8.1, .65, 9.1),
			_materials.shared_style_ivory, false, yaw)
		for band_index in 2:
			_add_box(portico, "ArrivalReveal%s_%02d" % [side_name, band_index + 1],
				tower_at + Vector3.UP * (5.5 + float(band_index) * 6.0),
				Vector3(7.45, .34, 8.45), _materials.shared_style_charcoal,
				false, yaw)
		_add_box(portico, "ArrivalGlass%s" % side_name,
			tower_at - side * float(lateral_side) * 3.56 + Vector3.UP * (tower_height * .54),
			Vector3(.28, tower_height * .55, 4.2), _materials.arrival_glass, false, yaw)
		_add_box(portico, "ArrivalGlassFrame%s" % side_name,
			tower_at - side * float(lateral_side) * 3.72 + Vector3.UP * (tower_height * .54),
			Vector3(.18, tower_height * .68, 5.25), _materials.shared_style_charcoal,
			false, yaw)
		_add_box(portico, "ArrivalGlassFace%s" % side_name,
			tower_at - side * float(lateral_side) * 3.83 + Vector3.UP * (tower_height * .54),
			Vector3(.12, tower_height * .54, 4.05), _materials.arrival_glass,
			false, yaw)
		_add_box(portico, "ArrivalCrownCourse%s" % side_name,
			tower_at + Vector3.UP * (tower_height + .55), Vector3(8.7, 1.1, 9.7),
			_materials.shared_style_ivory, false, yaw)
		_add_box(portico, "ArrivalCrownReveal%s" % side_name,
			tower_at + Vector3.UP * (tower_height + 1.25), Vector3(7.9, .32, 8.9),
			_materials.shared_style_charcoal, false, yaw)
		# Two facade pilasters break the old single-box tower silhouette into the
		# same base / shaft / crown rhythm used by the observatory architecture.
		# They remain decorative and sit against the tower face, outside the clear
		# bridge opening and player route.
		var facade_at := tower_at - forward * 4.12
		for pilaster_index in 2:
			var pilaster_side := -1.0 if pilaster_index == 0 else 1.0
			var pilaster_at := facade_at + side * pilaster_side * 2.35
			_add_cylinder(portico,
				"ArrivalPilasterFoot%s_%02d" % [side_name, pilaster_index + 1],
				pilaster_at + Vector3.UP * .72, .82, 1.44,
				_materials.shared_style_charcoal, false, 8)
			_add_tapered_cylinder(portico,
				"ArrivalPilasterShaft%s_%02d" % [side_name, pilaster_index + 1],
				pilaster_at + Vector3.UP * (tower_height * .48), .48, .66,
				tower_height - 4.0, _materials.shared_style_ivory, 8)
			_add_cylinder(portico,
				"ArrivalPilasterCapital%s_%02d" % [side_name, pilaster_index + 1],
				pilaster_at + Vector3.UP * (tower_height - 1.35), .92, .82,
				_materials.shared_style_ivory, false, 8)
		for spire_index in 2:
			var spire_at := tower_at + forward * (-2.1 if spire_index == 0 else 2.1) \
				+ Vector3.UP * (tower_height + 3.1)
			_add_tapered_cylinder(portico,
				"ArrivalSpire%s_%02d" % [side_name, spire_index + 1], spire_at,
				.10, 1.3, 6.0, _materials.arrival_glass, 6)
	# Keep the named BoxMesh as a thin structural tie while a six-piece pointed
	# arch supplies the finished silhouette. Straight faceted voussoirs avoid a
	# torus/ring and leave the exact 24 m ground opening unobstructed.
	_add_box(portico, "AetherArrivalArch", center + Vector3.UP * 14.1,
		Vector3(24.0, .58, 1.5), _materials.shared_style_ivory, false, yaw)
	_add_box(portico, "ArrivalLintelUndersill", center + Vector3.UP * 13.72,
		Vector3(21.5, .18, 1.72), _materials.shared_style_charcoal, false, yaw)
	var arch_points: Array[Vector3] = [
		center - side * 12.0 + Vector3.UP * 14.25,
		center - side * 8.0 + Vector3.UP * 17.25,
		center - side * 4.0 + Vector3.UP * 19.25,
		center + Vector3.UP * 20.15,
		center + side * 4.0 + Vector3.UP * 19.25,
		center + side * 8.0 + Vector3.UP * 17.25,
		center + side * 12.0 + Vector3.UP * 14.25,
	]
	for arch_index in arch_points.size() - 1:
		_add_beam_between(portico,
			"FacetedIvoryArchOrder_%02d" % (arch_index + 1),
			arch_points[arch_index], arch_points[arch_index + 1], 1.42,
			_materials.shared_style_ivory)
	# Short stepped shoulders join the arch to each tower without recreating the
	# previous long horizontal bar across the skyline.
	_add_box(portico, "ArrivalUpperLintel", center - side * 9.7 + Vector3.UP * 16.2,
		Vector3(5.4, .72, 2.15), _materials.shared_style_ivory, false, yaw)
	_add_box(portico, "ArrivalUpperLintelMirror", center + side * 9.7 + Vector3.UP * 16.2,
		Vector3(5.4, .72, 2.15), _materials.shared_style_ivory, false, yaw)
	for clerestory_index in 3:
		var inset_offset := float(clerestory_index - 1) * 5.7
		_add_box(portico, "ArrivalClerestory_%02d" % (clerestory_index + 1),
			center + side * inset_offset + Vector3.UP * 18.08,
			Vector3(2.3, .44, 2.16), _materials.arrival_glass, false, yaw)
	_add_tapered_cylinder(portico, "PorticoCrownPedestal",
		center + Vector3.UP * 20.72, .78, 1.28, 2.08,
		_materials.shared_style_ivory, 8)
	_add_brick(portico, "PorticoAetherCrown", center + Vector3.UP * 22.0,
		Bricks.build_crystal(1.8, 5.5, .4, 6), _materials.island_cyan)


func _build_island_three_arrival_processional(parent: Node3D, start: Vector3,
		forward: Vector3) -> void:
	## Turn the long bridge-to-court apron into a sequence of inhabited garden
	## rooms. The paired beds borrow Island One's low planting courts and Island
	## Two's lantern rhythm while preserving a broad, obstacle-free boss sightline.
	var processional := Node3D.new()
	processional.name = "StormworksArrivalGardenProcessional"
	processional.set_meta("design_reference",
		"Island One listening gardens + Island Two observatory lantern courts")
	processional.set_meta("garden_pair_count", 3)
	processional.set_meta("clear_central_aisle_m", 27.0)
	processional.set_meta("collision_backed", true)
	processional.set_meta("design_revision", "mature_canopy_grounded_lanterns_v2")
	processional.set_meta("arrival_view_readability", "continuous_tree_crowns_no_floating_orbs")
	processional.set_meta("grounded_lantern_count", 6)
	parent.add_child(processional)
	var route_forward := forward.normalized()
	var side_axis := Vector3(route_forward.z, 0, -route_forward.x)
	var yaw := atan2(route_forward.x, route_forward.z)
	var stations := [34.0, 68.0, 102.0]
	for station_index in stations.size():
		for side_value in [-1.0, 1.0]:
			var side_name := "Left" if side_value < 0 else "Right"
			# Stagger the middle-right bed toward the court so the existing direct
			# west-garden bypass remains a straight, readable player route.
			var station_distance: float = float(stations[station_index])
			if station_index == 1 and side_value > 0:
				station_distance += 13.0
			var bed_center := start + route_forward * station_distance \
				+ side_axis * float(side_value) * 19.5
			var prefix := "ArrivalGarden_%02d_%s" % [station_index + 1, side_name]
			_add_box(processional, "%sIvoryBed" % prefix,
				bed_center + Vector3.UP * .45, Vector3(12.0, .9, 7.0),
				_materials.shared_style_ivory, true, yaw)
			_add_box(processional, "%sRecessedSoil" % prefix,
				bed_center + Vector3.UP * .92, Vector3(10.6, .10, 5.7),
				_materials.island_three_earth, false, yaw)
			for shrub_index in 3:
				var shrub_at := bed_center + route_forward * float(shrub_index - 1) * 2.0 \
					+ side_axis * float(side_value) * .8 + Vector3.UP * 1.35
				var shrub := _add_sphere(processional,
					"%sSagePlanting_%02d" % [prefix, shrub_index + 1], shrub_at,
					Vector3(1.75, .85, 1.35),
					_island_three_canopy_material(station_index + shrub_index + 1))
				(shrub.mesh as SphereMesh).radial_segments = 7
				(shrub.mesh as SphereMesh).rings = 3
			var tree_base := bed_center + route_forward * (-1.6 if station_index % 2 == 0 else 1.6) \
				+ side_axis * float(side_value) * 1.2 + Vector3.UP * .92
			# The former 0.62-scale saplings collapsed into isolated spheres and
			# wire-like branches in the playable arrival view. These are mature
			# garden trees like the framed courts on Islands 1 and 2. Their trunks
			# remain inside the solid beds and the 27 m central aisle stays clear.
			_build_island_three_garden_tree(processional,
				"%sFacetedTree" % prefix, tree_base, .92 + float(station_index) * .12,
				station_index * 2 + (0 if side_value < 0 else 1))
			var pier_at := bed_center - route_forward * 2.3 \
				- side_axis * float(side_value) * 4.4
			_add_cylinder(processional, "%sLanternFoot" % prefix,
				pier_at + Vector3.UP * .28, .88, .56,
				_materials.shared_style_charcoal, true, 9)
			_add_cylinder(processional, "%sIvoryLanternPier" % prefix,
				pier_at + Vector3.UP * 3.25, .52, 5.6,
				_materials.shared_style_ivory, true, 9)
			_add_cylinder(processional, "%sLanternCap" % prefix,
				pier_at + Vector3.UP * 6.12, .76, .34,
				_materials.shared_style_charcoal, false, 9)
			_add_brick(processional, "%sCyanLantern" % prefix,
				pier_at + Vector3.UP * 7.05,
				Bricks.build_crystal(.62, 1.85, .18, 6),
				_materials.shared_style_cyan)


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
		Vector3(3.1, 2.1, 3.1), _materials.island_three_sage)
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
	# These routes sit over the already-solid fused deck. Keep their thin top
	# face coplanar with that deck so a walking capsule meets no curb at entry.
	center.y = minf(start.y, finish.y) - .27
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


func _build_island_three_shared_instrument(parent: Node3D, center: Vector3,
		operator_direction: Vector3, accent: Material, mini_game_mode: String) -> void:
	# The authoritative QuestObjectBase model already supplies the machine body,
	# state feedback and save-backed interaction. Earlier revisions placed a second
	# complete cabinet in front of it, producing two overlapping consoles at every
	# Island 3 landmark. Keep only a collision volume around the real machine and
	# inset one mode-specific crest into its existing circular face.
	var instrument := Node3D.new()
	instrument.name = "IslandOneStyleQuestInstrument"
	instrument.set_meta("shared_style_family", "island_one_ivory_cyan_lavender")
	instrument.set_meta("design_revision", "mode_specific_operator_controls_v12_identity_frames")
	instrument.set_meta("mini_game_identity", mini_game_mode)
	instrument.set_meta("visual_role", "mode crest overlay on authoritative quest object")
	instrument.set_meta("duplicate_cabinet_removed", true)
	parent.add_child(instrument)
	var facing := operator_direction.normalized()
	if facing.is_zero_approx():
		facing = Vector3.FORWARD
	var yaw := atan2(facing.x, facing.z)
	var collision_body := StaticBody3D.new()
	collision_body.name = "AuthoritativeQuestObjectCollision"
	collision_body.position = center + Vector3.UP * 3.6
	collision_body.rotation.y = yaw
	collision_body.set_meta("mass_class", "infinite_static_mass")
	collision_body.set_meta("collision_role", "authoritative quest machine envelope")
	var collision_shape := CollisionShape3D.new()
	var collision_box := BoxShape3D.new()
	collision_box.size = Vector3(10.0, 7.2, 5.2)
	collision_shape.shape = collision_box
	collision_body.add_child(collision_shape)
	instrument.add_child(collision_body)

	# The three Warden machines and the reflection mirror use the tall memory-style
	# display, while Rain Harvest's authoritative basin is only five metres high.
	# Mounting every crest at the tall-machine height left the catch symbol floating
	# above the observatory like a detached black face. Seat that one in the basin's
	# front panel and retain the high mount for the four genuinely tall displays.
	var basin_mount := mini_game_mode == "catch"
	var crest_height := 3.55 if basin_mount else 10.6
	var crest_depth := 4.78 if basin_mount else 3.38
	var crest_radius := 1.50 if basin_mount else 1.90
	instrument.set_meta("crest_mount",
		"authoritative_basin_front" if basin_mount else "authoritative_tall_display")
	instrument.set_meta("crest_center_height_m", crest_height)
	var dial_at := center + facing * crest_depth + Vector3.UP * crest_height
	if basin_mount:
		var basin_frame := _add_cylinder(instrument, "BasinCrestIvoryFrame",
			dial_at - facing * .04, 2.04, .15,
			_materials.shared_style_ivory, false, 16)
		basin_frame.rotation = Vector3(PI * .5, yaw, 0)
		basin_frame.set_meta("integrates_with", "QuestObjectBase/VisualRoot/BlenderModel")
	var dial_back := _add_cylinder(instrument, "ModeCrestBacking", dial_at,
		crest_radius, .12, _materials.shared_style_charcoal, false, 10)
	dial_back.rotation = Vector3(PI * .5, yaw, 0)
	dial_back.set_meta("integrates_with", "QuestObjectBase/VisualRoot/BlenderModel")
	var side_axis := Vector3(facing.z, 0, -facing.x)
	var crest := Node3D.new()
	crest.name = "ModeCrest_%s" % mini_game_mode.capitalize()
	crest.set_meta("mini_game_mode", mini_game_mode)
	crest.set_meta("preserve_authored_nodes", true)
	instrument.add_child(crest)
	# Retain one cabinet family while making the five interaction types readable
	# before the panel opens.  Each crown uses a different silhouette and the
	# same restrained ivory/cyan/lavender material vocabulary as the islands.
	match mini_game_mode:
		"align":
			for marker_index in 3:
				var marker_height := 2.65 if marker_index == 1 else 1.55
				_add_box(crest, "AlignBand_%02d" % (marker_index + 1),
					dial_at + side_axis * float(marker_index - 1) * 1.05
					+ facing * .12 + Vector3.UP * (-marker_height * .5),
					Vector3(.42, marker_height, .24),
					accent if marker_index == 1 else _materials.shared_style_ivory,
					false, yaw)
		"rhythm":
			var beat_heights := [.75, 1.35, 2.15, 1.35, .75]
			for beat_index in beat_heights.size():
				var beat_height: float = float(beat_heights[beat_index])
				_add_box(crest, "RhythmBeat_%02d" % (beat_index + 1),
					dial_at + side_axis * float(beat_index - 2) * .68
					+ facing * .12 + Vector3.UP * (-1.18 + beat_height * .5),
					Vector3(.46, beat_height, .24),
					accent if beat_index % 2 == 0 else _materials.shared_style_ivory,
					false, yaw)
		"dodge":
			for channel_index in 3:
				var channel_height := 1.7 + float(channel_index) * .34
				var channel := _add_box(crest, "DodgeChannel_%02d" % (channel_index + 1),
					dial_at + side_axis * float(channel_index - 1) * 1.0
					+ facing * .12 + Vector3.UP * (-.55 + channel_height * .5),
					Vector3(.42, channel_height, .24),
					_materials.shared_style_ivory if channel_index == 1 else accent,
					false, yaw)
				channel.rotation.z = -.34 if channel_index % 2 == 0 else .34
		"catch":
			_add_box(crest, "CatchReservoir", dial_at + facing * .12
				- Vector3.UP * 1.35, Vector3(3.35, .32, .24),
				_materials.shared_style_charcoal, false, yaw)
			var drop_heights := [.92, .10, -.68]
			for drop_index in 3:
				_add_sphere(crest, "CatchDroplet_%02d" % (drop_index + 1),
					dial_at + side_axis * float(drop_index - 1) * 1.05
					+ facing * .18 + Vector3.UP * float(drop_heights[drop_index]),
					Vector3(.34, .56, .24),
					accent if drop_index != 1 else _materials.shared_style_lavender)
		"route":
			var route_points: Array[Vector3] = [
				dial_at - side_axis * 1.35 + facing * .14 - Vector3.UP * .75,
				dial_at + facing * .14 + Vector3.UP * .75,
				dial_at + side_axis * 1.35 + facing * .14 - Vector3.UP * .40,
			]
			for route_index in route_points.size():
				_add_sphere(crest, "RouteStar_%02d" % (route_index + 1),
					route_points[route_index], Vector3(.48, .48, .28),
					accent if route_index == 1 else _materials.shared_style_cyan)
				if route_index > 0:
					_add_cable_between(crest, "RouteLink_%02d" % route_index,
						route_points[route_index - 1], route_points[route_index],
						.20, .14, _materials.shared_style_charcoal, 6)
		_:
			_add_brick(crest, "UnknownModeCrystal", dial_at + facing * .14,
				Bricks.build_crystal(1.0, 3.0, .28, 6), accent)
	_build_island_three_operator_controls(instrument, center, facing, yaw,
		side_axis, accent, mini_game_mode)
	_build_island_three_instrument_identity_frame(instrument, center, facing,
		yaw, side_axis, accent, mini_game_mode)


func _build_island_three_instrument_identity_frame(instrument: Node3D,
		center: Vector3, facing: Vector3, yaw: float, side_axis: Vector3,
		accent: Material, mini_game_mode: String) -> void:
	## Give each Island Three machine a different silhouette at interaction range.
	## The authoritative quest models intentionally share one save-backed cabinet
	## family, but a crest alone still made all five close views read as the same
	## white bench and dark round display. These sparse, non-colliding frames sit
	## around that cabinet: they keep the proven interaction envelope and route
	## clearance while making the task legible before the mini-game panel opens.
	var frame := Node3D.new()
	frame.name = "ModeIdentityFrame_%s" % mini_game_mode.capitalize()
	frame.set_meta("mini_game_mode", mini_game_mode)
	frame.set_meta("preserve_authored_nodes", true)
	frame.set_meta("collision_policy", "decorative outside authoritative machine envelope")
	instrument.add_child(frame)
	var part_count := 0
	match mini_game_mode:
		"align":
			# A tall open calibration yoke belongs to the Storm Lens. Its broken
			# outline avoids reintroducing the ring motif removed from this island.
			var lower_y := 6.8
			var shoulder_y := 13.1
			var crown_y := 15.3
			for side in [-1.0, 1.0]:
				var side_name := "Left" if side < 0 else "Right"
				var lower: Vector3 = center + side_axis * side * 3.75 + facing * 3.02 \
					+ Vector3.UP * lower_y
				var shoulder: Vector3 = center + side_axis * side * 3.75 + facing * 3.02 \
					+ Vector3.UP * shoulder_y
				var crown: Vector3 = center + side_axis * side * 1.85 + facing * 3.02 \
					+ Vector3.UP * crown_y
				_add_cable_between(frame, "AlignmentYoke%s" % side_name,
					lower, shoulder, .34, .26, _materials.shared_style_ivory, 8)
				_add_cable_between(frame, "AlignmentShoulder%s" % side_name,
					shoulder, crown, .28, .22, accent, 8)
				_add_brick(frame, "AlignmentIndex%s" % side_name,
					lower + Vector3.UP * 1.1,
					Bricks.build_crystal(.34, 1.15, .12, 6), accent)
				part_count += 3
			_add_cable_between(frame, "AlignmentOpenVisor",
				center - side_axis * 1.85 + facing * 3.02 + Vector3.UP * crown_y,
				center + side_axis * 1.85 + facing * 3.02 + Vector3.UP * crown_y,
				.24, .24, _materials.shared_style_charcoal, 8)
			part_count += 1
			frame.set_meta("silhouette_identity", "open storm calibration yoke")
		"rhythm":
			# Five unequal resonance reeds turn the forge console into a low organ
			# rather than another circular scanner.
			var reed_heights := [2.0, 3.0, 4.2, 3.0, 2.0]
			for reed_index in reed_heights.size():
				var reed_height: float = float(reed_heights[reed_index])
				_add_cylinder(frame, "ResonanceReed_%02d" % (reed_index + 1),
					center + side_axis * float(reed_index - 2) * 1.35 + facing * 2.82
					+ Vector3.UP * (12.35 + reed_height * .5),
					.24, reed_height,
					accent if reed_index % 2 == 0 else _materials.shared_style_ivory,
					false, 7)
				part_count += 1
			for side in [-1.0, 1.0]:
				_add_brick(frame, "ForgeSoundChest%s" % ("Left" if side < 0 else "Right"),
					center + side_axis * side * 4.45 + facing * 2.76 + Vector3.UP * 8.7,
					Bricks.build_bevel_box(Vector3(1.55, 3.2, 1.35), .22),
					_materials.shared_style_charcoal)
				part_count += 1
			frame.set_meta("silhouette_identity", "five-reed resonance organ")
		"dodge":
			# Staggered archive leaves make the safe-channel instrument asymmetric
			# and echo the tall illuminated pages behind it.
			var page_heights := [4.2, 6.5, 5.2, 7.4]
			var page_offsets := [-4.8, -3.45, 3.45, 4.8]
			for page_index in page_heights.size():
				var page_height: float = float(page_heights[page_index])
				_add_box(frame, "ArchiveLeaf_%02d" % (page_index + 1),
					center + side_axis * float(page_offsets[page_index]) + facing * 2.88
					+ Vector3.UP * (7.4 + page_height * .5),
					Vector3(.82, page_height, .42),
					_materials.shared_style_ivory \
					if absf(float(page_offsets[page_index])) > 4.0 else accent,
					false, yaw)
				part_count += 1
			for record_index in 3:
				_add_brick(frame, "DescendingRecord_%02d" % (record_index + 1),
					center + side_axis * float(record_index - 1) * 3.65 + facing * 3.18
					+ Vector3.UP * (13.8 - float(record_index % 2) * 1.2),
					Bricks.build_crystal(.28, 1.25, .12, 5), accent)
				part_count += 1
			frame.set_meta("silhouette_identity", "staggered lightning archive leaves")
		"catch":
			# An open collection cradle follows the low basin instead of borrowing
			# the tall cabinet proportions used by the three Warden anchors.
			var cradle_y := 1.25
			for side in [-1.0, 1.0]:
				var side_name := "Left" if side < 0 else "Right"
				var foot: Vector3 = center + side_axis * side * 3.2 + facing * 4.84 \
					+ Vector3.UP * cradle_y
				var shoulder: Vector3 = center + side_axis * side * 3.2 + facing * 4.84 \
					+ Vector3.UP * 4.5
				var lip: Vector3 = center + side_axis * side * 1.75 + facing * 4.84 \
					+ Vector3.UP * 5.55
				_add_cable_between(frame, "RainCradle%s" % side_name,
					foot, shoulder, .30, .22, _materials.shared_style_ivory, 8)
				_add_cable_between(frame, "RainLip%s" % side_name,
					shoulder, lip, .24, .16, accent, 8)
				part_count += 2
			for drop_index in 3:
				_add_brick(frame, "HarvestDrop_%02d" % (drop_index + 1),
					center + side_axis * float(drop_index - 1) * 1.4 + facing * 4.98
					+ Vector3.UP * (6.35 + float(drop_index % 2) * .65),
					Bricks.build_crystal(.32, 1.05, .12, 6),
					accent if drop_index != 1 else _materials.shared_style_lavender)
				part_count += 1
			frame.set_meta("silhouette_identity", "open rain collection cradle")
		"route":
			# Warm root forks make the final mirror part of the living grove and
			# clearly separate it from the mechanical storm instruments.
			for side in [-1.0, 1.0]:
				var side_name := "Left" if side < 0 else "Right"
				var root: Vector3 = center + side_axis * side * 4.0 + facing * 2.92 \
					+ Vector3.UP * 5.0
				var fork: Vector3 = center + side_axis * side * 3.15 + facing * 2.92 \
					+ Vector3.UP * 11.4
				var crown: Vector3 = center + side_axis * side * 1.45 + facing * 2.92 \
					+ Vector3.UP * 14.4
				_add_cable_between(frame, "ReflectionRoot%s" % side_name,
					root, fork, .48, .28, _materials.island_three_hero_bark, 8)
				_add_cable_between(frame, "ReflectionFork%s" % side_name,
					fork, crown, .30, .16, _materials.island_three_hero_bark_highlight, 8)
				part_count += 2
			for star_index in 3:
				_add_brick(frame, "ReflectionMemory_%02d" % (star_index + 1),
					center + side_axis * float(star_index - 1) * 1.8 + facing * 3.05
					+ Vector3.UP * (14.8 + float(star_index % 2) * .75),
					Bricks.build_crystal(.34, 1.18, .12, 6),
					accent if star_index == 1 else _materials.shared_style_cyan)
				part_count += 1
			frame.set_meta("silhouette_identity", "living root reflection fork")
		_:
			pass
	frame.set_meta("identity_part_count", part_count)


func _build_island_three_operator_controls(instrument: Node3D, center: Vector3,
		facing: Vector3, yaw: float, side_axis: Vector3, accent: Material,
		mini_game_mode: String) -> void:
	## Give each authoritative quest machine a readable player-scale task surface.
	## The earlier badge-only treatment changed the logo but left the physical
	## station as the same blank cabinet in all five review cameras.
	var controls := Node3D.new()
	controls.name = "OperatorControls_%s" % mini_game_mode.capitalize()
	controls.set_meta("mini_game_mode", mini_game_mode)
	controls.set_meta("preserve_authored_nodes", true)
	controls.set_meta("design_language", "island_two_research_bench_with_island_one_facets")
	instrument.add_child(controls)
	var basin_mount := mini_game_mode == "catch"
	var deck_height := 1.85 if basin_mount else 6.55
	var deck_depth := 5.20 if basin_mount else 4.55
	var deck_at := center + facing * deck_depth + Vector3.UP * deck_height
	_add_box(controls, "IvoryControlDeck", deck_at,
		Vector3(7.4, .38, 2.25), _materials.shared_style_ivory, false, yaw)
	_add_box(controls, "CharcoalControlInset", deck_at + Vector3.UP * .24,
		Vector3(6.55, .12, 1.55), _materials.shared_style_charcoal, false, yaw)
	for rail_side in [-1.0, 1.0]:
		_add_box(controls,
			"ControlDeckEnd%s" % ("Left" if rail_side < 0 else "Right"),
			deck_at + side_axis * float(rail_side) * 3.55 + Vector3.UP * .34,
			Vector3(.38, .68, 2.35), _materials.shared_style_ivory, false, yaw)
	var task_piece_count := 0
	match mini_game_mode:
		"align":
			for control_index in 3:
				var control_at := deck_at + side_axis * float(control_index - 1) * 1.75 \
					+ facing * .05 + Vector3.UP * .52
				_add_box(controls, "AlignmentRail_%02d" % (control_index + 1),
					control_at, Vector3(1.05, .16, 1.18),
					_materials.shared_style_ivory, false, yaw)
				_add_brick(controls, "AlignmentHandle_%02d" % (control_index + 1),
					control_at + Vector3.UP * (.42 + float(control_index) * .16),
					Bricks.build_crystal(.34, .82, .14, 6),
					accent if control_index == 1 else _materials.shared_style_cyan)
				task_piece_count += 2
		"rhythm":
			for key_index in 5:
				var key_at := deck_at + side_axis * float(key_index - 2) * 1.25 \
					+ facing * .02 + Vector3.UP * .50
				_add_box(controls, "ResonanceKey_%02d" % (key_index + 1), key_at,
					Vector3(.86, .28 + float(key_index % 2) * .14, 1.08),
					accent if key_index % 2 == 0 else _materials.shared_style_ivory,
					false, yaw)
				task_piece_count += 1
		"dodge":
			for channel_index in 3:
				var channel_at := deck_at + side_axis * float(channel_index - 1) * 1.85 \
					+ facing * .04 + Vector3.UP * .62
				_add_box(controls, "SafeChannel_%02d" % (channel_index + 1), channel_at,
					Vector3(1.18, .34, 1.18),
					_materials.shared_style_ivory if channel_index == 1 else accent,
					false, yaw)
				_add_brick(controls, "LightningRecord_%02d" % (channel_index + 1),
					channel_at + Vector3.UP * (.72 + float(channel_index % 2) * .32),
					Bricks.build_crystal(.28, 1.05, .12, 5),
					accent if channel_index != 1 else _materials.shared_style_cyan)
				task_piece_count += 2
		"catch":
			for reservoir_index in 3:
				var reservoir_at := deck_at + side_axis * float(reservoir_index - 1) * 1.72 \
					+ facing * .03 + Vector3.UP * .58
				_add_cylinder(controls, "RainGauge_%02d" % (reservoir_index + 1),
					reservoir_at, .48, .56, _materials.shared_style_ivory, false, 8)
				_add_brick(controls, "RainDropMarker_%02d" % (reservoir_index + 1),
					reservoir_at + Vector3.UP * .78,
					Bricks.build_crystal(.30, .88, .12, 6),
					accent if reservoir_index != 1 else _materials.shared_style_lavender)
				task_piece_count += 2
		"route":
			var route_controls: Array[Vector3] = [
				deck_at - side_axis * 2.15 + Vector3.UP * .62,
				deck_at + facing * .02 + Vector3.UP * .86,
				deck_at + side_axis * 2.15 + Vector3.UP * .62,
			]
			for route_index in route_controls.size():
				_add_brick(controls, "RouteNode_%02d" % (route_index + 1),
					route_controls[route_index], Bricks.build_crystal(.42, .92, .14, 6),
					accent if route_index == 1 else _materials.shared_style_cyan)
				task_piece_count += 1
				if route_index > 0:
					_add_cable_between(controls, "RouteTrace_%02d" % route_index,
						route_controls[route_index - 1], route_controls[route_index],
						.11, .08, _materials.shared_style_ivory, 6)
					task_piece_count += 1
		_:
			pass
	controls.set_meta("task_piece_count", task_piece_count)


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
	var outward := Vector3(center.x - float(ZONES[4].position.x), 0,
		center.z - float(ZONES[4].position.z)).normalized()
	var side_axis := Vector3(outward.z, 0, -outward.x)
	var landmark_yaw := atan2(outward.x, outward.z)
	# QuestObjectBase places the operator twelve metres outward. Keep another
	# sixteen metres of breathing room beyond that point so players arriving
	# diagonally from the bridge can reach the console without clipping a wing.
	# The player operates each instrument from the island-edge side and looks
	# inward toward the boss court. Place the landmark mass behind the console in
	# that view. The earlier outward offset put the tower, forge and archive
	# behind the player's camera, leaving every interaction framed by the same
	# generic cabinet and making the distinct architecture effectively invisible.
	var backdrop_inset := 12.0 if landmark_index == 0 else 18.0
	var rear_center := center - outward * backdrop_inset
	landmark.set_meta("silhouette_revision", "human_scale_civic_backdrop_v1")
	landmark.set_meta("operator_backdrop_side", "court_inward")
	landmark.set_meta("interaction_forecourt_clear_m", 11.0)
	var mini_game_modes := ["align", "rhythm", "dodge"]
	_build_island_three_shared_instrument(landmark, center, outward,
		_materials.shared_style_cyan if landmark_index != 1 else _materials.shared_style_lavender,
		str(mini_game_modes[landmark_index]))
	if landmark_index == 0:
		# A tall open survey instrument with one suspended lens crystal.  The
		# stepped observatory backing sits behind the operator, giving the lens a
		# readable mass from the arrival camera without closing its forecourt.
		for buttress_side in [-1.0, 1.0]:
			_add_box(landmark,
				"LensCitadelPodium%s" % ("Left" if buttress_side < 0 else "Right"),
				rear_center + side_axis * float(buttress_side) * 15.0 + Vector3.UP * 2.0,
				Vector3(6.5, 4.0, 13.0), _materials.shared_style_ivory, true,
				landmark_yaw)
			var buttress_at := rear_center + side_axis * float(buttress_side) * 14.5 \
				+ Vector3.UP * 10.0
			_add_box(landmark,
				"LensCivicButtress%s" % ("Left" if buttress_side < 0 else "Right"),
				buttress_at, Vector3(4.2, 20.0, 6.0),
				_materials.shared_style_ivory, true, landmark_yaw)
			_add_brick(landmark,
				"LensButtressCrystal%s" % ("Left" if buttress_side < 0 else "Right"),
				buttress_at + Vector3.UP * 12.0,
				Bricks.build_crystal(1.1, 4.2, .3, 6), _materials.shared_style_cyan)
		# Three slim survey supports carry the lens without recreating the former
		# 36 m scaffold or a second arrival gate. Their short upper braces terminate
		# below the compact sight, keeping the boss court and horizon visible.
		var support_offsets: Array[Vector3] = [
			-side_axis * 5.2,
			side_axis * 5.2,
			outward * 4.2,
		]
		for support_index in support_offsets.size():
			var support_at := rear_center + support_offsets[support_index]
			_add_cylinder(landmark,
				"LensInstrumentSupport_%02d" % (support_index + 1),
				support_at + Vector3.UP * 9.2, .66, 18.4,
				_materials.shared_style_ivory, true, 8)
			_add_sphere(landmark,
				"LensSupportJoint_%02d" % (support_index + 1),
				support_at + Vector3.UP * 18.6, Vector3.ONE * .82,
				_materials.shared_style_charcoal)
			var brace_target := rear_center + Vector3.UP * 20.0
			if support_index < 2:
				brace_target += side_axis * (-3.7 if support_index == 0 else 3.7)
			else:
				brace_target -= outward * 1.2
			var support_brace := _add_cable_between(landmark,
				"LensSightBrace_%02d" % (support_index + 1),
				support_at + Vector3.UP * 18.6, brace_target,
				.30, .22, _materials.shared_style_charcoal, 8)
			support_brace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			support_brace.set_meta("arrival_foreground_shadow_disabled", true)
		_add_brick(landmark, "StormLensPrism", rear_center + Vector3.UP * 25.0,
			Bricks.build_crystal(3.8, 11.0, .65, 6), _materials.arrival_glass)
		var sight_frame := Node3D.new()
		sight_frame.name = "OpenLensAlignmentFrame"
		sight_frame.position = rear_center + Vector3.UP * 25.0
		# Face the court; from the bridge this frame reads edge-on instead of
		# filling the arrival camera with a cropped geometric outline.
		sight_frame.rotation.y = PI * .75
		landmark.add_child(sight_frame)
		# The earlier sixteen-metre diamond was mostly empty outline and read like
		# an unfinished construction frame beside the more detailed Island 1 and 2
		# instruments. A tighter vertical hexagon now hugs the prism and uses short
		# calibration tabs instead of another ring or a route-like cyan line.
		var sight_corners := [
			Vector3(-4.0, 5.2, 0), Vector3(4.0, 5.2, 0),
			Vector3(5.4, 0, 0), Vector3(4.0, -5.2, 0),
			Vector3(-4.0, -5.2, 0), Vector3(-5.4, 0, 0),
		]
		for side_index in sight_corners.size():
			var alignment_beam := _add_beam_between(sight_frame,
				"IvoryAlignmentBeam_%02d" % (side_index + 1),
				sight_corners[side_index],
				sight_corners[(side_index + 1) % sight_corners.size()],
				.66, _materials.shared_style_ivory)
			alignment_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			alignment_beam.set_meta("arrival_foreground_shadow_disabled", true)
		for marker_index in 3:
			var marker_y := -2.6 + float(marker_index) * 2.6
			for marker_side in [-1.0, 1.0]:
				var marker := _add_box(sight_frame,
					"CyanAlignmentIndex_%02d_%s" % [marker_index + 1,
						"Left" if marker_side < 0 else "Right"],
					Vector3(float(marker_side) * 4.65, marker_y, .18),
					Vector3(.58, .74, .32), _materials.shared_style_cyan)
				marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				marker.set_meta("storm_band_calibration", marker_index + 1)
		sight_frame.set_meta("design_revision", "compact_hexagonal_calibrated_sight_v2")
		sight_frame.set_meta("frame_span_m", 10.8)
		sight_frame.set_meta("alignment_index_count", 6)
		sight_frame.set_meta("sighting_role", "single faceted storm-band alignment frame")
	elif landmark_index == 1:
		# The forge is low and muscular.  A broad pediment and rear furnace hall
		# make it read as occupied architecture while its open front retains the
		# rhythm-game interaction and boss-court sightline.
		for side in [-1.0, 1.0]:
			_add_box(landmark,
				"ForgeHallPlinth%s" % ("Left" if side < 0 else "Right"),
				rear_center + side_axis * float(side) * 15.0 + Vector3.UP * 2.0,
				Vector3(10.0, 4.0, 18.0), _materials.shared_style_charcoal, true,
				landmark_yaw)
			_add_box(landmark,
				"ForgeFurnaceHall%s" % ("Left" if side < 0 else "Right"),
				rear_center + side_axis * float(side) * 14.0 + Vector3.UP * 10.0,
				Vector3(9.0, 16.0, 11.0), _materials.shared_style_ivory, true,
				landmark_yaw)
			var pylon_at := rear_center + side_axis * float(side) * 15.0
			_add_box(landmark, "ForgeButtress_%s" % ("L" if side < 0 else "R"),
				pylon_at + Vector3.UP * 11.0, Vector3(7.0, 22.0, 10.0),
				_materials.celestial_floor, true, landmark_yaw)
			_add_tapered_cylinder(landmark,
				"ForgeConductor_%s" % ("L" if side < 0 else "R"),
				pylon_at + Vector3.UP * 25.0, .2, 1.8, 7.0,
				_materials.island_cyan, 8)
		_add_cable_between(landmark, "ForgeLintel",
			rear_center - side_axis * 14.0 + Vector3.UP * 22.5,
			rear_center + side_axis * 14.0 + Vector3.UP * 22.5,
			1.4, 1.4, _materials.floor_dark, 8)
		for side in [-1.0, 1.0]:
			_add_cable_between(landmark, "IvoryForgePediment_%s" % side,
				rear_center + side_axis * side * 15.0 + Vector3.UP * 23.0,
				rear_center + Vector3.UP * 36.0,
				2.0, 1.3, _materials.shared_style_ivory, 8)
		_add_brick(landmark, "LavenderForgeKeystone", rear_center + Vector3.UP * 36.0,
			Bricks.build_crystal(2.8, 5.8, .6, 6), _materials.shared_style_lavender)
		var resonance_core := _add_sphere(landmark, "SuspendedResonanceCore",
			rear_center + Vector3.UP * 16.0,
			Vector3(6.4, 7.0, 6.4), _materials.island_violet_energy)
		# The state-driven forge core is a semantic landmark, not disposable static
		# scenery. Keep its stable node path even when another lavender crest pushes
		# the surrounding material group over the static-batch threshold.
		resonance_core.set_meta("preserve_authored_nodes", true)
		for pylon_index in 4:
			var pylon_angle := TAU * float(pylon_index) / 4.0 + PI * .25
			var tuned_at := rear_center + Vector3(sin(pylon_angle) * 8.0, 2.3,
				cos(pylon_angle) * 8.0)
			_add_brick(landmark, "TunedCrystalPylon_%02d" % (pylon_index + 1), tuned_at,
				Bricks.build_crystal(1.0, 4.6, .3, 6),
				_materials.island_cyan if pylon_index % 2 == 0 else _materials.sanctum_lavender_glass)
	else:
		# The archive uses staggered vertical fins like open illuminated pages.
		# Two tall bookends and a lintel make those pages read as a building from
		# player height instead of a loose row of props. The whole page hall is
		# offset to one side, leaving the authored archive-to-rain egress open.
		var archive_center := rear_center + side_axis * 20.0
		for bookend_side in [-1.0, 1.0]:
			_add_box(landmark,
				"ArchiveHallBase%s" % ("Left" if bookend_side < 0 else "Right"),
				archive_center + side_axis * float(bookend_side) * 16.0 + Vector3.UP * 4.0,
				Vector3(10.0, 8.0, 17.0), _materials.shared_style_charcoal, true,
				landmark_yaw)
			var bookend_at := archive_center + side_axis * float(bookend_side) * 17.0 \
				+ Vector3.UP * 19.0
			_add_box(landmark,
				"ArchiveBookendTower%s" % ("Left" if bookend_side < 0 else "Right"),
				bookend_at, Vector3(6.0, 38.0, 9.0),
				_materials.shared_style_ivory, true, landmark_yaw)
			_add_box(landmark,
				"ArchiveBookendGlass%s" % ("Left" if bookend_side < 0 else "Right"),
				bookend_at - outward * 4.6, Vector3(3.0, 24.0, .24),
				_materials.shared_style_cyan, false, landmark_yaw)
		_add_box(landmark, "ArchiveCrownLintel", archive_center + Vector3.UP * 37.0,
			Vector3(36.0, 3.0, 8.0), _materials.shared_style_ivory, true,
			landmark_yaw)
		for fin_index in 7:
			var side := -1.0 if fin_index % 2 == 0 else 1.0
			var depth := -12.0 + float(fin_index) * 4.0
			var fin_height := 24.0 + float(fin_index) * 1.3
			var fin_at := archive_center + side_axis * side * (7.0 + absf(depth) * .25) \
				+ outward * (depth * .45) + Vector3.UP * (fin_height * .5)
			_add_box(landmark, "ArchiveFin_%02d" % (fin_index + 1), fin_at,
				Vector3(1.8, fin_height, 3.8), _materials.celestial_floor, true)
			_add_box(landmark, "ArchiveCharcoalBase_%02d" % (fin_index + 1),
				fin_at - Vector3.UP * (fin_height * .5 - .6),
				Vector3(2.4, 1.1, 4.2),
				_materials.floor_dark, true)
			_add_box(landmark, "ArchiveGlyph_%02d" % (fin_index + 1),
				fin_at + Vector3(-side * .92, 2.5, 0), Vector3(.12, 15.0, 1.2),
				_materials.arrival_glass)
		_add_brick(landmark, "ArchiveMemoryShard", archive_center + Vector3.UP * 25.0,
			Bricks.build_crystal(4.6, 14.0, .5, 6), _materials.island_cyan)
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
	observatory.set_meta("design_revision", "restrained_ivory_weather_house_v3_rain_garden")
	observatory.set_meta("cyan_surface_policy", "water and small glass accents only")
	observatory.set_meta("rain_garden_bed_count", 3)
	observatory.set_meta("rain_garden_planting_count", 9)
	parent.add_child(observatory)
	_build_island_three_shared_instrument(observatory, center, Vector3(0, 0, -1),
		_materials.shared_style_cyan, "catch")
	_add_box(observatory, "RainCollectorTerrace", center - Vector3.UP * .12,
		Vector3(42.0, .28, 34.0), _materials.celestial_floor, true)
	_add_box(observatory, "RainCollectorUndercroft", center - Vector3.UP * .54,
		Vector3(37.0, .60, 29.0), _materials.floor_dark, true)
	_add_cylinder(observatory, "RainPool", center + Vector3.UP * .12,
		9.0, .12, _materials.rain_glass, false, 12)
	var mast_top := center + Vector3.UP * 24.0
	for corner_index in 4:
		var x := -15.0 if corner_index % 2 == 0 else 15.0
		var z := -11.0 if corner_index < 2 else 11.0
		var corner := center + Vector3(x, 0, z)
		_add_island_three_civic_column(observatory,
			"RainGaugeMast_%02d" % (corner_index + 1), corner, 14.0)
		var collector_rib := _add_cable_between(observatory,
			"RainCollectorRib_%02d" % (corner_index + 1),
			corner + Vector3.UP * 14.8, mast_top, .64, .28,
			_materials.shared_style_ivory, 10)
		collector_rib.set_meta("finish_role", "ivory_weather_structure")
		_add_box(observatory, "RainVane_%02d" % (corner_index + 1),
			corner + Vector3.UP * 16.6, Vector3(3.2, .22, 1.2),
			_materials.rain_glass, false, float(corner_index) * PI * .25)
	var rain_needle := _add_cylinder(observatory, "CentralRainNeedle",
		center + Vector3.UP * 16.0, .18, 13.0,
		_materials.floor_dark, false, 8)
	rain_needle.set_meta("finish_role", "charcoal_weather_needle")
	_add_brick(observatory, "RainCrystalReservoir", center + Vector3.UP * 6.0,
		Bricks.build_crystal(2.2, 6.0, .55, 8), _materials.rain_glass)
	var dome := _add_sphere(observatory, "FacetedRainDome", center + Vector3.UP * 7.2,
		Vector3(9.5, 5.5, 9.5), _materials.rain_glass)
	var dome_mesh := dome.mesh as SphereMesh
	dome_mesh.radial_segments = 12
	dome_mesh.rings = 6
	for channel_index in 4:
		var channel_angle := TAU * float(channel_index) / 4.0
		var channel_center := center + Vector3(sin(channel_angle) * 14.5, .19,
			cos(channel_angle) * 14.5)
		_add_box(observatory, "RainChannel_%02d" % (channel_index + 1), channel_center,
			Vector3(.72, .08, 17.0), _materials.rain_glass, false, channel_angle)
	# Three low catchment gardens complete the rear half of the weather terrace.
	# Their solid ivory beds repeat the environmental rhythm of Islands One and
	# Two without closing the southern operator approach or crowding the pool.
	for bed_index in 3:
		var bed_angle := -.8 + float(bed_index) * .8
		var bed_at := center + Vector3(sin(bed_angle) * 14.0, 0,
			cos(bed_angle) * 12.8)
		var bed_yaw := -bed_angle
		_add_box(observatory, "RainCatchmentBed_%02d" % (bed_index + 1),
			bed_at + Vector3.UP * .45, Vector3(7.0, .9, 4.4),
			_materials.celestial_floor, true, bed_yaw)
		_add_box(observatory, "RainCatchmentSoil_%02d" % (bed_index + 1),
			bed_at + Vector3.UP * .94, Vector3(6.1, .10, 3.5),
			_materials.island_three_earth, false, bed_yaw)
		var bed_side := Vector3(cos(bed_yaw), 0, -sin(bed_yaw))
		for planting_index in 3:
			var planting_at := bed_at + bed_side * float(planting_index - 1) * 1.75
			_add_cylinder(observatory,
				"RainGardenStem_%02d_%02d" % [bed_index + 1, planting_index + 1],
				planting_at + Vector3.UP * 1.55, .12, 1.3,
				_materials.island_three_hero_bark, false, 7)
			var planting := _add_sphere(observatory,
				"RainGardenPlanting_%02d_%02d" % [bed_index + 1, planting_index + 1],
				planting_at + Vector3.UP * (2.25 + float(planting_index % 2) * .28),
				Vector3(1.0, .52, .78),
				_island_three_canopy_material(bed_index + planting_index))
			(planting.mesh as SphereMesh).radial_segments = 7
			(planting.mesh as SphereMesh).rings = 3
		_add_sphere(observatory, "RainGardenGauge_%02d" % (bed_index + 1),
			bed_at + Vector3.UP * 1.55, Vector3(.34, .48, .34),
			_materials.shared_style_cyan)
	var completion_visuals := Node3D.new()
	completion_visuals.name = "CompletionStateVisuals"
	completion_visuals.set_meta("preserve_authored_nodes", true)
	observatory.add_child(completion_visuals)
	_add_cylinder(completion_visuals, "HarvestedRainWater", center + Vector3.UP * .22,
		8.2, .14, _materials.rain_glass, false, 12)
	for stream_index in 6:
		var angle := TAU * float(stream_index) / 6.0
		_add_cable_between(completion_visuals, "CapturedRainStream_%02d" % (stream_index + 1),
			center + Vector3(sin(angle) * 9.0, 13.0, cos(angle) * 9.0),
			center + Vector3(sin(angle) * 2.8, 7.0, cos(angle) * 2.8),
			.15, .08, _materials.rain_glass, 8)
	for fall_index in 2:
		var fall_at := center + Vector3(-8.0 if fall_index == 0 else 8.0, -8.0, 19.0)
		_add_tapered_cylinder(completion_visuals, "ObservatoryWaterfall_%02d" % (fall_index + 1),
			fall_at, .22, 1.25, 18.0, _materials.rain_glass, 6)


func _build_oldest_tree_living_cathedral(parent: Node3D, base: Vector3) -> void:
	var cathedral := Node3D.new()
	cathedral.name = "OldestTreeLivingCathedral"
	cathedral.set_meta("design_revision", "root_crown_cathedral_v4_human_scale_canopy")
	cathedral.set_meta("quest_architecture", "walkable living landmark")
	cathedral.set_meta("asymmetric_canopy", true)
	cathedral.set_meta("camera_clearance_m", 30.0)
	cathedral.set_meta("player_height_read", "tapered trunk, curved root flare and visible lower canopy")
	cathedral.set_meta("low_poly_landmark", true)
	cathedral.set_meta("preserve_authored_nodes", true)
	cathedral.set_meta("shared_style_family", "island_one_ivory_cyan_lavender")
	cathedral.set_meta("matches_island_one_light_tree", true)
	parent.add_child(cathedral)
	# A square ivory clearing covers the obsolete concentric gold floor ornament
	# and gives the roots a calm architectural foreground.
	_add_box(cathedral, "LivingCathedralTerrace", base + Vector3.UP * .12,
		Vector3(62.0, .26, 58.0), _materials.celestial_floor, true)
	# Leave the approach clear. The previous five cyan floor bars read as loose
	# lines from the gameplay camera and competed with the reflection threshold.
	# A narrow collision-backed heartwood keeps the tree physically authoritative.
	# Two faceted tapered shells create the visible trunk.  The old single 52 m
	# cylinder filled the gameplay camera with a flat brown wall and placed every
	# branch above the player's view.
	_add_cylinder(cathedral, "LivingHeartwood", base + Vector3.UP * 26.0,
		4.8, 52.0, _materials.island_three_hero_bark, true, 14)
	_add_tapered_cylinder(cathedral, "HeartwoodLowerTrunk",
		base + Vector3.UP * 14.0, 6.2, 9.8, 28.0,
		_materials.island_three_hero_bark, 12)
	_add_tapered_cylinder(cathedral, "HeartwoodUpperTrunk",
		base + Vector3.UP * 39.0, 4.5, 6.4, 24.0,
		_materials.island_three_hero_bark, 12)
	for ribbon_index in 8:
		var ribbon_angle := TAU * float(ribbon_index) / 8.0
		var ribbon_start := base + Vector3(sin(ribbon_angle) * 9.4, 1.0,
			cos(ribbon_angle) * 9.4)
		var ribbon_finish_angle := ribbon_angle + .72
		var ribbon_finish := base + Vector3(sin(ribbon_finish_angle) * 4.7, 50.0,
			cos(ribbon_finish_angle) * 4.7)
		_add_cable_between(cathedral, "HeartwoodBarkRibbon_%02d" % (ribbon_index + 1),
			ribbon_start, ribbon_finish, .72, .38,
			_materials.island_three_hero_bark_highlight \
			if ribbon_index % 2 == 0 else _materials.island_three_hero_bark_shadow, 10)
	for root_index in 10:
		var angle := TAU * float(root_index) / 10.0 + sin(float(root_index)) * .10
		var radial := Vector3(sin(angle), 0, cos(angle))
		var start := base + radial * 5.0 + Vector3.UP * 5.2
		var shoulder := base + radial * (11.0 + float(root_index % 2) * 1.4) \
			+ Vector3.UP * 1.7
		var finish := base + radial * (18.0 + float(root_index % 3) * 2.2) \
			+ Vector3.UP * .30
		_add_cable_between(cathedral, "CathedralRoot_%02d" % (root_index + 1),
			start, shoulder, 3.0, 1.45, _materials.island_three_hero_bark, 12)
		_add_cable_between(cathedral, "CathedralRootTip_%02d" % (root_index + 1),
			shoulder, finish, 1.45, .55, _materials.island_three_hero_bark, 10)
		_add_cable_between(cathedral, "CathedralRootVein_%02d" % (root_index + 1),
			shoulder + Vector3.UP * .62, finish + Vector3.UP * .28,
			.26, .09, _materials.shared_style_cyan, 8)
	# Five great boughs form an uneven nave and pull the silhouette toward the basilica.
	var bough_lengths := [24.0, 32.0, 28.0, 35.0, 26.0]
	var bough_heights := [58.0, 66.0, 62.0, 69.0, 64.0]
	for bough_index in 5:
		var angle := -.8 + float(bough_index) * TAU / 5.0
		var radial := Vector3(sin(angle), 0, cos(angle))
		var branch_start := base + Vector3(0, 33.0 + bough_index * 1.7, 0)
		var branch_mid := base + radial * (float(bough_lengths[bough_index]) * .48) \
			+ Vector3.UP * (46.0 + bough_index * 1.8)
		var branch_end := base + radial * float(bough_lengths[bough_index]) \
			+ Vector3.UP * float(bough_heights[bough_index])
		_add_cable_between(cathedral, "GreatBough_%02dA" % (bough_index + 1),
			branch_start, branch_mid, 2.7, 1.4, _materials.island_three_hero_bark, 14)
		_add_cable_between(cathedral, "GreatBough_%02dB" % (bough_index + 1),
			branch_mid, branch_end, 1.4, .55, _materials.island_three_hero_bark, 12)
		# A pair of lower masses makes living foliage visible from the standard
		# third-person camera, while the five airy crown clusters keep the aerial
		# silhouette and memory-fruit spacing.
		for lower_index in 2:
			var lower_side := -1.0 if lower_index == 0 else 1.0
			var lower_at := branch_mid + Vector3(lower_side * 5.2, 1.2 + lower_index * 1.6,
				lower_side * 2.8)
			var lower_canopy := _add_sphere(cathedral,
				"LowerCanopyMass_%02d_%02d" % [bough_index + 1, lower_index + 1],
				lower_at, Vector3(11.5, 6.2, 10.0),
				_island_three_canopy_material(bough_index + lower_index + 1))
			(lower_canopy.mesh as SphereMesh).radial_segments = 8
			(lower_canopy.mesh as SphereMesh).rings = 4
		for leaf_cluster_index in 5:
			var leaf_angle := TAU * float(leaf_cluster_index) / 5.0 + bough_index * .29
			var leaf_offset := Vector3(sin(leaf_angle) * (7.0 + leaf_cluster_index % 2 * 3.0),
				float(leaf_cluster_index % 3) * 2.2 - 2.0,
				cos(leaf_angle) * (6.0 + (leaf_cluster_index + 1) % 2 * 3.0))
			var canopy := _add_sphere(cathedral,
				"CanopyLeafMass_%02d_%02d" % [bough_index + 1, leaf_cluster_index + 1],
				branch_end + leaf_offset,
				Vector3(17.0 + float(leaf_cluster_index % 2) * 3.0,
					8.5 + float((leaf_cluster_index + bough_index) % 3) * 1.2,
					16.0 + float((leaf_cluster_index + 1) % 3) * 1.5),
				_island_three_canopy_material(leaf_cluster_index + bough_index))
			var canopy_mesh := canopy.mesh as SphereMesh
			canopy_mesh.radial_segments = 8
			canopy_mesh.rings = 4
		for fruit_index in 3:
			var fruit_offset := Vector3(float(fruit_index - 1) * 4.0,
				-6.0 - float(fruit_index % 2) * 2.0, float((fruit_index + bough_index) % 2) * 3.0)
			_add_brick(cathedral,
				"MemoryFruit_%02d_%02d" % [bough_index + 1, fruit_index + 1],
				branch_end + fruit_offset, Bricks.build_crystal(.7, 2.4, .2, 6),
				_materials.shared_style_lavender if fruit_index == 1 \
				else _materials.shared_style_cyan)
	_add_brick(cathedral, "LivingCathedralCrown", base + Vector3.UP * 79.0,
		Bricks.build_crystal(3.8, 11.0, .8, 6), _materials.shared_style_cyan)


func _finish_island_three_masonry(campus: Node3D, geometry: Node3D) -> void:
	var finishes := {}
	var masonry_sources: Array[Material] = [
		_materials.shared_style_ivory, _materials.shared_style_charcoal,
		_materials.celestial_floor, _materials.sanctum_ivory,
		_materials.floor_dark, _materials.stone,
	]
	for assembly_name in ["FusedSuperIsland_05_06", "IslandThreePerimeterRepairs"]:
		var assembly := geometry.find_child(assembly_name, true, false)
		if assembly != null:
			_refine_island_one_scenery_node(assembly, finishes)
	for candidate in campus.find_children("*", "MeshInstance3D", true, false):
		var part := candidate as MeshInstance3D
		var source := part.material_override as StandardMaterial3D
		if source == null or source not in masonry_sources:
			continue
		var key := source.get_instance_id()
		if not finishes.has(key):
			var finish := source.duplicate() as StandardMaterial3D
			finish.roughness = maxf(finish.roughness, .65)
			finish.metallic = minf(finish.metallic, .12)
			finish.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			finish.emission_enabled = false
			# Only masonry is flattened; crystals and quest feedback keep their
			# original glass response and controlled emission.
			finishes[key] = finish
		part.material_override = finishes[key]
	campus.set_meta("masonry_finish", "matte_non_emissive")


func _build_island_three_paving(parent: Node3D, center: Vector3,
		radius: float, district: String) -> void:
	var paving := Node3D.new()
	paving.name = district + "JointedStonePaving"
	paving.set_meta("collision_policy", "flush finish over continuous foundation")
	parent.add_child(paving)
	# Match the pearl-ivory paving used by Islands One and Two. The former tan
	# courses made this district read as a separate prototype under the same sun.
	var colors := [Color("e6dcc5"), Color("efe6d2"), Color("ded3bd"), Color("f5ecd8")]
	var materials: Array[StandardMaterial3D] = []
	for color in colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = .9
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials.append(material)
	# Large masonry courses give the court human scale without luminous rings.
	for course in 9:
		var inner := float(course) * radius / 9.0 + .20
		var outer := float(course + 1) * radius / 9.0 - .20
		var divisions := maxi(12, 12 + course * 6)
		for block in divisions:
			var start := TAU * (float(block) + float(course % 2) * .5) / divisions + .001
			var end := start + TAU / divisions - .002
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var a := Vector3(sin(start) * inner, 0, cos(start) * inner)
			var b := Vector3(sin(end) * inner, 0, cos(end) * inner)
			var c := Vector3(sin(end) * outer, 0, cos(end) * outer)
			var d := Vector3(sin(start) * outer, 0, cos(start) * outer)
			for vertex in [a, b, c, a, c, d]:
				surface.set_normal(Vector3.UP)
				surface.add_vertex(vertex)
			_add_brick(paving, "Stone_%02d_%02d" % [course, block],
				center + Vector3.UP * .025, surface.commit(),
				materials[(course + block % 3) % materials.size()])


func _build_island_three_matched_environment(parent: Node3D, arena_center: Vector3,
		sanctuary_center: Vector3, arrival_center: Vector3,
		anchor_offsets: Array, basin_at: Vector3) -> void:
	# Islands One and Two read as finished places because their gameplay objects sit
	# inside repeated civic bays, mature gardens and a layered perimeter. Give the
	# third island that same hierarchy without narrowing any quest approach.
	var environment := Node3D.new()
	environment.name = "IslandThreeMatchedEnvironment"
	environment.set_meta("design_reference", "Island One research gardens + Island Two observatory terraces")
	environment.set_meta("environment_revision", "open_civic_gardens_v15_clear_reflection_skyline")
	environment.set_meta("foliage_palette", "pale sage, moss, muted evergreen, restrained ivory blossom")
	environment.set_meta("clear_routes_preserved", true)
	environment.set_meta("no_gold_lines_or_route_barriers", true)
	environment.set_meta("preserve_authored_nodes", true)
	parent.add_child(environment)

	_build_island_three_paving(environment, arena_center, 164.0, "Storm")
	_build_island_three_paving(environment, sanctuary_center, 135.0, "Sanctuary")
	_build_island_three_sky_garden_fragments(environment, arena_center)

	var storm_gallery := Node3D.new()
	storm_gallery.name = "StormworksPerimeterGardenGallery"
	storm_gallery.set_meta("spatial_role", "layered inhabited edge around the open boss court")
	environment.add_child(storm_gallery)
	var storm_blocked: Array[Vector3] = [arrival_center, basin_at]
	for offset in anchor_offsets:
		storm_blocked.append(arena_center + (offset as Vector3))
	var storm_bay_count := 0
	for bay_index in 11:
		var angle := TAU * float(bay_index) / 11.0
		var bay_center := arena_center + Vector3(sin(angle) * 145.0, 0,
			cos(angle) * 145.0)
		var clear := true
		for blocked in storm_blocked:
			if bay_center.distance_to(blocked) < 31.0:
				clear = false
				break
		if not clear:
			continue
		_build_island_three_environment_bay(storm_gallery,
			"StormGardenBay_%02d" % (storm_bay_count + 1), bay_center,
			angle, storm_bay_count, storm_bay_count % 3 == 0)
		storm_bay_count += 1
	storm_gallery.set_meta("garden_bay_count", storm_bay_count)

	# The tree district uses a quieter, greener terrace ring. Its opening toward
	# the storm court and its return gate remain broad and visually obvious.
	var sanctuary_gallery := Node3D.new()
	sanctuary_gallery.name = "OldestTreeTerracedGarden"
	sanctuary_gallery.set_meta("spatial_role", "mature garden frame around the living cathedral")
	environment.add_child(sanctuary_gallery)
	var incoming_direction := (arena_center - sanctuary_center).normalized()
	var sanctuary_blocked: Array[Vector3] = [
		sanctuary_center + incoming_direction * 108.0,
		sanctuary_center + Vector3(78.0, 0, 48.0),
	]
	var sanctuary_bay_count := 0
	for bay_index in 10:
		var angle := TAU * float(bay_index) / 10.0 + PI / 10.0
		var bay_center := sanctuary_center + Vector3(sin(angle) * 111.0, 0,
			cos(angle) * 111.0)
		var clear := true
		for blocked in sanctuary_blocked:
			if bay_center.distance_to(blocked) < 35.0:
				clear = false
				break
		if not clear:
			continue
		_build_island_three_environment_bay(sanctuary_gallery,
			"SanctuaryGardenBay_%02d" % (sanctuary_bay_count + 1), bay_center,
			angle, sanctuary_bay_count + 20, sanctuary_bay_count % 4 == 1)
		sanctuary_bay_count += 1
	sanctuary_gallery.set_meta("garden_bay_count", sanctuary_bay_count)

	var pavilion_gallery := Node3D.new()
	pavilion_gallery.name = "CivicGardenPavilions"
	pavilion_gallery.set_meta("design_reference", "Island Two domed observatories with Island One living-light machinery")
	environment.add_child(pavilion_gallery)
	var pavilion_centers: Array[Vector3] = [
		arena_center + Vector3(-112.0, 0, -82.0),
		arena_center + Vector3(106.0, 0, -82.0),
		sanctuary_center + Vector3(58.0, 0, -98.0),
	]
	for pavilion_index in pavilion_centers.size():
		_build_island_three_garden_pavilion(pavilion_gallery,
			"CivicGardenPavilion_%02d" % (pavilion_index + 1),
			pavilion_centers[pavilion_index], pavilion_index)
	pavilion_gallery.set_meta("pavilion_count", pavilion_centers.size())
	environment.set_meta("total_environment_bays", storm_bay_count + sanctuary_bay_count)
	var garden_offsets: Array[Vector3] = [Vector3(-51, 0, -66), Vector3(51, 0, -66),
		Vector3(-45, 0, 76), Vector3(45, 0, 76)]
	for garden_index in garden_offsets.size():
		_build_island_three_planted_room(environment, arena_center + garden_offsets[garden_index], garden_index)


func _build_island_three_sky_garden_fragments(parent: Node3D,
		arena_center: Vector3) -> void:
	# Two unreachable garden fragments break up the empty Stormworks horizon in
	# the normal arrival camera. They repeat the solid-rock, ivory-terrace and
	# living-tree language of the fused islands without creating another route.
	var fragments := Node3D.new()
	fragments.name = "DistantSkyGardenFragments"
	fragments.set_meta("fragment_count", 2)
	fragments.set_meta("collision_policy", "decorative and unreachable")
	fragments.set_meta("camera_role", "sparse Stormworks skyline depth")
	fragments.set_meta("preserve_authored_nodes", true)
	# The Web build already has the gallery's layered cosmic sky. These two
	# non-gameplay silhouettes add draw submissions and read as stray inverted
	# islands in the narrow reflection camera, so keep them as native scenery.
	fragments.visible = not _uses_web_render_budget()
	fragments.set_meta("web_scenery_retired", _uses_web_render_budget())
	parent.add_child(fragments)
	# Keep both fragments behind the Stormworks lateral skyline. The first v14
	# placement still aligned with the Reflection Court camera and showed its dark
	# keel directly over the quest instrument. Shift it far south-west and reduce
	# its scale so both fragments stay peripheral background accents.
	var fragment_specs: Array = [
		[arena_center + Vector3(120.0, 82.0, -260.0), .68, -0.18],
		[arena_center + Vector3(285.0, 88.0, 168.0), .72, .27],
	]
	for fragment_index in fragment_specs.size():
		var spec: Array = fragment_specs[fragment_index]
		var fragment := Node3D.new()
		fragment.name = "SkyGardenFragment_%02d" % (fragment_index + 1)
		fragment.position = spec[0] as Vector3
		fragment.rotation.y = float(spec[2])
		fragment.set_meta("decorative_unreachable", true)
		fragment.set_meta("background_scale", float(spec[1]))
		fragment.set_meta("storm_horizon_offset", fragment.position - arena_center)
		fragments.add_child(fragment)
		var scale_factor := float(spec[1])
		_add_tapered_cylinder(fragment, "FacetedRockCore", Vector3(0, -10.5, 0),
			14.0 * scale_factor, 2.4 * scale_factor, 22.0 * scale_factor,
			_materials.shared_style_charcoal, 7)
		_add_tapered_cylinder(fragment, "FacetedRockShoulder", Vector3(-8.5, -6.5, 2.0),
			7.5 * scale_factor, 1.3 * scale_factor, 13.0 * scale_factor,
			_materials.island_three_earth, 6)
		_add_tapered_cylinder(fragment, "FacetedRockShoulderEast", Vector3(8.0, -7.5, -2.5),
			6.4 * scale_factor, 1.1 * scale_factor, 14.5 * scale_factor,
			_materials.island_three_earth, 6)
		_add_cylinder(fragment, "IvoryGardenCap", Vector3.ZERO,
			16.5 * scale_factor, 1.25 * scale_factor,
			_materials.shared_style_ivory, false, 12)
		_add_cylinder(fragment, "SkyTreeTrunk", Vector3(-5.5, 6.0, 1.5) * scale_factor,
			1.0 * scale_factor, 11.0 * scale_factor,
			_materials.island_three_hero_bark, false, 7)
		for crown_index in 3:
			var crown_angle := TAU * float(crown_index) / 3.0 + .35
			var crown_at := Vector3(-5.5 + sin(crown_angle) * 5.0,
				13.0 + float(crown_index % 2),
				cos(crown_angle) * 4.0) * scale_factor
			var canopy := _add_sphere(fragment,
				"SkyGardenCanopy_%02d" % (crown_index + 1), crown_at,
				Vector3(6.8, 3.6, 5.5) * scale_factor,
				_island_three_canopy_material(fragment_index + crown_index + 1))
			(canopy.mesh as SphereMesh).radial_segments = 7
			(canopy.mesh as SphereMesh).rings = 4
		for beacon_index in 3:
			var beacon_angle := TAU * float(beacon_index) / 3.0 + PI * .5
			var beacon_at := Vector3(sin(beacon_angle) * 11.0, 2.3,
				cos(beacon_angle) * 8.5) * scale_factor
			_add_brick(fragment, "SkyBeacon_%02d" % (beacon_index + 1), beacon_at,
				Bricks.build_crystal(.55 * scale_factor, 3.0 * scale_factor, .18, 6),
				_materials.shared_style_cyan if beacon_index != 1 \
				else _materials.shared_style_lavender)
		for pier_side in [-1.0, 1.0]:
			_add_box(fragment,
				"SkyPorticoPier%s" % ("Left" if pier_side < 0 else "Right"),
				Vector3(4.5, 4.2, float(pier_side) * 5.2) * scale_factor,
				Vector3(2.2, 8.4, 2.2) * scale_factor,
				_materials.shared_style_ivory, false)
		_add_box(fragment, "SkyPorticoLintel", Vector3(4.5, 8.6, 0) * scale_factor,
			Vector3(2.4, 1.2, 12.5) * scale_factor,
			_materials.shared_style_ivory, false)
		_add_brick(fragment, "SkyPorticoCrown", Vector3(4.5, 11.0, 0) * scale_factor,
			Bricks.build_crystal(.75 * scale_factor, 3.6 * scale_factor, .2, 6),
			_materials.shared_style_lavender if fragment_index == 0 \
			else _materials.shared_style_cyan)
		# These distant silhouettes never touch the player route. Their long sun
		# shadows previously crossed the court even after the geometry moved out of
		# the reflection sightline, making the clean paving look obstructed.
		for mesh_value in fragment.find_children("*", "MeshInstance3D", true, false):
			var mesh := mesh_value as MeshInstance3D
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.set_meta("decorative_sky_shadow_disabled", true)



func _build_island_three_planted_room(parent: Node3D, center: Vector3, index: int) -> void:
	var garden := Node3D.new()
	garden.name = "PlantedCourt_%02d" % (index + 1)
	garden.set_meta("clear_boss_radius_m", 48.0)
	parent.add_child(garden)
	# Small, solid planting islands frame the circulation, never cross it.
	_add_box(garden, "IvoryPlantingBed", center + Vector3.UP * .6,
		Vector3(22, 1.2, 14), _materials.shared_style_ivory, true)
	_add_box(garden, "RecessedEarth", center + Vector3.UP * 1.22,
		Vector3(20.4, .12, 12.4), _materials.island_three_earth)
	for shrub_index in 5:
		var shrub_at := center + Vector3(float(shrub_index % 3 - 1) * 6.2,
			2.3, float(shrub_index / 3 - 1) * 3.5)
		var shrub := _add_sphere(garden, "PlantingMass_%02d" % shrub_index,
			shrub_at, Vector3(6.0, 2.5, 4.5), _materials.island_three_sage)
		(shrub.mesh as SphereMesh).radial_segments = 7
		(shrub.mesh as SphereMesh).rings = 3
	_build_island_three_garden_tree(garden, "ShadeTree", center + Vector3(-5, 1.2, 0),
		2.65 if index < 2 else 2.9, index)
	# One mature tree per room leaves a readable view across the storm court.
	# Benches sit outside the bed; their visible seats and feet are solid.
	for side in [-1.0, 1.0]:
		var seat_at := center + Vector3(side * 7, 1.1, -10)
		_add_box(garden, "IvoryBench_%s" % side, seat_at,
			Vector3(7, .65, 2.4), _materials.shared_style_ivory, true)
		for foot in [-1.0, 1.0]:
			_add_box(garden, "BenchFoot_%s_%s" % [side, foot],
				seat_at + Vector3(foot * 2.3, -.65, 0), Vector3(.8, 1.1, 1.8),
				_materials.shared_style_charcoal, true)


func _build_island_three_environment_bay(parent: Node3D, bay_name: String,
		center: Vector3, radial_angle: float, variant: int, with_arcade: bool) -> void:
	var bay := Node3D.new()
	bay.name = bay_name
	bay.set_meta("shared_environment_family", "island_one_two_civic_garden")
	bay.set_meta("player_collision_backed", true)
	parent.add_child(bay)
	var tangent_yaw := radial_angle + PI * .5
	_add_box(bay, "IvoryGardenTerrace", center + Vector3.UP * .18,
		Vector3(18.0, .36, 10.0), _materials.shared_style_ivory, true, tangent_yaw)
	_add_box(bay, "CharcoalTerraceReveal", center - Vector3.UP * .12,
		Vector3(15.8, .28, 8.2), _materials.island_three_earth, false, tangent_yaw)
	var radial := Vector3(sin(radial_angle), 0, cos(radial_angle))
	var tangent := Vector3(radial.z, 0, -radial.x)
	_add_box(bay, "RecessedPlantingSoil", center + Vector3.UP * .39,
		Vector3(15.2, .10, 7.5), _materials.island_three_earth, false, tangent_yaw)
	for shrub_index in 5:
		var shrub := _add_sphere(bay, "SageGroundCover_%02d" % shrub_index,
			center + tangent * float(shrub_index - 2) * 2.7 + radial * 2.4 + Vector3.UP * 1.15,
			Vector3(1.7, .9, 1.4), _materials.island_three_sage)
		(shrub.mesh as SphereMesh).radial_segments = 7
		(shrub.mesh as SphereMesh).rings = 4
	# The storm court keeps sightlines to its three landmarks; the quieter tree
	# district retains a continuous garden canopy around the sanctuary.
	if variant >= 20 or variant % 3 == 0:
		_build_island_three_garden_tree(bay, "LivingGardenTree", center + radial * 1.0,
			1.25 + float(variant % 3) * .12, variant)
	if variant % 3 == 0:
		for marker_side in [-1.0, 1.0]:
			var marker_at := center + tangent * float(marker_side) * 6.8 + Vector3.UP * 1.4
			_add_brick(bay, "GardenMarker%s" % ("Left" if marker_side < 0 else "Right"),
				marker_at, Bricks.build_crystal(.42, 2.8, .16, 6),
				_materials.shared_style_cyan)
	if not with_arcade:
		return
	for pier_side in [-1.0, 1.0]:
		var pier_at := center + tangent * float(pier_side) * 7.0 - radial * 2.8
		_add_cylinder(bay, "ArcadePier%s" % ("Left" if pier_side < 0 else "Right"),
			pier_at + Vector3.UP * 4.7, .72, 8.8,
			_materials.shared_style_ivory, true, 10)
		_add_sphere(bay, "ArcadeLantern%s" % ("Left" if pier_side < 0 else "Right"),
			pier_at + Vector3.UP * 10.0, Vector3(.55, .78, .55),
			_materials.shared_style_cyan)
	_add_box(bay, "IvoryArcadeLintel", center - radial * 2.8 + Vector3.UP * 9.0,
		Vector3(15.2, .72, 1.0), _materials.shared_style_ivory, false, tangent_yaw)
	_add_box(bay, "CyanArcadeClerestory", center - radial * 2.25 + Vector3.UP * 8.95,
		Vector3(10.5, .20, .18), _materials.shared_style_cyan, false, tangent_yaw)


func _build_island_three_garden_tree(parent: Node3D, tree_name: String,
		base: Vector3, tree_scale: float, variant: int) -> void:
	var tree := Node3D.new()
	tree.name = tree_name
	tree.set_meta("shared_tree_language", "faceted living-light garden tree")
	tree.set_meta("tree_scale", tree_scale)
	tree.set_meta("branch_count", 3)
	tree.set_meta("canopy_cluster_count", 6)
	parent.add_child(tree)
	var trunk_height := 7.4 * tree_scale
	_add_cylinder(tree, "GardenTrunk", base + Vector3.UP * trunk_height * .5,
		.72 * tree_scale, trunk_height, _materials.island_three_hero_bark, true, 7)
	_add_cable_between(tree, "CyanNutrientVein", base + Vector3.UP * .4,
		base + Vector3(.2, trunk_height + 2.8, -.15), .11, .06,
		_materials.shared_style_cyan, 6)
	for branch_index in 3:
		var angle := TAU * float(branch_index) / 3.0 + float(variant) * .31
		var branch_start := base + Vector3.UP * (trunk_height * .68)
		var branch_end := base + Vector3(sin(angle) * 3.7 * tree_scale,
			trunk_height + (1.0 + float(branch_index % 2)) * tree_scale,
			cos(angle) * 3.7 * tree_scale)
		_add_cable_between(tree, "GardenBranch_%02d" % (branch_index + 1),
			branch_start, branch_end, .36 * tree_scale, .15 * tree_scale,
			_materials.island_three_hero_bark, 7)
		for crown_index in 2:
			var crown_at := branch_end + Vector3(
				(-1.0 if crown_index == 0 else 1.0) * 1.4 * tree_scale,
				float(crown_index) * .7, 0)
			var canopy_material: Material = _island_three_canopy_material(
				variant + branch_index + crown_index)
			var canopy := _add_sphere(tree,
				"GardenCanopy_%02d_%02d" % [branch_index + 1, crown_index + 1],
				crown_at, Vector3(5.8, 3.2, 5.0) * tree_scale, canopy_material)
			(canopy.mesh as SphereMesh).radial_segments = 7
			(canopy.mesh as SphereMesh).rings = 4


func _island_three_canopy_material(variant: int) -> Material:
	# Ivory is a blossom accent, never the dominant leaf colour. The earlier
	# four-to-one ivory ratio caused every tree to disappear into the masonry in
	# both the gameplay camera and the island overview.
	match posmod(variant, 5):
		0:
			return _materials.island_three_canopy_ivory
		1, 4:
			return _materials.island_three_sage
		2:
			return _materials.island_three_sage_deep
		_:
			return _materials.island_three_moss


func _build_island_three_garden_pavilion(parent: Node3D, pavilion_name: String,
		center: Vector3, variant: int) -> void:
	var pavilion := Node3D.new()
	pavilion.name = pavilion_name
	pavilion.set_meta("shared_architecture_family", "island_two_observatory_island_one_living_light")
	pavilion.set_meta("open_walkable_pavilion", true)
	parent.add_child(pavilion)
	_add_cylinder(pavilion, "IvoryPavilionDais", center + Vector3.UP * .28,
		13.0, .56, _materials.shared_style_ivory, true, 16)
	_add_cylinder(pavilion, "CharcoalPavilionReveal", center + Vector3.UP * .62,
		11.4, .20, _materials.shared_style_charcoal, false, 16)
	for column_index in 8:
		var angle := TAU * float(column_index) / 8.0
		var column_at := center + Vector3(sin(angle) * 9.2, 0, cos(angle) * 9.2)
		_add_cylinder(pavilion, "PavilionColumn_%02d" % (column_index + 1),
			column_at + Vector3.UP * 6.2, .62, 11.2,
			_materials.shared_style_ivory, true, 10)
		_add_sphere(pavilion, "PavilionLamp_%02d" % (column_index + 1),
			column_at + Vector3.UP * 12.3, Vector3(.52, .72, .52),
			_materials.shared_style_cyan if column_index % 2 == 0 \
			else _materials.shared_style_lavender)
	_add_cylinder(pavilion, "IvoryPavilionEave", center + Vector3.UP * 11.7,
		11.6, .72, _materials.shared_style_ivory, false, 16)
	var dome := _add_sphere(pavilion, "FacetedPavilionDome", center + Vector3.UP * 14.4,
		Vector3(10.8, 7.2, 10.8), _materials.island_three_roof)
	(dome.mesh as SphereMesh).radial_segments = 12
	(dome.mesh as SphereMesh).rings = 5
	_add_brick(pavilion, "PavilionCrownCrystal", center + Vector3.UP * 24.0,
		Bricks.build_crystal(1.1, 4.6, .3, 6),
		_materials.shared_style_lavender if variant % 2 == 0 \
		else _materials.shared_style_cyan)
	_build_island_three_garden_tree(pavilion, "PavilionLivingTree", center,
		.72, variant + 40)
	for child in pavilion.get_children():
		if child is Node3D:
			child.position -= center
	pavilion.position = center
	pavilion.scale = Vector3(1.68, 1.72, 1.68)



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
				ring.mesh = null
				ring.material_override = null
				ring.set_meta("retired_geometry_purged", true)
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
			# The two imported v11 floor inlays are authored in normalised asset
			# space and inherit the island foundation's large scale. Their raw mesh
			# is only 2.19 units wide, so the old local-size heuristic missed the
			# screen-wide gold wedges visible at the Storm Lens and sanctuary. The
			# replacement ivory decks already cover their gameplay role.
			var is_imported_foundation_inlay := line.name in [
				&"Inlay_v11_05", &"Inlay_v11_06",
			] and "/ModularFloatingFoundation/IslandArchitecture/" in str(line.get_path())
			if (is_long_line and _is_island_three_gold_material(
					_effective_mesh_material(line))) \
					or is_obsolete_root_rail \
					or (is_imported_foundation_inlay and _is_island_three_gold_material(
						_effective_mesh_material(line))):
				line.visible = false
				line.set_meta("island_three_gold_line_removed", true)
				line.mesh = null
				line.material_override = null
				line.set_meta("retired_geometry_purged", true)
				removed_count += 1
	var visible_gold_line_count := 0
	for search_root in roots:
		for candidate in search_root.find_children("*", "MeshInstance3D", true, false):
			var line := candidate as MeshInstance3D
			if not line.visible or not _is_island_three_gold_material(
					_effective_mesh_material(line)):
				continue
			var is_imported_foundation_inlay := line.name in [
				&"Inlay_v11_05", &"Inlay_v11_06",
			] and "/ModularFloatingFoundation/IslandArchitecture/" in str(line.get_path())
			if is_imported_foundation_inlay:
				visible_gold_line_count += 1
			elif line.mesh is CylinderMesh:
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
		["circuit_wisp", "boss_adds", "05_thought_storm_arena", Vector3(-48, 4, -54)],
		["static_mite", "boss_adds", "05_thought_storm_arena", Vector3(48, 4, -54)],
	]
	# Island Two's completed story is a peaceful evidence and perspective chapter.
	# Its five former combat actors were still built, hidden, stripped of their
	# meshes and retained as empty compatibility nodes on every startup. No save
	# data or active quest references those actors, so omit them at the source.
	# Island One keeps its four teaching encounters and Island Three keeps its two
	# Warden adds.
	if _uses_existing_mind_district():
		specs = [
			["static_mite", "network", "02_living_network_forest", Vector3(-18, 1, 16)],
			["static_mite", "network", "02_living_network_forest", Vector3(19, 1, 19)],
			["glitch_sprout", "network", "02_living_network_forest", Vector3(-22, 1, -14)],
			["glitch_sprout", "network", "02_living_network_forest", Vector3(24, 1, -12)],
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
	var progression_hud := preload(
		"res://scripts/mind_spark/world_one_progression_hud.gd").new()
	progression_hud.name = "WorldOneProgressionHUD"
	canvas.add_child(progression_hud)


func _update_hud() -> void:
	if _prompt == null:
		return
	var panel := _prompt.get_parent() as Control
	var gate_button := _nearest_gate_interaction_button()
	if gate_button != null:
		panel.visible = true
		var gate_kind := str(gate_button.get_meta("gate_kind", "quest"))
		var unlocked := false
		var opened := false
		if gate_kind == "island_one":
			var island_gate := get_island_one_heavenly_star_gate()
			unlocked = island_gate != null and bool(island_gate.get_meta("gate_interaction_unlocked", false))
			opened = is_island_one_star_gate_open()
		else:
			var gate_index := int(gate_button.get_meta("quest_gate_index", -1))
			if gate_index >= 0 and gate_index < _quest_gates.size():
				var gate := _quest_gates[gate_index]
				unlocked = bool(gate.get_meta("gate_interaction_unlocked", false))
				opened = bool(gate.get_meta("open", false))
		_prompt.text = "Q • %s CELESTIAL GATE" % ("CLOSE" if opened else "OPEN")
		_status.text = "GATE CONTROL READY" if unlocked else "LOCKED • COMPLETE THIS ISLAND'S QUEST"
		return
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
		_player.global_position = _last_safe_position
		_player.velocity = Vector3.ZERO


func _build_organized_bio_tree_world(geometry: Node3D) -> void:
	var layout_root := Node3D.new()
	layout_root.name = "OrganizedMindSparkBioTreeWorld"
	layout_root.set_meta("planned_tree_total", 100)
	layout_root.set_meta("placement_policy", "authored deterministic rows, rings and arcs; no randomness")
	layout_root.set_meta("size_policy", "seeded random small-to-large scale; stable between game loads")
	layout_root.set_meta("hero_tree_count", 1)
	layout_root.set_meta("optimized_grove_tree_count", 83)
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
	set_meta("organized_tree_distribution", "10/30/14/14/4/12")


func _clear_garden_position(zone: Node3D, preferred: Vector3, tree_scale: float,
		excluded_tree: Node3D = null) -> Vector3:
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
			if tree == excluded_tree:
				continue
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
	var opening_half_width := ISLAND_THREE_ARRIVAL_EDGE_OPENING_HALF_WIDTH \
		if zone_index == 4 else (30.0 if zone_index < 2 else 18.0)
	return not (radial.dot(direction) > 0 and absf(radial.cross(direction))*radius < opening_half_width)


func _repair_island_one_legacy_openings(parent: Node3D, first_zone := 0) -> void:
	var repairs := Node3D.new()
	repairs.name = ["IslandOnePerimeterRepairs", "IslandTwoPerimeterRepairs", "IslandThreePerimeterRepairs"][first_zone / 2]
	repairs.set_meta("preserve_authored_nodes", true)
	var web_shared_perimeter := first_zone >= 2 and _uses_web_render_budget()
	var rail_bay_scene: PackedScene = preload(
		"res://assets3D/mind_spark/echo_garden_benchmark/export/rail_bay_web.glb") \
		if web_shared_perimeter else preload(
		"res://assets3D/mind_spark/echo_garden_benchmark/export/rail_bay.glb")
	var rail_post_scene: PackedScene = preload(
		"res://assets3D/mind_spark/echo_garden_benchmark/export/rail_post_web.glb") \
		if web_shared_perimeter else preload(
		"res://assets3D/mind_spark/echo_garden_benchmark/export/rail_post.glb")
	if web_shared_perimeter:
		repairs.set_meta("web_low_poly_perimeter", true)
		repairs.set_meta("web_rail_source_triangle_reduction", "6488->1167 bay; 4146->829 post")
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
					var panel := rail_bay_scene.instantiate() as Node3D
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
						var post := rail_post_scene.instantiate() as Node3D
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
	if first_zone == 4:
		repairs.set_meta("barrier_style", "island_one_two_civic_railing")
		repairs.set_meta("route_openings_preserved", true)
	if first_zone >= 2:
		_consolidate_perimeter_posts(repairs)


func _build_island_three_edge_run(parent: Node3D, center: Vector3, radius: float,
		start_angle: float, finish_angle: float, zone_index: int, bay: int) -> void:
	# The older lantern-scrollwork kit repeats too densely around the storm
	# district. These low, broad stone facets preserve the exact exposed-arc
	# openings while giving the three quest buildings a quieter skyline.
	var pieces := maxi(1, ceili((finish_angle - start_angle) / (TAU / 48.0)))
	var floor_y := _zone_floor_surface_y(center)
	for piece in pieces:
		var a := lerpf(start_angle, finish_angle, float(piece) / float(pieces))
		var b := lerpf(start_angle, finish_angle, float(piece + 1) / float(pieces))
		var from := center + Vector3(sin(a) * radius, 0, cos(a) * radius)
		var to := center + Vector3(sin(b) * radius, 0, cos(b) * radius)
		var chord := to - from
		var at := from.lerp(to, 0.5)
		var yaw := atan2(chord.x, chord.z)
		var panel_name := "StormEdgeStone_%d_%02d_%d" % [zone_index, bay, piece]
		var panel_at := Vector3(at.x, floor_y + 1.2, at.z)
		var panel_size := Vector3(1.8, 2.4, chord.length() + 0.45)
		var panel := _add_brick(parent, panel_name, panel_at,
			Bricks.build_bevel_box(panel_size, 0.18),
			_materials.sanctum_ivory, yaw)
		panel.set_meta("edge_role", "low faceted parapet")
		var solid := _add_box(parent, panel_name + "Solid", panel_at,
			panel_size, _materials.sanctum_ivory, true, yaw)
		solid.visible = false
		# Ivory lantern piers echo the finished garden edge on Islands One and
		# Two. They punctuate the parapet without making a continuous bright line.
		if bay % 3 == 0 and piece == 0:
			var pier_at := Vector3(from.x, floor_y, from.z)
			_add_brick(parent, "StormEdgePier_%d_%02d" % [zone_index, bay],
				pier_at + Vector3.UP * 2.3,
				Bricks.build_bevel_box(Vector3(2.8, 4.6, 2.8), 0.26),
				_materials.sanctum_ivory)
			_add_cylinder(parent, "StormEdgeLanternBase_%d_%02d" % [zone_index, bay],
				pier_at + Vector3.UP * 5.0, 1.05, .8,
				_materials.sanctum_ivory, false, 8)
			_add_sphere(parent, "StormEdgeLantern_%d_%02d" % [zone_index, bay],
				pier_at + Vector3.UP * 6.6, Vector3(.83, 1.45, .83),
				_materials.island_three_canopy_ivory)
			_add_cylinder(parent, "StormEdgeLanternCap_%d_%02d" % [zone_index, bay],
				pier_at + Vector3.UP * 8.2, 1.1, .45,
				_materials.sanctum_ivory, false, 8)


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
	if str(parent.get_meta("zone_id", "")) in [
		"01_world_gate_landing", "02_living_network_forest",
		"05_thought_storm_arena", "06_oldest_tree_sanctuary"]:
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


func _add_circuit_walkway(parent: Node3D, node_name: String, start: Vector3,
		finish: Vector3, width: float, with_rails := true) -> void:
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
	if not with_rails:
		return
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
	# Rain Harvest shares the production teal glass used by the other islands.
	# Reusing the material keeps its broad dome translucent without introducing
	# an extra Web spatial batch for a one-landmark finish.
	_materials.rain_glass = _materials.arrival_glass
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
		Color("d9d0bd"), Color("eee6d5"), Color("a88f6b"), 0.76, 28)
	_materials.celestial_floor.metallic = 0.02
	_materials.celestial_floor.metallic_specular = 0.22
	# A warmer, softly luminous finish keeps the Thought Sanctum distinct and
	# readable beneath the glass conservatory without turning it into neon.
	_materials.sanctum_ivory = _material(
		Color("fff1d7"), 0.30, Color("ffdf9d"), 0.16)
	_materials.sanctum_ivory.metallic_specular = 0.58
	_materials.sanctum_dial = _material(
		Color("214f5c"), 0.22, Color("70e3db"), 0.52)
	_materials.sanctum_dial.metallic = 0.10
	_materials.sanctum_dial.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials.sanctum_lavender_glass = _material(
		Color("b89ad8", 0.38), 0.24, Color("d8b8ff"), 0.30)
	_materials.sanctum_lavender_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials.sanctum_lavender_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	# One exact palette is shared by Island One's light tree and quest machines
	# and Island Three's sanctuary. Keeping the material resources identical
	# prevents the later island from drifting into a separate visual language.
	_materials.shared_style_ivory = _low_poly_surface_material(
		Color("d8ccb5"), Color("ede2cc"), Color("a78d68"), .78, .02, 71, 18)
	_materials.shared_style_charcoal = _material(
		Color("263443"), .62, Color("214e60"), .18)
	_materials.shared_style_cyan = _material(
		Color("38bfd0"), .26, Color("54e5f2"), 1.05)
	_materials.shared_style_lavender = _material(
		Color("9173b5"), .38, Color("c39aef"), .48)
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
	_materials.island_three_hero_bark = _material(Color("6b4b39"), 0.86)
	# Keep the highlight cool-red enough that the Island 3 gold-line cleanup does
	# not mistake this organic bark facet for brass and retire its mesh.
	_materials.island_three_hero_bark_highlight = _material(Color("8a5450"), 0.82)
	_materials.island_three_hero_bark_shadow = _material(Color("3f2d2a"), 0.92)
	_materials.island_three_sage = _material(Color("a7b59b"), 0.88)
	_materials.island_three_sage_deep = _material(Color("667b6a"), 0.92)
	_materials.island_three_moss = _material(Color("c0c39a"), 0.88)
	_materials.island_three_earth = _material(Color("6f6456"), 0.94)
	# The jointed paving deliberately leaves hairline mortar gaps. A flat pearl
	# base keeps those gaps quiet; the shared celestial floor's procedural gold
	# flecks previously appeared as detached route-line shards in quest cameras.
	_materials.island_three_paving_base = _material(Color("e9dfcb"), 0.94)
	_materials.island_three_canopy_ivory = _material(Color("e8ddc3"), 0.90)
	_materials.island_three_roof = _material(Color("b8cac3"), 0.58)
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


func _install_three_island_environment_audio(geometry: Node3D) -> void:
	## Give each fused island a quiet local acoustic identity. These are positional
	## environment layers, not replacement music, and stay beneath interaction,
	## dialogue and combat cues. Rain is present in the soundscape from startup so
	## its playback head can fade in smoothly when recovery changes the world state.
	var soundscape := Node3D.new()
	soundscape.name = "ThreeIslandEnvironmentAudio"
	soundscape.set_meta("design_revision", "district_soundscape_v1")
	soundscape.set_meta("physical_island_count", 3)
	soundscape.set_meta("quest_evidence_audio_only", false)
	geometry.add_child(soundscape)

	var island_one_midpoint: Vector3 = ZONES[0].position.lerp(ZONES[1].position, .58)
	var island_two_midpoint: Vector3 = ZONES[2].position.lerp(ZONES[3].position, .50)
	var stormworks_center: Vector3 = ZONES[4].position + Vector3.UP * 5.0
	var oldest_tree_center: Vector3 = ZONES[5].position + Vector3(0, 6.0, 18.0)
	var rain_observatory_center := stormworks_center + Vector3(0, 0, 105.0)

	var island_one_wind := _add_zone_ambience(soundscape, "IslandOneCanopyWind",
		TreeWindAmbience, -31.0, 210.0)
	island_one_wind.position = island_one_midpoint
	_configure_environment_audio_source(island_one_wind, 1, "living canopy")

	var island_two_engine := _add_zone_ambience(soundscape, "IslandTwoMemoryEngine",
		AetherPowerAmbience, -29.0, 215.0)
	island_two_engine.position = island_two_midpoint
	_configure_environment_audio_source(island_two_engine, 2, "memory observatory machinery")

	var stormworks_engine := _add_zone_ambience(soundscape, "IslandThreeStormworksEngine",
		AetherPowerAmbience, -27.0, 220.0)
	stormworks_engine.position = stormworks_center
	_configure_environment_audio_source(stormworks_engine, 3, "stormworks civic machinery")

	var oldest_tree_wind := _add_zone_ambience(soundscape, "IslandThreeOldestTreeWind",
		TreeWindAmbience, -28.0, 190.0)
	oldest_tree_wind.position = oldest_tree_center
	_configure_environment_audio_source(oldest_tree_wind, 3, "oldest tree canopy")

	_gentle_rain_ambience = _add_zone_ambience(soundscape, "RainHarvestRecoveryWater",
		RainWaterAmbience, -80.0, 150.0)
	_gentle_rain_ambience.position = rain_observatory_center
	_configure_environment_audio_source(_gentle_rain_ambience, 3, "recovered rain water")
	_gentle_rain_ambience.set_meta("unlocks_on_world_state", "gentle_rain")
	_gentle_rain_ambience.set_meta("inactive_volume_db", -80.0)
	_gentle_rain_ambience.set_meta("active_volume_db", -24.0)


func _configure_environment_audio_source(audio: AudioStreamPlayer3D,
		physical_island: int, sound_role: String) -> void:
	audio.unit_size = 34.0
	audio.max_db = -9.0
	audio.panning_strength = 1.0
	audio.set_meta("physical_island", physical_island)
	audio.set_meta("sound_role", sound_role)
	audio.set_meta("non_blocking_environment_layer", true)


func _refresh_environment_audio(world_state: String) -> void:
	if not is_instance_valid(_gentle_rain_ambience):
		return
	var target_db := -24.0 if world_state == "gentle_rain" else -80.0
	_gentle_rain_ambience.set_meta("target_volume_db", target_db)
	if AudioServer.get_driver_name() == "Dummy" \
			or not is_inside_tree() or not _gentle_rain_ambience.is_inside_tree():
		_gentle_rain_ambience.volume_db = target_db
		return
	if _gentle_rain_fade_tween != null and _gentle_rain_fade_tween.is_valid():
		_gentle_rain_fade_tween.kill()
	_gentle_rain_fade_tween = create_tween()
	_gentle_rain_fade_tween.tween_property(
		_gentle_rain_ambience, "volume_db", target_db, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _add_zone_ambience(parent: Node3D, node_name: String, stream: AudioStream,
		volume_db_value: float, max_distance_value: float) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.name = node_name
	# Imported ambience files are intentionally shared by several worlds and are
	# not globally marked to loop. Duplicate them here so World One's local beds
	# continue for the whole visit without mutating another scene's resource.
	var local_stream := stream.duplicate() as AudioStream
	if local_stream is AudioStreamOggVorbis:
		(local_stream as AudioStreamOggVorbis).loop = true
	elif local_stream is AudioStreamWAV:
		var wav := local_stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * float(wav.mix_rate)))
	audio.stream = local_stream
	audio.volume_db = volume_db_value
	audio.max_distance = max_distance_value
	audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	audio.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	audio.bus = &"Ambience"
	audio.autoplay = true
	audio.set_meta("continuous_loop", true)
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


# --- Three-island physical geometry ------------------------------------------


func _install_three_island_static_collisions(geometry: Node3D) -> void:
	# Imported art and the research-campus kit mix large architecture with floor
	# engraving, moving indicators, foliage and light effects. Only the explicit
	# gameplay inventory below becomes solid. Consolidate those selected forms
	# into one body before visual batching retires the source MeshInstance3D nodes.
	# StaticBody3D represents infinite mass, so the player cannot push or pass
	# through these structures.
	var collision_body := StaticBody3D.new()
	collision_body.name = "ThreeIslandVisibleObjectCollisions"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 1
	collision_body.set_meta("mass_class", "infinite_static_mass")
	collision_body.set_meta("collision_role", "three_island_visible_objects")
	collision_body.set_meta("inventory_revision", "reviewed_architecture_v2")
	geometry.add_child(collision_body)
	var station_spur := geometry.get_node_or_null("OptionalCompletedWorldStationSpur")
	if station_spur != null:
		geometry.move_child(collision_body, station_spur.get_index())

	var roots: Array[Node] = []
	for path in [
		"01WorldGateLanding",
		"02LivingNetworkForest",
		"03ConstellationCourt",
		"04HopePathRidge",
		"05ThoughtStormArena",
		"06OldestTreeSanctuary",
		"ThreeFusedSuperIslands/FusedSuperIsland_01_02",
		"ThreeFusedSuperIslands/FusedSuperIsland_03_04",
		"ThreeFusedSuperIslands/FusedSuperIsland_05_06",
		"IslandOnePerimeterRepairs",
		"IslandTwoPerimeterRepairs",
		"IslandThreePerimeterRepairs",
		"IslandThreeCivicSanctuary",
	]:
		var root_node := geometry.get_node_or_null(path)
		if root_node != null:
			roots.append(root_node)
	var campus_root := get_node_or_null("IslandOneResearchCampus")
	if campus_root != null:
		roots.append(campus_root)
	for campus_path in ["IslandTwoMemoryCampus", "GardenOfUnfinishedLight"]:
		var island_root := get_node_or_null(campus_path)
		if island_root != null:
			roots.append(island_root)

	var seen := {}
	var collision_count := 0
	var inventory_counts := {}
	var island_counts := {}
	for collision_root in roots:
		for candidate in collision_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if mesh_instance == null or seen.has(mesh_instance.get_instance_id()):
				continue
			seen[mesh_instance.get_instance_id()] = true
			var physical_island := _web_detail_island_for_node(mesh_instance)
			if physical_island == 0 and collision_root.has_meta("super_island_index"):
				physical_island = int(collision_root.get_meta("super_island_index", 0))
			if not _is_solid_three_island_mesh(mesh_instance, collision_root,
					physical_island):
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
			var inventory_role := _three_island_collision_inventory_role(
				mesh_instance, physical_island)
			shape_node.set_meta("inventory_role", inventory_role)
			collision_body.add_child(shape_node)
			collision_count += 1
			inventory_counts[inventory_role] = int(inventory_counts.get(inventory_role, 0)) + 1
			var island_key := "island_%d_visible_object" % physical_island
			island_counts[island_key] = int(island_counts.get(island_key, 0)) + 1

	collision_body.set_meta("collision_shape_count", collision_count)
	collision_body.set_meta("inventory_counts", inventory_counts)
	set_meta("three_island_visible_object_collision_count", collision_count)
	set_meta("island_one_visible_object_collision_count",
		int(island_counts.get("island_1_visible_object", 0)))
	set_meta("three_island_collision_inventory", inventory_counts)
	set_meta("three_island_collision_counts", island_counts)


func _is_solid_three_island_mesh(mesh_instance: MeshInstance3D,
		collision_root: Node, physical_island: int) -> bool:
	if mesh_instance.mesh == null or not mesh_instance.is_visible_in_tree():
		return false
	if _three_island_collision_inventory_role(mesh_instance, physical_island).is_empty():
		return false
	if mesh_instance.has_meta("detail_packet") or mesh_instance.has_meta("detail_orbit_speed"):
		return false
	if str(mesh_instance.get_meta("physical_role", "")).begins_with("flush non-solid"):
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


func _island_one_collision_inventory_role(mesh_instance: MeshInstance3D) -> String:
	# This allowlist is intentionally path and role based. Adding a decorative
	# mesh anywhere on Island One must not silently make it a player obstacle.
	# New solid families are reviewed here and exercised by the capsule tests.
	if mesh_instance == null or bool(mesh_instance.get_meta("decorative_floor_inset", false)):
		return ""
	var source := str(mesh_instance.get_path())
	var key := mesh_instance.name.to_lower()
	if "/PuzzleControls/" in source:
		return "learning_instrument"
	if "/IslandOneResearchCampus/" in source:
		return "quest_cabinet"
	if "DesignedBioTreeGrove/" in source:
		return "garden_tree_trunk" if key.ends_with("_warmbark") else ""
	if "/ScienceArtGarden/CognitiveLightTree/" in source:
		if key.begins_with("treeivorytrunk_") or key.begins_with("treestructuralroot_"):
			return "hero_tree_structure"
		return ""
	if "/CompassMachine/" in source:
		for solid_token in [
			"ringbody", "compassheartivory", "compassheartaethercore",
			"thoughtframe", "sanctumfoundation", "sanctumsteppedplinth",
			"sanctumflutedpylon", "sanctumpylonfoot", "sanctumgovernorcase",
		]:
			if solid_token in key:
				return "compass_structure"
		return ""
	if "/GateArchitectureKit/02_AetherConservatoryKit/" in source \
			or "/GateArchitectureKit/03_ThresholdStructureKit/" in source \
			or "/GateArchitectureKit/04_BeaconTowerKit/" in source:
		return "arrival_architecture"
	if "/LivingLightAtelierArchitecture/" in source:
		if key.begins_with("atelierbalustraderail_") \
				or key.begins_with("atelierbaluster_") \
				or key.begins_with("atelierrootlightwell"):
			return "atelier_architecture"
		return ""
	if "/EchoGardenQuestArchitecture/" in source \
			or "/LivingLightLaboratoryRoutes/" in source:
		return "quest_support"
	if "/IslandOnePerimeterRepairs/" in source:
		return "perimeter_architecture"
	if "/ModularFloatingFoundation/IslandArchitecture/" in source:
		return "foundation_architecture"
	if "/EchoTreeListeningCrescent/" in source:
		return "listening_pavilion"
	if "/MSI1_Runtime_GameplayArchitecture/" in source:
		return "authored_overlay_architecture"
	if "/VisualRoot/BlenderModel/" in source:
		return "quest_machine"
	return ""


func _three_island_collision_inventory_role(mesh_instance: MeshInstance3D,
		physical_island: int) -> String:
	var island_one_role := _island_one_collision_inventory_role(mesh_instance)
	if not island_one_role.is_empty():
		return island_one_role
	if physical_island not in [2, 3] or mesh_instance == null:
		return ""
	if bool(mesh_instance.get_meta("decorative_floor_inset", false)) \
			or bool(mesh_instance.get_meta("intentionally_non_solid", false)) \
			or bool(mesh_instance.get_meta("non_solid_guidance", false)):
		return ""
	var key := mesh_instance.name.to_lower()
	# Existing island floors, approaches and water are already backed by simple
	# collision. Signals, foliage and flush trim remain pass-through so a visible
	# route never gains hidden ankle-height blockers.
	for token in ["floor", "deck", "court", "path", "route", "lane", "walk",
			"promenade", "approach", "landing", "terrace", "dais", "threshold", "paving", "inlay", "channel",
			"water", "pool", "basin", "ripple", "line", "ribbon", "marker",
			"glow", "light", "halo", "aura", "ring", "orbit", "beam",
			"canopy", "leaf", "foliage", "flower", "petal", "grass",
			"gate", "portal", "door", "conduit", "socket"]:
		if token in key:
			return ""
	var bounds := mesh_instance.mesh.get_aabb().size * mesh_instance.scale.abs()
	if maxf(bounds.x, maxf(bounds.y, bounds.z)) < 0.18:
		return ""
	return "island_%d_visible_object" % physical_island


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
	if _uses_web_render_budget():
		set_meta("web_spatial_repeated_batching", true)
	var groups := {}
	_collect_batchable(root, groups, root)
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


func _collect_batchable(node: Node, groups: Dictionary,
		batch_root: Node3D = null) -> void:
	if batch_root == null and node is Node3D:
		batch_root = node as Node3D
	# A root-level MultiMesh cannot inherit a retired assembly's visibility.
	# Leave hidden source nodes untouched instead of resurrecting their geometry.
	if node is Node3D and not (node as Node3D).is_visible_in_tree():
		return
	# Actor descendants are owned by scripts that toggle/animate individual meshes.
	# Moving them into the world batch frees those references and breaks combat.
	if node is MindSparkEnemyBase or node.get_meta("preserve_authored_nodes", false):
		return
	for child in node.get_children():
		_collect_batchable(child, groups, batch_root)
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
	if bool(instance.get_meta("preserve_runtime_node", false)):
		return
	# A script on an ancestor may cache or animate this mesh. Collapsing such a
	# descendant into a MultiMesh leaves the script holding a freed node (enemy
	# telegraphs/cores and animated island packets were the visible failures).
	var ancestor := instance.get_parent()
	while ancestor != null and ancestor != self:
		if ancestor.get_script() != null:
			return
		ancestor = ancestor.get_parent()
	if instance.mesh == null:
		return
	# Group by what is actually drawn: identical primitive parameters and the
	# same material can share one MultiMesh.
	var key := "%s|%s|%s" % [
		instance.mesh.get_class(),
		_mesh_signature(instance.mesh),
		_material_signature(instance.material_override),
	]
	# A single archipelago-wide MultiMesh keeps every instance resident whenever
	# any part of its enormous AABB enters the camera. That saved draw calls but
	# made Web render hundreds of thousands of off-screen repeated triangles.
	# Split only the Web batches into the same spatial cells used by the later
	# static merge pass, allowing frustum culling while retaining one draw per
	# repeated mesh/material inside each visible cell.
	if _uses_web_render_budget():
		var local_origin := batch_root.to_local(instance.global_position)
		var cell_size := _static_render_cell_size(instance)
		var cell := Vector2i(floori(local_origin.x / cell_size),
			floori(local_origin.z / cell_size))
		key += "|cell=%.0f:%d,%d" % [cell_size, cell.x, cell.y]
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


# Retain authored nodes and collision while replacing safe static leaves with a
# much smaller set of render surfaces. Keeping the source nodes makes landmark
# paths, audit metadata and editor inspection stable; clearing only their visual
# layer prevents duplicate drawing. Stateful/scripted branches are excluded.
const STATIC_RENDER_MERGE_MIN_GROUP := 4
const STATIC_RENDER_MERGE_CELL_SIZE := 96.0


func _batch_repeated_static_render_geometry(root: Node3D) -> void:
	var groups := {}
	_collect_repeated_static_leaves(root, root, groups, false)
	var batch_count := 0
	var source_count := 0
	for key in groups:
		var members: Array = groups[key]
		if members.size() < _static_render_merge_minimum(members):
			continue
		var first := members[0] as MeshInstance3D
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = first.mesh
		multi.instance_count = members.size()
		for index in members.size():
			var member := members[index] as MeshInstance3D
			multi.set_instance_transform(index,
				root.global_transform.affine_inverse() * member.global_transform)
		var batch := MultiMeshInstance3D.new()
		batch.name = "BatchedStaticRender_%04d" % batch_count
		batch.multimesh = multi
		batch.material_override = first.material_override
		batch.cast_shadow = first.cast_shadow
		batch.gi_mode = first.gi_mode
		batch.set_meta("merged_static_source_count", members.size())
		batch.set_meta("render_role", "spatial repeated static geometry batch")
		var detail_island := _static_render_detail_island(members)
		if detail_island > 0:
			batch.set_meta("web_detail_island", detail_island)
		root.add_child(batch)
		for member_value in members:
			var member := member_value as MeshInstance3D
			member.layers = 0
			member.set_meta("render_merged_into", batch.name)
			source_count += 1
		batch_count += 1
	set_meta("batched_static_render_groups", batch_count)
	set_meta("batched_static_render_sources", source_count)


func _collect_repeated_static_leaves(node: Node, root: Node3D,
		groups: Dictionary, dynamic_ancestor: bool) -> void:
	if node is Node3D and not (node as Node3D).is_visible_in_tree():
		return
	var dynamic := _static_render_branch_is_dynamic(node, root, dynamic_ancestor)
	for child in node.get_children():
		_collect_repeated_static_leaves(child, root, groups, dynamic)
	if dynamic or not (node is MeshInstance3D):
		return
	var instance := node as MeshInstance3D
	if not _is_static_render_leaf(instance):
		return
	var local_origin := root.to_local(instance.global_position)
	var cell_size := _static_render_cell_size(instance)
	var cell := Vector2i(floori(local_origin.x / cell_size),
		floori(local_origin.z / cell_size))
	var material_id := 0 if instance.material_override == null \
		else instance.material_override.get_instance_id()
	var key := "%.0f:%d,%d|mesh=%d|material=%d|shadow=%d|gi=%d" % [
		cell_size, cell.x, cell.y, instance.mesh.get_instance_id(), material_id,
		instance.cast_shadow, instance.gi_mode,
	]
	if not groups.has(key):
		groups[key] = []
	groups[key].append(instance)


func _merge_static_render_geometry(root: Node3D) -> void:
	var groups := {}
	_collect_static_render_leaves(root, root, groups, false)
	var merged_groups := 0
	var merged_sources := 0
	for key in groups:
		var members: Array = groups[key]
		if members.size() < _static_render_merge_minimum(members):
			continue
		var first := members[0] as MeshInstance3D
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for member_value in members:
			var member := member_value as MeshInstance3D
			surface.append_from(member.mesh, 0,
				root.global_transform.affine_inverse() * member.global_transform)
		var combined := surface.commit()
		if combined == null or combined.get_surface_count() == 0:
			continue
		var batch := MeshInstance3D.new()
		batch.name = "MergedStaticRender_%04d" % merged_groups
		batch.mesh = combined
		batch.material_override = first.material_override
		batch.cast_shadow = first.cast_shadow
		batch.gi_mode = first.gi_mode
		batch.set_meta("merged_static_source_count", members.size())
		batch.set_meta("render_role", "spatial static geometry batch")
		var detail_island := _static_render_detail_island(members)
		if detail_island > 0:
			batch.set_meta("web_detail_island", detail_island)
		root.add_child(batch)
		for member_value in members:
			var member := member_value as MeshInstance3D
			member.layers = 0
			member.set_meta("render_merged_into", batch.name)
			merged_sources += 1
		merged_groups += 1
	# A dormant assembly such as the completed-world station may be merged in a
	# local pass before the whole-world pass. Accumulate both so integrity tests
	# can account for every disabled source and its live replacement exactly once.
	set_meta("merged_static_render_groups",
		int(get_meta("merged_static_render_groups", 0)) + merged_groups)
	set_meta("merged_static_render_sources",
		int(get_meta("merged_static_render_sources", 0)) + merged_sources)


func _collect_static_render_leaves(node: Node, root: Node3D,
		groups: Dictionary, dynamic_ancestor: bool) -> void:
	if node is Node3D and not (node as Node3D).is_visible_in_tree():
		return
	var dynamic := _static_render_branch_is_dynamic(node, root, dynamic_ancestor)
	for child in node.get_children():
		_collect_static_render_leaves(child, root, groups, dynamic)
	if dynamic or not (node is MeshInstance3D):
		return
	var instance := node as MeshInstance3D
	if not _is_static_render_leaf(instance):
		return
	if instance.mesh.get_surface_count() != 1 or instance.material_override == null:
		return
	var local_origin := root.to_local(instance.global_position)
	var cell_size := _static_render_cell_size(instance)
	var cell := Vector2i(floori(local_origin.x / cell_size),
		floori(local_origin.z / cell_size))
	var key := "%.0f:%d,%d|material=%d|shadow=%d|gi=%d" % [
		cell_size, cell.x, cell.y, instance.material_override.get_instance_id(),
		instance.cast_shadow, instance.gi_mode,
	]
	if not groups.has(key):
		groups[key] = []
	groups[key].append(instance)


func _static_render_cell_size(instance: Node) -> float:
	var current := instance
	while current != null and current != self:
		if current.has_meta("static_render_merge_cell_size"):
			return maxf(32.0, float(current.get_meta("static_render_merge_cell_size")))
		current = current.get_parent()
	return STATIC_RENDER_MERGE_CELL_SIZE


func _static_render_detail_island(members: Array) -> int:
	# Render replacements live at the World One root, outside the authored branch
	# whose visibility they replace. Preserve that ownership explicitly so Web
	# streaming cannot hide a distant island's sources while continuing to draw
	# their merged copies. Mixed or unclassified groups stay globally visible.
	var detail_island := 0
	for member_value in members:
		var member_island := _web_detail_island_for_node(member_value as Node)
		if member_island == 0:
			return 0
		if detail_island == 0:
			detail_island = member_island
		elif detail_island != member_island:
			return 0
	return detail_island


func _web_detail_island_for_node(node: Node) -> int:
	var current := node
	while current != null and current != self:
		var physical_island := int(current.get_meta("physical_island", 0))
		if physical_island in [1, 2, 3]:
			return physical_island
		var zone_id := str(current.get_meta("zone_id", ""))
		for zone_info in ZONES:
			if str(zone_info.id) == zone_id:
				return int(zone_info.super_island)
		match str(current.name):
			"IslandOneResearchCampus", "IslandOnePerimeterRepairs":
				return 1
			"IslandTwoMemoryCampus", "GardenOfUnfinishedLight", \
					"IslandTwoPerimeterRepairs":
				return 2
			"IslandThreeCivicSanctuary", "IslandThreePerimeterRepairs", \
					"OptionalCompletedWorldStationSpur":
				return 3
		current = current.get_parent()
	return 0


func _static_render_branch_is_dynamic(node: Node, root: Node3D,
		dynamic_ancestor: bool) -> bool:
	# A scripted landmark may own both animated gameplay and a separately marked
	# inert architecture kit. The marker deliberately ends inherited dynamism at
	# that boundary; scripts below it still re-establish their own exclusion.
	if node != root and bool(node.get_meta("static_render_branch_independent", false)):
		dynamic_ancestor = false
	var scripted := node.get_script() != null \
		and not bool(node.get_meta("allow_static_render_batching", false))
	return dynamic_ancestor or (node != root and (scripted \
		or node is MindSparkEnemyBase or node.has_meta("detail_orbit_speed")))


func _static_render_merge_minimum(members: Array) -> int:
	if members.is_empty():
		return STATIC_RENDER_MERGE_MIN_GROUP
	var current := members[0] as Node
	while current != null and current != self:
		if current.has_meta("static_render_merge_min_group"):
			return maxi(2, int(current.get_meta("static_render_merge_min_group")))
		current = current.get_parent()
	return STATIC_RENDER_MERGE_MIN_GROUP


func _is_static_render_leaf(instance: MeshInstance3D) -> bool:
	if instance.is_queued_for_deletion() or instance.mesh == null \
			or instance.layers != 1 or instance.get_child_count() > 0 \
			or not instance.get_groups().is_empty():
		return false
	if instance.has_meta("detail_packet") \
			or instance.has_meta("detail_orbit_speed"):
		return false
	var lower_name := str(instance.name).to_lower()
	for state_word in ["state", "signal", "packet", "pulse", "door", "gate", "reward", "memoryfruit"]:
		if state_word in lower_name:
			return false
	return true



# The three islands remain mounted as one continuous world so story state,
# bridges and saves never unload. Their thousands of small decorative meshes do
# not need to render across the entire archipelago, though. Give each visible
# mesh a range based on its true world-space size. Nearby details remain exact;
# distant sub-pixel trim stops consuming WebGL draw calls. Nodes, collisions,
# scripts and all authored paths remain intact.
func _configure_world_one_visibility_ranges(root: Node3D) -> void:
	var web_budget := _uses_web_render_budget()
	var range_profile: Array[float] = [90.0, 150.0, 240.0, 420.0, 1200.0]
	if web_budget:
		range_profile = [60.0, 105.0, 175.0, 300.0, 720.0]
	var configured := 0
	var shadow_culled := 0
	var island_two_foundation_lods := 0
	var island_three_foundation_lods := 0
	for candidate in root.find_children("*", "MeshInstance3D", true, false):
		var instance := candidate as MeshInstance3D
		if instance.mesh == null or not instance.visible:
			continue
		var scale := instance.global_transform.basis.get_scale().abs()
		var bounds := instance.mesh.get_aabb().size * scale
		var extent := maxf(bounds.x, maxf(bounds.y, bounds.z))
		var range_end: float = range_profile[4]
		if extent <= 0.4:
			range_end = range_profile[0]
		elif extent <= 1.6:
			range_end = range_profile[1]
		elif extent <= 4.0:
			range_end = range_profile[2]
		elif extent <= 12.0:
			range_end = range_profile[3]
		instance.visibility_range_end = range_end
		instance.visibility_range_end_margin = minf(48.0, range_end * .12)
		# Island Two's two imported foundations account for most of the remaining
		# Web primitives: their architecture, rock and machinery meshes carry
		# generated import LODs, but their very large bounds keep the default
		# screen-space threshold at full detail from a player-height camera. Move
		# only those foundations through their authored LOD chain sooner on Web.
		# Collision is separate and unchanged, and near silhouettes retain the
		# source mesh instead of being replaced with proxy geometry.
		var instance_path := str(root.get_path_to(instance))
		var island_two_foundation := instance_path.contains(
			"03ConstellationCourt/ModularFloatingFoundation") \
			or instance_path.contains("04HopePathRidge/ModularFloatingFoundation")
		var island_three_foundation := instance_path.contains(
			"05ThoughtStormArena/ModularFloatingFoundation") \
			or instance_path.contains("06OldestTreeSanctuary/ModularFloatingFoundation")
		if web_budget and island_two_foundation and instance.mesh is ArrayMesh \
				and extent >= 12.0:
			instance.lod_bias = 0.05
			instance.set_meta("web_lod_profile", "island_two_foundation_0.05")
			island_two_foundation_lods += 1
		elif web_budget and island_three_foundation and instance.mesh is ArrayMesh \
				and extent >= 12.0:
			instance.lod_bias = 0.05
			instance.set_meta("web_lod_profile", "island_three_foundation_0.05")
			island_three_foundation_lods += 1
		# Compatibility redraws each visible surface into the directional shadow
		# atlas. World One retains its low-poly diffuse modelling without those
		# duplicate submissions; ambient occlusion and authored colour contrast
		# continue to describe contact and depth on Web.
		if web_budget \
				and instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shadow_culled += 1
		configured += 1
	for candidate in root.find_children("*", "MultiMeshInstance3D", true, false):
		var instance := candidate as MultiMeshInstance3D
		if instance.multimesh == null:
			continue
		instance.visibility_range_end = 380.0 if web_budget else 560.0
		instance.visibility_range_end_margin = 36.0 if web_budget else 48.0
		if web_budget and instance.cast_shadow \
				!= GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shadow_culled += 1
	set_meta("distance_culled_mesh_count", configured)
	set_meta("visibility_range_profile", "%d/%d/%d/%d/%dm by world-space extent" % range_profile)
	set_meta("web_shadow_culled_mesh_count", shadow_culled)
	set_meta("web_island_two_foundation_lod_count", island_two_foundation_lods)
	set_meta("web_island_three_foundation_lod_count", island_three_foundation_lods)
	if web_budget:
		_configure_web_island_two_quest_detail_ranges()
		_configure_web_island_three_quest_detail_ranges()
		_configure_web_internal_resolution()
		# The production sun's 1,600 m shadow range submits the complete three-
		# island archipelago even when the camera sees only one court. WebGL then
		# redraws millions of off-camera primitives into cascaded shadow maps. The
		# low-poly world keeps its faceted diffuse shading and two-directional-light
		# modelling without this extra pass; native builds retain full shadows.
		call_deferred("_configure_web_directional_shadows")


func _configure_web_island_two_quest_detail_ranges() -> void:
	# Each production research bay is a readable pavilion/cabinet silhouette with
	# small controls inside it. Those controls remain independently animated but
	# do not need to submit from the next station or district. Preserve crowns,
	# state beacons and course silhouettes for long-range quest readability; bring
	# the operational detail back well before the 14 m interaction threshold.
	var configured := 0
	var preserved_silhouettes := 0
	for object in _objects:
		if int(object.get_meta("physical_island", 0)) != 2:
			continue
		for mesh_value in object.find_children("*", "MeshInstance3D", true, false):
			var mesh := mesh_value as MeshInstance3D
			if mesh.mesh == null or mesh.layers == 0:
				continue
			var scale := mesh.global_transform.basis.get_scale().abs()
			var bounds := mesh.mesh.get_aabb().size * scale
			var extent := maxf(bounds.x, maxf(bounds.y, bounds.z))
			var lower_name := str(mesh.name).to_lower()
			var silhouette := "pavilion" in lower_name or "cabinet" in lower_name \
				or "crown" in lower_name or "marker" in lower_name \
				or "course" in lower_name
			if silhouette:
				preserved_silhouettes += 1
				continue
			if extent > 3.5:
				continue
			mesh.visibility_range_end = minf(
				mesh.visibility_range_end if mesh.visibility_range_end > 0.0 else 64.0,
				64.0)
			mesh.visibility_range_end_margin = minf(
				mesh.visibility_range_end_margin if mesh.visibility_range_end_margin > 0.0 else 8.0,
				8.0)
			mesh.set_meta("web_quest_detail_range", 64.0)
			configured += 1
	set_meta("web_island_two_quest_detail_mesh_count", configured)
	set_meta("web_island_two_preserved_silhouette_mesh_count", preserved_silhouettes)


func _configure_web_island_three_quest_detail_ranges() -> void:
	# Island Three's five authored quest models contain many independent pedestal
	# armour plates and circuit studs. They are useful at interaction distance but
	# become sub-pixel draw calls across the broad Stormworks and Reflection Court
	# cameras. Keep the functional object and its readable core silhouette mounted,
	# then retire only small trim beyond 72 m. The 14 m interaction contract brings
	# every part back long before the player can operate the station.
	const DETAIL_RANGE := 72.0
	var configured := 0
	var preserved_silhouettes := 0
	for object in _objects:
		if int(object.get_meta("physical_island", 0)) != 3:
			continue
		for mesh_value in object.find_children("*", "MeshInstance3D", true, false):
			var mesh := mesh_value as MeshInstance3D
			if mesh.mesh == null or mesh.layers == 0:
				continue
			var scale := mesh.global_transform.basis.get_scale().abs()
			var bounds := mesh.mesh.get_aabb().size * scale
			var extent := maxf(bounds.x, maxf(bounds.y, bounds.z))
			var lower_name := str(mesh.name).to_lower()
			var silhouette := "stonebase" in lower_name or "stonecrown" in lower_name \
				or "anchorbody" in lower_name or "crystalspine" in lower_name \
				or "rainbasin" in lower_name or "basinwater" in lower_name \
				or "reflectionsurface" in lower_name or "mirrorframe" in lower_name \
				or "mirrorinnerframe" in lower_name
			if silhouette:
				mesh.visibility_range_end = maxf(mesh.visibility_range_end, 300.0)
				mesh.visibility_range_end_margin = maxf(
					mesh.visibility_range_end_margin, 24.0)
				mesh.set_meta("web_quest_silhouette_range", 300.0)
				preserved_silhouettes += 1
				continue
			if extent > 3.5:
				continue
			mesh.visibility_range_end = minf(
				mesh.visibility_range_end if mesh.visibility_range_end > 0.0 else DETAIL_RANGE,
				DETAIL_RANGE)
			mesh.visibility_range_end_margin = minf(
				mesh.visibility_range_end_margin if mesh.visibility_range_end_margin > 0.0 else 9.0,
				9.0)
			mesh.set_meta("web_quest_detail_range", DETAIL_RANGE)
			configured += 1
	set_meta("web_island_three_quest_detail_mesh_count", configured)
	set_meta("web_island_three_preserved_silhouette_mesh_count", preserved_silhouettes)


func _uses_web_render_budget() -> bool:
	return OS.has_feature("web") or OS.get_environment("ARTEA_FORCE_WEB_LOD") == "1"


func _configure_web_internal_resolution() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	# A retina browser canvas can contain four times as many pixels as the CSS
	# display. Cap only the 3D render buffer near 1.0 MP; HUD text and controls
	# stay at the browser's full native resolution.
	var pixels := float(viewport.size.x * viewport.size.y)
	var render_scale := 1.0
	if pixels > 1000000.0:
		render_scale = clampf(sqrt(1000000.0 / pixels), 0.50, 1.0)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = render_scale
	# The project-wide desktop preset uses 8x MSAA. High-DPI WebGL already renders
	# close to one million internal pixels, and multisampling the three large
	# courts pushes their p95 beyond a frame. Keep native 8x quality; Web uses the
	# high-DPI buffer itself for edge definition.
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	set_meta("web_3d_render_scale", snappedf(render_scale, 0.001))
	set_meta("web_3d_target_pixels", 1000000)
	set_meta("web_msaa_3d", int(viewport.msaa_3d))


func _configure_web_directional_shadows() -> void:
	if not _uses_web_render_budget() or get_tree() == null:
		return
	var disabled := 0
	for candidate in get_tree().root.find_children("*", "DirectionalLight3D", true, false):
		var light := candidate as DirectionalLight3D
		if light.shadow_enabled:
			light.shadow_enabled = false
			disabled += 1
	set_meta("web_directional_shadows_disabled", disabled)


# The six authored districts contain several thousand stateful render nodes.
# They cannot be folded into static batches because quest, enemy and restoration
# scripts address them individually. On Web, hide only the detailed branches of
# islands beyond the active camera's crossing distance. Foundations, bridges,
# route geometry and collisions stay mounted, so silhouettes and traversal are
# continuous while off-island scripted decoration stops submitting draw calls.
func _configure_web_island_detail_streaming() -> void:
	if not _uses_web_render_budget() or _uses_existing_mind_district() \
			or _uses_galaxy_foundation():
		return
	_web_island_detail_roots = {1: [], 2: [], 3: []}
	for index in ZONES.size():
		var zone_id := str(ZONES[index].id)
		var zone := _zone_nodes.get(zone_id) as Node3D
		if zone != null:
			(_web_island_detail_roots[int(ZONES[index].super_island)] as Array).append(zone)
	var named_roots := {
		1: ["IslandOneResearchCampus", "WorldOneGeometry/IslandOnePerimeterRepairs"],
		2: ["IslandTwoMemoryCampus", "GardenOfUnfinishedLight",
			"WorldOneGeometry/IslandTwoPerimeterRepairs"],
		3: ["WorldOneGeometry/IslandThreeCivicSanctuary",
			"WorldOneGeometry/IslandThreePerimeterRepairs",
			"WorldOneGeometry/OptionalCompletedWorldStationSpur"],
	}
	for island_value in named_roots:
		for path_value in named_roots[island_value]:
			var detail_root := get_node_or_null(str(path_value)) as Node3D
			if detail_root != null:
				(_web_island_detail_roots[int(island_value)] as Array).append(detail_root)
	# Static replacement batches are rooted here for stable transforms. Attach
	# them logically to their source island so the same visibility decision also
	# controls the replacement geometry.
	var streamed_batches := 0
	for child in get_children():
		if not (child is GeometryInstance3D) \
				or not child.has_meta("web_detail_island"):
			continue
		var detail_island := int(child.get_meta("web_detail_island", 0))
		if detail_island in [1, 2, 3]:
			(_web_island_detail_roots[detail_island] as Array).append(child)
			streamed_batches += 1
	set_meta("web_island_detail_streaming", true)
	set_meta("web_island_detail_distance", 285.0)
	set_meta("web_streamed_static_batch_count", streamed_batches)
	_update_web_island_detail_streaming_position(_web_focus_position_local())


func _update_web_island_detail_streaming() -> void:
	if _web_island_detail_roots.is_empty():
		return
	_update_web_island_detail_streaming_position(_web_focus_position_local())


func _web_focus_position_local() -> Vector3:
	var camera := get_viewport().get_camera_3d() if get_viewport() != null else null
	if camera != null:
		return to_local(camera.global_position)
	if _player != null:
		return to_local(_player.global_position)
	return get_player_arrival_local()


func _update_web_island_detail_streaming_position(focus_local: Vector3) -> void:
	if _web_island_detail_roots.is_empty():
		return
	if _web_last_detail_focus != Vector3.INF \
			and Vector2(_web_last_detail_focus.x - focus_local.x,
				_web_last_detail_focus.z - focus_local.z).length_squared() < 4.0:
		return
	_web_last_detail_focus = focus_local
	var visible_islands := PackedInt32Array()
	var focus_2d := Vector2(focus_local.x, focus_local.z)
	for island in [1, 2, 3]:
		var nearest := INF
		for zone_info in ZONES:
			if int(zone_info.super_island) != island:
				continue
			var zone_position := get_zone_position(str(zone_info.id))
			nearest = minf(nearest,
				focus_2d.distance_to(Vector2(zone_position.x, zone_position.z)))
		var show_detail := nearest <= 285.0
		if show_detail:
			visible_islands.append(island)
		for root_value in _web_island_detail_roots[island]:
			var detail_root := root_value as Node3D
			if is_instance_valid(detail_root) and detail_root.visible != show_detail:
				detail_root.visible = show_detail
	if _web_visible_detail_islands != visible_islands:
		_web_visible_detail_islands = visible_islands
		set_meta("web_visible_detail_islands", visible_islands)


# World One shares one scene with the full Castle Galaxy. The desktop camera's
# multi-kilometre far plane therefore keeps unrelated kingdoms in the WebGL
# render set behind these islands. Limit the active Web camera while it is near
# this route, then restore its authored value as soon as the camera leaves.
func _update_web_camera_far_plane() -> void:
	if not _uses_web_render_budget() or get_viewport() == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	if camera != _web_far_camera:
		_web_far_camera = camera
		_web_last_far_focus = Vector3.INF
	if not camera.has_meta("world_one_original_far"):
		camera.set_meta("world_one_original_far", camera.far)
	var focus := to_local(camera.global_position)
	if _web_last_far_focus != Vector3.INF \
			and Vector2(_web_last_far_focus.x - focus.x,
				_web_last_far_focus.z - focus.z).length_squared() < 16.0:
		return
	_web_last_far_focus = focus
	var focus_2d := Vector2(focus.x, focus.z)
	var nearest := INF
	for zone_info in ZONES:
		var zone_position := get_zone_position(str(zone_info.id))
		nearest = minf(nearest,
			focus_2d.distance_to(Vector2(zone_position.x, zone_position.z)))
	var original_far := float(camera.get_meta("world_one_original_far", camera.far))
	var inside_world_one := nearest <= 500.0
	var target_far := 900.0 if inside_world_one else original_far
	if not is_equal_approx(camera.far, target_far):
		camera.far = target_far
	set_meta("web_camera_far", camera.far)
