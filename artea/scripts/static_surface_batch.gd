extends RefCounted

## Opt-in for completed static architecture only. Merge sibling opaque
## surfaces in their parent's space. Source nodes and physics stay in place;
## parent visibility/transforms still control the replacement geometry.
static func build(root: Node3D, animated: Array = []) -> int:
	var merged := 0
	if not root.visible or root.is_queued_for_deletion(): return merged
	for child in root.get_children():
		if child is Node3D and child.get_script() == null:
			merged += build(child, animated)
	var groups := {}
	for child in root.get_children():
		var item := child as MeshInstance3D
		if item == null or item.mesh == null or not item.visible or item.layers == 0:
			continue
		if item in animated or item.is_queued_for_deletion() or item.get_meta("preserve_runtime_node", false):
			continue
		if item.get_script() != null or not item.get_groups().is_empty() or item.skin != null or item.get_node_or_null(item.skeleton) is Skeleton3D:
			continue
		if item.get_blend_shape_count() > 0 or item.mesh.get_surface_count() != 1 or item.material_overlay != null:
			continue
		if item.transparency != 0.0:
			continue
		if item.mesh is ArrayMesh and item.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		if not (item.mesh is ArrayMesh or item.mesh is PrimitiveMesh):
			continue
		if item.transform.basis.determinant() <= 0 or item.visibility_range_begin != 0 or item.visibility_range_end != 0:
			continue
		var material := item.get_active_material(0) as StandardMaterial3D
		if material == null or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.emission_enabled or material.next_pass != null:
			continue
		if material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or material.get_flag(BaseMaterial3D.FLAG_UV1_USE_TRIPLANAR) or material.get_flag(BaseMaterial3D.FLAG_UV2_USE_TRIPLANAR):
			continue
		# Include every stored material setting, not just its colour. Texture
		# resources compare by identity; animated/emissive materials stay live.
		var key: Array = [item.layers, item.cast_shadow, item.gi_mode, item.extra_cull_margin, material.resource_name]
		for property in material.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_"):
				key.append(material.get(property.name))
		if not groups.has(key): groups[key] = []
		groups[key].append(item)
	for key in groups:
		var items: Array = groups[key]
		if items.size() < 4: continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for item: MeshInstance3D in items:
			surface.append_from(item.mesh, 0, item.transform)
		var first: MeshInstance3D = items[0]
		surface.set_material(first.get_active_material(0))
		var batch := MeshInstance3D.new()
		batch.name = "StaticSurfaceBatch"
		batch.mesh = surface.commit()
		batch.material_override = first.get_active_material(0)
		batch.layers = first.layers
		batch.cast_shadow = first.cast_shadow
		batch.gi_mode = first.gi_mode
		batch.extra_cull_margin = first.extra_cull_margin
		root.add_child(batch)
		for item: MeshInstance3D in items:
			item.set_meta("static_batch_source_layers", item.layers)
			item.layers = 0
		merged += items.size() - 1
	return merged
