extends Node

# Continuous real-time object generation for artwork worlds.
#
# The manifest reconciler (realtime_world_generator.gd) builds the *authored*
# subjects the player painted. This loop builds everything in between: the
# grass, ferns, stones, drifting petals and small wildlife that make a world
# feel inhabited instead of like a handful of props on a plane.
#
# Algorithm — deterministic ring streaming:
#
#   1. The world is divided into fixed-size cells. Each cell has a stable seed
#      derived from (world_seed, cell_x, cell_z), so a cell always regenerates
#      with identical contents no matter how many times the player walks away
#      from it and returns. Nothing is stored to disk and nothing drifts.
#   2. Every tick, the cells inside `spawn_radius` of the player are collected
#      in nearest-first order and pushed into a work queue; cells beyond
#      `despawn_radius` release their instances back to a pool.
#   3. The queue is drained under a per-frame microsecond budget, so a dense
#      world spreads its construction over several frames and never stalls the
#      main thread.
#   4. Inside a cell, candidate points are placed with a Poisson-disc style
#      rejection sample against a minimum spacing, then filtered by terrain
#      slope, altitude and distance to the authored manifest actors. Surviving
#      points pick a species by weighted roulette over the world's biome
#      profile, which is itself derived from the player's palette.
#
# The result is an unbounded, always-populated world that costs a bounded
# number of live nodes.

signal cell_populated(cell: Vector2i, instances: int)
signal cell_released(cell: Vector2i)

const CELL_SIZE := 8.0
const POISSON_ATTEMPTS := 40

@export var spawn_radius := 34.0
@export var despawn_radius := 44.0
@export var frame_budget_usec := 2600
@export var max_cells_per_tick := 3
@export var density := 1.0
@export var tick_interval := 0.18

var world_seed := 0

var _tracked: Node3D
var _container: Node3D
var _terrain: RefCounted
var _palette: Array[Color] = []
var _species: Array[Dictionary] = []
var _live_cells: Dictionary = {}
var _queue: Array[Vector2i] = []
var _queued_lookup: Dictionary = {}
var _pool: Dictionary = {}
var _mask_cache: Dictionary = {}
var _reserved: Array[Dictionary] = []
var _bounds := Rect2(-18.0, -14.0, 36.0, 28.0)
var _tick_accumulator := 0.0
var _live_instance_count := 0
var _pool_ceiling := 48


func _ready() -> void:
	set_process(false)


# Pooled nodes are deliberately parentless while they wait for reuse, so the
# scene tree cannot free them for us when the world closes.
func _exit_tree() -> void:
	for kind in _pool:
		for instance in _pool[kind]:
			if is_instance_valid(instance) and instance.get_parent() == null:
				instance.queue_free()
	_pool.clear()


# `terrain` may be null; the loop then treats the world as flat at y = 0.
func configure(tracked: Node3D, container: Node3D, terrain: RefCounted,
		palette: Array[Color], bounds: Rect2) -> void:
	_tracked = tracked
	_container = container
	_terrain = terrain
	_palette = palette.duplicate()
	_bounds = bounds
	_species = _build_biome_profile(palette)
	if world_seed == 0:
		world_seed = abs(str(bounds, palette.size()).hash())
	set_process(_tracked != null and _container != null)


# Authored manifest actors reserve space so ambient scatter never grows through
# the middle of the house the player painted.
func set_reserved_areas(areas: Array[Dictionary]) -> void:
	_reserved = areas.duplicate(true)


func live_instance_count() -> int:
	return _live_instance_count


func live_cell_count() -> int:
	return _live_cells.size()


func pending_cell_count() -> int:
	return _queue.size()


func species_count() -> int:
	return _species.size()


# Runs one full streaming tick immediately. Used by headless tests and by the
# world's first frame so the player never spawns into an empty field.
func force_tick(budget_usec: int = 40000) -> void:
	_refresh_queue()
	_drain_queue(budget_usec, _queue.size())


func _process(delta: float) -> void:
	if _tracked == null or not is_instance_valid(_tracked):
		return
	_tick_accumulator += delta
	if _tick_accumulator < tick_interval:
		# Still drain a little between refreshes so a large backlog keeps
		# resolving smoothly instead of in visible bursts.
		_drain_queue(frame_budget_usec, max_cells_per_tick)
		return
	_tick_accumulator = 0.0
	_refresh_queue()
	_drain_queue(frame_budget_usec, max_cells_per_tick)


func _refresh_queue() -> void:
	var origin := _tracked.global_position
	var centre := Vector2i(
		int(floorf(origin.x / CELL_SIZE)),
		int(floorf(origin.z / CELL_SIZE)))
	var ring := int(ceilf(spawn_radius / CELL_SIZE))
	var wanted: Array[Vector2i] = []

	for dz in range(-ring, ring + 1):
		for dx in range(-ring, ring + 1):
			var cell := Vector2i(centre.x + dx, centre.y + dz)
			var cell_centre := _cell_centre(cell)
			if Vector2(cell_centre.x, cell_centre.z).distance_to(
					Vector2(origin.x, origin.z)) > spawn_radius:
				continue
			if not _cell_overlaps_bounds(cell):
				continue
			if _live_cells.has(cell) or _queued_lookup.has(cell):
				continue
			wanted.append(cell)

	# Nearest cells first: what the player is walking into matters more than
	# what is at the edge of the draw distance.
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _cell_centre(a).distance_squared_to(origin) \
			< _cell_centre(b).distance_squared_to(origin))
	for cell in wanted:
		_queue.append(cell)
		_queued_lookup[cell] = true

	for cell in _live_cells.keys():
		if _cell_centre(cell).distance_to(origin) > despawn_radius:
			_release_cell(cell)


func _drain_queue(budget_usec: int, max_cells: int) -> void:
	if _queue.is_empty():
		return
	var deadline := Time.get_ticks_usec() + budget_usec
	var processed := 0
	while not _queue.is_empty() and processed < max_cells \
			and Time.get_ticks_usec() <= deadline:
		var cell: Vector2i = _queue.pop_front()
		_queued_lookup.erase(cell)
		_populate_cell(cell)
		processed += 1


func _populate_cell(cell: Vector2i) -> void:
	if _live_cells.has(cell):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _cell_seed(cell)
	var origin := _cell_origin(cell)
	var placed: Array[Node3D] = []
	var accepted: Array[Vector2] = []
	var target := int(round(rng.randf_range(5.0, 9.0) * clampf(density, 0.0, 4.0)))

	for _attempt in POISSON_ATTEMPTS:
		if placed.size() >= target:
			break
		var point := Vector2(
			origin.x + rng.randf() * CELL_SIZE,
			origin.z + rng.randf() * CELL_SIZE)
		var species := _pick_species(rng)
		if species.is_empty():
			break
		var spacing := float(species.get("spacing", 1.6))
		if not _spacing_is_free(point, spacing, accepted):
			continue
		if not _point_is_placeable(point, species):
			continue
		var instance := _instantiate_species(species, point, rng)
		if instance == null:
			continue
		accepted.append(point)
		placed.append(instance)

	_live_cells[cell] = placed
	_live_instance_count += placed.size()
	cell_populated.emit(cell, placed.size())


func _spacing_is_free(point: Vector2, spacing: float, accepted: Array[Vector2]) -> bool:
	for existing in accepted:
		if existing.distance_to(point) < spacing:
			return false
	return true


func _point_is_placeable(point: Vector2, species: Dictionary) -> bool:
	if not _bounds.has_point(point):
		return false
	for area in _reserved:
		var centre = area.get("centre", Vector2.ZERO)
		if centre is Vector2 and centre.distance_to(point) < float(area.get("radius", 0.0)) \
				+ float(species.get("clearance", 0.9)):
			return false
	if _terrain == null:
		return true
	var slope: float = _terrain.slope_at(point.x, point.y)
	if slope > float(species.get("max_slope", 0.55)):
		return false
	var height: float = _terrain.height_at(point.x, point.y)
	if height < float(species.get("min_height", -1.0)):
		return false
	return true


func _instantiate_species(species: Dictionary, point: Vector2,
		rng: RandomNumberGenerator) -> Node3D:
	var kind := str(species.get("kind", "grass"))
	var instance := _acquire(kind, species)
	if instance == null:
		return null
	var y: float = 0.0 if _terrain == null else _terrain.height_at(point.x, point.y)
	instance.position = Vector3(point.x, y + float(species.get("y_offset", 0.0)), point.y)
	instance.rotation = Vector3(0.0, rng.randf() * TAU, 0.0)
	var jitter := rng.randf_range(0.82, 1.28) * float(species.get("scale", 1.0))
	instance.scale = Vector3.ONE * jitter
	if bool(species.get("align_to_ground", false)) and _terrain != null:
		var normal: Vector3 = _terrain.normal_at(point.x, point.y)
		instance.rotation.x = -atan2(normal.z, normal.y) * 0.6
		instance.rotation.z = atan2(normal.x, normal.y) * 0.6
	instance.set_meta("ambient_kind", kind)
	instance.visible = true
	if instance.get_parent() == null:
		_container.add_child(instance)
	return instance


func _release_cell(cell: Vector2i) -> void:
	var placed = _live_cells.get(cell, [])
	if placed is Array:
		for instance in placed:
			if is_instance_valid(instance):
				_recycle(instance)
		_live_instance_count = maxi(0, _live_instance_count - placed.size())
	_live_cells.erase(cell)
	cell_released.emit(cell)


func _acquire(kind: String, species: Dictionary) -> Node3D:
	var bucket: Array = _pool.get(kind, [])
	while not bucket.is_empty():
		var recycled = bucket.pop_back()
		if is_instance_valid(recycled):
			return recycled
	return _build_species_node(species)


func _recycle(instance: Node3D) -> void:
	var kind := str(instance.get_meta("ambient_kind", "grass"))
	var bucket: Array = _pool.get(kind, [])
	if bucket.size() >= _pool_ceiling:
		instance.queue_free()
		return
	instance.visible = false
	# Parked far below the terrain so a pooled node can never be seen or hit
	# while it waits for reuse.
	instance.position = Vector3(0.0, -400.0, 0.0)
	bucket.append(instance)
	_pool[kind] = bucket


func _build_species_node(species: Dictionary) -> Node3D:
	var asset := str(species.get("asset", ""))
	if not asset.is_empty() and ResourceLoader.exists(asset):
		var packed = load(asset)
		if packed is PackedScene:
			var model := packed.instantiate() as Node3D
			if model != null:
				return model
	return _procedural_node(species)


# Procedural fallbacks keep the world dressed even when a curated asset is
# missing from the project, and they cost far less than an imported mesh.
func _procedural_node(species: Dictionary) -> Node3D:
	var root := Node3D.new()
	var visual := MeshInstance3D.new()
	visual.name = "AmbientVisual"
	var shape := str(species.get("shape", "blade"))
	var colour: Color = species.get("colour", Color("74a559"))
	var mesh: Mesh
	match shape:
		"blade":
			# Two crossed alpha quads read as a soft grass tuft from any angle;
			# a solid prism reads as a spike stuck in the ground.
			mesh = _crossed_quad_mesh(0.38, 0.34)
		"frond":
			mesh = _crossed_quad_mesh(0.72, 0.62)
		"stone":
			var stone := SphereMesh.new()
			stone.radius = 0.32
			stone.height = 0.44
			stone.radial_segments = 7
			stone.rings = 4
			mesh = stone
		"petal":
			var petal := SphereMesh.new()
			petal.radius = 0.11
			petal.height = 0.18
			petal.radial_segments = 6
			petal.rings = 3
			mesh = petal
		_:
			var fallback := BoxMesh.new()
			fallback.size = Vector3(0.3, 0.5, 0.3)
			mesh = fallback
	visual.mesh = mesh
	# The crossed-quad tuft is authored with its origin at the base already;
	# primitive meshes are centred, so only those need lifting onto the ground.
	if mesh is PrimitiveMesh:
		visual.position.y = mesh.get_aabb().size.y * 0.5
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	if bool(species.get("glowing", false)):
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = 1.4
	if shape in ["blade", "frond"]:
		# A crossed quad without an alpha mask is just a cardboard slab. The
		# generated blade mask is what turns it into readable foliage.
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_texture = _foliage_mask(shape)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
	elif shape == "petal":
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material
	root.add_child(visual)
	return root


# Procedural alpha masks so the world needs no foliage art to ship. Each mask
# is built once and shared by every instance of that shape.
func _foliage_mask(shape: String) -> Texture2D:
	if _mask_cache.has(shape):
		return _mask_cache[shape]
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(shape.hash())
	var blades := 7 if shape == "blade" else 11
	for _blade in blades:
		var base_x := rng.randf_range(0.08, 0.92)
		var tip_x := base_x + rng.randf_range(-0.28, 0.28)
		var top := rng.randf_range(0.12, 0.55) if shape == "blade" else rng.randf_range(0.3, 0.7)
		var thickness := rng.randf_range(0.022, 0.05)
		for y in range(int(top * size), size):
			var t := float(y - int(top * size)) / maxf(1.0, float(size) - top * float(size))
			# Wide at the root, tapering to the tip, so the silhouette reads as
			# a growing blade rather than a rectangle.
			var centre := lerpf(tip_x, base_x, t)
			var half := thickness * (0.35 + t * 0.65) * float(size)
			for x in range(int((centre * float(size)) - half),
					int((centre * float(size)) + half) + 1):
				if x >= 0 and x < size:
					image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
	var texture := ImageTexture.create_from_image(image)
	_mask_cache[shape] = texture
	return texture


# Two intersecting vertical quads, the standard cheap billboard-free way to
# fake foliage volume. Vertex colour darkens the base so the tuft reads as
# rooted in the ground instead of hovering over it.
func _crossed_quad_mesh(width: float, height: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var half := width * 0.5

	for quad in 2:
		var axis := Vector3(half, 0.0, 0.0) if quad == 0 else Vector3(0.0, 0.0, half)
		var normal := Vector3(0.0, 0.0, 1.0) if quad == 0 else Vector3(1.0, 0.0, 0.0)
		var base := quad * 4
		vertices.append_array([
			-axis, axis,
			axis + Vector3(0.0, height, 0.0), -axis + Vector3(0.0, height, 0.0)])
		for _i in 4:
			normals.append(normal)
		uvs.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		colours.append_array([
			Color(0.62, 0.62, 0.62), Color(0.62, 0.62, 0.62),
			Color.WHITE, Color.WHITE])
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

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


# The palette the player painted with decides what grows here, so a warm sunset
# picture and a cold sea picture do not share the same undergrowth.
func _build_biome_profile(palette: Array[Color]) -> Array[Dictionary]:
	var accent := palette[1] if palette.size() > 1 else Color("ffd166")
	var highlight := palette[3] if palette.size() > 3 else Color("ff99c8")
	# Plants stay recognisably plant-coloured. The palette only tints them, so a
	# violet-heavy painting grows violet-tinged grass rather than violet spikes.
	var painted := palette[2] if palette.size() > 2 else Color("7bb661")
	# Borrow only the painting's hue *shift*, never its raw value. A palette
	# entry of pure blue would otherwise grow teal spikes instead of grass.
	var ground := Color("6f9e4e").lerp(
		Color(painted.r, painted.g, painted.b), 0.16)
	var warmth := clampf(painted.r - painted.b, -0.5, 0.5)

	var profile: Array[Dictionary] = [
		{
			"kind": "grass_tuft",
			"shape": "blade",
			"colour": ground.lerp(Color("8fbf6a"), 0.35),
			"weight": 5.0,
			"spacing": 0.75,
			"scale": 1.0,
			"clearance": 0.5,
			"max_slope": 0.5,
			"align_to_ground": true,
		},
		{
			"kind": "fern",
			"shape": "frond",
			"colour": ground.darkened(0.18),
			"weight": 2.4,
			"spacing": 1.5,
			"scale": 1.15,
			"clearance": 0.9,
			"max_slope": 0.42,
			"align_to_ground": true,
		},
		{
			"kind": "field_stone",
			"shape": "stone",
			"colour": Color("9a9384").lerp(ground, 0.3),
			"weight": 1.6,
			"spacing": 2.1,
			"scale": 1.0,
			"clearance": 1.2,
			"max_slope": 0.8,
			"align_to_ground": true,
		},
		{
			"kind": "bloom",
			"shape": "petal",
			"colour": highlight,
			"weight": 1.9,
			"spacing": 1.1,
			"scale": 1.0,
			"clearance": 0.6,
			"max_slope": 0.4,
			"y_offset": 0.35,
		},
		{
			"kind": "spark",
			"shape": "petal",
			"colour": accent,
			"weight": 0.7,
			"spacing": 3.6,
			"scale": 0.45,
			"clearance": 0.4,
			"max_slope": 1.0,
			"y_offset": 1.9,
			"glowing": true,
		},
	]
	# Warm palettes push toward blooms and sparks; cool ones toward ferns and
	# stone, which is what makes two different paintings feel like two places.
	for species in profile:
		if species["kind"] in ["bloom", "spark"]:
			species["weight"] = maxf(0.2, float(species["weight"]) * (1.0 + warmth))
		elif species["kind"] in ["fern", "field_stone"]:
			species["weight"] = maxf(0.2, float(species["weight"]) * (1.0 - warmth * 0.6))
	return profile


func _pick_species(rng: RandomNumberGenerator) -> Dictionary:
	if _species.is_empty():
		return {}
	var total := 0.0
	for species in _species:
		total += float(species.get("weight", 1.0))
	if total <= 0.0:
		return _species[0]
	var roll := rng.randf() * total
	for species in _species:
		roll -= float(species.get("weight", 1.0))
		if roll <= 0.0:
			return species
	return _species[_species.size() - 1]


func _cell_origin(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) * CELL_SIZE, 0.0, float(cell.y) * CELL_SIZE)


func _cell_centre(cell: Vector2i) -> Vector3:
	return _cell_origin(cell) + Vector3(CELL_SIZE * 0.5, 0.0, CELL_SIZE * 0.5)


func _cell_overlaps_bounds(cell: Vector2i) -> bool:
	var origin := _cell_origin(cell)
	return _bounds.intersects(Rect2(origin.x, origin.z, CELL_SIZE, CELL_SIZE))


func _cell_seed(cell: Vector2i) -> int:
	# Hashing the coordinates with the world seed keeps regeneration stable and
	# independent of visit order.
	return abs(hash(Vector3i(cell.x, cell.y, world_seed)))
