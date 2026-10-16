# Small herb plots inspired by medieval enclosed gardens, not formal topiary.
# One visual mesh per bed; the existing stone planter remains the only collider.
extends RefCounted

const Bot := preload("res://scripts/castle_royal_botanicals.gd")
const SAGE := Color("7d8c69")
const RUE := Color("567d68")
const STEM := Color("556144")
const WILLOW := Color("766044")
const PETAL := Color("e8dfc6")
const POLLEN := Color("b99942")

static func build(bed: Node3D, soil_y: float = 0.32) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two low woven hazel dividers organise three useful herb patches. Everything
	# remains below the existing bed's walking envelope, including the end stakes.
	for x: float in [-0.39, 0.39]:
		for z: float in [-0.48, -0.24, 0, 0.24, 0.48]:
			rod(surface, Vector3(x, soil_y, z), Vector3(x, soil_y + 0.18, z), 0.012, WILLOW)
		for row in 3:
			for segment in 16:
				var a := float(segment) / 16.0
				var b := float(segment + 1) / 16.0
				rod(surface, Vector3(x + sin(a * TAU * 2 + row * PI) * 0.02, soil_y + 0.045 + row * 0.044, lerpf(-0.49, 0.49, a)),
					Vector3(x + sin(b * TAU * 2 + row * PI) * 0.02, soil_y + 0.045 + row * 0.044, lerpf(-0.49, 0.49, b)), 0.008, WILLOW.lightened(0.05))
	for plot in 3:
		for row in 3:
			for column in 2:
				var p := Vector3((plot - 1) * 0.75 + (column - 0.5) * 0.24,
					soil_y + 0.012, (row - 1) * 0.30 + sin(float(plot + row)) * 0.018)
				var variant := row * 2 + column
				if plot == 0:
					_sage(surface, p, variant)
				elif plot == 1:
					_rue(surface, p, variant)
				else:
					_chamomile(surface, p, variant)
	# Soft moss creeps along a few stone/soil joins, not down into the path.
	for index in 15:
		var p := Vector3(-1.03 + index * 0.14, soil_y + 0.012, 0.53)
		leaf(surface, p, Vector3(0.075, 0.012, 0.012), 0.032, Bot.MOSS)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "MedievalHerbPlanting"
	mesh.mesh = surface.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.95
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.set_meta("visual_only", true)
	mesh.set_meta("species", ["sage", "rue", "chamomile"])
	mesh.set_meta("layout", "three_herb_plots_low_woven_dividers")
	bed.add_child(mesh)

static func _sage(s: SurfaceTool, p: Vector3, variant: int) -> void:
	for branch in 4:
		var angle := branch * TAU / 4.0 + variant * 0.73
		var radial := Vector3(cos(angle), 0, sin(angle))
		var tip := p + Vector3.UP * (0.26 + 0.025 * (variant % 3)) + radial * 0.06
		rod(s, p, tip, 0.006, STEM)
		for level in 3:
			var at := p.lerp(tip, 0.25 + level * 0.25)
			for side: float in [-1, 1]:
				var direction := radial.rotated(Vector3.UP, side * 1.15) * (0.12 - level * 0.014) + Vector3.UP * 0.065
				leaf(s, at, direction, 0.038, SAGE.lightened(branch * 0.025), true)

static func _rue(s: SurfaceTool, p: Vector3, variant: int) -> void:
	for branch in 4:
		var angle := branch * TAU / 4.0 + variant
		var radial := Vector3(cos(angle), 0, sin(angle))
		var tip := p + radial * 0.10 + Vector3.UP * (0.31 + 0.025 * (variant % 2))
		rod(s, p, tip, 0.004, STEM)
		for level in 2:
			var at := p.lerp(tip, 0.38 + level * 0.36)
			for side: float in [-1, 1]:
				var direction := radial.rotated(Vector3.UP, side) * 0.085 + Vector3.UP * 0.025
				for lobe in 3:
					leaf(s, at + direction * float(lobe) * 0.27,
						direction.rotated(Vector3.UP, (lobe - 1) * 0.7) * 0.58, 0.019, RUE)

static func _chamomile(s: SurfaceTool, p: Vector3, variant: int) -> void:
	for branch in 3:
		var angle := branch * TAU / 3.0 + variant * 0.81
		var radial := Vector3(cos(angle), 0, sin(angle))
		var tip := p + radial * 0.085 + Vector3.UP * (0.22 + 0.036 * ((variant + branch) % 3))
		rod(s, p, tip, 0.0035, STEM)
		for level in 3:
			var at := p.lerp(tip, 0.24 + level * 0.19)
			for side: float in [-1, 1]:
				leaf(s, at, radial.rotated(Vector3.UP, side) * 0.085 + Vector3.UP * 0.027, 0.008, RUE)
		for petal in 11:
			var a := TAU * float(petal) / 11.0
			leaf(s, tip, Vector3(cos(a) * 0.058, -0.010, sin(a) * 0.058), 0.010, PETAL, false, 2)
		rod(s, tip, tip + Vector3.UP * 0.015, 0.018, POLLEN, 10)

# Folded triangulated blades with a restrained midrib (not flat flower icons).
static func leaf(s: SurfaceTool, start: Vector3, direction: Vector3, width: float,
		colour: Color, veined: bool = false, subdivisions: int = 4) -> void:
	var cross := direction.cross(Vector3.UP).normalized()
	for row in subdivisions:
		var ta := float(row) / subdivisions
		var tb := float(row + 1) / subdivisions
		var a := start + direction * ta
		var b := start + direction * tb
		var wa := sin(ta * PI) * width
		var wb := sin(tb * PI) * width
		var ca := a + Vector3.UP * sin(ta * PI) * 0.012
		var cb := b + Vector3.UP * sin(tb * PI) * 0.012
		Bot._tri(s, a-cross*wa, b-cross*wb, cb, colour)
		Bot._tri(s, a-cross*wa, cb, ca, colour)
		Bot._tri(s, ca, cb, b+cross*wb, colour.lightened(0.035))
		Bot._tri(s, ca, b+cross*wb, a+cross*wa, colour.lightened(0.035))
		if veined:
			Bot._tri(s, ca-cross*0.0009, cb-cross*0.0009, cb+cross*0.0009, colour.lightened(0.12))

static func rod(s: SurfaceTool, a: Vector3, b: Vector3, radius: float,
		colour: Color, sides: int = 5) -> void:
	var along := (b-a).normalized()
	var reference := Vector3.RIGHT if absf(along.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := along.cross(reference).normalized() * radius
	var y := along.cross(x).normalized() * radius
	for index in sides:
		var t := TAU * float(index) / sides
		var u := TAU * float(index+1) / sides
		var p := x*cos(t)+y*sin(t)
		var q := x*cos(u)+y*sin(u)
		Bot._tri(s, a+p, b+p, b+q, colour)
		Bot._tri(s, a+p, b+q, a+q, colour)
		Bot._tri(s, b, b+p, b+q, colour)
