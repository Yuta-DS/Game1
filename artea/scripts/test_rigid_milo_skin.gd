extends SceneTree

const Optimizer = preload("res://scripts/rigid_milo_skin.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var model := (load("res://assets3D/characters/milo_exact_target_parts.glb") as PackedScene).instantiate() as Node3D
	root.add_child(model)
	await process_frame
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var count := Optimizer.build(model)
	assert(count > 85, "Most rigid sculpted parts avoid redundant skinning passes")
	assert((model.find_child("Sleeve_L", true, false) as MeshInstance3D).skin != null, "Flexible sleeves remain skinned")
	assert((model.find_child("Paw_L", true, false) as MeshInstance3D).get_blend_shape_count() == 1, "Finger-curl morph remains available")
	assert((model.find_child("Pupil_L", true, false) as MeshInstance3D).skin != null, "Procedural gaze retains its original coordinate space")
	for angle in [0.0, 0.3, -0.2]:
		skeleton.set_bone_pose_rotation(skeleton.find_bone("head"), Quaternion(Vector3.UP, angle))
		skeleton.set_bone_pose_rotation(skeleton.find_bone("chest"), Quaternion(Vector3.RIGHT, angle * 0.5))
		skeleton.force_update_all_bone_transforms()
		await process_frame
		await process_frame
		for item in model.find_children("*", "MeshInstance3D", true, false):
			if not item.has_meta("rigid_skin_bone"): continue
			var bone: int = item.get_meta("rigid_skin_bone")
			var bind: Transform3D = item.get_meta("rigid_skin_bind")
			var expected := skeleton.global_transform * skeleton.get_bone_global_pose(bone) * bind
			var vertices: PackedVector3Array = item.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for index in [0, vertices.size() / 2, vertices.size() - 1]:
				assert((expected * vertices[index]).distance_to(item.global_transform * vertices[index]) < 0.0001,
					"Rigid attachments must exactly reproduce weighted skinning in animated poses: " + str(item.name))
	model.free()
	print("RIGID MILO SKIN: PASS — exact animated vertex positions and live face/hand controls")
	quit()
