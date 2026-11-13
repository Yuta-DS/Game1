# A playable room for the Lens of Seeing, with nothing else attached.
#
# Run it directly:
#   Godot --path artea res://scenes/viewfinder/lens_demo.tscn
#
# Exists because every other check on this mechanic is headless. The cutter can
# pass all of its assertions and still look wrong — inside-out faces, an
# unlit cross-section, a fragment that pops out of the world — and none of that
# is visible from an assert. This is the scene to look at when changing the
# cutter.
#
# Deliberately built in code with no dependency on Artéa's player, hub, or
# autoloads, so a cutter regression can be reproduced without loading the game.
extends Node3D
const TouchDevice := preload("res://scripts/touch_controls.gd")

const ControllerScript := preload("res://scripts/viewfinder/lens_controller.gd")
const FrustumCutterScript := preload("res://scripts/viewfinder/frustum_cutter.gd")

const MOVE_SPEED := 6.0
const LOOK_SENSITIVITY := 0.0025
const PITCH_LIMIT := deg_to_rad(89.0)

var _camera: Camera3D
var _pitch := 0.0
var _yaw := 0.0


func _ready() -> void:
	_build_room()
	_build_player()
	_build_props()
	Input.mouse_mode = TouchDevice.captured_mode()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * LOOK_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * LOOK_SENSITIVITY,
			-PITCH_LIMIT, PITCH_LIMIT)
		_camera.rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		# Release the mouse so the window can be closed without a force quit.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	var input := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		input.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input.z += 1.0
	if Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input.x += 1.0
	if Input.is_key_pressed(KEY_E):
		input.y += 1.0
	if Input.is_key_pressed(KEY_C):
		input.y -= 1.0

	if input == Vector3.ZERO:
		return

	# Free flight rather than a character controller: this room is for looking
	# at cut geometry from every angle, including underneath it.
	var basis := _camera.global_transform.basis
	var motion := (basis.x * input.x + basis.y * input.y + basis.z * input.z)
	_camera.global_position += motion.normalized() * MOVE_SPEED * delta


func _build_player() -> void:
	_camera = Camera3D.new()
	_camera.name = "DemoCamera"
	_camera.fov = 70.0
	_camera.far = 200.0
	add_child(_camera)
	_camera.global_position = Vector3(0.0, 1.7, 8.0)

	# The controller is the capture point, so it must ride with the camera.
	var lens := ControllerScript.new()
	lens.name = "LensController"
	lens.camera = _camera
	# A sandbox: placements from a previous run would reappear on top of the
	# props and make a cutter regression harder to read, not easier.
	lens.persist = false
	_camera.add_child(lens)


func _build_room() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-38.0), 0.0)
	sun.light_energy = 1.1
	add_child(sun)

	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = ProceduralSkyMaterial.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.6
	env.environment = environment
	add_child(env)

	# Floor. Not cuttable — the mechanic is for discrete props, and a sliced
	# floor would drop the player out of the world.
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var floor_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(60.0, 0.5, 60.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.20, 0.22, 0.28)
	floor_mesh.material_override = floor_mat
	floor_body.add_child(floor_mesh)

	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = plane.size
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)

	add_child(floor_body)
	floor_body.global_position = Vector3(0.0, -0.25, 0.0)


# A row of shapes with different topologies, because the cutter behaves
# differently on each: a box exercises flat faces, a sphere exercises many
# straddling triangles, a cylinder exercises a curved side against flat caps.
func _build_props() -> void:
	var palette := [
		Color(0.86, 0.40, 0.44),
		Color(0.42, 0.62, 0.92),
		Color(0.52, 0.80, 0.56),
		Color(0.92, 0.76, 0.38),
	]

	var shapes: Array[Mesh] = []

	var box := BoxMesh.new()
	box.size = Vector3(2.4, 2.4, 2.4)
	shapes.append(box)

	var sphere := SphereMesh.new()
	sphere.radius = 1.4
	sphere.height = 2.8
	# Kept well inside MAX_CUTTABLE_TRIANGLES so the demo shows a cut, not a
	# refusal.
	sphere.radial_segments = 20
	sphere.rings = 12
	shapes.append(sphere)

	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.2
	cylinder.bottom_radius = 1.2
	cylinder.height = 3.0
	cylinder.radial_segments = 20
	shapes.append(cylinder)

	var prism := PrismMesh.new()
	prism.size = Vector3(2.6, 2.8, 2.6)
	shapes.append(prism)

	for i in shapes.size():
		var offset := (float(i) - float(shapes.size() - 1) * 0.5) * 4.2
		_add_cuttable(shapes[i], Vector3(offset, 1.6, -4.0), palette[i % palette.size()])


func _add_cuttable(mesh: Mesh, position: Vector3, colour: Color) -> void:
	var body := StaticBody3D.new()
	body.name = "Cuttable_%s" % mesh.get_class()
	body.collision_layer = FrustumCutterScript.CUTTABLE_MASK
	body.collision_mask = 0

	# Baked to an ArrayMesh: the cutter reads surface arrays, and that is also
	# the shape it will see from an imported .glb.
	var baked := ArrayMesh.new()
	baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.get_mesh_arrays())

	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.55
	baked.surface_set_material(0, material)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = baked
	body.add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	shape.shape = baked.create_convex_shape()
	body.add_child(shape)

	add_child(body)
	body.global_position = position
