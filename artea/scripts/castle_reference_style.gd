# Shared finish for the complete castle route. Colours sampled from the original
# building_castle_red atlas, weighted by triangle area (see audit script).
# Decoration is deliberately shallow and visual-only; existing bodies own travel.
extends RefCounted

const WALL := Color("818c91")
const BLOCK := Color("9198a2")
const TRIM := Color("586065")
const FLOOR := Color("9198a2")
const RECESS := Color("42494b")
const ROOF := Color("ef443d")
const ROOTS := ["CastleStairs/CastleStair", "CastleEntrance/CastleEntrance",
	"CastleArchitecture", "Art_Gallery/GalleryDoorRig"]
const LEGACY_STONE := ["8399a6", "9aabb2", "c7d2d2", "687f91", "91a8b5",
	"c4cfc2", "5c7580", "8ca5b1", "d3d9cc", "758aa8", "b7c7cc", "b4c5cf"]
static var _materials: Dictionary = {}


static func material(role: String = "wall") -> StandardMaterial3D:
	if _materials.has(role):
		return _materials[role]
	var result := StandardMaterial3D.new()
	result.resource_name = "Reference castle / " + role
	result.albedo_color = {"wall": WALL, "block": BLOCK, "trim": TRIM,
		"floor": FLOOR, "recess": RECESS, "roof": ROOF}.get(role, WALL)
	result.roughness = 0.92
	result.set_meta("reference_castle_role", role)
	result.set_meta("render_family", "red_village_hexagons_castle")
	_materials[role] = result
	return result


static func apply_route(hub: Node) -> void:
	for path: String in ROOTS:
		var part := hub.get_node_or_null(path)
		if part:
			_restyle(part)
	# No positions, collision shapes, masks or movement parameters are changed.
	hub.set_meta("castle_style_reference", "original_right_tower_atlas")


static func _restyle(node: Node) -> void:
	var label := String(node.name).to_lower()
	# Botanical GLBs contain pale flower petals as well as stone-like colours.
	# Never recolour them, fire, water, or the original textured reference model.
	if _contains(label, ["gardenflower", "gardenfern", "liveflame", "livingwater",
		"combinedstoneurn", "lowpolystairgrowth", "courtyardfire", "castlestairtorch"]):
		return
	if node is MeshInstance3D:
		var part := node as MeshInstance3D
		if part.mesh != null:
			for index in part.mesh.get_surface_count():
				var source := part.get_active_material(index) as StandardMaterial3D
				if source == null or source.albedo_texture != null or source.vertex_color_use_as_albedo \
						or source.has_meta("reference_castle_role"):
					continue
				if source.albedo_color.to_html(false) not in LEGACY_STONE:
					continue
				var role := "wall"
				if _contains(label, ["tread", "nosing", "landing", "deck", "apron", "paving"]):
					role = "floor"
				elif _contains(label, ["coping", "course", "buttress", "capital", "collar",
					"socle", "moulding", "frame", "keystone", "plinth"]):
					role = "trim"
				elif source.resource_name == "Pale carved limestone":
					role = "trim"
				elif source.resource_name == "Recessed stone joints":
					role = "recess"
				if part.material_override != null:
					part.material_override = material(role)
				else:
					part.set_surface_override_material(index, material(role))
	for child in node.get_children():
		_restyle(child)


static func _contains(label: String, words: Array) -> bool:
	for word: String in words:
		if word in label:
			return true
	return false


static func box(parent: Node3D, label: String, size: Vector3, at: Vector3,
		role: String = "block") -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	var result := MeshInstance3D.new()
	result.name = label
	result.mesh = shape
	result.material_override = material(role)
	parent.add_child(result, true)
	result.position = at
	result.set_meta("visual_only", true)
	return result


# The original tower uses isolated three-to-five stone patches, not all-over
# brick wallpaper. Blocks project only 35 mm and never enter the walking lane.
static func cluster(parent: Node3D, at: Vector3, normal: Vector3,
		size: float = 1.0) -> Node3D:
	var patch := Node3D.new()
	patch.name = "ReferenceStonePatch"
	parent.add_child(patch, true)
	patch.position = at
	patch.basis = Basis(Vector3(normal.z, 0, -normal.x).normalized(), Vector3.UP, normal.normalized())
	patch.set_meta("visual_only", true)
	patch.set_meta("preserve_castle_finish", true)
	patch.set_meta("reference_detail", "sparse_raised_masonry")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for data: Vector3 in [Vector3(-0.19, 0.22, 0.54), Vector3(0.18, 0, 0.60),
		Vector3(-0.28, -0.22, 0.42), Vector3(0.24, -0.22, 0.36)]:
		var stone := BoxMesh.new()
		stone.size = Vector3(data.z * size, 0.19 * size, 0.07)
		surface.append_from(stone, 0, Transform3D(Basis.IDENTITY, Vector3(data.x * size, data.y * size, 0)))
	var mesh := MeshInstance3D.new()
	mesh.name = "FourDressedStones"
	mesh.mesh = surface.commit()
	mesh.material_override = material("block")
	patch.add_child(mesh)
	return patch


# Rounded recess and a closed stone frame, in the same proportions as the
# imported tower. The dark inset stays backed by the solid tower wall.
static func window(parent: Node3D, at: Vector3, normal: Vector3,
		size: float = 1.0) -> Node3D:
	var frame := Node3D.new()
	frame.name = "ReferenceRoundArchWindow"
	parent.add_child(frame, true)
	frame.position = at
	frame.basis = Basis(Vector3(normal.z, 0, -normal.x).normalized(), Vector3.UP, normal.normalized())
	frame.scale = Vector3.ONE * size
	frame.set_meta("visual_only", true)
	frame.set_meta("preserve_castle_finish", true)
	frame.set_meta("reference_detail", "rounded_recessed_arch")
	const R := 0.43
	const SHOULDER := 0.34
	const BOTTOM := -0.92
	const BORDER := 0.16
	box(frame, "DarkRecess", Vector3(R * 2, SHOULDER - BOTTOM, 0.028),
		Vector3(0, (SHOULDER + BOTTOM) * 0.5, 0.02), "recess")
	for side: float in [-1, 1]:
		box(frame, "DressedArchJamb", Vector3(BORDER, SHOULDER - BOTTOM, 0.16),
			Vector3(side * (R + BORDER * 0.5), (SHOULDER + BOTTOM) * 0.5, 0.035), "trim")
	box(frame, "DressedArchSill", Vector3(2 * (R + BORDER), 0.18, 0.21),
		Vector3(0, BOTTOM - 0.065, 0.045), "trim")
	var arch := SurfaceTool.new()
	arch.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inset := SurfaceTool.new()
	inset.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 20:
		var a := PI * float(index) / 20
		var b := PI * float(index + 1) / 20
		var ia := Vector3(cos(a) * R, SHOULDER + sin(a) * R, 0.12)
		var ib := Vector3(cos(b) * R, SHOULDER + sin(b) * R, 0.12)
		var oa := Vector3(cos(a) * (R + BORDER), SHOULDER + sin(a) * (R + BORDER), 0.12)
		var ob := Vector3(cos(b) * (R + BORDER), SHOULDER + sin(b) * (R + BORDER), 0.12)
		_quad(arch, ia, ib, ob, oa)
		_quad(arch, oa, ob, ob - Vector3(0, 0, 0.16), oa - Vector3(0, 0, 0.16))
		_quad(arch, ib, ia, ia - Vector3(0, 0, 0.16), ib - Vector3(0, 0, 0.16))
		for p: Vector3 in [Vector3(0, SHOULDER, 0.036), Vector3(ib.x, ib.y, 0.036), Vector3(ia.x, ia.y, 0.036)]:
			inset.add_vertex(p)
	for data: Array in [[arch, "RoundedStoneArch", "trim"], [inset, "RoundedDarkRecess", "recess"]]:
		var surface: SurfaceTool = data[0]
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name = data[1]
		mesh.mesh = surface.commit()
		mesh.material_override = material(data[2])
		frame.add_child(mesh)
	return frame


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p: Vector3 in [a, b, c, a, c, d]:
		surface.add_vertex(p)
