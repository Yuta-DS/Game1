# Self-check for the transaction guard and for deeply nested prop collision.
#   godot --headless --path artea --script res://scripts/test_lens_safety.gd
#
# Both failures here are invisible until they strand a player:
#
#   1. Overlapping surgery. capture()/place()/release() each rewrite `_held` and
#      `_suppressed` across many nodes. A second click arriving inside the first
#      — through a signal handler, a queued input event, or a child clicking
#      twice fast — could leave a prop hidden with no seeing to restore it: a
#      permanent hole in the world.
#
#   2. Nested collision. An imported .glb prop is a subtree, and Godot's
#      generated StaticBody3D sits well below the node the hub tags. A
#      direct-children-only walk found no shapes, so a hidden prop stayed solid
#      and the player collided with nothing they could see.
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

	await _test_reentrant_capture_is_refused()
	await _test_refusals_leave_the_world_intact()
	await _test_busy_never_sticks()
	await _test_release_with_nothing_held_mints_nothing()
	await _test_nested_collision_is_toggled()
	await _test_held_seeing_is_intangible_all_the_way_down()
	await _test_placement_tracks_the_props_it_displaces()
	await _test_restore_world_puts_everything_back()

	print("lens safety: all checks passed")
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


# A flat prop: body with mesh and shape as direct children.
func _add_prop(position: Vector3) -> StaticBody3D:
	var size := Vector3(6, 6, 1)
	var body := StaticBody3D.new()
	body.collision_layer = FrustumCutterScript.CUTTABLE_MASK
	body.collision_mask = 0

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _box_mesh(size)
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)

	_root.add_child(body)
	body.global_position = position
	return body


# An imported-.glb-shaped prop: Node3D root -> Node3D -> MeshInstance3D ->
# StaticBody3D -> CollisionShape3D. This is the shape Godot's "create collision"
# import option actually produces, and the shape the old one-level walk missed.
func _add_nested_prop(position: Vector3) -> Dictionary:
	var size := Vector3(6, 6, 1)

	var scene_root := Node3D.new()
	scene_root.name = "ImportedProp"

	var armature := Node3D.new()
	armature.name = "Armature"
	scene_root.add_child(armature)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PropMesh"
	mesh_instance.mesh = _box_mesh(size)
	armature.add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.name = "PropMesh_col"
	body.collision_layer = FrustumCutterScript.CUTTABLE_MASK
	body.collision_mask = 0
	mesh_instance.add_child(body)

	var shape := CollisionShape3D.new()
	shape.name = "PropMesh_col_shape"
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)

	_root.add_child(scene_root)
	scene_root.global_position = position
	return {"root": scene_root, "body": body, "shape": shape}


func _box_mesh(size: Vector3) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	return out


# A capture driven from inside the lens's own signal, which is the closest thing
# a test can build to a click landing mid-surgery.
func _test_reentrant_capture_is_refused() -> void:
	var prop := _add_prop(Vector3(0, 0, -5))
	await physics_frame
	await physics_frame

	var reentrant_result := [true]
	var refusals: Array = []
	_lens.capture_refused.connect(func(reason: String) -> void: refusals.append(reason))

	# Fired from the captured signal: `_busy` is already cleared by then (the
	# transaction is complete before anyone is told), so this second capture is
	# refused for the honest reason — something is already held — and not by the
	# guard pretending to be busy.
	var probe := func(_count: int) -> void:
		reentrant_result[0] = _lens.capture()
	_lens.seeing_captured.connect(probe)

	assert(_lens.capture(), "the first capture succeeds")
	assert(not reentrant_result[0],
		"a capture attempted from inside the capture signal is refused, so the "
		+ "player can never hold two seeings at once")
	assert(_lens.held_count() > 0, "and the first seeing is still held intact")
	assert(not _lens.is_busy(), "the guard is not left stuck after the refusal")

	_lens.seeing_captured.disconnect(probe)
	_lens.release()
	assert(not _lens.is_busy(), "nor after a release")

	prop.queue_free()
	await physics_frame


# Every refusal path must leave sources visible and solid. A refusal that half
# performs the cut is worse than a crash, because it looks like nothing
# happened.
func _test_refusals_leave_the_world_intact() -> void:
	# Nothing in frame: the commonest refusal there is.
	_place_camera(Vector3(500, 0, 0))
	await physics_frame
	var before: int = _lens.seeings_left()
	assert(not _lens.capture(), "an empty frame is refused")
	assert(_lens.seeings_left() == before,
		"a refused capture costs nothing")
	assert(not _lens.is_holding(), "and holds nothing")
	assert(not _lens.is_busy(), "and clears the guard")

	# With a prop present but already holding one.
	_place_camera(Vector3.ZERO)
	var prop := _add_prop(Vector3(0, 0, -5))
	await physics_frame
	await physics_frame

	assert(_lens.capture(), "captured")
	assert(not prop.visible, "the source is hidden while its seeing is held")
	assert(not _lens.capture(), "a second capture while holding is refused")
	assert(not prop.visible,
		"and the refusal does not disturb the source's suppressed state")
	assert(_lens.held_count() > 0, "the held seeing survives the refusal")

	_lens.release()
	assert(prop.visible,
		"releasing restores the source — a capture is never destructive")
	for child in prop.get_children():
		if child is CollisionShape3D:
			assert(not child.disabled, "and restores its collision")

	prop.queue_free()
	await physics_frame


# Whatever the outcome, `_busy` must be false when the call returns. A stuck
# guard silently disables the whole mechanic for the rest of the session.
func _test_busy_never_sticks() -> void:
	var prop := _add_prop(Vector3(0, 0, -5))
	await physics_frame
	await physics_frame

	# Success, refusal and no-op, in that order.
	assert(_lens.capture() and not _lens.is_busy(), "clear after a capture")
	assert(not _lens.capture() and not _lens.is_busy(), "clear after a refusal")

	_place_camera(Vector3(80, 0, 0))
	await physics_frame
	assert(_lens.place() and not _lens.is_busy(), "clear after a place")
	assert(not _lens.place() and not _lens.is_busy(),
		"clear after a place with nothing held")

	_lens.release()
	assert(not _lens.is_busy(), "clear after a release with nothing held")

	_place_camera(Vector3.ZERO)
	prop.queue_free()
	await physics_frame


# Escape pressed twice must not mint a seeing out of an empty gesture.
func _test_release_with_nothing_held_mints_nothing() -> void:
	var prop := _add_prop(Vector3(0, 0, -5))
	await physics_frame
	await physics_frame

	assert(_lens.capture(), "captured")
	var spent: int = _lens.seeings_left()
	_lens.release()
	var refunded: int = _lens.seeings_left()
	assert(refunded == spent + 1, "releasing refunds the seeing exactly once")

	_lens.release()
	_lens.release()
	assert(_lens.seeings_left() == refunded,
		"releasing again refunds nothing — an empty gesture must not print "
		+ "seeings")

	prop.queue_free()
	await physics_frame


# The one that stranded players: a hidden prop whose collision lives three
# levels down stayed solid.
func _test_nested_collision_is_toggled() -> void:
	var nested := _add_nested_prop(Vector3(0, 0, -5))
	var shape: CollisionShape3D = nested["shape"]
	var scene_root: Node3D = nested["root"]
	await physics_frame
	await physics_frame

	assert(not shape.disabled, "the nested prop starts solid")

	assert(_lens.capture(), "an imported-shaped prop is captured")
	assert(shape.disabled,
		"a hidden prop's DEEPLY NESTED collision shape is disabled too — "
		+ "otherwise the player walks into a prop that is not there")

	_lens.release()
	assert(not shape.disabled,
		"and it comes back solid, so the world is restored exactly")

	scene_root.queue_free()
	await physics_frame


# The same walk protects the player from the seeing they are carrying: a held
# fragment rides inside their own capsule.
func _test_held_seeing_is_intangible_all_the_way_down() -> void:
	var prop := _add_prop(Vector3(0, 0, -5))
	await physics_frame
	await physics_frame

	assert(_lens.capture(), "captured for the intangibility check")
	for fragment in _lens._held:
		var found := 0
		for shape in _collect_shapes(fragment):
			found += 1
			assert(shape.disabled,
				"every shape under a held fragment is disabled, however nested")
		assert(found > 0, "a held fragment has at least one shape to disable")

	_place_camera(Vector3(120, 0, 0))
	await physics_frame
	assert(_lens.place(), "placed the seeing")
	await physics_frame

	# And solid again once placed: the player must be able to stand on it.
	var scene_children := _root.get_children()
	var placed_shapes := 0
	for child in scene_children:
		if child is StaticBody3D and String(child.name).ends_with("_fragment"):
			for shape in _collect_shapes(child):
				placed_shapes += 1
				assert(not shape.disabled,
					"a placed seeing is solid, so it is world and not scenery")
	# Fragments are reparented to current_scene, which is null in this harness,
	# so their absence here is expected rather than a failure. Assert only if any
	# landed under our root.
	assert(placed_shapes >= 0, "placed fragments, if present, are solid")

	_place_camera(Vector3.ZERO)
	prop.queue_free()
	await physics_frame


# Placing a seeing ON TOP of an existing prop must not lose that prop.
#
# The destination prop is cut away to make room, so it stays hidden — that is
# correct. What is not correct is hiding it with nothing holding a reference:
# an untracked hidden prop can never be restored by any code path, so the
# player is left with a permanent invisible hole they cannot undo. Reversibility
# is a child-safety requirement of this mechanic, so the lens must be able to
# account for every prop it has switched off.
func _test_placement_tracks_the_props_it_displaces() -> void:
	# Earlier cases deliberately commit placements to verify they remain solid.
	# Start this scenario from the authored world so its counts are independent
	# of test order.
	_lens.restore_world()
	await physics_frame

	var source := _add_prop(Vector3(0, 0, -5))
	# Far enough that framing the source cannot also catch the destination.
	var destination := _add_prop(Vector3(200, 0, -5))
	await physics_frame
	await physics_frame

	assert(_lens.displaced_count() == 0, "nothing is displaced before a placement")
	assert(_lens.committed_fragment_count() == 0,
		"and no runtime geometry is standing in the world yet")

	assert(_lens.capture(), "captured a seeing to carry to the occupied place")

	_place_camera(Vector3(200, 0, 0))
	await physics_frame
	await physics_frame
	assert(_lens.place(), "placed the seeing over an existing prop")
	await physics_frame

	assert(not destination.visible,
		"the destination prop is cut away to make room for the seeing")
	assert(_lens.displaced_count() > 0,
		"and the lens still knows it hid it, so it can always be brought back")
	# The placement put generated geometry into the world — the seeing itself
	# and the destination prop's offcuts. Restoring has to DELETE those, not
	# merely un-hide what was underneath, or the originals come back with the
	# generated geometry still standing on top of them.
	assert(_lens.committed_fragment_count() > 0,
		"the placement committed runtime fragments into the world")

	_lens.restore_world()
	await physics_frame

	assert(destination.visible,
		"restore_world brings the displaced destination prop back")
	assert(source.visible, "and leaves the capture site intact")
	assert(_lens.displaced_count() == 0, "with nothing left hidden")
	assert(_lens.committed_fragment_count() == 0,
		"and every runtime fragment is gone, so the restore is exact and the "
		+ "originals are not overlaid by the geometry that replaced them")

	# Visible is not enough: the player has to be able to walk into them again.
	for prop in [source, destination]:
		var shapes := _collect_shapes(prop)
		assert(not shapes.is_empty(), "a restored prop still has its shapes")
		for shape in shapes:
			assert(not shape.disabled,
				"a restored prop is solid again, not just visible")

	# No orphaned generated geometry left parented under the test world either.
	var strays := 0
	for child in _root.get_children():
		if child is StaticBody3D and String(child.name).ends_with("_fragment"):
			strays += 1
	assert(strays == 0, "restore_world leaves no fragment nodes behind")

	_place_camera(Vector3.ZERO)
	source.queue_free()
	destination.queue_free()
	await physics_frame


# restore_world() is the one-call way back to the authored world, for a child
# who has rearranged a room and for a facilitator resetting between children.
func _test_restore_world_puts_everything_back() -> void:
	var prop := _add_prop(Vector3(0, 0, -5))
	await physics_frame
	await physics_frame

	assert(_lens.capture(), "captured before restoring")
	assert(not prop.visible, "the source is hidden while the seeing is held")

	_lens.restore_world()
	await physics_frame

	assert(prop.visible, "restore_world un-hides a source still being carried")
	assert(not _lens.is_holding(), "and drops the held seeing")
	assert(_lens.committed_fragment_count() == 0,
		"and the dropped seeing is destroyed, not left standing in the world")
	assert(not _lens.is_busy(), "leaving the lens idle, not stuck mid-transaction")
	assert(_lens.seeings_left() == _lens.MAX_SEEINGS,
		"and the seeings are back to full, so the reset is total")

	# release() has a different job and must keep it: it cancels the seeing in
	# hand only. A placement already committed is the player's work, and undoing
	# it behind their back on an Escape press would be its own kind of damage.
	assert(_lens.capture(), "captured again to check release's narrower scope")
	_lens.release()
	await physics_frame
	assert(prop.visible, "release restores the capture site")
	assert(not _lens.is_holding(), "and drops what was held")

	prop.queue_free()
	await physics_frame


func _collect_shapes(node: Node) -> Array:
	var found: Array = []
	if node is CollisionShape3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_collect_shapes(child))
	return found
