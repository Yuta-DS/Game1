# One-off: checks which vertex order for the crown deck's centre-disc fan
# (the triangle-fan floor inside inner_radius in _crown_deck_mesh) actually
# faces up, by building both candidate orders and reading back the generated
# normal — same empirical approach as diag_helix_winding.gd, since hand
# derivation already proved unreliable once this session.
extends SceneTree


func _normal_for(order_reversed: bool) -> Vector3:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre_top := Vector3(0, 1, 0)
	var a0 := 0.0
	var a1 := deg_to_rad(10.0)
	var c0t := Vector3(cos(a0) * 4.0, 1, sin(a0) * 4.0)
	var c1t := Vector3(cos(a1) * 4.0, 1, sin(a1) * 4.0)
	if order_reversed:
		surface.add_vertex(centre_top)
		surface.add_vertex(c0t)
		surface.add_vertex(c1t)
	else:
		surface.add_vertex(centre_top)
		surface.add_vertex(c1t)
		surface.add_vertex(c0t)
	surface.generate_normals()
	var mesh := surface.commit()
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	return normals[0]


func _bottom_normal_for(order: Array) -> Vector3:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre_bottom := Vector3(0, 0, 0)
	var a0 := 0.0
	var a1 := deg_to_rad(10.0)
	var c0b := Vector3(cos(a0) * 4.0, 0, sin(a0) * 4.0)
	var c1b := Vector3(cos(a1) * 4.0, 0, sin(a1) * 4.0)
	var points := {"centre": centre_bottom, "c0": c0b, "c1": c1b}
	for key in order:
		surface.add_vertex(points[key])
	surface.generate_normals()
	var mesh := surface.commit()
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	return normals[0]


func _wedge_cap_normal(cut_angle: float, at_start: bool) -> Vector3:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_y := 1.0
	var bottom_y := 0.0
	var inner_radius := 5.0
	var cut_outer_radius := 8.0
	var ot := Vector3(cos(cut_angle) * cut_outer_radius, top_y, sin(cut_angle) * cut_outer_radius)
	var ob := Vector3(ot.x, bottom_y, ot.z)
	var it := Vector3(cos(cut_angle) * inner_radius, top_y, sin(cut_angle) * inner_radius)
	var ib := Vector3(it.x, bottom_y, it.z)
	if at_start:
		surface.add_vertex(it); surface.add_vertex(ot); surface.add_vertex(ob)
		surface.add_vertex(it); surface.add_vertex(ob); surface.add_vertex(ib)
	else:
		surface.add_vertex(ib); surface.add_vertex(ob); surface.add_vertex(ot)
		surface.add_vertex(ib); surface.add_vertex(ot); surface.add_vertex(it)
	surface.generate_normals()
	var mesh := surface.commit()
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	return normals[0]


func _tapered_landing_top_normal(order: Array) -> Vector3:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_length := 2.0
	var outer_width := 3.0
	var inner_width := 1.0
	var half_height := 0.5
	var outer_left := Vector3(half_length, half_height, -outer_width * 0.5)
	var outer_right := Vector3(half_length, half_height, outer_width * 0.5)
	var inner_left := Vector3(-half_length, half_height, -inner_width * 0.5)
	var inner_right := Vector3(-half_length, half_height, inner_width * 0.5)
	var points := {"ol": outer_left, "or": outer_right, "il": inner_left, "ir": inner_right}
	for key in order:
		surface.add_vertex(points[key])
	surface.generate_normals()
	var mesh := surface.commit()
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	return normals[0]


func _tapered_landing_face_normal(labels: Array, order: Array) -> Vector3:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_length := 2.0
	var outer_width := 3.0
	var inner_width := 1.0
	var half_height := 0.5
	var points := {
		"ol": Vector3(half_length, half_height, -outer_width * 0.5),
		"or": Vector3(half_length, half_height, outer_width * 0.5),
		"il": Vector3(-half_length, half_height, -inner_width * 0.5),
		"ir": Vector3(-half_length, half_height, inner_width * 0.5),
		"olb": Vector3(half_length, -half_height, -outer_width * 0.5),
		"orb": Vector3(half_length, -half_height, outer_width * 0.5),
		"ilb": Vector3(-half_length, -half_height, -inner_width * 0.5),
		"irb": Vector3(-half_length, -half_height, inner_width * 0.5),
	}
	var quad: Array = []
	for key in labels:
		quad.append(points[key])
	for idx in order:
		surface.add_vertex(quad[idx])
	surface.generate_normals()
	var mesh := surface.commit()
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	return normals[0]


func _curved_cap_normal(at_inner: bool, forward: bool) -> Vector3:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_y := 1.0
	var bottom_y := 0.0
	var radius := 5.0 if at_inner else 8.0
	var a0 := deg_to_rad(-10.0)
	var a1 := deg_to_rad(10.0)
	var p0t := Vector3(cos(a0) * radius, top_y, sin(a0) * radius)
	var p1t := Vector3(cos(a1) * radius, top_y, sin(a1) * radius)
	var p0b := Vector3(p0t.x, bottom_y, p0t.z)
	var p1b := Vector3(p1t.x, bottom_y, p1t.z)
	if forward:
		surface.add_vertex(p0t); surface.add_vertex(p1t); surface.add_vertex(p1b)
		surface.add_vertex(p0t); surface.add_vertex(p1b); surface.add_vertex(p0b)
	else:
		surface.add_vertex(p1t); surface.add_vertex(p0t); surface.add_vertex(p0b)
		surface.add_vertex(p1t); surface.add_vertex(p0b); surface.add_vertex(p1b)
	surface.generate_normals()
	var mesh := surface.commit()
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	return normals[0]


func _run() -> void:
	# Inner cap (radius 5.0) should face OUTWARD (+X-ish, away from centre,
	# into the open wedge). Outer cap (radius 8.0) should face INWARD
	# (-X-ish, toward centre, into the open wedge).
	print("inner curved cap, forward order, normal (want +X-ish): ", _curved_cap_normal(true, true))
	print("inner curved cap, reversed order, normal: ", _curved_cap_normal(true, false))
	print("outer curved cap, forward order, normal (want -X-ish): ", _curved_cap_normal(false, true))
	print("outer curved cap, reversed order, normal: ", _curved_cap_normal(false, false))
	# Current top-face order in _tapered_landing_mesh is
	# (outer_left, inner_left, inner_right, outer_right), split as two
	# triangles (ol,il,ir) and (ol,ir,or) by _add_surface_quad.
	print("tapered landing top: current order normal: ",
		_tapered_landing_top_normal(["ol", "il", "ir", "ol", "ir", "or"]))
	print("tapered landing top: reversed order normal: ",
		_tapered_landing_top_normal(["or", "ir", "il", "or", "il", "ol"]))
	# bottom: current order (olb, orb, irb, ilb); should face -Y (down).
	print("tapered landing bottom: current order normal (want -Y): ",
		_tapered_landing_face_normal(["olb", "orb", "irb", "ilb"], [0, 1, 2, 0, 2, 3]))
	# left side (outer_left_bottom, inner_left_bottom, inner_left, outer_left);
	# should face -Z (outward, since outer_left/inner_left are at -width/2).
	print("tapered landing left side: current order normal (want -Z-ish): ",
		_tapered_landing_face_normal(["olb", "ilb", "il", "ol"], [0, 1, 2, 0, 2, 3]))
	# right side (outer_right, inner_right, inner_right_bottom,
	# outer_right_bottom); should face +Z (outward).
	print("tapered landing right side: current order normal (want +Z-ish): ",
		_tapered_landing_face_normal(["or", "ir", "irb", "orb"], [0, 1, 2, 0, 2, 3]))
	# outer end (outer_left_bottom, outer_left, outer_right, outer_right_bottom);
	# should face +X (outward, toward the spiral's outer edge).
	print("tapered landing outer end: current order normal (want +X-ish): ",
		_tapered_landing_face_normal(["olb", "ol", "or", "orb"], [0, 1, 2, 0, 2, 3]))
	# inner end (inner_left, inner_left_bottom, inner_right_bottom, inner_right);
	# should face -X (outward, toward the crown floor it disappears into).
	print("tapered landing inner end: current order normal (want -X-ish): ",
		_tapered_landing_face_normal(["il", "ilb", "irb", "ir"], [0, 1, 2, 0, 2, 3]))
	print("top: current order (centre, c1, c0) normal: ", _normal_for(false))
	print("top: proposed order (centre, c0, c1) normal: ", _normal_for(true))
	print("bottom: new order (centre, c1, c0) normal: ", _bottom_normal_for(["centre", "c1", "c0"]))
	print("bottom: old order (centre, c0, c1) normal: ", _bottom_normal_for(["centre", "c0", "c1"]))
	# Wedge is centred on angle 0, spanning -0.3..0.3 rad. The open (cut) side
	# faces toward angle 0 (inward, toward the wedge centre) from each edge.
	print("wedge cap at cut_start (-0.3 rad), current order, normal: ", _wedge_cap_normal(-0.3, true))
	print("wedge cap at cut_end (+0.3 rad), current order, normal: ", _wedge_cap_normal(0.3, false))
	quit(0)


func _init() -> void:
	call_deferred("_run")
