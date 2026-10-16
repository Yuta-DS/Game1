extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate()
	world.build_hud = false
	world.object_state_store_path = "user://layout_audit_readonly.json"
	world.get_node("QuestController").enabled = false
	root.add_child(world)
	await process_frame
	await process_frame
	var arrival = world.get_quest_objects()[0].get_parent()
	var candidates := []
	var obstacles := []
	for mesh in world.find_children("*","MeshInstance3D",true,false):
		if mesh.is_visible_in_tree():
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			if bounds.size.length() < 80: obstacles.append(bounds)
	for x in [-90,-75,-60,-45,45,60,75,90]:
		for z in [0,15,30,45,60,75,90]:
			if Vector2(x,z).length()>112: continue
			var bounds: AABB = arrival.global_transform * AABB(Vector3(x-7,3,z-4),Vector3(14,14,14))
			var clear := true
			for obstacle in obstacles:
				if bounds.intersects(obstacle): clear=false; break
			if clear: candidates.append(Vector3(x,2,z))
	print("ARRIVAL_CANDIDATES ",candidates)
	for object in world.get_quest_objects():
		# Measure support below an object's root, excluding its own collision shapes.
		var support_query := PhysicsRayQueryParameters3D.create(
			object.global_position+Vector3.UP*40.0, object.global_position-Vector3.UP*120.0)
		for collider in object.find_children("*", "CollisionObject3D", true, false):
			support_query.exclude.append((collider as CollisionObject3D).get_rid())
		var support: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(support_query)
		if support.is_empty():
			print("HEIGHT ", object.save_id, " root_y=", snappedf(object.global_position.y,.01), " support=NONE")
		else:
			print("HEIGHT ", object.save_id, " root_y=", snappedf(object.global_position.y,.01),
				" support_y=", snappedf((support.position as Vector3).y,.01),
				" delta=", snappedf(object.global_position.y-(support.position as Vector3).y,.01),
				" support=", (support.collider as Node).get_path())
		var volume: AABB = object.global_transform * AABB(Vector3(-1,.25,-.5),Vector3(2,1.8,1.0))
		var overlaps := []
		for mesh in world.find_children("*","MeshInstance3D",true,false):
			if not mesh.is_visible_in_tree() or object.is_ancestor_of(mesh): continue
			var other: AABB = mesh.global_transform * mesh.get_aabb()
			if volume.intersects(other): overlaps.append(str(mesh.get_path()))
		print("LAYOUT ",object.save_id," ",object.position," overlaps=",overlaps)
		if object.save_id in ["world_one.focus_bell", "world_one.path_projector"]:
			for batch in world.find_children("*","MultiMeshInstance3D",true,false):
				if not batch.is_visible_in_tree(): continue
				for i in batch.multimesh.instance_count:
					var transform: Transform3D = batch.global_transform * batch.multimesh.get_instance_transform(i)
					if volume.intersects(transform * batch.multimesh.mesh.get_aabb()):
						print("BATCH_OVERLAP ",object.save_id," ",batch.name," ",i," ",batch.multimesh.mesh.get_class()," local=",object.get_parent().to_local(transform.origin))
	world.queue_free()
	await process_frame
	quit()
