extends SceneTree

# Development audit for authored village structures. It reports their real
# rendered footprints, making overlap cleanup independent of model pivots.

const HUB := preload("res://scenes/New_Hub_World.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var hub := HUB.instantiate()
	root.add_child(hub)
	await process_frame
	await process_frame
	var structures: Array[Node3D] = []
	_collect_structures(hub, structures)
	var terrain = hub.get_node_or_null("Environment/Terrain3D")
	var bounds := {}
	for structure in structures:
		var footprint := _visual_bounds(structure)
		if footprint.size.length_squared() > 0.0:
			bounds[structure] = footprint
			var ground_y: float = terrain.data.get_height(structure.global_position) \
				if terrain != null else structure.global_position.y
			print("VILLAGE_BOUND %s pos=(%.2f,%.2f,%.2f) ground=%.2f delta=%.2f x=[%.2f,%.2f] z=[%.2f,%.2f]" % [
				str(hub.get_path_to(structure)), structure.global_position.x,
				structure.global_position.y, structure.global_position.z, ground_y,
				structure.global_position.y - ground_y, footprint.position.x, footprint.end.x,
				footprint.position.z, footprint.end.z])
	for first in bounds:
		for second in bounds:
			if first.get_instance_id() >= second.get_instance_id():
				continue
			var overlap := _xz_overlap(bounds[first], bounds[second])
			if overlap.x > 0.35 and overlap.y > 0.35:
				print("VILLAGE_OVERLAP %s <-> %s area=%.2f depths=(%.2f,%.2f)" % [
					str(hub.get_path_to(first)), str(hub.get_path_to(second)),
					overlap.x * overlap.y, overlap.x, overlap.y])
	hub.queue_free()
	await process_frame
	quit()


func _collect_structures(node: Node, output: Array[Node3D]) -> void:
	for child in node.get_children():
		if child is Node3D and _is_structure(child):
			output.append(child)
		else:
			_collect_structures(child, output)


func _is_structure(node: Node3D) -> bool:
	var label := node.name.to_lower()
	if label.begins_with("building_") or label.begins_with("stall"):
		return true
	return label.begins_with("ms_") or label.begins_with("cl_") or label.begins_with("hm_")


func _visual_bounds(node: Node3D) -> AABB:
	var points := PackedVector3Array()
	_collect_mesh_points(node, points)
	if points.is_empty():
		return AABB()
	var result := AABB(points[0], Vector3.ZERO)
	for point in points:
		result = result.expand(point)
	return result


func _collect_mesh_points(node: Node, points: PackedVector3Array) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var mesh_instance := node as MeshInstance3D
		var box: AABB = mesh_instance.mesh.get_aabb()
		for x in [box.position.x, box.end.x]:
			for y in [box.position.y, box.end.y]:
				for z in [box.position.z, box.end.z]:
					points.append(mesh_instance.global_transform * Vector3(x, y, z))
	for child in node.get_children():
		_collect_mesh_points(child, points)


func _xz_overlap(first: AABB, second: AABB) -> Vector2:
	return Vector2(
		minf(first.end.x, second.end.x) - maxf(first.position.x, second.position.x),
		minf(first.end.z, second.end.z) - maxf(first.position.z, second.position.z))
