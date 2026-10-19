extends RefCounted
## One phase drives both exposed transmissions. Imported discs lie in local
## XZ (their axle is Y), not XY. Never accumulate Euler rotations on them.

# Common-pitch teeth retain the original large/medium/small silhouettes.
# Previously the three unrelated tooth pitches could not physically mesh.
const TEETH := [30, 20, 14]
const MODULE := .0925
const PRESSURE_ANGLE := PI * 25.0 / 180.0
const BACKLASH := .006
const THICKNESS := .24
const KINDS := ["Drive", "Valve", "Governor"]

var phase := 0.0
var parts: Array[Node3D] = []


func configure(imported: Node3D) -> void:
	phase = 0.0
	parts.clear()
	for side in ["L", "R"]:
		var gears: Array[MeshInstance3D] = []
		var old_centres: Array[Vector3] = []
		for i in 3:
			var gear := imported.find_child("*Steam%sGear_%s_%d" % [KINDS[i], side, i], true, false) as MeshInstance3D
			if gear == null:
				push_error("Missing train transmission gear %s/%d" % [side, i])
				return
			gears.append(gear)
			old_centres.append(gear.position)
		for i in 3:
			var gear := gears[i]
			if i > 0:
				gear.position = gears[i - 1].position + (old_centres[i] - old_centres[i - 1]).normalized() * (pitch_radius(i - 1) + pitch_radius(i))
			var material := gear.get_active_material(0)
			gear.mesh = gear_mesh(i, material)
			var offset := 0.0
			if i > 0:
				var previous := gears[i - 1]
				var to_next := previous.basis.inverse() * (gear.position - previous.position)
				var to_previous := gear.basis.inverse() * (previous.position - gear.position)
				var previous_angle := atan2(to_next.z, to_next.x)
				var next_angle := atan2(to_previous.z, to_previous.x)
				var previous_offset: float = previous.get_meta("gear_phase_offset")
				# Tooth centre on one gear meets a tooth space on its neighbour.
				offset = (PI - TEETH[i - 1] * (previous_angle + previous_offset)) / TEETH[i] - next_angle
			for part in [gear,
					imported.find_child("*SteamGearHub_%s_%d" % [side, i], true, false),
					imported.find_child("*SteamGearEnergyRing_%s_%d" % [side, i], true, false)]:
				if part == null:
					continue
				if part != gear:
					part.position += gear.position - old_centres[i]
				part.set_meta("gear_rest_transform", part.transform)
				part.set_meta("gear_phase_offset", offset)
				part.set_meta("mechanism_spin_ratio", ratio(i))
				part.set_meta("gear_teeth", TEETH[i])
				part.set_meta("gear_pitch_radius", pitch_radius(i))
				parts.append(part)
	apply_phase()


func advance(angle: float) -> void:
	# 14 driver turns repeat all three gears (30/20 and 30/14), so this wrap
	# bounds precision without introducing a phase jump in a driven gear.
	phase = fposmod(phase + angle, TAU * 14.0)
	apply_phase()


func apply_phase() -> void:
	for part in parts:
		var rest: Transform3D = part.get_meta("gear_rest_transform")
		var speed_ratio: float = part.get_meta("mechanism_spin_ratio")
		var offset: float = part.get_meta("gear_phase_offset")
		part.transform = Transform3D(rest.basis * Basis(Vector3.UP, phase * speed_ratio + offset), rest.origin)


static func ratio(index: int) -> float:
	return (1.0 if index % 2 == 0 else -1.0) * float(TEETH[0]) / TEETH[index]


static func pitch_radius(index: int) -> float:
	return MODULE * TEETH[index] * .5


static func _involute(angle: float) -> float:
	return tan(angle) - angle


static func profile(index: int) -> PackedVector2Array:
	var count: int = TEETH[index]
	var pitch := pitch_radius(index)
	var base := pitch * cos(PRESSURE_ANGLE)
	var root_radius := pitch - MODULE * 1.25
	var tip := pitch + MODULE
	var half_tooth := PI / (2.0 * count) - BACKLASH / (2.0 * pitch)
	var points := PackedVector2Array()
	for tooth in count:
		var centre := TAU * tooth / count
		var root_half := half_tooth + _involute(PRESSURE_ANGLE)
		points.append(Vector2.from_angle(centre - PI / count) * root_radius)
		points.append(Vector2.from_angle(centre - root_half) * root_radius)
		for step in 7:
			var radius := lerpf(maxf(base, root_radius), tip, float(step) / 6.0)
			var half_angle := half_tooth + _involute(PRESSURE_ANGLE) - _involute(acos(clampf(base / radius, -1.0, 1.0)))
			points.append(Vector2.from_angle(centre - half_angle) * radius)
		for step in range(6, -1, -1):
			var radius := lerpf(maxf(base, root_radius), tip, float(step) / 6.0)
			var half_angle := half_tooth + _involute(PRESSURE_ANGLE) - _involute(acos(clampf(base / radius, -1.0, 1.0)))
			points.append(Vector2.from_angle(centre + half_angle) * radius)
		points.append(Vector2.from_angle(centre + root_half) * root_radius)
	return points


static func gear_mesh(index: int, material: Material) -> ArrayMesh:
	var outline := profile(index)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var front_a := Vector3(a.x, THICKNESS * .5, a.y)
		var front_b := Vector3(b.x, THICKNESS * .5, b.y)
		var back_a := front_a - Vector3.UP * THICKNESS
		var back_b := front_b - Vector3.UP * THICKNESS
		_triangle(surface, Vector3(0, THICKNESS * .5, 0), front_a, front_b)
		_triangle(surface, Vector3(0, -THICKNESS * .5, 0), back_b, back_a)
		_triangle(surface, front_a, back_a, back_b)
		_triangle(surface, front_a, back_b, front_b)
	surface.index()
	return surface.commit()


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot front faces have clockwise winding.
	var normal := (c - a).cross(b - a).normalized()
	for point in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(point)
