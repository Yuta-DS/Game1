# Self-check for the capture/place loop (ViewFinder build order S5/S6).
#   godot --headless --path artea --script res://scripts/test_viewfinder_lens.gd
#
# The property that matters most here is REVERSIBILITY: a child who frames the
# wrong thing must never be left with a hole they cannot undo. Capture hides
# the source, place and release both restore it.
extends SceneTree

const LensScript := preload("res://scripts/viewfinder/viewfinder_lens.gd")
const FrustumCutterScript := preload("res://scripts/viewfinder/frustum_cutter.gd")

var _root: Node3D
var _camera: Camera3D
var _capture_point: Node3D
var _lens: Node3D


func _initialize() -> void:
	_build_world()
	# The world nodes only become tree-resident on the next frame; positioning
	# before that reads identity transforms silently.
	await process_frame
	_place_camera(Vector3.ZERO)
	await physics_frame
	await physics_frame

	await _test_empty_frame_is_refused()
	await _test_capture_then_place()
	await _test_release_restores_the_world()
	await _test_cannot_hold_two_seeings()

	print("viewfinder lens: all checks passed")
	quit()


func _build_world() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	_camera = Camera3D.new()
	_camera.fov = 70.0
	_root.add_child(_camera)

	# Stands in for the player's hand: the held seeing parents here, so its
	# pose relative to this node is the photograph.
	_capture_point = Node3D.new()
	_root.add_child(_capture_point)

	_lens = LensScript.new()
	_root.add_child(_lens)
	_lens.camera = _camera
	_lens.capture_point = _capture_point


# Move the player's viewpoint, keeping the capture point with it. The held
# seeing is parented to the capture point, so these two must never drift apart
# or a placement would land offset from where it was framed.
func _place_camera(position: Vector3) -> void:
	_camera.global_transform = Transform3D(Basis(), position)
	_capture_point.global_transform = _camera.global_transform


func _add_prop(position: Vector3, size := Vector3(14, 14, 1)) -> StaticBody3D:
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


func _test_empty_frame_is_refused() -> void:
	var reasons: Array = []
	_lens.capture_refused.connect(func(r: String) -> void: reasons.append(r))

	assert(not _lens.capture(), "an empty frame does not capture")
	assert(not _lens.is_holding(), "nothing is held after a refused capture")
	assert(reasons.size() == 1,
		"the player is told why, rather than being handed an empty pane")

	# Placing with nothing held is refused too, not silently ignored.
	assert(not _lens.place(), "placing with nothing held is refused")
	assert(reasons.size() == 2, "the refusal is explained")


func _test_capture_then_place() -> void:
	var prop := _add_prop(Vector3(0, 0, -6))
	await physics_frame
	await physics_frame

	var captured: Array = []
	_lens.seeing_captured.connect(func(n: int) -> void: captured.append(n))

	assert(_lens.capture(), "a framed prop is captured")
	assert(_lens.is_holding(), "the seeing is held")
	assert(captured.size() == 1 and captured[0] > 0, "the capture reports fragments")

	# The source is hidden, so the world shows the gap the player carries.
	assert(not prop.visible, "the source prop is hidden while its seeing is held")

	# The held fragments travel with the capture point — that relationship is
	# what makes placement exact without any projection maths.
	for fragment in _lens._held:
		assert(fragment.get_parent() == _capture_point,
			"a held fragment is parented to the capture point")
		assert(not fragment.visible, "a held fragment is not drawn in the world")

	# Move the player before placing, so the seeing genuinely lands somewhere
	# other than where it was taken from.
	_place_camera(Vector3(30, 0, 0))
	await physics_frame

	var placed: Array = []
	_lens.seeing_placed.connect(func(n: int) -> void: placed.append(n))

	assert(_lens.place(), "the held seeing is placed")
	assert(not _lens.is_holding(), "nothing is held after placing")
	assert(placed.size() == 1 and placed[0] > 0, "the placement reports fragments")
	assert(prop.visible,
		"the source is restored — a capture moves a seeing, it does not "
		+ "destroy the place it came from")

	prop.queue_free()
	_place_camera(Vector3.ZERO)
	await physics_frame


func _test_release_restores_the_world() -> void:
	var prop := _add_prop(Vector3(0, 0, -6))
	await physics_frame
	await physics_frame

	assert(_lens.capture(), "captured for the release test")
	assert(not prop.visible, "source hidden during the hold")

	_lens.release()
	assert(not _lens.is_holding(), "release drops the seeing")
	assert(prop.visible,
		"release puts the world back — framing the wrong thing is always undoable")

	prop.queue_free()
	await physics_frame


func _test_cannot_hold_two_seeings() -> void:
	var prop := _add_prop(Vector3(0, 0, -6))
	await physics_frame
	await physics_frame

	assert(_lens.capture(), "first capture succeeds")
	var refusals: Array = []
	_lens.capture_refused.connect(func(r: String) -> void: refusals.append(r))
	assert(not _lens.capture(), "a second capture while holding is refused")
	assert(refusals.size() == 1, "the player is told they are already carrying one")

	_lens.release()
	prop.queue_free()
	await physics_frame
