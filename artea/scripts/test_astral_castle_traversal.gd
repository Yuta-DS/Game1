extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("ASTRAL_CASTLE_TRAVERSAL: " + message)
	quit(1)


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	root.add_child(world)
	for _frame in 8:
		await physics_frame
	var route := world.get_node("WorldOneGeometry/MainStoryCircuitRoute") as Node3D
	for removed_leg in ["A", "B"]:
		if route.get_node_or_null("CircuitRoute_02_%s" % removed_leg) != null \
				or route.get_node_or_null("CircuitRoute_02_%sCollision" % removed_leg) != null:
			_fail("the photographed Island One bridge was not removed")
			return
	for retained_leg in ["A", "B"]:
		if route.get_node_or_null("CircuitRoute_03_%s" % retained_leg) == null \
				or route.get_node_or_null("CircuitRoute_03_%sCollision" % retained_leg) == null:
			_fail("the retained Island Two promenade is missing walkable collision")
			return
	print("ASTRAL_CASTLE_TRAVERSAL: PASS — Island One bridge removed; retained promenade is walkable")
	world.queue_free()
	await process_frame
	quit()
