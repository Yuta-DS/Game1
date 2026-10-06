extends RefCounted
## Tail-clear captain's chair fitted around the existing seated fox pose.
## The seating/camera/handle anchors do not move.

const CUSHION_TOP := 3.15
const SEAT_Z := -15.02
const TAIL_CLEARANCE_TOP := 3.55

static func is_legacy_component(bounds: AABB, material: String) -> bool:
	# Whole measured chair pieces only. Keep the original pedestal/swivel,
	# deck tiles, dashboard, console controls and every passenger seat.
	if bounds.position.x < -1.60 or bounds.end.x > 1.60 \
			or bounds.position.z < -16.65 or bounds.end.z > -13.65:
		return false
	if material.contains("seat_navy"):
		return bounds.position.y > 2.75 and bounds.end.y < 4.8
	if bounds.position.z < -16.0 or bounds.position.y < 2.62 or bounds.end.y > 5.85:
		return false
	return material in ["crown_gold", "crown_accentgold", "leaf_teal", "leaf_inner_light", "crystal_purple"]

static func build(train: Node3D, upholstery: Material) -> Node3D:
	var chair := Node3D.new()
	chair.name = "DriverCaptainSeat"
	train.add_child(chair)
	var gold := StandardMaterial3D.new()
	gold.resource_name = "CaptainSeatWarmGold"
	gold.albedo_color = Color("e7bb58")
	gold.metallic = .62
	gold.roughness = .25
	gold.emission_enabled = true
	gold.emission = Color("e7bb58")
	gold.emission_energy_multiplier = .10
	var pearl := StandardMaterial3D.new()
	pearl.resource_name = "CaptainSeatPearlShell"
	pearl.albedo_color = Color("fff2d8")
	pearl.roughness = .30
	var fabric := upholstery.duplicate() as ShaderMaterial
	fabric.shader = preload("res://shaders/train_captain_upholstery.gdshader")
	fabric.resource_name = "AuroraQuiltedCaptainUpholstery"
	fabric.set_meta("seat_effect_style", "quilted_aurora_silk")
	_box(chair, "GoldSeatPan", Vector3(0, 2.83, SEAT_Z), Vector3(1.92, .20, 1.12), .09, gold)
	_box(chair, "PearlSeatShell", Vector3(0, 2.94, SEAT_Z), Vector3(1.83, .18, 1.02), .08, pearl)
	_box(chair, "RainbowSeatCushion", Vector3(0, 3.025, SEAT_Z), Vector3(1.70, .25, .86), .12, fabric)
	var cushion_edge := PackedVector3Array()
	for corner in 4:
		var angle := corner * PI * .5
		# Rounded rectangle in the X/Z plane; each corner has its own centre.
		var centre: Vector2 = [Vector2(.72, .30), Vector2(-.72, .30), Vector2(-.72, -.30), Vector2(.72, -.30)][corner]
		for sample in 9:
			var point := centre + Vector2.from_angle(angle + sample * PI / 16.0) * .12
			cushion_edge.append(Vector3(point.x, 3.025, SEAT_Z + point.y))
	cushion_edge.append(cushion_edge[0])
	_tubes(chair, "CushionGoldPiping", [cushion_edge], .012, gold)
	# The back starts above the fox tail and reclines away from the character.
	var back := Node3D.new()
	back.name = "ReclinedBackrest"
	chair.add_child(back)
	back.position = Vector3(0, 4.25, -14.45)
	back.rotation.x = .10
	_panel(back, "GoldBackSurround", _back_outline(Vector2.ONE), .20, 0.0, gold)
	_panel(back, "PearlBackShell", _back_outline(Vector2(.95, .95)), .17, -.035, pearl)
	_panel(back, "RainbowContouredBackPad", _back_outline(Vector2(.88, .86)), .19, -.13, fabric)
	_snowflake_badge(back, gold, pearl)
	for side in [-1, 1]:
		var support := PackedVector3Array()
		var arm := PackedVector3Array()
		for sample in 17:
			var t := sample / 16.0
			support.append(Vector3(side * .81, 2.88, -14.66).bezier_interpolate(
				Vector3(side * .86, 3.14, -14.46), Vector3(side * .84, 3.53, -14.50),
				Vector3(side * .77, 3.76, -14.50), t))
			arm.append(Vector3(side * .88, 2.89, -14.72).bezier_interpolate(
				Vector3(side * 1.08, 3.56, -14.45), Vector3(side * 1.08, 3.55, -15.42),
				Vector3(side * .88, 2.89, -15.34), t))
		_tubes(chair, "BackSupport_%d" % side, [support], .06, gold)
		_tubes(chair, "SweptArmSupport_%d" % side, [arm], .055, gold)
		_box(chair, "GoldArmTray_%d" % side, Vector3(side * 1.03, 3.42, -15.09), Vector3(.30, .12, .98), .055, gold)
		_box(chair, "PearlArmInlay_%d" % side, Vector3(side * 1.03, 3.46, -15.09), Vector3(.27, .10, .91), .045, pearl)
		_box(chair, "RainbowArmPad_%d" % side, Vector3(side * 1.03, 3.51, -15.09), Vector3(.24, .12, .85), .055, fabric)
	chair.set_meta("cushion_top_m", CUSHION_TOP)
	chair.set_meta("tail_clearance_top_m", TAIL_CLEARANCE_TOP)
	chair.set_meta("keeps_original_driver_anchor", true)
	chair.set_meta("chair_style", "aurora_snowflake_captain")
	return chair

static func _back_outline(scale: Vector2) -> PackedVector2Array:
	var segments := [
		[Vector2(0, .82), Vector2(.52, .82), Vector2(.96, .70), Vector2(.91, .42)],
		[Vector2(.91, .42), Vector2(.93, .20), Vector2(.90, -.25), Vector2(.88, -.42)],
		[Vector2(.88, -.42), Vector2(.88, -.58), Vector2(.80, -.64), Vector2(.68, -.64)],
		[Vector2(.68, -.64), Vector2(.28, -.64), Vector2(-.28, -.64), Vector2(-.68, -.64)],
		[Vector2(-.68, -.64), Vector2(-.80, -.64), Vector2(-.88, -.58), Vector2(-.88, -.42)],
		[Vector2(-.88, -.42), Vector2(-.90, -.25), Vector2(-.93, .20), Vector2(-.91, .42)],
		[Vector2(-.91, .42), Vector2(-.96, .70), Vector2(-.52, .82), Vector2(0, .82)]]
	var points := PackedVector2Array()
	for curve in segments:
		for i in 12:
			points.append((curve[0] as Vector2).bezier_interpolate(curve[1], curve[2], curve[3], i / 12.0) * scale)
	return points

static func _panel(parent: Node3D, label: String, outline: PackedVector2Array,
		depth: float, z: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for level in 4:
		var ring := PackedVector3Array()
		for p in outline:
			var scale: float = [.96, 1.0, 1.0, .94][level]
			ring.append(Vector3(p.x * scale, p.y * scale, z + depth * [.5, .30, -.30, -.5][level]))
		rings.append(ring)
	for i in outline.size():
		var next := (i + 1) % outline.size()
		for level in 3:
			var a := rings[level][i]
			var b := rings[level][next]
			var c := rings[level + 1][next]
			var d := rings[level + 1][i]
			var outward := Vector3(outline[i].x, outline[i].y, 0)
			_triangle(surface, a, b, c, outward)
			_triangle(surface, a, c, d, outward)
		_triangle(surface, Vector3(0, 0, z + depth * .5), rings[0][i], rings[0][next], Vector3.BACK)
		_triangle(surface, Vector3(0, 0, z - depth * .54), rings[3][i], rings[3][next], Vector3.FORWARD)
	surface.generate_normals()
	surface.index()
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = surface.commit()
	part.material_override = material
	parent.add_child(part)

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	if (c - a).cross(b - a).dot(outward) < 0:
		var swap := b
		b = c
		c = swap
	for vertex in [a, b, c]:
		surface.set_uv(Vector2(vertex.x / 1.60 + .5, (vertex.y + .55) / 1.25))
		surface.add_vertex(vertex)

static func _tubes(parent: Node3D, label: String, paths: Array, radius: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for points: PackedVector3Array in paths:
		var bounds := AABB(points[0], Vector3.ZERO)
		for p in points:
			bounds = bounds.expand(p)
		# A single least-aligned reference keeps each curved tube's frame stable.
		var reference := Vector3.RIGHT
		if bounds.size.y <= bounds.size.x and bounds.size.y <= bounds.size.z:
			reference = Vector3.UP
		elif bounds.size.z <= bounds.size.x and bounds.size.z <= bounds.size.y:
			reference = Vector3.BACK
		var closed := points[0].is_equal_approx(points[-1])
		var rings: Array[PackedVector3Array] = []
		for i in points.size():
			var before := points[maxi(i - 1, 0)]
			var after := points[mini(i + 1, points.size() - 1)]
			if closed and (i == 0 or i == points.size() - 1):
				before = points[-2]
				after = points[1]
			var axis := (after - before).normalized()
			var u := axis.cross(reference).normalized()
			var v := axis.cross(u)
			var ring := PackedVector3Array()
			for step in 10:
				ring.append(points[i] + (u * cos(TAU * step / 10.0) + v * sin(TAU * step / 10.0)) * radius)
			rings.append(ring)
		for i in points.size() - 1:
			var axis := (points[i + 1] - points[i]).normalized()
			for step in 10:
				var next := (step + 1) % 10
				var a := rings[i][step]
				var b := rings[i][next]
				var c := rings[i + 1][next]
				var d := rings[i + 1][step]
				var outward := (a + b) * .5 - points[i]
				_triangle(surface, a, b, c, outward)
				_triangle(surface, a, c, d, outward)
				if not closed and i == 0:
					_triangle(surface, points[i], b, a, -axis)
				if not closed and i == points.size() - 2:
					_triangle(surface, points[i + 1], d, c, axis)
	surface.generate_normals()
	surface.index()
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = surface.commit()
	part.material_override = material
	parent.add_child(part)

static func _snowflake_badge(back: Node3D, gold: Material, pearl: Material) -> void:
	var disk := MeshInstance3D.new()
	disk.name = "InsetSnowflakeMedallion"
	var mesh := CylinderMesh.new()
	mesh.top_radius = .16
	mesh.bottom_radius = .16
	mesh.height = .06
	mesh.radial_segments = 36
	disk.mesh = mesh
	disk.material_override = gold
	disk.position = Vector3(0, .58, -.245)
	disk.rotation.x = PI * .5
	back.add_child(disk)
	var paths: Array[PackedVector3Array] = []
	var centre := Vector3(0, .58, -.278)
	for arm in 6:
		var direction := Vector3(sin(TAU * arm / 6.0), cos(TAU * arm / 6.0), 0)
		paths.append(PackedVector3Array([centre, centre + direction * .122]))
		for side in [-1, 1]:
			var branch := direction.rotated(Vector3.BACK, side * .72)
			paths.append(PackedVector3Array([centre + direction * .07, centre + direction * .07 + branch * .046]))
	_tubes(back, "PearlSnowflakeInlay", paths, .009, pearl)

static func _box(parent: Node3D, label: String, position: Vector3, size: Vector3, radius: float, material: Material) -> void:
	var source := BoxMesh.new()
	source.size = size
	source.subdivide_width = 12
	source.subdivide_height = 12
	source.subdivide_depth = 12
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var inner := size * .5 - Vector3.ONE * radius
	for i in vertices.size():
		var core := vertices[i].clamp(-inner, inner)
		var normal := (vertices[i] - core).normalized()
		vertices[i] = core + normal * radius
		normals[i] = normal
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.material_override = material
	if material is ShaderMaterial:
		var fabric := material.duplicate() as ShaderMaterial
		fabric.set_shader_parameter("upholstery_phase", position.x * .29)
		part.material_override = fabric
	part.position = position
	parent.add_child(part)
