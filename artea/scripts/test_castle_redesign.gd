extends SceneTree

func _run() -> void:
	# Load after autoloads exist; preloading the complete hub while this test
	# compiles makes its NPC scripts resolve Global/GameManager too early.
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(hub)
	for _frame in 20:
		await process_frame
	await physics_frame

	var redesign := hub.get_node_or_null("CastleRedesign")
	var castle := hub.get_node_or_null("building_castle_red2") as Node3D
	var architecture := hub.get_node_or_null("CastleArchitecture") as Node3D
	assert(redesign != null, "castle-only redesign controller is installed in the real hub")
	assert(castle != null, "original authored gameplay castle remains installed")
	assert(architecture != null, "detailed castle castle architecture is installed")
	assert(architecture.get_meta("render_family", "") == "red_village_hexagons_castle",
		"procedural castle architecture uses the same render family as the village kit")
	var barbican := architecture.get_node_or_null(
		"CastleBridgeBarbican") as Node3D
	var barbican_towers := barbican.find_children(
		"BarbicanTower*", "MeshInstance3D", true, false) if barbican != null else []
	assert(barbican_towers.size() == 2,
		"the bridge entrance retains its paired village-style barbican towers")
	for tower_candidate in barbican_towers:
		var tower := tower_candidate as MeshInstance3D
		assert(tower.get_node_or_null("SolidBarbicanTower/SolidShape") != null,
			"barbican tower %s is solid and cannot be walked through" % tower.name)
		assert(absf(tower.position.z) >= 4.19,
			"solid barbican tower %s leaves a full player lane beside the fire" % tower.name)
	var stair_tower := hub.get_node_or_null("CastleStairs/CastleStair/MasonryTower") as MeshInstance3D
	assert(stair_tower != null and stair_tower.material_override != null
		and stair_tower.material_override.get_meta("castle_role", "") == "stained_glass",
		"the spiral stair tower's core is glazed in stained glass")
	assert(hub.get_node("CastleStairs/CastleStair").find_children(
			"AetherWindow*", "Node3D", false, false).is_empty(),
		"the square panels on the stair tower are removed")
	var village_masonry := hub.get_node_or_null("VillageStyleStairTowerMasonry") as Node3D
	assert(village_masonry == null,
		"thin protruding masonry lines are removed from around the stair tower")

	var palette_found := false
	for mesh_candidate in castle.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := mesh_candidate as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var material := mesh_node.get_active_material(surface)
			if material is StandardMaterial3D and material.get_meta("castle_palette", "") \
					== "sleeping_beauty_rose_atlas" \
					and not (material as StandardMaterial3D).emission_enabled:
				palette_found = true
	assert(palette_found, "castle uses the non-emissive rose (Sleeping Beauty) village atlas")
	assert(architecture.find_children("*TurretRoof", "MeshInstance3D", true, false).size() == 4,
		"four castle turrets carry spire roofs")
	for roof in architecture.find_children("*TurretRoof", "MeshInstance3D", true, false):
		assert((roof as MeshInstance3D).material_override.get_meta(
			"original_palette_role", "") == "sleeping_beauty_blue_roof",
			"added turret roofs match the castle's blue roofs")
		assert(architecture.get_node_or_null("%sFinialOrb" % roof.name) != null,
			"each turret spire is topped with a gold finial")
	for lancet in architecture.find_children("GothicLancet_*", "Node3D", true, false):
		var glass := lancet.get_node_or_null("StainedGlass") as MeshInstance3D
		assert(glass != null and glass.material_override.get_meta("castle_role", "")
			== "stained_glass", "every lancet frame is glazed with stained glass")
	assert(architecture.get_node_or_null("RoseWindow/StainedGlass") != null,
		"the entrance face carries a stained-glass rose window")
	assert(architecture.find_children("GothicButtress_*", "Node3D", true, false).size() == 4,
		"castle-only redesign retains detailed Gothic buttresses")
	assert(architecture.find_children("GothicLancet_*", "Node3D", true, false).size() == 4,
		"four glazed lancet frames complete the keep detailing")
	assert(architecture.get_node_or_null("LowerKeepHoarding") == null
		and architecture.get_node_or_null("UpperKeepHoarding") == null,
		"both wooden rings around the upper castle are removed")
	assert(hub.find_children("RoyalTread_*", "MeshInstance3D", true, false).size() == 18,
		"continuous castle stair reaches from lower court to upper door")
	assert(hub.find_children("RoyalStairNewel*", "MeshInstance3D", true, false).size() == 4,
		"lower and upper stair landings are framed by grounded newel towers")
	assert(hub.find_children("AscentRoyalShield*", "MeshInstance3D", true, false).size() == 6,
		"original red accents repeat along the full castle ascent")
	var architecture_bodies := architecture.find_children(
		"*", "StaticBody3D", true, false)
	assert(architecture_bodies.size() >= 12,
		"wide gate, continuous courtyard barriers and stone planters are solid")
	for body_candidate in architecture_bodies:
		assert((body_candidate as StaticBody3D).name in ["SolidBarbicanTower",
			"SolidAscentCheek", "CourtyardSolidBody"],
			"only authored courtyard structures add collision, not tiny decorative details")

	for technology_path in ["ReferenceAstralMachine", "HighAetherFacade",
			"AstralObservatoryCrown", "AetherCalibrationBand"]:
		var technology := hub.get_node_or_null("CastleFoundation/%s" % technology_path) \
			as Node3D
		assert(technology == null,
			"%s is not built into the simple castle silhouette" % technology_path)
	var gallery_ring := hub.get_node_or_null(
		"CastleFoundation/GalleryFoundationPlaza") as MeshInstance3D
	assert(gallery_ring == null or not gallery_ring.visible,
		"large grey circular platform beneath the front door is removed")
	var root_crown := hub.get_node_or_null(
		"CastleFoundation/GiantTreeFoundation/IntegratedCastleRootCrown") as Node3D
	assert(root_crown != null and root_crown.get_node_or_null("CastleRootCrownCore") != null,
		"a flared central root crown joins the tree trunk to the castle foundation")
	assert(root_crown.find_children("UnderCastleBearingRoot_*", "MeshInstance3D",
		true, false).size() == 8,
		"eight radial bearing roots distribute the castle load across its underside")
	assert(root_crown.find_children("UnderCastleCrossTie_*", "MeshInstance3D",
		true, false).size() == 8,
		"interwoven root ties visually consolidate the castle support crown")
	var stair := hub.get_node_or_null("CastleStairs/CastleStair") as Node3D
	assert(stair != null, "real bridge route remains installed")
	for obsolete_frame in stair.find_children("*AetherLensGate", "Node3D", true, false) \
			+ stair.find_children("MidspanResonanceFrame", "Node3D", true, false):
		assert(not (obsolete_frame as Node3D).visible,
			"technology frame %s is removed from the bridge" % obsolete_frame.name)
	for obsolete_rib in stair.find_children("AetherTensionRib_*", "MeshInstance3D", true, false):
		assert(not (obsolete_rib as MeshInstance3D).visible,
			"hanging underside rib %s is removed from the simplified bridge" % obsolete_rib.name)
	var entrance := hub.get_node_or_null("CastleEntrance/CastleEntrance") as Node3D
	var terrace_rings := entrance.find_children("TerraceLevitationRing_*",
		"MeshInstance3D", true, false) if entrance != null else []
	for terrace_ring in terrace_rings:
		assert(not (terrace_ring as MeshInstance3D).visible,
			"tree-root-adjacent ring %s is removed" % terrace_ring.name)
	var receiving_court := entrance.get_node_or_null(
		"CastleArrivalTerrace") as MeshInstance3D
	assert(not entrance.has_node("CastleBridgeReceivingCourt"),
		"the raised receiving rectangle is removed in favour of one continuous floor")
	var masonry_bridge := architecture.get_node_or_null("CastleMasonryCauseway") as Node3D
	assert(receiving_court != null and masonry_bridge != null,
		"bridge meets the single solid arrival floor")
	assert(receiving_court.visible
		and String(receiving_court.get_meta("surface_policy", "")) \
			== "single_collision_backed_floor_no_overlay",
		"arrival court keeps only its thin visible collision-backed surface")
	var receiving_bounds := receiving_court.global_transform * receiving_court.mesh.get_aabb()
	assert(absf(receiving_bounds.end.y - (masonry_bridge.global_position.y + 0.22)) <= 0.04,
		"arrival floor meets the masonry deck's actual walkable top")
	assert(architecture.get_node_or_null("CastleTimberCauseway") == null,
		"raised wooden plank overlay is removed")
	var fire := entrance.get_node_or_null("CastleCourtyardFire") as Node3D
	var live_flames := fire.get_node_or_null("CourtyardLiveFlames") as Node3D \
		if fire != null else null
	var fire_light := fire.get_node_or_null("CourtyardFireLight") as OmniLight3D \
		if fire != null else null
	var fire_pedestal := fire.get_node_or_null("CourtyardFirePedestal") as MeshInstance3D \
		if fire != null else null
	assert(live_flames != null
		and live_flames.find_children("CourtyardFlame_*", "MeshInstance3D", true, false).size() >= 6
		and fire_light != null and fire_light.visible,
		"central orb is replaced by layered real-time animated fire")
	assert(live_flames.get_meta("animation", "") == "real_time_independent_flame_sway",
		"courtyard flame cluster identifies its real-time animation")
	assert(fire.get_node_or_null("CourtyardFireCore") == null,
		"old floating sphere fire core is removed")
	assert(fire_pedestal != null
		and fire.find_children("*", "StaticBody3D", true, false).size() == 2,
		"original pedestal and bowl remain solid with no added court barriers")
	assert(absf(fire_pedestal.global_position.z - 27.41) <= 0.02,
		"live fire occupies the old orange orb's exact central position")
	assert(fire.get_node_or_null("MedievalHearthWard") == null
		and fire.find_children("CourtyardHearthPaver_*", "MeshInstance3D", true, false).is_empty(),
		"clipping hearth barriers and extra paving are removed from the existing court")
	var ground_roots := hub.find_children("GroundButtressRoot_*", "MeshInstance3D", true, false)
	assert(ground_roots.size() == 10, "ten exposed ground-root mounds remain installed")
	for root_candidate in ground_roots:
		var ground_root := root_candidate as MeshInstance3D
		assert(bool(ground_root.get_meta("walkable_ground_mound", false))
			and ground_root.find_children("WalkableRootBody", "StaticBody3D", true, false).size() == 1,
			"%s has one smooth closed walkable collision hull" % ground_root.name)
	for fire_mesh_candidate in fire.find_children("*", "MeshInstance3D", true, false):
		assert(not (fire_mesh_candidate as MeshInstance3D).mesh is TorusMesh,
			"the fire beacon has no orbit rings or wide fountain platform")
	var commander := hub.get_node_or_null("Knight2") as Node3D
	assert(commander != null and commander.visible
		and commander.get_meta("castle_role", "") == "upper_court_commander",
		"animated commander is moved to the castle's raised upper court")
	assert(absf(commander.global_position.y - 78.33) < 0.08 and absf(commander.global_position.z - 27.41) > 2.4,
		"commander stands at the top while remaining outside the central stair lane")
	for cap_candidate in stair.find_children("*Cap*", "MeshInstance3D", true, false):
		var cap := cap_candidate as MeshInstance3D
		if cap.visible and ("guard" in String(cap.name).to_lower()
				or "continuous" in String(cap.name).to_lower()):
			assert(cap.get_meta("castle_palette_role", "") == "dark_oak_stair_edge",
				"%s uses village dark oak instead of a red racetrack stripe" % cap.name)
	var crystal_front_root := hub.get_node_or_null(
		"CastleFoundation/GiantTreeFoundation/FrontWallCenterSupports/CrystalWindowFrontCenterRoot") \
		as MeshInstance3D
	var crystal_grips := hub.find_children("CrystalWindowFrontWallGripRoot_*",
		"MeshInstance3D", true, false)
	assert(crystal_front_root != null and crystal_grips.is_empty(),
		"crystal-side root ends under the court without wall-grip branches")
	var crystal_root_bounds := crystal_front_root.global_transform \
		* crystal_front_root.mesh.get_aabb()
	var terrace_bounds := (entrance.get_node("CastleArrivalTerrace") as MeshInstance3D) \
		.global_transform * (entrance.get_node("CastleArrivalTerrace") as MeshInstance3D) \
		.mesh.get_aabb()
	assert(crystal_root_bounds.end.y < terrace_bounds.position.y,
		"tree root stays below the front-castle ground slab")
	assert(stair.get_node_or_null("GroundEntranceApron") == null
		and stair.get_node_or_null("EntranceRune") == null,
		"circular stair-ground apron and rune are removed")
	var first_tread := stair.get_node_or_null("StairTread_000") as MeshInstance3D
	var first_tread_bounds := first_tread.global_transform * first_tread.mesh.get_aabb()
	var terrain_ground := float(stair.get_meta("terrain_ground_y"))
	assert(absf(first_tread_bounds.position.y - terrain_ground) <= 0.03,
		"spiral stair begins directly on sampled terrain")
	var tower_base: Vector2 = stair.get_meta("tower_base")
	var inner_guard_face := float(stair.get_meta("inner_guard_lane_face_radius"))
	var outer_guard_face := float(stair.get_meta("outer_guard_lane_face_radius"))
	var visible_inner_clearance := float(stair.get_meta(
		"visible_tread_inner_clearance"))
	for tread_candidate in stair.find_children("StairTread_*", "MeshInstance3D",
			true, false):
		var tread := tread_candidate as MeshInstance3D
		var tread_mesh := tread.mesh as BoxMesh
		var tread_radius := Vector2(tread.global_position.x - tower_base.x,
			tread.global_position.z - tower_base.y).length()
		var tread_inner_radius := tread_radius - tread_mesh.size.x * 0.5
		# The outer corners sit farther from the tower than the radial box face.
		# Proving corner clearance catches the exact clipping seen in the report.
		var tread_outer_corner_radius := sqrt(pow(
			tread_radius + tread_mesh.size.x * 0.5, 2.0)
			+ pow(tread_mesh.size.z * 0.5, 2.0))
		assert(tread_inner_radius >= inner_guard_face + visible_inner_clearance - 0.01,
			"%s stops before the inner masonry instead of clipping through it" \
			% tread.name)
		assert(tread_outer_corner_radius <= outer_guard_face - 0.03,
			"%s stops cleanly behind the outer masonry without clipping through it" % tread.name)
	var finished_roadbed := stair.get_node_or_null("AscentRoadbed") as MeshInstance3D
	var hidden_walk_inner_radius := float(stair.get_meta("stair_tread_inner_radius"))
	assert(hidden_walk_inner_radius <= inner_guard_face - 0.04,
		"hidden continuous walk surface still overlaps inner guard with no trap seam")
	var inner_skirting := stair.get_node_or_null("InnerParapetLaneSkirting") \
		as MeshInstance3D
	assert(inner_skirting != null and inner_skirting.visible \
		and bool(inner_skirting.get_meta("closes_visible_tread_seam", false)),
		"dressed inner skirting closes the visual stair-to-parapet joint")
	assert(finished_roadbed != null \
		and bool(finished_roadbed.get_meta("covers_riser_bottoms", false)),
		"continuous stone roadbed closes the tread-to-barrier seam and finished underside")
	var last_tread_candidates := stair.find_children("StairTread_*", "MeshInstance3D",
		true, false)
	var last_tread := last_tread_candidates[last_tread_candidates.size() - 1] \
		as MeshInstance3D
	var last_tread_bounds := last_tread.global_transform * last_tread.mesh.get_aabb()
	for guard_name in ["OuterContinuousGuard", "InnerContinuousGuard"]:
		var guard := stair.get_node_or_null(guard_name) as MeshInstance3D
		assert(guard != null and guard.mesh != null,
			"%s exists beside the spiral stair" % guard_name)
		var guard_bounds := guard.global_transform * guard.mesh.get_aabb()
		assert(guard_bounds.position.y <= first_tread_bounds.end.y,
			"%s begins no higher than the terrain-level first tread" % guard_name)
		assert(guard_bounds.end.y >= last_tread_bounds.end.y + 1.0,
			"%s protects the final tread through the crown" % guard_name)
	var outer_guard := stair.get_node("OuterContinuousGuard") as MeshInstance3D
	assert(float(outer_guard.get_meta("bottom_offset")) <= -0.6,
		"continuous outer fascia hides the tread and riser boxes below the stair")
	var entry_foundation := stair.get_node_or_null(
		"TerrainFittedEntryFoundation") as MeshInstance3D
	assert(entry_foundation != null and entry_foundation.mesh != null
		and bool(entry_foundation.get_meta("terrain_fitted")),
		"first stair flight has a terrain-fitted low-poly foundation")
	assert(entry_foundation.find_children("*", "StaticBody3D", true, false).size() == 1,
		"ground transition is solid and leaves no walk-under gap")
	var medieval_details := stair.get_node_or_null("MedievalStairDetails") as Node3D
	assert(medieval_details != null
		and medieval_details.get_meta("render_family", "") \
			== "red_village_hexagons_castle",
		"spiral stair uses the same medieval render family as the castle and village")
	assert(medieval_details.find_children("OuterStoneNewel_*", "MeshInstance3D",
		true, false).size() >= 10,
		"regular stone newels break up the long spiral silhouette")
	assert(medieval_details.find_children("NewelRedRoof_*", "MeshInstance3D",
		true, false).size() >= 10,
		"red roof caps repeat the nearby castle tower language")
	assert(medieval_details.find_children("UndersideCorbel_*", "MeshInstance3D",
		true, false).is_empty(),
		"no decorative corbel ends project below the continuous stair soffit")
	assert(medieval_details.find_children("*", "StaticBody3D", true, false).size() >= 12
		and medieval_details.get_meta("collision_policy", "") \
			== "solid_keep_details_outside_continuous_guard_lane",
		"medieval stair newels remain solid outside the proven route")
	assert(stair.get_node_or_null("LowPolyStairGrowth") == null,
		"green vine and fibre stripes are removed from the castle stair")
	assert(stair.find_children("AetherWindow_*", "MeshInstance3D", true, false).is_empty(),
		"arcane tower windows are removed from the medieval stair tower")
	assert(stair.find_children("ReferenceRoundArchWindow*", "Node3D",
		true, false).size() >= 20,
		"rounded stone-framed windows match the original castle tower")
	var outer_parapet := stair.get_node_or_null("OuterStoneParapet") as MeshInstance3D
	var inner_parapet := stair.get_node_or_null("InnerStoneParapet") as MeshInstance3D
	assert(outer_parapet != null and outer_parapet.visible
		and inner_parapet != null and inner_parapet.visible,
		"finished stone parapets replace the oversized dark ribbon walls")
	assert(bool(outer_parapet.get_meta("full_height_closed_barrier", false))
		and bool(inner_parapet.get_meta("full_height_closed_barrier", false)),
		"solid-looking stone barriers cover the complete stair edge")
	assert(stair.get_node_or_null("OuterContinuousCap") == null
		and stair.get_node_or_null("InnerContinuousCap") == null
		and medieval_details.find_children("OuterOakRailBay_*", "MeshInstance3D",
			true, false).is_empty(),
		"thin continuous lines are removed from around the castle stair")
	for duplicate_visual in stair.find_children("LumenBridgeSurfacePlank_*",
			"MeshInstance3D", true, false) \
			+ stair.find_children("AetherTensionCollar_*", "MeshInstance3D", true, false) \
			+ stair.find_children("AetherBridgeKeel", "MeshInstance3D", true, false):
		assert(not (duplicate_visual as MeshInstance3D).visible,
			"duplicate bridge visual %s is hidden" % duplicate_visual.name)
	var roadbed := stair.get_node_or_null("LumenBridgeRoadbed") as MeshInstance3D
	assert(roadbed != null and not roadbed.visible
		and roadbed.find_children("*", "StaticBody3D", true, false).size() == 1,
		"one authoritative bridge collider remains without a coplanar duplicate floor")
	assert(architecture.find_children("DrawbridgeCrossbeam_*", "MeshInstance3D", true, false).is_empty()
		and architecture.find_children("OakSideStringer*", "MeshInstance3D", true, false).is_empty(),
		"timber crossbeams and stringers are replaced by the closed stone vault")
	assert(masonry_bridge.find_children("*", "MeshInstance3D", true, false).size() == 1,
		"editable Blender bridge is batched into one runtime mesh")

	print("CASTLE_REDESIGN_TEST: PASS — castle palette, grounded architecture, and full door ascent installed")
	hub.queue_free()
	quit()


func _init() -> void:
	call_deferred("_run")
