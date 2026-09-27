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
		if pair_index == 2:
			assert(fusion.get_node_or_null("SharedIvorySaddle") == null)
			assert(fusion.get_node_or_null("SharedIvorySaddleCollision") == null)
			assert(fusion.find_children("*PromenadeRail", "Node3D", true, false).is_empty())
			assert(fusion.find_children("*PromenadeLamp*", "Node3D", true, false).is_empty())
			assert(bool(fusion.get_meta("internal_promenade_removed", false)),
				"the visible bridge and grey barriers beside the Oldest Tree are removed")
			var storm_center := world.get_zone_position("05_thought_storm_arena")
			var tree_center := world.get_zone_position("06_oldest_tree_sanctuary")
			var centre_distance := Vector2(
				tree_center.x - storm_center.x, tree_center.z - storm_center.z).length()
			assert(centre_distance < 175.0 + 145.0,
				"Storm Arena and Oldest Tree floors overlap without the bridge")
		else:
			assert(fusion.get_node_or_null("SharedIvorySaddleCollision") is StaticBody3D,
				"the retained fused waist is a continuous walkable surface")
		if pair_index == 0:
			var authored := fusion.get_node("BlenderAuthoredIslandOneTopOverlay") as Node3D
			assert(int(authored.get_meta("editable_source_parts", 0)) == 3000)
			assert(int(authored.get_meta("runtime_batches", 0)) == 9)
			assert(int(authored.get_meta("visible_overlay_batches", 0)) == 1)
			assert(bool(authored.get_meta("existing_foundation_preserved", false)))
			assert(str(authored.get_meta("application_mode", "")) == "additive_above_ground_only")
		elif pair_index == 1:
			assert(fusion.find_children("FoundationPressureTank_*", "MeshInstance3D", true, false).size() == 4)
			assert(fusion.find_children("FoundationFlywheel_*", "MeshInstance3D", true, false).size() == 2)
			assert(fusion.find_children("TriangulatedKeelRib_*", "MeshInstance3D", true, false).size() == 12)
		assert(not str(fusion.get_meta("gameplay_purpose", "")).is_empty(),
			"every foundation machine has a gameplay purpose")

	var route := geometry.get_node("MainStoryCircuitRoute") as Node3D
	assert(int(route.get_meta("external_bridge_count", 0)) == 2)
	assert(PackedStringArray(route.get_meta("external_bridge_pairs", [])).size() == 2)
	assert(PackedStringArray(route.get_meta("internal_promenade_pairs", [])).size() == 2)
	assert(not bool(route.get_meta("ring_closed", true)),
		"the obsolete sixth sky bridge is removed from the three-island silhouette")
	for link_index in range(1, 6):
		if link_index == 1:
			assert(route.get_node_or_null("CircuitRoute_01_A") == null)
			assert(route.get_node_or_null("CircuitRoute_01_B") == null)
			assert(world.get_island_one_heavenly_star_gate() != null)
			continue
		if link_index == 5:
			assert(route.get_node_or_null("CircuitRoute_05_A") == null)
			assert(route.get_node_or_null("CircuitRoute_05_B") == null)
			assert(route.get_node_or_null("CircuitRoute_05_ACollision") == null)
			assert(route.get_node_or_null("CircuitRoute_05_BCollision") == null)
			continue
		var expected_kind := "internal_promenade" if link_index % 2 == 1 else "external_sky_bridge"
		for leg in ["A", "B"]:
			var deck := route.get_node("CircuitRoute_%02d_%s" % [link_index, leg]) as MeshInstance3D
			assert(str(deck.get_meta("route_kind", "")) == expected_kind)
			assert(route.get_node_or_null("CircuitRoute_%02d_%sCollision" % [link_index, leg]) is StaticBody3D)

	assert(world.get_quest_objects().size() == 15,
		"the complete object-driven mini-game remains installed")
	var reflection := world.get_quest_objects().filter(func(object: QuestObjectBase) -> bool:
		return object.save_id == "world_one.identity_reflection")[0] as QuestObjectBase
	assert(int(reflection.get_meta("physical_collision_shape_count", 0)) > 0,
		"the Oldest Tree reflection object creates physical collision")
	var reflection_bodies := reflection.find_children("*Collision", "StaticBody3D", true, false)
	assert(not reflection_bodies.is_empty(),
		"the player cannot walk through the Oldest Tree reflection object")
	var collision_probe := PhysicsRayQueryParameters3D.create(
		reflection.to_global(Vector3(0, 1.0, 2.0)),
		reflection.to_global(Vector3(0, 1.0, -2.0)))
	collision_probe.collision_mask = 1
	var reflection_hit := world.get_world_3d().direct_space_state.intersect_ray(collision_probe)
	assert(not reflection_hit.is_empty() and reflection_hit.get("collider") in reflection_bodies,
		"a player-layer probe cannot pass through the visible reflection frame")
	assert(world.get_collectibles().size() == 2)
	assert(world.get_island_one_puzzle() != null)
	assert(world.get_warden() != null)
	var gates := geometry.get_node("SavedQuestProgressionGates") as Node3D
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
	var removed_tree_barrier := gates.get_child(3) as AnimatableBody3D
	assert(bool(removed_tree_barrier.get_meta("physical_barrier_removed", false)))
	assert(removed_tree_barrier.get_node_or_null("Barrier") == null)
	assert((removed_tree_barrier.get_node("CollisionShape3D") as CollisionShape3D).disabled,
		"the bridge barrier beside the Oldest Tree is absent in the live scene")
	var island_three_repairs := geometry.get_node("IslandThreePerimeterRepairs") as Node3D
	var visible_posts := island_three_repairs.get_children().filter(func(child: Node) -> bool:
		return child is Node3D and not child is StaticBody3D \
			and str(child.name).begins_with("ReferencePost_") \
			and (child as Node3D).visible)
	assert(int(island_three_repairs.get_meta("solid_reference_post_count", 0)) == visible_posts.size(),
		"every large Oldest Tree perimeter post has player collision")
	for post: Node3D in visible_posts:
		var post_collision := island_three_repairs.get_node_or_null(
			"%sCollision" % post.name) as StaticBody3D
		assert(post_collision != null and post_collision.collision_layer == 1,
			"each visible Oldest Tree perimeter post blocks the player")
	print("MindSparkThreeIslandFusion: PASS — three fused foundations preserve all six quest districts")
	world.queue_free()
	await process_frame
	quit()
