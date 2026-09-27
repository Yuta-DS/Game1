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
	var objects_per_island := {1: 0, 2: 0, 3: 0}
	var zones_per_island := {
		1: PackedStringArray(["01_world_gate_landing", "02_living_network_forest"]),
		2: PackedStringArray(["03_constellation_court", "04_hope_path_ridge"]),
		3: PackedStringArray(["05_thought_storm_arena", "06_oldest_tree_sanctuary"]),
	}
	for object in world.get_quest_objects():
		var physical_island := int(object.get_meta("physical_island", 0))
		assert(physical_island in [1, 2, 3], "every quest object names its physical island")
		objects_per_island[physical_island] += 1
		assert(str(object.get_parent().get_meta("zone_id", "")) \
			in zones_per_island[physical_island],
			"quest object is parented to the district belonging to its physical island")
		var operator_approach: Vector3 = object.get_meta("operator_approach_local")
		assert(object.position.distance_to(operator_approach) <= 14.0,
			"every operator point stays inside interaction range")
		var intended := ((object.get_parent() as Node3D).global_basis \
			* (operator_approach - object.position)).normalized()
		assert(object.global_basis.z.normalized().dot(intended) > .99,
			"each quest object faces its operator approach")
		var approach_global := (object.get_parent() as Node3D).to_global(operator_approach)
		var approach_ray := PhysicsRayQueryParameters3D.create(
			approach_global + Vector3.UP * 8.0, approach_global + Vector3.DOWN * 12.0)
		approach_ray.collision_mask = 1
		assert(not world.get_world_3d().direct_space_state.intersect_ray(approach_ray).is_empty(),
			"every quest object has a physically supported operator approach")
		for other in world.get_quest_objects():
			if other == object or other.get_parent() != object.get_parent():
				continue
			assert(object.position.distance_to(other.position) >= 20.0,
				"quest objects in one district keep a clear walking apron")
	assert(objects_per_island == {1: 5, 2: 5, 3: 5},
		"the 15 quest objects are distributed five per physical island")
	var island_three := geometry.get_node("IslandThreeCivicSanctuary") as Node3D
	assert(str(island_three.get_meta("design_revision", "")) == "island_one_style_match_v7")
	assert(int(island_three.get_meta("island_one_style_matched_quest_objects", 0)) == 5,
		"all five Island 3 quest objects use Island One's production style family")
	assert(bool(island_three.get_meta("matches_previous_islands", false)))
	assert(island_three.has_node("IslandThreeStormDeck"))
	assert(island_three.has_node("IslandThreeSanctuaryDeck"))
	assert(island_three.has_node("StormworksArrivalPortico/IvoryArrivalTerraceCollision"))
	assert(island_three.has_node("StormworksArrivalPortico/AetherArrivalArch"))
	assert((island_three.get_node("StormworksArrivalPortico/AetherArrivalArch") as MeshInstance3D).mesh is BoxMesh,
		"the low-poly arrival uses an open lintel instead of another ring")
	assert(island_three.has_node("StormworksArrivalPortico/ArrivalTowerNorthCollision"))
	assert(island_three.has_node("StormworksArrivalPortico/ArrivalTowerSouthCollision"))
	assert(island_three.get_node("StormworksGrandCourt").get_meta("clear_center_radius_m") == 34.0)
	assert(island_three.has_node("StormworksGrandCourt/StormCourtCompass/CompassWedge_01"))
	assert(island_three.get_node("StormworksGrandCourt").find_children(
		"StormCourtGarden_*", "Node3D", false, false).size() == 8)
	var storm_zone := geometry.get_node("05ThoughtStormArena") as Node3D
	for retired_ring in storm_zone.find_children("LayeredStormRing_*", "MeshInstance3D", true, false):
		assert(not retired_ring.visible, "the oversized legacy vortex must remain retired")
	assert(str((storm_zone.get_node("BossArenaCollision") as MeshInstance3D).get_meta(
		"restyled_as", "")) == "IvoryStormworksCourt")
	var quest_landmarks := PackedStringArray([
		"StormLensTower", "ResonanceForge", "LightningArchive",
	])
	for landmark_name in quest_landmarks:
		assert(island_three.has_node("StormworksGrandCourt/%s/SolidQuestTerraceCollision" % landmark_name),
			"each Warden anchor has distinct, solid quest architecture")
		assert(island_three.has_node("StormworksGrandCourt/%s/CompletionStateVisuals" % landmark_name))
		assert(island_three.has_node(
			"StormworksGrandCourt/%s/IslandOneStyleQuestInstrument/IvoryInstrumentCabinetCollision" % landmark_name),
			"each storm landmark uses the same cabinet-and-dial grammar as Island One")
	assert(island_three.has_node("StormworksGrandCourt/ShieldProcessional_01Collision"))
	assert(island_three.get_node_or_null("CalmRainCloister") == null,
		"the Calm-Rain Cloister is removed from the recovery sequence")
	assert(island_three.has_node("RainHarvestObservatory/RainCollectorTerraceCollision"))
	assert(island_three.has_node("RainHarvestObservatory/RainCrystalReservoir"))
	assert(island_three.has_node("RainHarvestObservatory/FacetedRainDome"))
	assert((island_three.get_node("RainHarvestObservatory/FacetedRainDome") as MeshInstance3D).mesh.radial_segments == 12)
	assert(island_three.has_node("RainHarvestObservatory/CompletionStateVisuals/HarvestedRainWater"))
	assert(island_three.has_node(
		"RainHarvestObservatory/IslandOneStyleQuestInstrument/CyanInstrumentDial"))
	assert(island_three.has_node("WisdomBasilicaPromenade/OldestTreeReflectionApseCollision"))
	assert(island_three.has_node("WisdomBasilicaPromenade/RootboundReflectionCourt/ReflectionMemorySeed"))
	assert(island_three.has_node("WisdomBasilicaPromenade/RootboundReflectionCourt/ReflectionPool"))
	assert(island_three.has_node("WisdomBasilicaPromenade/RootboundReflectionCourt/ReflectionMarker_01"))
	assert(island_three.has_node(
		"WisdomBasilicaPromenade/RootboundReflectionCourt/IslandOneStyleQuestInstrument/CyanInstrumentDial"))
	assert(not island_three.has_node("WisdomBasilicaPromenade/CyanBasilicaRidge"),
		"the unsupported blue line over the Island 3 promenade is removed")
	assert(int(world.get_meta("island_three_route_barriers_removed", 0)) > 0,
		"the Island 3 route cleanup finds and removes the former purple gate")
	for candidate in geometry.find_children("QuestGate_4", "AnimatableBody3D", true, false):
		var gate := candidate as AnimatableBody3D
		var barrier := gate.get_node_or_null("Barrier") as MeshInstance3D
		assert(barrier == null or not barrier.visible,
			"the purple barrier between the storm court and tree sanctuary is removed")
		var barrier_collision := gate.get_node_or_null("CollisionShape3D") as CollisionShape3D
		assert(barrier_collision == null or barrier_collision.disabled,
			"the removed purple barrier leaves no invisible collision")
	assert(island_three.has_node("OldestTreeLivingCathedral/LivingHeartwoodCollision"),
		"the redesigned Oldest Tree is a solid living landmark")
	assert(island_three.has_node("OldestTreeLivingCathedral/GreatBough_01A"))
	var shared_palette: Dictionary = world.get("_materials")
	assert((island_three.get_node("OldestTreeLivingCathedral/LivingHeartwood") as MeshInstance3D).material_override \
		== shared_palette.shared_style_ivory,
		"the Oldest Tree uses the same ivory structure material as Island One's light tree")
	assert((island_three.get_node("OldestTreeLivingCathedral/CanopyLeafMass_01_01") as MeshInstance3D).material_override \
		in [shared_palette.shared_style_cyan, shared_palette.shared_style_lavender],
		"the Oldest Tree canopy uses Island One's cyan and lavender light foliage")
	assert(island_three.has_node("LowPolyUndersideAccents/EmbeddedAetherCrystal_01"))
	var return_arch_left := geometry.get_node(
		"06OldestTreeSanctuary/ReturnWorldGate/Left") as MeshInstance3D
	assert(return_arch_left.material_override == world.get("_materials").celestial_floor,
		"the old gold return arch is refinished in ivory")
	assert(int(island_three.get_meta("gold_rings_removed", 0)) > 0)
	assert(int(island_three.get_meta("visible_gold_ring_count", -1)) == 0,
		"Island 3 contains no visible gold torus geometry")
	assert(str(island_three.get_meta("gold_ring_policy", "")) \
		== "no visible gold torus geometry")
	assert(int(island_three.get_meta("gold_lines_removed", 0)) > 0)
	assert(int(island_three.get_meta("visible_gold_line_count", -1)) == 0,
		"Island 3 contains no visible elongated gold geometry")
	assert(island_three.get_node_or_null("StormworksGrandCourt/BrassRadialInlay_01") == null,
		"the former gold radial floor lines are no longer constructed")
	assert(not (island_three.get_node(
		"WisdomBasilicaPromenade/LeftBasilicaCornice") as MeshInstance3D).visible)
	assert(not (island_three.get_node(
		"WisdomBasilicaPromenade/LeftLivingRootRail") as MeshInstance3D).visible)
	for removed_ring in geometry.find_children("*", "MeshInstance3D", true, false):
		if bool(removed_ring.get_meta("island_three_gold_ring_removed", false)):
			assert(not (removed_ring as MeshInstance3D).visible,
				"all Island 3 gold ring geometry remains hidden")
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
