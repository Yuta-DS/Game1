# Islands 2-4 — Mind Spark, Heart Melody, Creator's Light.
#
# Mirrors isle_castle.gd's structure and conventions, but this script builds
# THREE islands instead of one, because it is attached to "Isles2", a single
# staging node under the world root, not to an Isle_* node itself.
#
# Per-island approach: state_targets() must be callable ON THE Isle_* NODE
# itself (rail_network.gd and isle_state.gd both do
# `world.find_child("Isle_%s" % isle_id, ...)` then call methods/read meta
# straight off the result). A single script cannot expose three different
# state_targets() results depending on which node asks, so each Isle_* node
# gets its OWN tiny script instance: three inner classes (_MindIsle,
# _HeartIsle, _CreatorIsle), each `extends Node3D` and each implementing its
# own state_targets(). They are declared once at the bottom of this file and
# instantiated here in _ready(). This keeps everything in the one file this
# agent owns (CONTRACT.md's one-file-per-agent rule) while still giving
# rail_network/isle_state a real per-node method to call, exactly like
# isle_castle.gd gives Isle_castle its own state_targets().
extends Node3D

const ISLES := {
	"mind":    { "pos": Vector3(-95, 12, -60), "radius": 20.0 },
	"heart":   { "pos": Vector3(105, -6, -40), "radius": 20.0 },
	"creator": { "pos": Vector3(15, 8, 115),   "radius": 20.0 },
}

# Dormant/vibrant palette, duplicated from CONTRACT.md so this file has no
# hard load-order dependency on sky_isles_world.gd existing yet — same
# reasoning isle_castle.gd documents for its own copy.
const DORMANT := {
	"mind": Color(0.34, 0.38, 0.52),
	"heart": Color(0.50, 0.38, 0.44),
	"creator": Color(0.50, 0.45, 0.34),
}

# Shared structural tones, independent of each island's rock-body palette —
# buildings sit ON the island, they aren't tinted the same as the ground.
const STONE_LIGHT := Color(0.62, 0.60, 0.66)
const STONE_DARK := Color(0.42, 0.40, 0.48)
const GLASS_TINT := Color(0.75, 0.85, 0.95)
const WOOD_TONE := Color(0.55, 0.42, 0.32)
const WATER_TONE := Color(0.55, 0.75, 0.80)


func _ready() -> void:
	var mind := _MindIsle.new()
	add_child(mind)

	var heart := _HeartIsle.new()
	add_child(heart)

	var creator := _CreatorIsle.new()
	add_child(creator)


# --- Isle_mind: Mind Spark — blue/lavender, crystalline cliffs, towers -----

class _MindIsle:
	extends Node3D

	const ISLE_ID := "mind"
	const ISLE_POS := Vector3(-95, 12, -60)
	const ISLE_RADIUS := 20.0
	const DORMANT_COLOR := Color(0.34, 0.38, 0.52)

	var _materials: Array[StandardMaterial3D] = []
	var _emissives: Array[StandardMaterial3D] = []
	var _lights: Array[Light3D] = []
	var _particles: Array[GPUParticles3D] = []

	func _ready() -> void:
		name = "Isle_mind"

		set_meta("isle_id", ISLE_ID)
		set_meta("bob_phase", 1.9)

		var island_root := Node3D.new()
		island_root.name = "IslandBody"
		add_child(island_root)
		island_root.position = ISLE_POS

		_build_island_body(island_root)
		_build_towers(island_root)
		_build_crystals(island_root)
		_build_platform(island_root)

		# Platform sits on the castle-facing edge. Castle is at the world
		# origin, so "facing the castle" from this island's position is the
		# direction back toward Vector3.ZERO.
		var to_castle: Vector3 = (Vector3.ZERO - ISLE_POS).normalized()
		var platform_world: Vector3 = ISLE_POS + to_castle * (ISLE_RADIUS - 3.0) + Vector3(0.0, 2.0, 0.0)
		set_meta("platform_pos", platform_world)
		set_meta("camera_anchor", ISLE_POS + to_castle * (ISLE_RADIUS + 14.0) + Vector3(0.0, 12.0, 0.0))
		set_meta("look_target", ISLE_POS + Vector3(0.0, 8.0, 0.0))

	# The rock the towers stand on, built via the shared IsleBuilder helper
	# every island in this world uses — keeps all four islands feeling like
	# the same place instead of four different art directions.
	func _build_island_body(parent: Node3D) -> void:
		# load(), not the IsleBuilder global class name: inner classes in
		# this file parse before class_name resolution is guaranteed to be
		# available, same reasoning isle_castle.gd documents for its own
		# copy of this call.
		var builder: GDScript = load("res://scripts/sky_isles/isle_builder.gd")
		var body: Node3D = builder.build_island(ISLE_RADIUS, DORMANT_COLOR, 1, 1)
		parent.add_child(body)
		var mat: StandardMaterial3D = _find_first_material(body)
		if mat != null:
			_materials.append(mat)

	func _find_first_material(node: Node) -> StandardMaterial3D:
		if node is MeshInstance3D and node.material_override is StandardMaterial3D:
			return node.material_override
		for child in node.get_children():
			var found: StandardMaterial3D = _find_first_material(child)
			if found != null:
				return found
		return null

	# A few tall thin tower shapes reading as an observatory/library
	# silhouette: stacked cylinder shafts topped with cone caps, mismatched
	# heights so the cluster reads as a skyline, not one repeated prop.
	func _build_towers(parent: Node3D) -> void:
		var towers := Node3D.new()
		towers.name = "Towers"
		parent.add_child(towers)
		towers.position.y = 4.0

		var stone := _mat(STONE_LIGHT)
		_materials.append(stone)

		var specs := [
			{"pos": Vector3(-3.0, 0.0, -2.0), "h": 22.0, "r": 1.8},
			{"pos": Vector3(4.0, 0.0, 1.0), "h": 16.0, "r": 1.4},
			{"pos": Vector3(0.5, 0.0, 5.0), "h": 12.0, "r": 1.2},
		]
		for i in specs.size():
			var spec: Dictionary = specs[i]
			var pos: Vector3 = spec["pos"]
			var h: float = spec["h"]
			var r: float = spec["r"]

			var shaft := MeshInstance3D.new()
			var shaft_mesh := CylinderMesh.new()
			shaft_mesh.top_radius = r * 0.8
			shaft_mesh.bottom_radius = r
			shaft_mesh.height = h
			shaft_mesh.radial_segments = 8
			shaft.mesh = shaft_mesh
			shaft.material_override = stone
			shaft.position = pos + Vector3(0.0, h * 0.5, 0.0)
			towers.add_child(shaft)

			# Observatory-dome cap: a cone reading as a peaked roof from a
			# distance, cheap enough not to need a real dome mesh.
			var cap := MeshInstance3D.new()
			var cap_mesh := CylinderMesh.new()
			cap_mesh.top_radius = 0.0
			cap_mesh.bottom_radius = r * 1.1
			cap_mesh.height = r * 2.6
			cap_mesh.radial_segments = 8
			cap.mesh = cap_mesh
			cap.material_override = _crystal_mat(i)
			cap.position = pos + Vector3(0.0, h + r * 1.3, 0.0)
			towers.add_child(cap)

			# One soft light per tower top, dormant-dim, matching the
			# crystalline blue theme. isle_state.gd scales energy on swap.
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(0.55, 0.65, 1.0)
			lamp.light_energy = 0.12
			lamp.omni_range = 6.0
			lamp.shadow_enabled = false
			lamp.position = pos + Vector3(0.0, h + r * 1.3, 0.0)
			towers.add_child(lamp)
			_lights.append(lamp)

	# Crystal material factory — each call makes a fresh emissive material
	# (index kept for signature symmetry with callers) so isle_state.gd can
	# tint tower caps and cliff shards independently if it ever wants to.
	func _crystal_mat(_i: int) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.45, 0.55, 0.95)
		m.roughness = 0.15
		m.metallic = 0.2
		m.emission_enabled = true
		m.emission = Color(0.5, 0.65, 1.0)
		m.emission_energy_multiplier = 0.0  # dormant: off
		_emissives.append(m)
		return m

	# Crystalline cliff detail: angular low-poly shards (PrismMesh spikes)
	# scattered around the island rim to sell "crystal formation" without
	# needing a custom crystal mesh.
	func _build_crystals(parent: Node3D) -> void:
		var cluster := Node3D.new()
		cluster.name = "Crystals"
		parent.add_child(cluster)

		var rng := RandomNumberGenerator.new()
		rng.seed = 7

		var count := 10
		for i in count:
			var shard := MeshInstance3D.new()
			var mesh := PrismMesh.new()
			var h: float = rng.randf_range(2.0, 5.5)
			mesh.size = Vector3(h * 0.4, h, h * 0.4)
			shard.mesh = mesh
			shard.material_override = _crystal_mat(i)

			var angle: float = rng.randf_range(0.0, TAU)
			var dist: float = rng.randf_range(ISLE_RADIUS * 0.55, ISLE_RADIUS * 0.92)
			shard.position = Vector3(cos(angle) * dist, 1.0 + h * 0.3, sin(angle) * dist)
			shard.rotation.x = rng.randf_range(-0.25, 0.25)
			shard.rotation.z = rng.randf_range(-0.25, 0.25)
			shard.rotation.y = rng.randf_range(0.0, TAU)
			cluster.add_child(shard)

	# Small train platform on the castle-facing edge. Deck + a pair of
	# lanterns, matching the light-industrial read of the castle's Grand
	# Station but scaled down — this is a kingdom stop, not the hub.
	func _build_platform(parent: Node3D) -> void:
		var to_castle: Vector3 = (Vector3.ZERO - ISLE_POS).normalized()
		var local_dir: Vector3 = to_castle  # island_root has no rotation, world dir == local dir

		var platform := Node3D.new()
		platform.name = "Platform"
		parent.add_child(platform)
		platform.position = local_dir * (ISLE_RADIUS - 3.0) + Vector3(0.0, 1.5, 0.0)
		platform.look_at(platform.position + local_dir, Vector3.UP)

		var stone := _mat(STONE_DARK)
		_materials.append(stone)

		var deck := MeshInstance3D.new()
		var deck_mesh := BoxMesh.new()
		deck_mesh.size = Vector3(7.0, 0.8, 4.0)
		deck.mesh = deck_mesh
		deck.material_override = stone
		platform.add_child(deck)

		var post_positions := [Vector3(-3.0, 0.0, -1.5), Vector3(3.0, 0.0, -1.5)]
		for p in post_positions:
			var post := MeshInstance3D.new()
			var post_mesh := CylinderMesh.new()
			post_mesh.top_radius = 0.2
			post_mesh.bottom_radius = 0.25
			post_mesh.height = 3.5
			post.mesh = post_mesh
			post.material_override = stone
			post.position = p + Vector3(0.0, 2.15, 0.0)
			platform.add_child(post)

			var lamp := OmniLight3D.new()
			lamp.light_color = Color(0.55, 0.65, 1.0)
			lamp.light_energy = 0.12
			lamp.omni_range = 5.0
			lamp.shadow_enabled = false
			lamp.position = p + Vector3(0.0, 3.9, 0.0)
			platform.add_child(lamp)
			_lights.append(lamp)

	func _mat(color: Color) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		return m

	func state_targets() -> Dictionary:
		return {
			"materials": _materials,
			"emissives": _emissives,
			"lights": _lights,
			"particles": _particles,
		}


# --- Isle_heart: Heart Melody — pink/coral, hills, bandstand + water ------

class _HeartIsle:
	extends Node3D

	const ISLE_ID := "heart"
	const ISLE_POS := Vector3(105, -6, -40)
	const ISLE_RADIUS := 20.0
	const DORMANT_COLOR := Color(0.50, 0.38, 0.44)

	var _materials: Array[StandardMaterial3D] = []
	var _emissives: Array[StandardMaterial3D] = []
	var _lights: Array[Light3D] = []
	var _particles: Array[GPUParticles3D] = []

	func _ready() -> void:
		name = "Isle_heart"

		set_meta("isle_id", ISLE_ID)
		set_meta("bob_phase", 3.6)

		var island_root := Node3D.new()
		island_root.name = "IslandBody"
		add_child(island_root)
		island_root.position = ISLE_POS

		_build_island_body(island_root)
		_build_hills(island_root)
		_build_bandstand(island_root)
		_build_water(island_root)
		_build_platform(island_root)

		var to_castle: Vector3 = (Vector3.ZERO - ISLE_POS).normalized()
		var platform_world: Vector3 = ISLE_POS + to_castle * (ISLE_RADIUS - 3.0) + Vector3(0.0, 2.0, 0.0)
		set_meta("platform_pos", platform_world)
		set_meta("camera_anchor", ISLE_POS + to_castle * (ISLE_RADIUS + 14.0) + Vector3(0.0, 11.0, 0.0))
		set_meta("look_target", ISLE_POS + Vector3(0.0, 4.0, 0.0))

	func _build_island_body(parent: Node3D) -> void:
		var builder: GDScript = load("res://scripts/sky_isles/isle_builder.gd")
		var body: Node3D = builder.build_island(ISLE_RADIUS, DORMANT_COLOR, 1, 2)
		parent.add_child(body)
		var mat: StandardMaterial3D = _find_first_material(body)
		if mat != null:
			_materials.append(mat)

	func _find_first_material(node: Node) -> StandardMaterial3D:
		if node is MeshInstance3D and node.material_override is StandardMaterial3D:
			return node.material_override
		for child in node.get_children():
			var found: StandardMaterial3D = _find_first_material(child)
			if found != null:
				return found
		return null

	# Rolling soft-hill terrain: a scatter of low, wide, heavily-squashed
	# spheres over the island body — no sharp edges, unlike Mind's crystals,
	# so the silhouette reads as gentle and organic.
	func _build_hills(parent: Node3D) -> void:
		var hills := Node3D.new()
		hills.name = "Hills"
		parent.add_child(hills)

		var grass := _mat(Color(0.62, 0.42, 0.48))
		_materials.append(grass)

		var rng := RandomNumberGenerator.new()
		rng.seed = 3

		var count := 6
		for i in count:
			var hill := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			var r: float = rng.randf_range(3.5, 7.0)
			mesh.radius = r
			mesh.height = r * 1.1
			mesh.radial_segments = 8
			mesh.rings = 5
			hill.mesh = mesh
			hill.material_override = grass
			hill.scale = Vector3(1.0, 0.35, 1.0)

			var angle: float = rng.randf_range(0.0, TAU)
			var dist: float = rng.randf_range(0.0, ISLE_RADIUS * 0.6)
			hill.position = Vector3(cos(angle) * dist, 0.5, sin(angle) * dist)
			hills.add_child(hill)

	# Bandstand/gazebo: a round deck, a ring of thin posts, and a shallow
	# conical roof — small enough to read as "gazebo," not "building."
	func _build_bandstand(parent: Node3D) -> void:
		var gazebo := Node3D.new()
		gazebo.name = "Bandstand"
		parent.add_child(gazebo)
		gazebo.position = Vector3(-4.0, 3.0, -3.0)

		var wood := _mat(WOOD_TONE)
		_materials.append(wood)

		var deck := MeshInstance3D.new()
		var deck_mesh := CylinderMesh.new()
		deck_mesh.top_radius = 4.5
		deck_mesh.bottom_radius = 4.5
		deck_mesh.height = 0.6
		deck_mesh.radial_segments = 10
		deck.mesh = deck_mesh
		deck.material_override = wood
		gazebo.add_child(deck)

		var post_count := 6
		var posts := Node3D.new()
		gazebo.add_child(posts)
		for i in post_count:
			var angle: float = (float(i) / float(post_count)) * TAU
			var post := MeshInstance3D.new()
			var post_mesh := CylinderMesh.new()
			post_mesh.top_radius = 0.18
			post_mesh.bottom_radius = 0.22
			post_mesh.height = 4.0
			post.mesh = post_mesh
			post.material_override = wood
			post.position = Vector3(cos(angle) * 3.8, 2.3, sin(angle) * 3.8)
			posts.add_child(post)

		var roof := MeshInstance3D.new()
		var roof_mesh := CylinderMesh.new()
		roof_mesh.top_radius = 0.2
		roof_mesh.bottom_radius = 5.2
		roof_mesh.height = 2.4
		roof_mesh.radial_segments = 10
		roof.mesh = roof_mesh
		var roof_mat := _mat(Color(0.85, 0.55, 0.62))
		_materials.append(roof_mat)
		roof.material_override = roof_mat
		roof.position = Vector3(0.0, 5.4, 0.0)
		gazebo.add_child(roof)

		# Bandstand string-light ring, dormant-off, warms up when vibrant.
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.7, 0.75)
		lamp.light_energy = 0.15
		lamp.omni_range = 8.0
		lamp.shadow_enabled = false
		lamp.position = Vector3(0.0, 4.5, 0.0)
		gazebo.add_child(lamp)
		_lights.append(lamp)

	# Small reflective water plane next to the bandstand: a flat, glassy
	# disc using a low-roughness/high-metallic material to fake reflectivity
	# cheaply (no planar-reflection probe, mobile budget).
	func _build_water(parent: Node3D) -> void:
		var pond := MeshInstance3D.new()
		pond.name = "ReflectingPool"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 5.5
		mesh.bottom_radius = 5.5
		mesh.height = 0.15
		mesh.radial_segments = 12
		pond.mesh = mesh

		var water_mat := StandardMaterial3D.new()
		water_mat.albedo_color = WATER_TONE
		water_mat.roughness = 0.05
		water_mat.metallic = 0.6
		_materials.append(water_mat)
		pond.material_override = water_mat
		pond.position = Vector3(5.0, 2.6, 4.0)
		parent.add_child(pond)

	func _build_platform(parent: Node3D) -> void:
		var to_castle: Vector3 = (Vector3.ZERO - ISLE_POS).normalized()
		var local_dir: Vector3 = to_castle

		var platform := Node3D.new()
		platform.name = "Platform"
		parent.add_child(platform)
		platform.position = local_dir * (ISLE_RADIUS - 3.0) + Vector3(0.0, 1.5, 0.0)
		platform.look_at(platform.position + local_dir, Vector3.UP)

		var stone := _mat(STONE_LIGHT)
		_materials.append(stone)

		var deck := MeshInstance3D.new()
		var deck_mesh := BoxMesh.new()
		deck_mesh.size = Vector3(7.0, 0.8, 4.0)
		deck.mesh = deck_mesh
		deck.material_override = stone
		platform.add_child(deck)

		var post_positions := [Vector3(-3.0, 0.0, -1.5), Vector3(3.0, 0.0, -1.5)]
		for p in post_positions:
			var post := MeshInstance3D.new()
			var post_mesh := CylinderMesh.new()
			post_mesh.top_radius = 0.2
			post_mesh.bottom_radius = 0.25
			post_mesh.height = 3.5
			post.mesh = post_mesh
			post.material_override = stone
			post.position = p + Vector3(0.0, 2.15, 0.0)
			platform.add_child(post)

			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.7, 0.75)
			lamp.light_energy = 0.12
			lamp.omni_range = 5.0
			lamp.shadow_enabled = false
			lamp.position = p + Vector3(0.0, 3.9, 0.0)
			platform.add_child(lamp)
			_lights.append(lamp)

	func _mat(color: Color) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		return m

	func state_targets() -> Dictionary:
		return {
			"materials": _materials,
			"emissives": _emissives,
			"lights": _lights,
			"particles": _particles,
		}


# --- Isle_creator: Creator's Light — amber/gold, canvas hill, glass dome --

class _CreatorIsle:
	extends Node3D

	const ISLE_ID := "creator"
	const ISLE_POS := Vector3(15, 8, 115)
	const ISLE_RADIUS := 20.0
	const DORMANT_COLOR := Color(0.50, 0.45, 0.34)

	var _materials: Array[StandardMaterial3D] = []
	var _emissives: Array[StandardMaterial3D] = []
	var _lights: Array[Light3D] = []
	var _particles: Array[GPUParticles3D] = []

	func _ready() -> void:
		name = "Isle_creator"

		set_meta("isle_id", ISLE_ID)
		set_meta("bob_phase", 5.3)

		var island_root := Node3D.new()
		island_root.name = "IslandBody"
		add_child(island_root)
		island_root.position = ISLE_POS

		_build_island_body(island_root)
		_build_canvas_hill(island_root)
		_build_glass_dome(island_root)
		_build_platform(island_root)

		var to_castle: Vector3 = (Vector3.ZERO - ISLE_POS).normalized()
		var platform_world: Vector3 = ISLE_POS + to_castle * (ISLE_RADIUS - 3.0) + Vector3(0.0, 2.0, 0.0)
		set_meta("platform_pos", platform_world)
		set_meta("camera_anchor", ISLE_POS + to_castle * (ISLE_RADIUS + 14.0) + Vector3(0.0, 13.0, 0.0))
		set_meta("look_target", ISLE_POS + Vector3(0.0, 7.0, 0.0))

	func _build_island_body(parent: Node3D) -> void:
		var builder: GDScript = load("res://scripts/sky_isles/isle_builder.gd")
		var body: Node3D = builder.build_island(ISLE_RADIUS, DORMANT_COLOR, 1, 3)
		parent.add_child(body)
		var mat: StandardMaterial3D = _find_first_material(body)
		if mat != null:
			_materials.append(mat)

	func _find_first_material(node: Node) -> StandardMaterial3D:
		if node is MeshInstance3D and node.material_override is StandardMaterial3D:
			return node.material_override
		for child in node.get_children():
			var found: StandardMaterial3D = _find_first_material(child)
			if found != null:
				return found
		return null

	# Uneven "canvas hill": a displaced PlaneMesh whose vertices are pushed
	# up/down per-vertex to fake a painterly, uneven ground — cheaper than
	# a heightmap terrain system and stays well inside the low-poly budget.
	func _build_canvas_hill(parent: Node3D) -> void:
		var plane_mesh := PlaneMesh.new()
		plane_mesh.size = Vector2(ISLE_RADIUS * 1.1, ISLE_RADIUS * 1.1)
		plane_mesh.subdivide_width = 14
		plane_mesh.subdivide_depth = 14

		# PlaneMesh is a PrimitiveMesh, not an ArrayMesh, and MeshDataTool
		# only accepts ArrayMesh — copy the generated surface arrays across
		# before handing it to MeshDataTool for per-vertex displacement.
		var array_mesh := ArrayMesh.new()
		var surface_arrays: Array = plane_mesh.surface_get_arrays(0)
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)

		var mesh_data_tool := MeshDataTool.new()
		mesh_data_tool.create_from_surface(array_mesh, 0)

		var rng := RandomNumberGenerator.new()
		rng.seed = 5

		var vertex_count: int = mesh_data_tool.get_vertex_count()
		for i in vertex_count:
			var v: Vector3 = mesh_data_tool.get_vertex(i)
			# Low-frequency displacement via sine of position, plus a touch
			# of per-vertex jitter — reads as "hand-painted canvas ridges"
			# rather than random spikes.
			var lift: float = sin(v.x * 0.35) * cos(v.z * 0.3) * 1.6
			lift += rng.randf_range(-0.3, 0.3)
			v.y += lift
			mesh_data_tool.set_vertex(i, v)

		array_mesh.clear_surfaces()
		mesh_data_tool.commit_to_surface(array_mesh)

		var canvas := MeshInstance3D.new()
		canvas.name = "CanvasHill"
		canvas.mesh = array_mesh

		var canvas_mat := _mat(Color(0.68, 0.55, 0.32))
		_materials.append(canvas_mat)
		canvas.material_override = canvas_mat
		canvas.position = Vector3(0.0, 1.0, 0.0)
		parent.add_child(canvas)

	# Glass-dome studio: a faceted low-poly dome (SphereMesh, few segments)
	# with a transparent amber-tinted material, sitting on a short cylinder
	# base so it reads as a small structure, not a marble dropped on the hill.
	func _build_glass_dome(parent: Node3D) -> void:
		var studio := Node3D.new()
		studio.name = "GlassDomeStudio"
		parent.add_child(studio)
		studio.position = Vector3(2.0, 3.0, -2.0)

		var base_mat := _mat(STONE_LIGHT)
		_materials.append(base_mat)
		var base := MeshInstance3D.new()
		var base_mesh := CylinderMesh.new()
		base_mesh.top_radius = 5.0
		base_mesh.bottom_radius = 5.4
		base_mesh.height = 1.6
		base_mesh.radial_segments = 10
		base.mesh = base_mesh
		base.material_override = base_mat
		studio.add_child(base)

		var dome := MeshInstance3D.new()
		var dome_mesh := SphereMesh.new()
		dome_mesh.radius = 4.6
		dome_mesh.height = 4.6
		dome_mesh.radial_segments = 10
		dome_mesh.rings = 5
		dome.mesh = dome_mesh
		dome.position = Vector3(0.0, 0.8, 0.0)

		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(GLASS_TINT.r, GLASS_TINT.g * 0.85, GLASS_TINT.b * 0.55, 0.55)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.roughness = 0.05
		glass.metallic = 0.1
		glass.emission_enabled = true
		glass.emission = Color(1.0, 0.76, 0.30)
		glass.emission_energy_multiplier = 0.0  # dormant: off, warms on vibrant
		dome.material_override = glass
		_emissives.append(glass)
		studio.add_child(dome)

		# Interior work-light, dormant-dim, reads as "studio lamp glowing
		# through the glass" once vibrant boosts its energy.
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.82, 0.45)
		lamp.light_energy = 0.15
		lamp.omni_range = 9.0
		lamp.shadow_enabled = false
		lamp.position = Vector3(0.0, 1.5, 0.0)
		studio.add_child(lamp)
		_lights.append(lamp)

		# Gentle creative-spark motes drifting up from the studio — off
		# until vibrant, matching the dormant-particles convention in
		# isle_castle.gd's station.
		var particles := GPUParticles3D.new()
		particles.amount = 30
		particles.lifetime = 3.5
		particles.emitting = false
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 25.0
		pm.gravity = Vector3(0, 0.1, 0)
		pm.initial_velocity_min = 0.3
		pm.initial_velocity_max = 0.7
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 3.5
		particles.process_material = pm
		var pmesh := SphereMesh.new()
		pmesh.radius = 0.07
		pmesh.height = 0.14
		pmesh.radial_segments = 4
		pmesh.rings = 2
		particles.draw_pass_1 = pmesh
		particles.position = Vector3(0.0, 2.0, 0.0)
		studio.add_child(particles)
		_particles.append(particles)

	func _build_platform(parent: Node3D) -> void:
		var to_castle: Vector3 = (Vector3.ZERO - ISLE_POS).normalized()
		var local_dir: Vector3 = to_castle

		var platform := Node3D.new()
		platform.name = "Platform"
		parent.add_child(platform)
		platform.position = local_dir * (ISLE_RADIUS - 3.0) + Vector3(0.0, 1.5, 0.0)
		platform.look_at(platform.position + local_dir, Vector3.UP)

		var stone := _mat(STONE_DARK)
		_materials.append(stone)

		var deck := MeshInstance3D.new()
		var deck_mesh := BoxMesh.new()
		deck_mesh.size = Vector3(7.0, 0.8, 4.0)
		deck.mesh = deck_mesh
		deck.material_override = stone
		platform.add_child(deck)

		var post_positions := [Vector3(-3.0, 0.0, -1.5), Vector3(3.0, 0.0, -1.5)]
		for p in post_positions:
			var post := MeshInstance3D.new()
			var post_mesh := CylinderMesh.new()
			post_mesh.top_radius = 0.2
			post_mesh.bottom_radius = 0.25
			post_mesh.height = 3.5
			post.mesh = post_mesh
			post.material_override = stone
			post.position = p + Vector3(0.0, 2.15, 0.0)
			platform.add_child(post)

			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.82, 0.45)
			lamp.light_energy = 0.12
			lamp.omni_range = 5.0
			lamp.shadow_enabled = false
			lamp.position = p + Vector3(0.0, 3.9, 0.0)
			platform.add_child(lamp)
			_lights.append(lamp)

	func _mat(color: Color) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		return m

	func state_targets() -> Dictionary:
		return {
			"materials": _materials,
			"emissives": _emissives,
			"lights": _lights,
			"particles": _particles,
		}
