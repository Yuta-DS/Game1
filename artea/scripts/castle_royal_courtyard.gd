# The approved entrance parterre. Dimensions are shared with the floor owner;
# all floor decoration is a material, not additional collision/mesh layers.
extends RefCounted

const Garden := preload("res://scripts/castle_rooftop_garden.gd")
const ReferenceStyle := preload("res://scripts/castle_reference_style.gd")
const STONE_SHADER := preload("res://shaders/castle_courtyard_stone.gdshader")
const FLOOR_Y := 67.97
const CENTER := Vector3(-23.65, FLOOR_Y, 27.41)
const GATE_X := -19.3
const TOWER_LATERAL := 6.4
const WALL_LATERAL := 7.2


static func stone_material(paving := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = STONE_SHADER
	material.set_shader_parameter("paving", paving)
	material.set_shader_parameter("court_center", CENTER)
	return material


static func build(parent: Node3D) -> void:
	var court := Node3D.new()
	court.name = "RoyalEntranceCourtyard"
	parent.add_child(court)
	court.global_position = CENTER
	court.set_meta("preserve_castle_finish", true)
	court.set_meta("floor_policy", "one_level_collision_backed_stone_no_overlay")
	var stone := stone_material()
	var coping := ReferenceStyle.material("trim")
	var roof := ReferenceStyle.material("roof")
	var blue := Garden._material(Color("526671"))
	var gold := Garden._material(Color("c5a45e"))
	var gate := Node3D.new()
	gate.name = "CastleBridgeBarbican"
	parent.add_child(gate)
	gate.global_position = Vector3(GATE_X, FLOOR_Y, CENTER.z)
	gate.set_meta("preserve_castle_finish", true)
	gate.set_meta("clear_opening_width", 10.6)
	for side: float in [-1.0, 1.0]:
		var z := side * TOWER_LATERAL
		var tower := box(gate, "BarbicanTower", Vector3(2.2, 5.2, 2.2), Vector3(0, 2.6, z), stone, true)
		tower.get_child(0).name = "SolidBarbicanTower"
		for trim_y: float in [0.22, 4.91]:
			box(gate, "TowerDressedCourse", Vector3(2.3, 0.42, 2.3), Vector3(0, trim_y, z), ReferenceStyle.material("trim"))
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.64
		cone.height = 2.2
		cone.radial_segments = 4
		var cap := mesh(gate, "BarbicanSlateRoof", cone, Vector3(0, 6.3, z), roof)
		cap.rotation.y = PI * 0.25
		# Recessed lancet and small crown stay on the tower's front face.
		ReferenceStyle.window(gate, Vector3(1.11, 2.53, z), Vector3.RIGHT, 0.8)
		ReferenceStyle.cluster(gate, Vector3(1.11, 1.0, z + 0.2), Vector3.RIGHT, 0.75)
		ReferenceStyle.cluster(gate, Vector3(0, 2.1, z + side * 1.11), Vector3(0, 0, side), 0.9)
		crown(gate, Vector3(1.13, 4.39, z), gold, 0.55)
		# Continuous perimeter, with the gate towers integrated into the walls.
		var back := -28.0 - CENTER.x
		var front := -17.4 - CENTER.x
		var gate_back := GATE_X - 1.1 - CENTER.x
		var gate_front := GATE_X + 1.1 - CENTER.x
		for interval: Vector2 in [Vector2(back, gate_back), Vector2(gate_front, front)]:
			wall(court, "CourtyardSideBarrier", Vector3(interval.y - interval.x, 1.6, 0.6),
				Vector3((interval.x + interval.y) * 0.5, 0.8, side * WALL_LATERAL), stone, coping)
		wall(court, "BridgeMouthReturn", Vector3(0.6, 1.6, 3.99),
			Vector3(front - 0.3, 0.8, side * 5.505), stone, coping)
		wall(court, "StairFootReturn", Vector3(0.6, 1.6, 0.8),
			Vector3(back + 0.3, 0.8, side * 6.8), stone, coping)
		planter(court, Vector3(0.0, 0.0, side * 5.8), side, stone, coping, blue, gold)
	# Smooth arch: closed, individually solid masonry voussoirs. A shallow
	# ellipse preserves headroom without an enormous triangular roof above it.
	for index in 32:
		var a := PI * float(index) / 32.0
		var b := PI * float(index + 1) / 32.0
		var points := PackedVector3Array()
		for x: float in [-0.42, 0.42]:
			for value: Vector2 in [Vector2(5.30 * cos(a), 3.86 + 1.86 * sin(a)),
				Vector2(5.30 * cos(b), 3.86 + 1.86 * sin(b)),
				Vector2(5.68 * cos(b), 3.86 + 2.35 * sin(b)),
				Vector2(5.68 * cos(a), 3.86 + 2.35 * sin(a))]:
				points.append(Vector3(x, value.y, value.x))
		var arch := mesh(gate, "BarbicanArchStone_%02d" % index, prism(points), Vector3.ZERO,
			coping)
		solid(arch, arch.mesh.create_convex_shape())
	crown(gate, Vector3(0.432, 5.99, 0), gold, 0.54)


static func planter(parent: Node3D, origin: Vector3, side: float, stone: Material,
		coping: Material, _blue: Material, _gold: Material) -> void:
	var bed := Node3D.new()
	bed.name = "CourtyardFlowerBed_%d" % int(side)
	parent.add_child(bed)
	bed.position = origin
	bed.rotation.y = 0.0 if side > 0 else PI
	var plinth := mesh(bed, "SolidStonePlanter", Garden._chamfered_bed_mesh(Garden.BED_SIZE, 0.12), Vector3.ZERO, stone)
	solid(plinth, plinth.mesh.create_convex_shape())
	box(bed, "Soil", Vector3(2.35, 0.02, 1.12), Vector3(0, 0.314, 0), Garden._material(Color("514331")))
	for sign_value: float in [-1.0, 1.0]:
		box(bed, "PlanterRim", Vector3(2.39, 0.09, 0.14), Vector3(0, 0.275, sign_value * 0.63), coping)
		box(bed, "PlanterRim", Vector3(0.14, 0.09, 1.18), Vector3(sign_value * 1.24, 0.275, 0), coping)
	Garden.Herbs.build(bed, Garden.BED_SIZE.y)


static func wall(parent: Node3D, label: String, size: Vector3, at: Vector3, stone: Material, coping: Material) -> void:
	# Separate the stone and coping faces at their joint. Coplanar overlays
	# shimmer in the real renderer even when the collider is otherwise sound.
	box(parent, label, Vector3(size.x, size.y - 0.13, size.z), at - Vector3.UP * 0.065, stone, true)
	box(parent, label + "Coping", Vector3(size.x, 0.13, size.z), at + Vector3.UP * (size.y * 0.5 - 0.065), coping, true)
	if size.x > 2.8:
		for side: float in [-1.0, 1.0]:
			ReferenceStyle.cluster(parent, at + Vector3(0, -0.05, side * (size.z * 0.5 + 0.005)),
				Vector3(0, 0, side), 0.9)


static func crown(parent: Node3D, at: Vector3, material: Material, width: float) -> void:
	box(parent, "RoyalCrownBand", Vector3(0.018, width * 0.12, width), at, material)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var z := float(i - 1) * width / 3.0
		for p: Vector3 in [Vector3(0.012, 0, z - width / 6), Vector3(0.012, 0, z + width / 6), Vector3(0.012, width * (0.5 if i == 1 else 0.34), z)]:
			surface.add_vertex(p)
	surface.generate_normals()
	mesh(parent, "RoyalCrownPoints", surface.commit(), at, material)


static func box(parent: Node3D, label: String, size: Vector3, at: Vector3, material: Material, collision := false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var part := mesh(parent, label, shape, at, material)
	if collision:
		var hull := BoxShape3D.new()
		hull.size = size
		solid(part, hull)
	return part


static func mesh(parent: Node3D, label: String, geometry: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = geometry
	part.material_override = material
	parent.add_child(part, true)
	part.position = at
	return part


static func solid(host: Node3D, hull: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.name = "CourtyardSolidBody"
	host.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "SolidShape"
	shape.shape = hull
	body.add_child(shape)


static func prism(points: PackedVector3Array) -> ArrayMesh:
	# Two matching four-vertex rings, closed with outward-facing triangles.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var center := Vector3.ZERO
	for p in points:
		center += p / 8.0
	for quad: Array in [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		for triangle: Array in [[quad[0], quad[1], quad[2]], [quad[0], quad[2], quad[3]]]:
			var a := points[triangle[0]]
			var b := points[triangle[1]]
			var c := points[triangle[2]]
			# Godot front faces are clockwise.
			if (b - a).cross(c - a).dot((a + b + c) / 3.0 - center) > 0:
				var swap := b
				b = c
				c = swap
			for vertex: Vector3 in [a, b, c]:
				surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()
