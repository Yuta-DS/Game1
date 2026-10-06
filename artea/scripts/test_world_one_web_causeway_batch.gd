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
	var removal := world.get_node_or_null("MindSparkWorldOneCausewayRemoved") as Node3D
	assert(world.get_node_or_null("MindSparkWorldOneCauseway") == null,
		"the retired kilometre causeway must not be exported")
	assert(removal != null and bool(removal.get_meta("all_visuals_removed", false)) \
		and bool(removal.get_meta("all_collision_removed", false)),
		"the Web build must retain the complete causeway removal contract")
	assert(world.find_children("WebCausewayBatch_*", "MeshInstance3D", true, false).is_empty(),
		"retired causeway render batches must not survive in the Web scene")
	assert(world.find_children("CausewaySupportIsland_*", "Node3D", true, false).is_empty(),
		"retired causeway support land must not survive in the Web scene")
	OS.set_environment("ARTEA_FORCE_WEB_LOD", "")
	print("WORLD_ONE_WEB_CAUSEWAY_BATCH: PASS — kilometre causeway, support land, visuals and collision absent")
	quit()
