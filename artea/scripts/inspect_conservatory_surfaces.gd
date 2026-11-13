extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1280,720)
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud=false
	# Diagnostic only: keep source ownership available to ray picking. Production
	# still batches static geometry normally.
	world.set_meta("preserve_authored_nodes",true)
	world.get_node("QuestController").enabled=false
	root.add_child(world)
	var gallery := world.get_node("GardenOfUnfinishedLight/ConservatoryOfPossibleTomorrow") as Node3D
	var camera := Camera3D.new()
	camera.fov=60
	root.add_child(camera)
	camera.global_position=gallery.to_global(Vector3(55,38,48))
	camera.look_at(gallery.to_global(Vector3(0,20,0)))
	await process_frame
	print("VIEWPORT ",root.get_visible_rect())
	for batch in world.find_children("*","MultiMeshInstance3D",true,false):
		if batch.is_visible_in_tree(): print("BATCH ",batch.get_path())
	for pixel in [Vector2(551,460),Vector2(534,410),Vector2(391,397),Vector2(261,598)]:
		var origin := camera.project_ray_origin(pixel)
		var direction := camera.project_ray_normal(pixel)
		var nearest := INF
		var owner_path := "none"
		for candidate in world.find_children("*","MeshInstance3D",true,false):
			var node := candidate as MeshInstance3D
			if not node.is_visible_in_tree() or node.mesh==null: continue
			var inverse := node.global_transform.affine_inverse()
			var start := inverse*origin
			var end := inverse*(origin+direction*1000)
			if not node.get_aabb().intersects_segment(start,end): continue
			var faces := node.mesh.get_faces()
			for index in range(0,faces.size(),3):
				var hit: Variant=Geometry3D.ray_intersects_triangle(start,(end-start).normalized(),faces[index],faces[index+1],faces[index+2])
				if hit==null: continue
				var distance := origin.distance_to(node.to_global(hit))
				if distance<nearest:
					nearest=distance
					owner_path=str(node.get_path())
		print("SURFACE ",pixel," -> ",owner_path)
	world.queue_free()
	await process_frame
	quit()
