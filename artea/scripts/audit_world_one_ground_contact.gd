extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 10:
		await physics_frame
	for object in world.get_quest_objects():
		var lowest := _lowest_visible_point(object)
		print("GROUND_AUDIT ", object.save_id, " root=", snappedf(object.global_position.y, .001),
			" visible_bottom=", snappedf(float(lowest.y), .001), " mesh=", str(lowest.name),
			" support=", str(object.get_meta("ground_support", "")))
	world.queue_free()
	await process_frame
	quit()


func _lowest_visible_point(root_node: Node3D) -> Dictionary:
	var result := {"y": INF, "name": ""}
	for candidate in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if not mesh_instance.visible or mesh_instance.mesh == null:
			continue
		var box := mesh_instance.mesh.get_aabb()
		for x in [box.position.x, box.end.x]:
			for y in [box.position.y, box.end.y]:
				for z in [box.position.z, box.end.z]:
					var point := mesh_instance.to_global(Vector3(x, y, z))
					if point.y < float(result.y):
						result.y = point.y
						result.name = str(mesh_instance.get_path())
	return result
