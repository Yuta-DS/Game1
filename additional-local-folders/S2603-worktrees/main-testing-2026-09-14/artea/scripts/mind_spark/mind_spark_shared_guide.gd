class_name MindSparkSharedGuide
extends Node3D

enum GuideKind { MAYOR_MILO, MOTHER_GUARDIAN }

@export var guide_kind := GuideKind.MAYOR_MILO
@export var display_name := "Mayor Milo"
@export_multiline var default_line := "Let us follow one clear light."


func _ready() -> void:
	_build_visual()
	set_meta("non_combat", true)
	set_meta("solves_puzzles", false)


func set_dialogue_line(line: String) -> void:
	$DialogueLabel.text = "%s: %s" % [display_name, line]


func move_to_guide_point(point: Marker3D) -> void:
	if point != null:
		global_position = point.global_position


func _build_visual() -> void:
	var visuals := $Visuals
	var outfit := Color("24395f") if guide_kind == GuideKind.MAYOR_MILO else Color("dbe7cf")
	_add_cylinder(visuals, "Body", Vector3(0, 3.6, 0), 1.5, 6.2, _material(outfit, 0.72))
	_add_sphere(visuals, "Head", Vector3(0, 7.4, 0), Vector3(1.45, 1.55, 1.4),
		_material(Color("e8c7a8"), 0.92))
	_add_sphere(visuals, "SilverHair", Vector3(0, 8.0, -0.25), Vector3(1.55, 1.1, 1.45),
		_material(Color("d9dce6"), 0.72))
	if guide_kind == GuideKind.MAYOR_MILO:
		_add_cylinder(visuals, "ProfessorCane", Vector3(1.65, 2.2, 0), 0.12, 4.4,
			_material(Color("d5b15d"), 0.4))
		_add_box(visuals, "MayorSash", Vector3(0, 4.6, 1.35), Vector3(2.4, 0.45, 0.18),
			_material(Color("e4bd5b"), 0.42))
	else:
		_build_guardian_details(visuals)
	$DialogueLabel.text = "%s: %s" % [display_name, default_line]


func _build_guardian_details(parent: Node3D) -> void:
	var wing_materials := [
		_material(Color("41dbe8"), 0.34, 1.0),
		_material(Color("8961d0"), 0.34, 0.8),
		_material(Color("57a978"), 0.58, 0.55),
	]
	for side in [-1.0, 1.0]:
		for wing in 3:
			var panel := _add_box(parent, "WingPanel_%s_%d" % ["L" if side < 0 else "R", wing + 1],
				Vector3(side * (2.2 + wing * 0.75), 5.2 + wing * 0.6, -0.5), Vector3(1.2, 4.8, 0.35),
				wing_materials[wing])
			panel.rotation.z = side * (0.28 + wing * 0.12)
	_add_torus(parent, "GoldBranchHalo", Vector3(0, 9.5, 0), 1.6, 2.0,
		_material(Color("e9bd55"), 0.38, 1.25))
	for panel in 7:
		var angle := -1.1 + panel * 0.36
		var gown := _add_box(parent, "RigidGownPanel_%d" % panel, Vector3(sin(angle) * 1.2, 2.3, cos(angle) * 0.55),
			Vector3(0.75, 4.6, 0.28), _material(Color("eef0dc") if panel % 2 == 0 else Color("6e9f87"), 0.78))
		gown.rotation.z = angle * 0.12


func _material(color: Color, roughness: float, emission_energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material


func _add_box(parent: Node3D, node_name: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, at: Vector3, radius: float, height: float,
		material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, node_name: String, at: Vector3, scale_value: Vector3,
		material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = SphereMesh.new()
	instance.position = at
	instance.scale = scale_value
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_torus(parent: Node3D, node_name: String, at: Vector3, inner: float, outer: float,
		material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 7
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance

