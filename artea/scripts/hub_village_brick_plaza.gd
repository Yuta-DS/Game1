extends Node3D

const PLAZA_CENTER := Vector2(90.0, -20.0)
const PLAZA_SIZE := Vector2(72.0, 150.0)
const CORNER_RADIUS := 10.0
const CELL_SIZE := 1.0
const SURFACE_LIFT := 0.055
const BRICK_SHADER := preload("res://shaders/village_brick_plaza.gdshader")
const WEB_GRID_SIDE := 513
const WEB_GRID_SPACING := 8.0
const WEB_HALF_EXTENT := 2048.0
const OVERGROWTH_TUFTS := 420
const BLADES_PER_TUFT := 3

var _terrain_data
var _web_vertices := PackedVector3Array()


func _ready() -> void:
	call_deferred("_build_plaza")


func _build_plaza() -> void:
	var terrain = get_node_or_null("../Environment/Terrain3D")
	if terrain != null and terrain.get("data") != null:
		_terrain_data = terrain.get("data")
	else:
		var web_ground := get_node_or_null(
			"../WebTerrainCompatibility/WebTerrainMesh") as MeshInstance3D
		if web_ground != null and web_ground.mesh != null:
			var arrays := web_ground.mesh.surface_get_arrays(0)
			_web_vertices = arrays[Mesh.ARRAY_VERTEX]
	if _terrain_data == null and _web_vertices.is_empty():
		push_warning("VillageBrickPlaza: no terrain height source is available")
		return
	var mesh := _create_terrain_fitted_mesh()
	if mesh.get_surface_count() == 0:
		push_warning("VillageBrickPlaza: no valid terrain cells found")
		return
	var plaza := MeshInstance3D.new()
	plaza.name = "BrickGround"
	plaza.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = BRICK_SHADER
	plaza.material_override = material
	plaza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plaza)
	_add_grass_overgrowth()


func _create_terrain_fitted_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half := PLAZA_SIZE * 0.5
	var columns := int(PLAZA_SIZE.x / CELL_SIZE)
	var rows := int(PLAZA_SIZE.y / CELL_SIZE)
	for row in rows:
		for column in columns:
			var x0 := PLAZA_CENTER.x - half.x + column * CELL_SIZE
			var z0 := PLAZA_CENTER.y - half.y + row * CELL_SIZE
			var center := Vector2(x0 + CELL_SIZE * 0.5, z0 + CELL_SIZE * 0.5)
			if not _inside_rounded_plaza(center):
				continue
			var corners := [
				Vector2(x0, z0), Vector2(x0 + CELL_SIZE, z0),
				Vector2(x0 + CELL_SIZE, z0 + CELL_SIZE), Vector2(x0, z0 + CELL_SIZE),
			]
			var heights := PackedFloat32Array()
			var valid := true
			for corner in corners:
				var height := _sample_height(corner)
				if is_nan(height):
					valid = false
					break
				heights.append(height + SURFACE_LIFT)
			if not valid:
				continue
			var first := vertices.size()
			for index in 4:
				var corner: Vector2 = corners[index]
				vertices.append(Vector3(corner.x, heights[index], corner.y))
				normals.append(Vector3.UP)
				uvs.append(Vector2(corner.x, corner.y))
			indices.append_array(PackedInt32Array([
				first, first + 1, first + 2, first, first + 2, first + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _sample_height(point: Vector2) -> float:
	if _terrain_data != null:
		return _terrain_data.get_height(Vector3(point.x, 0.0, point.y))
	var grid := (point + Vector2.ONE * WEB_HALF_EXTENT) / WEB_GRID_SPACING
	var x0 := clampi(int(floor(grid.x)), 0, WEB_GRID_SIDE - 2)
	var z0 := clampi(int(floor(grid.y)), 0, WEB_GRID_SIDE - 2)
	var blend := Vector2(clampf(grid.x - x0, 0.0, 1.0), clampf(grid.y - z0, 0.0, 1.0))
	var h00 := _web_vertices[z0 * WEB_GRID_SIDE + x0].y
	var h10 := _web_vertices[z0 * WEB_GRID_SIDE + x0 + 1].y
	var h01 := _web_vertices[(z0 + 1) * WEB_GRID_SIDE + x0].y
	var h11 := _web_vertices[(z0 + 1) * WEB_GRID_SIDE + x0 + 1].y
	return lerpf(lerpf(h00, h10, blend.x), lerpf(h01, h11, blend.x), blend.y)


func _inside_rounded_plaza(point: Vector2) -> bool:
	var half := PLAZA_SIZE * 0.5
	var local := (point - PLAZA_CENTER).abs()
	var inner := half - Vector2.ONE * CORNER_RADIUS
	var outside := Vector2(maxf(local.x - inner.x, 0.0), maxf(local.y - inner.y, 0.0))
	return outside.length_squared() <= CORNER_RADIUS * CORNER_RADIUS


func _add_grass_overgrowth() -> void:
	var blade_mesh := PrismMesh.new()
	blade_mesh.size = Vector3(0.08, 0.42, 0.05)
	var grass_material := StandardMaterial3D.new()
	grass_material.albedo_color = Color(0.17, 0.38, 0.08)
	grass_material.roughness = 0.96
	blade_mesh.material = grass_material

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade_mesh
	multimesh.instance_count = OVERGROWTH_TUFTS * BLADES_PER_TUFT
	var rng := RandomNumberGenerator.new()
	rng.seed = 746231
	var half := PLAZA_SIZE * 0.5
	var instance_index := 0
	for tuft_index in OVERGROWTH_TUFTS:
		var point := Vector2.ZERO
		for _attempt in 20:
			if tuft_index < 280:
				# Most growth follows the damp, less-travelled plaza perimeter.
				var side := tuft_index % 4
				if side < 2:
					point.x = PLAZA_CENTER.x + (-1.0 if side == 0 else 1.0) \
						* (half.x - rng.randf_range(0.45, 3.8))
					point.y = PLAZA_CENTER.y + rng.randf_range(-half.y, half.y)
				else:
					point.x = PLAZA_CENTER.x + rng.randf_range(-half.x, half.x)
					point.y = PLAZA_CENTER.y + (-1.0 if side == 2 else 1.0) \
						* (half.y - rng.randf_range(0.45, 3.8))
			else:
				# A few tufts push through old mortar cracks inside the square.
				point = PLAZA_CENTER + Vector2(
					rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
			if _inside_rounded_plaza(point):
				break
		var height := _sample_height(point) + SURFACE_LIFT
		for blade_index in BLADES_PER_TUFT:
			var offset_angle := TAU * float(blade_index) / BLADES_PER_TUFT + rng.randf_range(-0.3, 0.3)
			var offset := Vector3(cos(offset_angle), 0.0, sin(offset_angle)) * rng.randf_range(0.035, 0.11)
			var blade_scale := rng.randf_range(0.68, 1.18)
			var basis := Basis.from_euler(Vector3(
				rng.randf_range(-0.16, 0.16), rng.randf_range(0.0, TAU),
				rng.randf_range(-0.18, 0.18))).scaled(Vector3.ONE * blade_scale)
			var origin := Vector3(point.x, height + 0.21 * blade_scale, point.y) + offset
			multimesh.set_instance_transform(instance_index, Transform3D(basis, origin))
			instance_index += 1
	var grass := MultiMeshInstance3D.new()
	grass.name = "GrassOvergrowth"
	grass.multimesh = multimesh
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)
