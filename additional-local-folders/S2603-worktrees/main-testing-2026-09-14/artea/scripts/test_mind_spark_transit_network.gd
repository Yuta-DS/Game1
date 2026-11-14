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
	var network := world.get_node("WorldOneGeometry/MindSparkTransitNetwork") as Node3D
	var portals := world.get_transit_portals()
	assert(portals.size() == 6, "each of the six islands needs one shortcut portal")
	assert(int(network.get_meta("physical_bridge_degree_per_island")) == 2,
		"portal travel must complement the two walkable bridges on each island")
	assert(PackedStringArray(network.get_meta("reciprocal_pairs")).size() == 3)

	for portal in portals:
		assert(not portal.gate_enabled,
			"fast travel must remain locked while the story world is unrestored")
		var reciprocal_name := str(portal.get_meta("reciprocal_portal"))
		var reciprocal := network.get_node(reciprocal_name) as MindSparkWorldGate
		assert(reciprocal.get_meta("reciprocal_portal") == portal.name)
		assert(reciprocal.get_meta("source_zone_id") == portal.get_meta("destination_zone_id"))
		assert(reciprocal.get_meta("destination_zone_id") == portal.get_meta("source_zone_id"))
		var destination_id := str(portal.get_meta("destination_zone_id"))
		var arrival: Vector3 = portal.get_meta("arrival_world_one_local")
		var destination_center := world.get_zone_position(destination_id)
		assert(Vector2(arrival.x, arrival.z).distance_to(
			Vector2(destination_center.x, destination_center.z)) < world.get_zone_radius(destination_id),
			"portal arrival must be safely inside its destination island")
		assert(is_equal_approx(arrival.y, destination_center.y + 7.0))

	world.set_world_state("gentle_rain")
	for portal in portals:
		assert(portal.gate_enabled, "restoring MindSpark must enable every transit portal")

	var player := floating_world.get_node("Player3D") as CharacterBody3D
	assert(player.get_node_or_null("FoxVisuals/Fox") != null)
	var test_portal := network.get_node("Transit_01_to_04") as MindSparkWorldGate
	assert(test_portal.teleport_player(player), "the production player must use the transit portal")
	var expected_global := floating_world.to_global(test_portal.destination_world_local)
	assert(player.global_position.is_equal_approx(expected_global),
		"portal must deliver the fox to its exact safe island landing")
	assert(player.velocity == Vector3.ZERO)
	print("MindSparkTransitNetwork: PASS — 6 islands retain bridge ring and gain 3 reciprocal restored-world shortcuts")
	quit()
