extends RefCounted

const Torch := preload("res://scripts/castle_parapet_torch.gd")
const Garden := preload("res://scripts/castle_rooftop_garden.gd")
const ReferenceStyle := preload("res://scripts/castle_reference_style.gd")
const Paving := preload("res://shaders/castle_palace_paving.gdshader")
const PANEL_LENGTH := 6.236
const STONE := ReferenceStyle.WALL
const CREAM := ReferenceStyle.TRIM
const RECESS := ReferenceStyle.RECESS
const GOLD := Color("bda365")


static func build(parent: Node3D, origin: Vector3) -> void:
	var palace := Node3D.new()
	palace.name = "CrownPalaceGardenArchitecture"
	parent.add_child(palace)
	palace.global_position = origin
	palace.set_meta("preserve_castle_finish", true)
	palace.set_meta("collision_policy", "reuse_existing_barriers_and_floor_plus_solid_merlons_above")
	var stone := ReferenceStyle.material("wall")
	var cream := ReferenceStyle.material("trim")
	var facing := Garden._material(Color.WHITE)
	facing.vertex_color_use_as_albedo = true
	facing.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Replace presentation only. All existing smooth wall bodies, openings,
	# heights and orientations remain the gameplay authority.
	for candidate in parent.get_children():
		if not candidate is Node3D:
			continue
		var source := candidate as Node3D
		var label := String(source.name)
		if label.begins_with("BlenderCrownParapetPanel_") \
				or (label.begins_with("CrownStairArrivalWing_") and source.has_meta("source_blend")) \
				or label == "BlenderCrownStairArrivalGuard_Outer":
			var size := Vector3(PANEL_LENGTH * source.scale.x,
				1.18 * source.scale.y, 0.64 * source.scale.z)
			var bay := Node3D.new()
			bay.name = "PalaceWall_%s" % label
			palace.add_child(bay)
			bay.global_transform = Transform3D(source.global_basis.orthonormalized(), source.global_position)
			bay.set_meta("source_wall", label)
			bay.set_meta("wall_size", size)
			_build_wall(bay, size, stone, cream, facing)
			source.visible = false
			source.set_meta("replaced_by_palace_facing", true)
		elif label.begins_with("StairwellStoneBalustrade_"):
			var old_size := ((source as MeshInstance3D).mesh as BoxMesh).size
			var bay := Node3D.new()
			bay.name = "PalaceReturn_%s" % label
			palace.add_child(bay)
			bay.global_transform = source.global_transform
			bay.global_position -= Vector3.UP * old_size.y * 0.5
			bay.set_meta("source_wall", label)
			_build_wall(bay, old_size + Vector3(0, 0.14, 0), stone, cream, facing)
			source.visible = false
			var old_cap := parent.get_node("StairwellBalustradeCoping_%s" % label.right(1)) as Node3D
			old_cap.visible = false
		elif label.begins_with("CrownParapetJointPierCap_"):
			Torch.build(palace, source.global_position + Vector3.UP * 0.07,
				float(palace.get_child_count()) * 0.83)
	_build_curved_facing(parent, palace, facing)
	var paving := ShaderMaterial.new()
	paving.shader = Paving
	paving.set_shader_parameter("roof_origin", origin)
	for label in ["CrownDeck", "CrownDeckCentreStoneFinish", "CrownGatewayApron",
			"CastleCrownStairLanding"]:
		var floor_mesh := parent.get_node_or_null(NodePath(label)) as MeshInstance3D
		if floor_mesh == null:
			continue
		floor_mesh.material_override = paving
		floor_mesh.set_meta("preserve_castle_finish", true)
		floor_mesh.set_meta("palace_paving_on_existing_floor", true)
	palace.set_meta("paved_surface_count", 4)


static func _build_wall(parent: Node3D, size: Vector3, stone: Material,
		cream: Material, facing: Material) -> void:
	Garden._box(parent, "SolidPalaceWall", Vector3(size.x, size.y - 0.10, size.z - 0.06),
		Vector3(0, (size.y - 0.10) * 0.5, 0), stone)
	Garden._box(parent, "StoneSocle", Vector3(size.x, 0.22, size.z), Vector3(0, 0.11, 0), cream)
	Garden._box(parent, "ContinuousCoping", Vector3(size.x + 0.09, 0.14, size.z + 0.12),
		Vector3(0, size.y - 0.07, 0), cream)
	# Low, solid merlons repeat the main keep's battlement silhouette. Keep the
	# continuous wall below them; never cut player-sized gaps into the barrier.
	# Short stair/gateway returns stay unobstructed and retain their smooth joins.
	if size.x > 4.0:
		for x: float in [-size.x * 0.26, size.x * 0.26]:
			var merlon_size := Vector3(0.86, 0.38, size.z)
			var merlon := ReferenceStyle.box(parent, "KeepStyleMerlon", merlon_size,
				Vector3(x, size.y + 0.19, 0), "wall")
			merlon.set_meta("solid_battlement_above_existing_guard", true)
			var body := StaticBody3D.new()
			body.name = "MerlonSolidBody"
			merlon.add_child(body)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = merlon_size
			shape.shape = box
			body.add_child(shape)
	var count := maxi(1, floori(size.x / 3.0))
	var patch_scale := minf(0.82, size.x * 0.8)
	for column in count:
		var x := -size.x * 0.5 + (float(column) + 0.5) * size.x / float(count)
		for side: float in [-1, 1]:
			ReferenceStyle.cluster(parent, Vector3(x, size.y * 0.50, side * (size.z * 0.5 - 0.025)),
				Vector3(0, 0, side), patch_scale)
	parent.set_meta("reference_stone_patches", count * 2)


static func _build_curved_facing(parent: Node3D, palace: Node3D, _facing: Material) -> void:
	var guard := parent.get_node("CrownStairwellInnerReturn") as MeshInstance3D
	var profile: Dictionary = guard.get_meta("palace_wall_profile")
	var radius: float = profile.radius
	var start: float = profile.start_angle
	var end: float = profile.end_angle
	var count := maxi(3, floori((end - start) * radius / 2.8))
	var details := Node3D.new()
	details.name = "PalaceCurvedStairGuardMasonry"
	palace.add_child(details)
	details.set_meta("follows_existing_guard_radius", radius)
	details.set_meta("reference_stone_patches", count * 2)
	for column in count:
		var angle := lerpf(start, end, (float(column) + 0.5) / float(count))
		var radial := Vector3(cos(angle), 0, sin(angle))
		for side: float in [-1, 1]:
			ReferenceStyle.cluster(details, radial * (radius + side * (float(profile.half_width) + 0.004))
				+ Vector3.UP * float(profile.height) * 0.53, radial * side, 0.8)
	for brick in parent.find_children("CrownStairwellReturnBrick_*", "MeshInstance3D", false, false):
		(brick as MeshInstance3D).visible = false
