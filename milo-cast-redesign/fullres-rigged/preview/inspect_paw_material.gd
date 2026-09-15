extends SceneTree

func _initialize() -> void:
	var model = load("res://milo_fullres.glb").instantiate()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if not "Articulated_Paw" in node.name: continue
		for surface in node.mesh.get_surface_count():
			var material = node.mesh.surface_get_material(surface)
			var colors = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			print(node.name, " vertex_colors=", colors.size() if colors != null else 0, " use_as_albedo=", material.vertex_color_use_as_albedo, " srgb=", material.vertex_color_is_srgb, " base=", material.albedo_color)
			if colors != null and colors.size(): print("COLOR_SAMPLE ", colors[0], " ", colors[colors.size()/2])
	model.free()
	quit()
