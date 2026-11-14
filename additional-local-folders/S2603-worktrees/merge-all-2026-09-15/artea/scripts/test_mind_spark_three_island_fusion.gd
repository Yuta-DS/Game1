extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	root.add_child(world)
	for _frame in 5:
		await physics_frame

	assert(int(world.get_meta("physical_island_count", 0)) == 3,
		"World One exposes exactly three physical islands")
	assert(int(world.get_meta("zone_count", 0)) == 6,
		"all six gameplay districts remain available to the quest chain")
	var geometry := world.get_node("WorldOneGeometry") as Node3D
	var fusions := geometry.get_node("ThreeFusedSuperIslands") as Node3D
	assert(fusions.get_child_count() == 3, "the foundation owns three fused assemblies")
	var expected_pairs := [
		PackedStringArray(["01_world_gate_landing", "02_living_network_forest"]),
		PackedStringArray(["03_constellation_court", "04_hope_path_ridge"]),
		PackedStringArray(["05_thought_storm_arena", "06_oldest_tree_sanctuary"]),
	]
	for pair_index in 3:
		var fusion := fusions.get_child(pair_index) as Node3D
		assert(PackedStringArray(fusion.get_meta("legacy_zone_ids", [])) == expected_pairs[pair_index],
			"super-island %d combines the approved legacy pair" % (pair_index + 1))
		assert(bool(fusion.get_meta("continuous_foundation", false)))
		assert(fusion.get_node_or_null("SharedIvorySaddleCollision") is StaticBody3D,
			"each fused waist is a continuous walkable surface")
		if pair_index == 0:
			var authored := fusion.get_node("BlenderAuthoredIslandOneTopOverlay") as Node3D
			assert(int(authored.get_meta("editable_source_parts", 0)) == 3000)
			assert(int(authored.get_meta("runtime_batches", 0)) == 9)
			assert(int(authored.get_meta("visible_overlay_batches", 0)) == 1)
			assert(bool(authored.get_meta("existing_foundation_preserved", false)))
			assert(str(authored.get_meta("application_mode", "")) == "additive_above_ground_only")
		else:
			assert(fusion.find_children("FoundationPressureTank_*", "MeshInstance3D", true, false).size() == 4)
			assert(fusion.find_children("FoundationFlywheel_*", "MeshInstance3D", true, false).size() == 2)
			assert(fusion.find_children("TriangulatedKeelRib_*", "MeshInstance3D", true, false).size() == 12)
		assert(not str(fusion.get_meta("gameplay_purpose", "")).is_empty(),
			"every foundation machine has a gameplay purpose")

	var route := geometry.get_node("MainStoryCircuitRoute") as Node3D
	assert(int(route.get_meta("external_bridge_count", 0)) == 2)
	assert(PackedStringArray(route.get_meta("external_bridge_pairs", [])).size() == 2)
	assert(PackedStringArray(route.get_meta("internal_promenade_pairs", [])).size() == 3)
	assert(not bool(route.get_meta("ring_closed", true)),
		"the obsolete sixth sky bridge is removed from the three-island silhouette")
	for link_index in range(1, 6):
		if link_index == 1:
			assert(route.get_node_or_null("CircuitRoute_01_A") == null)
			assert(route.get_node_or_null("CircuitRoute_01_B") == null)
			assert(world.get_island_one_heavenly_star_gate() != null)
			continue
		var expected_kind := "internal_promenade" if link_index % 2 == 1 else "external_sky_bridge"
		for leg in ["A", "B"]:
			var deck := route.get_node("CircuitRoute_%02d_%s" % [link_index, leg]) as MeshInstance3D
			assert(str(deck.get_meta("route_kind", "")) == expected_kind)
			assert(route.get_node_or_null("CircuitRoute_%02d_%sCollision" % [link_index, leg]) is StaticBody3D)

	assert(world.get_quest_objects().size() == 15,
		"the complete object-driven mini-game remains installed")
	assert(world.get_collectibles().size() == 2)
	assert(world.get_island_one_puzzle() != null)
	assert(world.get_warden() != null)
	var gates := geometry.get_node("SavedQuestProgressionGates") as Node3D
	var island_one_to_two := gates.get_node("QuestGate_1") as AnimatableBody3D
	assert(bool(island_one_to_two.get_meta("physical_barrier_removed", false)))
	assert(str(island_one_to_two.get_meta("progression_mode", "")) \
		== "narrative_only_clear_crossing")
	assert(island_one_to_two.get_node_or_null("Barrier") == null \
		and island_one_to_two.get_node_or_null("CollisionShape3D") == null,
		"Island One to Island Two bridge must not contain a visible or invisible barrier")
	assert(world.is_quest_gate_open(0),
		"the unobstructed Island One to Island Two crossing always reports open")
	var expected_gated_connections := PackedStringArray([
		"02_living_network_forest>03_constellation_court",
		"03_constellation_court>04_hope_path_ridge",
		"04_hope_path_ridge>05_thought_storm_arena",
		"05_thought_storm_arena>06_oldest_tree_sanctuary",
	])
	for gate_index in 4:
		assert(str(gates.get_child(gate_index).get_meta("gated_connection", "")) \
			== expected_gated_connections[gate_index],
			"quest gates follow the playable mini-game order without circular locks")
	print("MindSparkThreeIslandFusion: PASS — three fused foundations preserve all six quest districts")
	world.queue_free()
	await process_frame
	quit()
