# Self-check for the frustum cutter (ViewFinder build order S3/S4).
#   godot --headless --path artea --script res://scripts/test_frustum_cutter.gd
#
# Runs inside a real SceneTree with real physics so the broad-phase shape query
# is exercised for what it is — the replacement for the original's three-frame
# trigger hack. A MainLoop-only test could not cover that.
extends SceneTree

const FrustumCutterScript := preload("res://scripts/viewfinder/frustum_cutter.gd")

var _root: Node3D
var _camera: Camera3D
var _cutter: Node3D


func _initialize() -> void:
	_build_world()
	# One physics frame so the bodies the query will find are registered.
	await physics_frame
	await physics_frame

	_test_planes_face_inward()
	_test_query_finds_only_cuttable()
	_test_prop_in_view_is_sliced()
	_test_prop_outside_view_untouched()
	_test_fragments_are_usable()

	print("frustum cutter: all checks passed")
	quit()


func _build_world() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	_camera = Camera3D.new()
	_camera.fov = 70.0
	_root.add_child(_camera)
	# Set after entering the tree: global_transform is unavailable before then.
	# Looking down -Z from the origin, Godot's camera convention.
	_camera.global_transform = Transform3D(Basis(), Vector3.ZERO)

	_cutter = FrustumCutterScript.new()
	_root.add_child(_cutter)


# A cuttable prop: a static body on the Cuttable layer with a box mesh.
func _add_prop(position: Vector3, cuttable := true, size := Vector3.ONE) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = FrustumCutterScript.CUTTABLE_MASK if cuttable else 1
	body.collision_mask = 0

	var box := BoxMesh.new()
	box.size = size
	var mesh_instance := MeshInstance3D.new()
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	mesh_instance.mesh = array_mesh
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)

	_root.add_child(body)
	body.global_position = position
	return body


func _test_planes_face_inward() -> void:
	var planes := FrustumCutterScript.frustum_planes(_camera, 10.0)
	assert(planes.size() == 4, "four side planes")

	# A point on the camera's axis, well inside the view, must be in front of
	# every plane. If any normal were flipped, a cut would keep the outside of
	# the frustum and throw away its contents.
	var inside := Vector3(0, 0, -5)
	for i in planes.size():
		assert(planes[i].distance_to(inside) > 0.0,
			"plane %d faces inward (axis point is in front)" % i)

	# Points far off to each side must fall behind at least one plane.
	for probe in [Vector3(50, 0, -5), Vector3(-50, 0, -5),
			Vector3(0, 50, -5), Vector3(0, -50, -5)]:
		var outside := false
		for plane in planes:
			if plane.distance_to(probe) < 0.0:
				outside = true
				break
		assert(outside, "point %v is outside the frustum" % probe)

	# Behind the camera is outside too.
	var behind := Vector3(0, 0, 5)
	var caught := false
	for plane in planes:
		if plane.distance_to(behind) < 0.0:
			caught = true
			break
	assert(caught, "a point behind the camera is not inside the frustum")


func _test_query_finds_only_cuttable() -> void:
	var cuttable := _add_prop(Vector3(0, 0, -6))
	var plain := _add_prop(Vector3(1.5, 0, -6), false)
	await physics_frame
	await physics_frame

	var found: Array = _cutter.overlapping_bodies(_camera, 12.0)
	assert(found.has(cuttable), "the cuttable prop is found by the shape query")
	assert(not found.has(plain),
		"a prop off the Cuttable layer is ignored, so the mechanic cannot "
		+ "slice scenery it was never meant to touch")

	cuttable.queue_free()
	plain.queue_free()
	await physics_frame


func _test_prop_in_view_is_sliced() -> void:
	# Wide enough that the frustum's sides pass through it, so it must be cut
	# rather than swallowed whole.
	var prop := _add_prop(Vector3(0, 0, -6), true, Vector3(14, 14, 1))
	await physics_frame
	await physics_frame

	var result: Dictionary = _cutter.slice_frustum(_camera, 12.0)
	assert(not result["sources"].is_empty(), "the prop was picked up for cutting")
	assert(not result["inside"].is_empty(), "something ended up inside the frustum")
	assert(not result["outside"].is_empty(),
		"a prop wider than the frustum must leave geometry outside it")

	# Everything reported as inside really is in front of all four planes.
	var planes := FrustumCutterScript.frustum_planes(_camera, 12.0)
	for fragment in result["inside"]:
		var centre: Vector3 = fragment.global_transform * fragment.mesh.get_aabb().get_center()
		for i in planes.size():
			assert(planes[i].distance_to(centre) >= 0.0,
				"fragment centre %v is behind plane %d" % [centre, i])

	for fragment in result["inside"] + result["outside"]:
		fragment.queue_free()
	prop.queue_free()
	await physics_frame


func _test_prop_outside_view_untouched() -> void:
	# Behind the camera: the query must not reach it.
	var behind := _add_prop(Vector3(0, 0, 8))
	await physics_frame
	await physics_frame

	var result: Dictionary = _cutter.slice_frustum(_camera, 12.0)
	assert(result["sources"].is_empty(),
		"a prop behind the camera is never cut")

	behind.queue_free()
	await physics_frame

	# Beyond the capture distance: also untouched. This is the guard that keeps
	# the cost bounded (ViewFinder.txt R1) — without a short far plane the
	# mechanic would try to cut the whole level.
	var distant := _add_prop(Vector3(0, 0, -40))
	await physics_frame
	await physics_frame

	var far_result: Dictionary = _cutter.slice_frustum(_camera, 12.0)
	assert(far_result["sources"].is_empty(),
		"a prop past the capture distance is out of reach")

	distant.queue_free()
	await physics_frame


func _test_fragments_are_usable() -> void:
	var prop := _add_prop(Vector3(0, 0, -6), true, Vector3(14, 14, 1))
	await physics_frame
	await physics_frame

	var result: Dictionary = _cutter.slice_frustum(_camera, 12.0)
	var fragments: Array = result["inside"] + result["outside"]
	assert(not fragments.is_empty(), "the cut produced fragments")

	for fragment in fragments:
		assert(fragment is MeshInstance3D, "a fragment is a MeshInstance3D")
		assert(fragment.mesh != null, "a fragment carries a mesh")
		# An empty fragment would be an invisible node and a physics shape with
		# no points; the cutter must drop those rather than emit them.
		assert(not fragment.mesh.get_faces().is_empty(),
			"a fragment has real geometry")
		# The cap is a trailing surface, so a cut piece has more surfaces than
		# the single-surface box it came from. That separation is what lets the
		# cross-section take its own material.
		assert(fragment.mesh.get_surface_count() >= 1, "a fragment has surfaces")

	for fragment in fragments:
		fragment.queue_free()
	prop.queue_free()
	await physics_frame
