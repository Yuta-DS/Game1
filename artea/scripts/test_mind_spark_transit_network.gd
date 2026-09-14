extends SceneTree

const FloatingWorldScene := preload("res://scenes/art_castle_floating_world.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var floating_world := FloatingWorldScene.instantiate() as Node3D
	root.add_child(floating_world)
	for _frame in 8:
		await physics_frame

	var world := floating_world.get_node("MindSparkWorldOne") as MindSparkWorldOne
	assert(world.get_node_or_null("WorldOneGeometry/MindSparkTransitNetwork") == null,
		"the retired shortcut pad/portal set must stay absent from the three-island route")
	assert(world.get_transit_portals().is_empty(),
		"the player must use authored gates and walkways, not duplicate shortcut portals")
	print("MindSparkTransitNetwork: PASS — retired cyan pads and violet/cyan shortcut rings remain removed")
	quit()
