extends RefCounted
## Swept panoramic locomotive glazing, with a restrained machined surround.

const HALF_WIDTH := 4.43
const BOTTOM := 3.24
const TOP := 7.44
const CORNER_RADIUS := 1.02
const FRAME_WIDTH := 0.14
const SEAL_WIDTH := 0.035
const DEPTH := 0.18
const FRONT_Z := -19.72
const RAKE := 0.14
const WRAP := 0.48
const TAPER := 0.10
const GLASS_ALPHA := 0.045

static func is_legacy_component(box: AABB, material_name: String) -> bool:
	# Replace whole objects only. The boiler band starts at z=-19.889,
	# outside this measured window plane, and must remain untouched.
	if box.position.z < -19.85 or box.end.z > -19.15:
		return false
	return material_name.contains("cab_clear_cyan_glass") \
		or material_name.contains("warm_ivory") \
		or (material_name.contains("crown_accentgold") and box.size.x > 8.0 and box.size.y > 5.0)

static func build(train: Node3D) -> Node3D:
	var assembly := Node3D.new()
	assembly.name = "DriverFrontWindscreen"
	train.add_child(assembly)
	var gold := StandardMaterial3D.new()
	gold.resource_name = "WindscreenChampagneGold"
	gold.albedo_color = Color("e7bb58")
	gold.metallic = 0.68
	gold.roughness = 0.24
	gold.emission_enabled = true
	gold.emission = Color("e7bb58")
	gold.emission_energy_multiplier = 0.10
	var metal := StandardMaterial3D.new()
	metal.resource_name = "WindscreenSatinTitanium"
	metal.albedo_color = Color("405058")
	metal.metallic = 0.50
	metal.roughness = 0.36
	var rubber := StandardMaterial3D.new()
	rubber.resource_name = "WindscreenGraphiteSeal"
	rubber.albedo_color = Color("14212c")
	rubber.roughness = 0.88
	# The full perimeter is gold, following exactly the same rounded, wrapped
	# profile as the pane. A fine recessed seal holds the glass inside the frame.
	_add_mesh(assembly, "ContinuousGoldFrame", _ring(0.0, FRAME_WIDTH, DEPTH), gold)
	_add_mesh(assembly, "RecessedRubberSeal", _ring(FRAME_WIDTH, FRAME_WIDTH + SEAL_WIDTH, 0.055), rubber)
	var glass := StandardMaterial3D.new()
	glass.resource_name = "WindscreenClearGlass"
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.albedo_color = Color(0.92, 0.98, 1.0, GLASS_ALPHA)
	glass.roughness = 0.18
	glass.metallic = 0.0
	# One double-sided surface, not a transparent box with overlapping faces.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rim := outline(FRAME_WIDTH + SEAL_WIDTH)
	var center := Vector2(0, (BOTTOM + TOP) * 0.5)
	# Concentric tessellation follows the gentle wrap without large planar
	# facets or stacked transparent faces.
	for ring in range(1, 9):
		var inner_ratio := float(ring - 1) / 8.0
		var outer_ratio := float(ring) / 8.0
		for i in rim.size():
			var j := (i + 1) % rim.size()
			var a := surface_point(center.lerp(rim[i], inner_ratio))
			var b := surface_point(center.lerp(rim[i], outer_ratio))
			var c := surface_point(center.lerp(rim[j], outer_ratio))
			var d := surface_point(center.lerp(rim[j], inner_ratio))
			_triangle(surface, a, c, b)
			if ring > 1:
				_triangle(surface, a, d, c)
	var pane := _add_mesh(assembly, "SingleClearPane", surface.commit(), glass)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Uprights continue into the body. Small upper brackets meet the roof
	# underside (y=7.48), keeping the curved header clear of the purple skin.
	for side in [-1, 1]:
		_bar(assembly, "RoofMountLeft" if side < 0 else "RoofMountRight",
			surface_point(Vector2(side * 3.20, 7.31), 0.05),
			surface_point(Vector2(side * 3.20, 7.54), 0.05), 0.085, gold)
		_bar(assembly, "LowerMountLeft" if side < 0 else "LowerMountRight",
			surface_point(Vector2(side * 4.36, 2.20)),
			surface_point(Vector2(side * 4.30, 3.98)), FRAME_WIDTH, gold)
		# Small parked wipers stay along the lower edge, below the road window.
		var pivot := surface_point(Vector2(side * 2.85, 3.37), -0.07)
		var elbow := surface_point(Vector2(side * 1.82, 3.51), -0.07)
		_bar(assembly, "ParkedWiperArmLeft" if side < 0 else "ParkedWiperArmRight",
			pivot, elbow, 0.026, metal)
		_bar(assembly, "ParkedWiperBladeLeft" if side < 0 else "ParkedWiperBladeRight",
			surface_point(Vector2(side * 1.22, 3.51), -0.05),
			surface_point(Vector2(side * 2.42, 3.51), -0.05), 0.040, rubber)
		var cap := SphereMesh.new()
		cap.radius = 0.045
		cap.height = 0.09
		var bearing := _add_mesh(assembly, "WiperBearingLeft" if side < 0 else "WiperBearingRight", cap, gold)
		bearing.position = pivot
	assembly.set_meta("glass_alpha", GLASS_ALPHA)
	assembly.set_meta("frame_width_m", FRAME_WIDTH)
	return assembly

static func outline(inset: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	var radius := CORNER_RADIUS - inset
	var centers := [Vector2(HALF_WIDTH - CORNER_RADIUS, TOP - CORNER_RADIUS),
		Vector2(-HALF_WIDTH + CORNER_RADIUS, TOP - CORNER_RADIUS),
		Vector2(-HALF_WIDTH + CORNER_RADIUS, BOTTOM + CORNER_RADIUS),
		Vector2(HALF_WIDTH - CORNER_RADIUS, BOTTOM + CORNER_RADIUS)]
	for corner in 4:
		for step in 13:
			var angle := (float(corner) + float(step) / 12.0) * PI * 0.5
			corners.append(centers[corner] + Vector2(cos(angle), sin(angle)) * radius)
	var points := PackedVector2Array()
	for i in corners.size():
		var a := corners[i]
		var b := corners[(i + 1) % corners.size()]
		var steps := maxi(1, ceili(a.distance_to(b) / 0.20))
		for step in steps:
			var point := a.lerp(b, float(step) / float(steps))
			var height := (point.y - BOTTOM) / (TOP - BOTTOM)
			var x_ratio := point.x / HALF_WIDTH
			point.x *= 1.0 - TAPER * height
			point.y -= 0.12 * pow(height, 3.0) * x_ratio * x_ratio
			points.append(point)
	return points

static func _ring(outer_inset: float, inner_inset: float, depth: float) -> ArrayMesh:
	var outer := outline(outer_inset)
	var inner := outline(inner_inset)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# All nested outlines must share the same parameter samples. See the
	# fixed connector tessellation in outline().
	var front := -depth * 0.5
	var back := depth * 0.5
	for i in outer.size():
		var j := (i + 1) % outer.size()
		_quad(tool, _point(outer[i], front), _point(inner[i], front),
			_point(inner[j], front), _point(outer[j], front))
		_quad(tool, _point(outer[j], back), _point(inner[j], back),
			_point(inner[i], back), _point(outer[i], back))
		_quad(tool, _point(outer[i], back), _point(outer[i], front),
			_point(outer[j], front), _point(outer[j], back))
		_quad(tool, _point(inner[j], back), _point(inner[j], front),
			_point(inner[i], front), _point(inner[i], back))
	return tool.commit()

static func surface_point(point: Vector2, offset_z: float = 0.0) -> Vector3:
	return Vector3(point.x, point.y, FRONT_Z + RAKE * (point.y - BOTTOM)
		+ WRAP * pow(point.x / HALF_WIDTH, 2.0) + offset_z)

static func _point(point: Vector2, offset_z: float) -> Vector3:
	return surface_point(point, offset_z)

static func _bar(parent: Node3D, label: String, a: Vector3, b: Vector3,
		width: float, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, a.distance_to(b), width)
	var instance := _add_mesh(parent, label, mesh, material)
	instance.position = (a + b) * 0.5
	instance.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot renders clockwise triangles; the normal points out of that face.
	var normal := (c - a).cross(b - a).normalized()
	for vertex in [a, b, c]:
		tool.set_normal(normal)
		tool.add_vertex(vertex)

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(tool, a, c, b)
	_triangle(tool, a, d, c)

static func _add_mesh(parent: Node3D, label: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
