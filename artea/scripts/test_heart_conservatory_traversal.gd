extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/art_castle_floating_world.tscn") as PackedScene
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	for _frame in 3:
		await process_frame
	await physics_frame

	var heart := world.get_node("HeartMelodyTemple") as Node3D
	var conservatory := heart.get_node("HeartMelodyCelestialConservatory") as Node3D
	var entrance := conservatory.get_node("GrandResonanceEntrance") as Node3D
	var bays := conservatory.get_node("SixResonanceBays") as Node3D
	if float(entrance.get_meta("principal_route_width_m", 0.0)) < 18.0:
		_fail("the pavilion does not preserve the 18 metre principal aisle")
		return

	# Player-height probes cover the Tree approach, pavilion, both gardens and
	# every hall frontage. All use production collision layer 1.
	var local_points: Array[Vector3] = [
		Vector3(0, 0, -62), Vector3(0, 0, -42), Vector3(0, 0, -18),
		Vector3(0, 0, 8), Vector3(-73, 0, -32), Vector3(73, 0, -32),
		Vector3(-96, 0, 4), Vector3(96, 0, 4),
	]
	for hall_x in [-111.0, -79.0, -50.0, 50.0, 80.0, 112.0]:
		local_points.append(Vector3(hall_x, 0, -18))
	var space := world.get_world_3d().direct_space_state
	for local_point in local_points:
		var point := conservatory.to_global(local_point)
		var query := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * 24.0, point + Vector3.DOWN * 28.0, 1)
		if space.intersect_ray(query).is_empty():
			_fail("the conservatory route has no supporting collision at %s" % local_point)
			return

	if bays.find_children("HallCollisionCollision", "StaticBody3D", true, false).size() != 6:
		_fail("not every instrument hall blocks the production player capsule")
		return
	if heart.find_children("LivingEdgeRock_*", "MeshInstance3D", true, false).size() != 19 \
			or heart.find_children("LivingEdgeCollision_*", "StaticBody3D", true, false).size() != 19:
		_fail("the planted platform boundary is not collision-backed")
		return
	print("HEART_CONSERVATORY_TRAVERSAL: PASS — approach, pavilion, gardens and six halls are supported")
	quit()


func _fail(message: String) -> void:
	push_error("HEART_CONSERVATORY_TRAVERSAL: %s" % message)
	quit(1)
