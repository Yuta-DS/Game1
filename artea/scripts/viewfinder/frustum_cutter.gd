# Slices every cuttable prop overlapping a camera's view frustum, by applying
# the frustum's four side planes in sequence.
#
# The frustum is not a solid to intersect against — it is the intersection of
# four half-spaces, so four sequential plane cuts produce it for free. One prop
# can end up as at most 2^4 = 16 fragments.
#
# Broad phase uses Godot's synchronous intersect_shape() rather than the
# original's "enable a trigger, wait three frames, read what collided" hack.
# That hack depends on physics tick timing and is the mechanic's biggest
# fragility; the query answers in the same frame, deterministically
# (ViewFinder.txt §6.2).
extends Node3D

const MeshCutterScript := preload("res://scripts/viewfinder/mesh_cutter.gd")

# Set in project.godot layer_names. Never put Terrain3D or ProtonScatter
# MultiMesh output on this layer: clipmaps and MultiMesh have no per-instance
# mesh to cut (ViewFinder.txt §6.8).
const CUTTABLE_LAYER := 4
const CUTTABLE_MASK := 1 << (CUTTABLE_LAYER - 1)

# Broad-phase result cap. Beyond this the frame cost is not worth paying.
const MAX_OVERLAPS := 32

# Fragments are nudged this far off the cut planes so a piece sitting exactly
# on a seam is not re-caught by the next query (ViewFinder.txt L7). Chosen
# relative to Artéa's world scale, where props are metres.
const SEAM_EPSILON := 0.001

# How far the capture frustum reaches. Deliberately short: the cost is
# O(triangles overlapping the frustum), so a far plane at Artéa's usual draw
# distance would try to cut the entire level (ViewFinder.txt R1).
const CAPTURE_DISTANCE := 18.0

var cap_material: Material = null


func _ready() -> void:
	if cap_material == null:
		cap_material = _default_cap_material()


# The cross-section material. A cut only reads as a cut if the exposed face
# looks different from the surface — without this the fragment just looks like
# a badly-modelled prop.
static func _default_cap_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.94, 0.72)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.86, 0.52)
	mat.emission_energy_multiplier = 0.6
	mat.roughness = 0.35
	# The cut face is interior geometry; lighting it from one side only makes
	# thin fragments read as paper.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


# The four side planes of `camera`'s frustum, in WORLD space, all normals
# pointing inward so "inside the frustum" is "in front of all four".
static func frustum_planes(camera: Camera3D, distance: float) -> Array[Plane]:
	var xf := camera.global_transform
	var origin := xf.origin

	var half_h := tan(deg_to_rad(camera.fov) * 0.5) * distance
	var viewport := camera.get_viewport()
	var size := viewport.get_visible_rect().size if viewport != null else Vector2(16, 9)
	var aspect := size.x / maxf(size.y, 1.0)
	var half_w := half_h * aspect

	# Godot cameras look down -Z.
	var forward := -xf.basis.z * distance
	var right := xf.basis.x * half_w
	var up := xf.basis.y * half_h

	var top_left := origin + forward - right + up
	var top_right := origin + forward + right + up
	var bottom_left := origin + forward - right - up
	var bottom_right := origin + forward + right - up

	# Each plane is built from the apex and two far corners. Corner order sets
	# the winding, and therefore which way the normal points — these four are
	# ordered so every normal faces into the frustum interior.
	var planes: Array[Plane] = [
		Plane(origin, top_left, bottom_left),      # left
		Plane(origin, bottom_right, top_right),    # right
		Plane(origin, top_right, top_left),        # top
		Plane(origin, bottom_left, bottom_right),  # bottom
	]

	# Guard the winding rather than trusting it: if a plane's normal points
	# away from the frustum's own centre, the cut would keep the outside and
	# discard the contents.
	var centre := origin + forward * 0.5
	for i in planes.size():
		if planes[i].distance_to(centre) < 0.0:
			planes[i] = -planes[i]

	return planes


# Point cloud of the frustum's far wedge, for the broad-phase shape query.
# ConvexPolygonShape3D takes points and hulls them itself, so no index buffer
# is needed (ViewFinder.txt §6.2).
static func frustum_points(camera: Camera3D, distance: float) -> PackedVector3Array:
	var xf := camera.global_transform
	var origin := xf.origin

	var half_h := tan(deg_to_rad(camera.fov) * 0.5) * distance
	var viewport := camera.get_viewport()
	var size := viewport.get_visible_rect().size if viewport != null else Vector2(16, 9)
	var aspect := size.x / maxf(size.y, 1.0)
	var half_w := half_h * aspect

	var forward := -xf.basis.z * distance
	var right := xf.basis.x * half_w
	var up := xf.basis.y * half_h

	return PackedVector3Array([
		origin,
		origin + forward - right + up,
		origin + forward + right + up,
		origin + forward - right - up,
		origin + forward + right - up,
	])


# Which cuttable bodies overlap the frustum, answered this frame.
func overlapping_bodies(camera: Camera3D, distance: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	var world := get_world_3d()
	if world == null or camera == null:
		return found

	var shape := ConvexPolygonShape3D.new()
	shape.points = frustum_points(camera, distance)

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	# Points are already in world space, so the query transform is identity.
	params.transform = Transform3D.IDENTITY
	params.collision_mask = CUTTABLE_MASK
	params.collide_with_bodies = true
	params.collide_with_areas = false

	for hit in world.direct_space_state.intersect_shape(params, MAX_OVERLAPS):
		var collider = hit.get("collider")
		if collider is Node3D and not found.has(collider):
			found.append(collider)
	return found


# Cut every cuttable prop in the frustum, returning the fragments that lie
# INSIDE it. Fragments outside are returned separately so the caller can decide
# whether to restore or discard them.
#
# Returns {"inside": Array[MeshInstance3D], "outside": Array[MeshInstance3D],
#          "sources": Array[Node3D]}.
func slice_frustum(camera: Camera3D, distance: float = CAPTURE_DISTANCE) -> Dictionary:
	var result := {"inside": [], "outside": [], "sources": []}
	if camera == null:
		return result

	var planes := frustum_planes(camera, distance)
	var bodies := overlapping_bodies(camera, distance)
	# One imported prop can expose more than one physics body. Process its mesh
	# once, or duplicate fragments would be created at exactly the same pose.
	var processed_meshes := {}

	for body in bodies:
		var mesh_instance := _find_mesh_for_collider(body)
		if mesh_instance == null:
			continue
		var mesh_id := mesh_instance.get_instance_id()
		if processed_meshes.has(mesh_id):
			continue
		processed_meshes[mesh_id] = true

		# The body and visible mesh are not always parent/child in imported GLBs.
		# Suppress their nearest common root so both rendering and collision
		# disappear together while the seeing is held.
		var source_root := _lowest_common_ancestor(body, mesh_instance)
		if source_root == null:
			source_root = body
		if not result["sources"].has(source_root):
			result["sources"].append(source_root)

		# Fragments accumulate: each plane cuts every piece the previous plane
		# produced, so the set grows as the frustum's corners bite in.
		var pieces: Array = [{
			"mesh": mesh_instance.mesh,
			"transform": mesh_instance.global_transform,
		}]

		for plane in planes:
			var next: Array = []
			for piece in pieces:
				next.append_array(_cut_piece(piece, plane))
			pieces = next
			if pieces.is_empty():
				break

		# Classify by centroid: a piece produced by all four cuts is inside the
		# frustum only if it is in front of every plane.
		for piece in pieces:
			var node := _build_fragment(piece, mesh_instance)
			if node == null:
				continue
			if _is_inside(piece, planes):
				result["inside"].append(node)
			else:
				result["outside"].append(node)

	return result


# Split one piece by one plane, returning what it became (1 or 2 pieces).
func _cut_piece(piece: Dictionary, world_plane: Plane) -> Array:
	var mesh: Mesh = piece["mesh"]
	var xf: Transform3D = piece["transform"]
	if mesh == null:
		return []

	# Transform the PLANE into the mesh's local space rather than the mesh's
	# vertices into world space: one transform instead of N. This is the whole
	# reason the technique is affordable (ViewFinder.txt L1).
	var inv := xf.affine_inverse()
	var local_point := inv * (world_plane.normal * world_plane.d)
	var local_normal := (inv.basis.transposed().inverse() * world_plane.normal).normalized()
	var local_plane := Plane(local_normal, local_point)

	var halves: Dictionary = MeshCutterScript.cut(mesh, local_plane, cap_material)
	if halves["positive"] == null and halves["negative"] == null:
		# The plane missed this piece entirely — it survives unchanged.
		return [piece]

	var out: Array = []
	for key in ["positive", "negative"]:
		if halves[key] != null:
			out.append({"mesh": halves[key], "transform": xf})
	return out


# Is this piece on the inside of every frustum plane?
func _is_inside(piece: Dictionary, planes: Array[Plane]) -> bool:
	var mesh: Mesh = piece["mesh"]
	var xf: Transform3D = piece["transform"]
	if mesh == null:
		return false

	var aabb := mesh.get_aabb()
	var centre: Vector3 = xf * aabb.get_center()
	for plane in planes:
		# Nudged off the seam so a fragment lying exactly on a cut plane is
		# not classified by floating-point noise.
		if plane.distance_to(centre) < SEAM_EPSILON:
			return false
	return true


# A fragment is a StaticBody3D carrying its mesh and its own collision shape.
#
# Bare MeshInstance3D fragments looked correct and were walked straight
# through: placed geometry has to be standable, or the mechanic produces
# scenery rather than world. Static rather than rigid because a placed seeing
# is part of the level, not debris — it must not settle, roll, or fall.
func _build_fragment(piece: Dictionary, source: MeshInstance3D) -> StaticBody3D:
	var mesh: Mesh = piece["mesh"]
	if mesh == null:
		return null
	# A cut can leave a piece with no triangles at all; adding it would put an
	# empty node in the world and a shape with no points in the physics server.
	if mesh.get_faces().is_empty():
		return null

	var shape := _collision_shape_for(mesh)
	if shape == null:
		return null

	var body := StaticBody3D.new()
	body.name = "%s_fragment" % source.name
	# Fragments are themselves cuttable, so a placed seeing can be re-framed
	# and carried onward rather than becoming permanently inert.
	body.collision_layer = CUTTABLE_MASK
	body.collision_mask = 0

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)

	# The piece's transform is the source's GLOBAL transform. Written to the
	# local `transform` here because the body is not in the tree yet; callers
	# add it and then reparent with keep_global_transform, so it must already
	# hold the right pose at the moment it is added. `_place_fragment()` is the
	# supported way to do that.
	body.transform = piece["transform"]
	return body


# Add a fragment to the world at the pose it was cut in.
#
# Fragments carry a GLOBAL transform in their local `transform` before they are
# parented, so adding one under a parent that is not at the origin silently
# offsets it. This restores the intended global pose after the add.
static func place_fragment(fragment: Node3D, parent: Node) -> void:
	if fragment == null or parent == null:
		return
	var pose := fragment.transform
	parent.add_child(fragment)
	fragment.global_transform = pose


# Collision for one fragment.
#
# Trimesh, not convex: cut pieces are routinely concave — an L-shaped corner
# left after a frustum bites a notch out of a wall is the normal case, not the
# exception. A convex hull would fill that notch in and let the player stand on
# air (ViewFinder.txt R3, which the original inherits by using convex
# everywhere). Trimesh is exact and is only valid on static bodies, which is
# what fragments are.
static func _collision_shape_for(mesh: Mesh) -> Shape3D:
	var trimesh := mesh.create_trimesh_shape()
	if trimesh != null and not trimesh.get_faces().is_empty():
		return trimesh
	# Degenerate sliver: fall back rather than adding a body with no shape.
	var convex := mesh.create_convex_shape()
	if convex != null and not convex.points.is_empty():
		return convex
	return null


# The first MeshInstance3D at or under `body`. Cuttable props are authored as a
# body with the mesh as a child, but .glb imports vary.
static func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


# Resolve the visual mesh represented by a physics-query hit.
#
# Authored props commonly put the MeshInstance3D under the StaticBody3D, while
# imported GLBs often do the reverse (MeshInstance3D -> StaticBody3D) or make
# them siblings. Search the collider subtree first, then expand one ancestor at
# a time; the nearest containing subtree is the least ambiguous match.
static func _find_mesh_for_collider(collider: Node) -> MeshInstance3D:
	if collider == null:
		return null
	var direct := _find_mesh_instance(collider)
	if direct != null:
		return direct
	var ancestor := collider.get_parent()
	while ancestor != null:
		if ancestor is MeshInstance3D:
			return ancestor
		var nearby := _find_mesh_instance(ancestor)
		if nearby != null:
			return nearby
		ancestor = ancestor.get_parent()
	return null


# Smallest node whose subtree contains both the collider and its visual mesh.
# Hiding only one of them produces either invisible collision or visible
# geometry the player can walk through.
static func _lowest_common_ancestor(a: Node, b: Node) -> Node3D:
	if a == null or b == null:
		return null
	var ancestors := {}
	var cursor: Node = a
	while cursor != null:
		ancestors[cursor.get_instance_id()] = cursor
		cursor = cursor.get_parent()
	cursor = b
	while cursor != null:
		if ancestors.has(cursor.get_instance_id()) and cursor is Node3D:
			return cursor
		cursor = cursor.get_parent()
	return null
