extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.get_node("QuestController").enabled = false
	root.add_child(world)
	await process_frame
	var repairs := world.get_node("WorldOneGeometry/IslandTwoPerimeterRepairs")
	var posts: Array = []
	for node in repairs.get_children():
		if not str(node.name).begins_with("ReferencePost_") or not node.visible: continue
		var mesh := node.get_child(0) as MeshInstance3D
		var point := mesh.to_global(mesh.get_aabb().get_center())
		posts.append({"name":node.name, "point":point})
	var clashes := 0
	for i in posts.size():
		for j in range(i + 1, posts.size()):
			var a: Vector3 = posts[i].point
			var b: Vector3 = posts[j].point
			var distance := Vector2(a.x-b.x, a.z-b.z).length()
			if distance < 14.0:
				clashes += 1
				print("CLOSE_POSTS: %s / %s distance %.2f" % [posts[i].name,posts[j].name,distance])
	print("LANTERN_SPACING: %d visible posts, %d clusters" % [posts.size(),clashes])
	world.queue_free()
	await process_frame
	quit(1 if clashes else 0)
