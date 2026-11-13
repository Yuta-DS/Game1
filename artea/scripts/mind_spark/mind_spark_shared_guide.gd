class_name MindSparkSharedGuide
extends Node3D

enum GuideKind { MAYOR_MILO, MOTHER_GUARDIAN }

@export var guide_kind := GuideKind.MAYOR_MILO
@export var display_name := "Mayor Milo"
@export_multiline var default_line := "Let us follow one clear light."

# Primitives recorded while a figure is sculpted, merged per material after.
var _parts: Array[Part] = []
var _materials: Dictionary = {}


class Part:
	var mesh: PrimitiveMesh
	var material: Material
	var position := Vector3.ZERO
	var scale := Vector3.ONE
	var basis := Basis.IDENTITY

	func turn(euler: Vector3) -> Part:
		basis = Basis.from_euler(euler) * Basis.from_scale(scale)
		return self

	# Points the part's own up axis along `direction`.
	func aim(direction: Vector3) -> Part:
		basis = Basis(Quaternion(Vector3.UP, direction.normalized())) * Basis.from_scale(scale)
		return self


func _ready() -> void:
	_build_visual()
	set_meta("non_combat", true)
	set_meta("solves_puzzles", false)


func set_dialogue_line(line: String) -> void:
	$DialogueLabel.text = "%s: %s" % [display_name, line]


func move_to_guide_point(point: Marker3D) -> void:
	if point != null:
		global_position = point.global_position


func _build_visual() -> void:
	if guide_kind == GuideKind.MAYOR_MILO:
		_build_mayor()
	else:
		_build_guardian()
	# Sculpted from many small primitives, but merged into one mesh per
	# material so each guide costs only a handful of draw calls on the web.
	var tools := {}
	for part in _parts:
		if not tools.has(part.material):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[part.material] = tool
		tools[part.material].append_from(part.mesh, 0, Transform3D(part.basis, part.position))
	for material in tools:
		var instance := MeshInstance3D.new()
		instance.name = "GuidePart"
		instance.mesh = tools[material].commit()
		instance.material_override = material
		$Visuals.add_child(instance)
	_parts.clear()
	$DialogueLabel.text = "%s: %s" % [display_name, default_line]


func _build_mayor() -> void:
	var coat := _material(Color("24395f"), 0.72)
	var skin := _material(Color("e8c7a8"), 0.92)
	var silver := _material(Color("d9dce6"), 0.72)
	var gold := _material(Color("e4bd5b"), 0.38)
	var dark := _material(Color("3a2a22"), 0.8)
	_head(skin, silver, dark)
	# Spectacles, moustache and a neat beard.
	for side in [-1.0, 1.0]:
		_ring(Vector3(side * 0.46, 7.8, 1.3), 0.22, 0.28, gold).turn(Vector3(PI / 2, 0, 0))
		_ellipsoid(Vector3(side * 0.33, 7.25, 1.28), Vector3(0.36, 0.13, 0.15), silver).turn(Vector3(0, 0, side * 0.25))
	_box(Vector3(0, 7.82, 1.36), Vector3(0.3, 0.05, 0.05), gold)
	_ellipsoid(Vector3(0, 6.85, 1.0), Vector3(0.85, 0.75, 0.55), silver)
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(side * 0.62, 0.28, 0.35), Vector3(0.55, 0.3, 0.85), dark)
	# Long frock coat over a burgundy waistcoat, with gold trim and buttons.
	_tube(Vector3(0, 2.55, 0), 1.22, 1.78, 4.7, coat)
	_ring(Vector3(0, 0.3, 0), 1.62, 1.82, gold)
	_tube(Vector3(0, 5.55, 0), 1.12, 1.28, 1.7, coat)
	_box(Vector3(0, 4.5, 1.32), Vector3(1.25, 2.6, 0.2), _material(Color("8a2f3a"), 0.7))
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 0.62, 5.6, 1.18), Vector3(0.36, 1.7, 0.16), coat).turn(Vector3(0, 0, side * 0.32))
	for i in 4:
		_ellipsoid(Vector3(0, 5.3 - i * 0.62, 1.45), Vector3.ONE * 0.13, gold)
	_ring(Vector3(0, 6.62, 0), 0.5, 0.78, _material(Color("efe6cf"), 0.85))
	_tube(Vector3(0, 6.85, 0), 0.45, 0.45, 0.5, skin)
	# Chain of office and its medallion.
	_ring(Vector3(0, 6.15, 0.25), 0.95, 1.08, gold).turn(Vector3(0.45, 0, 0))
	_tube(Vector3(0, 5.35, 1.48), 0.42, 0.42, 0.12, gold).turn(Vector3(PI / 2, 0, 0))
	_ellipsoid(Vector3(0, 5.35, 1.56), Vector3.ONE * 0.16, _material(Color("c23b4b"), 0.3, 0.4))
	_arms(coat, skin, gold, Vector3(1.8, 4.3, 0.35), Vector3(-1.25, 3.4, 0.9), false)
	# Top hat with a gold band, and the professor's cane.
	_tube(Vector3(0, 9.0, -0.1), 1.05, 1.05, 0.12, dark)
	_tube(Vector3(0, 9.65, -0.1), 0.78, 0.82, 1.3, dark)
	_tube(Vector3(0, 9.18, -0.1), 0.84, 0.84, 0.22, gold)
	_tube(Vector3(1.85, 2.2, 0.35), 0.11, 0.13, 4.4, _material(Color("6b4a2f"), 0.6))
	_ellipsoid(Vector3(1.85, 4.45, 0.35), Vector3.ONE * 0.24, gold)


func _build_guardian() -> void:
	var ivory := _material(Color("eef0dc"), 0.78)
	var mint := _material(Color("bcd9c6"), 0.78)
	var skin := _material(Color("eccfb4"), 0.9)
	var hair := _material(Color("f1dfae"), 0.6)
	var gold := _material(Color("e9bd55"), 0.38, 1.25)
	var light := _material(Color("fff1c4"), 0.2, 2.2)
	_head(skin, hair, _material(Color("4b3b46"), 0.8))
	# Long flowing hair down the back.
	_ellipsoid(Vector3(0, 6.9, -0.75), Vector3(1.3, 2.3, 0.65), hair)
	# Gown with soft folds, a gold girdle and a mint overskirt.
	_tube(Vector3(0, 2.7, 0), 0.92, 2.05, 5.4, ivory)
	for i in 10:
		var angle := TAU * i / 10.0
		# Each fold leans in with the gown's taper, lying along its surface.
		_tube(Vector3(sin(angle) * 1.5, 2.4, cos(angle) * 1.5), 0.07, 0.24, 4.6, mint if i % 2 else ivory) \
			.turn(Vector3(-cos(angle) * 0.21, 0, sin(angle) * 0.21))
	_tube(Vector3(0, 4.55, 0), 1.08, 1.55, 1.2, mint)
	_tube(Vector3(0, 5.85, 0), 0.86, 0.98, 1.7, ivory)
	_ring(Vector3(0, 5.05, 0), 0.92, 1.08, gold)
	_ring(Vector3(0, 0.15, 0), 1.9, 2.1, gold)
	_tube(Vector3(0, 6.85, 0), 0.42, 0.42, 0.5, skin)
	_ring(Vector3(0, 6.68, 0), 0.48, 0.66, gold)
	# Bell sleeves reaching forward to cradle a small light.
	_arms(ivory, skin, gold, Vector3(0.55, 4.9, 1.45), Vector3(-0.55, 4.9, 1.45), true)
	_ellipsoid(Vector3(0, 5.05, 1.75), Vector3.ONE * 0.42, light)
	# Double halo.
	_ring(Vector3(0, 9.45, -0.15), 1.5, 1.72, gold).turn(Vector3(-0.2, 0, 0))
	_ring(Vector3(0, 9.45, -0.15), 1.15, 1.22, light).turn(Vector3(-0.2, 0, 0))
	# Layered feathered wings: each wing's arm arcs up and out from the
	# shoulders, and three rows of feathers hang from it, the long primaries
	# behind and below the short coverts.
	var rows := [
		[_material(Color("41dbe8"), 0.34, 1.0), 6, 1.2],
		[_material(Color("8961d0"), 0.34, 0.8), 7, 2.0],
		[_material(Color("57a978"), 0.58, 0.55), 8, 2.9],
	]
	for side in [-1.0, 1.0]:
		for row in rows.size():
			var count: int = rows[row][1]
			for i in count:
				var t := float(i) / (count - 1)
				var root := Vector3(side * (0.6 + t * (2.6 + row * 0.3)), 6.4 + sin(t * 2.4) * 1.5 - row * 0.35,
					-0.95 - row * 0.1)
				var hang := Vector3(side * (0.2 + 0.7 * t), -1.0, -0.15).normalized()
				var length: float = rows[row][2] * (0.7 + 0.5 * t)
				_ellipsoid(root + hang * length * 0.5, Vector3(0.26 + row * 0.03, length * 0.5, 0.07), rows[row][0]) \
					.aim(hang)


# Shared by both guides: head, ears, eyes, brows, nose, mouth and hair cap.
func _head(skin: Material, hair: Material, dark: Material) -> void:
	_ellipsoid(Vector3(0, 7.65, 0), Vector3(1.4, 1.5, 1.35), skin)
	var white := _material(Color("fbf8f0"), 0.4)
	for side in [-1.0, 1.0]:
		_ellipsoid(Vector3(side * 1.36, 7.65, 0), Vector3(0.28, 0.42, 0.22), skin)
		_ellipsoid(Vector3(side * 0.46, 7.8, 1.18), Vector3(0.24, 0.2, 0.12), white)
		_ellipsoid(Vector3(side * 0.46, 7.8, 1.27), Vector3.ONE * 0.12, dark)
		_box(Vector3(side * 0.47, 8.12, 1.2), Vector3(0.5, 0.1, 0.12), hair).turn(Vector3(0, 0, side * -0.12))
	_ellipsoid(Vector3(0, 7.5, 1.36), Vector3(0.2, 0.26, 0.2), skin)
	_ellipsoid(Vector3(0, 7.08, 1.2), Vector3(0.42, 0.1, 0.1), _material(Color("b4706a"), 0.6))
	_ellipsoid(Vector3(0, 8.3, -0.2), Vector3(1.5, 0.95, 1.45), hair)


# Sleeves from each shoulder to its hand, with a cuff and the hand itself.
func _arms(sleeve: Material, skin: Material, cuff: Material, right_hand: Vector3, left_hand: Vector3, bell: bool) -> void:
	for pair in [[1.0, right_hand], [-1.0, left_hand]]:
		var shoulder := Vector3(pair[0] * 1.2, 6.25, 0)
		var hand: Vector3 = pair[1]
		var down := hand - shoulder
		_ellipsoid(shoulder, Vector3.ONE * 0.62, sleeve)
		_tube((shoulder + hand) * 0.5, 0.36, 0.62 if bell else 0.34, down.length(), sleeve).aim(-down)
		_ring(hand - down.normalized() * 0.25, 0.55 if bell else 0.3, 0.68 if bell else 0.42, cuff).aim(down)
		_ellipsoid(hand, Vector3.ONE * 0.3, skin)


func _material(color: Color, roughness: float, emission_energy := 0.0) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [color.to_html(), roughness, emission_energy]
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		if emission_energy > 0.0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = emission_energy
		_materials[key] = material
	return _materials[key]


func _part(mesh: PrimitiveMesh, at: Vector3, scale_value: Vector3, material: Material) -> Part:
	var part := Part.new()
	part.mesh = mesh
	part.material = material
	part.position = at
	part.scale = scale_value
	part.basis = Basis.from_scale(scale_value)
	_parts.append(part)
	return part


func _ellipsoid(at: Vector3, scale_value: Vector3, material: Material) -> Part:
	# Unit radius, so `scale_value` gives the ellipsoid's radii.
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _part(mesh, at, scale_value, material)


func _tube(at: Vector3, top: float, bottom: float, height: float, material: Material) -> Part:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	return _part(mesh, at, Vector3.ONE, material)


func _ring(at: Vector3, inner: float, outer: float, material: Material) -> Part:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 6
	return _part(mesh, at, Vector3.ONE, material)


func _box(at: Vector3, size: Vector3, material: Material) -> Part:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(mesh, at, Vector3.ONE, material)
