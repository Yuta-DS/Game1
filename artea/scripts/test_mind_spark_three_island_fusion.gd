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
			if pair_index == 2:
				assert(fusion.get_node_or_null("RightPromenadeRailCollision") == null
					and fusion.get_node_or_null("LeftPromenadeRailCollision") == null,
					"Island 3's interior saddle has no cross-court rail barrier")
				assert(fusion.get_node_or_null("InternalPromenadeInlay") == null
					and fusion.get_node_or_null("AetherFlowChannel") == null,
					"Island 3's old gold and blue saddle lines are removed")
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
			if link_index == 5:
				assert(route.get_node_or_null("CircuitRoute_05_%sRightRailCollision" % leg) == null
					and route.get_node_or_null("CircuitRoute_05_%sLeftRailCollision" % leg) == null,
					"Island 3's interior route does not divide the walkable court")

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
	var storm_edge := geometry.get_node("IslandThreePerimeterRepairs") as Node3D
	assert(storm_edge.find_children("StormEdgeStone_*", "MeshInstance3D", true, false).size() >= 40,
		"Island 3 has a continuous low-poly stone parapet at exposed edges")
	assert(storm_edge.find_children("StormEdgeStone_*SolidCollision", "StaticBody3D", true, false).size() >= 40,
		"the visible Island 3 parapet blocks the player at its actual position")
	assert(storm_edge.find_children("ReferenceScrollwork_*", "Node3D", true, false).is_empty()
		and storm_edge.find_children("ReferencePost_*", "Node3D", true, false).is_empty(),
		"the repeated ornate rail and lantern-post kit is retired on Island 3")
	assert(storm_edge.find_children("RepairedBay_*Collision", "StaticBody3D", true, false).size() >= 100,
		"the quieter Island 3 edge retains its player-blocking cliff collision")
	var island_three_saplings := 0
	for sapling in geometry.find_children("HeavenlySapling", "Node3D", true, false):
		if str(sapling.get_parent().get_meta("zone_id", "")) in [
			"05_thought_storm_arena", "06_oldest_tree_sanctuary"]:
			island_three_saplings += 1
	assert(island_three_saplings == 15,
		"Island 3 uses fifteen restrained pale perimeter saplings around its hero tree")
	assert(str(island_three.get_meta("design_revision", "")) \
		== "landmark_hierarchy_v15_clear_reflection_skyline")
	assert(int(island_three.get_meta("island_one_style_matched_quest_objects", 0)) == 5,
		"all five Island 3 quest objects use Island One's production style family")
	assert(bool(island_three.get_meta("matches_previous_islands", false)))
	assert(island_three.has_node("IslandThreeStormDeck"))
	assert(island_three.has_node("IslandThreeSanctuaryDeck"))
	var matched_environment := island_three.get_node("IslandThreeMatchedEnvironment") as Node3D
	assert(str(matched_environment.get_meta("environment_revision", "")) \
		== "open_civic_gardens_v15_clear_reflection_skyline")
	assert(str(matched_environment.get_meta("foliage_palette", "")).contains("pale sage"))
	assert(bool(matched_environment.get_meta("clear_routes_preserved", false)))
	assert(int(matched_environment.get_meta("total_environment_bays", 0)) >= 16 \
		and int(matched_environment.get_meta("total_environment_bays", 0)) <= 24,
		"Island 3 uses garden bays as a sparse frame around readable landmarks; found %d" % int(matched_environment.get_meta("total_environment_bays", 0)))
	var storm_environment := matched_environment.get_node(
		"StormworksPerimeterGardenGallery") as Node3D
	var sanctuary_environment := matched_environment.get_node(
		"OldestTreeTerracedGarden") as Node3D
	assert(int(storm_environment.get_meta("garden_bay_count", 0)) >= 8)
	assert(int(sanctuary_environment.get_meta("garden_bay_count", 0)) >= 8)
	assert(storm_environment.find_children(
		"IvoryGardenTerraceCollision", "StaticBody3D", true, false).size() >= 8,
		"storm garden terraces are solid architecture")
	assert(sanctuary_environment.find_children(
		"GardenTrunkCollision", "StaticBody3D", true, false).size() >= 8,
		"the Oldest Tree district has collision-backed mature garden trees")
	assert(matched_environment.find_children(
		"IvoryArcadeLintel", "MeshInstance3D", true, false).size() >= 4,
		"repeated ivory garden arcades match the skyline rhythm of Islands 1 and 2")
	var civic_pavilions := matched_environment.get_node(
		"CivicGardenPavilions") as Node3D
	assert(int(civic_pavilions.get_meta("pavilion_count", 0)) == 3)
	assert(civic_pavilions.find_children(
		"FacetedPavilionDome", "MeshInstance3D", true, false).size() == 3,
		"three faceted observatory pavilions frame the quest district")
	assert(civic_pavilions.find_children(
		"PavilionColumn_*", "MeshInstance3D", true, false).size() == 24,
		"open pavilion colonnades repeat Island 1's civic rhythm without blocking routes")
	var sky_fragments := matched_environment.get_node(
		"DistantSkyGardenFragments") as Node3D
	assert(int(sky_fragments.get_meta("fragment_count", 0)) == 2,
		"two sparse sky gardens add depth behind the Stormworks skyline")
	assert(sky_fragments.find_children(
		"SkyGardenFragment_*", "Node3D", false, false).size() == 2)
	var reflection_eye := Vector3(520.0, 27.0, 15.0)
	var reflection_forward := Vector3(650.0, 34.0, -58.0) - reflection_eye
	reflection_forward.y = 0.0
	reflection_forward = reflection_forward.normalized()
	for fragment_value in sky_fragments.find_children(
			"SkyGardenFragment_*", "Node3D", false, false):
		var fragment := fragment_value as Node3D
		var horizon_offset := fragment.get_meta("storm_horizon_offset", Vector3.ZERO) as Vector3
		var from_reflection_camera := fragment.global_position - reflection_eye
		from_reflection_camera.y = 0.0
		assert(float(fragment.get_meta("background_scale", 1.0)) <= .82,
			"sky gardens remain background accents rather than island-sized foreground props")
		assert(absf(horizon_offset.z) >= 160.0
			and reflection_forward.dot(from_reflection_camera.normalized()) < .80,
			"sky gardens stay outside the actual Reflection Court camera cone")
	assert(sky_fragments.find_children(
		"SkyGardenCanopy_*", "MeshInstance3D", true, false).size() == 6)
	for mesh_value in sky_fragments.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_value as MeshInstance3D
		assert(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
			and bool(mesh.get_meta("decorative_sky_shadow_disabled", false)),
			"distant sky accents cannot cast oversized shadows across the playable court")
	assert(sky_fragments.find_children(
		"*", "CollisionObject3D", true, false).is_empty(),
		"distant fragments remain decorative and cannot create reachable ledges or blockers")
	var garden_trunk := matched_environment.find_child(
		"GardenTrunk", true, false) as MeshInstance3D
	var island_three_palette: Dictionary = world.get("_materials")
	assert(garden_trunk != null and garden_trunk.material_override \
		== island_three_palette.island_three_hero_bark,
		"Island 3 garden trees share the hero-tree bark instead of near-black prototype trunks")
	var paving_stone := matched_environment.find_child("Stone_00_00", true, false) as MeshInstance3D
	assert(paving_stone != null)
	var paving_color := (paving_stone.material_override as StandardMaterial3D).albedo_color
	assert(paving_color.get_luminance() >= .72,
		"Island 3 paving stays in the pearl-ivory value range of Islands 1 and 2")
	assert(island_three.has_node("StormworksArrivalPortico/IvoryArrivalTerraceCollision"))
	assert(island_three.has_node("StormworksArrivalPortico/AetherArrivalArch"))
	assert((island_three.get_node("StormworksArrivalPortico/AetherArrivalArch") as MeshInstance3D).mesh is BoxMesh,
		"the low-poly arrival uses an open lintel instead of another ring")
	assert(island_three.has_node("StormworksArrivalPortico/ArrivalTowerNorthCollision"))
	assert(island_three.has_node("StormworksArrivalPortico/ArrivalTowerSouthCollision"))
	var arrival_gardens := island_three.get_node(
		"StormworksArrivalGardenProcessional") as Node3D
	assert(int(arrival_gardens.get_meta("garden_pair_count", 0)) == 3
		and float(arrival_gardens.get_meta("clear_central_aisle_m", 0.0)) >= 27.0,
		"the long Island 3 arrival uses three paired garden rooms around a broad clear aisle")
	assert(arrival_gardens.find_children("*IvoryBed", "MeshInstance3D", true, false).size() == 6
		and arrival_gardens.find_children("*IvoryBedCollision", "StaticBody3D", true, false).size() == 6,
		"all six arrival garden beds are visible and collision-backed")
	assert(island_three.get_node("StormworksGrandCourt").get_meta("clear_center_radius_m") == 34.0)
	assert(island_three.has_node("StormworksGrandCourt/StormCourtCompass/CompassWedge_01"))
	assert(island_three.get_node("StormworksGrandCourt").find_children(
		"StormCourtGarden_*", "Node3D", false, false).size() == 4,
		"the boss court uses four planted edges and leaves open views to its quest landmarks")
	var lens := island_three.get_node("StormworksGrandCourt/StormLensTower") as Node3D
	var forge := island_three.get_node("StormworksGrandCourt/ResonanceForge") as Node3D
	var archive := island_three.get_node("StormworksGrandCourt/LightningArchive") as Node3D
	var arena_center := MindSparkWorldOne.ZONES[4].position
	var backdrop_parts := [
		[lens, lens.get_node("StormLensPrism") as Node3D],
		[forge, forge.get_node("SuspendedResonanceCore") as Node3D],
		[archive, archive.get_node("ArchiveMemoryShard") as Node3D],
	]
	for backdrop_pair in backdrop_parts:
		var landmark := backdrop_pair[0] as Node3D
		var terrace := landmark.get_node("SolidQuestTerrace") as Node3D
		var backdrop := backdrop_pair[1] as Node3D
		var outward := Vector3(terrace.position.x - arena_center.x, 0,
			terrace.position.z - arena_center.z).normalized()
		var minimum_inset := 11.5 if landmark == lens else 17.5
		assert((backdrop.position - terrace.position).dot(outward) < -minimum_inset
			and str(landmark.get_meta("operator_backdrop_side", "")) == "court_inward",
			"each storm landmark must frame its operator camera from the court side")
	assert((lens.get_node("StormLensPrism") as Node3D).position.y
		> (lens.get_node("SolidQuestTerrace") as Node3D).position.y + 20.0,
		"the northwest quest reads as a tower above the shared instrument")
	var lens_sight := lens.get_node("OpenLensAlignmentFrame") as Node3D
	assert(lens_sight.find_children(
		"IvoryAlignmentBeam_*", "MeshInstance3D", false, false).size() == 6
		and lens_sight.find_children(
			"CyanAlignmentIndex_*", "MeshInstance3D", false, false).size() == 6
		and str(lens_sight.get_meta("design_revision", ""))
			== "compact_hexagonal_calibrated_sight_v2"
		and float(lens_sight.get_meta("frame_span_m", 0.0)) <= 10.8
		and lens.find_children("IvorySightFrame_*", "MeshInstance3D", true, false).is_empty(),
		"the Storm Lens uses one compact calibrated sight instead of an oversized empty frame")
	assert(lens.find_children("LensIvoryMast_*", "MeshInstance3D", true, false).is_empty()
		and lens.find_children("LensIvoryRoofBrace_*", "MeshInstance3D", true, false).is_empty()
		and lens.find_children(
			"LensInstrumentSupport_*Collision", "StaticBody3D", true, false).size() == 3,
		"the lens tower uses three solid survey supports rather than an empty mast scaffold")
	var island_three_materials: Dictionary = world.get("_materials")
	var ivory_support_color: Color = (island_three_materials.shared_style_ivory \
		as StandardMaterial3D).albedo_color
	var charcoal_support_color: Color = (island_three_materials.shared_style_charcoal \
		as StandardMaterial3D).albedo_color
	for masonry_pattern in ["LensCitadelPodium*", "LensCivicButtress*"]:
		for masonry_value in lens.find_children(
				masonry_pattern, "MeshInstance3D", true, false):
			var masonry := masonry_value as MeshInstance3D
			assert((masonry.material_override as StandardMaterial3D).albedo_color \
				.is_equal_approx(ivory_support_color),
				"Storm Lens plinths and buttresses remain ivory masonry, never cyan slabs")
	for support_value in lens.find_children(
			"LensInstrumentSupport_*", "MeshInstance3D", true, false):
		var support := support_value as MeshInstance3D
		assert((support.material_override as StandardMaterial3D).albedo_color \
			.is_equal_approx(ivory_support_color),
			"Storm Lens structural supports stay ivory instead of reading as cyan barriers")
	for joint_value in lens.find_children(
			"LensSupportJoint_*", "MeshInstance3D", true, false):
		var joint := joint_value as MeshInstance3D
		assert((joint.material_override as StandardMaterial3D).albedo_color \
			.is_equal_approx(charcoal_support_color),
			"Storm Lens support joints use the restrained charcoal structural accent")
	var high_lens_parts: Array[Node] = []
	high_lens_parts.append_array(lens.find_children(
		"IvoryAlignmentBeam_*", "MeshInstance3D", true, false))
	high_lens_parts.append_array(lens.find_children(
		"LensSightBrace_*", "MeshInstance3D", true, false))
	assert(high_lens_parts.size() == 9,
		"the Storm Lens retains six compact alignment beams and three short support braces")
	for high_part_value in high_lens_parts:
		var high_part := high_part_value as MeshInstance3D
		assert(high_part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and bool(high_part.get_meta("arrival_foreground_shadow_disabled", false)),
			"high Storm Lens framework stays visible without projecting a lattice over arrival")
		if high_part.name.begins_with("LensSightBrace_"):
			assert((high_part.material_override as StandardMaterial3D).albedo_color \
				.is_equal_approx(charcoal_support_color),
				"Storm Lens braces remain charcoal instead of becoming long cyan lines")
	assert(lens.has_node("LensCitadelPodiumLeftCollision")
		and lens.has_node("LensCitadelPodiumRightCollision")
		and lens.has_node("LensCivicButtressLeftCollision")
		and lens.has_node("LensCivicButtressRightCollision"),
		"the lens has a collision-backed civic silhouette behind its clear forecourt")
	assert((forge.get_node("SuspendedResonanceCore") as MeshInstance3D).mesh != null,
		"the north quest retains its broad, suspended forge core")
	assert(forge.has_node("ForgeFurnaceHallLeftCollision")
		and forge.has_node("ForgeFurnaceHallRightCollision")
		and forge.has_node("ForgeHallPlinthLeftCollision")
		and forge.has_node("ForgeHallPlinthRightCollision"),
		"the resonance forge has a broad collision-backed furnace hall")
	assert((archive.get_node("ArchiveFin_07") as MeshInstance3D).mesh != null,
		"the northeast quest retains the staggered archive skyline")
	assert(archive.has_node("ArchiveBookendTowerLeftCollision")
		and archive.has_node("ArchiveBookendTowerRightCollision")
		and archive.has_node("ArchiveHallBaseLeftCollision")
		and archive.has_node("ArchiveHallBaseRightCollision")
		and archive.has_node("ArchiveCrownLintelCollision"),
		"the archive pages sit inside a solid, recognizable civic hall")
	for storm_landmark in [lens, forge, archive]:
		assert(str(storm_landmark.get_meta("silhouette_revision", "")) \
			== "human_scale_civic_backdrop_v1")
		assert(float(storm_landmark.get_meta("interaction_forecourt_clear_m", 0.0)) >= 11.0)
	var storm_zone := geometry.get_node("05ThoughtStormArena") as Node3D
	assert(is_equal_approx((storm_zone.get_node("BossArenaCollision") as Node3D).position.y, -1.0),
		"legacy boss floor must not bury the new paving and architecture")
	assert(island_three.get_meta("masonry_finish") == "matte_non_emissive")
	assert(not (island_three.get_node("IslandThreeStormDeck") as MeshInstance3D).material_override.emission_enabled,
		"large masonry surfaces reflect light rather than washing out the courtyard")
	assert((island_three.get_node(
		"StormworksGrandCourt/StormLensTower/StormLensPrism") as MeshInstance3D
		).material_override.emission_enabled,
		"storm glass keeps its controlled glow after the masonry finish pass")

	for retired_ring in storm_zone.find_children("LayeredStormRing_*", "MeshInstance3D", true, false):
		assert(not retired_ring.visible, "the oversized legacy vortex must remain retired")
		assert(retired_ring.mesh == null and bool(retired_ring.get_meta("retired_geometry_purged", false)),
			"the retired vortex must not retain Web render resources")
	var retired_tree := geometry.get_node("06OldestTreeSanctuary/MindSparkBioDataTree") as Node3D
	for old_body in retired_tree.find_children("*", "CollisionObject3D", true, false):
		assert((old_body as CollisionObject3D).collision_layer == 0,
			"the invisible retired Oldest Tree must not block the player")
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
	var mode_instruments := [
		["StormworksGrandCourt/StormLensTower/IslandOneStyleQuestInstrument", "align", "ModeCrest_Align", 3],
		["StormworksGrandCourt/ResonanceForge/IslandOneStyleQuestInstrument", "rhythm", "ModeCrest_Rhythm", 5],
		["StormworksGrandCourt/LightningArchive/IslandOneStyleQuestInstrument", "dodge", "ModeCrest_Dodge", 3],
		["RainHarvestObservatory/IslandOneStyleQuestInstrument", "catch", "ModeCrest_Catch", 4],
		["WisdomBasilicaPromenade/RootboundReflectionCourt/IslandOneStyleQuestInstrument", "route", "ModeCrest_Route", 5],
	]
	var distinct_modes := {}
	for mode_spec in mode_instruments:
		var mode_instrument := island_three.get_node(str(mode_spec[0])) as Node3D
		var mode_name := str(mode_spec[1])
		var crest := mode_instrument.get_node(str(mode_spec[2])) as Node3D
		assert(str(mode_instrument.get_meta("design_revision", "")) \
			== "distinct_minigame_crest_v8"
			and str(mode_instrument.get_meta("mini_game_identity", "")) == mode_name,
			"each Island 3 instrument identifies its actual mini-game mode in the world art")
		assert(crest.find_children("*", "MeshInstance3D", true, false).size() == int(mode_spec[3]),
			"the %s console keeps its authored low-poly crest silhouette" % mode_name)
		distinct_modes[mode_name] = true
	assert(distinct_modes.size() == 5,
		"Island 3 exposes five visibly distinct console identities for five mini-game modes")
	assert(island_three.has_node("StormworksGrandCourt/ShieldProcessional_01Collision"))
	assert(island_three.get_node_or_null("CalmRainCloister") == null,
		"the Calm-Rain Cloister is removed from the recovery sequence")
	assert(island_three.has_node("RainHarvestObservatory/RainCollectorTerraceCollision"))
	assert(island_three.has_node("RainHarvestObservatory/RainCrystalReservoir"))
	assert(island_three.has_node("RainHarvestObservatory/FacetedRainDome"))
	var rain_observatory := island_three.get_node("RainHarvestObservatory") as Node3D
	var rain_dome := rain_observatory.get_node("FacetedRainDome") as MeshInstance3D
	assert(str(rain_observatory.get_meta("design_revision", "")) \
		== "restrained_ivory_weather_house_v3_rain_garden"
		and str(rain_observatory.get_meta("cyan_surface_policy", "")) \
		== "water and small glass accents only",
		"Rain Harvest uses restrained civic masonry instead of a neon cyan shell")
	assert(int(rain_observatory.get_meta("rain_garden_bed_count", 0)) == 3
		and int(rain_observatory.get_meta("rain_garden_planting_count", 0)) == 9,
		"the observatory has a restrained rear catchment garden instead of an empty slab")
	assert(rain_observatory.find_children(
		"RainCatchmentBed_*Collision", "StaticBody3D", true, false).size() == 3,
		"every rain-garden bed is solid while the southern operator approach stays open")
	assert((rain_dome.mesh as SphereMesh).radial_segments == 12
		and rain_dome.scale.x <= 9.5 and rain_dome.scale.y <= 5.5,
		"the rain dome stays faceted and below the player-camera-dominating prototype size")
	for rib in rain_observatory.find_children("RainCollectorRib_*", "MeshInstance3D", true, false):
		assert(str((rib as MeshInstance3D).get_meta("finish_role", "")) \
			== "ivory_weather_structure",
			"the weather-house structure is ivory; cyan is reserved for water and glass")
	assert(str(rain_observatory.get_node("CentralRainNeedle").get_meta("finish_role", "")) \
		== "charcoal_weather_needle",
		"the central weather needle remains charcoal instead of becoming another cyan line")
	assert(island_three.has_node("RainHarvestObservatory/CompletionStateVisuals/HarvestedRainWater"))
	assert(island_three.has_node(
		"RainHarvestObservatory/IslandOneStyleQuestInstrument/CyanInstrumentDial"))
	var rain_definition := load(
		"res://resources/mind_spark/quest_objects/09_calm_rain_basin.tres") as QuestObjectDefinition
	assert(rain_definition.display_name == "Rain Harvest Observatory",
		"the preserved calm-rain save object uses the finished architecture's player-facing name")
	assert(island_three.has_node("WisdomBasilicaPromenade/OldestTreeReflectionApseCollision"))
	assert(island_three.has_node("WisdomBasilicaPromenade/RootboundReflectionCourt/ReflectionMemorySeed"))
	assert(island_three.has_node("WisdomBasilicaPromenade/RootboundReflectionCourt/ReflectionPool"))
	assert(island_three.has_node("WisdomBasilicaPromenade/RootboundReflectionCourt/ReflectionMarker_01"))
	var reflection_court := island_three.get_node(
		"WisdomBasilicaPromenade/RootboundReflectionCourt") as Node3D
	assert(str(reflection_court.get_meta("design_revision", "")) \
		== "rootbound_grove_pavilion_v5_clear_arcade")
	assert(float(reflection_court.get_meta("clear_story_entrance_m", 0.0)) >= 22.0)
	assert(float(reflection_court.get_meta("clear_inner_court_radius_m", 0.0)) >= 24.0,
		"the reflection console sits in an open court instead of a field of root stakes")
	assert(reflection_court.find_children(
		"ReflectionRootRib_*", "MeshInstance3D", true, false).size() == 6)
	assert(reflection_court.find_children(
		"ReflectionRootCrown_*", "MeshInstance3D", true, false).size() == 6)
	assert(reflection_court.find_children(
		"ReflectionRootShoulder_*", "MeshInstance3D", true, false).size() == 6,
		"ivory shoulder joints tie the living roots into the civic architecture")
	assert(reflection_court.find_children(
		"ReflectionRootFoot_*Collision", "StaticBody3D", true, false).size() == 6,
		"each visible reflection root has a matching player collision foot")
	for root_index in 6:
		var root_foot := reflection_court.get_node(
			"ReflectionRootFoot_%02d" % (root_index + 1)) as MeshInstance3D
		var root_mesh := root_foot.mesh as CylinderMesh
		assert(root_mesh.bottom_radius > root_mesh.top_radius * 2.0,
			"reflection root feet need a broad organic flare")
		assert(root_mesh.height <= 1.11,
			"reflection root feet stay low so the sloped living ribs own the silhouette")
	var reflection_canopy_count := reflection_court.find_children(
		"ReflectionCanopyMass_*", "MeshInstance3D", true, false).size()
	for canopy_index in 6:
		assert(reflection_court.has_node(
			"ReflectionCanopyMass_%02d" % (canopy_index + 1)),
			"reflection canopy node %02d is preserved" % (canopy_index + 1))
	assert(reflection_canopy_count == 6,
		"the reflection pavilion has six low faceted canopy masses at player height; found %d" \
		% reflection_canopy_count)
	var reflection_center := (reflection_court.get_node("ReflectionPool") as Node3D).position
	for root_rib in reflection_court.find_children(
			"ReflectionRootRib_*", "MeshInstance3D", true, false):
		var rib_finish: Vector3 = (root_rib as MeshInstance3D).get_meta("path_end")
		assert(Vector2(rib_finish.x, rib_finish.z).distance_to(
			Vector2(reflection_center.x, reflection_center.z)) >= 24.0,
			"reflection roots stop at perimeter buttresses instead of converging into a black roof")
	assert(island_three.has_node(
		"WisdomBasilicaPromenade/RootboundReflectionCourt/IslandOneStyleQuestInstrument/CyanInstrumentDial"))
	assert(not island_three.has_node("WisdomBasilicaPromenade/CyanBasilicaRidge"),
		"the unsupported blue line over the Island 3 promenade is removed")
	var wisdom_basilica := island_three.get_node("WisdomBasilicaPromenade") as Node3D
	assert(str(wisdom_basilica.get_meta("design_revision", "")) \
		== "living_grove_processional_v6_crowned_arcade")
	assert(int(wisdom_basilica.get_meta("living_grove_bay_count", 0)) == 4)
	assert(float(wisdom_basilica.get_meta("open_arrival_fraction", 0.0)) >= .40,
		"the reflection promenade keeps its arrival sightline open before the grove bays")
	assert(float(wisdom_basilica.get_meta("clear_nave_width_m", 0.0)) >= 25.0,
		"the living-grove trunks leave a broad player and camera corridor")
	var story_axis_start: Vector3 = wisdom_basilica.get_meta("story_axis_start")
	var story_axis_end: Vector3 = wisdom_basilica.get_meta("story_axis_end")
	var reflection_axis_point := Geometry3D.get_closest_point_to_segment_uncapped(
		reflection_center, story_axis_start, story_axis_end)
	assert(Vector2(reflection_center.x, reflection_center.z).distance_to(
		Vector2(reflection_axis_point.x, reflection_axis_point.z)) < .25
		and bool(wisdom_basilica.get_meta("reflection_camera_axis_clear", false)),
		"the reflection station and its player camera stay on the open living-grove nave")
	assert(wisdom_basilica.find_children(
		"WisdomGroveTrunk_*Collision", "StaticBody3D", true, false).size() == 8,
		"the living promenade uses eight collision-backed trunks around its open nave")
	assert(int(wisdom_basilica.get_meta("paired_canopy_count", 0)) == 8,
		"every grove trunk has a paired low canopy instead of ending as a bare pole")
	assert(int(wisdom_basilica.get_meta("visible_fork_count", 0)) == 8,
		"visible bark forks connect the paired crowns to their trunks")
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
	var oldest_tree_zone := geometry.get_node("06OldestTreeSanctuary") as Node3D
	assert(oldest_tree_zone.has_node("OldestTreeMemoryStar")
		and oldest_tree_zone.find_children(
			"OldestTreeMemoryShard_*", "MeshInstance3D", true, false).size() == 4,
		"the final shrine uses a faceted lavender memory seed with four cyan shards")
	assert(oldest_tree_zone.find_child("StarCore", true, false) == null
		and str(oldest_tree_zone.get_meta("oldest_tree_shrine_palette", "")).contains("no gold"),
		"the legacy gold sphere is removed from Island 3's final tree court")
	assert(island_three.has_node("OldestTreeLivingCathedral/GreatBough_01A"))
	assert(island_three.find_children("RootNaveInlay_*", "MeshInstance3D", true, false).is_empty(),
		"the Oldest Tree approach has no loose cyan floor bars")
	assert(island_three.get_node("OldestTreeLivingCathedral").find_children(
		"CanopyLeafMass_*", "MeshInstance3D", true, false).size() == 25,
		"the Oldest Tree crown leaves space between its five primary boughs")
	var shared_palette: Dictionary = world.get("_materials")
	assert((island_three.get_node("OldestTreeLivingCathedral/LivingHeartwood") as MeshInstance3D).material_override \
		.albedo_color == shared_palette.island_three_hero_bark.albedo_color,
		"the Oldest Tree has a warm bark trunk like Island One's hero tree")
	var cathedral := island_three.get_node("OldestTreeLivingCathedral") as Node3D
	assert(str(cathedral.get_meta("design_revision", "")) == "root_crown_cathedral_v4_human_scale_canopy")
	assert(cathedral.has_node("HeartwoodLowerTrunk") and cathedral.has_node("HeartwoodUpperTrunk"),
		"the Oldest Tree uses a tapered two-stage visible trunk around its collision core")
	assert(cathedral.find_children(
		"CathedralRootTip_*", "MeshInstance3D", true, false).size() == 10,
		"the root flare bends through shoulders instead of ending as ten straight spikes")
	assert(cathedral.find_children(
		"LowerCanopyMass_*", "MeshInstance3D", true, false).size() == 10,
		"living foliage enters the normal player camera below the high crown")
	var cathedral_base_y := (cathedral.get_node("LivingHeartwood") as Node3D).position.y - 26.0
	assert((cathedral.get_node("LivingCathedralCrown") as Node3D).position.y \
		- cathedral_base_y <= 79.1,
		"the crown stays inside the human-scale tree silhouette")
	var ivory_canopy_count := 0
	var living_canopy_count := 0
	var living_canopy_colors := [shared_palette.island_three_sage.albedo_color,
		shared_palette.island_three_sage_deep.albedo_color,
		shared_palette.island_three_moss.albedo_color]
	for leaf in cathedral.find_children("CanopyLeafMass_*", "MeshInstance3D", true, false):
		var leaf_color: Color = (leaf as MeshInstance3D).material_override.albedo_color
		if leaf_color == shared_palette.island_three_canopy_ivory.albedo_color:
			ivory_canopy_count += 1
		elif leaf_color in living_canopy_colors:
			living_canopy_count += 1
	assert(living_canopy_count >= 20 and ivory_canopy_count <= 5,
		"the Oldest Tree reads as living foliage with ivory reserved for blossom accents")
	var ribbon_colors: Array[Color] = []
	for ribbon in cathedral.find_children("HeartwoodBarkRibbon_*", "MeshInstance3D", true, false):
		var ribbon_material := (ribbon as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if ribbon_material != null:
			ribbon_colors.append(ribbon_material.albedo_color)
	assert(shared_palette.island_three_hero_bark_highlight.albedo_color in ribbon_colors
		and shared_palette.island_three_hero_bark_shadow.albedo_color in ribbon_colors,
		"alternating bark facets give the hero trunk readable low-poly depth; got %s" % str(ribbon_colors))
	assert(island_three.has_node("LowPolyUndersideAccents/EmbeddedAetherCrystal_01"))
	var return_arch_left := geometry.get_node(
		"06OldestTreeSanctuary/ReturnWorldGate/Left") as MeshInstance3D
	assert(return_arch_left.material_override == world.get("_materials").celestial_floor,
		"the old gold return arch is refinished in ivory")
	var return_arch := geometry.get_node("06OldestTreeSanctuary/ReturnWorldGate") as Node3D
	assert(str(return_arch.get_meta("design_revision", "")) == "sanctuary_portal_v2")
	assert(float(return_arch.get_meta("clear_opening_width_m", 0.0)) >= 24.0)
	assert(bool(return_arch.get_meta("faces_oldest_tree_court", false))
		and absf(return_arch.rotation.y) > .8,
		"the portal opening faces the sanctuary approach instead of reading edge-on")
	assert(return_arch.has_node("ReturnGateSteppedFoot_West")
		and return_arch.has_node("ReturnGateSteppedFoot_East")
		and return_arch.has_node("ReturnGateCrownCrystal")
		and return_arch.has_node("ReturnGateThresholdCollision"),
		"the return threshold is a finished, collision-backed sanctuary portal")
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
	assert(island_three.get_node_or_null(
		"WisdomBasilicaPromenade/LeftBasilicaCornice") == null)
	assert(island_three.get_node_or_null(
		"WisdomBasilicaPromenade/LeftLivingRootRail") == null)
	for removed_ring in geometry.find_children("*", "MeshInstance3D", true, false):
		if bool(removed_ring.get_meta("island_three_gold_ring_removed", false)):
			assert(not (removed_ring as MeshInstance3D).visible \
				and (removed_ring as MeshInstance3D).mesh == null,
				"all removed Island 3 gold rings release their render resources")
		if bool(removed_ring.get_meta("island_three_gold_line_removed", false)):
			assert(not (removed_ring as MeshInstance3D).visible \
				and (removed_ring as MeshInstance3D).mesh == null,
				"all removed Island 3 gold lines release their render resources")
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
	assert(str(island_one_collisions.get_meta("inventory_revision", "")) \
		== "explicit_architecture_v1")
	var collision_shape_count := int(island_one_collisions.get_meta("collision_shape_count", 0))
	assert(collision_shape_count >= 500 and collision_shape_count < 1000,
		"Island One uses a reviewed solid-architecture inventory instead of every visible mesh")
	var inventory_counts := island_one_collisions.get_meta("inventory_counts", {}) as Dictionary
	for required_role in [
		"learning_instrument", "quest_cabinet", "garden_tree_trunk",
		"hero_tree_structure", "compass_structure", "arrival_architecture",
		"quest_support", "perimeter_architecture",
	]:
		assert(int(inventory_counts.get(required_role, 0)) > 0,
			"Island One collision inventory is missing %s" % required_role)
	for selected_shape_value in island_one_collisions.get_children():
		var selected_shape := selected_shape_value as CollisionShape3D
		var selected_source := str(selected_shape.get_meta("source_mesh", ""))
		assert(not selected_source.is_empty() \
			and not str(selected_shape.get_meta("inventory_role", "")).is_empty())
		for decorative_marker in [
			"/PuzzlePowerConduits/", "/SolvedRouteProjection/RouteLight_",
			"/ScienceArtGarden/GoldenAnglePavementPip_", "/ThoughtSpark_",
			"/CompassToEchoTreeLearningPromenade/", "/EntryWorldGate/Portal/",
		]:
			assert(decorative_marker not in selected_source,
				"decorative Island One mesh entered the solid inventory: %s" % selected_source)
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
