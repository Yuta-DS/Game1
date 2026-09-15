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
	world.free()
	await process_frame
	print("STATIC_BATCH_VISIBILITY: PASS — direct/inherited hidden meshes retained, only eight visible meshes batched")
	quit()
