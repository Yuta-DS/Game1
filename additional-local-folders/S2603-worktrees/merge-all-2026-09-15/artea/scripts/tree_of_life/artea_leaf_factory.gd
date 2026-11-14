class_name ArteaLeafFactory
extends RefCounted

## Native Godot construction library for the four Artéa powered leaf families.
## Every blade facet, edge tooth, vein, connector, rune and sensor remains a
## separately named MeshInstance3D so artists can identify and tune parts.

enum LeafType {
	LIVING_FAN,
	MAGIC_RUNE,
	SOLAR_GLASS,
	EMERALD_SENSOR,
}

const LEAF_TYPE_NAMES := {
	LeafType.LIVING_FAN: "living_leaf_fan",
	LeafType.MAGIC_RUNE: "magic_rune_leaf",
	LeafType.SOLAR_GLASS: "solar_glass_science_leaf",
	LeafType.EMERALD_SENSOR: "emerald_sensor_leaf",
}

static var _materials: Dictionary = {}


static func create_leaf(leaf_type: LeafType, component_name := "") -> Node3D:
	_ensure_materials()
	var leaf: Node3D
	match leaf_type:
		LeafType.LIVING_FAN:
			leaf = _create_living_fan()
		LeafType.MAGIC_RUNE:
			leaf = _create_single_leaf(LeafType.MAGIC_RUNE, true)
		LeafType.SOLAR_GLASS:
			leaf = _create_single_leaf(LeafType.SOLAR_GLASS, true)
		LeafType.EMERALD_SENSOR:
			leaf = _create_single_leaf(LeafType.EMERALD_SENSOR, true)
		_:
			leaf = _create_single_leaf(LeafType.EMERALD_SENSOR, true)
	if not component_name.is_empty():
		leaf.name = component_name
	leaf.set_meta("leaf_type", LEAF_TYPE_NAMES.get(leaf_type, "unknown"))
	leaf.set_meta("construction", "native_godot_editable_components")
	leaf.set_meta("reference", "04_crystal_powered_leaf_system")
	leaf.set_meta("editable_component_count", _count_mesh_components(leaf))
	return leaf


static func _ensure_materials() -> void:
	if not _materials.is_empty():
		return
	_materials = {
		"forest_a": _make_material("LeafLivingForestA", Color("315f32"), 0.04, 0.86),
		"forest_b": _make_material("LeafLivingForestB", Color("4b7438"), 0.03, 0.82),
		"forest_c": _make_material("LeafLivingForestC", Color("718b43"), 0.02, 0.78),
		"violet_a": _make_material("LeafMagicVioletA", Color("55317f"), 0.13, 0.64, Color("6c3cb0"), 0.55),
		"violet_b": _make_material("LeafMagicVioletB", Color("7848a5"), 0.10, 0.58, Color("8d53cf"), 0.42),
		"violet_c": _make_material("LeafMagicVioletC", Color("9b68c6"), 0.07, 0.54, Color("9f70d8"), 0.30),
		"glass_a": _make_material("LeafSolarGlassA", Color(0.05, 0.52, 0.65, 0.58), 0.28, 0.16, Color("1fccea"), 0.72, true),
		"glass_b": _make_material("LeafSolarGlassB", Color(0.10, 0.65, 0.76, 0.46), 0.22, 0.12, Color("5be7ff"), 0.58, true),
		"glass_c": _make_material("LeafSolarGlassC", Color(0.06, 0.34, 0.55, 0.63), 0.32, 0.18, Color("1d9ec8"), 0.48, true),
		"emerald_a": _make_material("LeafEmeraldSensorA", Color("12684f"), 0.17, 0.44, Color("0c8b6b"), 0.30),
		"emerald_b": _make_material("LeafEmeraldSensorB", Color("248667"), 0.14, 0.40, Color("17aa82"), 0.26),
		"cyan": _make_material("LeafCircuitCyan", Color("36dcef"), 0.18, 0.22, Color("45efff"), 2.35),
		"cyan_soft": _make_material("LeafCircuitCyanSoft", Color("22a9c0"), 0.12, 0.28, Color("2bc8dc"), 1.10),
		"gold": _make_material("LeafEdgeGold", Color("ba8a36"), 0.80, 0.24, Color("6b3e0c"), 0.18),
		"brass": _make_material("LeafConnectorBrass", Color("8c5b23"), 0.84, 0.26),
		"black_tech": _make_material("LeafBlackBioTech", Color("07131b"), 0.72, 0.20, Color("052b38"), 0.22),
		"crystal": _make_material("LeafPowerCrystal", Color("54d9ff"), 0.22, 0.12, Color("64e8ff"), 2.80),
	}


static func _make_material(
		material_name: String,
		color: Color,
		metallic: float,
		roughness: float,
		emission := Color(0, 0, 0, 1),
		emission_energy := 0.0,
		transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	return material


static func _create_living_fan() -> Node3D:
	var fan := Node3D.new()
	fan.name = "LivingLeafFan"
	var structure := Node3D.new()
	structure.name = "PoweredStemNetwork"
	fan.add_child(structure)
	_add_segment(structure, "BlackBioTechSpine", Vector3(-1.15, 0, -0.04), Vector3(3.55, 0, 0.02), 0.16, _materials.black_tech, 8)
	_add_segment(structure, "CrystalSapBus", Vector3(-0.92, 0, 0.15), Vector3(3.48, 0, 0.15), 0.045, _materials.cyan, 7)
	_add_connector(structure, Vector3(-1.2, 0, 0), 0.82)
	_add_power_crystal(structure, Vector3(0.15, 0, 0.28), 0.34)

	var fan_specs := [
		[Vector3(0.55, -0.55, 0.02), -0.76, 0.58],
		[Vector3(1.12, -0.42, 0.05), -0.51, 0.64],
		[Vector3(1.78, -0.24, 0.08), -0.26, 0.70],
		[Vector3(2.55, 0.00, 0.11), 0.00, 0.76],
		[Vector3(1.78, 0.24, 0.08), 0.26, 0.70],
		[Vector3(1.12, 0.42, 0.05), 0.51, 0.64],
		[Vector3(0.55, 0.55, 0.02), 0.76, 0.58],
	]
	var leaves := Node3D.new()
	leaves.name = "SevenLivingLeaves"
	fan.add_child(leaves)
	for index in fan_specs.size():
		var spec: Array = fan_specs[index]
		var leaf := _create_single_leaf(LeafType.LIVING_FAN, false)
		leaf.name = "LivingBlade_%02d" % index
		leaf.position = spec[0]
		leaf.rotation.z = float(spec[1])
		leaf.scale = Vector3.ONE * float(spec[2])
		leaves.add_child(leaf)
		_add_segment(
			structure, "PoweredPetiole_%02d" % index,
			Vector3(leaf.position.x - 0.28, 0.0, 0.11),
			leaf.position + Vector3(cos(leaf.rotation.z), sin(leaf.rotation.z), 0.0) * 0.92,
			0.035, _materials.cyan_soft, 6)
	return fan


static func _create_single_leaf(leaf_type: LeafType, include_connector: bool) -> Node3D:
	var leaf := Node3D.new()
	leaf.name = String(LEAF_TYPE_NAMES.get(leaf_type, "Leaf")).to_pascal_case()
	var blade := Node3D.new()
	blade.name = "BladeFacetComponents"
	leaf.add_child(blade)
	var details := Node3D.new()
	details.name = "VeinAndScienceComponents"
	leaf.add_child(details)

	var length := 5.0
	var width := 1.85
	var segments := 10
	var palette: Array[Material] = [_materials.forest_a, _materials.forest_b, _materials.forest_c]
	var edge_material: Material = _materials.gold
	var vein_material: Material = _materials.cyan_soft
	match leaf_type:
		LeafType.MAGIC_RUNE:
			length = 5.75
			width = 2.08
			segments = 11
			palette = [_materials.violet_a, _materials.violet_b, _materials.violet_c]
			vein_material = _materials.cyan
		LeafType.SOLAR_GLASS:
			length = 5.60
			width = 2.15
			segments = 9
			palette = [_materials.glass_a, _materials.glass_b, _materials.glass_c]
			vein_material = _materials.cyan
		LeafType.EMERALD_SENSOR:
			length = 3.30
			width = 1.18
			segments = 8
			palette = [_materials.emerald_a, _materials.emerald_b]
			vein_material = _materials.cyan

	_build_blade_facets(blade, leaf_type, length, width, segments, palette)
	_build_edge(details, leaf_type, length, width, segments, edge_material)
	_build_veins(details, leaf_type, length, width, segments, vein_material)
	if leaf_type == LeafType.MAGIC_RUNE:
		_build_runes(details, length, width)
	elif leaf_type == LeafType.SOLAR_GLASS:
		_build_science_cells(details, length, width)
	elif leaf_type == LeafType.EMERALD_SENSOR:
		_build_sensor_nodes(details, length, width)
	if include_connector:
		var connector := Node3D.new()
		connector.name = "StemConnectorComponents"
		leaf.add_child(connector)
		_add_segment(connector, "BlackStemContact", Vector3(-0.82, 0, 0), Vector3(0.32, 0, 0), 0.11, _materials.black_tech, 7)
		_add_connector(connector, Vector3(-0.82, 0, 0), 0.62 if leaf_type != LeafType.EMERALD_SENSOR else 0.42)
	return leaf


static func _build_blade_facets(
		parent: Node3D,
		leaf_type: LeafType,
		length: float,
		width: float,
		segments: int,
		palette: Array[Material]) -> void:
	var lanes := PackedFloat32Array([-1.0, -0.34, 0.34, 1.0])
	for segment in segments:
		var t0 := float(segment) / float(segments)
		var t1 := float(segment + 1) / float(segments)
		var x0 := t0 * length
		var x1 := t1 * length
		var w0 := _profile_width(leaf_type, t0, segment) * width
		var w1 := _profile_width(leaf_type, t1, segment + 1) * width
		for lane in range(lanes.size() - 1):
			var y00 := lanes[lane] * w0
			var y01 := lanes[lane + 1] * w0
			var y10 := lanes[lane] * w1
			var y11 := lanes[lane + 1] * w1
			var ridge0: float = (1.0 - abs((lanes[lane] + lanes[lane + 1]) * 0.5)) * width * 0.11
			var ridge1: float = ridge0 + sin(t1 * PI) * width * 0.055
			var points := PackedVector3Array([
				Vector3(x0, y00, ridge0), Vector3(x1, y10, ridge1),
				Vector3(x1, y11, ridge1), Vector3(x0, y01, ridge0),
			])
			_add_quad_component(
				parent, "BladeFacet_%02d_%02d" % [segment, lane], points,
				palette[(segment + lane * 2) % palette.size()])


static func _profile_width(leaf_type: LeafType, t: float, segment: int) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.035
	var profile := pow(sin(t * PI), 0.58)
	if leaf_type == LeafType.EMERALD_SENSOR:
		return profile * (0.96 + 0.035 * sin(float(segment) * PI))
	var serration := 1.0 + (0.13 if segment % 2 == 0 else -0.075)
	if leaf_type == LeafType.SOLAR_GLASS:
		serration = 1.0 + (0.055 if segment % 2 == 0 else -0.035)
	return profile * serration


static func _build_edge(parent: Node3D, leaf_type: LeafType, length: float, width: float,
		segments: int, material: Material) -> void:
	for side in [-1.0, 1.0]:
		for segment in segments:
			var t0 := float(segment) / float(segments)
			var t1 := float(segment + 1) / float(segments)
			var a := Vector3(t0 * length, side * _profile_width(leaf_type, t0, segment) * width, width * 0.13)
			var b := Vector3(t1 * length, side * _profile_width(leaf_type, t1, segment + 1) * width, width * 0.11)
			_add_segment(parent, "GoldEdge_%s_%02d" % ["Upper" if side > 0 else "Lower", segment], a, b, 0.026, material, 5)


static func _build_veins(parent: Node3D, leaf_type: LeafType, length: float, width: float,
		segments: int, material: Material) -> void:
	_add_segment(parent, "CrystalSapMidrib", Vector3(-0.05, 0, width * 0.17), Vector3(length * 0.96, 0, width * 0.13), 0.043, material, 7)
	var step_count := 3 if leaf_type == LeafType.EMERALD_SENSOR else 5
	for vein_index in step_count:
		var t := 0.22 + float(vein_index) * (0.58 / maxf(1.0, float(step_count - 1)))
		var segment := mini(int(round(t * segments)), segments - 1)
		var end_t := minf(0.94, t + 0.115)
		var end_segment := mini(int(round(end_t * segments)), segments - 1)
		var reach := _profile_width(leaf_type, end_t, end_segment) * width * 0.72
		for side in [-1.0, 1.0]:
			_add_segment(
				parent, "BranchVein_%02d_%s" % [vein_index, "Upper" if side > 0 else "Lower"],
				Vector3(t * length, 0, width * 0.17),
				Vector3(end_t * length, side * reach, width * 0.14),
				0.026 if leaf_type != LeafType.EMERALD_SENSOR else 0.021,
				material, 6)


static func _build_runes(parent: Node3D, length: float, width: float) -> void:
	for rune_index in 3:
		var center := Vector3(length * (0.32 + rune_index * 0.19),
			(-1.0 if rune_index % 2 == 0 else 1.0) * width * 0.28, width * 0.19)
		_add_sensor_or_rune(parent, "MagicRuneNode_%02d" % rune_index, center, 0.14, _materials.crystal)
		_add_segment(parent, "RuneStroke_%02d" % rune_index, center,
			center + Vector3(length * 0.10, width * (0.16 if rune_index % 2 == 0 else -0.16), 0),
			0.025, _materials.cyan, 6)


static func _build_science_cells(parent: Node3D, length: float, width: float) -> void:
	var nodes := [
		Vector3(length * 0.28, width * 0.38, width * 0.18),
		Vector3(length * 0.43, -width * 0.32, width * 0.18),
		Vector3(length * 0.60, width * 0.42, width * 0.17),
		Vector3(length * 0.74, -width * 0.25, width * 0.16),
		Vector3(length * 0.86, width * 0.16, width * 0.15),
	]
	for index in nodes.size():
		_add_sensor_or_rune(parent, "ScienceCellNode_%02d" % index, nodes[index], 0.10, _materials.cyan_soft)
		if index > 0:
			_add_segment(parent, "ScienceCellLink_%02d" % index, nodes[index - 1], nodes[index], 0.022, _materials.cyan_soft, 5)


static func _build_sensor_nodes(parent: Node3D, length: float, width: float) -> void:
	var nodes := [
		Vector3(length * 0.35, width * 0.22, width * 0.19),
		Vector3(length * 0.50, -width * 0.28, width * 0.18),
		Vector3(length * 0.68, width * 0.16, width * 0.17),
		Vector3(length * 0.79, -width * 0.10, width * 0.16),
	]
	for index in nodes.size():
		_add_sensor_or_rune(parent, "EmeraldSensor_%02d" % index, nodes[index], 0.095, _materials.crystal)


static func _add_quad_component(parent: Node3D, component_name: String,
		points: PackedVector3Array, material: Material) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var normal := (points[1] - points[0]).cross(points[2] - points[0]).normalized()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal, normal, normal, normal])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var component := MeshInstance3D.new()
	component.name = component_name
	component.mesh = mesh
	component.material_override = material
	component.set_meta("editable_leaf_component", true)
	parent.add_child(component)
	return component


static func _add_segment(parent: Node3D, component_name: String, start: Vector3,
		end: Vector3, radius: float, material: Material, radial_segments := 6) -> MeshInstance3D:
	var direction := end - start
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = direction.length()
	mesh.radial_segments = radial_segments
	mesh.rings = 1
	var component := MeshInstance3D.new()
	component.name = component_name
	component.mesh = mesh
	component.material_override = material
	component.position = (start + end) * 0.5
	if direction.length_squared() > 0.000001:
		component.quaternion = Quaternion(Vector3.UP, direction.normalized())
	component.set_meta("editable_leaf_component", true)
	parent.add_child(component)
	return component


static func _add_connector(parent: Node3D, start: Vector3, length: float) -> void:
	_add_segment(parent, "BrassConnectorCore", start, start + Vector3(length, 0, 0), 0.19, _materials.brass, 10)
	_add_segment(parent, "ConnectorBandA", start + Vector3(length * 0.20, 0, 0), start + Vector3(length * 0.34, 0, 0), 0.235, _materials.gold, 10)
	_add_segment(parent, "ConnectorBandB", start + Vector3(length * 0.72, 0, 0), start + Vector3(length * 0.86, 0, 0), 0.235, _materials.gold, 10)


static func _add_power_crystal(parent: Node3D, position: Vector3, radius: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.2
	mesh.radial_segments = 8
	mesh.rings = 4
	var component := MeshInstance3D.new()
	component.name = "CrystalPowerNode"
	component.mesh = mesh
	component.material_override = _materials.crystal
	component.position = position
	component.scale = Vector3(1.0, 0.72, 0.72)
	component.set_meta("editable_leaf_component", true)
	parent.add_child(component)


static func _add_sensor_or_rune(parent: Node3D, component_name: String,
		position: Vector3, radius: float, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 3
	var component := MeshInstance3D.new()
	component.name = component_name
	component.mesh = mesh
	component.material_override = material
	component.position = position
	component.scale.z = 0.30
	component.set_meta("editable_leaf_component", true)
	parent.add_child(component)


static func _count_mesh_components(root: Node) -> int:
	return root.find_children("*", "MeshInstance3D", true, false).size()
