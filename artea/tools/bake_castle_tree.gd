extends SceneTree

## Build the exact authored tree once per Web export, including generated
## meshes, leaf instances, materials, collision shapes and animation metadata.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	OS.set_environment("ARTEA_FORCE_WEB_LOD", "1")
	OS.unset_environment("ARTEA_USE_BAKED_TREE")
	var started := Time.get_ticks_msec()
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	var world := gallery.get_node("ArtCastleFloatingWorld")
	var tree := world.get_node("CentralSanctuary/TreeOfImagination") as Node3D
	for child in tree.find_children("*", "", true, false):
		# Flatten imported subscene instance boundaries before taking ownership;
		# otherwise PackedScene restores their source children a second time.
		child.scene_file_path = ""
		child.owner = tree
	var packed := PackedScene.new()
	if packed.pack(tree) != OK:
		push_error("Cannot pack generated castle tree")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://generated")
	if ResourceSaver.save(packed, "res://generated/castle_tree.scn", ResourceSaver.FLAG_COMPRESS) != OK:
		push_error("Cannot save generated castle tree")
		quit(1)
		return
	# Reload from disk: verify saved mesh data, metadata, transforms and physics,
	# rather than merely checking a file was written.
	var saved := (load("res://generated/castle_tree.scn") as PackedScene).instantiate()
	if _signature(tree) != _signature(saved):
		_find_difference(tree, saved)
		saved.free()
		gallery.queue_free()
		await process_frame
		quit(1)
		return
	saved.free()
	print("CASTLE TREE BAKE: PASS in ", Time.get_ticks_msec() - started, " ms")
	gallery.queue_free()
	await process_frame
	quit()

func _signature(node: Node) -> Array:
	var values: Array = [node.name, node.get_class()]
	if node is Node3D:
		values.append(node.transform)
	if node is MeshInstance3D:
		values.append(node.visible)
		values.append(_material(node.material_override))
		values.append(_material(node.material_overlay))
		values.append(node.mesh.get_aabb() if node.mesh != null else AABB())
		if node.mesh != null:
			for surface in node.mesh.get_surface_count():
				values.append(hash(node.mesh.surface_get_arrays(surface)))
				values.append(_material(node.get_surface_override_material(surface)))
				values.append(_material(node.mesh.surface_get_material(surface)))
	if node is MultiMeshInstance3D:
		values.append(node.multimesh.instance_count)
		values.append(hash(node.multimesh.buffer))
		values.append(_material(node.material_override))
		for surface in node.multimesh.mesh.get_surface_count():
			values.append(_material(node.multimesh.mesh.surface_get_material(surface)))
	if node is CollisionShape3D:
		values.append(node.shape.get_class())
		values.append(node.shape.get_debug_mesh().get_aabb())
	var keys := node.get_meta_list()
	keys.sort()
	for key in keys:
		if not str(key).begins_with("_"):
			values.append([key, node.get_meta(key)])
	for child in node.get_children():
		values.append(_signature(child))
	return values

func _material(material: Material) -> Dictionary:
	var properties := {}
	if material == null:
		return properties
	for property in material.get_property_list():
		if not property.usage & PROPERTY_USAGE_STORAGE or property.name == "resource_path":
			continue
		var value = material.get(property.name)
		if value is Texture2D:
			value = [value.resource_path, hash(value.get_image().get_data())]
		elif value is Shader:
			value = value.code
		elif value is Material:
			value = _material(value)
		properties[property.name] = value
	return properties

func _find_difference(original: Node, saved: Node) -> void:
	if original.get_child_count() == saved.get_child_count():
		for index in original.get_child_count():
			if _signature(original.get_child(index)) != _signature(saved.get_child(index)):
				_find_difference(original.get_child(index), saved.get_child(index))
				return
	push_error("Prepared tree mismatch at %s" % original.get_path())
	print("ORIGINAL CHILDREN ", original.get_children().map(func(n): return n.name))
	print("SAVED CHILDREN ", saved.get_children().map(func(n): return n.name))
	var original_values := _signature(original)
	var saved_values := _signature(saved)
	for index in mini(original_values.size(), saved_values.size()):
		if original_values[index] != saved_values[index]:
			print("FIRST DIFFERENCE index ", index)
			if not original_values[index] is Array:
				print(original_values[index], " != ", saved_values[index])
			break
