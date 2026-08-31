extends SceneTree

const MILO_SCENE := preload("res://scenes/milo_animations.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var milo := MILO_SCENE.instantiate() as CharacterBody3D
	root.add_child(milo)
	await process_frame
	milo.set_physics_process(false)
	milo.set_process(false)
	var skeleton := milo.find_child("Skeleton3D", true, false) as Skeleton3D
	var animation_player := milo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for node in milo.find_children("*", "Node", true, false):
		if "cane" in node.name.to_lower():
			var node_3d := node as Node3D
			var bounds := (node as MeshInstance3D).get_aabb() if node is MeshInstance3D \
				else AABB()
			var center := node_3d.to_global(bounds.get_center())
			print("CANE_NODE %s %s global=(%.3f,%.3f,%.3f) center=(%.3f,%.3f,%.3f) size=(%.3f,%.3f,%.3f)" % [
				str(milo.get_path_to(node)), node.get_class(), node_3d.global_position.x,
				node_3d.global_position.y, node_3d.global_position.z, center.x, center.y,
				center.z, bounds.size.x, bounds.size.y, bounds.size.z])
	animation_player.play("Cane_Walk", 0.0, 1.0)
	var clip := animation_player.get_animation("Cane_Walk")
	for sample_index in 17:
		var phase := float(sample_index) / 16.0
		animation_player.seek(minf(phase, 0.9999) * clip.length, true)
		animation_player.advance(0.0)
		var values: Array[String] = []
		for bone_name in ["hips", "upperleg.l", "lowerleg.l", "foot.l", "toes.l",
				"upperleg.r", "lowerleg.r", "foot.r", "toes.r", "hand.l", "hand.r"]:
			var bone := skeleton.find_bone(bone_name)
			var point := skeleton.get_bone_global_pose(bone).origin
			values.append("%s=(%.3f,%.3f,%.3f)" % [bone_name, point.x, point.y, point.z])
		print("PHASE %.4f %s" % [phase, " ".join(values)])
	milo.queue_free()
	quit()
