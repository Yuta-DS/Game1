extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for frame in 90:
		await process_frame
	var mesh := hub.get_node("building_castle_red2/building_castle_red") as MeshInstance3D
	print("CASTLE_TRANSFORM ", mesh.global_transform, " bounds ", mesh.get_aabb())
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var ids: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var material := mesh.get_active_material(surface) as StandardMaterial3D
		var picture := material.albedo_texture.get_image()
		if picture.is_compressed():
			picture.decompress()
		for index in range(0, ids.size(), 3):
			var a := vertices[ids[index]]
			var b := vertices[ids[index + 1]]
			var c := vertices[ids[index + 2]]
			var normal := -(b-a).cross(c-a).normalized()
			var area := (b-a).cross(c-a).length() * 0.5
			var at := (uv[ids[index]] + uv[ids[index+1]] + uv[ids[index+2]]) / 3
			var colour := picture.get_pixel(clampi(int(at.x * picture.get_width()), 0, picture.get_width()-1),
				clampi(int(at.y * picture.get_height()), 0, picture.get_height()-1))
			var grey := maxf(colour.r, maxf(colour.g, colour.b)) - minf(colour.r, minf(colour.g, colour.b))
			if absf(normal.y) < 0.05 and area > 0.035 and grey < 0.16 and colour.r > 0.35:
				print("STONE_FACE ", index, " centre=", (a+b+c)/3, " normal=", normal, " area=", area, " colour=", colour.to_html(false))
	quit()
