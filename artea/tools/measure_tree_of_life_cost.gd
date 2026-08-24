extends SceneTree

## Report what the Tree of Life actually costs to draw.
##
## Runs headless - no rendering needed to count MultiMesh instances and the
## triangles they each replicate.
##
##   Godot --headless --path artea --script res://tools/measure_tree_of_life_cost.gd

const WorldScene := preload("res://scenes/art_castle_floating_world.tscn")


func _init() -> void:
	call_deferred("_measure")


func _mesh_triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var triangles := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			continue
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.size() > 0:
			triangles += indices.size() / 3
		else:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += vertices.size() / 3
	return triangles


func _measure() -> void:
	var world := WorldScene.instantiate() as Node3D
	root.add_child(world)
	for _frame in 6:
		await process_frame
	var tree := world.get_node_or_null("CentralSanctuary/TreeOfImagination") as Node3D
	if tree == null:
		print("COST: no tree")
		quit(1)
		return

	var total_triangles := 0
	var total_instances := 0
	var rows: Array = []
	for node in tree.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := node as MultiMeshInstance3D
		if not batch.visible:
			continue
		var count := batch.multimesh.instance_count
		var per := _mesh_triangles(batch.multimesh.mesh)
		rows.append({"name": batch.name, "instances": count, "per": per, "total": count * per})
		total_instances += count
		total_triangles += count * per

	var single_triangles := 0
	var single_meshes := 0
	for node in tree.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if not mesh_node.visible:
			continue
		single_meshes += 1
		single_triangles += _mesh_triangles(mesh_node.mesh)

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.total > b.total)
	print("COST: visible MultiMesh batches")
	for row in rows:
		print("COST:   %-38s %7d inst x %6d tris = %10d" % [
			row.name, row.instances, row.per, row.total])
	print("COST: multimesh totals  %d instances, %d triangles" % [
		total_instances, total_triangles])
	print("COST: plain meshes      %d visible, %d triangles" % [
		single_meshes, single_triangles])
	print("COST: TREE TOTAL        %d triangles" % [total_triangles + single_triangles])

	var lights := tree.find_children("*", "Light3D", true, false).size()
	print("COST: lights on tree    %d" % lights)
	quit()
