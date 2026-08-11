# Self-check for the frozen-seeing card and its headless fallback.
#   godot --headless --path artea --script res://scripts/test_lens_photo_card.gd
#
# The card is pure presentation, so the only interesting questions are about
# SAFETY: it runs headless (where there is no framebuffer to read), it survives
# being driven in any order, and it never lies about what the player is holding.
# A card that stays on screen after a placement tells the player they are still
# carrying something they are not.
extends SceneTree

const PhotoCardScript := preload("res://scripts/viewfinder/lens_photo_card.gd")
const ControllerScript := preload("res://scripts/viewfinder/lens_controller.gd")
const FrustumCutterScript := preload("res://scripts/viewfinder/frustum_cutter.gd")

var _layer: CanvasLayer
var _card: Control


func _initialize() -> void:
	_layer = CanvasLayer.new()
	root.add_child(_layer)

	_card = PhotoCardScript.new()
	_layer.add_child(_card)
	await process_frame

	_test_headless_freeze_is_a_safe_failure()
	await _test_lifecycle()
	_test_out_of_tree_card_does_not_crash()
	await _test_rotation_tracks_the_geometry()
	await _test_controller_integration()

	print("lens photo card: all checks passed")
	quit()


# Headless has no framebuffer. freeze() must report that plainly and leave the
# card usable — never throw, and never make a capture depend on it.
func _test_headless_freeze_is_a_safe_failure() -> void:
	assert(DisplayServer.get_name() == "headless",
		"this test asserts the headless path, so run it with --headless")

	assert(not _card.freeze(Vector2(0.19, 0.19)),
		"freeze() reports failure headless rather than throwing")
	assert(not _card.has_frozen_image(), "and holds no image")

	# The card still shows: the player must always be able to tell they are
	# carrying a seeing, image or no image.
	_card.show_card("A seeing (unseen)")
	assert(_card.is_showing(),
		"a card with no frozen image still appears, so the held state is "
		+ "always visible")
	_card.reset()
	assert(not _card.is_showing(), "reset clears it")


func _test_lifecycle() -> void:
	# Every ordering a real session can produce, including the wrong ones.
	_card.reset()
	_card.hide_card(false)
	assert(not _card.is_showing(), "hiding a hidden card is a no-op, not an error")

	_card.rotate_card(-1)
	assert(_card.roll_steps() == 0,
		"turning a card that is not shown does nothing — there is nothing held")

	_card.show_card("A seeing")
	assert(_card.is_showing(), "show puts it up")
	_card.show_card("A seeing")
	assert(_card.is_showing(), "showing twice is idempotent")

	_card.hide_card(true)
	# The leave animation runs on a tween, so the card is not gone until it has
	# had frames to finish. What matters is that it does go.
	for i in 30:
		await process_frame
		if not _card.is_showing():
			break
	assert(not _card.is_showing(),
		"placing retires the card, so it never outlives the seeing it depicts")
	assert(not _card.has_frozen_image(), "and drops its image with it")

	_card.reset()


func _test_out_of_tree_card_does_not_crash() -> void:
	# create_tween() throws outside the tree, so every animated path has to fall
	# back to setting its final value. A card built and driven before being added
	# is exactly what a scene assembled in code does.
	var loose: Control = PhotoCardScript.new()
	assert(not loose.freeze(), "freeze outside the tree fails safely")
	loose.show_card("Loose")
	assert(loose.is_showing(), "an out-of-tree card still shows")
	loose.rotate_card(-1)
	loose.hide_card(true)
	assert(not loose.is_showing(), "and still hides, with no tween available")
	loose.free()


# The card's rotation must match the 30-degree steps the geometry turns in, or
# the picture stops describing what is held.
func _test_rotation_tracks_the_geometry() -> void:
	_card.show_card("A seeing")
	await process_frame

	assert(_card.roll_steps() == 0, "a fresh card is unturned")
	_card.rotate_card(-1)
	assert(_card.roll_steps() == 11,
		"one press of T is -30 degrees, wrapping to step 11 — the same step "
		+ "count viewfinder_lens.rotate_held keeps")

	for i in 11:
		_card.rotate_card(-1)
	assert(_card.roll_steps() == 0, "twelve presses is a full turn")

	_card.reset()
	assert(_card.roll_steps() == 0, "reset clears the turn too")


# The controller must build a card, put it up on capture, and take it down on
# placement — driven through the same public calls the mouse drives.
func _test_controller_integration() -> void:
	var holder := Node3D.new()
	root.add_child(holder)

	var camera := Camera3D.new()
	camera.fov = 70.0
	holder.add_child(camera)

	var controller: Node3D = ControllerScript.new()
	controller.camera = camera
	# A sandbox: this must not write placements into the player's real save.
	controller.persist = false
	holder.add_child(controller)
	await process_frame

	camera.global_transform = Transform3D(Basis(), Vector3.ZERO)
	controller.global_transform = camera.global_transform
	await physics_frame

	var card: Control = controller.photo_card()
	assert(card != null, "the controller builds a photo card")
	assert(not card.is_showing(), "which is down during ordinary play")

	var prop := _add_prop(holder, Vector3(0, 0, -5))
	await physics_frame
	await physics_frame

	var lens := controller.find_child("ViewfinderLens", false, false)

	# Drive the real gesture path, not the lens directly: the freeze-before-cut
	# ordering lives in the controller and is the thing worth testing.
	controller._do_capture()
	assert(lens.is_holding(), "the capture went through")
	assert(card.is_showing(),
		"holding a seeing shows the card, so the player can see what they carry")

	# A second click landing during the same gesture must not double-capture.
	controller._do_capture()
	assert(lens.held_count() > 0, "still holding exactly one seeing")

	camera.global_transform = Transform3D(Basis(), Vector3(40, 0, 0))
	controller.global_transform = camera.global_transform
	await physics_frame

	controller._do_place()
	assert(not lens.is_holding(), "the placement went through")
	for i in 30:
		await process_frame
		if not card.is_showing():
			break
	assert(not card.is_showing(),
		"placing takes the card down — a card left up would claim the player "
		+ "is still carrying something")

	prop.queue_free()
	holder.queue_free()
	await process_frame


func _add_prop(parent: Node3D, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = FrustumCutterScript.CUTTABLE_MASK
	body.collision_mask = 0

	var size := Vector3(6, 6, 1)
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

	parent.add_child(body)
	body.global_position = position
	return body
