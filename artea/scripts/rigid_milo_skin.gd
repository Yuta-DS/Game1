extends RefCounted

const SurfaceBatch = preload("res://scripts/static_surface_batch.gd")

## Most of Milo's separately sculpted pieces have exactly one bone at 100%
## weight. Bone attachments produce the identical motion without running a
## separate WebGL skinning pass for every button, whisker and coat panel.
## Flexible sleeves, morphing hands and procedurally offset pieces stay skinned.
const LIVE_PARTS := ["Paw_L", "Paw_R"]

static func build(model: Node3D) -> int:
	var converted := 0
	var attachments := {}
	for candidate in model.find_children("*", "MeshInstance3D", true, false):
		var item := candidate as MeshInstance3D
		if item.skin == null or item.mesh == null or item.get_blend_shape_count() > 0:
			continue
		if item.name in LIVE_PARTS or str(item.name).begins_with("MayorCane") or str(item.name).begins_with("Pupil") or str(item.name).begins_with("IrisInner") or str(item.name).begins_with("EyeCatchlight"):
			continue
		var skeleton := item.get_node_or_null(item.skeleton) as Skeleton3D
		if skeleton == null or not item.transform.is_equal_approx(Transform3D.IDENTITY): continue
		var joint := _rigid_joint(item.mesh)
		if joint < 0 or joint >= item.skin.get_bind_count(): continue
		var skin := item.skin
		var bone := skin.get_bind_bone(joint)
		if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(joint))
		if bone < 0: continue
		var attachment_key := str(skeleton.get_instance_id()) + ":" + str(bone)
		if not attachments.has(attachment_key):
			var attachment := BoneAttachment3D.new()
			attachment.name = "RigidPartBone_%d" % bone
			attachment.bone_name = skeleton.get_bone_name(bone)
			skeleton.add_child(attachment)
			attachments[attachment_key] = attachment
		var mesh := ArrayMesh.new()
		for surface in item.mesh.get_surface_count():
			var arrays := item.mesh.surface_get_arrays(surface)
			arrays[Mesh.ARRAY_BONES] = null
			arrays[Mesh.ARRAY_WEIGHTS] = null
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(surface, item.mesh.surface_get_material(surface))
		item.set_meta("rigid_skin_bone", bone)
		item.set_meta("rigid_skin_bind", skin.get_bind_pose(joint))
		# Speaking/blinking switches these named pieces independently.
		if str(item.name).begins_with("Mouth") or str(item.name).begins_with("Tongue") or str(item.name).begins_with("Eyelid"):
			item.set_meta("preserve_runtime_node", true)
		item.reparent(attachments[attachment_key], false)
		item.transform = skin.get_bind_pose(joint)
		item.skin = null
		item.skeleton = NodePath("")
		item.mesh = mesh
		converted += 1
	for attachment: BoneAttachment3D in attachments.values():
		SurfaceBatch.build(attachment)
	return converted

static func _rigid_joint(mesh: Mesh) -> int:
	var joint := -1
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var count: int = arrays[Mesh.ARRAY_VERTEX].size()
		if count == 0 or weights.is_empty() or bones.size() != weights.size(): return -1
		var stride := weights.size() / count
		for vertex in count:
			var total := 0.0
			for offset in stride:
				var index: int = vertex * stride + offset
				var weight := weights[index]
				total += weight
				if weight <= 0.00001: continue
				if joint < 0: joint = bones[index]
				if bones[index] != joint: return -1
			if absf(total - 1.0) > 0.0001: return -1
	return joint
