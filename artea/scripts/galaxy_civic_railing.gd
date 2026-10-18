extends RefCounted

# The ivory piers, cyan insets and crossed brass rails already used on the
# Mind Spark islands. MultiMeshes keep long Galaxy World boundaries affordable
# in the browser; the separate, simple wall shapes provide reliable collision.

const MAX_BAY_LENGTH := 12.0
const WALL_HEIGHT := 5.55


static func build(parent: Node3D, node_name: String, paths: Array,
		with_collision := true, max_bay_length := MAX_BAY_LENGTH) -> Node3D:
	var railing := Node3D.new()
	railing.name = node_name
	railing.set_meta("barrier_style", "ivory_gold_cyan_civic_railing")
	parent.add_child(railing)
	var ivory: Array[Transform3D] = []
	var brass: Array[Transform3D] = []
	var finials: Array[Transform3D] = []
	var cyan: Array[Transform3D] = []
	var wall := StaticBody3D.new()
	wall.name = "InvisibleEdgeGuard"
	railing.add_child(wall)
	var bay_count := 0
	var wall_count := 0
	for path in paths:
		if path.size() < 2:
			continue
		for segment_index in path.size() - 1:
			var start: Vector3 = path[segment_index]
			var finish: Vector3 = path[segment_index + 1]
			var length := start.distance_to(finish)
			if length < 0.5:
				continue
			var subdivisions := maxi(1, ceili(length / max_bay_length))
			var sideways := Vector3(finish.z - start.z, 0.0,
				start.x - finish.x).normalized()
			if segment_index == 0:
				_add_pier(ivory, finials, cyan, start, sideways)
			for bay_index in subdivisions:
				var first := start.lerp(finish, float(bay_index) / float(subdivisions))
				var last := start.lerp(finish, float(bay_index + 1) / float(subdivisions))
				_add_pier(ivory, finials, cyan, last, sideways)
				_add_between(ivory, first + Vector3.UP * 0.22,
					last + Vector3.UP * 0.22, 0.58, 0.44)
				_add_between(brass, first + Vector3.UP * 1.40,
					last + Vector3.UP * 1.40, 0.13, 0.13)
				_add_between(brass, first + Vector3.UP * 4.56,
					last + Vector3.UP * 4.56, 0.17, 0.17)
				_add_between(brass, first + Vector3.UP * 1.40,
					last + Vector3.UP * 4.56, 0.10, 0.10)
				_add_between(brass, first + Vector3.UP * 4.56,
					last + Vector3.UP * 1.40, 0.10, 0.10)
				bay_count += 1
			if with_collision:
				_add_wall_shape(wall, start, finish)
				wall_count += 1
	_add_multimesh(railing, "IvoryPiersAndCurb", BoxMesh.new(), ivory,
		_make_material(Color("e8e5dc"), 0.83))
	_add_multimesh(railing, "CrossedGoldRails", BoxMesh.new(), brass,
		_make_material(Color("bd9140"), 0.46))
	var finial_mesh := SphereMesh.new()
	finial_mesh.radial_segments = 8
	finial_mesh.rings = 4
	_add_multimesh(railing, "GoldPierFinials", finial_mesh, finials,
		_make_material(Color("d5aa50"), 0.38))
	var inset_mesh := SphereMesh.new()
	inset_mesh.radial_segments = 4
	inset_mesh.rings = 2
	_add_multimesh(railing, "CyanPierInsets", inset_mesh, cyan,
		_make_material(Color("62e6eb"), 0.35, true))
	railing.set_meta("path_count", paths.size())
	railing.set_meta("bay_count", bay_count)
	railing.set_meta("collision_section_count", wall_count)
	return railing


static func _add_pier(ivory: Array[Transform3D], finials: Array[Transform3D],
		cyan: Array[Transform3D], foot: Vector3, sideways: Vector3) -> void:
	_add_box(ivory, foot + Vector3.UP * 0.42, Vector3(1.65, 0.84, 1.85))
	_add_box(ivory, foot + Vector3.UP * 2.64, Vector3(1.08, 4.18, 1.22))
	_add_box(ivory, foot + Vector3.UP * 4.96, Vector3(1.75, 0.48, 1.95))
	finials.append(Transform3D(Basis().scaled(Vector3(0.49, 0.42, 0.49)),
		foot + Vector3.UP * 5.37))
	for face in [-1.0, 1.0]:
		cyan.append(Transform3D(Basis().scaled(Vector3(0.35, 0.74, 0.26)),
			foot + Vector3.UP * 2.9 + sideways * face * 0.62))


static func _add_box(transforms: Array[Transform3D], at: Vector3,
		size: Vector3) -> void:
	transforms.append(Transform3D(Basis().scaled(size), at))


static func _add_between(transforms: Array[Transform3D], first: Vector3,
		last: Vector3, width: float, height: float) -> void:
	var delta := last - first
	if delta.length_squared() < 0.01:
		return
	var forward := delta.normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var up := forward.cross(right).normalized()
	transforms.append(Transform3D(Basis(right * width, up * height,
		forward * delta.length()), first.lerp(last, 0.5)))


static func _add_wall_shape(wall: StaticBody3D, first: Vector3,
		last: Vector3) -> void:
	var delta := last - first
	var forward := delta.normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var up := forward.cross(right).normalized()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.78, WALL_HEIGHT, delta.length() + 0.25)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.transform = Transform3D(Basis(right, up, forward),
		first.lerp(last, 0.5) + Vector3.UP * (WALL_HEIGHT * 0.5))
	wall.add_child(collision)


static func _add_multimesh(parent: Node3D, node_name: String, mesh: Mesh,
		transforms: Array[Transform3D], material: Material) -> void:
	if transforms.is_empty():
		return
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for index in transforms.size():
		batch.set_instance_transform(index, transforms[index])
	var visual := MultiMeshInstance3D.new()
	visual.name = node_name
	visual.multimesh = batch
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)


static func _make_material(color: Color, roughness: float,
		glowing := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if glowing:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.55
	return material
