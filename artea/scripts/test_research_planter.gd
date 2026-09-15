extends SceneTree
const Planter = preload("res://scripts/mind_spark/research_planter.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud=false
	world.get_node("QuestController").enabled=false
	root.add_child(world)
	var garden := world.get_node("GardenOfUnfinishedLight")
	var beds := garden.find_children("ResearchPlanter_*","Node3D",true,false)
	assert(beds.size()==9,"Seven court beds and two conservatory beds must remain")
	for bed in beds:
		var solid := bed.get_node("RetainingShellSolid") as StaticBody3D
		assert(solid.collision_layer != 0)
		var shape := solid.get_child(0) as CollisionShape3D
		assert((shape.shape as BoxShape3D).size == Vector3(15,2,9))
		var foliage := bed.get_node("RootedSageRosettes") as MultiMeshInstance3D
		assert(foliage.multimesh.instance_count == 40)
		var vertices: PackedVector3Array=foliage.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		assert(vertices.size()==24,"Each leaf has eight deliberate triangular faces")
		for i in 40:
			# Dummy rendering does not retain instance transforms. Check the exact
			# construction function headlessly, and GPU-backed storage in Compatibility.
			var transform := Planter.leaf_transform(i / 8,i % 8)
			if DisplayServer.get_name() != "headless":
				transform=foliage.multimesh.get_instance_transform(i)
			if not is_equal_approx(transform.origin.y,1.72):
				push_error("Unexpected root transform: %s at instance %d" % [transform.origin,i])
				quit(1)
				return
			for vertex in vertices:
				var point: Vector3=transform*vertex
				assert(absf(point.x)<6.6 and absf(point.z)<3.3,"Foliage must not cross the retaining rim or route")
		assert(bed.find_children("DripBranch*","Node3D",true,false).size()==5)
	assert(garden.find_children("SagePlant*","Node3D",true,false).is_empty(),"No old spherical plant placeholders")
	var zones: Dictionary=world.get("_zone_nodes")
	var terraces := (zones["04_hope_path_ridge"] as Node3D).get_node("CelestialHopeUpperDistrict/CurvedSunriseGardenTerraces")
	assert(terraces.find_children("RootedTerraceFoliage_*","MultiMeshInstance3D",false,false).size()==12)
	for index in 12:
		for prefix in ["SunriseGardenCrown_","SunriseGardenBloom_"]:
			assert(not terraces.get_node(prefix+"%02d"%(index+1)).is_visible_in_tree(),"No hovering decorative blooms")
		var plants := terraces.get_node("RootedTerraceFoliage_%02d"%(index+1)) as MultiMeshInstance3D
		assert(plants.multimesh.instance_count==72)
		if DisplayServer.get_name()!="headless":
			var vertices: PackedVector3Array=plants.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			for instance in 72:
				var transform := plants.multimesh.get_instance_transform(instance)
				assert(is_equal_approx(transform.origin.y,1.48),"Terrace plants must root below the soil surface")
				for vertex in vertices:
					var point: Vector3=transform*vertex
					var radius := Vector2(point.x,point.z).length()
					var angle := wrapf(rad_to_deg(atan2(point.x,point.z)),0,360)
					assert(radius>79 and radius<98,"Leaves must remain inside curved bed")
					assert(angle>126+index*10 and angle<134+index*10,"Leaves must not extend into terrace gaps")
	world.queue_free()
	await process_frame
	print("RESEARCH_PLANTER: PASS — nine beds, original solid footprints, 360 rooted instanced leaves inside soil, five feeds per bed")
	print("CURVED_TERRACES: PASS — twelve retained beds, 24 hovering ornaments retired, 864 instanced leaves; rendered mode checks every vertex against curved boundaries")
	print("Transform evidence: construction math" if DisplayServer.get_name()=="headless" else "Transform evidence: rendered MultiMesh storage")
	quit()
