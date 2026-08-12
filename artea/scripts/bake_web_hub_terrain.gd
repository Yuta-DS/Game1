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
	var mesh := _build_mesh(terrain.get("data"))
	var error := ResourceSaver.save(mesh, "res://resources/web_hub_terrain.res")
	if error != OK:
		push_error("Failed to save Web terrain mesh: %s" % error_string(error))
		quit(1)
		return
	print("Saved Web hub terrain: %d vertices" % ((GRID_CELLS + 1) * (GRID_CELLS + 1)))
	quit()


func _build_mesh(terrain_data) -> ArrayMesh:
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
			var lowland := Color(0.20, 0.42, 0.16)
			var highland := Color(0.34, 0.39, 0.27)
			var rock := Color(0.36, 0.35, 0.33)
			colors[index] = lowland.lerp(highland, clampf((height - 18.0) / 38.0, 0.0, 1.0)).lerp(rock, clampf(slope * 2.6, 0.0, 1.0))

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
