extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	root.add_child(world)
	for _frame in 5:
		await process_frame

	var geometry := world.get_node("WorldOneGeometry") as Node3D
	var fusion := geometry.get_node(
		"ThreeFusedSuperIslands/FusedSuperIsland_01_02"
	) as Node3D
	var authored := fusion.get_node("BlenderAuthoredIslandOneTopOverlay") as Node3D
	assert(int(authored.get_meta("editable_source_parts", 0)) == 3000)
	assert(int(authored.get_meta("runtime_batches", 0)) == 9)
	assert(authored.find_children("MSI1_Runtime_*", "MeshInstance3D", true, false).size() == 9,
		"the exact 3,000 editable pieces are safely merged into nine live render roles")
	assert(str(authored.get_meta("application_mode", "")) == "additive_above_ground_only")
	assert(bool(authored.get_meta("existing_foundation_preserved", false)))
	var visible_batches := 0
	for mesh in authored.find_children("MSI1_Runtime_*", "MeshInstance3D", true, false):
		if (mesh as MeshInstance3D).visible:
			visible_batches += 1
	print("MindSparkSuperIslandOne3000: visible upper-detail batches = %d" % visible_batches)
	assert(visible_batches == 3,
		"only the three non-duplicating upper-detail batches are layered over the existing island")
	assert(fusion.get_node_or_null("SharedIvorySaddleCollision") is StaticBody3D,
		"the fused waist has uninterrupted traversal collision")
	assert(int(fusion.get_meta("foundation_machine_parts", -1)) == 0,
		"the rejected Blender undercroft is not drawn over the existing foundation")

	var foundations := geometry.find_children("ModularFloatingFoundation", "Node3D", true, false)
	for variant_index in [1, 2]:
		var foundation: Node3D = null
		for candidate in foundations:
			if int(candidate.get_meta("variant_index", 0)) == variant_index:
				foundation = candidate as Node3D
				break
		assert(foundation != null, "both original Island One foundations remain present")
		assert(str(foundation.get_meta("replaced_by", "")) == "")
		assert(foundation.get_child_count() > 0,
			"the existing paving and island architecture remain visible")

	var compass := world.get_island_one_puzzle()
	assert(compass != null)
	assert(compass.find_children("PuzzleControl_*", "Node3D", true, false).size() == 6)
	assert(world.get_quest_objects().size() == 15)
	assert(world.get_collectibles().size() == 2)
	print("MindSparkSuperIslandOne3000: PASS — additive top design preserves the existing island")
	world.queue_free()
	await process_frame
	quit()
