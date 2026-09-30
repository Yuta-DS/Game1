extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const Definition := preload("res://scripts/mind_spark/quest_objects/quest_object_definition.gd")
const TEST_STORE := "user://test_mind_spark_world_one_objects.json"
var _failures := 0


func _init() -> void:
	if FileAccess.file_exists(TEST_STORE):
		DirAccess.remove_absolute(TEST_STORE)
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.get_node("QuestController").enabled = false
	world.object_state_store_path = TEST_STORE
	root.add_child(world)
	await process_frame
	await process_frame
	_test_world_geometry(world)
	_test_architecture(world)
	_test_organized_tree_world(world)
	_test_object_coverage(world)
	_test_combat_roster(world)
	world.queue_free()
	await process_frame
	if FileAccess.file_exists(TEST_STORE):
		DirAccess.remove_absolute(TEST_STORE)
	if _failures > 0:
		push_error("MindSparkWorldOne: %d greybox checks failed" % _failures)
		quit(1)
		return
	print("MindSparkWorldOne: all checks passed")
	quit()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("MindSparkWorldOne: %s" % message)


func _test_world_geometry(world: MindSparkWorldOne) -> void:
	assert(world.get_zone_ids().size() == 6, "World One preserves the required six gameplay districts")
	assert(int(world.get_meta("physical_island_count", 0)) == 3,
		"the six gameplay districts are combined into three physical islands")
	assert(world.get_meta("world_identity") == "living computer forest")
	var geometry := world.get_node("WorldOneGeometry")
	assert(world.find_child("EchoListeningBranch_*", true, false) == null,
		"Island One's crossing brass listening lines stay removed")
	assert(world.find_child("EchoOrbCradle_*", true, false) == null,
		"Island One's loose gold orb rings stay removed")
	assert(world.find_child("EchoListeningOrb_01", true, false) != null,
		"live echo classifier orbs remain in the quest")
	for zone_id in world.get_zone_ids():
		var zone := geometry.get_node(zone_id.to_pascal_case())
		assert(zone.get_node_or_null("WalkableZoneFloorCollision") is StaticBody3D,
			"%s has a walkable collision floor" % zone_id)
		assert(zone.get_node_or_null("PerimeterRecoveryVolume") is Area3D,
			"%s has a recovery volume" % zone_id)
	var route := geometry.get_node("MainStoryCircuitRoute")
	var route_decks := route.find_children("CircuitRoute_*", "MeshInstance3D", false, false)
	assert(route_decks.size() >= 10, "five zone links use two circuit walkway legs each")
	var spur := geometry.get_node("OptionalCompletedWorldStationSpur")
	assert(bool(spur.get_meta("optional_after_completion")))
	assert(not bool(spur.get_meta("blocks_story_route")))
	_test_greybox_build_order(world, geometry, route, spur)


func _test_greybox_build_order(world: MindSparkWorldOne, geometry: Node,
		route: Node, spur: Node) -> void:
	var expected_order := PackedStringArray([
		"three_fused_super_island_foundations",
		"main_story_route",
		"world_gate_checkpoints_boss_sanctuary",
		"optional_station_spur",
	])
	_check(PackedStringArray(world.get_meta("greybox_build_sequence", [])) == expected_order,
		"greybox phase order must remain floors, story route, landmarks, station spur")
	_check(PackedStringArray(route.get_meta("route_zone_ids", [])) == PackedStringArray([
		"01_world_gate_landing",
		"02_living_network_forest",
		"03_constellation_court",
		"04_hope_path_ridge",
		"05_thought_storm_arena",
		"06_oldest_tree_sanctuary",
	]), "main route must follow the six numbered zones without using the station")
	_check(spur.get_index() == geometry.get_child_count() - 1,
		"optional station spur must be the final geometry phase")
	_check(spur.get_meta("branches_from_zone", "") == "05_thought_storm_arena",
		"station spur must branch from the boss-arena side, not the World Gate")
	var station_center: Vector3 = spur.get_meta("station_center", Vector3.ZERO)
	var branch_start: Vector3 = spur.get_meta("branch_start", Vector3.ZERO)
	var zone_05 := world.get_zone_position("05_thought_storm_arena")
	var zone_01 := world.get_zone_position("01_world_gate_landing")
	_check(station_center.distance_to(zone_05) < station_center.distance_to(zone_01),
		"station island must remain a Zone 05 side destination")
	for route_index in world.get_zone_ids().size() - 1:
		var route_start := world.get_zone_position(world.get_zone_ids()[route_index])
		var route_finish := world.get_zone_position(world.get_zone_ids()[route_index + 1])
		_check(_segment_distance_xz(branch_start, station_center, route_start, route_finish) > 60.0,
			"station spur must stay clear of story route link %d" % (route_index + 1))
	_check(not spur.visible, "station spur starts hidden until story completion")
	for body in spur.find_children("*", "StaticBody3D", true, false):
		_check((body as StaticBody3D).collision_layer == 0,
			"hidden station collision must never block the required story route")
	var world_gate_zone := geometry.get_node("01WorldGateLanding")
	_check(world_gate_zone.get_node_or_null("EntryWorldGate") is MindSparkWorldGate,
		"Zone 01 must contain the World Gate landmark")
	var checkpoint_count := 0
	for marker in geometry.find_children("*Checkpoint", "Marker3D", true, false):
		if bool(marker.get_meta("story_route_checkpoint", false)) or marker.name == "BossRetryCheckpoint":
			checkpoint_count += 1
	_check(checkpoint_count >= 5,
		"arrival, network, constellation, hope and boss checkpoints must exist")
	for name in ["ArrivalCheckpointPad", "NetworkCheckpointPad",
			"ConstellationCheckpointPad", "HopePathCheckpointPad"]:
		_check(geometry.find_child(name, true, false) == null,
			"route checkpoints must not leave cyan greybox pads in the finished world")


func _segment_distance_xz(a_start: Vector3, a_end: Vector3,
		b_start: Vector3, b_end: Vector3) -> float:
	var a0 := Vector2(a_start.x, a_start.z)
	var a1 := Vector2(a_end.x, a_end.z)
	var b0 := Vector2(b_start.x, b_start.z)
	var b1 := Vector2(b_end.x, b_end.z)
	if Geometry2D.segment_intersects_segment(a0, a1, b0, b1) != null:
		return 0.0
	var a_distance := minf(
		_point_segment_distance(a0, b0, b1),
		_point_segment_distance(a1, b0, b1))
	var b_distance := minf(
		_point_segment_distance(b0, a0, a1),
		_point_segment_distance(b1, a0, a1))
	return minf(a_distance, b_distance)


func _point_segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() <= 0.0001:
		return point.distance_to(start)
	var progress := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * progress)


func _test_architecture(world: MindSparkWorldOne) -> void:
	var geometry := world.get_node("WorldOneGeometry")
	var forest := geometry.get_node("02LivingNetworkForest")
	assert(forest.find_children("MindSparkGroveTree_*", "Node3D", true, false).size() == 30,
		"the organized living-network grove establishes the technology forest skyline")
	assert(geometry.get_node("03ConstellationCourt/ConstellationDaisCollision") is StaticBody3D)
	assert(geometry.get_node("05ThoughtStormArena/BossArenaCollisionCollision") is StaticBody3D)
	assert(geometry.get_node("05ThoughtStormArena/BossRetryCheckpoint") is Marker3D)
	assert(geometry.get_node("06OldestTreeSanctuary/OldestTreeTrunkCollision") is StaticBody3D)
	assert(geometry.get_node("06OldestTreeSanctuary/StarOfWisdomReward") is Node3D)


func _test_organized_tree_world(world: MindSparkWorldOne) -> void:
	var geometry := world.get_node("WorldOneGeometry")
	var expected_distribution := {
		"01_world_gate_landing": 10,
		"02_living_network_forest": 30,
		"03_constellation_court": 14,
		"04_hope_path_ridge": 14,
		"05_thought_storm_arena": 4,
		"06_oldest_tree_sanctuary": 12,
	}
	var organized_trees := get_nodes_in_group("mind_spark_organized_tree")
	_check(organized_trees.size() == 84,
		"the quieter three-island landscape has 84 deliberately placed trees")
	_check(int(world.get_meta("organized_tree_count", 0)) == 84,
		"world metadata must report the 84-tree composition")
	_check(str(world.get_meta("organized_tree_distribution", "")) == "10/30/14/14/4/12",
		"tree distribution must match the revised six-zone composition")
	_check(geometry.find_children("ServerTree_*", "Node3D", true, false).is_empty(),
		"legacy blocky server-tree instances must not remain in the redesigned world")
	var world_indices := {}
	var grove_scales: Array[float] = []
	var distinct_grove_scales := {}
	for tree in organized_trees:
		var tree_index := int(tree.get_meta("world_tree_index", 0))
		_check(tree_index >= 1 and tree_index <= 84,
			"every organized tree needs a stable index from 1 through 84")
		world_indices[tree_index] = true
		_check(not bool(tree.get_meta("randomized", false)),
			"organized grove trees must never use random placement")
		if str(tree.get_meta("tree_lod", "")) == "gameplay_grove_editable":
			var growth_scale := float(tree.get_meta("growth_scale", 0.0))
			grove_scales.append(growth_scale)
			distinct_grove_scales[snappedf(growth_scale, 0.001)] = true
			_check(bool(tree.get_meta("size_randomized", false)),
				"each grove tree must record its seeded random growth scale")
	_check(world_indices.size() == 84,
		"all 84 organized trees need unique stable world indices")
	_check(grove_scales.size() == 83,
		"the population needs 83 variable-size grove trees plus one hero tree")
	_check(distinct_grove_scales.size() >= 60,
		"seeded growth must provide broad small-to-large size variation")
	_check(grove_scales.min() < 0.32 and grove_scales.max() > 0.60,
		"standalone groves must visibly span sapling through large-canopy scales")
	for zone_id in expected_distribution:
		var zone := geometry.get_node(zone_id.to_pascal_case())
		var zone_tree_count := 0
		for tree in organized_trees:
			if str(tree.get_meta("zone_id", "")) == zone_id:
				zone_tree_count += 1
		_check(zone_tree_count == int(expected_distribution[zone_id]),
			"%s must contain exactly %d authored trees" % [zone_id,
				int(expected_distribution[zone_id])])
		var grove := zone.get_node_or_null("%sDesignedBioTreeGrove" % zone_id.to_pascal_case())
		_check(grove is Node3D and not bool(grove.get_meta("randomized", true)),
			"%s must expose its deterministic grove organizer" % zone_id)


func _test_object_coverage(world: MindSparkWorldOne) -> void:
	var objects := world.get_quest_objects()
	assert(objects.size() == 15, "all twelve types plus repeated checkpoints and three anchors are placed")
	var kinds := {}
	for object in objects:
		assert(object is QuestObjectBase)
		assert(object.definition != null)
		assert(not object.save_id.is_empty())
		assert(object.get_node("InteractionArea/CollisionShape3D") is CollisionShape3D)
		kinds[object.definition.object_kind] = true
	assert(kinds.size() == Definition.ObjectKind.size(), "all twelve approved functional object types are present")
	var scanner := world.get_object_by_kind(Definition.ObjectKind.EVIDENCE_SCANNER)
	assert(not scanner.interact(&"capture", 0).accepted, "observation needs a clear instrument reading")
	for channel in 3:
		for adjustment in [2, 1, 3][channel]:
			assert(scanner.interact(&"adjust", channel).accepted)
		assert(scanner.interact(&"capture", channel).accepted)
	assert(scanner.current_state.completed, "physical scanner saves all three observations")
	var anchor := world.get_object_by_kind(Definition.ObjectKind.WARDEN_ANCHOR)
	assert(anchor.interact()["reason"] == "vulnerable")
	assert(anchor.interact(&"strike")["completed"], "physical Warden anchor has dodge and strike states")
	var bell := world.get_object_by_kind(Definition.ObjectKind.FOCUS_BELL_BEACON)
	assert(bell.interact(&"help")["reason"] == "hint_on", "Focus Bell gives help without completion")
	assert(not bool(bell.current_state.get("completed", false)))


func _test_combat_roster(world: MindSparkWorldOne) -> void:
	var enemies := world.get_enemies()
	assert(enemies.size() == 6,
		"production keeps four Island One teaching actors and two Island Three Warden adds")
	var kinds := {}
	for enemy in enemies:
		assert(enemy.definition.validated_telegraph() >= 0.75, "every normal attack warns for at least 0.75 seconds")
		kinds[enemy.definition.enemy_kind] = true
	assert(kinds.size() == 3,
		"only Static Mites, Glitch Sprouts and Circuit Wisps remain in live bounded waves")
	assert(enemies.filter(func(enemy): return enemy.encounter_id in ["constellation", "ridge"]).is_empty(),
		"peaceful Island Two does not construct hidden prototype combat actors")
	assert(world.activate_enemy_wave("network") == 4)
	assert(world.active_enemy_count() <= 4, "the encounter director never activates more than four normal enemies")
	var mite := enemies[0] as MindSparkEnemyBase
	assert(mite.take_damage(999.0) == 25.0)
	assert(mite.state == MindSparkEnemyBase.State.DEFEATED and mite.core.visible,
		"defeat removes the Blight shell and reveals the calm living core")
	var boss := world.get_warden() as MindSparkWardenBoss
	var storm_crown := boss.get_node("VisualRoot/BlightShell/StormCrown") as Node3D
	var shell_mesh := (boss.get_node("VisualRoot/BlightShell/Shell") as MeshInstance3D).mesh \
		as SphereMesh
	assert(shell_mesh.radial_segments == 12 and shell_mesh.rings == 6,
		"the Warden shell itself uses a deliberately faceted low-poly surface")
	assert(storm_crown.get_meta("visual_revision") == "island_three_civic_storm_engine_v3_faceted_shell",
		"Island Three Warden uses the faceted civic storm engine")
	assert(int(storm_crown.get_meta("giant_ring_count", -1)) == 0,
		"the prototype giant purple shield rings remain removed")
	assert(storm_crown.find_children("IvoryPylon*", "MeshInstance3D", true, false).size() == 4,
		"four grounded ivory pylons give the Warden an architectural silhouette")
	assert(bool(storm_crown.get_meta("faceted_shell", false))
		and int(storm_crown.get_meta("ivory_shell_panel_count", 0)) == 8
		and storm_crown.find_children("IvoryShell*Panel*", "MeshInstance3D", true, false).size() == 8,
		"eight ivory armor plates break up the dark shell without closing its core sightlines")
	assert(storm_crown.find_children("CyanShellConductor*", "MeshInstance3D", true, false).size() == 4,
		"each cardinal armor blade carries a restrained cyan conductor")
	assert(int(storm_crown.get_meta("merged_static_source_count", 0)) == 54
		and int(storm_crown.get_meta("render_batch_count", 0)) == 4,
		"the animated Warden crown preserves its 54-part silhouette in four material batches")
	for visual in storm_crown.find_children("*", "MeshInstance3D", true, false):
		assert(not ((visual as MeshInstance3D).mesh is TorusMesh),
			"the completed Warden contains no luminous torus geometry")
	var crown_light := storm_crown.get_node("StormCrownLight") as OmniLight3D
	assert(crown_light.light_energy <= 2.401 and crown_light.omni_range <= 18.001,
		"the Warden light preserves the surrounding Island Three architecture")
	boss.start_battle()
	for anchor in world.get_quest_objects():
		if anchor.definition.object_kind != Definition.ObjectKind.WARDEN_ANCHOR:
			continue
		if not bool(anchor.current_state.get("completed", false)):
			anchor.interact(&"dodge")
			anchor.take_damage(25.0)
	assert(boss.phase == MindSparkWardenBoss.Phase.PHASE_3, "three anchors expose the crystal core")
	assert(boss.take_damage(300.0) == 300.0)
	assert(boss.phase == MindSparkWardenBoss.Phase.COMPLETE and not boss.active,
		"zero core health stops combat before the Calm Rain Basin")
