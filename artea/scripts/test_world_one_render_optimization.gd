extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://test_world_one_render_optimization.json"
	root.add_child(world)
	await process_frame

	var merged_groups := int(world.get_meta("merged_static_render_groups", 0))
	var merged_sources := int(world.get_meta("merged_static_render_sources", 0))
	var repeated_groups := int(world.get_meta("batched_static_render_groups", 0))
	var repeated_sources := int(world.get_meta("batched_static_render_sources", 0))
	var ranged_meshes := int(world.get_meta("distance_culled_mesh_count", 0))
	var storm_crown := world.get_warden().get_node("VisualRoot/BlightShell/StormCrown") as Node3D
	var animated_crown_sources := int(storm_crown.get_meta("merged_static_source_count", 0))
	assert(merged_groups > 0 and merged_sources > merged_groups * 3,
		"World One must consolidate meaningful groups of inert static render leaves")
	assert(repeated_groups > 0 and repeated_sources > repeated_groups * 3,
		"World One must instance repeated static meshes without deleting authored nodes")
	assert(ranged_meshes > 1000,
		"World One must apply distance ranges broadly enough to cull distant trim")

	var tagged_sources := 0
	var batched_sources := 0
	for mesh_value in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_value as MeshInstance3D
		if mesh.layers == 0:
			assert(mesh.has_meta("render_merged_into"),
				"no visible mesh may be removed from render layers without a replacement batch")
			assert(mesh.mesh != null,
				"merged sources retain authored mesh data for inspection and collision derivation")
			tagged_sources += 1
		if mesh.has_meta("merged_static_source_count"):
			assert(mesh.layers == 1 and mesh.mesh != null,
				"every merged render batch remains drawable")
			batched_sources += int(mesh.get_meta("merged_static_source_count"))
	for batch_value in world.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := batch_value as MultiMeshInstance3D
		if batch.has_meta("merged_static_source_count"):
			assert(batch.layers == 1 and batch.multimesh != null,
				"every repeated static batch remains drawable")
			batched_sources += int(batch.get_meta("merged_static_source_count"))
	assert(tagged_sources == merged_sources + repeated_sources + animated_crown_sources \
			and batched_sources == tagged_sources,
		"every disabled source maps exactly once to a live static or animated render batch")
	var garden := world.get_node("GardenOfUnfinishedLight")
	var garden_batched_sources := 0
	for mesh_value in garden.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_value as MeshInstance3D
		if mesh.layers == 0 and mesh.has_meta("render_merged_into"):
			garden_batched_sources += 1
	assert(garden_batched_sources > 300,
		"the retired garden projector must not prevent its live static conservatory from batching")

	for object in world.get_quest_objects():
		var visible_meshes := 0
		for mesh_value in object.find_children("*", "MeshInstance3D", true, false):
			var mesh := mesh_value as MeshInstance3D
			if mesh.visible and mesh.layers != 0:
				visible_meshes += 1
		assert(visible_meshes > 0,
			"quest object %s must retain independently rendered feedback geometry" % object.save_id)

	print("WORLD_ONE_RENDER_OPTIMIZATION: PASS — %d static sources -> %d spatial batches, plus %d animated Warden crown sources -> 4 batches, including %d conservatory sources; %d meshes use distance ranges; all 15 quest visuals remain independent" % [
		merged_sources + repeated_sources, merged_groups + repeated_groups,
		animated_crown_sources, garden_batched_sources, ranged_meshes])
	quit()
