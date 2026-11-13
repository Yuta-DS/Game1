extends SceneTree

const WorldScene := preload("res://scenes/art_castle_floating_world.tscn")


func _init() -> void:
	call_deferred("_run")


func _subtree_bounds(tree: Node3D, subtree: Node) -> AABB:
	var inverse := tree.global_transform.affine_inverse()
	var bounds := AABB()
	var has_bounds := false
	var candidates: Array[Node] = [subtree]
	candidates.append_array(subtree.find_children("*", "GeometryInstance3D", true, false))
	for candidate in candidates:
		if not candidate is GeometryInstance3D:
			continue
		var geometry := candidate as GeometryInstance3D
		if not geometry.is_visible_in_tree():
			continue
		var local_bounds := AABB()
		if geometry is MeshInstance3D:
			var mesh_instance := geometry as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			local_bounds = mesh_instance.mesh.get_aabb()
		elif geometry is MultiMeshInstance3D:
			var batch := geometry as MultiMeshInstance3D
			if batch.multimesh == null or batch.multimesh.mesh == null:
				continue
			var mesh_bounds := batch.multimesh.mesh.get_aabb()
			var has_instance_bounds := false
			for instance_index in batch.multimesh.instance_count:
				var instance_bounds := batch.multimesh.get_instance_transform(
					instance_index) * mesh_bounds
				local_bounds = local_bounds.merge(instance_bounds) \
					if has_instance_bounds else instance_bounds
				has_instance_bounds = true
		else:
			continue
		var in_tree := inverse * geometry.global_transform * local_bounds
		bounds = bounds.merge(in_tree) if has_bounds else in_tree
		has_bounds = true
	return bounds


func _print_bounds(label: String, bounds: AABB) -> void:
	print("BLUEPRINT_AUDIT: %s min=%s max=%s size=%s" % [
		label, bounds.position, bounds.position + bounds.size, bounds.size])


func _run() -> void:
	var world := WorldScene.instantiate() as Node3D
	root.add_child(world)
	for candidate in world.find_children("*", "Node", true, false):
		var candidate_script := candidate.get_script() as Script
		if candidate_script != null and candidate_script.resource_path.ends_with(
				"mind_spark_island_detail_animator.gd"):
			candidate.set_process(false)
	for _frame in 8:
		await process_frame
	var tree := world.get_node_or_null(
		"CentralSanctuary/TreeOfImagination") as Node3D
	if tree == null:
		push_error("BLUEPRINT_AUDIT: production tree missing")
		quit(1)
		return
	var body := tree.get_node_or_null("OldGrowthTrunkBody")
	var canopy := tree.get_node_or_null("LaptopGravityBoughCanopy")
	var visual := tree.get_node_or_null("BlenderTreeOfLifeVisual")
	if body == null or canopy == null or visual == null:
		push_error("BLUEPRINT_AUDIT: required production systems missing")
		quit(1)
		return
	_print_bounds("trunk_root", _subtree_bounds(tree, body))
	_print_bounds("canopy", _subtree_bounds(tree, canopy))
	var star_nodes := canopy.find_children(
		"BlueprintGoldCrownStar", "MeshInstance3D", true, false)
	if not star_nodes.is_empty():
		_print_bounds("star", _subtree_bounds(tree, star_nodes[0]))
	var original_star := visual.find_children("WisdomStar*", "MeshInstance3D", true, false)
	if not original_star.is_empty():
		_print_bounds("authored_star", _subtree_bounds(tree, original_star[0]))
	for batch_name in ["PoweredBranchStructureBatch", "BlueprintTwigFanBatch",
			"PoweredLeafBatch_living_leaf_fan"]:
		var batch := canopy.get_node_or_null(batch_name) as MultiMeshInstance3D
		if batch != null and batch.multimesh.instance_count > 0:
			print("BLUEPRINT_AUDIT: %s mesh=%s first=%s last=%s" % [
				batch_name, batch.multimesh.mesh.get_aabb(),
				batch.multimesh.get_instance_transform(0),
				batch.multimesh.get_instance_transform(
					batch.multimesh.instance_count - 1)])
	quit()
