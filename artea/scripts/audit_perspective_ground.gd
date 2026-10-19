extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud=false
	world.get_node("QuestController").enabled=false
	root.add_child(world)
	for i in 4: await physics_frame
	var station := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.PERSPECTIVE_LENS)
	var excluded: Array[RID]=[]
	for body in station.find_children("*","CollisionObject3D",true,false): excluded.append(body.get_rid())
	var zone := station.get_parent() as Node3D
	for x in [-24,-12,0]:
		for z in [-30,-18,-6,6,18]:
			var heights: Array[float]=[]
			var owners: Array[String]=[]
			for offset in [Vector3.ZERO,Vector3(-3.6,0,-2),Vector3(3.6,0,-2),Vector3(-3.6,0,2),Vector3(3.6,0,2),Vector3(0,0,6)]:
				var at: Vector3 = zone.to_global(Vector3(x,0,z))+station.global_basis*offset
				var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*8,at-Vector3.UP*5,1,excluded)
				var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty():
					heights.append(hit.position.y)
					owners.append(str(hit.collider.name))
			if heights.size()==6 and heights.max()-heights.min()<.05: print("LEVEL_CANDIDATE ",x,",",z," floor=",heights[0]," ",owners)
	world.queue_free()
	await process_frame
	quit()
