# Measures the join between the spiral stair's crown deck, the causeway, and
# the courtyard terrace — the two places the player reports a missing
# connection and objects they can walk through.
#
# Prints the real world extents of each piece plus every gap between them, so
# the fix is driven by numbers rather than by reading renders.
extends SceneTree


func _bounds(root: Node3D, filter: String) -> AABB:
	var total := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		if filter != "" and not String(mi.name).begins_with(filter):
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
	return total


func _report(label: String, box: AABB) -> void:
	print("PROBE: %-22s x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f"
		% [label, box.position.x, box.position.x + box.size.x,
			box.position.y, box.position.y + box.size.y,
			box.position.z, box.position.z + box.size.z])


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _i in 40:
		await process_frame

	var stair := hub.get_node_or_null("CastleStairs/CastleStair") as Node3D
	var entrance := hub.get_node_or_null("CastleEntrance/CastleEntrance") as Node3D
	if stair == null or entrance == null:
		push_error("PROBE: stair or entrance missing")
		quit(1)
		return

	var deck := stair.get_node_or_null("CrownDeck") as Node3D
	if deck != null:
		print("PROBE: crown deck origin ", deck.global_position)

	_report("whole stair", _bounds(stair, ""))
	_report("stair treads", _bounds(stair, "StairTread_"))
	_report("whole entrance", _bounds(entrance, ""))

	# Causeway planks are unnamed boxes built by _build_bridge. Identify them by
	# sitting above the terrain but outside the tower's own radius.
	var plank_total := AABB()
	var plank_first := true
	var plank_count := 0
	for node in stair.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var p := mi.global_position
		if p.y < 66.0 or p.y > 74.0:
			continue
		if p.x < -40.0 or p.x > -8.0:
			continue
		var b := AABB(p, Vector3.ZERO)
		if plank_first:
			plank_total = b
			plank_first = false
		else:
			plank_total = plank_total.expand(p)
		plank_count += 1
	print("PROBE: causeway-height stair meshes: %d" % plank_count)
	if plank_count > 0:
		_report("causeway span", plank_total)

	# Collision is what actually stops the player, so count bodies too — a
	# visible plank with no StaticBody3D is a thing you walk through.
	var stair_bodies := stair.find_children("*", "StaticBody3D", true, false)
	var entrance_bodies := entrance.find_children("*", "StaticBody3D", true, false)
	print("PROBE: stair collision bodies    %d" % stair_bodies.size())
	print("PROBE: entrance collision bodies %d" % entrance_bodies.size())

	var stair_meshes := stair.find_children("*", "MeshInstance3D", true, false)
	print("PROBE: stair meshes %d (bodies %d)"
		% [stair_meshes.size(), stair_bodies.size()])
	quit()


func _init() -> void:
	call_deferred("_run")
