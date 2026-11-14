extends RefCounted

## Leaf Style B — the supplied low-poly orb, crystal-bud and blade cluster.
##
## This is a fully independent mesh implementation. It intentionally duplicates
## no calls into Style A: the two files only receive the same family material and
## are attached later to the same immutable twig transforms.


static func style_id() -> String:
	return "blossom_bud_cluster"


static func prepare_transforms(
		source: Array[Transform3D]) -> Array[Transform3D]:
	# The supplied reference uses a smaller number of much larger foliage masses.
	# Select every twelfth immutable socket and enlarge only this style's local
	# mesh transform. The source socket array itself is never modified.
	var prepared: Array[Transform3D] = []
	for source_index in range(0, source.size(), 12):
		var placement := source[source_index]
		placement.basis = placement.basis * Basis.from_scale(Vector3.ONE * 1.65)
		prepared.append(placement)
	return prepared


static func _make_material(colour: Color, emission_energy: float,
		roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.emission_enabled = emission_energy > 0.0
	material.emission = colour
	material.emission_energy_multiplier = emission_energy
	return material


static func _add_orb_surface(mesh: ArrayMesh,
		family_material: StandardMaterial3D) -> void:
	# Three octagonal rings form a 48-triangle low-poly oval. This is visibly more
	# mesh-like than Style A while retaining the faceting in the supplied image.
	var vertices := PackedVector3Array([Vector3.ZERO])
	var normals := PackedVector3Array([Vector3.LEFT])
	var ring_specs := [
		Vector3(0.30, 0.58, 0.50),
		Vector3(0.78, 0.78, 0.70),
		Vector3(1.28, 0.60, 0.56),
	]
	for ring_spec_value in ring_specs:
		var ring_spec := ring_spec_value as Vector3
		for side in 8:
			var angle := TAU * float(side) / 8.0
			var radial := Vector3(0.0, cos(angle), sin(angle))
			vertices.append(Vector3(ring_spec.x,
				cos(angle) * ring_spec.y, sin(angle) * ring_spec.z))
			normals.append(radial)
	var tip_index := vertices.size()
	vertices.append(Vector3(1.62, 0.0, 0.0))
	normals.append(Vector3.RIGHT)
	var indices := PackedInt32Array()
	for side in 8:
		var next := (side + 1) % 8
		indices.append_array(PackedInt32Array([0, 1 + next, 1 + side]))
		for ring in 2:
			var current := 1 + ring * 8 + side
			var current_next := 1 + ring * 8 + next
			var following := current + 8
			var following_next := current_next + 8
			indices.append_array(PackedInt32Array([
				current, current_next, following_next,
				current, following_next, following,
			]))
		indices.append_array(PackedInt32Array([
			17 + side, 17 + next, tip_index,
		]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, family_material)


static func _add_bud_surface(mesh: ArrayMesh) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var bud_specs := [
		Vector4(0.30, 0.57, -0.20, 0.15), Vector4(0.52, 0.72, 0.16, 0.18),
		Vector4(0.78, 0.80, -0.10, 0.16), Vector4(1.04, 0.69, 0.25, 0.18),
		Vector4(1.28, 0.54, -0.18, 0.14),
	]
	for spec_value in bud_specs:
		var spec := spec_value as Vector4
		var base := Vector3(spec.x, spec.y, spec.z)
		var radius := spec.w
		var offset := vertices.size()
		for corner in 4:
			var angle := TAU * float(corner) / 4.0
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			vertices.append(base + radial * radius)
			normals.append((radial + Vector3.UP * 0.20).normalized())
		vertices.append(base + Vector3.UP * radius * 2.45)
		normals.append(Vector3.UP)
		for corner in 4:
			var next := (corner + 1) % 4
			indices.append_array(PackedInt32Array([
				offset + corner, offset + next, offset + 4,
			]))
		indices.append_array(PackedInt32Array([
			offset, offset + 2, offset + 1,
			offset, offset + 3, offset + 2,
		]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1,
		_make_material(Color("c7a9cb"), 0.08, 0.82))


static func _add_blade_surface(mesh: ArrayMesh) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var blade_specs := [
		[Vector3(0.20, 0.16, 0.48), Vector3(-0.04, 0.26, 0.98)],
		[Vector3(0.42, -0.20, -0.50), Vector3(0.14, -0.34, -1.02)],
		[Vector3(0.66, 0.22, 0.62), Vector3(0.43, 0.38, 1.16)],
		[Vector3(0.92, -0.18, -0.64), Vector3(0.76, -0.34, -1.18)],
		[Vector3(1.18, 0.15, 0.52), Vector3(1.05, 0.27, 1.02)],
		[Vector3(1.40, -0.12, -0.38), Vector3(1.52, -0.24, -0.82)],
	]
	for blade_value in blade_specs:
		var blade := blade_value as Array
		var root_point := blade[0] as Vector3
		var tip_point := blade[1] as Vector3
		var tangent := (tip_point - root_point).normalized()
		var width := tangent.cross(Vector3.UP)
		if width.length_squared() < 0.001:
			width = Vector3.RIGHT
		width = width.normalized() * 0.11
		var offset := vertices.size()
		vertices.append(root_point - width)
		vertices.append(root_point + width)
		vertices.append(tip_point)
		var normal := width.cross(tangent).normalized()
		normals.append_array(PackedVector3Array([normal, normal, normal]))
		indices.append_array(PackedInt32Array([
			offset, offset + 1, offset + 2,
			offset + 2, offset + 1, offset,
		]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var blade_material := _make_material(Color("69379b"), 0.12, 0.68)
	blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(mesh.get_surface_count() - 1, blade_material)


static func build_mesh(family_material: StandardMaterial3D) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	_add_orb_surface(mesh, family_material)
	_add_bud_surface(mesh)
	_add_blade_surface(mesh)
	return mesh
