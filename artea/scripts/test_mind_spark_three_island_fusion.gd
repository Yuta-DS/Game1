extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const PlayerScene := preload("res://scenes/player_3d.tscn")


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
			var echo_garden := authored.get_node("EchoGardenHeroBenchmark") as Node3D
			var trunk_mesh := echo_garden.get_node("WarmBark") as MeshInstance3D
			var tree_collision := trunk_mesh.get_node_or_null("WarmBarkCollision") as StaticBody3D
			assert(tree_collision != null and tree_collision.collision_layer == 1,
				"the Island One garden trees block the player")
			var trunk_vertices: PackedVector3Array = trunk_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var trunk_probe_shape := SphereShape3D.new()
			trunk_probe_shape.radius = 0.35
			var trunk_probe := PhysicsShapeQueryParameters3D.new()
			trunk_probe.shape = trunk_probe_shape
			trunk_probe.transform = Transform3D(Basis.IDENTITY,
				trunk_mesh.to_global(trunk_vertices[0]))
			trunk_probe.collision_mask = 1
			var trunk_hits := world.get_world_3d().direct_space_state.intersect_shape(trunk_probe)
			assert(trunk_hits.any(func(hit: Dictionary) -> bool:
				return hit.get("collider") == tree_collision),
				"a player-layer shape probe cannot pass through the Island One tree mesh")
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
	var removed_island_one_barrier := gates.get_child(0) as AnimatableBody3D
	assert(bool(removed_island_one_barrier.get_meta("physical_barrier_removed", false)))
	assert(removed_island_one_barrier.get_node_or_null("Barrier") == null)
	assert((removed_island_one_barrier.get_node("CollisionShape3D") as CollisionShape3D).disabled,
		"the grey barrier beside the Island One garden trees is absent")
	var island_one_collisions := geometry.get_node("IslandOneVisibleObjectCollisions") as StaticBody3D
	assert(str(island_one_collisions.get_meta("mass_class", "")) == "infinite_static_mass")
	assert(int(island_one_collisions.get_meta("collision_shape_count", 0)) > 1000,
		"Island One visible structures have static collision and cannot be walked through")
	var visible_shape_node := island_one_collisions.get_child(0) as CollisionShape3D
	var visible_faces := (visible_shape_node.shape as ConcavePolygonShape3D).get_faces()
	var visible_probe_shape := SphereShape3D.new()
	visible_probe_shape.radius = 0.35
	var visible_probe := PhysicsShapeQueryParameters3D.new()
	visible_probe.shape = visible_probe_shape
	visible_probe.transform = Transform3D(Basis.IDENTITY,
		visible_shape_node.to_global(visible_faces[0]))
	visible_probe.collision_mask = 1
	var visible_hits := world.get_world_3d().direct_space_state.intersect_shape(visible_probe)
	assert(visible_hits.any(func(hit: Dictionary) -> bool:
		return hit.get("collider") == island_one_collisions),
		"a player-layer probe is stopped by Island One visible-object collision")
	# Use the production character capsule against a scripted quest machine. This
	# guards the exact regression where those visuals rendered correctly but were
	# omitted from the static scenery pass and could be walked through.
	var quest_machine_shape: CollisionShape3D
	for candidate in island_one_collisions.get_children():
		if "/PuzzleControls/PuzzleControl_colour_prism/" \
				in str(candidate.get_meta("source_mesh", "")):
			quest_machine_shape = candidate as CollisionShape3D
			break
	assert(quest_machine_shape != null,
		"scripted Island One quest machines are included in static collision")
	var machine_faces := (quest_machine_shape.shape as ConcavePolygonShape3D).get_faces()
	var machine_face_center := Vector3.ZERO
	var machine_face_normal := Vector3.ZERO
	for face_index in range(0, machine_faces.size(), 3):
		var a := quest_machine_shape.to_global(machine_faces[face_index])
		var b := quest_machine_shape.to_global(machine_faces[face_index + 1])
		var c := quest_machine_shape.to_global(machine_faces[face_index + 2])
		var candidate_normal := (b - a).cross(c - a).normalized()
		if absf(candidate_normal.y) < 0.25:
			machine_face_center = (a + b + c) / 3.0
			machine_face_normal = Vector3(candidate_normal.x, 0, candidate_normal.z).normalized()
			break
	assert(not machine_face_normal.is_zero_approx())
	var production_player := PlayerScene.instantiate() as CharacterBody3D
	root.add_child(production_player)
	production_player.set_physics_process(false)
	production_player.global_position = machine_face_center + machine_face_normal * 2.0
	await physics_frame
	var player_collision := production_player.move_and_collide(-machine_face_normal * 4.0)
	assert(player_collision != null and player_collision.get_collider() == island_one_collisions,
		"the production player capsule cannot walk through an Island One quest machine")
	production_player.queue_free()
	print("MindSparkThreeIslandFusion: PASS — three fused foundations preserve all six quest districts")
	world.queue_free()
	await process_frame
	quit()
