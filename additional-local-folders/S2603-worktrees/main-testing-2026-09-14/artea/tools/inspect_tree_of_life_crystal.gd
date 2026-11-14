extends SceneTree

## Find the heart crystal in the built tree and report whether it is visible.
##
##   Godot --headless --path artea --script res://tools/inspect_tree_of_life_crystal.gd

const WorldScene := preload("res://scenes/art_castle_floating_world.tscn")


func _init() -> void:
	call_deferred("_inspect")


func _materials_of(mesh_node: MeshInstance3D) -> Array:
	var names: Array = []
	var mesh := mesh_node.mesh
	if mesh == null:
		return names
	for surface in mesh.get_surface_count():
		var material := mesh_node.get_active_material(surface)
		if material != null and material.resource_name != "":
			names.append(material.resource_name)
		elif material != null:
			names.append(str(material))
	return names


func _inspect() -> void:
	var world := WorldScene.instantiate() as Node3D
	root.add_child(world)
	for _frame in 6:
		await process_frame
	var tree := world.get_node_or_null("CentralSanctuary/TreeOfImagination") as Node3D
	if tree == null:
		print("CRYSTAL: no tree")
		quit(1)
		return

	print("CRYSTAL: mesh nodes under the tree, with visibility")
	var hidden_with_crystal := 0
	var visible_with_crystal := 0
	for node in tree.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var mats := _materials_of(mesh_node)
		var has_crystal := false
		for material_name in mats:
			if "Crystal" in str(material_name) or "crystal" in str(material_name):
				has_crystal = true
		# visible_in_tree accounts for a hidden ancestor, which is how the runtime
		# canopy rebuild removes the old layers.
		var shown := mesh_node.is_visible_in_tree()
		if has_crystal:
			if shown:
				visible_with_crystal += 1
			else:
				hidden_with_crystal += 1
			print("CRYSTAL:   %-46s shown=%s parent=%s mats=%s" % [
				mesh_node.name, shown, mesh_node.get_parent().name, mats])
	print("CRYSTAL: crystal-material meshes visible=%d hidden=%d" % [
		visible_with_crystal, hidden_with_crystal])

	var heart := tree.find_children("CrystalTechnology_001", "MeshInstance3D", true, false)
	if not heart.is_empty():
		var mesh_node := heart[0] as MeshInstance3D
		var local := mesh_node.mesh.get_aabb()
		var world_transform := mesh_node.global_transform
		var world_center := world_transform * local.get_center()
		var world_size := world_transform.basis.get_scale() * local.size
		print("CRYSTAL: heart mesh world centre %s" % world_center)
		print("CRYSTAL: heart mesh world size   %s" % world_size)
		print("CRYSTAL: tree base at             %s" % tree.global_position)
		print("CRYSTAL: height above tree base   %.1f" % (world_center.y - tree.global_position.y))

	print("CRYSTAL: top-level layers")
	for child in tree.get_children():
		var node3d := child as Node3D
		if node3d != null:
			print("CRYSTAL:   %-40s visible=%s" % [node3d.name, node3d.visible])
			for sub in node3d.get_children():
				var sub3d := sub as Node3D
				if sub3d != null:
					print("CRYSTAL:       %-36s visible=%s" % [sub3d.name, sub3d.visible])
	quit()
