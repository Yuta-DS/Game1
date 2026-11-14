extends SceneTree

# Regression coverage for the village cleanup: one intentional Jesus/Father,
# no Father model reused by ordinary NPC systems, no authored object overlap,
# and a continuous central walking route through the village.

const HUB := preload("res://scenes/New_Hub_World.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("SINGLE_JESUS_VILLAGE_LAYOUT_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var hub := HUB.instantiate()
	root.add_child(hub)
	await process_frame
	await process_frame
	var father_instances := hub.find_children("Father_Animations2", "Node3D", true, false)
	if father_instances.size() != 1:
		_fail("the hub must contain exactly one intentional Jesus/Father instance")
		return
	for npc in get_nodes_in_group("villager"):
		if "father" in str(npc.name).to_lower():
			_fail("ordinary villagers must not use the Jesus/Father character")
			return
	var hub_source := FileAccess.get_file_as_string("res://scenes/New_Hub_World.tscn")
	if "villager_father.tscn" in hub_source or "106_vfather" in hub_source:
		_fail("the hub must not instantiate the legacy Father villager")
		return
	for path in [
		"res://scripts/creation_world/semantic_object_factory.gd",
		"res://scripts/viewfinder/crown_of_life_story.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		if "Father_Animations.glb" in source or "Father_output.glb" in source:
			_fail("%s must use a generic character instead of another Jesus" % path)
			return

	var objects: Array[Node3D] = []
	_collect_village_objects(hub, objects)
	var bounds := {}
	for object in objects:
		var box := _visual_bounds(object)
		if box.size.length_squared() > 0.0:
			bounds[object] = box
	for first in bounds:
		for second in bounds:
			if first.get_instance_id() >= second.get_instance_id():
				continue
			var overlap := _xz_overlap(bounds[first], bounds[second])
			if overlap.x > 0.35 and overlap.y > 0.35:
				_fail("village objects overlap: %s and %s" % [
					str(hub.get_path_to(first)), str(hub.get_path_to(second))])
				return

	var central_route := Rect2(84.0, -64.5, 16.0, 108.0)
	for object in bounds:
		var box: AABB = bounds[object]
		var footprint := Rect2(box.position.x, box.position.z, box.size.x, box.size.z)
		if central_route.intersects(footprint):
			_fail("central walking route is blocked by %s" % str(hub.get_path_to(object)))
			return
	print("SINGLE_JESUS_VILLAGE_LAYOUT_TEST: PASS — one Jesus, clear routes, zero village-object overlaps")
	quit()


func _collect_village_objects(node: Node, output: Array[Node3D]) -> void:
	for child in node.get_children():
		if child is Node3D and _is_village_object(child):
			output.append(child)
		else:
			_collect_village_objects(child, output)


func _is_village_object(node: Node3D) -> bool:
	var label := node.name.to_lower()
	return label.begins_with("building_") or label.begins_with("stall") \
		or label.begins_with("ms_") or label.begins_with("cl_") \
		or label.begins_with("hm_")


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
