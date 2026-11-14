# Single-plane mesh surgery: split one mesh into the two halves either side of
# a plane, capping both so neither is hollow.
#
# Reimplemented for Godot from the technique described in ViewFinder.txt
# (ToughNutToCrack's ViewFinder, whose cutting core derives from Kristin
# Lague's Mesh-Cutting). Studied and rewritten, not transliterated — see the
# attribution note at the end of ViewFinder.txt.
#
# GDScript rather than C#: Artéa has no C# gameplay code at all, and adding a
# build step to a ~160-file GDScript project costs more than it buys while the
# cuttable set is low-poly props. MAX_CUTTABLE_TRIANGLES enforces that
# assumption instead of leaving it as a hope — see cut().
#
# Deliberately a plain RefCounted with static-style entry points and no scene
# presence: this is the one piece that can be subtly, invisibly wrong, so it is
# testable in isolation with no camera, no input, and no physics.
class_name MeshCutter
extends RefCounted

# Above this, a cut costs more than a frame. The mechanic is for discrete
# props (the .glb models), never for Terrain3D clipmaps or MultiMesh scatter,
# which cannot be cut at all — see ViewFinder.txt §6.8.
const MAX_CUTTABLE_TRIANGLES := 4000

# Vertices closer than this to the plane are treated as lying exactly on it,
# rather than generating a near-degenerate sliver triangle.
const EPSILON := 0.00001

# How close two seam points must be to be welded into one cap vertex. EPSILON is
# the cutter's on-plane tolerance, so a small multiple of it is the right weld
# distance: points closer than that were always meant to be one vertex.
const WELD_GRID := EPSILON * 10.0


# One half of a cut, accumulated as parallel arrays and committed once.
#
# Surfaces are kept separate so a multi-material prop keeps its materials, and
# the cap is written to its own extra surface so the cross-section can take a
# distinct material — that separation is what makes a cut read visually.
#
# Named Half, not Side: `Side` is a built-in Godot enum (SIDE_LEFT etc.) and
# shadowing it makes every type annotation using it a parse error.
class Half:
	extends RefCounted

	var surfaces: Array = []          # Array[Dictionary] of packed arrays
	# Flat list of seam segment endpoint PAIRS (a0,b0, a1,b1, ...). The pairing
	# is what _boundary_loops chains back into loops, so nothing may append a
	# lone point here.
	var cap_points: PackedVector3Array = PackedVector3Array()

	func _init(surface_count: int) -> void:
		for i in surface_count:
			surfaces.append({
				"verts": PackedVector3Array(),
				"normals": PackedVector3Array(),
				"uvs": PackedVector2Array(),
			})

	func add_triangle(surface: int, v: Array, n: Array, uv: Array) -> void:
		var s: Dictionary = surfaces[surface]
		for i in 3:
			s["verts"].append(v[i])
			s["normals"].append(n[i])
			s["uvs"].append(uv[i])

	func is_empty() -> bool:
		for s in surfaces:
			if not s["verts"].is_empty():
				return false
		return true


# Split `mesh` by `plane` (both in the MESH'S OWN LOCAL SPACE).
#
# Cutting in local space is the central performance decision: the plane is
# transformed once by the caller instead of every vertex being transformed
# into world space inside the loop.
#
# Returns {"positive": ArrayMesh|null, "negative": ArrayMesh|null}, naming the
# sides by which side of the plane normal they fall on. A null side means the
# mesh lay entirely on the other side — nothing was cut.
static func cut(mesh: Mesh, plane: Plane, cap_material: Material = null) -> Dictionary:
	var empty := {"positive": null, "negative": null}
	if mesh == null:
		return empty

	var surface_count := mesh.get_surface_count()
	if surface_count == 0:
		return empty

	var positive := Half.new(surface_count)
	var negative := Half.new(surface_count)
	var total_triangles := 0

	# Whether any vertex genuinely lies off the plane on each side. Triangles
	# lying flat ON the plane are routed to the positive half (they have no
	# negative vertex), so half-emptiness alone cannot distinguish "cut" from
	# "grazed the surface" — a plane tangent to a box face would otherwise
	# shear off a zero-thickness shell of that face.
	var saw_positive := false
	var saw_negative := false

	for surface_i in surface_count:
		var arrays := mesh.surface_get_arrays(surface_i)
		if arrays.is_empty():
			continue

		# Read once, outside the loop. Re-reading these per triangle is the
		# dominant cost in the original implementation.
		if arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if verts.is_empty():
			continue
		# An absent channel comes back as null, not an empty array — assigning
		# that straight into a typed local is a hard crash, and real .glb props
		# do ship without UVs or normals.
		var normals := PackedVector3Array()
		if arrays[Mesh.ARRAY_NORMAL] != null:
			normals = arrays[Mesh.ARRAY_NORMAL]
		var uvs := PackedVector2Array()
		if arrays[Mesh.ARRAY_TEX_UV] != null:
			uvs = arrays[Mesh.ARRAY_TEX_UV]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]

		var has_normals := normals.size() == verts.size()
		var has_uvs := uvs.size() == verts.size()

		# Godot allows non-indexed surfaces; walk vertices in threes when the
		# index buffer is absent rather than assuming .glb-style indexing.
		var count := indices.size() if not indices.is_empty() else verts.size()
		total_triangles += count / 3
		if total_triangles > MAX_CUTTABLE_TRIANGLES:
			push_warning(
				"MeshCutter: mesh exceeds %d triangles, refusing to cut"
				% MAX_CUTTABLE_TRIANGLES)
			return empty

		var i := 0
		while i + 2 < count:
			var idx := [0, 0, 0]
			for k in 3:
				idx[k] = indices[i + k] if not indices.is_empty() else i + k

			var tv := [verts[idx[0]], verts[idx[1]], verts[idx[2]]]
			var tn := [Vector3.UP, Vector3.UP, Vector3.UP]
			var tuv := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
			if has_normals:
				tn = [normals[idx[0]], normals[idx[1]], normals[idx[2]]]
			else:
				# No authored normals — derive a flat face normal so the
				# fragment still lights, rather than shipping Vector3.UP.
				var edge_a: Vector3 = tv[1] - tv[0]
				var edge_b: Vector3 = tv[2] - tv[0]
				var face: Vector3 = edge_a.cross(edge_b).normalized()
				if face != Vector3.ZERO:
					tn = [face, face, face]
			if has_uvs:
				tuv = [uvs[idx[0]], uvs[idx[1]], uvs[idx[2]]]

			for vertex in tv:
				var dist: float = plane.distance_to(vertex)
				if dist > EPSILON:
					saw_positive = true
				elif dist < -EPSILON:
					saw_negative = true

			_split_triangle(plane, surface_i, tv, tn, tuv, positive, negative)
			i += 3

	# Entirely on one side, or merely tangent to a face: report "no cut" rather
	# than handing back a copy and an empty shell, so callers can cheaply
	# detect the common case.
	if not saw_positive or not saw_negative:
		return empty
	if positive.is_empty() or negative.is_empty():
		return empty

	return {
		"positive": _commit(positive, mesh, plane, false, cap_material),
		"negative": _commit(negative, mesh, plane, true, cap_material),
	}


# Route one triangle to one side, or split it across both.
static func _split_triangle(plane: Plane, surface: int, v: Array, n: Array,
		uv: Array, positive: Half, negative: Half) -> void:
	# distance_to > 0 means "in front of the plane" — its sign is the whole
	# classification. Treat near-zero as on-plane so a vertex sitting exactly
	# on the cut does not produce a zero-area sliver.
	var d := [
		plane.distance_to(v[0]),
		plane.distance_to(v[1]),
		plane.distance_to(v[2]),
	]
	var sides := [0, 0, 0]
	for i in 3:
		if d[i] > EPSILON:
			sides[i] = 1
		elif d[i] < -EPSILON:
			sides[i] = -1

	var positives := 0
	var negatives := 0
	for s in sides:
		if s > 0:
			positives += 1
		elif s < 0:
			negatives += 1

	# Wholly one side (vertices lying on the plane do not force a split).
	if negatives == 0:
		positive.add_triangle(surface, v, n, uv)
		return
	if positives == 0:
		negative.add_triangle(surface, v, n, uv)
		return

	# Straddles: exactly one vertex is alone on its side. Find it, so the
	# split is always "lone vertex + the two others".
	var lone := 0
	for i in 3:
		var a: int = sides[i]
		var b: int = sides[(i + 1) % 3]
		var c: int = sides[(i + 2) % 3]
		if a != 0 and (b == -a or b == 0) and (c == -a or c == 0):
			lone = i
			break

	var i0 := lone
	var i1 := (lone + 1) % 3
	var i2 := (lone + 2) % 3

	# The two points where the triangle's edges pierce the plane.
	var e1 := _intersect(v[i0], v[i1], n[i0], n[i1], uv[i0], uv[i1], d[i0], d[i1])
	var e2 := _intersect(v[i0], v[i2], n[i0], n[i2], uv[i0], uv[i2], d[i0], d[i2])

	var lone_half: Half = positive if sides[i0] > 0 else negative
	var other_half: Half = negative if sides[i0] > 0 else positive

	# Lone vertex keeps one triangle; the opposite edge becomes a quad, which
	# is two triangles. Winding is preserved by construction: each new triangle
	# lists its vertices in the same rotational order as the source, so no
	# after-the-fact winding fix is needed.
	lone_half.add_triangle(surface,
		[v[i0], e1["v"], e2["v"]],
		[n[i0], e1["n"], e2["n"]],
		[uv[i0], e1["uv"], e2["uv"]])

	other_half.add_triangle(surface,
		[e1["v"], v[i1], v[i2]],
		[e1["n"], n[i1], n[i2]],
		[e1["uv"], uv[i1], uv[i2]])
	other_half.add_triangle(surface,
		[e1["v"], v[i2], e2["v"]],
		[e1["n"], n[i2], e2["n"]],
		[e1["uv"], uv[i2], e2["uv"]])

	# Both sides record the same boundary segment; it is the seam each will
	# cap, from opposite directions.
	positive.cap_points.append(e1["v"])
	positive.cap_points.append(e2["v"])
	negative.cap_points.append(e1["v"])
	negative.cap_points.append(e2["v"])


# Where the segment a->b crosses the plane, with normal and UV carried along.
#
# Uses the analytic form rather than a ray intersection: it is faster and has
# no null case to guard (ViewFinder.txt §6.3).
static func _intersect(a: Vector3, b: Vector3, na: Vector3, nb: Vector3,
		ua: Vector2, ub: Vector2, da: float, db: float) -> Dictionary:
	var denom := da - db
	# Parallel to the plane: both ends equidistant. Fall back to the midpoint
	# rather than dividing by ~zero.
	var t := 0.5 if absf(denom) < EPSILON else da / denom
	t = clampf(t, 0.0, 1.0)
	return {
		"v": a.lerp(b, t),
		"n": na.lerp(nb, t).normalized(),
		"uv": ua.lerp(ub, t),
	}


# Build the ArrayMesh for one side, appending the cap as its own final surface.
static func _commit(half: Half, source: Mesh, plane: Plane, flip: bool,
		cap_material: Material) -> ArrayMesh:
	var out := ArrayMesh.new()

	for surface_i in half.surfaces.size():
		var s: Dictionary = half.surfaces[surface_i]
		if s["verts"].is_empty():
			continue

		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s["verts"]
		arrays[Mesh.ARRAY_NORMAL] = s["normals"]
		arrays[Mesh.ARRAY_TEX_UV] = s["uvs"]
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		# Carry the source material across so a cut prop still looks like
		# itself. Surface indices shift when an earlier surface contributed
		# nothing, so map by the material we just read.
		var material := source.surface_get_material(surface_i)
		if material != null:
			out.surface_set_material(out.get_surface_count() - 1, material)

	_add_cap(out, half.cap_points, plane, flip, cap_material)
	return out


# Seal the cut, one triangle fan per closed seam loop.
#
# The seam arrives as an unordered soup of segments. It is chained back into
# loops (_boundary_loops) before any fan is built, because a single global
# angular sort silently bridges disjoint loops: slice a torus and the seam is
# two rings, and sorting all their points by angle around one shared centroid
# stitches the inner ring to the outer one, producing a cap that visibly spans
# the hole. Each loop is capped around its OWN centroid instead, so a hole in a
# prop stays a hole.
#
# The fan is still a centroid fan, so a strongly non-convex loop can bulge
# slightly outside its true outline. That is a far smaller error than bridging,
# and correct for the convex-ish seams a frustum cut produces on props.
static func _add_cap(out: ArrayMesh, points: PackedVector3Array, plane: Plane,
		flip: bool, cap_material: Material) -> void:
	if points.size() < 3:
		return

	# An orthonormal basis in the plane, shared by every loop so the cross
	# section's UVs are consistent across the whole cut. Building `right` from an
	# axis that is not parallel to the normal avoids the degenerate cross product
	# that leaves the original implementation's cap UVs constant.
	var normal := plane.normal
	var reference := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var right := normal.cross(reference).normalized()
	var forward := normal.cross(right).normalized()

	var loops := _boundary_loops(points)
	if loops.is_empty():
		return

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()

	# The positive half lies in the direction of plane.normal, so its exposed
	# cut face points BACK toward the negative half. The negative half faces the
	# opposite way. `flip` is false for positive and true for negative in
	# _commit(), hence this deliberately looks inverted relative to the plane.
	var cap_normal := normal if flip else -normal

	for loop in loops:
		var ring: Array = loop
		if ring.size() < 3:
			continue

		var center := Vector3.ZERO
		for p in ring:
			center += p
		center /= float(ring.size())

		# Wind each loop the same way in the plane before fanning it: the chain
		# walk follows whatever direction the segments happened to be emitted
		# in, so half the loops arrive reversed and would cap inside-out.
		if _loop_is_clockwise(ring, center, right, forward):
			ring.reverse()

		for i in ring.size():
			var a: Vector3 = ring[i]
			var b: Vector3 = ring[(i + 1) % ring.size()]
			# `ring` is normalised to counter-clockwise in the (right, forward)
			# basis, whose cross product is plane.normal. Negative pieces keep
			# that winding; positive pieces reverse it to face -plane.normal.
			var tri: Array = [center, a, b] if flip else [center, b, a]
			for v in tri:
				var vertex: Vector3 = v
				verts.append(vertex)
				normals.append(cap_normal)
				var d: Vector3 = vertex - center
				uvs.append(Vector2(0.5 + d.dot(right), 0.5 + d.dot(forward)))

	if verts.is_empty():
		return

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if cap_material != null:
		out.surface_set_material(out.get_surface_count() - 1, cap_material)


# Chain the seam's unordered segment soup into separate closed loops.
#
# `points` is a flat list of segment endpoint pairs (a0,b0, a1,b1, ...) emitted
# in triangle order, which is effectively random around the seam. Endpoints are
# welded first (see _weld) so the two triangles either side of a source edge,
# whose intersection points can differ by float noise, agree on one shared
# vertex — without welding nothing connects and every segment becomes its own
# two-point stub, which caps nothing.
#
# Returns Array[Array[Vector3]], each entry a loop in walk order.
static func _boundary_loops(points: PackedVector3Array) -> Array:
	# Welded vertex ids, and the adjacency between them.
	var ids: Array[int] = []
	var unique: Array[Vector3] = []
	var lookup := {}

	for p in points:
		var id := _weld(p, lookup, unique)
		ids.append(id)

	# Adjacency as id -> Array[int]. A well-formed seam gives every vertex
	# exactly two neighbours; degenerate geometry can give one or three, and the
	# walk below is written not to trust the count.
	var neighbours := {}
	var i := 0
	while i + 1 < ids.size():
		var a: int = ids[i]
		var b: int = ids[i + 1]
		i += 2
		if a == b:
			continue
		for pair in [[a, b], [b, a]]:
			var from: int = pair[0]
			var to: int = pair[1]
			if not neighbours.has(from):
				neighbours[from] = []
			if not neighbours[from].has(to):
				neighbours[from].append(to)

	var loops: Array = []
	var visited := {}

	for start in unique.size():
		if visited.has(start) or not neighbours.has(start):
			continue

		# Walk the chain from `start`, always stepping forward rather than back
		# over the edge we just used. Only a chain that returns to `start` is a
		# cap boundary. Closing an open/non-manifold chain with an invented edge
		# creates collision geometry the artwork never contained, so those chains
		# are deliberately left uncapped.
		var loop: Array = []
		var previous := -1
		var current: int = start
		var closed := false
		while current != -1:
			if visited.has(current):
				break
			visited[current] = true
			loop.append(unique[current])
			var next := -1
			for candidate in neighbours[current]:
				if candidate == start and loop.size() >= 3:
					next = start
					break
				if candidate != previous and not visited.has(candidate) \
						and neighbours.has(candidate):
					next = candidate
					break
			if next == start:
				closed = true
				break
			previous = current
			current = next

		if closed and loop.size() >= 3:
			loops.append(loop)

	return loops


# Find or create the welded id for a seam point.
#
# Spatial hash rather than an all-pairs comparison: at the triangle budget a seam
# can carry thousands of points, and O(n^2) welding would cost more than the cut
# itself.
#
# The 27 neighbouring cells are probed, not just the point's own cell. Two values
# a nanometre apart can straddle a grid line and land in different cells, which
# would leave the seam unchained and every segment its own stub — so the grid
# locates candidates and the distance test decides.
static func _weld(p: Vector3, lookup: Dictionary, unique: Array[Vector3]) -> int:
	var cell := _weld_cell(p)
	for dx in [0, -1, 1]:
		for dy in [0, -1, 1]:
			for dz in [0, -1, 1]:
				var key := cell + Vector3i(dx, dy, dz)
				if not lookup.has(key):
					continue
				for candidate in lookup[key]:
					var id: int = candidate
					if unique[id].distance_squared_to(p) <= WELD_GRID * WELD_GRID:
						return id

	var new_id := unique.size()
	unique.append(p)
	if not lookup.has(cell):
		lookup[cell] = []
	lookup[cell].append(new_id)
	return new_id


static func _weld_cell(p: Vector3) -> Vector3i:
	return Vector3i(
		floori(p.x / WELD_GRID),
		floori(p.y / WELD_GRID),
		floori(p.z / WELD_GRID))


# Signed area of a loop projected into the cut plane, as a winding test.
static func _loop_is_clockwise(loop: Array, center: Vector3, right: Vector3,
		forward: Vector3) -> bool:
	var area := 0.0
	for i in loop.size():
		var a: Vector3 = loop[i] - center
		var b: Vector3 = loop[(i + 1) % loop.size()] - center
		var ax := a.dot(right)
		var ay := a.dot(forward)
		var bx := b.dot(right)
		var by := b.dot(forward)
		area += ax * by - bx * ay
	return area < 0.0
