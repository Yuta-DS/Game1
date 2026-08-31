extends RefCounted

## Web-performance adapter for the four August gravity_leaf_bough leaf reliefs.
## The RGBA materials come directly from the authored runtime GLB. Each 6,336
## triangle relief is represented by one socket-centred, folded alpha-cutout
## blade so the reference artwork survives without the source mesh cost and
## still catches light when the player walks beneath the canopy.

const GravityLeafBoughLibrary := preload(
	"res://assets3D/tree_of_life/gravity_leaf_bough/glb/gravity_leaf_bough_runtime.glb")

const FAMILY_PATTERNS := {
	"living_leaf_fan": "GravityBough_SocketLeaf_living_leaf_fan_*",
	"magic_rune_leaf": "GravityBough_SocketLeaf_magic_rune_leaf_*",
	"solar_glass_science_leaf": "GravityBough_SocketLeaf_solar_glass_science_leaf_*",
	"emerald_sensor_leaf": "GravityBough_SocketLeaf_emerald_sensor_leaf_*",
}

# build_gravity_leaf_bough.py LEAF_SOCKET_LOCAL converted from Blender Z-up
# coordinates to Godot Y-up coordinates: (x, y, z) -> (x, z, -y).
const FAMILY_SOCKETS := {
	"living_leaf_fan": Vector3(-2.37, 0.20, 1.66),
	"magic_rune_leaf": Vector3(-3.38, 0.20, 1.96),
	"solar_glass_science_leaf": Vector3(-3.47, 0.21, 2.63),
	"emerald_sensor_leaf": Vector3(-1.21, 0.20, 1.38),
}

# The source relief is naturally long and narrow. Broadening the local Z blade
# axis closes gaps over major boughs without adding runtime instances.
# Local X remains tail-to-tip, so the measured brass socket stays unchanged.
const LANDMARK_LENGTH_SCALE := 0.39
const LANDMARK_RELIEF_SCALE := 0.36
const LANDMARK_WIDTH_SCALE := 0.56

static var _mesh_cache: Dictionary = {}


static func _upward_triangle_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var normal := (b - a).cross(c - a).normalized()
	return -normal if normal.y < 0.0 else normal


static func style_id() -> String:
	return "gravity_leaf_relief"


static func source_asset() -> String:
	return "res://assets3D/tree_of_life/gravity_leaf_bough/glb/gravity_leaf_bough_runtime.glb"


static func tail_local_point() -> Vector3:
	# Every generated relief is translated so the authored brass stem connector
	# is exactly here. Runtime placement must map this point to the twig surface.
	return Vector3.ZERO


static func prepare_transforms(source: Array[Transform3D]) -> Array[Transform3D]:
	var prepared: Array[Transform3D] = []
	prepared.resize(source.size())
	for index in source.size():
		var placement := source[index]
		# Existing blueprint sockets were scaled for tiny procedural pods. The
		# August compound reliefs are already 5.1-9.2 m wide in source space.
		placement.basis = placement.basis.scaled(Vector3(
			LANDMARK_LENGTH_SCALE, LANDMARK_RELIEF_SCALE, LANDMARK_WIDTH_SCALE))
		prepared[index] = placement
	return prepared


static func build_mesh(family: String, _family_material: StandardMaterial3D) -> Mesh:
	if _mesh_cache.has(family):
		return _mesh_cache[family] as Mesh
	var library := GravityLeafBoughLibrary.instantiate() as Node3D
	var matches := library.find_children(
		str(FAMILY_PATTERNS.get(family, FAMILY_PATTERNS.living_leaf_fan)),
		"MeshInstance3D", true, false)
	assert(not matches.is_empty(), "August gravity leaf mesh is missing: %s" % family)
	var source := matches[0] as MeshInstance3D
	var source_mesh := source.mesh
	var bounds := source_mesh.get_aabb()
	var socket: Vector3 = FAMILY_SOCKETS.get(family, FAMILY_SOCKETS.living_leaf_fan)
	var y := bounds.get_center().y - socket.y
	var vertices := PackedVector3Array([
		Vector3(bounds.position.x - socket.x, y, bounds.position.z - socket.z),
		Vector3(bounds.end.x - socket.x, y, bounds.position.z - socket.z),
		Vector3(bounds.end.x - socket.x, y, bounds.end.z - socket.z),
		Vector3(bounds.position.x - socket.x, y, bounds.end.z - socket.z),
	])
	# Each authored family has a different off-centre brass connector. After
	# moving that connector to the origin, normalize the direction from socket
	# to painted leaf mass onto local +X. The placement transform can then follow
	# its twig tangent exactly instead of making some families grow sideways.
	var mass_direction := Vector3(bounds.get_center().x - socket.x, 0.0,
		bounds.get_center().z - socket.z).normalized()
	var align_to_forward := Basis(Vector3.UP,
		atan2(mass_direction.z, mass_direction.x))
	for vertex_index in vertices.size():
		vertices[vertex_index] = align_to_forward * vertices[vertex_index]
	# Split the relief along its centre vein and lift the shared ridge. Two copies
	# cross around the biological tail-to-tip axis, creating an eight-triangle
	# cluster that cannot disappear edge-on. Both panels retain the same measured
	# socket at local zero, so this adds coverage without another runtime instance.
	var corner_a := vertices[0]
	var corner_c := vertices[1]
	var corner_f := vertices[2]
	var corner_d := vertices[3]
	var ridge_height := minf(bounds.size.x, bounds.size.z) * 0.055
	var ridge_b := (corner_a + corner_c) * 0.5 + Vector3.UP * ridge_height
	var ridge_e := (corner_d + corner_f) * 0.5 + Vector3.UP * ridge_height
	var panel_vertices := PackedVector3Array([
		corner_a, ridge_b, ridge_e, corner_d,
		ridge_b, corner_c, corner_f, ridge_e,
	])
	var left_normal := _upward_triangle_normal(corner_a, ridge_e, ridge_b)
	var right_normal := _upward_triangle_normal(ridge_b, corner_f, corner_c)
	var panel_normals := PackedVector3Array([
		left_normal, left_normal, left_normal, left_normal,
		right_normal, right_normal, right_normal, right_normal])
	var panel_uvs := PackedVector2Array([
		# Godot samples imported image V from the top edge. The previous inverse-V
		# mapping put the texture's upper leaf edge at the measured lower brass
		# socket, so transforms were numerically connected while the visible cuff
		# floated away. This mapping makes the authored cuff pixel and local origin
		# the same physical point.
		Vector2(0.0, 0.0), Vector2(0.5, 0.0),
		Vector2(0.5, 1.0), Vector2(0.0, 1.0),
		Vector2(0.5, 0.0), Vector2(1.0, 0.0),
		Vector2(1.0, 1.0), Vector2(0.5, 1.0)])
	var cluster_vertices := PackedVector3Array()
	var cluster_normals := PackedVector3Array()
	var cluster_uvs := PackedVector2Array()
	var cluster_indices := PackedInt32Array()
	for panel_angle_degrees in [-32.0, 32.0]:
		var panel_rotation := Basis(Vector3.RIGHT, deg_to_rad(panel_angle_degrees))
		var offset := cluster_vertices.size()
		for vertex in panel_vertices:
			cluster_vertices.append(panel_rotation * vertex)
		for normal in panel_normals:
			cluster_normals.append((panel_rotation * normal).normalized())
		cluster_uvs.append_array(panel_uvs)
		cluster_indices.append_array(PackedInt32Array([
			offset + 0, offset + 2, offset + 1,
			offset + 0, offset + 3, offset + 2,
			offset + 4, offset + 6, offset + 5,
			offset + 4, offset + 7, offset + 6,
		]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = cluster_vertices
	arrays[Mesh.ARRAY_NORMAL] = cluster_normals
	arrays[Mesh.ARRAY_TEX_UV] = cluster_uvs
	arrays[Mesh.ARRAY_INDEX] = cluster_indices
	var card := ArrayMesh.new()
	card.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := source_mesh.surface_get_material(0)
	if material is BaseMaterial3D:
		material = material.duplicate()
		var detailed := material as BaseMaterial3D
		detailed.cull_mode = BaseMaterial3D.CULL_DISABLED
		detailed.texture_filter = \
			BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		detailed.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		detailed.alpha_scissor_threshold = 0.32
		if detailed is StandardMaterial3D:
			var standard := detailed as StandardMaterial3D
			standard.roughness = 0.58
			if standard.albedo_texture != null:
				standard.emission_enabled = true
				standard.emission_texture = standard.albedo_texture
				standard.emission_energy_multiplier = 0.22
	card.surface_set_material(0, material)
	card.resource_name = "GravityLeafReliefCard_%s" % family
	_mesh_cache[family] = card
	library.free()
	return card
