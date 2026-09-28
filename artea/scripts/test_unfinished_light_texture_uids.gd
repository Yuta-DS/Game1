extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const BayMount := preload("res://scripts/mind_spark/research_bay_mount.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	root.add_child(world)
	for _frame in 8:
		await physics_frame
	for asset in BayMount.IMPORTED_TEXTURE_UID_ALIASES:
		var alias: Dictionary = BayMount.IMPORTED_TEXTURE_UID_ALIASES[asset]
		var uid := ResourceUID.text_to_id(str(alias.uid))
		assert(ResourceUID.has_id(uid), "%s is registered before its GLB loads" % alias.uid)
		assert(ResourceUID.get_id_path(uid) == str(alias.path),
			"%s resolves directly to its checked-in atlas" % alias.uid)
		assert(ResourceLoader.exists(str(asset)), "%s remains a loadable production model" % asset)
	for node_name in ["ProductionInspectionBay", "ProductionRecorderBay",
			"ProductionTesterBay", "ProductionPerspectiveBay", "ProductionLivingProjector"]:
		assert(world.find_child(node_name, true, false) != null,
			"%s remains mounted after UID registration" % node_name)
	print("UnfinishedLightTextureUIDs: PASS — five legacy texture UIDs resolve without path fallback")
	world.queue_free()
	await process_frame
	quit()
