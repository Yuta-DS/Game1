# Self-check that the player-facing lens wires itself together (S7).
#   godot --headless --path artea --script res://scripts/test_lens_controller.gd
#
# The controller builds its own lens, story layer and HUD, so the thing most
# worth testing is that those three are actually connected — a silent wiring
# failure would leave a lens that looks fine and does nothing.
extends SceneTree

const ControllerScript := preload("res://scripts/viewfinder/lens_controller.gd")
const FrustumCutterScript := preload("res://scripts/viewfinder/frustum_cutter.gd")

var _root: Node3D
var _camera: Camera3D
var _controller: Node3D


func _initialize() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	_camera = Camera3D.new()
	_camera.fov = 70.0
	_root.add_child(_camera)

	_controller = ControllerScript.new()
	_controller.camera = _camera
	# A wiring test must never touch the player's real journey or placement
	# files. The story signals still fire when persistence is disabled.
	_controller.persist = false
	_root.add_child(_controller)

	await process_frame
	_camera.global_transform = Transform3D(Basis(), Vector3.ZERO)
	_controller.global_transform = _camera.global_transform
	await physics_frame

	_test_wiring()
	await _test_capture_flows_through_to_the_story()

	print("lens controller: all checks passed")
	quit()


func _test_wiring() -> void:
	var lens := _controller.find_child("ViewfinderLens", false, false)
	assert(lens != null, "the controller builds its lens")
	assert(lens.camera == _camera, "the lens is given the player's camera")
	assert(lens.capture_point == _controller,
		"the controller is the capture point, so held seeings travel with the "
		+ "player — that relationship is what makes placement exact")

	var journey := _controller.find_child("LensJourney", false, false)
	assert(journey != null, "the controller builds the story layer")
	assert(journey.lens == lens, "the story layer is bound to the lens")

	# Bound before _ready(), so the story layer never has to find the lens by
	# name — a rename would otherwise silently unhook the whole narrative.
	assert(lens.seeing_placed.get_connections().size() > 0,
		"placing a seeing reaches the story layer")
	assert(lens.capture_refused.get_connections().size() > 0,
		"refusals reach the story layer, so a child is always told why")


func _test_capture_flows_through_to_the_story() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = FrustumCutterScript.CUTTABLE_MASK
	body.collision_mask = 0

	var box := BoxMesh.new()
	box.size = Vector3(14, 14, 1)
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box.size
	shape.shape = box_shape
	body.add_child(shape)

	_root.add_child(body)
	body.global_position = Vector3(0, 0, -6)
	await physics_frame
	await physics_frame

	var lens := _controller.find_child("ViewfinderLens", false, false)
	var journey := _controller.find_child("LensJourney", false, false)

	var bridged: Array = []
	journey.bridging_completed.connect(func() -> void: bridged.append(true))

	assert(lens.capture(), "the wired lens captures")
	assert(lens.is_holding(), "and holds the seeing")
	assert(bridged.is_empty(), "capturing alone is not yet a bridging")

	assert(lens.place(), "the wired lens places")
	assert(bridged.size() == 1,
		"carrying a seeing across and placing it completes the bridging")

	body.queue_free()
	await physics_frame
