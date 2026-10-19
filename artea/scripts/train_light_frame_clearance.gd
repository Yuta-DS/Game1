extends RefCounted
## Keep roof sockets in place; offset only pendants that intersect the fitted
## gold windscreen. A connected outboard arm carries each moved hanger.

const FRAME_GAP := .10
const OFFSET_STEP := .04
const MAX_OFFSET := .80

static func fit(train: Node3D) -> void:
	var frame := train.get_node("DriverFrontWindscreen") as Node3D
	var decor := train.find_child("GoldenChristmasExpressDecor", true, false) as Node3D
	var faces := PackedVector3Array()
	for part: MeshInstance3D in frame.find_children("*", "MeshInstance3D", true, false):
		var material := part.get_active_material(0)
		if material == null or material.resource_name != "WindscreenChampagneGold":
			continue
		# This runs while the AnimatableBody is being assembled, before its
		# first physics sync. Use the local hierarchy, not cached world poses.
		var pose := Transform3D.IDENTITY
		var ancestor: Node3D = part
		while ancestor != train:
			pose = ancestor.transform * pose
			ancestor = ancestor.get_parent() as Node3D
		for vertex in part.mesh.get_faces():
			faces.append(pose * vertex)
	if faces.is_empty():
		push_error("Cannot measure roof light clearance without the gold frame")
		return
	var moved := 0
	decor.set_meta("frame_clearance_triangle_vertices", faces.size())
	for ball: MeshInstance3D in decor.find_children("*", "MeshInstance3D", false, false):
		var label := String(ball.name)
		if not ball.mesh is SphereMesh or not (label.begins_with("RoofBall_00_") or label.begins_with("EngineRearRoofBall_")):
			continue
		var original := ball.position
		ball.set_meta("original_pendant_position", original)
		ball.set_meta("roof_pendant_offset", Vector3.ZERO)
		var radius := (ball.mesh as SphereMesh).radius
		var old_distance := distance_to_frame(original, faces)
		ball.set_meta("frame_distance_before_fit", old_distance)
		if old_distance >= radius + FRAME_GAP:
			continue
		var offset := Vector3.ZERO
		var found := false
		for step in range(1, int(MAX_OFFSET / OFFSET_STEP) + 1):
			offset = Vector3(signf(original.x) * OFFSET_STEP * step, 0, 0)
			var candidate := original + offset
			if distance_to_frame(candidate, faces) < radius + FRAME_GAP:
				continue
			# Check the cap, stem and horizontal arm as well as the globe.
			var fixtures_clear := distance_to_frame(candidate + Vector3.UP * .30, faces) >= .16
			for sample in 9:
				var ratio := sample / 8.0
				fixtures_clear = fixtures_clear \
					and distance_to_frame(candidate + Vector3.UP * lerpf(.20, .40, ratio), faces) >= .115 \
					and distance_to_frame(original + Vector3.UP * .40 + offset * ratio, faces) >= .09
			if fixtures_clear:
				found = true
				break
		if not found:
			push_error("Unable to clear roof pendant from windscreen: " + label)
			continue
		var cap := decor.get_node(label + "_GoldCap") as MeshInstance3D
		var hanger := decor.get_node(label.replace("RoofBall_", "RoofBallHanger_")) as MeshInstance3D
		ball.position += offset
		cap.position += offset
		hanger.position += offset
		ball.set_meta("roof_pendant_offset", offset)
		var arm := MeshInstance3D.new()
		arm.name = label + "_FrameClearanceArm"
		var tube := CylinderMesh.new()
		tube.top_radius = .04
		tube.bottom_radius = .04
		tube.height = offset.length()
		tube.radial_segments = 12
		arm.mesh = tube
		arm.material_override = cap.material_override
		arm.position = original + Vector3.UP * .40 + offset * .5
		arm.basis = Basis(Quaternion(Vector3.UP, offset.normalized()))
		decor.add_child(arm)
		moved += 1
	decor.set_meta("driver_offset_pendant_count", moved)
	decor.set_meta("driver_light_frame_clearance_m", FRAME_GAP)

static func distance_to_frame(point: Vector3, faces: PackedVector3Array) -> float:
	var distance_squared := INF
	for i in range(0, faces.size(), 3):
		var closest := _closest_triangle(point, faces[i], faces[i + 1], faces[i + 2])
		if closest.is_finite():
			distance_squared = minf(distance_squared, point.distance_squared_to(closest))
	return sqrt(distance_squared)

static func _closest_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	# Closest point in the triangle's vertex, edge or interior Voronoi region.
	var ab := b - a
	var ac := c - a
	# Primitive sphere poles can have zero-area triangles. Never let NaNs
	# from these reset the minimum distance to the real frame surface.
	if ab.cross(ac).length_squared() < .000000000001:
		var closest := a
		for edge in [[a, b], [b, c], [c, a]]:
			var delta: Vector3 = edge[1] - edge[0]
			var length_squared := delta.length_squared()
			var candidate: Vector3 = edge[0]
			if length_squared > .000000000001:
				candidate += delta * clampf((p - candidate).dot(delta) / length_squared, 0, 1)
			if p.distance_squared_to(candidate) < p.distance_squared_to(closest):
				closest = candidate
		return closest
	var ap := p - a
	var d1 := ab.dot(ap)
	var d2 := ac.dot(ap)
	if d1 <= 0 and d2 <= 0:
		return a
	var bp := p - b
	var d3 := ab.dot(bp)
	var d4 := ac.dot(bp)
	if d3 >= 0 and d4 <= d3:
		return b
	var vc := d1 * d4 - d3 * d2
	if vc <= 0 and d1 >= 0 and d3 <= 0:
		return a + ab * (d1 / (d1 - d3))
	var cp := p - c
	var d5 := ab.dot(cp)
	var d6 := ac.dot(cp)
	if d6 >= 0 and d5 <= d6:
		return c
	var vb := d5 * d2 - d1 * d6
	if vb <= 0 and d2 >= 0 and d6 <= 0:
		return a + ac * (d2 / (d2 - d6))
	var va := d3 * d6 - d5 * d4
	if va <= 0 and d4 - d3 >= 0 and d5 - d6 >= 0:
		return b + (c - b) * ((d4 - d3) / ((d4 - d3) + (d5 - d6)))
	var denominator := va + vb + vc
	if absf(denominator) < .000000001:
		return a
	return a + ab * (vb / denominator) + ac * (vc / denominator)
