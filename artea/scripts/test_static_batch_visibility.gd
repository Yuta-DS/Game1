extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var world := MindSparkWorldOne.new()
	var fixture := Node3D.new()
	root.add_child(fixture)
	var retired := Node3D.new()
	retired.visible=false
	fixture.add_child(retired)
	var mesh := BoxMesh.new()
	for i in 24:
		var part := MeshInstance3D.new()
		part.name="Part%d"%i
		part.mesh=mesh
		part.position=Vector3(i,0,0)
		if i<8: retired.add_child(part)
		else:
			fixture.add_child(part)
			part.visible=i>=16
	var groups := {}
	world.call("_collect_batchable",fixture,groups)
	var count := 0
	for members in groups.values(): count+=members.size()
	if count!=8:
		push_error("Hidden geometry entered visible batches: expected 8, got %d"%count)
		fixture.queue_free()
		world.free()
		await process_frame
		quit(1)
		return
	world.call("_batch_static_geometry",fixture)
	await process_frame
	var batches := fixture.find_children("BatchedGeometry*","MultiMeshInstance3D",false,false)
	assert(batches.size()==1 and batches[0].multimesh.instance_count==8)
	assert(retired.get_child_count()==8,"Retired source must stay available for recovery")
	assert(not retired.is_visible_in_tree())
	fixture.queue_free()
	await process_frame
	OS.set_environment("ARTEA_FORCE_WEB_LOD", "1")
	var web_fixture := Node3D.new()
	root.add_child(web_fixture)
	for cell in 2:
		for index in 8:
			var part := MeshInstance3D.new()
			part.mesh = mesh
			part.position = Vector3(cell * 160.0 + index, 0, 0)
			web_fixture.add_child(part)
	world.call("_batch_static_geometry",web_fixture)
	await process_frame
	var web_batches := web_fixture.find_children(
		"BatchedGeometry*","MultiMeshInstance3D",false,false)
	assert(web_batches.size()==2,
		"Web repeated geometry must split into independently culled spatial cells")
	for batch in web_batches:
		assert((batch as MultiMeshInstance3D).multimesh.instance_count==8)
	OS.set_environment("ARTEA_FORCE_WEB_LOD", "")
	web_fixture.queue_free()
	world.free()
	await process_frame
	print("STATIC_BATCH_VISIBILITY: PASS — hidden meshes retained; Web repeated geometry uses two independently culled spatial cells")
	quit()
