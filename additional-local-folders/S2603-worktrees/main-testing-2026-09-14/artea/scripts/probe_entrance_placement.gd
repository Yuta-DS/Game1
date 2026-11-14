# Reports where the entrance's parts actually end up in the live hub, so their
# placement can be checked against the castle instead of inferred from renders.
extends SceneTree


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _i in 30:
		await process_frame

	var rig := hub.get_node_or_null("CastleEntrance/CastleEntrance") as Node3D
	if rig == null:
		push_error("PROBE: entrance rig missing")
		quit(1)
		return

	var total := AABB()
	var first := true
	for node in rig.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var local := mi.mesh.get_aabb()
		var xform := mi.global_transform
		var world := AABB(xform * local.position, Vector3.ZERO)
		for c in 8:
			world = world.expand(xform * (local.position + Vector3(
				local.size.x * float(c & 1),
				local.size.y * float((c >> 1) & 1),
				local.size.z * float((c >> 2) & 1))))
		if first:
			total = world
			first = false
		else:
			total = total.merge(world)

	print("PROBE: entrance AABB centre = ", total.get_center())
	print("PROBE: entrance AABB size   = ", total.size)
	print("PROBE: entrance x %.2f .. %.2f" % [total.position.x, total.position.x + total.size.x])
	print("PROBE: entrance y %.2f .. %.2f" % [total.position.y, total.position.y + total.size.y])
	print("PROBE: entrance z %.2f .. %.2f" % [total.position.z, total.position.z + total.size.z])

	# The stair's crown deck and causeway, for comparison — the big white slab
	# in the renders is one of these, not the plaza.
	var stair := hub.get_node_or_null("CastleStairs/CastleStair") as Node3D
	if stair != null:
		var deck := stair.get_node_or_null("CrownDeck") as Node3D
		if deck != null:
			print("PROBE: crown deck at ", deck.global_position)
		var landing := stair.get_node_or_null("CastleDoorLanding") as Node3D
		if landing != null:
			print("PROBE: causeway landing at ", landing.global_position)

	# The castle foundation, which is what the plaza has been disappearing into.
	var foundation := hub.get_node_or_null("CastleFoundation") as Node3D
	if foundation != null:
		print("PROBE: foundation at ", foundation.global_position)
	quit()


func _init() -> void:
	call_deferred("_run")
