# Measures the imported castle instead of guessing where its door is.
#
# Two independent readings of the transform disagreed with what the renders
# show, so this stops reasoning about basis columns and asks the actual mesh:
# its world-space AABB, and the AABB of every named child, so the doorway /
# gate / arch submesh can be located directly.
extends SceneTree


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _i in 20:
		await process_frame

	var castle := hub.get_node_or_null("building_castle_red2") as Node3D
	if castle == null:
		push_error("PROBE: castle node not found")
		quit(1)
		return

	print("PROBE: castle global_position = ", castle.global_position)
	print("PROBE: castle global basis X = ", castle.global_transform.basis.x)
	print("PROBE: castle global basis Y = ", castle.global_transform.basis.y)
	print("PROBE: castle global basis Z = ", castle.global_transform.basis.z)

	var meshes := castle.find_children("*", "MeshInstance3D", true, false)
	print("PROBE: %d mesh children" % meshes.size())

	var total := AABB()
	var first := true
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var local := mi.mesh.get_aabb()
		# Corners into world space, so rotation/scale are accounted for.
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
		print("PROBE: mesh '%s' centre=%s size=%s"
			% [mi.name, world.get_center(), world.size])

	print("PROBE: castle world AABB centre = ", total.get_center())
	print("PROBE: castle world AABB size   = ", total.size)
	print("PROBE: x range %.2f .. %.2f" % [total.position.x, total.position.x + total.size.x])
	print("PROBE: y range %.2f .. %.2f" % [total.position.y, total.position.y + total.size.y])
	print("PROBE: z range %.2f .. %.2f" % [total.position.z, total.position.z + total.size.z])
	quit()


func _init() -> void:
	call_deferred("_run")
