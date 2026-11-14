# Self-check for the single-plane mesh cutter (ViewFinder build order S1/S2).
#   godot --headless --path artea --script res://scripts/test_mesh_cutter.gd
#
# The cutter is the one piece that can be subtly, invisibly wrong while
# everything downstream still appears to run, so it is tested with no camera,
# no input and no physics — just meshes and planes.
extends SceneTree

const MeshCutterScript := preload("res://scripts/viewfinder/mesh_cutter.gd")

const EPS := 0.0005


func _init() -> void:
	_test_plane_through_middle()
	_test_volume_is_conserved()
	_test_cap_seals_both_halves()
	_test_miss_returns_nothing()
	_test_materials_survive()
	_test_triangle_budget()
	_test_degenerate_inputs()
	print("mesh cutter: all checks passed")
	quit()


func _box(size := Vector3.ONE) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	# BoxMesh is a PrimitiveMesh; bake it to an ArrayMesh so the cutter reads
	# the same shape of data it will see from an imported .glb.
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	return out


# Every vertex of a half must sit on its own side of the plane (within
# epsilon). This is what catches a cut that "looks right" but leaks geometry.
func _assert_side(mesh: ArrayMesh, plane: Plane, want_positive: bool, label: String) -> void:
	assert(mesh != null, "%s: mesh exists" % label)
	assert(mesh.get_surface_count() > 0, "%s: has geometry" % label)

	for surface_i in mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.surface_get_arrays(surface_i)[Mesh.ARRAY_VERTEX]
		for v in verts:
			var d := plane.distance_to(v)
			if want_positive:
				assert(d > -EPS, "%s: vertex %v leaked to the negative side (d=%f)" % [label, v, d])
			else:
				assert(d < EPS, "%s: vertex %v leaked to the positive side (d=%f)" % [label, v, d])


func _tri_count(mesh: ArrayMesh) -> int:
	return mesh.get_faces().size() / 3


# Signed volume via the divergence theorem. For a closed surface this is the
# enclosed volume; for an unsealed one it is wrong — which is exactly why it
# doubles as the "is it capped" test below.
#
# Uses get_faces() rather than ARRAY_VERTEX: source meshes from BoxMesh/.glb
# are INDEXED (a unit box is 24 verts + 36 indices), so walking the vertex
# array in threes reads garbage triangles. get_faces() returns the expanded
# triangle soup for indexed and non-indexed surfaces alike.
func _volume(mesh: ArrayMesh) -> float:
	var faces := mesh.get_faces()
	var total := 0.0
	var i := 0
	while i + 2 < faces.size():
		total += faces[i].cross(faces[i + 1]).dot(faces[i + 2]) / 6.0
		i += 3
	return absf(total)


func _test_plane_through_middle() -> void:
	var mesh := _box()
	var plane := Plane(Vector3.RIGHT, 0.0)
	var result: Dictionary = MeshCutterScript.cut(mesh, plane)

	_assert_side(result["positive"], plane, true, "half through middle (+)")
	_assert_side(result["negative"], plane, false, "half through middle (-)")

	# An off-centre cut must still divide cleanly.
	var offset := Plane(Vector3.RIGHT, 0.25)
	var skewed: Dictionary = MeshCutterScript.cut(_box(), offset)
	_assert_side(skewed["positive"], offset, true, "off-centre (+)")
	_assert_side(skewed["negative"], offset, false, "off-centre (-)")

	# A diagonal plane exercises the straddling-triangle path on every face.
	var diagonal := Plane(Vector3(1, 1, 1).normalized(), 0.0)
	var cut_diag: Dictionary = MeshCutterScript.cut(_box(), diagonal)
	_assert_side(cut_diag["positive"], diagonal, true, "diagonal (+)")
	_assert_side(cut_diag["negative"], diagonal, false, "diagonal (-)")


func _test_volume_is_conserved() -> void:
	var plane := Plane(Vector3.RIGHT, 0.0)
	var result: Dictionary = MeshCutterScript.cut(_box(), plane)

	var whole := _volume(_box())
	var halves: float = _volume(result["positive"]) + _volume(result["negative"])
	assert(absf(whole - 1.0) < 0.01, "unit box measures 1.0, got %f" % whole)
	# Conservation only holds if both halves are watertight — an uncapped cut
	# reads as a smaller volume.
	assert(absf(halves - whole) < 0.01,
		"cut halves (%f) must sum to the whole (%f)" % [halves, whole])

	# Halved down the middle, each piece is half the box.
	assert(absf(_volume(result["positive"]) - 0.5) < 0.01, "positive half is 0.5")
	assert(absf(_volume(result["negative"]) - 0.5) < 0.01, "negative half is 0.5")


func _test_cap_seals_both_halves() -> void:
	var plane := Plane(Vector3.UP, 0.0)
	var result: Dictionary = MeshCutterScript.cut(_box(), plane)

	# The cap is written as its own trailing surface (S2): that separation is
	# what allows a distinct cross-section material.
	for key in ["positive", "negative"]:
		var mesh: ArrayMesh = result[key]
		assert(mesh.get_surface_count() >= 2,
			"%s half has a dedicated cap surface" % key)

		var cap_index := mesh.get_surface_count() - 1
		var cap_verts: PackedVector3Array = mesh.surface_get_arrays(cap_index)[Mesh.ARRAY_VERTEX]
		assert(cap_verts.size() >= 9, "%s cap has at least one triangle" % key)
		# Every cap vertex lies in the cut plane.
		for v in cap_verts:
			assert(absf(plane.distance_to(v)) < EPS,
				"%s cap vertex %v is off the cut plane" % [key, v])

	# The two caps face opposite ways, so neither half shows the other's
	# backfaces at the seam.
	var pos_n: PackedVector3Array = result["positive"].surface_get_arrays(
		result["positive"].get_surface_count() - 1)[Mesh.ARRAY_NORMAL]
	var neg_n: PackedVector3Array = result["negative"].surface_get_arrays(
		result["negative"].get_surface_count() - 1)[Mesh.ARRAY_NORMAL]
	assert(pos_n[0].dot(neg_n[0]) < -0.9,
		"cap normals oppose each other, got %v vs %v" % [pos_n[0], neg_n[0]])

	# Cap UVs must vary. The original implementation's degenerate basis left
	# the u coordinate pinned at 0.5 on every cap vertex.
	var cap_uvs: PackedVector2Array = result["positive"].surface_get_arrays(
		result["positive"].get_surface_count() - 1)[Mesh.ARRAY_TEX_UV]
	var distinct_u := {}
	for uv in cap_uvs:
		distinct_u[snappedf(uv.x, 0.001)] = true
	assert(distinct_u.size() > 1, "cap UVs vary across the cross-section")


func _test_miss_returns_nothing() -> void:
	# Entirely on one side: reported as "no cut" so callers can skip cheaply
	# instead of receiving a copy plus an empty shell.
	var far := Plane(Vector3.RIGHT, 50.0)
	var missed: Dictionary = MeshCutterScript.cut(_box(), far)
	assert(missed["positive"] == null and missed["negative"] == null,
		"a plane that misses the mesh cuts nothing")

	# Exactly tangent to the face: still not a cut, and must not produce a
	# zero-area sliver.
	var tangent := Plane(Vector3.RIGHT, 0.5)
	var grazed: Dictionary = MeshCutterScript.cut(_box(), tangent)
	assert(grazed["positive"] == null and grazed["negative"] == null,
		"a plane tangent to a face cuts nothing")


func _test_materials_survive() -> void:
	var mesh := _box()
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.2, 0.6, 1.0)
	mesh.surface_set_material(0, body)

	var cap := StandardMaterial3D.new()
	cap.albedo_color = Color(1.0, 0.9, 0.4)

	var result: Dictionary = MeshCutterScript.cut(mesh, Plane(Vector3.RIGHT, 0.0), cap)

	for key in ["positive", "negative"]:
		var half: ArrayMesh = result[key]
		assert(half.surface_get_material(0) == body,
			"%s half keeps the prop's own material" % key)
		assert(half.surface_get_material(half.get_surface_count() - 1) == cap,
			"%s half takes the cross-section material on its cap" % key)


func _test_triangle_budget() -> void:
	# The budget is the guard that keeps this affordable in GDScript. A sphere
	# with a high segment count clears it comfortably.
	var sphere := SphereMesh.new()
	sphere.radial_segments = 128
	sphere.rings = 128
	var dense := ArrayMesh.new()
	dense.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sphere.get_mesh_arrays())

	var tris := _tri_count(dense)
	assert(tris > MeshCutterScript.MAX_CUTTABLE_TRIANGLES,
		"test fixture is over budget (%d tris)" % tris)

	var refused: Dictionary = MeshCutterScript.cut(dense, Plane(Vector3.RIGHT, 0.0))
	assert(refused["positive"] == null and refused["negative"] == null,
		"an over-budget mesh is refused rather than stalling the frame")

	# A prop-sized mesh is still cut.
	var small := SphereMesh.new()
	small.radial_segments = 12
	small.rings = 6
	var prop := ArrayMesh.new()
	prop.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, small.get_mesh_arrays())
	assert(_tri_count(prop) <= MeshCutterScript.MAX_CUTTABLE_TRIANGLES,
		"prop fixture is within budget")
	var ok: Dictionary = MeshCutterScript.cut(prop, Plane(Vector3.RIGHT, 0.0))
	assert(ok["positive"] != null, "a prop-sized mesh is within budget")


func _test_degenerate_inputs() -> void:
	# These are the calls a live frustum will eventually make by accident. None
	# may crash — a failed cut must leave the world intact.
	var nothing: Dictionary = MeshCutterScript.cut(null, Plane(Vector3.RIGHT, 0.0))
	assert(nothing["positive"] == null, "a null mesh is handled")

	var empty: Dictionary = MeshCutterScript.cut(
		ArrayMesh.new(), Plane(Vector3.RIGHT, 0.0))
	assert(empty["positive"] == null, "a mesh with no surfaces is handled")

	# A surface with no normals or UVs: the cutter derives a face normal
	# rather than shipping a fallback that lights wrongly.
	var bare := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(0, 0, 1),
	])
	bare.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var bare_cut: Dictionary = MeshCutterScript.cut(bare, Plane(Vector3.RIGHT, 0.0))
	assert(bare_cut["positive"] != null, "a surface without normals or UVs is cut")
	var got: PackedVector3Array = bare_cut["positive"].surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert(got[0].is_normalized(), "a derived normal is unit length")
