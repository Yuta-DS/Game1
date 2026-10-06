extends RefCounted
## Driver-only pearl transmission surround with scalloped gap infill.
## The top/bottom are covered; both broad faces remain open over the gears.
## No gear is hidden, reparented or resized.

const Transmission := preload("res://scripts/train_gear_transmission.gd")
const CLEARANCE := .18
const RAIL_RADIUS := .04
const WALL_THICKNESS := .045
const GEAR_OPENING_CLEARANCE := .15
const INNER_X := 5.40
const OUTER_X := 6.04
const DECK_Y := 1.30

static func build(train: Node3D) -> Node3D:
	var assembly := Node3D.new()
	assembly.name = "FPSGearHousings"
	assembly.visible = false
	train.add_child(assembly)
	var pearl := _material("GearHousingPearlEnamel", Color("f3e8d7"), .12, .32)
	var gold := _material("GearHousingChampagneGold", Color("d8b65e"), .65, .28)
	for side in ["L", "R"]:
		var circles := PackedVector2Array()
		var centres: Array[Vector3] = []
		var radii: Array[float] = []
		for i in 3:
			var gear := train.find_child("*Steam%sGear_%s_%d" % [Transmission.KINDS[i], side, i], true, false) as MeshInstance3D
			if gear == null:
				push_error("Cannot fit FPS housing: missing gear " + side + str(i))
				assembly.free()
				return null
			var centre := train.to_local(gear.global_position)
			var radius := Transmission.pitch_radius(i) + Transmission.MODULE
			centres.append(centre)
			radii.append(radius)
			for sample in 96:
				var point := Vector2(centre.z, centre.y) + Vector2.from_angle(TAU * sample / 96.0) * (radius + CLEARANCE)
				circles.append(point)
		var outline := Geometry2D.convex_hull(circles)
		outline.resize(outline.size() - 1) # convex_hull repeats its first point
		var housing := Node3D.new()
		housing.name = "TransmissionHousing_" + side
		assembly.add_child(housing)
		housing.scale.x = signf(centres[0].x)
		housing.set_meta("swept_centres", centres)
		housing.set_meta("swept_radii", radii)
		housing.set_meta("outline", outline)
		_curved_surround(housing, outline, pearl)
		_rail(housing, "InnerGoldGuard", outline, INNER_X, gold)
		_rail(housing, "OuterGoldGuard", outline, OUTER_X, gold)
		# Fill only unused space between the case and swept gear discs. The
		# joined scalloped opening leaves teeth and their meshing points exposed.
		var opening := _gear_opening(centres, radii, GEAR_OPENING_CLEARANCE)
		var gold_edge := _gear_opening(centres, radii, GEAR_OPENING_CLEARANCE + .02)
		var fan_centre := Vector2(centres[1].z, centres[1].y)
		for face in ["Inner", "Outer"]:
			var x := INNER_X + .015 if face == "Inner" else OUTER_X - .015
			_infill(housing, "PearlScallopedInfill" + face, outline, opening, fan_centre, x, pearl)
			_infill(housing, "GoldOpeningLip" + face, gold_edge, opening, fan_centre,
				x + (-.003 if face == "Inner" else .003), gold)
		# Short feet connect the retained shell to the deck below the teeth.
		for index in [0, 2]:
			var base_y := _outline_floor(outline, centres[index].z) + RAIL_RADIUS * .5
			_box(housing, "DeckFoot_%d" % index,
				Vector3((INNER_X + OUTER_X) * .5, (DECK_Y + base_y) * .5, centres[index].z),
				Vector3(OUTER_X - INNER_X + RAIL_RADIUS, base_y - DECK_Y + .02, .22), gold)
	return assembly

static func _material(label: String, color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = label
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material

static func _point(x: float, zy: Vector2) -> Vector3:
	return Vector3(x, zy.y, zy.x)

static func _gear_opening(centres: Array[Vector3], radii: Array[float], clearance: float) -> PackedVector2Array:
	var opening := PackedVector2Array()
	for i in centres.size():
		var circle := PackedVector2Array()
		for sample in 96:
			circle.append(Vector2(centres[i].z, centres[i].y)
				+ Vector2.from_angle(TAU * sample / 96.0) * (radii[i] + clearance))
		if opening.is_empty():
			opening = circle
		else:
			var merged := Geometry2D.merge_polygons(opening, circle)
			if merged.size() != 1:
				push_error("Gear inspection openings must join across both meshing points")
				return PackedVector2Array()
			opening = merged[0]
	return opening

static func _infill(parent: Node3D, label: String, outer: PackedVector2Array,
		opening: PackedVector2Array, centre: Vector2, x: float, material: Material) -> void:
	if opening.is_empty():
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The fan apex lies in the joined opening. Clipping individual fan cells
	# avoids feeding a polygon-with-a-hole to the simple polygon triangulator.
	for i in outer.size():
		var cell := PackedVector2Array([centre, outer[i], outer[(i + 1) % outer.size()]])
		for bounded in Geometry2D.intersect_polygons(cell, outer):
			for piece in Geometry2D.clip_polygons(bounded, opening):
				var triangles := Geometry2D.triangulate_polygon(piece)
				for t in range(0, triangles.size(), 3):
					var a := _point(x, piece[triangles[t]])
					var b := _point(x, piece[triangles[t + 1]])
					var c := _point(x, piece[triangles[t + 2]])
					_triangle(surface, a, b, c, Vector3.LEFT)
					_triangle(surface, a, b, c, Vector3.RIGHT)
	_add_mesh(parent, label, surface, material)

static func _curved_surround(parent: Node3D, outline: PackedVector2Array, material: Material) -> void:
	var centre := Vector2.ZERO
	for point in outline:
		centre += point
	centre /= outline.size()
	var surround := SurfaceTool.new()
	surround.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var inner_a := a.move_toward(centre, WALL_THICKNESS)
		var inner_b := b.move_toward(centre, WALL_THICKNESS)
		var radial := _point(0, (a + b) * .5 - centre).normalized()
		_quad(surround, _point(INNER_X, a), _point(OUTER_X, a),
			_point(OUTER_X, b), _point(INNER_X, b), radial)
		_quad(surround, _point(INNER_X, inner_a), _point(OUTER_X, inner_a),
			_point(OUTER_X, inner_b), _point(INNER_X, inner_b), -radial)
		# Finish the thin edges at BOTH openings, without filling either face.
		_quad(surround, _point(INNER_X, a), _point(INNER_X, b),
			_point(INNER_X, inner_b), _point(INNER_X, inner_a), Vector3.LEFT)
		_quad(surround, _point(OUTER_X, a), _point(OUTER_X, b),
			_point(OUTER_X, inner_b), _point(OUTER_X, inner_a), Vector3.RIGHT)
	_add_mesh(parent, "PearlCurvedSurround", surround, material)

static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_triangle(surface, a, b, c, outward)
	_triangle(surface, a, c, d, outward)

static func _outline_floor(outline: PackedVector2Array, z: float) -> float:
	var lowest := INF
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		if z < minf(a.x, b.x) or z > maxf(a.x, b.x):
			continue
		if absf(b.x - a.x) < .000001:
			lowest = minf(lowest, minf(a.y, b.y))
		else:
			lowest = minf(lowest, lerpf(a.y, b.y, (z - a.x) / (b.x - a.x)))
	return lowest

static func _rail(parent: Node3D, label: String, outline: PackedVector2Array, x: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# One closed tubular perimeter, not a transparent version of the old wall.
	var rings: Array[PackedVector3Array] = []
	for i in outline.size():
		var tangent := (outline[(i + 1) % outline.size()] - outline[(i + outline.size() - 1) % outline.size()]).normalized()
		var across := Vector3(0, tangent.x, -tangent.y)
		var ring := PackedVector3Array()
		for step in 8:
			var angle := TAU * step / 8.0
			ring.append(_point(x, outline[i]) + (Vector3.RIGHT * cos(angle) + across * sin(angle)) * RAIL_RADIUS)
		rings.append(ring)
	for i in outline.size():
		var next := (i + 1) % outline.size()
		for step in 8:
			var after := (step + 1) % 8
			var a := rings[i][step]
			var b := rings[next][step]
			var c := rings[next][after]
			var d := rings[i][after]
			var outward := ((a + b + c + d) * .25 - _point(x, (outline[i] + outline[next]) * .5)).normalized()
			_triangle(surface, a, b, c, outward)
			_triangle(surface, a, c, d, outward)
	_add_mesh(parent, label, surface, material)

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	if normal.dot(outward) < 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	for point in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(point)

static func _add_mesh(parent: Node3D, label: String, surface: SurfaceTool, material: Material) -> void:
	surface.index()
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = surface.commit()
	part.material_override = material
	parent.add_child(part)

static func _box(parent: Node3D, label: String, position: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.material_override = material
	part.position = position
	parent.add_child(part)
