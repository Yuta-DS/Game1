extends RefCounted
## Test-only collision proxy of the rendered opaque surfaces, not the train's
## deliberately broad gameplay collision boxes. Glass is not an opaque blocker.

const LAYER := 1 << 30

static func build(train: Node3D, world: Node3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "SightlineTestProbe"
	body.collision_layer = LAYER
	body.collision_mask = 0
	for mesh: MeshInstance3D in train.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		var to_train := train.global_transform.affine_inverse() * mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material is BaseMaterial3D and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
					and material.albedo_color.a < 0.35:
				continue
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] \
				if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var faces := PackedVector3Array()
			if indices.is_empty():
				for vertex in vertices:
					faces.append(to_train * vertex)
			else:
				for index in indices:
					faces.append(to_train * vertices[index])
			if faces.is_empty():
				continue
			var collision := CollisionShape3D.new()
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(faces)
			collision.shape = shape
			collision.set_meta("mesh_path", String(train.get_path_to(mesh)))
			var source := mesh.mesh.surface_get_material(surface)
			collision.set_meta("material", source.resource_name if source != null else "native")
			body.add_child(collision)
	world.add_child(body)
	body.global_transform = train.global_transform
	return body

static func trace(camera: Camera3D, uv: Vector2) -> Dictionary:
	var pixel := uv * camera.get_viewport().get_visible_rect().size
	var origin := camera.project_ray_origin(pixel)
	var query := PhysicsRayQueryParameters3D.create(origin,
		origin + camera.project_ray_normal(pixel) * 60.0, LAYER)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var body := hit.collider as StaticBody3D
	var shape := body.shape_owner_get_owner(body.shape_find_owner(hit.shape)) as CollisionShape3D
	return {"uv": uv, "mesh": shape.get_meta("mesh_path"),
		"material": shape.get_meta("material"), "point": body.to_local(hit.position)}
