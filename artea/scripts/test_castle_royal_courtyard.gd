extends "res://scripts/test_castle_rooftop_barrier_safety.gd"

const Court := preload("res://scripts/castle_royal_courtyard.gd")


func _fail(message: String) -> void:
	push_error("ROYAL_COURTYARD_TEST: " + message)
	quit(1)


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process_input(false)
	player.global_position = Court.CENTER + Vector3(2, 2, 2)
	for frame in 80:
		await process_frame
		await physics_frame
	var entrance := hub.get_node("CastleEntrance/CastleEntrance")
	var floor_mesh := entrance.get_node("CastleArrivalTerrace") as MeshInstance3D
	var floor_bounds := floor_mesh.global_transform * floor_mesh.mesh.get_aabb()
	var underside := entrance.get_node("CastleArrivalUnderside") as MeshInstance3D
	var underside_bounds := underside.global_transform * underside.mesh.get_aabb()
	if underside_bounds.end.y > floor_bounds.position.y + 0.002:
		_fail("visual foundation protrudes above the walking floor")
		return
	if absf(floor_bounds.end.y - Court.FLOOR_Y) > 0.001 or entrance.has_node("CastleBridgeReceivingCourt"):
		_fail("raised receiving overlay remains or floor has the wrong top")
		return
	var pedestal := entrance.get_node("CastleCourtyardFire/CourtyardFirePedestal") as MeshInstance3D
	var fire_bounds := pedestal.global_transform * pedestal.mesh.get_aabb()
	if absf(fire_bounds.position.y - Court.FLOOR_Y) > 0.002 \
			or Vector2(pedestal.global_position.x - Court.CENTER.x, pedestal.global_position.z - Court.CENTER.z).length() > 0.002:
		_fail("fire is not grounded at the centre of the inlaid flower")
		return
	var gate := hub.find_child("CastleBridgeBarbican", true, false) as Node3D
	var towers := gate.find_children("BarbicanTower*", "MeshInstance3D", true, false)
	if towers.size() != 2 or absf(float(gate.get_meta("clear_opening_width")) - 10.6) > 0.001:
		_fail("wide paired gate is missing")
		return
	for tower: MeshInstance3D in towers:
		var bounds := tower.global_transform * tower.mesh.get_aabb()
		var outer_z := maxf(absf(bounds.position.z - Court.CENTER.z), absf(bounds.end.z - Court.CENTER.z))
		if absf(outer_z - 7.5) > 0.002:
			_fail("gate tower does not align with the perimeter barrier")
			return
	var space := player.get_world_3d().direct_space_state
	var probes := 0
	for x: float in [-27.2, -26.0, -24.5, -22.0, -20.0, -18.3, -18.1]:
		for z: float in [-3.8, -2.0, 2.0, 3.8]:
			var point := Vector3(x, Court.FLOOR_Y, Court.CENTER.z + z)
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.25, point - Vector3.UP)
			query.exclude = [player.get_rid()]
			var hit := space.intersect_ray(query)
			if hit.is_empty() or absf(hit.position.y - floor_bounds.end.y) > 0.004:
				_fail("floor/collider mismatch at %s: %s" % [point, hit])
				return
			probes += 1
	# Real player controller stepping, with four usable lanes through the gate.
	for z: float in [-4.0, -2.0, 2.0, 4.0]:
		if not await _settle(player, Vector3(-18.5, Court.FLOOR_Y + 2, Court.CENTER.z + z)):
			_fail("cannot settle in gate lane")
			return
		for x: float in [-27.1, -18.5]:
			if not await _walk_to(player, Vector3(x, Court.FLOOR_Y, Court.CENTER.z + z)) \
					or absf(player.global_position.y - Court.FLOOR_Y) > 0.07:
				_fail("gate/court traversal stuck or feet sunk: %s" % player.global_position)
				return
	if not await _settle(player, Court.CENTER + Vector3(2.2, 2, 0)):
		_fail("cannot stand beside centred fire")
		return
	for i in range(1, 17):
		var angle := TAU * float(i) / 16.0
		if not await _walk_to(player, Court.CENTER + Vector3(cos(angle), 0, sin(angle)) * 2.2):
			_fail("fire prevents a full walk around its base")
			return
	# Both directions across every new ceremonial riser.
	for z: float in [-2.0, 2.0]:
		await _settle(player, Vector3(-27.0, Court.FLOOR_Y + 2, Court.CENTER.z + z))
		for x: float in [-31.1, -27.0]:
			if not await _walk_to(player, Vector3(x, Court.FLOOR_Y, Court.CENTER.z + z)):
				_fail("stair-foot or tread seam trapped the player at %s" % player.global_position)
				return
	# Sprint into closed edge walls and move away without clipping or sticking.
	for side: float in [-1.0, 1.0]:
		for x: float in [-26.7, -26.0, -21.4]:
			var start := Vector3(x, Court.FLOOR_Y + 2, Court.CENTER.z + side * 5.5)
			await _settle(player, start)
			if absf(player.global_position.y - Court.FLOOR_Y) > 0.07:
				_fail("barrier test must start on the floor, not on a return wall")
				return
			await _run_direction(player, Vector3(0, 0, side), 24)
			if absf(player.global_position.z - Court.CENTER.z) > 6.91 or player.global_position.y < Court.FLOOR_Y - 0.07:
				_fail("player crossed or fell through the side barrier: x=%s side=%s position=%s" % [x, side, player.global_position])
				return
			if not await _walk_to(player, start):
				_fail("player stuck after hitting a side barrier")
				return
	# Jump, land, and check feet on the actual visible surface.
	await _settle(player, Court.CENTER + Vector3(2.4, 2, 2.0))
	player.velocity = Vector3(0, 8.0, 0)
	for i in 90:
		player.velocity.y -= GRAVITY_PER_FRAME
		player.move_and_slide()
		await physics_frame
	if not player.is_on_floor() or absf(player.global_position.y - Court.FLOOR_Y) > 0.07:
		_fail("jump landing does not finish on the visible paving")
		return
	print("ROYAL_COURTYARD_TEST: PASS — %d floor probes; 4 gate lanes both ways; full fire circuit; stairs up/down; 6 wall impacts/escapes; jump landing" % probes)
	quit(0)
