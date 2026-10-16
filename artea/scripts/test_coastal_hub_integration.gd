extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(hub)
	for frame in 120:
		await physics_frame
	var port := hub.get_node("Port") as Node3D
	assert(port.get_node_or_null("HarbourModel") != null, "hub must resolve the new harbour, not the legacy pier UID")
	assert(port.call("creature_counts").fish == 23)
	var sign := port.find_child("HarbourSign", true, false) as Node3D
	var end := port.find_child("JettyPlank_17", true, false) as Node3D
	assert(sign.global_position.z < 180 and end.global_position.z > 190, "office faces the southern shore and jetty extends into sea")
	var tower := hub.get_node("building_tower_B_red2") as Node3D
	assert(port.global_position.distance_to(tower.global_position) < 22.0, "harbour is beside the sea watchtower")
	var water := hub.get_node("Environment/Water/MeshInstance3D") as MeshInstance3D
	assert(water.material_override.get_shader_parameter("harbour_clear_radius") == 20.0)
	var water_center: Vector2 = water.material_override.get_shader_parameter("harbour_center")
	assert(water_center.distance_to(Vector2(38, 188.5)) < 0.1, "clear-water pocket moves with the harbour")
	var boat := hub.get_node("Boat") as CharacterBody3D
	assert((-boat.global_basis.z).dot(Vector3.RIGHT) > 0.99, "boat faces east along its seaward berth")
	var berth := port.get_node("WalkableHarbour/BerthCollision") as CollisionShape3D
	assert(boat.global_position.distance_to(berth.global_position) < 6.0, "boat is alongside its real berth")
	var apron := port.find_child("ShoreApron", true, false) as MeshInstance3D
	assert(apron != null and apron.has_node("HarbourCollision"), "shore collision follows the Blender ramp")
	var terrain = hub.get_node("Environment/Terrain3D")
	var apron_bounds := apron.global_transform * apron.get_aabb()
	assert(apron_bounds.size.x > 25.0, "ramp serves the house, entrance and shop")
	for x in [24.0, 38.0, 46.0]:
		var ground: float = terrain.data.get_height(Vector3(x, 0, apron_bounds.position.z))
		assert(ground > 1.41 and ground < 1.95, "ramp toe is seated below the beach")
	# The moored hull has clearance from the watchtower and pier colliders.
	var boat_shape := boat.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = boat_shape.shape
	query.transform = boat_shape.global_transform
	query.collision_mask = boat.collision_mask
	query.exclude = [boat.get_rid()]
	assert(boat.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(), "moored boat must not intersect the watchtower or jetty")
	# The same wave clock/height must move the boat offshore, not an unrelated bob.
	var ocean := water.get_parent()
	ocean.set_process(false)
	boat.set_physics_process(false)
	var docked_position := boat.global_position
	var low := INF
	var high := -INF
	for point in [Vector3(38, 0, 197.4), Vector3(30, 0, 274), Vector3(-60, 0, 320)]:
		for t in range(0, 24, 2):
			ocean.set("wave_time", float(t))
			ocean.call("_process", 0.0)
			boat.global_position = point
			boat.call("_physics_process", 0.0)
			var expected_height: float = ocean.call("get_water_height", point)
			assert(absf(boat.global_position.y - expected_height - .17) < .001, "boat floats on the rendered wave field")
			low = minf(low, boat.global_position.y)
			high = maxf(high, boat.global_position.y)
	assert(high - low > .25, "boat responds to changing open-water swells")
	boat.global_position = docked_position
	print("COASTAL_HUB_INTEGRATION: PASS — correct harbour scene, shore/sea orientation, berth placement and clear-water binding")
	quit()
