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
	for required in ["AscentRoadbed", "OuterContinuousGuard",
			"InnerContinuousGuard", "InnerSafetyPlinth"]:
		var part := stair.get_node_or_null(required) as MeshInstance3D
		if part == null or part.mesh == null:
			_fail("missing continuous stair part %s" % required)
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
		var slot_surface_y := lerpf(ascent_ground + 0.4, ascent_top, slot_t)
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
	var safety_posts := stair.find_children("AetherSafetyPost_*", "MeshInstance3D", true, false)
	if safety_fields.size() != 6 or safety_posts.size() != 10:
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
	# Exact Aether Lens Bridge inventory. The former duplicated gateways used
	# unnamed 1.15 m collider piers at the deck edge and a 6 m box lintel across
	# the player camera. The new paired lens gates are named, visual-only, and
	# stand outside the complete 4.8 m road envelope.
	var rune_seals := stair.find_children("LumenRuneSeal_*", "MeshInstance3D", true, false)
	var arch_pylons := stair.find_children("LumenArchPylon_*", "MeshInstance3D", true, false)
	var arch_keystones := stair.find_children("LumenArchKeystone_*", "MeshInstance3D", true, false)
	var lens_gates := stair.find_children("*AetherLensGate", "Node3D", true, false)
	var lens_pylons := stair.find_children("AetherLensPylon_*", "MeshInstance3D", true, false)
	var lens_yokes := stair.find_children("AetherLensYoke_*", "MeshInstance3D", true, false)
	var lens_apices := stair.find_children("AetherLensApex_*", "MeshInstance3D", true, false)
	var midspan_frames := stair.find_children("MidspanResonanceFrame", "Node3D", true, false)
	var arch_yokes := stair.find_children("LumenArchYoke_*", "MeshInstance3D", true, false)
	var glass_bays := stair.find_children("AetherRuneGlassBay_*", "MeshInstance3D", true, false)
	var glass_tracery := stair.find_children("AetherGlassTracery_*", "MeshInstance3D", true, false)
	var rune_fascias := stair.find_children("AetherRuneFascia_*", "MeshInstance3D", true, false)
	var fascia_runes := stair.find_children("AetherFasciaRune_*", "MeshInstance3D", true, false)
	var gear_roots := stair.find_children("AetherGear_*", "Node3D", true, false)
	var gear_hubs := stair.find_children("AetherGearHub_*", "MeshInstance3D", true, false)
	var gear_cores := stair.find_children("AetherGearCore_*", "MeshInstance3D", true, false)
	var gear_teeth := stair.find_children("AetherGearTooth_*", "MeshInstance3D", true, false)
	var astrolabe_rings := stair.find_children("AetherAstrolabeRing_*", "MeshInstance3D", true, false)
	var astrolabe_cores := stair.find_children("AetherAstrolabeCore_*", "MeshInstance3D", true, false)
	var conductors := stair.find_children("LumenCenterConductor_*", "MeshInstance3D", true, false)
	var tension_ribs := stair.find_children("AetherTensionRib_*", "MeshInstance3D", true, false)
	var underbraces := stair.find_children("AetherUnderbrace_*", "MeshInstance3D", true, false)
	var levitation_coils := stair.find_children("AetherLevitationCoil_*", "MeshInstance3D", true, false)
	var bridge_keel := stair.get_node_or_null("AetherBridgeKeel") as MeshInstance3D
	if rune_seals.size() != 3 or arch_pylons.size() != 2 or arch_keystones.size() != 1 \
			or lens_gates.size() != 2 or lens_pylons.size() != 4 \
			or lens_yokes.size() != 8 or lens_apices.size() != 2 \
			or midspan_frames.size() != 1 or arch_yokes.size() != 4 \
			or glass_bays.size() != 6 or glass_tracery.size() != 12 \
			or rune_fascias.size() != 2 or fascia_runes.size() != 6 \
			or gear_roots.size() != 2 or gear_hubs.size() != 2 \
			or gear_cores.size() != 2 or gear_teeth.size() != 16 \
			or astrolabe_rings.size() != 4 or astrolabe_cores.size() != 2 \
			or conductors.size() != 12 or tension_ribs.size() != 3 \
			or underbraces.size() != 6 or levitation_coils.size() != 2 \
			or bridge_keel == null:
		_fail("Aether Lens Bridge inventory is incomplete: %d seals, %d resonance pylons, %d keystones, %d gates, %d gate pylons, %d yokes, %d lenses, %d conductor segments, %d ribs, %d coils, keel %s"
			% [rune_seals.size(), arch_pylons.size(), arch_keystones.size(),
				lens_gates.size(), lens_pylons.size(), lens_yokes.size(), lens_apices.size(),
				conductors.size(), tension_ribs.size(), levitation_coils.size(), bridge_keel != null])
		return
	# All three pointed assemblies must clear the complete camera prism. The
	# AABB test catches a thickened or lowered yoke even when its origin remains
	# above the clearance plane.
	var clear_prism := AABB(Vector3(-18.6, 67.73 + 0.55, 27.41 - 2.4),
		Vector3(10.6, 2.85, 4.8))
	var reference_ornaments: Array = lens_pylons + lens_yokes + lens_apices \
		+ arch_pylons + arch_yokes + arch_keystones + glass_bays \
		+ glass_tracery + rune_fascias + fascia_runes + gear_hubs \
		+ gear_cores + gear_teeth + astrolabe_rings + astrolabe_cores \
		+ underbraces + tension_ribs + levitation_coils
	for ornament_candidate in reference_ornaments:
		var ornament := ornament_candidate as MeshInstance3D
		if ornament == null or ornament.mesh == null:
			_fail("reference bridge inventory contains an invalid mesh")
			return
		if _world_aabb(ornament).intersects(clear_prism):
			_fail("reference ornament %s enters the 4.8 m × 3.4 m player/camera prism" % ornament.name)
			return
		if not ornament.find_children("*", "StaticBody3D", true, false).is_empty():
			_fail("reference ornament %s carries collision" % ornament.name)
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
	for pylon_candidate in lens_pylons:
		var pylon := pylon_candidate as MeshInstance3D
		if not (pylon.mesh is BoxMesh):
			_fail("lens gate pylon %s is not measurable box geometry" % pylon.name)
			return
		var half_extent := (pylon.mesh as BoxMesh).size.z * 0.5
		var inner_face := absf(pylon.global_position.z - 27.41) - half_extent
		if inner_face < 2.80:
			_fail("lens gate pylon %s narrows the 4.8 m route: inner face %.2f" % [pylon.name, inner_face])
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
	var bridge_ornaments: Array = rune_seals + arch_pylons + arch_keystones \
		+ lens_pylons + lens_yokes + lens_apices + conductors \
		+ tension_ribs + levitation_coils
	bridge_ornaments.append(bridge_keel)
	for ornament in bridge_ornaments:
		if not ornament.find_children("*", "StaticBody3D", true, false).is_empty():
			_fail("Aether Lens Bridge ornament %s has collision inside the visual layer" % ornament.name)
			return

	var foundation := hub.get_node_or_null("CastleFoundation") as Node3D
	var shelf := foundation.get_node_or_null("CitadelRockShelf") as MeshInstance3D \
		if foundation != null else null
	var keel := foundation.get_node_or_null("CitadelRockKeel") as MeshInstance3D \
		if foundation != null else null
	if shelf == null or keel == null or not (shelf.mesh is CylinderMesh):
		_fail("floating citadel has no tapered rock shelf and keel")
		return
	var shelf_mesh := shelf.mesh as CylinderMesh
	if shelf_mesh.top_radius <= shelf_mesh.bottom_radius:
		_fail("citadel foundation is not tapered")
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
		var floor_hit := space_state.intersect_ray(floor_query)
		if not floor_hit.has("collider") or (floor_hit["collider"] != deck_body \
				and floor_hit["collider"] != gateway_apron_body):
			_fail("crown centre has a player-trapping floor gap at radius %.1f angle %.2f"
				% [TRAP_RING_RADIUS, probe_angle])
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
	for shelf_radius: float in [5.1, 7.9]:
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

	# The Lumen Bridge's ceremonial dressing (halo arches, conduit pylons, rune
	# inlays) has to stay decorative. Two things can go wrong as it is tuned:
	# an ornament creeps inboard into the 4.8 m deck at body height, or one
	# quietly gains a collider and becomes a wall across the route. Assert both.
	#
	# Corridor test: for every ceremonial mesh, either it stands outboard of the
	# deck half-width, or it crests above the head-clearance datum, or it lies
	# flush with the deck. Anything else is inside the player's capsule.
	const DECK_HALF_WIDTH := 2.4
	const HEAD_CLEARANCE := 2.4
	const FLUSH_BAND := 0.75
	var stair_owner := hub.get_node_or_null("CastleStairs") as Node3D
	if stair_owner == null:
		_fail("castle stair root did not build")
		return
	var stair_terrace: float = stair_owner.get("TERRACE_DECK_Y")
	var ceremony := stair.find_children("LumenArch*", "MeshInstance3D", true, false)
	ceremony.append_array(
		stair.find_children("LumenRuneSeal_*", "MeshInstance3D", true, false))
	ceremony.append_array(
		stair.find_children("AetherLens*", "MeshInstance3D", true, false))
	if ceremony.size() < 4:
		_fail("Lumen Bridge ceremonial dressing is missing (found %d pieces)"
			% ceremony.size())
		return
	for candidate in ceremony:
		var piece := candidate as MeshInstance3D
		var p := piece.global_position
		# The span runs along X on the castle's Z 27.41 axis, so lateral offset
		# from the corridor centreline is the Z distance.
		var lateral := absf(p.z - 27.41)
		var height := p.y - stair_terrace
		var outboard := lateral >= DECK_HALF_WIDTH - 0.01
		var overhead := height >= HEAD_CLEARANCE
		var flush := height <= FLUSH_BAND
		if not (outboard or overhead or flush):
			_fail("Lumen ceremonial piece %s intrudes into the walking corridor at %s (lateral %.2f m, height %.2f m)"
				% [piece.name, p, lateral, height])
			return
		if not piece.find_children("*", "StaticBody3D", true, false).is_empty():
			_fail("Lumen ceremonial piece %s carries collision; decoration must be visual-only"
				% piece.name)
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
	var ascent_ramp := entrance_rig.get_node_or_null("CastleAscentRamp") as MeshInstance3D \
		if entrance_rig != null else null
	if ascent_ramp == null \
		or ascent_ramp.find_children("*", "StaticBody3D", true, false).is_empty():
		_fail("high citadel approach has no collision-backed smooth ramp")
		return

	# The researched magic-and-science facade must remain an authored system:
	# paired structural buttresses, an instrument aperture and an overhead
	# calibration band. They are visual-only, leaving the ascent collision clear.
	var facade := hub.get_node_or_null("CastleFoundation/HighAetherFacade") as Node3D
	if facade == null \
		or facade.find_children("AetherButtress_*", "Node3D", true, false).size() != 2 \
		or facade.get_node_or_null("ObservatoryAperture") == null \
		or hub.get_node_or_null("CastleFoundation/AetherCalibrationBand") == null \
		or not facade.find_children("*", "StaticBody3D", true, false).is_empty():
		_fail("high aether facade is incomplete")
		return
	var calibration_nodes := hub.find_children("AetherCalibrationNode_*", "Node3D", true, false)
	var observatory := hub.get_node_or_null("CastleFoundation/AstralObservatoryCrown") as Node3D
	if calibration_nodes.size() != 6 \
		or observatory == null \
		or observatory.get_node_or_null("CrownLumenLens") == null \
		or observatory.find_children("CrownAstralFin_*", "Node3D", true, false).size() != 4 \
		or not observatory.find_children("*", "StaticBody3D", true, false).is_empty():
		_fail("art castle structural hierarchy or observatory crown is incomplete")
		return
	if foundation == null:
		_fail("high aether facade has no foundation")
		return
	# The foundation's real support collision must remain outside the central
	# final-ascent corridor. This catches a future return to the old full-disc
	# collider, which would make the taller visual castle look reachable but
	# physically block its stairs midway up.
	for support_name in ["FoundationRearSupport", "FoundationWestSupport", "FoundationEastSupport"]:
		var support := foundation.get_node_or_null(support_name) as StaticBody3D
		if support == null:
			_fail("high aether foundation support is missing: %s" % support_name)
			return
		if support.global_position.x > -44.0 \
			and absf(support.global_position.z - entrance_axis.z) < 4.5:
			_fail("foundation support intrudes into final ascent corridor: %s" % support_name)
			return

	# Whole-castle reference machine: a monumental measuring spire, integrated
	# celestial core, articulated skyline arms, floating archive and readable
	# script facade.  Inventory and dimensions are measured from the live world,
	# while one complete AABB sweep protects the real door/ascent prism.
	var machine := foundation.get_node_or_null("ReferenceAstralMachine") as Node3D
	if machine == null:
		_fail("reference astral machine did not build")
		return
	var machine_meshes := machine.find_children("*", "MeshInstance3D", true, false)
	var machine_lights := machine.find_children("*", "OmniLight3D", true, false)
	if machine_meshes.size() > 100 or machine_lights.size() > 2:
		_fail("reference machine exceeds visual budget: %d meshes / %d lights"
			% [machine_meshes.size(), machine_lights.size()])
		return
	if not machine.find_children("*", "StaticBody3D", true, false).is_empty():
		_fail("reference machine contains gameplay collision")
		return
	var spire := machine.get_node_or_null("AetherMeasureSpire/AetherMeasureMonolith") \
		as MeshInstance3D
	if spire == null:
		_fail("AetherMeasureSpire monolith is missing")
		return
	var spire_bounds := _world_aabb(spire)
	var spire_plan_width := maxf(spire_bounds.size.x, spire_bounds.size.z)
	if spire_bounds.size.y < 24.0 or spire_bounds.size.y > 30.0 \
			or spire_bounds.size.y / spire_plan_width < 5.2:
		_fail("AetherMeasureSpire is not monumental/slender: AABB %s" % spire_bounds)
		return
	var channels := machine.find_children("AetherSpireCyanChannel_*", "MeshInstance3D", true, false)
	var rails := machine.find_children("AetherSpireBrassRail_*", "MeshInstance3D", true, false)
	if channels.size() != 3 or rails.size() != 4:
		_fail("AetherMeasureSpire channel/rail inventory is incomplete")
		return
	var core_sphere := machine.get_node_or_null("CelestialCore/CelestialCoreSphere") \
		as MeshInstance3D
	var core_rings := machine.find_children("CelestialCoreRing_*", "MeshInstance3D", true, false)
	if core_sphere == null or core_rings.size() != 3:
		_fail("CelestialCore sphere or crossed rings are missing")
		return
	if machine.get_node_or_null("CelestialCore/CelestialCoreStalk") == null:
		_fail("CelestialCore is not visibly seated into the castle crown")
		return
	var core_bounds := _world_aabb(core_sphere)
	if core_bounds.size.x < 5.0 or core_bounds.size.x > 7.0 \
			or core_bounds.size.y < 5.0 or core_bounds.size.y > 7.0:
		_fail("CelestialCore is outside the 5–7 m diameter: %s" % core_bounds.size)
		return
	var lumen_arms := machine.find_children("LumenArm_*", "Node3D", true, false)
	var arm_outer_beams := machine.find_children("LumenArmOuterBeam_*", "MeshInstance3D", true, false)
	var arm_conductors := machine.find_children("LumenArmConductor_*", "MeshInstance3D", true, false)
	if lumen_arms.size() != 2 or arm_outer_beams.size() != 4 or arm_conductors.size() != 4:
		_fail("articulated LumenArm skyline inventory is incomplete")
		return
	var archive := machine.get_node_or_null("FloatingArchiveCube") as Node3D
	var archive_faces := machine.find_children("ArchiveLuminousFace_*", "MeshInstance3D", true, false)
	if archive == null or archive_faces.size() != 6:
		_fail("FloatingArchiveCube does not have six luminous inset faces")
		return
	var script_facade := machine.get_node_or_null("MachineScriptFacade") as Node3D
	var script_panels := machine.find_children("MachineScriptPanel_*", "MeshInstance3D", true, false)
	var facade_gears := machine.find_children("MachineFacadeGear_*", "Node3D", true, false)
	var machine_gear_teeth := machine.find_children("MachineGearTooth_*", "MeshInstance3D", true, false)
	var terminals := machine.find_children("*Terminal*", "Node3D", true, false)
	if script_facade == null or script_panels.size() != 4 \
			or facade_gears.size() != 3 or machine_gear_teeth.size() != 18 \
			or terminals.size() < 5:
		_fail("script facade, readable gear train, or distributed terminals are incomplete")
		return
	var door_ascent_prism := AABB(Vector3(-42.5, 67.4, entrance_axis.z - 2.4),
		Vector3(15.0, 14.2, 4.8))
	for machine_piece_candidate in machine_meshes:
		var machine_piece := machine_piece_candidate as MeshInstance3D
		if machine_piece == null or machine_piece.mesh == null:
			_fail("reference machine inventory contains an invalid mesh")
			return
		if _world_aabb(machine_piece).intersects(door_ascent_prism):
			_fail("reference machine piece %s enters the final ascent/door prism"
				% machine_piece.name)
			return
	var machine_transform := machine.global_transform
	var archive_rotation := archive.rotation.y
	for _machine_frame in 24:
		await process_frame
	if not machine.global_transform.is_equal_approx(machine_transform):
		_fail("reference machine architecture moved with its walkable castle")
		return
	if is_equal_approx(archive.rotation.y, archive_rotation):
		_fail("FloatingArchiveCube is not connected to the slow rotor system")
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

	print("CASTLE_POLISH_TEST: PASS — reference bridge %d meshes/%d lights; astral machine %d meshes/%d lights; clear approach prisms" \
		% [bridge_mesh_count, bridge_light_count, machine_meshes.size(), machine_lights.size()])
	quit()


func _init() -> void:
	call_deferred("_run")
