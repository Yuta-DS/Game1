extends RefCounted


# Some glTF imports lose their embedded atlas even though the source PNG is
# present in the project. Restore it per instance without changing the GLB.
static func apply(root: Node, atlas: Texture2D) -> void:
	if atlas == null:
		return
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index in mesh_instance.mesh.get_surface_count():
				var active := mesh_instance.get_active_material(surface_index)
				if active is StandardMaterial3D:
					var material := active as StandardMaterial3D
					if material.albedo_texture != null:
						continue
					var repaired := material.duplicate() as StandardMaterial3D
					repaired.albedo_texture = atlas
					mesh_instance.set_surface_override_material(surface_index, repaired)
	for child in root.get_children():
		apply(child, atlas)
