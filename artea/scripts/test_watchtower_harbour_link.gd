extends SceneTree

class Sailor:
	extends CharacterBody3D
	var interacting := false
	func collect_item(_item = null) -> void:
		pass

var walker: CharacterBody3D

func _init() -> void:
	call_deferred("_run")

func _walk_to(target: Vector3) -> bool:
	for frame in 240:
		await physics_frame
		var delta := target - walker.global_position
		delta.y = 0
		if delta.length() < .16:
			return true
		walker.velocity = delta.normalized() * 5.0 + Vector3.DOWN * 3.0
		walker.move_and_slide()
		if walker.position.y < 1.6:
			push_error("Walkway gap at %s" % walker.position)
			return false
	push_error("Walking blocked at %s toward %s" % [walker.position, target])
	return false

func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(hub)
	for frame in 120:
		await physics_frame
	var link := hub.get_node("WatchtowerHarbourLink") as Node3D
	if link.find_child("PorchPost*", true, false) != null:
		push_error("Porch supports must not occupy the walking surface")
		quit(1)
		return
	var port := hub.get_node("Port") as Node3D
	var lane := AABB(Vector3(26, 1.9, 192.3), Vector3(10, 2.1, 1.4))
	for node in port.get_node("HarbourModel").find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not (mesh.name.begins_with("CargoCrate") or mesh.name.begins_with("Barrel")
				or mesh.name.begins_with("MooringRopeCoil")):
			continue
		if lane.intersects(mesh.global_transform * mesh.get_aabb()):
			push_error("Visible cargo blocks the tower approach: %s" % mesh.name)
			quit(1)
			return
	if link.find_children("HarbourCollision", "StaticBody3D", true, false).size() < 60:
		push_error("Blender collision metadata must import and bind")
		quit(1)
		return
	walker = Sailor.new()
	var collider := CollisionShape3D.new()
	collider.name = "CollisionShape3D"
	collider.shape = CapsuleShape3D.new()
	# Wider than the player's normal capsule: prove a continuous 1.4m lane.
	(collider.shape as CapsuleShape3D).radius = .7
	collider.position.y = 1.0
	walker.add_child(collider)
	root.add_child(walker)
	walker.position = Vector3(38, 1.85, 173.7)
	# Visit both inland-facing frontages, then return through the shore entrance.
	for point in [Vector3(43.4, 0, 173.7), Vector3(38, 0, 173.7),
			Vector3(26.5, 0, 173.7), Vector3(24, 0, 173.7),
			Vector3(38, 0, 173.7), Vector3(38, 0, 188.5)]:
		if not await _walk_to(point):
			quit(1)
			return
	# Main jetty -> connecting bridge -> tower porch -> full terrace circuit -> berth.
	var route: Array[Vector3] = [Vector3(38, 0, 193), Vector3(26.2, 0, 193),
		Vector3(24.4, 0, 194.5), Vector3(19.9201, 0, 196.6)]
	for degrees in [110, 135, 160, 185, 210, 235, 260, 285, 310, 335, 360, 385]:
		var angle := deg_to_rad(float(degrees))
		route.append(link.position + Vector3(cos(angle) * 6.35, 0, sin(angle) * 6.35))
	route.append(Vector3(32, 0, 193))
	for point in route:
		if not await _walk_to(point):
			quit(1)
			return
	# Reverse the same full circuit so the bridge/porch cannot be one-way traps.
	var reverse_route := route.duplicate()
	reverse_route.reverse()
	for point in reverse_route:
		if not await _walk_to(point):
			quit(1)
			return
	if not await _walk_to(Vector3(32, 0, 193)):
		quit(1)
		return
	# Approach the relocated boat from the seaward edge, not through the tower link.
	var boat := hub.get_node("Boat") as CharacterBody3D
	for frame in 90:
		await physics_frame
		if boat.call("is_boarded"):
			break
		walker.velocity = Vector3(0, -3, 3)
		walker.move_and_slide()
	if not boat.call("is_boarded"):
		push_error("Seaward berth must allow walking into the boarding trigger")
		quit(1)
		return
	boat.call("disembark")
	await physics_frame
	if boat.call("is_boarded") or walker.position.y < 1.7:
		push_error("Boat must disembark safely onto the connected harbour")
		quit(1)
		return
	# Push against the outer terrace rail to verify it really prevents walking off.
	walker.position = link.position + Vector3(0, 1.85, -6.35)
	for frame in 90:
		await physics_frame
		walker.velocity = Vector3(0, -3, -4)
		walker.move_and_slide()
	if walker.position.z < link.position.z - 7.7 or walker.position.y < 1.6:
		push_error("Terrace rail must retain the player")
		quit(1)
		return
	print("WATCHTOWER_HARBOUR_LINK: PASS — clear cargo lane, 1.4m bidirectional jetty/bridge/porch/terrace circuit, boarding/return, railings")
	quit()
