extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud=false
	world.get_node("QuestController").enabled=false
	root.add_child(world)
	var garden := world.get_node("GardenOfUnfinishedLight")
	var gallery := garden.get_node("ConservatoryOfPossibleTomorrow")
	var roof := gallery.get_node("FramedConservatoryRoof")
	var vertices: PackedVector3Array=roof.get_node("FramedSideGlazing").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(vertices.size()==96)
	for point in vertices:
		assert(point.z>=-20 and point.z<=20,"Glazing beyond the end arches")
		assert(point.y>28,"Glazing encroaches on the open aisle")
		assert(absf(point.x)>24,"Central ventilation opening must remain clear")
	for member in roof.get_children():
		if not member.has_meta("support_start"): continue
		for key in ["support_start","support_end"]:
			var endpoint: Vector3=member.get_meta(key)
			assert(absf(endpoint.z)==20)
			# Check against the authored arch equation, not an independent
			# approximate bounding box or a node-existence-only assertion.
			assert(absf(pow(endpoint.x/35.0,2)+pow((endpoint.y-24)/12.0,2)-1)<.001)
	assert(gallery.find_children("Ridge*","Node3D",false,false).is_empty())
	assert(gallery.find_children("PierFootSolid*","StaticBody3D",false,false).size()==10)
	var fused := world.get_node("WorldOneGeometry/ThreeFusedSuperIslands/FusedSuperIsland_03_04")
	for pattern in ["*PromenadeRail","*PromenadeLamp_*","*PromenadeGlow_*","InternalPromenadeInlay","AetherFlowChannel"]:
		for fitting in fused.find_children(pattern,"Node3D",false,false):
			assert(not fitting.is_visible_in_tree(),"Obsolete promenade fittings cross the conservatory")
			for body in fitting.find_children("*","CollisionObject3D",true,false):
				assert(body.collision_layer==0,"Retired rail must not become an invisible obstacle")
	assert(world.get_node("IslandTwoMemoryCampus/MemoryPromenade").is_visible_in_tree())
	world.queue_free()
	await process_frame
	print("CONSERVATORY_ROOF: PASS — glazing bounded by arches, supported members, open central roof, ten column feet")
	quit()
