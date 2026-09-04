@tool
extends EditorScenePostImport

# This Godot build imported COLOR_0 arrays but left the material's vertex
# color switch off. Preserve the authored GLB colors in the saved scene.
func _post_import(scene: Node) -> Object:
	var paws := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		if not node.name.begins_with("Milo_Articulated_Paw"): continue
		paws += 1
		for surface in node.mesh.get_surface_count():
			var colors = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			assert(colors != null and colors.size() > 0, "Authored paw colors missing")
			var material = node.mesh.surface_get_material(surface).duplicate() as BaseMaterial3D
			material.vertex_color_use_as_albedo = true
			material.vertex_color_is_srgb = false # glTF COLOR_0 is linear.
			node.mesh.surface_set_material(surface, material)
	assert(paws == 2)
	return scene
