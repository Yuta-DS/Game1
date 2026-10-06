extends RefCounted
## Measures the actual tapered purple beam in train-local coordinates.

const EDGE_INSET := 0.12
const LINE_CLEARANCE := 0.10
const CONTACT_OVERLAP := 0.008

static func purple_faces(train: Node3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	var detailed := train.get_node("BlenderCrownLineTrain")
	for instance: MeshInstance3D in detailed.find_children("*", "MeshInstance3D", true, false):
		if instance.mesh == null:
			continue
		var to_train := train.global_transform.affine_inverse() * instance.global_transform
		for surface in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface)
			if material == null or material.resource_name.to_lower() != "engine_rainbow_violet":
				continue
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				var a := to_train * vertices[indices[i]]
				var b := to_train * vertices[indices[i + 1]]
				var c := to_train * vertices[indices[i + 2]]
				# The same violet material also colours lower engine/deck pieces.
				# They must never widen the measured roof profile.
				if minf(a.y, minf(b.y, c.y)) < 7.1 or maxf(a.y, maxf(b.y, c.y)) > 8.3:
					continue
				result.append_array(PackedVector3Array([a, b, c]))
	return result

static func side_anchor(faces: PackedVector3Array, z: float, side: float) -> Vector3:
	var edge_x := 0.0
	for i in range(0, faces.size(), 3):
		for edge in 3:
			var a := faces[i + edge]
			var b := faces[i + (edge + 1) % 3]
			if z < minf(a.z, b.z) - 0.00001 or z > maxf(a.z, b.z) + 0.00001:
				continue
			if absf(a.z - b.z) < 0.00001:
				edge_x = maxf(edge_x, maxf(side * a.x, side * b.x))
			else:
				edge_x = maxf(edge_x, side * a.lerp(b, (z - a.z) / (b.z - a.z)).x)
	return anchor_at(faces, side * (edge_x - EDGE_INSET), z)

static func anchor_at(faces: PackedVector3Array, x: float, z: float) -> Vector3:
	var height := INF
	for i in range(0, faces.size(), 3):
		var hit = Geometry3D.ray_intersects_triangle(Vector3(x, 6.0, z), Vector3.UP,
			faces[i], faces[i + 1], faces[i + 2])
		if hit != null:
			height = minf(height, (hit as Vector3).y)
	return Vector3(x, height, z)
