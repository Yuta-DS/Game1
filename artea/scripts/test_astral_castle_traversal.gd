extends "res://scripts/test_mind_spark_zone02_route_clearance.gd"


func _fail(message: String) -> void:
	push_error("ASTRAL_CASTLE_TRAVERSAL: " + message)
	quit(1)


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://test_astral_v13_traversal.json"
	root.add_child(world)
	var player := PlayerScene.instantiate() as CharacterBody3D
	root.add_child(player)
	for _frame in 8:
		await physics_frame
	player.set_physics_process(false)
	var zone := world.get_zone_position("03_constellation_court")
	var radius := world.get_zone_radius("03_constellation_court")
	var zone_global := world.to_global(zone)
	var capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	var stand_height := capsule.height*.5+.18
	for route_name in ["CircuitRoute_02_B", "CircuitRoute_03_A"]:
		var approach := world.get_node("WorldOneGeometry/MainStoryCircuitRoute/" + route_name) as MeshInstance3D
		var mesh := approach.mesh as BoxMesh
		var endpoint_a := approach.to_global(Vector3(0,0,-mesh.size.z*.5))
		var endpoint_b := approach.to_global(Vector3(0,0,mesh.size.z*.5))
		var near_sign := -1.0 if endpoint_a.distance_to(zone_global) < endpoint_b.distance_to(zone_global) else 1.0
		var spawn := approach.to_global(Vector3(0,mesh.size.y*.5+stand_height,near_sign*(mesh.size.z*.5-minf(15.0,mesh.size.z*.35))))
		if not await _settle(player,spawn):
			_fail("production capsule cannot stand on " + route_name)
			return
		var outward := Vector3(spawn.x-zone_global.x,0,spawn.z-zone_global.z).normalized()
		var destination := zone_global+outward*(radius-16.0)+Vector3.UP*(stand_height+.4)
		if route_name == "CircuitRoute_02_B":
			# This approach has an authored quest barrier 7 m inside the rim.
			# Exercise both fixture states without removing the gate or changing
			# quest rules. Full quest progression remains a separate story test.
			world.set_quest_gate_open(1, false)
			for _frame in 2:
				await physics_frame
			if await _walk(player,destination) or not _collider_labels(player).contains("QuestGate_2"):
				_fail("locked quest gate must still block the approach")
				return
			world.set_quest_gate_open(1, true)
			for _frame in 2:
				await physics_frame
			if not world.is_quest_gate_open(1) or not await _settle(player,spawn):
				_fail("could not prepare the existing open-gate traversal state")
				return
		if not await _walk(player,destination):
			_fail("blocked on %s at %s: %s" % [route_name,player.global_position,_collider_labels(player)])
			return
	print("ASTRAL_CASTLE_TRAVERSAL: PASS — locked gate blocks; production capsule walked both approaches with the saved-path gate open")
	world.queue_free()
	player.queue_free()
	await process_frame
	quit()
