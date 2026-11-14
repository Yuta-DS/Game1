# Self-check for fragment collision, the seeing limit, and turning a held
# seeing.
#   godot --headless --path artea --script res://scripts/test_lens_collision.gd
#
# Fragment collision is the one that matters: bare MeshInstance3D fragments
# render correctly and are walked straight through, so a placed seeing that
# looks solid is not. Every assertion here is about geometry the player can
# actually stand on.
extends SceneTree

const LensScript := preload("res://scripts/viewfinder/viewfinder_lens.gd")
const FrustumCutterScript := preload("res://scripts/viewfinder/frustum_cutter.gd")

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

	await _test_fragments_are_solid()
	await _test_placed_geometry_stops_a_ray()
	await _test_seeing_limit()
	await _test_rotation_turns_the_whole_seeing()

	print("lens collision: all checks passed")
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


func _test_fragments_are_solid() -> void:
	var prop := _add_prop(Vector3(0, 0, -5))
	await physics_frame
	await physics_frame

	var cutter := _lens.find_child("FrustumCutter", false, false)
	var result: Dictionary = cutter.slice_frustum(_camera, 9.0)
	var fragments: Array = result["inside"] + result["outside"]
	assert(not fragments.is_empty(), "the cut produced fragments")

	for fragment in fragments:
		assert(fragment is StaticBody3D,
			"a fragment is a body, not a bare MeshInstance3D — otherwise the "
			+ "player walks through everything they place")

		var mesh_child: Node = fragment.find_child("Mesh", false, false)
		assert(mesh_child is MeshInstance3D, "the fragment carries its mesh")

		var collision: Node = fragment.find_child("Collision", false, false)
		assert(collision is CollisionShape3D, "the fragment carries a shape")
		assert(collision.shape != null, "the shape is real")

		# Concave pieces are the normal case for a frustum cut, so the shape
		# must be exact rather than a hull that fills in notches.
		assert(collision.shape is ConcavePolygonShape3D,
			"fragment collision is trimesh, so a cut notch is not filled in "
			+ "by a convex hull the player could stand on")
		assert(not collision.shape.get_faces().is_empty(), "the shape has faces")

		# Placed seeings stay cuttable, so a player can re-frame what they put
		# down instead of it becoming permanently inert.
		assert(fragment.collision_layer == FrustumCutterScript.CUTTABLE_MASK,
			"a fragment is itself cuttable")

	for fragment in fragments:
		fragment.queue_free()
	prop.queue_free()
	await physics_frame


# The real question: after a capture and a place, is there something there?
func _test_placed_geometry_stops_a_ray() -> void:
	var prop := _add_prop(Vector3(0, 0, -5))
	await physics_frame
	await physics_frame

	assert(_lens.capture(), "captured the prop")

	# While held, the seeing must be intangible — it rides inside the player's
	# own capsule, and live collision there would trap them.
	for fragment in _lens._held:
		var collision: Node = fragment.find_child("Collision", false, false)
		assert(collision.disabled,
			"a held seeing has no collision, so the player is not stuck "
			+ "inside what they are carrying")

	_place_camera(Vector3(40, 0, 0))
	await physics_frame
	assert(_lens.place(), "placed the seeing somewhere new")
	await physics_frame
	await physics_frame

	# Cast a ray from the camera through where the seeing was placed.
	var space := _root.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(40, 0, 0), Vector3(40, 0, -9))
	query.collision_mask = FrustumCutterScript.CUTTABLE_MASK
	var hit := space.intersect_ray(query)

	assert(not hit.is_empty(),
		"a ray into the placed seeing hits something — placed geometry is "
		+ "solid, not scenery")

	_place_camera(Vector3.ZERO)
	prop.queue_free()
	await physics_frame


func _test_seeing_limit() -> void:
	var lens_max: int = LensScript.MAX_SEEINGS
	assert(_lens.seeings_left() == lens_max,
		"the lens starts with a full complement of seeings")

	var prop := _add_prop(Vector3(0, 0, -5))
	await physics_frame
	await physics_frame

	assert(_lens.capture(), "capture succeeds")
	assert(_lens.seeings_left() == lens_max - 1, "taking a seeing costs one")

	# Releasing refunds: cancelling must never quietly burn the resource, or a
	# child is punished for changing their mind.
	_lens.release()
	assert(_lens.seeings_left() == lens_max,
		"putting a seeing back costs nothing")

	# Placing also refunds, so the player can never reach a dead end where
	# every seeing is spent and the puzzle is unsolvable.
	assert(_lens.capture(), "captured again")
	assert(_lens.seeings_left() == lens_max - 1, "spent one")
	_place_camera(Vector3(60, 0, 0))
	await physics_frame
	assert(_lens.place(), "placed it")
	assert(_lens.seeings_left() == lens_max, "placing returns the seeing")

	# The counter never exceeds the maximum.
	_lens.release()
	assert(_lens.seeings_left() == lens_max, "the count is capped at the max")

	_place_camera(Vector3.ZERO)
	prop.queue_free()
	await physics_frame


func _test_rotation_turns_the_whole_seeing() -> void:
	var prop := _add_prop(Vector3(0, 0, -5))
	await physics_frame
	await physics_frame

	assert(not _lens.rotate_held(), "nothing to turn before a capture")
	assert(_lens.capture(), "captured for the rotation test")
	assert(_lens.roll_steps() == 0, "a fresh seeing is unturned")

	# Relative offsets between fragments must survive the turn, or a
	# multi-fragment seeing is torn apart by rotating each piece separately.
	var before: Array = []
	for fragment in _lens._held:
		before.append(fragment.global_position - _capture_point.global_position)

	assert(_lens.rotate_held(-1), "the held seeing turns")
	assert(_lens.roll_steps() == 11, "a turn of -30 degrees wraps to step 11")

	var after: Array = []
	for fragment in _lens._held:
		after.append(fragment.global_position - _capture_point.global_position)

	for i in before.size():
		assert(absf(before[i].length() - after[i].length()) < 0.001,
			"a turned fragment keeps its distance from the capture point")

	# Twelve steps of 30 degrees is a full turn, back to the start.
	for i in 11:
		_lens.rotate_held(-1)
	assert(_lens.roll_steps() == 0, "twelve turns of 30 degrees is a full circle")

	_lens.release()
	prop.queue_free()
	await physics_frame
