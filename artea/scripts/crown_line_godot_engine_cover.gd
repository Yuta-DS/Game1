extends Node3D

const BLUEPRINT_PATH := "res://assets3D/crown_line_train/crown_line_engine_cover_blueprint.json"

var _blueprint: Dictionary
var _materials: Dictionary = {}


func _ready() -> void:
	name = "GodotEngineCover"
	_build_from_shared_blueprint()


func _build_from_shared_blueprint() -> void:
	var file := FileAccess.open(BLUEPRINT_PATH, FileAccess.READ)
	if file == null:
		push_error("Crown Line Godot cover blueprint could not be opened")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Crown Line Godot cover blueprint is invalid")
		return
	_blueprint = parsed as Dictionary
	_build_materials()
	_build_shell_bands("UpperShellBand", false, "side_teal")
	_build_shell_bands("LowerJawBand", true, "blue_steel")
	_build_feather_skin()
	_build_macro_leaf_panels()
	_build_gold_flow_ribs()
	_build_crystal_socket()
	set_meta("source", "native Godot procedural geometry")
	set_meta("shared_blueprint", BLUEPRINT_PATH)
	set_meta("component_count", _count_render_components(self))


func _build_materials() -> void:
	var palette: Dictionary = _blueprint.palette
	for key: String in palette:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(String(palette[key]))
		# ARTEA uses broad, friendly colour blocks rather than physically noisy
		# hard-surface shading. Toon diffuse/specular keeps the same geometry
		# readable beside Milo and the low-poly islands at gameplay distance.
		material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		material.specular_mode = BaseMaterial3D.SPECULAR_TOON
		material.roughness = 0.68
		material.metallic = 0.0
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if key == "coral":
			# Legacy palette key: warm matte sandstone, not pink or metallic gold.
			material.albedo_color = Color("e6b366")
			material.metallic = 0.0
			material.roughness = 0.68
		elif key == "deep_teal":
			material.albedo_color = Color("148099")
		elif key == "light_teal":
			material.albedo_color = Color("52d7c0")
		elif key == "side_teal":
			material.albedo_color = Color("1ab3b8")
		elif key == "nature_green":
			material.albedo_color = Color("30c96d")
			material.roughness = 0.58
		elif key == "blue_steel":
			material.albedo_color = Color("2e6bc2")
			material.roughness = 0.44
		elif key == "cyan":
			material.albedo_color = Color("5ff3ff")
			material.emission_enabled = true
			material.emission = Color("36cce8")
			material.emission_energy_multiplier = 1.05
			material.roughness = 0.30
		elif key == "purple":
			material.albedo_color = Color("bf6bff")
			material.emission_enabled = true
			material.emission = Color("7043b5")
			material.emission_energy_multiplier = 0.32
			material.roughness = 0.42
		elif key == "vent":
			material.albedo_color = Color("152437")
			material.roughness = 0.62
		_materials[key] = material
	var accent_gold := StandardMaterial3D.new()
	accent_gold.albedo_color = Color("ffb02e")
	accent_gold.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	accent_gold.specular_mode = BaseMaterial3D.SPECULAR_TOON
	accent_gold.metallic = 0.34
	accent_gold.roughness = 0.34
	_materials.accent_gold = accent_gold


func _sample(values: Array, t: float) -> float:
	var clamped := clampf(t, 0.0, 1.0)
	var scaled := clamped * float(values.size() - 1)
	var index := mini(values.size() - 2, int(scaled))
	var local_t := scaled - float(index)
	var eased := local_t * local_t * (3.0 - 2.0 * local_t)
	return lerpf(float(values[index]), float(values[index + 1]), eased)


func _surface_point(t: float, contour: float, lower: bool = false, lift: float = 0.0) -> Vector3:
	var widths: Array = _blueprint.lower_widths if lower else _blueprint.upper_widths
	var centres: Array = _blueprint.lower_centres if lower else _blueprint.upper_centres
	var arches: Array = _blueprint.lower_arches if lower else _blueprint.upper_arches
	var half_width := _sample(widths, t)
	var centre_y := _sample(centres, t)
	var arch := _sample(arches, t)
	var exponent := (1.45 + 0.30 * t) if lower else (1.35 + 0.45 * t)
	var height := centre_y + (-arch if lower else arch) * (1.0 - pow(absf(contour), exponent))
	return Vector3(half_width * contour, height + lift,
		lerpf(float(_blueprint.cover_start_z), float(_blueprint.cover_end_z), t))


func _build_shell_bands(prefix: String, lower: bool, material_key: String) -> void:
	var band_count := int(_blueprint.godot_shell_bands)
	var contours := 18
	for band_index in band_count:
		var t0 := float(band_index) / float(band_count)
		var t1 := float(band_index + 1) / float(band_count)
		var vertices := PackedVector3Array()
		var indices := PackedInt32Array()
		for contour_index in contours + 1:
			var contour := -1.0 + 2.0 * float(contour_index) / float(contours)
			vertices.append(_surface_point(t0, contour, lower))
			vertices.append(_surface_point(t1, contour, lower))
		for contour_index in contours:
			var base := contour_index * 2
			indices.append_array(PackedInt32Array([base, base + 1, base + 3, base, base + 3, base + 2]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var instance := MeshInstance3D.new()
		instance.name = "%s_%02d" % [prefix, band_index]
		instance.mesh = mesh
		instance.material_override = _materials[material_key]
		add_child(instance)


func _build_feather_skin() -> void:
	var rows := int(_blueprint.godot_panel_rows)
	var contours := int(_blueprint.godot_panel_contours)
	var start_z := float(_blueprint.cover_start_z)
	var end_z := float(_blueprint.cover_end_z)
	var course_length := (end_z - start_z) / float(rows)
	for row_index in rows:
		var t := (float(row_index) + 0.5) / float(rows)
		var previous := _surface_point(maxf(0.0, t - 0.015), 0.0)
		var following := _surface_point(minf(1.0, t + 0.015), 0.0)
		var pitch := -atan2(following.y - previous.y, following.z - previous.z)
		var half_width := _sample(_blueprint.upper_widths, t)
		for side in [-1.0, 1.0]:
			for contour_index in contours:
				var contour := (float(contour_index) + 0.5) / float(contours)
				var point := _surface_point(t, side * contour, false, 0.045)
				var panel := MeshInstance3D.new()
				panel.name = "Feather_%s_%02d_%02d" % ["L" if side < 0.0 else "R", row_index, contour_index]
				var mesh := PrismMesh.new()
				mesh.size = Vector3(half_width / float(contours) * 1.08, 0.050, course_length * 1.18)
				mesh.left_to_right = 0.50
				panel.mesh = mesh
				panel.position = point
				panel.rotation.x = pitch
				panel.rotation.z = side * deg_to_rad(3.0 + 34.0 * pow(contour, 1.15))
				var material_key := "deep_teal"
				if contour_index >= contours - 2:
					material_key = "blue_steel"
				elif contour_index >= int(contours * 0.58):
					material_key = "side_teal"
				elif (row_index * 3 + contour_index) % 17 == 0:
					# Sparse violet scales read as magic travelling through the
					# natural shell rather than turning the bonnet purple.
					material_key = "purple"
				elif contour_index < int(contours * 0.36) or (row_index + contour_index) % 5 == 0:
					material_key = "light_teal"
				panel.material_override = _materials[material_key]
				add_child(panel)


func _build_gold_flow_ribs() -> void:
	for side in [-1.0, 1.0]:
		for rib_index in 5:
			var contour := 0.14 + float(rib_index) * 0.17
			for segment_index in 18:
				var t0 := 0.05 + float(segment_index) * 0.05
				var t1 := t0 + 0.05
				# Cyan conduits are the train technology; warm sandstone is the
				# crafted framework joining the nature shell and magical core.
				var rib_material: Material = _materials.cyan if rib_index in [1, 3] else (
					_materials.accent_gold if rib_index == 2 else _materials.coral)
				_add_beam("EnergyFlowRib", _surface_point(t0, side * contour, false, 0.10),
					_surface_point(t1, side * contour, false, 0.10), 0.026, rib_material)
	for segment_index in 22:
		var t0 := float(segment_index) / 22.0
		var t1 := float(segment_index + 1) / 22.0
		var spine_material: Material = _materials.purple if segment_index % 4 == 1 else (
			_materials.accent_gold if segment_index % 6 == 0 else _materials.coral)
		_add_beam("CrownSpine", _surface_point(t0, 0.0, false, 0.13),
			_surface_point(t1, 0.0, false, 0.13), 0.038, spine_material)


func _build_macro_leaf_panels() -> void:
	var panel_index := 0
	for t in [0.24, 0.45, 0.66, 0.84]:
		var previous := _surface_point(maxf(0.0, t - 0.02), 0.0)
		var following := _surface_point(minf(1.0, t + 0.02), 0.0)
		var pitch := -atan2(following.y - previous.y, following.z - previous.z)
		var half_width := _sample(_blueprint.upper_widths, t)
		for side in [-1.0, 1.0]:
			for contour in [0.27, 0.62]:
				var centre := _surface_point(t, side * contour, false, 0.10)
				var panel := MeshInstance3D.new()
				panel.name = "MacroLeafPanel_%02d" % panel_index
				var mesh := PrismMesh.new()
				mesh.size = Vector3(maxf(0.34, half_width * 0.34), 0.072, 1.52 + t * 0.48)
				mesh.left_to_right = 0.50
				panel.mesh = mesh
				panel.position = centre
				panel.rotation.x = pitch
				panel.rotation.z = side * deg_to_rad(8.0 + contour * 24.0)
				panel.material_override = _materials.light_teal if panel_index % 4 == 0 else _materials.nature_green
				add_child(panel)
				var tip_a := centre + Vector3(0.0, 0.045, -mesh.size.z * 0.44)
				var tip_b := centre + Vector3(0.0, 0.045, mesh.size.z * 0.44)
				_add_beam("MacroLeafMidrib", tip_a, tip_b, 0.032,
					_materials.cyan if panel_index % 4 == 0 else _materials.accent_gold)
				panel_index += 1


func _build_crystal_socket() -> void:
	var socket_z := float(_blueprint.cover_start_z) + 0.18
	for ring_index in 3:
		var ring := MeshInstance3D.new()
		ring.name = "CrystalSocketRing_%02d" % ring_index
		var torus := TorusMesh.new()
		torus.inner_radius = 0.58 + float(ring_index) * 0.08
		torus.outer_radius = torus.inner_radius + 0.07
		torus.rings = 24
		torus.ring_segments = 8
		ring.mesh = torus
		ring.rotation.x = PI * 0.5
		ring.position = Vector3(0.0, 3.18, socket_z + float(ring_index) * 0.24)
		if ring_index == 0:
			ring.material_override = _materials.accent_gold
		elif ring_index == 1:
			ring.material_override = _materials.purple
		else:
			ring.material_override = _materials.nature_green
		add_child(ring)
	var crystal := MeshInstance3D.new()
	crystal.name = "HalfExposedPowerCrystal"
	var crystal_mesh := CylinderMesh.new()
	crystal_mesh.top_radius = 0.05
	crystal_mesh.bottom_radius = 0.62
	crystal_mesh.height = 1.10
	crystal_mesh.radial_segments = 8
	crystal.mesh = crystal_mesh
	crystal.rotation.x = -PI * 0.5
	crystal.position = Vector3(0.0, 3.18, socket_z - 0.30)
	crystal.material_override = _materials.cyan
	add_child(crystal)


func _add_beam(node_name: String, start: Vector3, finish: Vector3, radius: float,
		material: Material) -> void:
	var direction := finish - start
	if direction.length() < 0.001:
		return
	var beam := MeshInstance3D.new()
	beam.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = direction.length()
	mesh.radial_segments = 6
	beam.mesh = mesh
	beam.position = (start + finish) * 0.5
	beam.basis = Basis.looking_at(direction.normalized(), Vector3.UP) * Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0))
	beam.material_override = material
	add_child(beam)


func _count_render_components(root_node: Node) -> int:
	var count := 0
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		count += 1
	return count
