extends RefCounted

## Leaf Style A — compact faceted foliage pod.
##
## This file owns every vertex of Style A. It does not import or call Style B,
## so either renderer can change without altering the other leaf silhouette.


static func style_id() -> String:
	return "faceted_pod"


static func prepare_transforms(
		source: Array[Transform3D]) -> Array[Transform3D]:
	# Style A retains every compact pod placement exactly as authored.
	return source.duplicate()


static func build_mesh(family_material: StandardMaterial3D) -> ArrayMesh:
	# A closed 24-triangle oval whose local X axis follows the twig socket.
	var vertices := PackedVector3Array([Vector3.ZERO])
	var normals := PackedVector3Array([Vector3.LEFT])
	for ring in 2:
		var x := 0.42 if ring == 0 else 1.18
		var radius_y := 0.68 if ring == 0 else 0.62
		var radius_z := 0.54 if ring == 0 else 0.60
		for side in 6:
			var angle := TAU * float(side) / 6.0
			var radial := Vector3(0.0, cos(angle), sin(angle))
			vertices.append(Vector3(x, cos(angle) * radius_y,
				sin(angle) * radius_z))
			normals.append((radial + Vector3(
				0.10 if ring == 0 else -0.10, 0.0, 0.0)).normalized())
	var tip_index := vertices.size()
	vertices.append(Vector3(1.62, 0.0, 0.0))
	normals.append(Vector3.RIGHT)
	var indices := PackedInt32Array()
	for side in 6:
		var next := (side + 1) % 6
		var first := 1 + side
		var first_next := 1 + next
		var second := 7 + side
		var second_next := 7 + next
		indices.append_array(PackedInt32Array([
			0, first_next, first,
			first, first_next, second_next,
			first, second_next, second,
			second, second_next, tip_index,
		]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, family_material)
	return mesh
