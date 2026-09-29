extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("ARTEA_FORCE_WEB_LOD", "1")
	var scene := load("res://scenes/art_castle_floating_world.tscn") as PackedScene
	assert(scene != null, "the Castle Galaxy scene must load")
	var world := scene.instantiate() as Node3D
	root.add_child(world)
	for _frame in 8:
		await process_frame
	var causeway := world.get_node_or_null("MindSparkWorldOneCauseway") as Node3D
	assert(causeway != null, "the walkable World One causeway must be present")
	var batch_count := int(causeway.get_meta("web_visual_batch_count", 0))
	var source_count := int(causeway.get_meta("web_visual_source_count", 0))
	assert(source_count >= 400,
		"the Web pass must retire the causeway's hundreds of independent render submissions")
	assert(batch_count > 0 and batch_count <= 96,
		"the kilometre causeway must use a compact spatial batch set")
	var batches := causeway.find_children("WebCausewayBatch_*", "MeshInstance3D", false, false)
	assert(batches.size() == batch_count,
		"every reported causeway batch must remain mounted and inspectable")
	var represented_sources := 0
	var batch_triangles := 0
	for value in batches:
		var batch := value as MeshInstance3D
		assert(batch.mesh != null and batch.mesh.get_surface_count() == 1,
			"each causeway batch must be one real render surface")
		assert(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"Web causeway batches must not reintroduce an unused shadow pass")
		represented_sources += int(batch.get_meta("merged_static_source_count", 0))
		batch_triangles += _triangle_count(batch.mesh)
	assert(represented_sources == source_count,
		"batch metadata must account for every retired source exactly once")
	var retired_sources := 0
	var source_triangles := 0
	for value in causeway.find_children("*", "MeshInstance3D", true, false):
		var mesh := value as MeshInstance3D
		if not mesh.has_meta("render_merged_into"):
			continue
		retired_sources += 1
		source_triangles += _triangle_count(mesh.mesh)
		assert(mesh.layers == 0,
			"batched source geometry must not draw underneath its replacement")
		var replacement := causeway.get_node_or_null(
			str(mesh.get_meta("render_merged_into"))) as MeshInstance3D
		assert(replacement != null,
			"every retired source must name a live replacement batch")
		assert(replacement.material_override == mesh.material_override,
			"a replacement batch must retain the exact authored source material")
		var source_center := causeway.to_local(mesh.to_global(mesh.mesh.get_aabb().get_center()))
		assert(replacement.mesh.get_aabb().grow(0.01).has_point(source_center),
			"a replacement batch must contain its source at the authored transform")
	assert(retired_sources == source_count,
		"source nodes must stay inspectable while their visual layers are retired")
	assert(batch_triangles == source_triangles,
		"batching must preserve the complete causeway triangle inventory")
	var segment_count := int(causeway.get_meta("segment_count", 0))
	var deck_sources := 0
	for child in causeway.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
			var box := (child as MeshInstance3D).mesh as BoxMesh
			if absf(box.size.x - float(world.get("CAUSEWAY_WIDTH"))) < 0.01 \
					and box.size.z > 100.0:
				deck_sources += 1
	assert(deck_sources == segment_count,
		"batching must preserve every authored deck node used by traversal audits")
	var collision_bodies := causeway.find_children("*", "StaticBody3D", true, false)
	assert(collision_bodies.size() >= segment_count * 6,
		"render batching must preserve the bridge deck, curb, rail and pier collisions")
	OS.set_environment("ARTEA_FORCE_WEB_LOD", "")
	print("WORLD_ONE_WEB_CAUSEWAY_BATCH: PASS — %d static visuals -> %d spatial batches; %d collision bodies preserved" \
		% [source_count, batch_count, collision_bodies.size()])
	quit()


func _triangle_count(mesh: Mesh) -> int:
	var arrays := mesh.surface_get_arrays(0)
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	if not indices.is_empty():
		return indices.size() / 3
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
