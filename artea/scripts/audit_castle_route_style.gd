extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for frame in 90:
		await process_frame
		await physics_frame
	var original := hub.get_node("building_castle_red2/building_castle_red") as MeshInstance3D
	var palette := {}
	for surface in original.mesh.get_surface_count():
		var arrays := original.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var material := original.get_active_material(surface) as StandardMaterial3D
		var source := material.albedo_texture.get_image()
		if source.is_compressed():
			source.decompress()
		for index in range(0, indices.size(), 3):
			var a := indices[index]
			var b := indices[index + 1]
			var c := indices[index + 2]
			var area := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).length() * 0.5
			var at := (uv[a] + uv[b] + uv[c]) / 3
			var colour := source.get_pixel(clampi(int(at.x * source.get_width()), 0, source.get_width() - 1),
				clampi(int(at.y * source.get_height()), 0, source.get_height() - 1))
			var hex := colour.to_html(false)
			palette[hex] = float(palette.get(hex, 0)) + area
	var colours := palette.keys()
	colours.sort_custom(func(a, b): return palette[a] > palette[b])
	for index in mini(16, colours.size()):
		print("ATLAS_PALETTE ", colours[index], " area=", palette[colours[index]])
	var records: Array = []
	for path in ["CastleStairs/CastleStair", "CastleEntrance/CastleEntrance", "CastleArchitecture", "Art_Gallery/GalleryDoorRig"]:
		var root_node := hub.get_node_or_null(path)
		if root_node == null:
			continue
		for mesh: MeshInstance3D in root_node.find_children("*", "MeshInstance3D", true, false):
			if not mesh.is_visible_in_tree() or mesh.mesh == null:
				continue
			var materials: Array = []
			for index in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(index)
				materials.append({"name": material.resource_name if material else "null",
					"colour": (material as StandardMaterial3D).albedo_color.to_html(false) if material is StandardMaterial3D else "shader"})
			records.append({"node": str(mesh.get_path()), "materials": materials,
				"bounds": str(mesh.global_transform * mesh.mesh.get_aabb())})
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_unified_style")
	var file := FileAccess.open("res://artifacts/castle_unified_style/audit_nodes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	print("STYLE_AUDIT: ", records.size(), " visible route meshes")
	quit()
