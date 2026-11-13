# Self-check for cap reconstruction when a cut produces MORE THAN ONE seam loop.
#   godot --headless --path artea --script res://scripts/test_cutter_cap_loops.gd
#
# This is the failure the first cutter shipped with: the cap was a single fan
# built by sorting every seam point by angle around one shared centroid, which
# stitches disjoint loops together. Slice a torus and the visible result is a
# solid disc spanning the hole — geometry the player can stand on that is not
# there.
#
# A torus is the cheapest fixture that produces the case: any plane through its
# axis-aligned body cuts two rings, an inner and an outer.
extends SceneTree

const MeshCutterScript := preload("res://scripts/viewfinder/mesh_cutter.gd")

const EPS := 0.0005
const CUT_OFFSET := 0.073


func _init() -> void:
	_test_torus_caps_two_loops_without_bridging()
	_test_hole_stays_open()
	_test_single_loop_still_caps()
	_test_cap_winding_is_consistent_per_loop()
	print("cutter cap loops: all checks passed")
	quit()


# A torus lying in the XZ plane, cut by a vertical plane through its centre.
# Kept coarse so it stays inside MAX_CUTTABLE_TRIANGLES.
func _torus(inner := 0.6, outer := 1.0) -> ArrayMesh:
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 24
	torus.ring_segments = 16
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, torus.get_mesh_arrays())
	return out


func _box(size := Vector3.ONE) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	return out


func _cap_arrays(mesh: ArrayMesh) -> Array:
	return mesh.surface_get_arrays(mesh.get_surface_count() - 1)


# The cross-section of a torus cut through its axis is two rings. The tube
# sections sit at |x| between inner and outer radius, so nothing in the cap may
# land near the torus centre — that is the hole.
func _test_torus_caps_two_loops_without_bridging() -> void:
	# Offset from the torus' authored vertex rings. A plane exactly on a ring is
	# the separate coplanar-vertex case; this fixture is specifically about two
	# ordinary disconnected seam loops.
	var plane := Plane(Vector3.FORWARD, CUT_OFFSET)
	var result: Dictionary = MeshCutterScript.cut(_torus(), plane)

	assert(result["positive"] != null and result["negative"] != null,
		"a plane through the torus cuts it")

	for key in ["positive", "negative"]:
		var mesh: ArrayMesh = result[key]
		var cap: PackedVector3Array = _cap_arrays(mesh)[Mesh.ARRAY_VERTEX]
		assert(cap.size() >= 9, "%s half has a cap" % key)

		for v in cap:
			assert(absf(plane.distance_to(v)) < EPS,
				"%s cap vertex %v is off the cut plane" % [key, v])

		# Two separate fans means two separate centroids: pooling the loops
		# would put every triangle's apex at the torus centre instead.
		var centres := _apex_positions(cap)
		assert(centres.size() >= 2,
			("each seam loop is capped around its own centroid, got %d distinct "
			+ "fan apexes on the %s half") % [centres.size(), key])
		for apex in centres:
			assert(absf(apex.x) > 0.3,
				("a fan apex at %v sits in the torus hole — the loops were "
				+ "bridged into one cap") % apex)


# Direct statement of the bug: no cap triangle may cover the hole's centre.
func _test_hole_stays_open() -> void:
	var plane := Plane(Vector3.FORWARD, CUT_OFFSET)
	var result: Dictionary = MeshCutterScript.cut(_torus(0.6, 1.0), plane)

	for key in ["positive", "negative"]:
		var mesh: ArrayMesh = result[key]
		var cap: PackedVector3Array = _cap_arrays(mesh)[Mesh.ARRAY_VERTEX]
		var i := 0
		while i + 2 < cap.size():
			# The torus axis is Y, so the hole's centre line is x == 0.
			var spans := _triangle_spans_axis(cap[i], cap[i + 1], cap[i + 2])
			assert(not spans,
				("%s cap triangle (%v %v %v) crosses the torus axis — the two "
				+ "seam loops were bridged") % [key, cap[i], cap[i + 1], cap[i + 2]])
			i += 3


# The ordinary case must not regress: a box cut is one loop, one fan.
func _test_single_loop_still_caps() -> void:
	var plane := Plane(Vector3.RIGHT, 0.0)
	var result: Dictionary = MeshCutterScript.cut(_box(), plane)

	for key in ["positive", "negative"]:
		var mesh: ArrayMesh = result[key]
		var cap: PackedVector3Array = _cap_arrays(mesh)[Mesh.ARRAY_VERTEX]
		assert(cap.size() >= 9, "%s half of a box is capped" % key)
		var apexes := _apex_positions(cap)
		assert(apexes.size() == 1,
			"a box's single seam loop makes one fan, got %d" % apexes.size())

	# Watertightness is the real test of the cap: signed volume only comes out
	# right if the seam is sealed.
	var halves: float = _volume(result["positive"]) + _volume(result["negative"])
	assert(absf(halves - 1.0) < 0.01,
		"a capped unit box's halves still sum to 1.0, got %f" % halves)


# Every triangle in one cap must wind the same way, or the cross-section
# flickers between front and back faces as the camera moves.
func _test_cap_winding_is_consistent_per_loop() -> void:
	var plane := Plane(Vector3.FORWARD, CUT_OFFSET)
	var result: Dictionary = MeshCutterScript.cut(_torus(), plane)

	for key in ["positive", "negative"]:
		var arrays := _cap_arrays(result[key])
		var cap: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		assert(normals.size() == cap.size(), "%s cap normals are complete" % key)

		var declared: Vector3 = normals[0]
		var i := 0
		while i + 2 < cap.size():
			var geometric := (cap[i + 1] - cap[i]).cross(cap[i + 2] - cap[i])
			# Degenerate slivers carry no winding information; skip them rather
			# than failing on noise.
			if geometric.length() > 1e-6:
				assert(geometric.normalized().dot(declared) > 0.0,
					("%s cap triangle %d winds against the cap normal — a loop "
					+ "was fanned inside-out") % [key, i / 3])
			i += 3


# The apex of a centroid fan is the repeated first vertex of every triangle.
# Distinct apexes = distinct loops.
func _apex_positions(cap: PackedVector3Array) -> Array:
	var found: Array = []
	var i := 0
	while i + 2 < cap.size():
		var apex: Vector3 = cap[i]
		var seen := false
		for q in found:
			if apex.distance_to(q) < 0.001:
				seen = true
				break
		if not seen:
			found.append(apex)
		i += 3
	return found


# Does this triangle straddle x == 0 (the torus axis)?
func _triangle_spans_axis(a: Vector3, b: Vector3, c: Vector3) -> bool:
	var min_x: float = minf(a.x, minf(b.x, c.x))
	var max_x: float = maxf(a.x, maxf(b.x, c.x))
	return min_x < -0.05 and max_x > 0.05


func _volume(mesh: ArrayMesh) -> float:
	var faces := mesh.get_faces()
	var total := 0.0
	var i := 0
	while i + 2 < faces.size():
		total += faces[i].cross(faces[i + 1]).dot(faces[i + 2]) / 6.0
		i += 3
	return absf(total)
