extends SceneTree

const HUB_SCENE := preload("res://scenes/New_Hub_World.tscn")


func _run() -> void:
	var hub := HUB_SCENE.instantiate() as Node3D
	root.add_child(hub)
	for _frame in 20:
		await process_frame
	await physics_frame

	var redesign := hub.get_node_or_null("MedievalCastleRedesign")
	var castle := hub.get_node_or_null("building_castle_red2") as Node3D
	var architecture := hub.get_node_or_null("MedievalCastleArchitecture") as Node3D
	assert(redesign != null, "castle-only redesign controller is installed in the real hub")
	assert(castle != null, "original authored gameplay castle remains installed")
	assert(architecture != null, "detailed medieval castle architecture is installed")

	var palette_found := false
	for mesh_candidate in castle.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := mesh_candidate as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for surface in mesh_node.mesh.get_surface_count():
			var material := mesh_node.get_active_material(surface)
			if material is StandardMaterial3D and material.get_meta("castle_palette", "") \
					== "simple_village_atlas" \
					and not (material as StandardMaterial3D).emission_enabled:
				palette_found = true
	assert(palette_found, "castle uses the same simple non-emissive village atlas")
	assert(architecture.find_children("*TurretRoof", "MeshInstance3D", true, false).size() == 4,
		"four castle turrets use the restored red roof language")
	for roof in architecture.find_children("*TurretRoof", "MeshInstance3D", true, false):
		assert((roof as MeshInstance3D).material_override.get_meta(
			"original_palette_role", "") == "reference_red_roof",
			"added turret roofs match the original red castle roofs")
	assert(architecture.find_children("GothicButtress_*", "Node3D", true, false).size() == 4,
		"castle-only redesign retains detailed Gothic buttresses")
	assert(architecture.find_children("GothicLancet_*", "Node3D", true, false).size() == 4,
		"castle-only redesign retains pointed lancet frames")
	assert(architecture.get_node_or_null("LowerKeepHoarding") == null
		and architecture.get_node_or_null("UpperKeepHoarding") == null,
		"both wooden rings around the upper castle are removed")
	assert(architecture.find_children("GrandAscentTread_*", "MeshInstance3D", true, false).size() == 18,
		"continuous medieval stair reaches from lower court to upper door")
	assert(architecture.find_children("AscentNewelTower*", "MeshInstance3D", true, false).size() == 4,
		"lower and upper stair landings are framed by grounded newel towers")
	assert(architecture.find_children("AscentHeraldicShield*", "MeshInstance3D", true, false).size() == 8,
		"original red accents repeat along the full castle ascent")
	assert(architecture.find_children("*", "StaticBody3D", true, false).is_empty(),
		"new visual castle detail does not alter authored route collision")

	for technology_path in ["ReferenceAstralMachine", "HighAetherFacade",
			"AstralObservatoryCrown", "AetherCalibrationBand"]:
		var technology := hub.get_node_or_null("CastleFoundation/%s" % technology_path) \
			as Node3D
		assert(technology == null,
			"%s is not built into the simple castle silhouette" % technology_path)
	var gallery_ring := hub.get_node_or_null(
		"CastleFoundation/GalleryFoundationPlaza") as MeshInstance3D
	assert(gallery_ring != null and not gallery_ring.visible,
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
	assert(terrace_rings.size() == 2, "the two terrace rings have stable identities")
	for terrace_ring in terrace_rings:
		assert(not (terrace_ring as MeshInstance3D).visible,
			"tree-root-adjacent ring %s is removed" % terrace_ring.name)
	var receiving_court := entrance.get_node_or_null(
		"CastleBridgeReceivingCourt") as MeshInstance3D
	var final_bridge_plank := architecture.get_node_or_null(
		"MedievalTimberCauseway/OakDrawbridgePlank_14") as MeshInstance3D
	assert(receiving_court != null and final_bridge_plank != null,
		"bridge and front court have a dedicated joined endpoint")
	var receiving_bounds := receiving_court.global_transform * receiving_court.mesh.get_aabb()
	var final_plank_bounds := final_bridge_plank.global_transform * final_bridge_plank.mesh.get_aabb()
	assert(absf(receiving_bounds.end.y - final_plank_bounds.position.y) <= 0.02,
		"front court top meets the timber bridge underside without a vertical gap")
	var fire := entrance.get_node_or_null("MedievalCourtyardFire") as Node3D
	var fire_core := fire.get_node_or_null("CourtyardFireCore") as MeshInstance3D \
		if fire != null else null
	var fire_light := fire.get_node_or_null("CourtyardFireLight") as OmniLight3D \
		if fire != null else null
	assert(fire_core != null and fire_core.visible and fire_light != null and fire_light.visible,
		"central front-castle ball is a visible warm fire beacon")
	for fire_mesh_candidate in fire.find_children("*", "MeshInstance3D", true, false):
		assert(not (fire_mesh_candidate as MeshInstance3D).mesh is TorusMesh,
			"the fire beacon has no orbit rings or wide fountain platform")
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
		assert(tread_inner_radius >= inner_guard_face + 0.04,
			"%s stays clear of the inner barrier" % tread.name)
		assert(tread_outer_corner_radius <= outer_guard_face - 0.02,
			"%s does not pass through the outer barrier" % tread.name)
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
	var stair_growth := stair.get_node_or_null("LowPolyStairGrowth") as Node3D
	assert(stair_growth != null, "low-poly tree growth is installed on the stair")
	assert(stair_growth.find_children("StairTreeFiber_*", "MeshInstance3D",
		true, false).size() == 88,
		"two continuous woody fibres grow along the castle stair")
	assert(stair_growth.find_children("StairTreeLeaf_*", "MeshInstance3D",
		true, false).size() >= 16,
		"low-poly leaves surround the stair fibres")
	assert(stair_growth.find_children("*", "StaticBody3D", true, false).is_empty(),
		"stair tree growth remains visual-only outside the walking lane")
	var sample_fibre := stair_growth.get_node("StairTreeFiber_0_00") as MeshInstance3D
	var sample_leaf := stair_growth.get_node("StairTreeLeaf_0_02") as MeshInstance3D
	var fibre_colour := (sample_fibre.material_override as StandardMaterial3D).albedo_color
	var leaf_colour := (sample_leaf.material_override as StandardMaterial3D).albedo_color
	assert(fibre_colour.r > fibre_colour.g and leaf_colour.g > leaf_colour.r,
		"palette pass preserves brown bark and green low-poly leaves")
	for duplicate_visual in stair.find_children("LumenBridgeSurfacePlank_*",
			"MeshInstance3D", true, false) \
			+ stair.find_children("AetherTensionCollar_*", "MeshInstance3D", true, false) \
			+ stair.find_children("AetherBridgeKeel", "MeshInstance3D", true, false):
		assert(not (duplicate_visual as MeshInstance3D).visible,
			"duplicate bridge visual %s is hidden" % duplicate_visual.name)
	var roadbed := stair.get_node_or_null("LumenBridgeRoadbed") as MeshInstance3D
	assert(roadbed != null and roadbed.visible, "one authoritative bridge roadbed remains")
	var roadbed_bounds := roadbed.global_transform * roadbed.mesh.get_aabb()
	for crossbeam_candidate in architecture.find_children("DrawbridgeCrossbeam_*",
			"MeshInstance3D", true, false):
		var crossbeam := crossbeam_candidate as MeshInstance3D
		var crossbeam_bounds := crossbeam.global_transform * crossbeam.mesh.get_aabb()
		assert(not roadbed_bounds.intersects(crossbeam_bounds),
			"%s stays below the roadbed without clipping" % crossbeam.name)
	for stringer_candidate in architecture.find_children("OakSideStringer*",
			"MeshInstance3D", true, false):
		var stringer := stringer_candidate as MeshInstance3D
		var stringer_bounds := stringer.global_transform * stringer.mesh.get_aabb()
		assert(not roadbed_bounds.intersects(stringer_bounds),
			"%s stays below the roadbed without clipping" % stringer.name)

	print("MEDIEVAL_CASTLE_REDESIGN_TEST: PASS — original blue/red palette, detailed castle-only architecture, and full door ascent installed")
	hub.queue_free()
	quit()


func _init() -> void:
	call_deferred("_run")
