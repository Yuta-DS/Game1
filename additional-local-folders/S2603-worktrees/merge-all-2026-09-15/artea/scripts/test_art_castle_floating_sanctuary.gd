extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("FLOATING_SANCTUARY_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var sanctuary := Node3D.new()
	sanctuary.name = "FloatingCrownSanctuary"
	sanctuary.set_script(load("res://scripts/art_castle_floating_sanctuary.gd"))
	root.add_child(sanctuary)
	await process_frame

	for required in ["SanctuaryDeck", "ArrivalBridge", "WorldFrameGate", "LumenTree"]:
		if sanctuary.get_node_or_null(required) == null:
			_fail("missing required world element %s" % required)
			return
	if sanctuary.find_children("Route_*", "Node3D", false, false).size() != 3:
		_fail("expected three route beacons")
		return
	if sanctuary.get_node_or_null("WalkableBridgeCollision") == null \
			or sanctuary.get_node_or_null("SanctuaryDeckCollision") == null:
		_fail("bridge and sanctuary must both be walkable")
		return
	if sanctuary.get_node_or_null("WorldPortalBridge") != null \
			or sanctuary.get_node_or_null("FloatingWorldPortal") != null:
		_fail("separate galaxy bridge or teleport door still exists")
		return
	print("FLOATING_SANCTUARY_TEST: PASS — entrance, walkable world, tree, and 3 routes built")
	quit()
