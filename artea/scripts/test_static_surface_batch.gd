extends SceneTree

const Batcher = preload("res://scripts/static_surface_batch.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var architecture := Node3D.new()
	root.add_child(architecture)
	var originals: Array[MeshInstance3D] = []
	for i in 8:
		var item := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1 + i * 0.1, 1, 2)
		item.mesh = box
		item.position = Vector3(i * 3, 0, 0)
		item.rotation.y = i * 0.1
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.RED if i < 4 else Color.BLUE
		item.material_override = material
		architecture.add_child(item)
		item.create_trimesh_collision()
		originals.append(item)
	var animated := MeshInstance3D.new()
	animated.mesh = BoxMesh.new()
	var glow := StandardMaterial3D.new()
	glow.emission_enabled = true
	animated.material_override = glow
	architecture.add_child(animated)
	assert(Batcher.build(architecture) == 6, "Eight opaque surfaces become two exact material batches")
	assert(animated.layers == 1, "Animated emissive surfaces remain live")
	await physics_frame
	for item in originals:
		assert(item.layers == 0 and item.visible and item.get_child_count() == 1,
			"Source transforms, visibility and collision nodes remain available")
		var ray := PhysicsRayQueryParameters3D.create(item.global_position + Vector3.UP * 4, item.global_position - Vector3.UP * 4)
		assert(not root.world_3d.direct_space_state.intersect_ray(ray).is_empty(), "Actual stair collision survives batching")
	var surfaces := 0
	var vertices := 0
	for child in architecture.get_children():
		if child is MeshInstance3D and child.layers != 0 and child != animated:
			surfaces += child.mesh.get_surface_count()
			vertices += child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	assert(surfaces == 2 and vertices == 8 * 24, "All original geometry is retained")
	architecture.hide()
	for child in architecture.get_children():
		if child is MeshInstance3D: assert(not child.is_visible_in_tree(), "Parent visibility still controls batches")
	architecture.free()
	print("STATIC SURFACE BATCH: PASS")
	quit()
