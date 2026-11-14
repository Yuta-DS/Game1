extends "res://scripts/test_castle_rooftop_barrier_safety.gd"


func _fail(message: String) -> void:
	push_error("CASTLE_ROOFTOP_GARDEN_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 80:
		await process_frame
		await physics_frame
	var stair := hub.get_node("CastleStairs/CastleStair") as Node3D
	var garden := stair.get_node_or_null("CrownRoofGarden") as Node3D
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process_input(false)
	var base: Vector2 = stair.get_meta("tower_base")
	var crown_y := float(stair.get_meta("tower_top_y")) + CROWN_SURFACE_OFFSET
	if garden == null or garden.get_child_count() != 4 \
			or absf(garden.global_position.y - crown_y) > 0.01 \
			or garden.get_meta("garden_style", "") != "medieval_enclosed_herb_garden":
		_fail("four planted beds are not anchored to the roof")
		return
	var palace := stair.get_node_or_null("CrownPalaceGardenArchitecture") as Node3D
	if palace == null:
		_fail("rooftop presentation is missing")
		return
	var battlements := palace.find_children("KeepStyleMerlon*", "MeshInstance3D", true, false)
	if battlements.size() < 8:
		_fail("main-castle battlement rhythm is missing")
		return
	for body: CollisionObject3D in palace.find_children("*", "CollisionObject3D", true, false):
		var merlon := body.get_parent() as MeshInstance3D
		if merlon == null or not merlon.get_meta("solid_battlement_above_existing_guard", false):
			_fail("new collision is not an above-wall battlement")
			return
		var size := (merlon.mesh as BoxMesh).size
		var wall_size: Vector3 = merlon.get_parent().get_meta("wall_size")
		var shape := body.get_child(0) as CollisionShape3D
		if (shape.shape as BoxShape3D).size != size \
				or absf(merlon.position.y - size.y * 0.5 - wall_size.y) > 0.001 \
				or absf(merlon.position.x) + size.x * 0.5 > wall_size.x * 0.5 \
				or size.z > wall_size.z + 0.001:
			_fail("battlement mesh/collider mismatch or intrusion into walking space")
			return
	var walls := palace.find_children("PalaceWall_*", "Node3D", false, false)
	if walls.size() < 6 or palace.find_children("PalaceParapetTorch_*", "Node3D", false, false).size() < 6:
		_fail("palace design does not cover the perimeter and its corners")
		return
	var torches := palace.find_children("PalaceParapetTorch_*", "Node3D", false, false)
	var caps := stair.find_children("CrownParapetJointPierCap_*", "MeshInstance3D", false, false)
	if torches.size() != caps.size() or not palace.find_children("PalacePlantedUrn_*", "Node3D", true, false).is_empty():
		_fail("not every green globe was replaced by a torch")
		return
	for torch: Node3D in torches:
		if torch.find_children("*", "MeshInstance3D", true, false).size() != 2 \
				or not torch.has_node("ForgedIronBasketAndFuel") or not torch.has_node("LiveFlames"):
			_fail("torch is missing its iron basket/flame or exceeds two mesh surfaces")
			return
		var aligned := false
		for cap: Node3D in caps:
			if torch.global_position.distance_to(cap.global_position+Vector3.UP*0.07) < 0.001:
				aligned = true
		if not aligned:
			_fail("torch is floating or misaligned with the existing pier cap")
			return
		var flame := (torch.get_node("LiveFlames") as MeshInstance3D).material_override as ShaderMaterial
		var clock: float = flame.get_shader_parameter("flame_time")
		for frame in 4:
			await process_frame
		if float(flame.get_shader_parameter("flame_time")) <= clock:
			_fail("torch flame is static")
			return
	var returns := palace.find_children("PalaceReturn_*", "Node3D", false, false)
	if returns.size() != 2:
		_fail("short stair-return barriers were left in a different style")
		return
	for candidate in returns:
		var wall := candidate as Node3D
		var source := stair.get_node(NodePath(wall.get_meta("source_wall"))) as MeshInstance3D
		var floor_origin := source.global_position - Vector3.UP * (source.mesh as BoxMesh).size.y * 0.5
		if wall.global_position.distance_to(floor_origin) > 0.001 or source.visible:
			_fail("short palace return is not aligned with its solid wall")
			return
	for candidate in walls:
		var wall := candidate as Node3D
		var source := stair.get_node(NodePath(wall.get_meta("source_wall"))) as Node3D
		if wall.global_position.distance_to(source.global_position) > 0.001 \
				or not wall.global_basis.is_equal_approx(source.global_basis.orthonormalized()) \
				or source.visible:
			_fail("palace wall is misaligned with its original protected edge")
			return
		var size: Vector3 = wall.get_meta("wall_size")
		var patches := wall.find_children("ReferenceStonePatch*", "Node3D", false, false)
		if patches.is_empty():
			_fail("wall is missing the reference masonry detail")
			return
		for patch: Node3D in patches:
			var detail := patch.get_node("FourDressedStones") as MeshInstance3D
			var bounds := patch.transform * detail.get_aabb()
			if bounds.position.z < -size.z * 0.5 - 0.012 or bounds.end.z > size.z * 0.5 + 0.012 \
					or bounds.position.x < -size.x * 0.5 or bounds.end.x > size.x * 0.5:
				_fail("stone patches protrude beyond %s: %s vs wall %s" % [wall.name, bounds, size])
				return
	var curved := palace.get_node_or_null("PalaceCurvedStairGuardMasonry") as Node3D
	if curved == null or int(curved.get_meta("reference_stone_patches", 0)) < 6:
		_fail("curved stair guard was not given the matching palace treatment")
		return
	for label in ["CrownDeck", "CrownDeckCentreStoneFinish", "CrownGatewayApron", "CastleCrownStairLanding"]:
		var floor_mesh := stair.get_node(NodePath(label)) as MeshInstance3D
		var finish := floor_mesh.material_override as ShaderMaterial
		if finish == null or not floor_mesh.visible \
				or finish.shader.resource_path != "res://shaders/castle_palace_paving.gdshader":
			_fail("palace paving was hidden/repainted by the castle palette pass")
			return
	# The fountain now occupies the exact centre. Walk the surrounding paved
	# court at 3.4m, with 45-degree corners keeping the real capsule away from
	# the basin and safely inside the guarded stairwell.
	var centre := Vector3(base.x, crown_y, base.y)
	if not await _settle(player, centre + Vector3(3.4, 2.0, 0)):
		_fail("player could not stand on the palace court")
		return
	for index in range(1, 9):
		var angle := TAU * float(index) / 8.0
		var offset := Vector3(cos(angle), 0, sin(angle)) * 3.4
		if not await _walk_to(player, centre + offset) or absf(player.global_position.y - crown_y) > 0.06:
			_fail("player snagged or sank while crossing the palace paving: position=%s target=%s fountain=%s" % [
				player.global_position, centre + offset, stair.get_node("CastleRoyalFountain").global_position])
			return
	# The split wall panels must follow the tangent, not protrude perpendicular
	# to the parapet. Both visuals and simple collision use the same basis.
	for wing in stair.find_children("CrownStairArrivalWing_*", "Node3D", true, false):
		if not (wing as Node3D).has_meta("source_blend"):
			continue
		var collision := stair.get_node("%sCollision" % wing.name) as Node3D
		var side_index := int(String(wing.name).split("_")[1])
		var angle := TAU * float(side_index) / 8.0
		var tangent := Vector3(-sin(angle), 0.0, cos(angle))
		if absf((wing as Node3D).global_basis.x.normalized().dot(tangent)) < 0.999 \
				or absf(collision.global_basis.x.normalized().dot(tangent)) < 0.999:
			_fail("arrival wing is still perpendicular to the parapet")
			return
	var joints := stair.find_children("RoundedStairwellJoint_*", "MeshInstance3D", true, false)
	if joints.size() != 2:
		_fail("curved guard has no rounded end joints")
		return
	for joint in joints:
		if not ((joint as MeshInstance3D).mesh is CylinderMesh) \
				or joint.find_children("*", "StaticBody3D", true, false).is_empty():
			_fail("rounded joint is not solid")
			return
	for bed_candidate in garden.get_children():
		var bed := bed_candidate as Node3D
		var herbs := bed.get_node_or_null("MedievalHerbPlanting") as MeshInstance3D
		if herbs == null or herbs.get_meta("species", []) != ["sage","rue","chamomile"] \
				or bed.find_children("*", "StaticBody3D", true, false).size() != 1 \
				or not bed.find_children("RoyalTopiary_*", "Node3D", true, false).is_empty() \
				or not bed.find_children("GardenFlower_*", "Node3D", true, false).is_empty():
			_fail("herb bed lost species, retained old topiary or added snag-prone collision")
			return
		var arrays := herbs.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if herbs.mesh.get_surface_count() != 1 or vertices.size()/3 > 15000:
			_fail("medieval herb bed exceeds Web geometry/draw budget")
			return
		var material := herbs.material_override as StandardMaterial3D
		if material == null or not material.vertex_color_use_as_albedo:
			_fail("herb palette was repainted as castle stone")
			return
		for point: Vector3 in vertices:
			if not point.is_finite() or point.y < 0.3199 or point.y > 0.75:
				_fail("herb/wattle geometry leaves the low planting envelope: %s" % point)
				return
		for mesh_node in bed.find_children("*", "MeshInstance3D", true, false):
			var mesh := mesh_node as MeshInstance3D
			var bounds := mesh.get_aabb()
			# Existing soft ivy hangs a little beyond the stone face; it never
			# receives collision. All other planting stays inside the bed envelope.
			var max_depth := 0.96 if String(mesh.name).begins_with("TrailingIvy") else 0.87
			for corner in 8:
				var local_corner := bed.to_local(mesh.to_global(bounds.get_endpoint(corner)))
				if absf(local_corner.x) > 1.326 or absf(local_corner.z) > max_depth:
					_fail("garden decoration protrudes into a walking route: %s" % mesh.name)
					return
		var radial := Vector3(bed.global_position.x - base.x, 0.0,
			bed.global_position.z - base.y).normalized()
		var tangent := Vector3(-radial.z, 0.0, radial.x)
		var front := bed.global_position - radial * 1.7
		if not await _settle(player, front + Vector3.UP * 2.0):
			_fail("player could not stand in front of planter")
			return
		await _run_direction(player, radial, 12)
		if player.global_position.y < crown_y - 0.05 \
				or Vector2(player.global_position.x - base.x,
					player.global_position.z - base.y).length() > 7.8:
			_fail("player fell or passed through %s: %s, roof %.3f" % [
				bed.name, player.global_position, crown_y])
			return
		if not await _walk_to(player, front) \
				or not await _walk_to(player, front + tangent * 1.8) \
				or not await _walk_to(player, front - tangent * 1.8):
			_fail("player snagged along planter front/corner")
			return
		# Falling onto the bed exercises actual support, including its soil/rim
		# datum. Stems and fern leaves must never catch a descending capsule.
		if not await _settle(player, bed.global_position + Vector3.UP * 2.6) \
				or absf(player.global_position.y - crown_y - 0.32) > 0.06:
			_fail("player does not land with feet on the planter soil surface")
			return
		if not await _walk_to(player, front):
			_fail("player stuck stepping off planter")
			return
	print("CASTLE_ROOFTOP_GARDEN_TEST: PASS — reference stone perimeter/curved masonry, animated iron torches, flush patterned court, medieval herb plots; aligned walls; sprint, court traversal, corners, landings and exits")
	quit(0)
