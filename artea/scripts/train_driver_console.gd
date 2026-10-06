extends Node3D
## A compact reachable working control stand inside the existing cab.
## Imported gauges, wheels and engine effects remain owned by the railway.

var handles: Dictionary = {}
var power_lens: MeshInstance3D
var pressure_needle: Node3D

func _ready() -> void:
	name = "DriverWorkingControls"
	# Mounted behind the imported dashboard (rear edge z=-16.05), above the lap.
	position = Vector3(0, 1.16, 0.80)
	var gold := _material(Color("e9b94e"), 0.65)
	var dark := _material(Color("193543"), 0.15)
	_box("GoldDeskEdge", Vector3(0, 2.80, -16.49), Vector3(1.65, 0.10, 0.72), gold)
	_box("PearlControlPanel", Vector3(0, 2.86, -16.49), Vector3(1.52, 0.06, 0.61), dark)
	for side in [-1.0, 1.0]:
		_box("DeskLeg", Vector3(side * 0.61, 1.495, -16.55), Vector3(0.07, 2.71, 0.07), gold)
		_box("DriverFootrest", Vector3(side * 0.31, 1.44, -16.36), Vector3(0.42, 0.08, 0.50), dark)
	_box("FootrestSupport", Vector3(0, 1.36, -16.36), Vector3(1.28, 0.08, 0.07), gold)
	var specs := {
		"brake": Vector3(-0.47, 2.91, -16.44),
		"throttle": Vector3(0.46, 2.91, -16.44),
		"reverser": Vector3(0.0, 2.91, -16.69),
		"power": Vector3(0.22, 2.91, -16.65),
		"horn": Vector3(-0.22, 2.91, -16.65),
	}
	for control in specs:
		var pivot := Node3D.new()
		pivot.name = String(control).capitalize() + "Handle"
		pivot.position = specs[control]
		add_child(pivot)
		var stem := MeshInstance3D.new()
		var stem_mesh := CylinderMesh.new()
		stem_mesh.top_radius = 0.028
		stem_mesh.bottom_radius = 0.028
		stem_mesh.height = 0.20
		stem.mesh = stem_mesh
		stem.position.y = 0.10
		stem.material_override = gold
		pivot.add_child(stem)
		var grip := MeshInstance3D.new()
		grip.name = "Grip"
		var sphere := SphereMesh.new()
		sphere.radius = 0.065
		sphere.height = 0.13
		sphere.radial_segments = 12
		sphere.rings = 6
		grip.mesh = sphere
		grip.position.y = 0.22
		grip.material_override = _material(Color("ff6585") if control == "brake"
			else Color("70edff"), 0.1)
		pivot.add_child(grip)
		handles[control] = pivot
		if control == "power":
			power_lens = grip
		var label := Label3D.new()
		label.text = String(control).to_upper()
		label.font_size = 32
		label.pixel_size = 0.0015
		label.position = specs[control] + Vector3(0, 0.03, 0.17)
		label.rotation_degrees.x = -65
		add_child(label)
	# A small front-facing pressure dial is visible from the driver's seat.
	var dial := MeshInstance3D.new()
	dial.name = "CabPressureDial"
	var disk := CylinderMesh.new()
	disk.top_radius = 0.14
	disk.bottom_radius = 0.14
	disk.height = 0.035
	dial.mesh = disk
	dial.rotation_degrees.x = 90
	# Bottom of the dial meets the desk at y=4.02 after the console offset;
	# the gauge stays below the forward first-person field of view.
	dial.position = Vector3(0, 3.00, -16.83)
	dial.material_override = gold
	add_child(dial)
	pressure_needle = Node3D.new()
	pressure_needle.name = "CabPressureNeedle"
	pressure_needle.position = dial.position + Vector3(0, 0, 0.03)
	add_child(pressure_needle)
	var needle := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.012, 0.11, 0.012)
	needle.mesh = bar
	needle.position.y = 0.045
	needle.material_override = dark
	pressure_needle.add_child(needle)

func update_controls(state: Dictionary, delta: float) -> Dictionary:
	var blend := 1.0 - exp(-12.0 * maxf(delta, 0.0))
	var phase: String = state.get("phase", "off")
	var angles := {"throttle": -0.65 * float(state.get("throttle", 0.0)),
		"brake": 0.55 * float(state.get("brake", 1.0)),
		"reverser": -0.55 * float(state.get("reverser_target", 0)),
		"power": -0.45 if phase not in ["off", "take_controls"] else 0.0,
		"horn": -0.55 if state.get("horn", false) else 0.0}
	for control in handles:
		var pivot: Node3D = handles[control]
		pivot.rotation.x = lerpf(pivot.rotation.x, float(angles[control]), blend)
	pressure_needle.rotation.z = lerpf(1.15, -1.15, float(state.get("pressure", 0.0)))
	var lens_material := power_lens.material_override as StandardMaterial3D
	lens_material.emission_enabled = phase not in ["off", "take_controls"]
	lens_material.emission = Color("70edff")
	lens_material.emission_energy_multiplier = 0.45
	var left_control := "brake"
	var right_control := "throttle"
	if phase == "power_on":
		right_control = "power"
	elif phase == "select_direction":
		right_control = "reverser"
	if state.get("horn", false):
		left_control = "horn"
	return {"left": _grip_position(left_control), "right": _grip_position(right_control)}

func _grip_position(control: String) -> Vector3:
	return (handles[control] as Node3D).get_node("Grip").global_position

func _box(node_name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = node_name
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.position = pos
	part.material_override = mat
	add_child(part)

func _material(colour: Color, metal: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.metallic = metal
	mat.roughness = 0.28
	return mat
