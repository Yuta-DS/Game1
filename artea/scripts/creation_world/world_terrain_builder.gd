extends RefCounted

# Builds the physical ground of an artwork world.
#
# The old world stood on a flat box, which read as a prototype the moment the
# player walked more than a few metres. Here the terrain is sculpted from the
# player's own painting: image luminance drives elevation, so bright skies stay
# low and open while dense painted masses rise into hills. The mesh carries
# vertex colours sampled from the same image, which means the ground itself is
# recognisably made of the artwork rather than a flat tinted slab.
#
# Everything is generated once into a real ArrayMesh with a matching
# HeightMapShape3D collider, so walking, jumping and the frame-budgeted ambient
# spawner all agree on where the ground is.

const SEA_LEVEL := 0.0

var width: float
var depth: float
var resolution: int
var _heights: PackedFloat32Array = PackedFloat32Array()
var _cells_x: int
var _cells_z: int
var _max_height := 0.0


func _init(world_width: float, world_depth: float, grid_resolution: int = 64) -> void:
	width = world_width
	depth = world_depth
	resolution = clampi(grid_resolution, 16, 160)
	_cells_x = resolution
	_cells_z = resolution


# Samples the artwork into a height field. `relief` scales the tallest hill.
func sculpt(source: Image, palette: Array[Color], relief: float = 3.4) -> void:
	var samples := PackedFloat32Array()
	samples.resize((_cells_x + 1) * (_cells_z + 1))
	var image := _prepared_image(source)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.055
	noise.seed = _stable_seed(image, palette)

	for z in _cells_z + 1:
		for x in _cells_x + 1:
			var u := float(x) / float(_cells_x)
			var v := float(z) / float(_cells_z)
			var painted := 0.5
			if image != null:
				var pixel := image.get_pixel(
					clampi(int(u * float(image.get_width() - 1)), 0, image.get_width() - 1),
					clampi(int(v * float(image.get_height() - 1)), 0, image.get_height() - 1))
				# Dark, saturated paint reads as ground mass; pale washes read as air.
				painted = clampf(1.0 - pixel.get_luminance(), 0.0, 1.0)
			var organic := noise.get_noise_2d(float(x), float(z)) * 0.5 + 0.5
			samples[z * (_cells_x + 1) + x] = painted * 0.68 + organic * 0.32

	# A pale wash and a dark impasto painting must both yield walkable hills, so
	# the blended field is stretched across its own observed range before it is
	# given physical height. Without this a light artwork sculpts a flat slab.
	_normalize(samples)
	for z in _cells_z + 1:
		for x in _cells_x + 1:
			var index := z * (_cells_x + 1) + x
			# A soft rim keeps the playfield readable and stops the player from
			# walking off a visible edge into empty space.
			samples[index] *= relief * _rim_falloff(
				float(x) / float(_cells_x), float(z) / float(_cells_z))

	_heights = _smoothed(samples)
	_max_height = 0.0
	for value in _heights:
		_max_height = maxf(_max_height, value)


func height_at(world_x: float, world_z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var u := clampf((world_x + width * 0.5) / width, 0.0, 1.0) * float(_cells_x)
	var v := clampf((world_z + depth * 0.5) / depth, 0.0, 1.0) * float(_cells_z)
	var x0 := clampi(int(u), 0, _cells_x - 1)
	var z0 := clampi(int(v), 0, _cells_z - 1)
	var tx := u - float(x0)
	var tz := v - float(z0)
	var h00 := _sample(x0, z0)
	var h10 := _sample(x0 + 1, z0)
	var h01 := _sample(x0, z0 + 1)
	var h11 := _sample(x0 + 1, z0 + 1)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func normal_at(world_x: float, world_z: float) -> Vector3:
	var step := maxf(width, depth) / float(resolution)
	var dx := height_at(world_x + step, world_z) - height_at(world_x - step, world_z)
	var dz := height_at(world_x, world_z + step) - height_at(world_x, world_z - step)
	return Vector3(-dx, 2.0 * step, -dz).normalized()


func max_height() -> float:
	return _max_height


func water_level() -> float:
	return _low_percentile_height() + 0.10


# Slope in the 0..1 range, where 0 is dead flat. Used by the ambient spawner to
# keep props off cliff faces.
func slope_at(world_x: float, world_z: float) -> float:
	return clampf(1.0 - normal_at(world_x, world_z).dot(Vector3.UP), 0.0, 1.0)


func build_ground(palette: Array[Color], source: Image) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "ArtworkTerrain"
	body.collision_layer = 1
	body.collision_mask = 0

	var visual := MeshInstance3D.new()
	visual.name = "TerrainSurface"
	visual.mesh = _build_mesh(palette, source)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.86
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	visual.material_override = material
	body.add_child(visual)

	var collision := CollisionShape3D.new()
	collision.name = "TerrainCollision"
	collision.shape = _build_collision_shape()
	# HeightMapShape3D spans map_width/map_depth units centred on its origin, so
	# it is scaled onto the visual grid rather than resampled.
	collision.scale = Vector3(width / float(_cells_x), 1.0, depth / float(_cells_z))
	body.add_child(collision)
	return body


# A translucent plane at sea level so low painted basins read as water rather
# than as holes in the ground.
func build_water(palette: Array[Color]) -> MeshInstance3D:
	var water := MeshInstance3D.new()
	water.name = "ArtworkWater"
	var mesh := PlaneMesh.new()
	# Inset rather than oversized: a plane wider than the terrain reads as an
	# opaque wall of sea floating past the edge of the world.
	mesh.size = Vector2(width - 2.0, depth - 2.0)
	mesh.subdivide_width = 24
	mesh.subdivide_depth = 24
	water.mesh = mesh
	# Sit just above the lowest ground so basins fill but the plain does not
	# flood. A fixed sea level drowned or floated depending on the artwork.
	water.position.y = water_level()
	# The palette only tints the water. A raw palette entry can be fully
	# saturated primary blue, which reads as painted plastic rather than water.
	var painted := palette[0] if not palette.is_empty() else Color("6fb7d8")
	var tint := Color("6fb7d8").lerp(Color(painted.r, painted.g, painted.b), 0.4)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(tint.r, tint.g, tint.b, 0.42)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.08
	material.metallic = 0.25
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return water


# The 12th-percentile height: low enough to be a basin, high enough that a
# single stray dip does not set the waterline for the whole world.
func _low_percentile_height() -> float:
	if _heights.is_empty():
		return SEA_LEVEL
	var sorted := Array(_heights)
	sorted.sort()
	return float(sorted[clampi(int(float(sorted.size()) * 0.12), 0, sorted.size() - 1)])


func _build_mesh(palette: Array[Color], source: Image) -> ArrayMesh:
	var image := _prepared_image(source)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var row_size := _cells_x + 1

	for z in _cells_z + 1:
		for x in row_size:
			var u := float(x) / float(_cells_x)
			var v := float(z) / float(_cells_z)
			var position := Vector3(
				lerpf(-width * 0.5, width * 0.5, u),
				_sample(x, z),
				lerpf(-depth * 0.5, depth * 0.5, v))
			vertices.append(position)
			normals.append(normal_at(position.x, position.z))
			uvs.append(Vector2(u, v))
			colours.append(_ground_colour(image, palette, u, v, position.y))

	for z in _cells_z:
		for x in _cells_x:
			var top_left := z * row_size + x
			var top_right := top_left + 1
			var bottom_left := top_left + row_size
			var bottom_right := bottom_left + 1
			indices.append_array([top_left, bottom_left, top_right])
			indices.append_array([top_right, bottom_left, bottom_right])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_collision_shape() -> HeightMapShape3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = _cells_x + 1
	shape.map_depth = _cells_z + 1
	shape.map_data = _heights
	return shape


func _ground_colour(image: Image, palette: Array[Color], u: float, v: float,
		elevation: float) -> Color:
	var base := palette[2] if palette.size() > 2 else Color("7bb661")
	if image != null:
		var painted := image.get_pixel(
			clampi(int(u * float(image.get_width() - 1)), 0, image.get_width() - 1),
			clampi(int(v * float(image.get_height() - 1)), 0, image.get_height() - 1))
		# Keep the painting's hue but push it toward a walkable ground value so
		# the terrain never turns into a glaring flat copy of the picture.
		base = base.lerp(Color(painted.r, painted.g, painted.b), 0.62)
	var altitude := 0.0 if _max_height <= 0.001 else clampf(elevation / _max_height, 0.0, 1.0)
	var peak := palette[1] if palette.size() > 1 else Color("f6e7c1")
	return base.lerp(peak, altitude * 0.42).darkened(0.06)


func _rim_falloff(u: float, v: float) -> float:
	var edge := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
	return clampf(smoothstep(0.0, 0.14, edge), 0.05, 1.0)


# Stretches the field to fill 0..1. A nearly uniform painting would otherwise
# divide by ~0, so a flat input is left flat rather than amplified into noise.
func _normalize(samples: PackedFloat32Array) -> void:
	var lowest := INF
	var highest := -INF
	for value in samples:
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	var span := highest - lowest
	if span < 0.0001:
		return
	for index in samples.size():
		samples[index] = (samples[index] - lowest) / span


func _smoothed(samples: PackedFloat32Array) -> PackedFloat32Array:
	var output := samples.duplicate()
	var row_size := _cells_x + 1
	for z in range(1, _cells_z):
		for x in range(1, _cells_x):
			var total := 0.0
			for dz in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					total += samples[(z + dz) * row_size + (x + dx)]
			output[z * row_size + x] = total / 9.0
	return output


func _sample(x: int, z: int) -> float:
	if _heights.is_empty():
		return 0.0
	var cx := clampi(x, 0, _cells_x)
	var cz := clampi(z, 0, _cells_z)
	return _heights[cz * (_cells_x + 1) + cx]


func _prepared_image(source: Image) -> Image:
	if source == null or source.is_empty():
		return null
	var copy := source.duplicate() as Image
	if copy.is_compressed():
		if copy.decompress() != OK:
			return null
	copy.convert(Image.FORMAT_RGBA8)
	# A small working copy keeps sculpting cheap regardless of canvas size.
	copy.resize(128, 128, Image.INTERPOLATE_BILINEAR)
	return copy


func _stable_seed(image: Image, palette: Array[Color]) -> int:
	var key := "artea-terrain"
	if image != null:
		key += str(image.get_width(), "x", image.get_height())
		key += str(image.get_pixel(0, 0), image.get_pixel(
			image.get_width() - 1, image.get_height() - 1))
	for colour in palette:
		key += colour.to_html(false)
	return abs(key.hash())
