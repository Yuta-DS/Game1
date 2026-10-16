# Regression coverage for the professional Art Castle construction pass.
extends SceneTree


func _fail(message: String) -> void:
	push_error("CASTLE_POLISH_TEST: %s" % message)
	quit(1)


func _world_aabb(piece: MeshInstance3D) -> AABB:
	var local := piece.mesh.get_aabb()
	var first := piece.global_transform * local.position
	var minimum := first
	var maximum := first
	for x_index in 2:
		for y_index in 2:
			for z_index in 2:
				var corner := local.position + Vector3(
					local.size.x * float(x_index),
					local.size.y * float(y_index),
					local.size.z * float(z_index))
				var world_corner := piece.global_transform * corner
				minimum = minimum.min(world_corner)
				maximum = maximum.max(world_corner)
	return AABB(minimum, maximum - minimum)


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 50:
		await process_frame

	var stair := hub.get_node_or_null("CastleStairs/CastleStair") as Node3D
	if stair == null:
		_fail("castle stair did not build")
		return
	for required in ["AscentRoadbed", "AscentWalkSurface", "OuterContinuousGuard",
			"InnerContinuousGuard", "InnerSafetyPlinth"]:
		var part := stair.get_node_or_null(required) as MeshInstance3D
		if part == null or part.mesh == null:
			_fail("missing continuous stair part %s" % required)
			return
	var audited_soffit := stair.get_node("AscentRoadbed") as MeshInstance3D
	var integrated_newel := stair.get_node("InnerSafetyPlinth") as MeshInstance3D
	if float(audited_soffit.get_meta("outer_masonry_overlap", 0.0)) < 0.20 \
			or not bool(audited_soffit.get_meta("radial_faces_buried_and_omitted", false)) \
			or not bool(integrated_newel.get_meta("integrated_stone_newel_mass", false)) \
			or float(integrated_newel.get_meta("soffit_overlap", 0.0)) < 0.15:
		_fail("spiral soffit radial faces are not buried into both masonry sides")
		return
	var walk_surface := stair.get_node_or_null("AscentWalkSurface") as MeshInstance3D
	if walk_surface.find_children("*", "StaticBody3D", true, false).is_empty():
		_fail("continuous spiral walk surface is missing collision")
		return
	var grounded_entry := stair.get_node_or_null("GroundedCastleEntry") as Node3D
	if grounded_entry == null or not bool(grounded_entry.get_meta(
			"walkable_from_terrain", false)):
		_fail("castle stair is missing its terrain-grounded castle entry")
		return
	var ground_walk_surface := grounded_entry.get_node_or_null(
		"GroundEntryWalkSurface") as MeshInstance3D
	var ground_walk_collision := grounded_entry.get_node_or_null(
		"GroundEntryWalkCollision") as MeshInstance3D
	if ground_walk_surface == null or not ground_walk_surface.visible \
			or not bool(ground_walk_surface.get_meta("smooth_straight_route", false)) \
			or ground_walk_collision == null or ground_walk_collision.visible \
			or not bool(ground_walk_collision.get_meta(
				"authoritative_collision_surface", false)) \
			or ground_walk_collision.find_children(
				"*", "StaticBody3D", true, false).size() != 1 \
			or not ground_walk_surface.material_override is ShaderMaterial \
			or not ground_walk_surface.get_meta("floor_edges_seated_in_masonry", false):
		_fail("ground entry is missing its visible paved route or seamless hidden collision")
		return
	var inner_plinth := stair.get_node_or_null("InnerSafetyPlinth") as MeshInstance3D
	var inner_plinth_bodies := inner_plinth.find_children("*", "StaticBody3D", true, false) \
		if inner_plinth != null else []
	if inner_plinth == null or inner_plinth_bodies.size() != 1:
		_fail("inner stair safety plinth is missing collision")
		return
	# Probe the former slot between the 3.0 m tower collider and the inner guard
	# throughout the climb. Every ray must now meet the raised plinth; an empty
	# result means a player capsule can once again jump behind the rail and wedge.
	var ascent_space := (stair.get_world_3d() as World3D).direct_space_state
	var ascent_base: Vector2 = stair.get_meta("tower_base")
	var ascent_ground: float = stair.get_meta("terrain_ground_y")
	var ascent_top: float = stair.get_meta("tower_top_y")
	var slot_capsule := CapsuleShape3D.new()
	slot_capsule.radius = 0.5
	slot_capsule.height = 2.0
	for slot_probe_index in 12:
		var slot_t := 0.985 * (float(slot_probe_index) + 0.5) / 12.0
		var slot_angle := slot_t * TAU * 2.35
		var slot_surface_y := lerpf(ascent_ground + 0.17, ascent_top, slot_t)
		var slot_point := Vector3(
			ascent_base.x + cos(slot_angle) * 3.6,
			slot_surface_y,
			ascent_base.y + sin(slot_angle) * 3.6)
		var slot_query := PhysicsShapeQueryParameters3D.new()
		slot_query.shape = slot_capsule
		slot_query.transform = Transform3D(Basis.IDENTITY,
			slot_point + Vector3.UP)
		slot_query.collide_with_areas = false
		var slot_hits := ascent_space.intersect_shape(slot_query, 16)
		var slot_blocked := slot_hits.any(func(hit):
			return inner_plinth_bodies.has(hit.get("collider")))
		if not slot_blocked:
			_fail("inner stair has a player-trapping service slot at climb t=%.3f"
				% slot_t)
			return
	if not stair.find_children("OuterSafetyWall_*", "MeshInstance3D", true, false).is_empty():
		_fail("legacy box-per-step railing is still present")
		return
	var safety_fields := stair.find_children("CausewaySafetyWall*", "MeshInstance3D", true, false)
	# The aether safety posts are freed by the castle redesign (visual only,
	# no collision); the safety walls carry the edge protection.
	if safety_fields.size() != 6:
		_fail("causeway does not have two core safety walls and four flared mouth wings")
		return
	var core_safety_fields := 0
	var mouth_safety_wings := 0
	for field_candidate in safety_fields:
		var field := field_candidate as MeshInstance3D
		if not (field.mesh is BoxMesh):
			_fail("causeway safety field is not measurable box geometry")
			return
		var field_size := (field.mesh as BoxMesh).size
		if field_size.y < 1.3:
			_fail("causeway safety field is too low: %s" % field_size)
			return
		if field.name.ends_with("_Core"):
			core_safety_fields += 1
			var field_inner_face := absf(field.global_position.z - 27.41) \
				- field_size.x * 0.5
			if field_size.z < 5.5 or field_inner_face < 2.4:
				_fail("causeway core safety field is too short or intrudes into the road: size %s inner face %.2f"
					% [field_size, field_inner_face])
				return
		elif field.name.contains("Wing"):
			mouth_safety_wings += 1
			if field_size.z < 1.2:
				_fail("causeway mouth safety wing is too short to form a funnel")
				return
		if field.find_children("*", "StaticBody3D", true, false).is_empty():
			_fail("causeway safety field has no fall-prevention collision")
			return
		var field_material := field.material_override as StandardMaterial3D
		if field_material == null \
				or field_material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA \
				or field_material.albedo_color.a > 0.22:
			_fail("causeway safety field is not a transparent aether barrier")
			return
	if core_safety_fields != 2 or mouth_safety_wings != 4:
		_fail("causeway safety field naming/inventory does not describe two flared mouths")
		return
	# The castle redesign removes the Aether Lens Bridge's technology dressing
	# (castle_redesign.gd frees it: it was visual-only, with no collision), so
	# none of it may be left over the walkway.
	var aether_leftovers: Array = []
	for pattern in ["LumenRuneSeal_*", "LumenArchPylon_*", "LumenArchKeystone_*",
			"*AetherLensGate", "AetherLensPylon_*", "AetherLensYoke_*",
			"AetherLensApex_*", "MidspanResonanceFrame", "LumenArchYoke_*",
			"AetherRuneGlassBay_*", "AetherGlassTracery_*", "AetherRuneFascia_*",
			"AetherFasciaRune_*", "AetherGear_*", "AetherAstrolabeRing_*",
			"LumenCenterConductor_*", "AetherTensionRib_*", "AetherUnderbrace_*",
			"AetherLevitationCoil_*", "AetherBridgeKeel"]:
		aether_leftovers += stair.find_children(pattern, "Node3D", true, false)
	if not aether_leftovers.is_empty():
		_fail("Aether Lens Bridge dressing survived the castle redesign: %s"
			% ", ".join(aether_leftovers.map(func(n): return String(n.name)).slice(0, 6)))
		return

	var roadbed := stair.get_node_or_null("LumenBridgeRoadbed") as MeshInstance3D
	var launch := stair.get_node_or_null("LumenBridgeLaunch") as MeshInstance3D
	var bridge_landing := stair.get_node_or_null("CastleDoorLanding") as MeshInstance3D
	if roadbed == null or launch == null or bridge_landing == null \
			or not roadbed.global_position.is_equal_approx(Vector3(-13.1, 67.73, 27.41)) \
			or not launch.global_position.is_equal_approx(Vector3(-10.2, 67.73, 27.41)) \
			or not bridge_landing.global_position.is_equal_approx(Vector3(-17.9, 67.73, 27.41)):
		_fail("reference redesign moved a gameplay bridge transform")
		return

	# Budget the actual meshes occupying the bridge volume rather than trusting
	# a hand-maintained list. This includes anonymous deck strips and lamps.
	var bridge_mesh_count := 0
	for mesh_candidate in stair.find_children("*", "MeshInstance3D", true, false):
		var bridge_piece := mesh_candidate as MeshInstance3D
		var p := bridge_piece.global_position
		if p.x >= -19.2 and p.x <= -7.8 and absf(p.z - 27.41) <= 4.4 \
				and p.y >= 63.0 and p.y <= 75.0:
			bridge_mesh_count += 1
	if bridge_mesh_count > 190:
		_fail("reference bridge exceeds 190-mesh budget: %d" % bridge_mesh_count)
		return
	var bridge_light_count := 0
	for light_candidate in stair.find_children("*", "OmniLight3D", true, false):
		var bridge_light := light_candidate as OmniLight3D
		var lp := bridge_light.global_position
		if lp.x >= -19.2 and lp.x <= -7.8 and absf(lp.z - 27.41) <= 4.4:
			bridge_light_count += 1
	if bridge_light_count > 3:
		_fail("reference bridge exceeds three-light budget: %d" % bridge_light_count)
		return
	if not stair.find_children("*Lintel*", "MeshInstance3D", true, false).is_empty() \
			or not stair.find_children("LumenRunePlate_*", "MeshInstance3D", true, false).is_empty():
		_fail("legacy bridge lintel or oversized rune plate survived the redesign")
		return
	# Detect a future unnamed replacement for the old camera-blocking lintel:
	# no wide box may cross a gateway between 3.0 and 5.0 m above the deck.
	for candidate in stair.find_children("*", "MeshInstance3D", true, false):
		var piece := candidate as MeshInstance3D
		if piece.mesh is BoxMesh:
			var size := (piece.mesh as BoxMesh).size
			var over_deck := piece.global_position.y - 67.73
			if over_deck > 3.0 and over_deck < 5.0 and maxf(size.x, size.z) > 5.5:
				_fail("wide transverse box %s blocks the gateway camera at %.2f m" % [piece.name, over_deck])
				return

	var foundation := hub.get_node_or_null("CastleFoundation") as Node3D
	var tree_foundation := foundation.get_node_or_null("GiantTreeFoundation") as Node3D \
		if foundation != null else null
	if tree_foundation == null \
			or foundation.get_meta("foundation_style", "") != "giant_living_tree" \
			or not bool(foundation.get_meta("floating_undercarriage_removed", false)):
		_fail("castle has no grounded giant-tree foundation")
		return
	if tree_foundation.get_node_or_null("TreeTrunkCore") == null \
			or tree_foundation.find_children(
				"CastleCradleRoot_*", "MeshInstance3D", true, false).size() != 6 \
			or tree_foundation.find_children(
				"GroundButtressRoot_*", "MeshInstance3D", true, false).size() != 10:
		_fail("giant-tree trunk, castle cradle roots, or ground roots are incomplete")
		return
	var gallery_zone := tree_foundation.get_node_or_null("GalleryRootSupportZone") as Node3D
	var crystal_zone := tree_foundation.get_node_or_null("CrystalRootSupportZone") as Node3D
	if gallery_zone == null or crystal_zone == null \
			or gallery_zone.find_children(
				"GallerySupportRoot_*", "MeshInstance3D", true, false).size() != 2 \
			or crystal_zone.find_children(
				"CrystalSupportRoot_*", "MeshInstance3D", true, false).size() != 2 \
			or gallery_zone.get_node_or_null("GalleryGroundSupportTrunk") == null \
			or crystal_zone.get_node_or_null("CrystalGroundSupportTrunk") == null \
			or gallery_zone.get_node_or_null("GalleryUndersideCradleSweepRoot") == null \
			or crystal_zone.get_node_or_null("CrystalUndersideCradleSweepRoot") == null \
			or not bool(gallery_zone.get_meta("ground_to_architecture", false)) \
			or not bool(crystal_zone.get_meta("ground_to_architecture", false)) \
			or gallery_zone.get_meta("supported_area", "") != "gallery_foundation_plaza" \
			or crystal_zone.get_meta("supported_area", "") != "castle_upper_court":
		_fail("gallery and crystal architecture do not have independent living-root cradles")
		return
	var gallery_trunk := gallery_zone.get_node("GalleryGroundSupportTrunk") as MeshInstance3D
	var crystal_trunk := crystal_zone.get_node("CrystalGroundSupportTrunk") as MeshInstance3D
	var gallery_trunk_bounds := gallery_trunk.mesh.get_aabb()
	var crystal_trunk_bounds := crystal_trunk.mesh.get_aabb()
	if gallery_trunk_bounds.position.y > -48.0 \
			or gallery_trunk_bounds.end.y < 0.0 \
			or crystal_trunk_bounds.position.y > -48.0 \
			or crystal_trunk_bounds.end.y < -6.0:
		_fail("two front support trunks do not form continuous ground-to-castle load paths")
		return
	var front_wall_supports := tree_foundation.get_node_or_null(
		"FrontWallCenterSupports") as Node3D
	var gallery_front_root := front_wall_supports.get_node_or_null(
		"GalleryEntranceFrontCenterRoot") as MeshInstance3D if front_wall_supports != null else null
	var crystal_front_root := front_wall_supports.get_node_or_null(
		"CrystalWindowFrontCenterRoot") as MeshInstance3D if front_wall_supports != null else null
	if front_wall_supports == null or gallery_front_root == null or crystal_front_root == null \
			or not bool(front_wall_supports.get_meta("separate_from_central_foundation", false)) \
			or int(tree_foundation.get_meta("front_wall_center_supports", 0)) != 2 \
			or gallery_front_root.get_meta("target_name", "") \
				!= "art_explore_gallery_entrance_wall" \
			or crystal_front_root.get_meta("target_name", "") \
				!= "outer_crystal_window_wall" \
			or not (gallery_front_root.get_meta("target_center", Vector3.ZERO) as Vector3) \
				.is_equal_approx(Vector3(11.6, 4.15, 0.0)) \
			or not (crystal_front_root.get_meta("target_center", Vector3.ZERO) as Vector3) \
				.is_equal_approx(Vector3(29.5, -5.35, 0.0)):
		_fail("two additional roots are not centred under the confirmed front walls")
		return
	for front_root in [gallery_front_root, crystal_front_root]:
		var front_bounds := (front_root as MeshInstance3D).mesh.get_aabb()
		var required_contact_y := 4.0 if front_root == gallery_front_root else -5.6
		if front_bounds.position.y > -48.0 or front_bounds.end.y < required_contact_y:
			_fail("front wall root %s does not rise continuously from terrain" % front_root.name)
			return
	var tree_fibres := tree_foundation.find_children(
		"TreeFiber_*", "MeshInstance3D", true, false)
	var tree_leaves := tree_foundation.find_children(
		"TreeLeaf_*", "MeshInstance3D", true, false)
	if tree_fibres.size() < 40 or tree_leaves.size() < 120 \
			or int(tree_foundation.get_meta("architecture_support_zones", 0)) != 2:
		_fail("living-root fibres, vines, leaves, or two-area support metadata are incomplete")
		return
	for root_mesh in tree_foundation.find_children(
			"*Root_*", "MeshInstance3D", true, false):
		if not ((root_mesh as MeshInstance3D).mesh is ArrayMesh):
			_fail("living root %s is not a continuous curved mesh" % root_mesh.name)
			return
	if foundation.get_node_or_null("CitadelRockShelf") != null \
			or foundation.get_node_or_null("CitadelRockKeel") != null \
			or not foundation.find_children(
				"FloatingFoundationAnchor_*", "Node3D", true, false).is_empty() \
			or hub.get_node_or_null("building_castle_red2/LumenEngineRig") != null:
		_fail("old floating rock, anchors, or mechanical undercarriage remain beneath castle")
		return

	var castle := hub.get_node_or_null("building_castle_red2") as Node3D
	var castle_position := castle.position
	for _frame in 40:
		await process_frame
	if not castle.position.is_equal_approx(castle_position):
		_fail("walkable castle architecture still moves under the player")
		return

	# The crown landing must be a broad, collision-backed room, not a thin
	# ring around the shaft — the last tread used to hand the player onto a
	# deck barely wider than the stair itself, which read as a beam crossing.
	#
	# The deck is a hand-built ArrayMesh (a full disc with a stairwell wedge
	# cut out), not a plain CylinderMesh, so its footprint is read from the
	# mesh AABB rather than from CylinderMesh-specific properties. That AABB
	# is authored in the deck's own local space (see hub_castle_stairs.gd),
	# so global_position is still the disc centre.
	var crown_deck := stair.get_node_or_null("CrownDeck") as MeshInstance3D
	if crown_deck == null or crown_deck.mesh == null:
		_fail("spiral crown landing is missing")
		return
	var deck_aabb := crown_deck.mesh.get_aabb()
	var crown_radius: float = maxf(deck_aabb.size.x, deck_aabb.size.z) * 0.5
	if crown_radius < 8.0 or crown_radius > 8.8:
		_fail("spiral crown landing is outside the professional 8.0–8.8 m envelope: radius %s" % crown_radius)
		return
	var crown_deck_bodies := crown_deck.find_children("*", "StaticBody3D", true, false)
	if crown_deck_bodies.is_empty():
		_fail("spiral crown landing has no collision")
		return
	var roof_finish := stair.get_node_or_null("CrownMasonryFinish") as Node3D
	if roof_finish == null \
			or not bool(roof_finish.get_meta("clean_uninterrupted_roof_surface", false)) \
			or not bool(roof_finish.get_meta("concentric_and_radial_lines_removed", false)) \
			or not roof_finish.get_children().is_empty() \
			or not stair.find_children("CrownPavingCourse_*", "MeshInstance3D", true, false).is_empty() \
			or not stair.find_children("CrownRadialMasonryJoint_*", "MeshInstance3D", true, false).is_empty() \
			or stair.get_node_or_null("CrownStoneCompass") != null \
			or not stair.find_children("CrownCompassJoint_*", "MeshInstance3D", true, false).is_empty():
		_fail("crown roof still contains the reported white or black line work")
		return
	if stair.get_node_or_null("CrownStoneMedallion") != null:
		_fail("raised centre medallion still creates an unwanted rooftop outline")
		return
	var centre_finish := stair.get_node_or_null("CrownDeckCentreStoneFinish") \
		as MeshInstance3D
	if centre_finish == null or not (centre_finish.mesh is CylinderMesh) \
			or not bool(centre_finish.get_meta("covers_exposed_tower_cap", false)) \
			or not centre_finish.find_children(
				"*", "StaticBody3D", true, false).is_empty():
		_fail("crown centre still exposes the dark tower cap or adds duplicate collision")
		return
	var blender_parapets := stair.find_children(
		"BlenderCrownParapetPanel_*", "Node3D", true, false)
	if blender_parapets.size() < 3:
		_fail("Blender-authored rooftop parapet modules are missing")
		return
	for panel_candidate in blender_parapets:
		var panel := panel_candidate as Node3D
		if panel.find_children("*", "MeshInstance3D", true, false).size() < 3 \
				or not panel.find_children(
					"*", "StaticBody3D", true, false).is_empty() \
				or String(panel.get_meta("collision_policy", "")) \
					!= "visual_only_over_procedural_godot_wall":
			_fail("Blender parapet lost detail or introduced snag-prone collision")
			return
	var stair_arrival_wings: Array[Node] = []
	for wing_candidate in stair.find_children(
			"CrownStairArrivalWing_*", "Node3D", true, false):
		if (wing_candidate as Node).has_meta("source_blend"):
			stair_arrival_wings.append(wing_candidate)
	var stair_arrival_guard := stair.get_node_or_null(
		"CrownStairArrivalGuard_Outer") as MeshInstance3D
	if stair_arrival_wings.size() != 2 or stair_arrival_guard == null \
			or stair_arrival_guard.find_children(
				"*", "StaticBody3D", true, false).is_empty() \
			or not bool(stair_arrival_guard.get_meta(
				"continuous_from_stair_to_rooftop", false)):
		_fail("rooftop perimeter does not narrow safely into the stair arrival")
		return
	var stairwell_return := stair.get_node_or_null(
		"CrownStairwellInnerReturn") as MeshInstance3D
	var stairwell_return_coping := stair.get_node_or_null(
		"CrownStairwellInnerReturnCoping") as MeshInstance3D
	if stairwell_return == null \
			or stairwell_return_coping == null \
			or stairwell_return.find_children("*", "StaticBody3D", true, false).is_empty() \
			or not bool(stairwell_return.get_meta("continuous_stairwell_barrier", false)) \
			or stairwell_return.get_meta("design_language", "") \
				!= "restrained_medieval_castle_masonry" \
			or not bool(stairwell_return_coping.get_meta("castle_stone_coping", false)) \
			or stair.find_children("CrownStairwellReturnBrick_*", "MeshInstance3D", true, false).size() < 32:
		_fail("rooftop stairwell is not fully framed in matching castle masonry")
		return
	var parapet_joint_piers := stair.find_children(
		"CrownParapetJointPier_*", "MeshInstance3D", true, false)
	if parapet_joint_piers.size() < 4:
		_fail("rooftop perimeter still has open dark joints between parapet panels")
		return
	for pier_candidate in parapet_joint_piers:
		var pier := pier_candidate as MeshInstance3D
		if not bool(pier.get_meta("closes_parapet_panel_joint", false)) \
				or pier.find_children("*", "StaticBody3D", true, false).is_empty():
			_fail("rooftop parapet joint pier is decorative but not solid")
			return
	var deck_body := crown_deck_bodies[0] as StaticBody3D
	if deck_body == null:
		_fail("spiral crown landing collision is not a StaticBody3D")
		return
	var gateway_apron := stair.get_node_or_null("CrownGatewayApron") as MeshInstance3D
	if gateway_apron == null or not (gateway_apron.mesh is BoxMesh):
		_fail("crown gateway has no stable box-shaped floor apron")
		return
	var gateway_apron_bodies := gateway_apron.find_children(
		"*", "StaticBody3D", true, false)
	if gateway_apron_bodies.is_empty():
		_fail("crown gateway floor apron has no collision")
		return
	var gateway_apron_body := gateway_apron_bodies[0] as StaticBody3D
	if gateway_apron_body == null:
		_fail("crown gateway apron collision is not a StaticBody3D")
		return
	var stair_handoff := stair.get_node_or_null("CrownStairHandoff") as MeshInstance3D
	if stair_handoff == null or not (stair_handoff.mesh is BoxMesh) \
			or stair_handoff.find_children("*", "StaticBody3D", true, false).is_empty():
		_fail("crown stair mouth has no stable box-shaped handoff floor")
		return
	var fitted_handoff := stair.get_node_or_null(
		"CastleCrownStairLanding") as MeshInstance3D
	if stair_handoff.visible or not bool(stair_handoff.get_meta("collision_only", false)) \
			or fitted_handoff == null or not (fitted_handoff.mesh is ArrayMesh) \
			or not fitted_handoff.find_children(
				"*", "StaticBody3D", true, false).is_empty():
		_fail("spiral crown still renders the oversized box instead of the fitted landing")
		return
	var fountain := stair.get_node_or_null("CastleRoyalFountain") as Node3D
	if fountain == null or not bool(fountain.get_meta("solid_stone_animated_water", false)) \
			or fountain.find_children("BasinCascade_*", "MeshInstance3D", true, false).size() != 4 \
			or fountain.find_children("*", "StaticBody3D", true, false).size() != 1 \
			or stair.get_node_or_null("CastleBallista") != null:
		_fail("royal fountain has not safely replaced the rooftop ballista")
		return
	var arrival_court := stair.get_node_or_null("CrownArrivalCourt") as Node3D
	var arrival_pylons := stair.find_children(
		"CrownArrivalPylon_*", "MeshInstance3D", true, false)
	var arrival_caps := stair.find_children(
		"CrownArrivalCap_*", "MeshInstance3D", true, false)
	var arrival_roofs := stair.find_children(
		"CrownArrivalRoof_*", "MeshInstance3D", true, false)
	var arrival_ashlar := stair.find_children(
		"CrownArrivalAshlarCourse_*", "MeshInstance3D", true, false)
	if arrival_court == null \
			or arrival_court.get_meta("design_language", "") \
				!= "restrained_medieval_castle_masonry" \
			or arrival_pylons.size() != 2 or arrival_caps.size() != 2 \
			or arrival_roofs.size() != 2 or arrival_ashlar.size() != 2:
		_fail("medieval crown arrival gate is incomplete")
		return
	if not arrival_court.find_children("*", "StaticBody3D", true, false).is_empty():
		_fail("crown arrival dressing added collision back into the player lane")
		return
	if not stair.find_children("CrownArrivalYoke_*", "MeshInstance3D", true, false).is_empty() \
			or not stair.find_children("CrownArrivalGuide_*", "MeshInstance3D", true, false).is_empty() \
			or stair.get_node_or_null("CrownArrivalLens") != null:
		_fail("mixed glowing arrival machinery remains on the medieval crown")
		return
	var crown_vaulting := stair.get_node_or_null("CrownUndersideVaulting") as Node3D
	if crown_vaulting == null \
			or not bool(crown_vaulting.get_meta("finished_beneath_surface", false)) \
			or not bool(crown_vaulting.get_meta("uninterrupted_stone_soffit", false)) \
			or not crown_vaulting.find_children("CrownUndersideCorbel_*", "MeshInstance3D", true, false).is_empty() \
			or not crown_vaulting.find_children("CrownUndersideVaultRib_*", "MeshInstance3D", true, false).is_empty() \
			or crown_vaulting.get_node_or_null("CrownUndersideRingBeam") != null \
			or not crown_vaulting.find_children("*", "StaticBody3D", true, false).is_empty():
		_fail("crown beneath-surface vaulting is incomplete or obstructive")
		return
	var final_tread: MeshInstance3D = null
	for candidate in stair.find_children("StairTread_*", "MeshInstance3D", true, false):
		var tread := candidate as MeshInstance3D
		if final_tread == null or tread.global_position.y > final_tread.global_position.y:
			final_tread = tread
	if final_tread == null or not (final_tread.mesh is BoxMesh):
		_fail("final spiral tread is missing, so the crown handoff cannot be verified")
		return
	var crown_surface := crown_deck.global_position.y + deck_aabb.position.y + deck_aabb.size.y
	var tread_surface := final_tread.global_position.y \
		+ (final_tread.mesh as BoxMesh).size.y * 0.5
	if absf(crown_surface - tread_surface) > 0.05:
		_fail("spiral crown is not flush with the final tread: %.3f vs %.3f"
			% [crown_surface, tread_surface])
		return

	# The hand-built crown mesh must also floor its centre. A previous version
	# only emitted the outer ring despite claiming to add a centre disc. That
	# left a 0.6 m annular slot between the 3.0 m shaft collision and the ring's
	# 3.6 m inner edge—just wide enough for the player capsule to drop into and
	# become wedged at the exact location shown in the overhead bug capture.
	var space_state: PhysicsDirectSpaceState3D = (stair.get_world_3d() as World3D).direct_space_state
	var handoff_body := stair.get_node("CrownStairHandoff").find_children(
		"*", "StaticBody3D", true, false).front() as StaticBody3D
	const TRAP_RING_RADIUS := 3.3
	for probe_index in 16:
		var probe_angle := TAU * float(probe_index) / 16.0
		var probe_xz := Vector3(cos(probe_angle) * TRAP_RING_RADIUS, 0.0,
			sin(probe_angle) * TRAP_RING_RADIUS)
		var floor_query := PhysicsRayQueryParameters3D.create(
			Vector3(crown_deck.global_position.x, crown_surface + 1.0,
				crown_deck.global_position.z) + probe_xz,
			Vector3(crown_deck.global_position.x, crown_surface - 1.0,
				crown_deck.global_position.z) + probe_xz)
		floor_query.collide_with_areas = false
		# The requested solid fountain now occupies part of this old empty-floor
		# probe ring. Still verify the roof underneath it; fountain support and
		# player escape are covered by test_castle_royal_fountain.gd.
		floor_query.exclude = [(fountain.get_node("SolidFountainStone") as StaticBody3D).get_rid()]
		var floor_hit := space_state.intersect_ray(floor_query)
		if not floor_hit.has("collider") or (floor_hit["collider"] != deck_body \
				and floor_hit["collider"] != gateway_apron_body \
				and floor_hit["collider"] != handoff_body) \
				or (floor_hit.has("position") \
				and absf((floor_hit["position"] as Vector3).y - crown_surface) > 0.03):
			_fail("crown centre has a player-trapping floor gap at radius %.1f angle %.2f (hit %s)"
				% [TRAP_RING_RADIUS, probe_angle,
					floor_hit.get("collider", "nothing")])
			return

	# The deck must have an actual open stairwell above the final approach,
	# not just an omitted parapet — a full disc used to sit as a low ceiling
	# barely 0.5 m over the last treads (the "blocked stair / low overhead
	# collision" defect). Sample the treads closest to the crown and confirm
	# no CrownDeck triangle overlaps their headspace within a safe clearance.
	# The packed player capsule is 2.0 m tall. The crown opening deliberately
	# keeps another 0.8 m above it and clears the capsule's full width, not only
	# a zero-width ray through the stair centre.
	const MIN_HEAD_CLEARANCE := 2.8
	var near_crown_treads := stair.find_children("StairTread_*", "MeshInstance3D", true, false) \
		.filter(func(t): return (t as MeshInstance3D).global_position.y > tread_surface - 3.0)
	for candidate in near_crown_treads:
		var tread := candidate as MeshInstance3D
		var radial := Vector3(tread.global_position.x - crown_deck.global_position.x,
			0.0, tread.global_position.z - crown_deck.global_position.z).normalized()
		for radial_offset: float in [-0.55, 0.0, 0.55]:
			var probe_from: Vector3 = tread.global_position + radial * radial_offset + Vector3.UP * 0.2
			var probe_to: Vector3 = probe_from + Vector3.UP * MIN_HEAD_CLEARANCE
			var query := PhysicsRayQueryParameters3D.create(probe_from, probe_to)
			query.collide_with_areas = false
			var hit: Dictionary = space_state.intersect_ray(query)
			if hit.has("collider") and hit["collider"] == deck_body:
				_fail("crown deck blocks player-width headroom above a spiral tread at %s (needs %.1f m clear)"
					% [tread.global_position, MIN_HEAD_CLEARANCE])
				return

	# Close the oversized pie-slice gap beside the usable stair lane. At the
	# final tread angle the centre must remain open, while the inner and outer
	# shelves must both be real CrownDeck floor.
	var shelf_probe_tread := final_tread
	var shelf_probe_target_y := tread_surface - MIN_HEAD_CLEARANCE * 0.5
	for candidate in near_crown_treads:
		var tread := candidate as MeshInstance3D
		if absf(tread.global_position.y - shelf_probe_target_y) \
				< absf(shelf_probe_tread.global_position.y - shelf_probe_target_y):
			shelf_probe_tread = tread
	var final_radial := Vector3(
		shelf_probe_tread.global_position.x - crown_deck.global_position.x,
		0.0, shelf_probe_tread.global_position.z - crown_deck.global_position.z).normalized()
	# Probe beyond the full player-width stairwell lane. The opening is 3.0 m
	# wide so a 1.0 m capsule can leave either side of the spiral without its
	# shoulder catching the crown floor shelf.
	for shelf_radius: float in [4.7, 8.3]:
		var shelf_point: Vector3 = crown_deck.global_position + final_radial * shelf_radius
		shelf_point.y = crown_surface
		var shelf_query := PhysicsRayQueryParameters3D.create(
			shelf_point + Vector3.UP * 0.35, shelf_point - Vector3.UP * 0.2)
		shelf_query.collide_with_areas = false
		var shelf_hit := space_state.intersect_ray(shelf_query)
		if not shelf_hit.has("collider") or shelf_hit["collider"] != deck_body:
			var blocker := "nothing"
			if shelf_hit.has("collider"):
				blocker = str((shelf_hit["collider"] as Node).get_parent().name)
			_fail("crown stairwell still has an oversized side gap at radius %.1f (hit %s)"
				% [shelf_radius, blocker])
			return

	# The causeway/terrace handoff must expose a clear route: the continuous
	# guard rails have to stop short of the terrace end (an open gate) rather
	# than running the full span into the terrace's own balustrade, and the
	# end-cap landing must not be a full disc obstructing the walking axis.
	var causeway_landing := stair.get_node_or_null("CastleDoorLanding") as MeshInstance3D
	if causeway_landing == null or causeway_landing.mesh is CylinderMesh:
		_fail("causeway end-cap is missing or is still a round full-disc obstruction")
		return

	# The medieval redesign removes the old glowing bridge machinery.
	for pattern in ["LumenArch*", "LumenRuneSeal_*", "AetherLens*"]:
		if not stair.find_children(pattern, "MeshInstance3D", true, false).is_empty():
			_fail("obsolete Lumen Bridge machinery remains: %s" % pattern)
			return

	# Datum cross-check: the entrance's upper court and the stair's terrace
	# must agree on one shared arrival level. Both scripts expose these as
	# script constants so a future edit to one without the other fails loudly
	# instead of silently reintroducing the mismatched-height bug.
	var entrance_root := hub.get_node_or_null("CastleEntrance") as Node3D
	var stair_root := hub.get_node_or_null("CastleStairs") as Node3D
	if entrance_root == null or stair_root == null:
		_fail("castle entrance or stair root did not build")
		return
	var entrance_terrace_y: float = entrance_root.get("TERRACE_DECK_Y")
	var stair_terrace_y: float = stair_root.get("TERRACE_DECK_Y")
	if not is_equal_approx(entrance_terrace_y, stair_terrace_y):
		_fail("entrance and stair disagree on the shared terrace datum: %s vs %s"
			% [entrance_terrace_y, stair_terrace_y])
		return

	# The stair tower, bridge, entrance and castle share one Z axis. The former
	# -14 m tower offset forced a diagonal approach that never visually met the
	# front architecture.
	var tower_base: Vector2 = stair.get_meta("tower_base")
	var entrance_axis: Vector3 = entrance_root.get("CASTLE_DOOR")
	if absf(tower_base.y - entrance_axis.z) > 0.05:
		_fail("stair tower is not aligned with the castle entrance axis: %s vs %s"
			% [tower_base.y, entrance_axis.z])
		return
	var castle_threshold: Vector3 = entrance_root.get("CASTLE_THRESHOLD")
	var upper_deck_y: float = entrance_root.get("UPPER_DECK_Y")
	var castle_rise: float = entrance_root.get("CASTLE_RISE")
	var door_level: Vector3 = entrance_root.get("DOOR_LEVEL")
	var court_level: Vector3 = entrance_root.get("COURT_LEVEL")
	if not is_equal_approx(castle.position.y, 74.49) \
		or not is_equal_approx(castle_threshold.y, 78.33) \
		or not is_equal_approx(castle_rise, 9.0) \
		or not is_equal_approx(door_level.y, castle_rise) \
		or not court_level.is_zero_approx() \
		or castle_threshold.y <= upper_deck_y + 5.5:
		_fail("high aether citadel datum is not elevated above the entrance court")
		return
	var entrance_rig := entrance_root.get_node_or_null("CastleEntrance") as Node3D
	var ascent_ramp := entrance_rig.get_node_or_null("RoyalCastleStair/RoyalTread_00") as MeshInstance3D \
		if entrance_rig != null else null
	if ascent_ramp == null \
		or ascent_ramp.find_children("*", "StaticBody3D", true, false).is_empty():
		_fail("high citadel approach has no collision-backed royal stair")
		return

	# The user requested the floating orbital observatory and its related astral
	# machinery be removed completely. The simple castle keeps only the authored
	# architecture, living-tree foundation, and safe gameplay approach.
	for removed_path in ["HighAetherFacade", "AetherCalibrationBand",
			"AstralObservatoryCrown", "ReferenceAstralMachine"]:
		if foundation.get_node_or_null(removed_path) != null:
			_fail("removed orbital castle machinery still exists: %s" % removed_path)
			return
	if not hub.find_children("AetherCalibrationNode_*", "Node3D", true, false).is_empty() \
			or not hub.find_children("CelestialCoreRing_*", "MeshInstance3D", true, false).is_empty():
		_fail("orbital calibration or celestial-core pieces remain in the hub")
		return
	var simple_palette_found := false
	for castle_mesh_candidate in castle.find_children("*", "MeshInstance3D", true, false):
		var castle_mesh := castle_mesh_candidate as MeshInstance3D
		if castle_mesh.mesh == null:
			continue
		for castle_surface in castle_mesh.mesh.get_surface_count():
			var castle_material := castle_mesh.get_active_material(castle_surface)
			if castle_material is StandardMaterial3D \
					and castle_material.get_meta("castle_palette", "") == "sleeping_beauty_rose_atlas" \
					and not (castle_material as StandardMaterial3D).emission_enabled:
				simple_palette_found = true
	if not simple_palette_found:
		_fail("castle does not use the non-emissive rose village colour atlas")
		return

	# Real support collision remains outside the final-ascent corridor after the
	# visual simplification.
	for support_name in ["FoundationRearSupport", "FoundationWestSupport", "FoundationEastSupport"]:
		var support := foundation.get_node_or_null(support_name) as StaticBody3D
		if support == null:
			_fail("simple castle foundation support is missing: %s" % support_name)
			return
		if support.global_position.x > -44.0 \
				and absf(support.global_position.z - entrance_axis.z) < 4.5:
			_fail("foundation support intrudes into final ascent corridor: %s" % support_name)
			return

	var skyway := hub.get_node_or_null("SkywayMap") as Node3D
	var bead_count := skyway.find_children("Skyway_Bead*", "MeshInstance3D", true, false).size() \
		if skyway != null else 0
	if bead_count < 20:
		_fail("constellation route has only %d dotted wayfinding beads" % bead_count)
		return

	var player := hub.get_node_or_null("NewPlayer") as CharacterBody3D
	var camera_arm := player.get_node_or_null("CameraController") as SpringArm3D \
		if player != null else null
	if player == null or float(player.get("runSpeed")) > 10.0:
		_fail("player traversal is still tuned as a debug sprint")
		return
	if camera_arm == null or camera_arm.spring_length < 6.5:
		_fail("professional collision-aware follow camera is not configured")
		return

	print("CASTLE_POLISH_TEST: PASS — reference bridge %d meshes/%d lights; orbital machinery removed; simple village palette active" \
		% [bridge_mesh_count, bridge_light_count])
	quit()


func _init() -> void:
	call_deferred("_run")
