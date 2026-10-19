extends RefCounted
## Whole-piece measurements for refitting the cab without cutting its mesh.

const DASHBOARD_DROP := 1.25
const COVER_DROP := 0.90
const BOILER_SCALE := 0.65
const BOILER_OFFSET_Y := -0.268
const Windscreen := preload("res://scripts/train_front_windscreen.gd")
const DriverSeat := preload("res://scripts/train_driver_seat.gd")
const TankViews := preload("res://scripts/train_tank_views.gd")

static func fitting_transform(box: AABB, material_name: String) -> Transform3D:
	var low := box.position
	var high := box.end
	if material_name.begins_with("cover_"):
		return Transform3D(Basis.IDENTITY, Vector3.DOWN * COVER_DROP)
	# The separate ivory segments all clad the same front windscreen arch.
	# Keep every segment with its gold frame, including its lower shoulders.
	if (material_name.contains("warm_ivory") or material_name.contains("crown_accentgold") \
			or material_name.contains("cab_clear")) and low.z >= -19.85 and high.z <= -19.15:
		return Transform3D.IDENTITY
	if low.z >= -19.45 and high.z <= -16.0 and low.y >= 2.0 and high.y <= 5.5 \
			and low.x >= -3.5 and high.x <= 3.5:
		return Transform3D(Basis.IDENTITY, Vector3.DOWN * DASHBOARD_DROP)
	if material_name.contains("cab_clear") or (material_name.contains("warm_ivory") and low.y > 7.2):
		return Transform3D.IDENTITY
	# Fit the small engraved arc to the new circular boiler surface as one
	# consistent ring, instead of leaving its tiny segments above the eye line.
	if absf(box.get_center().z + 21.76) < 0.03 and box.size.z < 0.04 \
			and maxf(box.size.x, box.size.y) < 0.10:
		return Transform3D(Basis.from_scale(Vector3(0.42, 0.42, 1)), Vector3(0, 0.8176, 0))
	var front_limit := -27.15 if material_name.contains("root_bronze_band") else -26.30
	if low.z >= front_limit and high.z <= -19.15 and low.y >= 2.0 and high.y <= 8.2 \
			and low.x >= -5.5 and high.x <= 5.5:
		# Keep the boiler round and seated just above the deck, not squashed flat.
		var fit := Transform3D(Basis.from_scale(Vector3(BOILER_SCALE, BOILER_SCALE, 1)),
			Vector3(0, BOILER_OFFSET_Y, 0))
		# Shorten the chimney above its base, retaining the connected cap/rings.
		if low.z >= -24.5 and high.z <= -22.2 and low.y >= 5.6 \
				and low.x >= -1.1 and high.x <= 1.1:
			fit.basis = Basis.from_scale(Vector3(BOILER_SCALE, 0.35, 1))
			fit.origin.y = 1.532
		return fit
	return Transform3D.IDENTITY

static func refit_imported(train: Node3D, detailed: Node3D) -> void:
	var tank_views := TankViews.new()
	tank_views.name = "TrainTankViews"
	train.add_child(tank_views)
	var fitted_pieces := 0
	var replaced_window_pieces := 0
	var replaced_seat_pieces := 0
	for instance: MeshInstance3D in detailed.find_children("*", "MeshInstance3D", true, false):
		if instance.mesh == null:
			continue
		var to_train := train.global_transform.affine_inverse() * instance.global_transform
		if (to_train * instance.get_aabb()).position.z > -16.0:
			continue
		# Named mechanism nodes retain their local meshes and animation pivots.
		# This runs before the railway records their rest transforms.
		if String(instance.name) != "CrownLineRuntimeTexturedSurface":
			var material := instance.mesh.surface_get_material(0)
			var name := material.resource_name.to_lower() if material != null else ""
			var fit := fitting_transform(to_train * instance.get_aabb(), name)
			if fit != Transform3D.IDENTITY:
				var parent_to_train := train.global_transform.affine_inverse() \
					* (instance.get_parent() as Node3D).global_transform
				if fit.basis != Basis.IDENTITY:
					tank_views.add_moving_part(instance, parent_to_train.affine_inverse() * fit * parent_to_train)
				else:
					instance.transform = parent_to_train.affine_inverse() * fit * to_train
				fitted_pieces += 1
			continue
		var rebuilt := ArrayMesh.new()
		var overrides: Array[Material] = []
		for surface in instance.mesh.get_surface_count():
			var material := instance.mesh.surface_get_material(surface)
			var material_name := material.resource_name.to_lower() if material != null else ""
			var override := instance.get_surface_override_material(surface)
			if material_name.contains("cab_clear_cyan_glass"):
				var glass := (override if override != null else material).duplicate() as StandardMaterial3D
				glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glass.albedo_color = Color(0.7, 0.95, 1.0, 0.06)
				glass.emission_enabled = false
				override = glass
			var arrays := instance.mesh.surface_get_arrays(surface)
			var original_arrays := arrays.duplicate(true)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] \
				if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
			var retained_indices := PackedInt32Array()
			var tank_indices := PackedInt32Array()
			for group in components(arrays, to_train):
				if DriverSeat.is_legacy_component(group.bounds, material_name):
					replaced_seat_pieces += 1
					continue
				if Windscreen.is_legacy_component(group.bounds, material_name):
					replaced_window_pieces += 1
					continue
				var fit := fitting_transform(group.bounds, material_name)
				if fit.basis != Basis.IDENTITY:
					tank_indices.append_array(group.indices)
				else:
					retained_indices.append_array(group.indices)
				if fit == Transform3D.IDENTITY:
					continue
				var local_fit := to_train.affine_inverse() * fit * to_train
				var normal_basis := local_fit.basis.inverse().transposed()
				var visited := {}
				for index: int in group.indices:
					if visited.has(index):
						continue
					visited[index] = true
					vertices[index] = local_fit * vertices[index]
					if normals.size() == vertices.size():
						normals[index] = (normal_basis * normals[index]).normalized()
					if tangents.size() == vertices.size() * 4:
						var tangent := (local_fit.basis * Vector3(tangents[index * 4],
							tangents[index * 4 + 1], tangents[index * 4 + 2])).normalized()
						for axis in 3:
							tangents[index * 4 + axis] = tangent[axis]
				fitted_pieces += 1
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			if not tangents.is_empty():
				arrays[Mesh.ARRAY_TANGENT] = tangents
			if not tank_indices.is_empty():
				tank_views.add_static_surface(original_arrays, arrays, tank_indices, to_train,
					override if override != null else material)
			if retained_indices.is_empty():
				continue
			arrays[Mesh.ARRAY_INDEX] = retained_indices
			rebuilt.add_surface_from_arrays(instance.mesh.surface_get_primitive_type(surface), arrays)
			var rebuilt_surface := rebuilt.get_surface_count() - 1
			rebuilt.surface_set_material(rebuilt_surface, material)
			rebuilt.surface_set_name(rebuilt_surface, instance.mesh.surface_get_name(surface))
			overrides.append(override)
		instance.mesh = rebuilt
		for surface in overrides.size():
			instance.set_surface_override_material(surface, overrides[surface])
	detailed.set_meta("driver_sightline_refitted_pieces", fitted_pieces)
	detailed.set_meta("driver_sightline_boiler_radial_scale", BOILER_SCALE)
	detailed.set_meta("driver_sightline_dashboard_drop_m", DASHBOARD_DROP)
	detailed.set_meta("replaced_front_window_pieces", replaced_window_pieces)
	detailed.set_meta("replaced_driver_seat_pieces", replaced_seat_pieces)

static func refit_native(train: Node3D) -> void:
	train.get_node("GodotEngineCover").position.y -= COVER_DROP
	var fit := Transform3D(Basis.from_scale(Vector3(BOILER_SCALE, BOILER_SCALE, 1)),
		Vector3(0, BOILER_OFFSET_Y, 0))
	for instance: MeshInstance3D in train.find_children("EngineTank*", "MeshInstance3D", true, false):
		var parent_to_train := train.global_transform.affine_inverse() \
			* (instance.get_parent() as Node3D).global_transform
		var tank_views := train.get_node("TrainTankViews")
		tank_views.add_native_part(instance, parent_to_train.affine_inverse() * fit * parent_to_train * instance.transform)
	Windscreen.build(train)
	preload("res://scripts/train_light_frame_clearance.gd").fit(train)
	# Build after the transmission's pitch centres have been configured. The
	# existing driver-view selector owns visibility; exterior gears stay exposed.
	var tank_views := train.get_node("TrainTankViews")
	tank_views.fps_gear_covers = preload("res://scripts/train_fps_gear_covers.gd").build(train)

static func components(arrays: Array, to_train: Transform3D) -> Array[Dictionary]:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
		if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in vertices.size():
			indices.append(i)
	var parents: Array[int] = []
	var owners := {}
	for i in range(0, indices.size(), 3):
		var triangle := i / 3
		parents.append(triangle)
		for corner in 3:
			var key := vertices[indices[i + corner]].snapped(Vector3.ONE * 0.0001)
			if owners.has(key):
				parents[_root(parents, triangle)] = _root(parents, owners[key])
			else:
				owners[key] = triangle
	var groups := {}
	for i in range(0, indices.size(), 3):
		var root := _root(parents, i / 3)
		if not groups.has(root):
			groups[root] = {"indices": PackedInt32Array(),
				"bounds": AABB(to_train * vertices[indices[i]], Vector3.ZERO)}
		var group: Dictionary = groups[root]
		for corner in 3:
			var index := indices[i + corner]
			group.indices.append(index)
			group.bounds = (group.bounds as AABB).expand(to_train * vertices[index])
	var result: Array[Dictionary] = []
	for group: Dictionary in groups.values():
		result.append(group)
	return result

static func _root(parents: Array[int], index: int) -> int:
	while parents[index] != index:
		parents[index] = parents[parents[index]]
		index = parents[index]
	return index
