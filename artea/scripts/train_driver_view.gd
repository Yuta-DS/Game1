extends RefCounted

# Remove only the authored navigation wheel; first person renders the intact train.

static func find_control_wheel_triangles(instance: MeshInstance3D, train: Node3D,
		vertices: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	# Work on whole disconnected pieces so the overlapping overhead instrument
	# rings are preserved, rather than sliced by a rectangular triangle filter.
	var to_train := train.global_transform.affine_inverse() * instance.global_transform
	var candidates: Array[int] = []
	var parents: Array[int] = []
	var owner := {}
	var search_box := AABB(Vector3(-2.1, 4.6, -17.6), Vector3(4.2, 2.9, 1.4))
	for i in range(0, indices.size(), 3):
		if not (search_box.has_point(to_train * vertices[indices[i]]) \
				or search_box.has_point(to_train * vertices[indices[i + 1]]) \
				or search_box.has_point(to_train * vertices[indices[i + 2]])):
			continue
		var candidate := candidates.size()
		candidates.append(i)
		parents.append(candidate)
		for corner in 3:
			var key := vertices[indices[i + corner]].snapped(Vector3.ONE * 0.0001)
			if owner.has(key):
				parents[_root(parents, candidate)] = _root(parents, owner[key])
			else:
				owner[key] = candidate
	var bounds := {}
	for candidate in candidates.size():
		var root := _root(parents, candidate)
		for corner in 3:
			var point := to_train * vertices[indices[candidates[candidate] + corner]]
			bounds[root] = (bounds[root] as AABB).expand(point) if bounds.has(root) \
				else AABB(point, Vector3.ZERO)
	var selected := {}
	for root in bounds:
		var box: AABB = bounds[root]
		var centre := box.get_center()
		# Separate overhead centre pendant (ring, three beads, crystal) sits
		# just behind the wheel. Its measured centres distinguish it from the
		# wheel's concentric rings at y=6.22 and z=-16.95.
		var overhead := false
		if absf(centre.x) < 0.02 and absf(centre.z + 17.0) < 0.02:
			for y in [6.90, 6.78, 6.64, 6.50, 6.28]:
				if absf(centre.y - y) < 0.02:
					overhead = true
		if overhead:
			continue
		var inside := true
		for corner in 8:
			var point := box.get_endpoint(corner)
			inside = inside and absf(point.x) <= 1.86 and point.y >= 4.79 and point.y <= 7.02 \
				and point.z >= -17.40 and point.z <= -16.40 \
				and (point.y < 6.05 or absf(point.x) <= 0.85)
		if inside:
			selected[root] = true
	var result := {}
	for candidate in candidates.size():
		if selected.has(_root(parents, candidate)):
			result[candidates[candidate]] = true
	return result

static func _root(parents: Array[int], index: int) -> int:
	while parents[index] != index:
		parents[index] = parents[parents[index]]
		index = parents[index]
	return index
