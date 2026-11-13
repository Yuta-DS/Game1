# Self-check for saving and restoring placed seeings (ViewFinder.txt §R5).
#   godot --headless --path artea --script res://scripts/test_lens_persistence.gd
#
# Placed geometry is generated at runtime and has no source asset, so it is
# saved by recording the CUT (two player poses) and replaying it, not by
# serializing meshes. These checks are mostly about the failure modes: a
# corrupt file, a stale record, and a malformed transform must all degrade to
# "you lose some placements", never to a crash or geometry in a random place.
extends SceneTree

const LensScript := preload("res://scripts/viewfinder/viewfinder_lens.gd")
const FrustumCutterScript := preload("res://scripts/viewfinder/frustum_cutter.gd")
const LensPersistence := preload("res://scripts/viewfinder/lens_persistence.gd")

# Never the real placements file.
const TEST_SAVE := "res://.godot/test_lens_placements.json"

var _root: Node3D
var _camera: Camera3D
var _capture_point: Node3D
var _lens: Node3D


func _initialize() -> void:
	_build_world()
	await process_frame
	_place_camera(Vector3.ZERO)
	await physics_frame
	await physics_frame

	_test_round_trip()
	_test_corrupt_file_is_survivable()
	_test_malformed_records_are_dropped()
	await _test_replay_rebuilds_geometry()
	await _test_stale_record_does_not_abort_the_rest()

	LensPersistence.clear(TEST_SAVE)
	print("lens persistence: all checks passed")
	quit()


func _build_world() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	_camera = Camera3D.new()
	_camera.fov = 70.0
	_root.add_child(_camera)

	_capture_point = Node3D.new()
	_root.add_child(_capture_point)

	_lens = LensScript.new()
	_root.add_child(_lens)
	_lens.camera = _camera
	_lens.capture_point = _capture_point


func _place_camera(position: Vector3) -> void:
	_camera.global_transform = Transform3D(Basis(), position)
	_capture_point.global_transform = _camera.global_transform


func _add_prop(position: Vector3, size := Vector3(6, 6, 1)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = FrustumCutterScript.CUTTABLE_MASK
	body.collision_mask = 0

	var box := BoxMesh.new()
	box.size = size
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	var mesh_instance := MeshInstance3D.new()
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


func _test_round_trip() -> void:
	var taken := Transform3D(Basis(Vector3.UP, 0.7), Vector3(1, 2, 3))
	var placed := Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(-4, 5, 6))

	var record := LensPersistence.make_record(taken, placed, 4)
	assert(LensPersistence.save_placements([record], TEST_SAVE), "placements save")

	var loaded: Array = LensPersistence.load_placements(TEST_SAVE)
	assert(loaded.size() == 1, "one placement survives the round trip")
	assert(int(loaded[0]["roll_steps"]) == 4, "the turn survives too")

	# Poses must come back accurately, or a restored seeing lands somewhere the
	# player never put it.
	var back_taken: Transform3D = LensPersistence._array_to_transform(loaded[0]["taken_from"])
	var back_placed: Transform3D = LensPersistence._array_to_transform(loaded[0]["placed_at"])
	assert(back_taken.origin.distance_to(taken.origin) < 0.0001,
		"the capture position round trips")
	assert(back_placed.origin.distance_to(placed.origin) < 0.0001,
		"the placement position round trips")
	assert(back_taken.basis.get_rotation_quaternion().dot(
		taken.basis.get_rotation_quaternion()) > 0.9999,
		"the capture orientation round trips")

	LensPersistence.clear(TEST_SAVE)
	assert(LensPersistence.load_placements(TEST_SAVE).is_empty(),
		"clearing removes every placement")


func _test_corrupt_file_is_survivable() -> void:
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file = null

	# A corrupt file costs the player their placements, not their session.
	assert(LensPersistence.load_placements(TEST_SAVE).is_empty(),
		"a corrupt placements file loads as empty instead of crashing")
	LensPersistence.clear(TEST_SAVE)

	# A missing file is simply "nothing placed yet".
	assert(LensPersistence.load_placements(TEST_SAVE).is_empty(),
		"a missing file is not an error")


func _test_malformed_records_are_dropped() -> void:
	var good := LensPersistence.make_record(
		Transform3D.IDENTITY, Transform3D.IDENTITY, 0)

	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"placements": [
		good,
		{"taken_from": [1, 2, 3], "placed_at": []},          # wrong length
		{"placed_at": LensPersistence._transform_to_array(Transform3D.IDENTITY)},
		{"taken_from": "nonsense", "placed_at": "nonsense"},  # wrong type
		"not even a dictionary",
	]}))
	file = null

	var loaded: Array = LensPersistence.load_placements(TEST_SAVE)
	assert(loaded.size() == 1,
		"malformed records are dropped rather than replayed as garbage "
		+ "transforms that would cut a hole somewhere arbitrary")
	LensPersistence.clear(TEST_SAVE)


func _test_replay_rebuilds_geometry() -> void:
	var prop := _add_prop(Vector3(0, 0, -5))
	await physics_frame
	await physics_frame

	# Do a real capture and placement, recording the poses as the controller
	# would.
	var taken := _camera.global_transform
	assert(_lens.capture(), "captured")
	_place_camera(Vector3(40, 0, 0))
	await physics_frame
	var placed := _camera.global_transform
	assert(_lens.place(), "placed")
	await physics_frame

	var record := LensPersistence.make_record(taken, placed, 0)

	# Wipe every fragment, as a scene reload would.
	for child in _root.get_children():
		if child is StaticBody3D and String(child.name).ends_with("_fragment"):
			child.queue_free()
	await physics_frame
	await physics_frame

	# Replay drives the same public API the player does.
	var mover := func(pose: Transform3D) -> void:
		_camera.global_transform = pose
		_capture_point.global_transform = pose

	var restored: int = LensPersistence.replay(_lens, [record], mover)
	assert(restored == 1, "the saved placement is replayed")
	await physics_frame
	await physics_frame

	# And the restored geometry is solid, not just visible.
	var space := _root.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(40, 0, 0), Vector3(40, 0, -9))
	query.collision_mask = FrustumCutterScript.CUTTABLE_MASK
	assert(not space.intersect_ray(query).is_empty(),
		"replayed geometry is solid, so a reload does not leave the player "
		+ "standing on something they can fall through")

	_place_camera(Vector3.ZERO)
	prop.queue_free()
	await physics_frame


func _test_stale_record_does_not_abort_the_rest() -> void:
	# A record whose prop no longer exists: capture will find nothing.
	var stale := LensPersistence.make_record(
		Transform3D(Basis(), Vector3(500, 500, 500)),
		Transform3D(Basis(), Vector3(520, 500, 500)), 0)

	var prop := _add_prop(Vector3(0, 0, -5))
	await physics_frame
	await physics_frame

	var live := LensPersistence.make_record(
		Transform3D(Basis(), Vector3.ZERO),
		Transform3D(Basis(), Vector3(40, 0, 0)), 0)

	var mover := func(pose: Transform3D) -> void:
		_camera.global_transform = pose
		_capture_point.global_transform = pose

	# The stale one is first: if it aborted the loop, the live one would be
	# lost too, and the player would lose everything for one bad record.
	var restored: int = LensPersistence.replay(_lens, [stale, live], mover)
	assert(restored == 1,
		"a stale record is skipped without costing the player the placements "
		+ "that are still valid")
	assert(not _lens.is_holding(),
		"replay never leaves the lens holding a seeing the player did not take")

	_place_camera(Vector3.ZERO)
	prop.queue_free()
	await physics_frame
