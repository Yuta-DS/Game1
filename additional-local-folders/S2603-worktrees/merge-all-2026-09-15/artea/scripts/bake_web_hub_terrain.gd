extends SceneTree

const GRID_CELLS := 512
const GRID_SPACING := 8.0
const HALF_EXTENT := GRID_CELLS * GRID_SPACING * 0.5


func _init() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var scene := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for _frame in range(12):
		await process_frame
	var terrain = scene.get_node("Environment/Terrain3D")
	var mesh := _build_mesh(terrain.get("data"), _build_palette(terrain))
	var surface_map_error := _save_surface_map(terrain.get("data"))
	if surface_map_error != OK:
		push_error("Failed to save Web terrain surface map: %s" % error_string(surface_map_error))
		quit(1)
		return
	var error := ResourceSaver.save(mesh, "res://resources/web_hub_terrain.res")
	if error != OK:
		push_error("Failed to save Web terrain mesh: %s" % error_string(error))
		quit(1)
		return
	print("Saved Web hub terrain: %d vertices" % ((GRID_CELLS + 1) * (GRID_CELLS + 1)))
	quit()


# R8 lookup used by Web audio after Terrain3D is replaced by its baked mesh.
# Values are texture IDs: 0 moss/grass, 1 sand, 2 village ground tile.
func _save_surface_map(terrain_data) -> Error:
	var side := GRID_CELLS + 1
	var image := Image.create(side, side, false, Image.FORMAT_R8)
	for z_index in side:
		for x_index in side:
			var center := Vector3(
				float(x_index) * GRID_SPACING - HALF_EXTENT, 0.0,
				float(z_index) * GRID_SPACING - HALF_EXTENT)
			var base_id: int = terrain_data.get_control_base_id(center)
			var overlay_id: int = terrain_data.get_control_overlay_id(center)
			var blend: float = terrain_data.get_control_blend(center)
			var texture_id := overlay_id if not is_nan(blend) and blend >= 0.5 else base_id
			# Store the three IDs at the centres of broad thirds. This survives Web
			# texture transcoding and filtering much more safely than raw 1/255 steps.
			image.set_pixel(x_index, z_index, Color((float(clampi(texture_id, 0, 2)) + 0.5) / 3.0, 0, 0))
	return image.save_png("res://resources/web_hub_surface_map.png")


# One flat colour per painted Terrain3D texture, taken as the average of the
# asset's own albedo. The Web ground carries no UVs, so this is what lets the
# village brick, the sand and the moss read as different surfaces instead of
# one procedural green.
func _build_palette(terrain) -> PackedColorArray:
	var palette := PackedColorArray()
	var assets = terrain.get("assets")
	if assets == null:
		push_warning("Terrain3D has no assets; falling back to height-based colour.")
		return palette
	for asset in assets.get("texture_list"):
		var averaged := Color(0.5, 0.5, 0.5)
		if asset != null and asset.albedo_texture != null:
			var img: Image = asset.albedo_texture.get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				img.resize(1, 1, Image.INTERPOLATE_LANCZOS)
				averaged = img.get_pixel(0, 0)
		print("  palette[%d] = %s (%s)" % [palette.size(), str(averaged),
			str(asset.name) if asset != null else "?"])
		palette.append(averaged)
	return palette


func _palette_color(palette: PackedColorArray, id: int) -> Color:
	if palette.is_empty():
		return Color(0.5, 0.5, 0.5)
	return palette[clampi(id, 0, palette.size() - 1)]


func _build_mesh(terrain_data, palette: PackedColorArray) -> ArrayMesh:
	var side := GRID_CELLS + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.resize(side * side)
	normals.resize(side * side)
	colors.resize(side * side)
	indices.resize(GRID_CELLS * GRID_CELLS * 6)

	for z_index in range(side):
		for x_index in range(side):
			var x := float(x_index) * GRID_SPACING - HALF_EXTENT
			var z := float(z_index) * GRID_SPACING - HALF_EXTENT
			var center := Vector3(x, 0.0, z)
			var height: float = terrain_data.get_height(center)
			if is_nan(height): height = -2.0
			var left: float = terrain_data.get_height(center - Vector3(GRID_SPACING, 0.0, 0.0))
			var right: float = terrain_data.get_height(center + Vector3(GRID_SPACING, 0.0, 0.0))
			var back: float = terrain_data.get_height(center - Vector3(0.0, 0.0, GRID_SPACING))
			var front: float = terrain_data.get_height(center + Vector3(0.0, 0.0, GRID_SPACING))
			if is_nan(left): left = height
			if is_nan(right): right = height
			if is_nan(back): back = height
			if is_nan(front): front = height
			var index := z_index * side + x_index
			vertices[index] = Vector3(x, height, z)
			var normal := Vector3(left - right, GRID_SPACING * 2.0, back - front).normalized()
			normals[index] = normal
			var slope := 1.0 - normal.y
			if palette.is_empty():
				var lowland := Color(0.20, 0.42, 0.16)
				var highland := Color(0.34, 0.39, 0.27)
				var rock := Color(0.36, 0.35, 0.33)
				colors[index] = lowland.lerp(highland, clampf((height - 18.0) / 38.0, 0.0, 1.0)).lerp(rock, clampf(slope * 2.6, 0.0, 1.0))
			else:
				# Blend the two painted textures exactly as Terrain3D does, then
				# tint by its colour map. A colour map that has never been
				# painted reads as black, which would erase everything, so an
				# unpainted texel is treated as white.
				var base_id: int = terrain_data.get_control_base_id(center)
				var overlay_id: int = terrain_data.get_control_overlay_id(center)
				var blend: float = terrain_data.get_control_blend(center)
				if is_nan(blend):
					blend = 0.0
				var ground := _palette_color(palette, base_id).lerp(
					_palette_color(palette, overlay_id), clampf(blend, 0.0, 1.0))
				var painted: Color = terrain_data.get_color(center)
				if painted.r + painted.g + painted.b > 0.01:
					ground = Color(ground.r * painted.r, ground.g * painted.g, ground.b * painted.b)
				colors[index] = ground

	var write_index := 0
	for z_index in range(GRID_CELLS):
		for x_index in range(GRID_CELLS):
			var top_left := z_index * side + x_index
			var top_right := top_left + 1
			var bottom_left := top_left + side
			var bottom_right := bottom_left + 1
			for vertex_index in [top_left, top_right, bottom_left, top_right, bottom_right, bottom_left]:
				indices[write_index] = vertex_index
				write_index += 1

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
