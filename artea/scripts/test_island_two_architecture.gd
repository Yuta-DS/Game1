extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.get_node("QuestController").enabled = false
	root.add_child(world)
	for i in 8: await physics_frame
	var gate := world.get_node("WorldOneGeometry/SavedQuestProgressionGates/QuestGate_3") as Node3D
	var center := world.get_zone_position("04_hope_path_ridge")
	assert(is_equal_approx(Vector2(gate.position.x-center.x, gate.position.z-center.z).length(), 100.0))
	var portal := gate.get_node("IslandTwoMemoryGate") as Node3D
	world.set_quest_gate_open(2, false)
	await create_timer(2.5).timeout
	assert(portal.get_meta("gate_state") == "sealed")
	world.set_quest_gate_open(2, true)
	await create_timer(2.5).timeout
	assert(portal.get_meta("gate_state") == "open", str(portal.get_meta("last_obstruction", "departure blocked")))
	world.set_quest_gate_open(2, false)
	await create_timer(2.5).timeout
	assert(portal.get_meta("gate_state") == "sealed")
	var physics := world.get_world_3d().direct_space_state
	# Bridge traversal is tested only after the preceding quest gate is unlocked.
	world.set_quest_gate_open(0, true)
	for i in 3: await physics_frame
	var repairs := world.get_node("WorldOneGeometry/IslandTwoPerimeterRepairs")
	assert(repairs.find_children("ReferenceScrollwork*", "Node3D", false, false).size() > 20)
	var checked := 0
	for zone_index in [2, 3]:
		var zone: Dictionary = world.ZONES[zone_index]
		for segment in 144:
			var angle := TAU * (segment + .5) / 144.0
			if not world.call("_is_exposed_garden_edge", zone_index, angle): continue
			var radial := Vector3(sin(angle), 0, cos(angle))
			var at: Vector3 = zone.position + radial * float(zone.radius) * .985
			at.y = world.call("_zone_floor_surface_y", zone.position)
			at.y += 4
			var hit := physics.intersect_ray(PhysicsRayQueryParameters3D.create(at-radial*2, at+radial*2, 1))
			assert(not hit.is_empty(), "Unprotected edge %d/%d" % [zone_index, segment])
			checked += 1
	var fittings := world.get_node("WorldOneGeometry/IslandTwoBridgeFittings")
	assert(fittings.get_child_count() == 4)
	assert(str(fittings.get_meta("design_revision", "")) \
			== "continuous_ivory_parapet_v3"
			and bool(fittings.get_meta("duplicate_joint_piers_removed", false))
			and bool(fittings.get_meta("gold_route_handrails_removed", false))
			and bool(fittings.get_meta("bridge_joint_sightline_clear", false))
			and bool(fittings.get_meta("detached_bridge_ornaments_removed", false))
			and int(fittings.get_meta("decorative_lantern_count", -1)) == 0
			and bool(fittings.get_meta(
				"island_three_arrival_uses_authored_solid_rails", false)),
		"external bridges use continuous ivory parapets without detached ornaments")
	for assembly in fittings.get_children():
		assert(assembly.find_children("BrassHandrail*", "MeshInstance3D", true, false).is_empty(),
			"external bridges must not restore long gold handrails")
		if bool(assembly.get_meta("arrival_sightline_clear", false)):
			assert(assembly.name == "CircuitRoute_04_BCivicBalustrade"
					and assembly.find_children("*", "MeshInstance3D", true, false).is_empty(),
				"the short Island 3 threshold must use only its authored solid rails")
			continue
		assert(assembly.find_children("IvoryHandrail*", "MeshInstance3D", true, false).size() == 2,
			"each bridge half needs two finished ivory handrails")
		assert(assembly.find_children("IvoryParapet*", "MeshInstance3D", true, false).size() == 2
				and assembly.find_children("IvoryParapet*Collision", "StaticBody3D", true, false).size() == 2,
			"each bridge half needs two visible collision-backed ivory parapets")
		assert(assembly.find_children("TealInfill*", "MeshInstance3D", true, false).is_empty()
				and assembly.find_children("Pier*", "MeshInstance3D", true, false).is_empty()
				and assembly.find_children("Lantern*", "MeshInstance3D", true, false).is_empty(),
			"bridge edges must not restore translucent infill or repeated detached ornaments")
	var story_route := world.get_node("WorldOneGeometry/MainStoryCircuitRoute") as Node3D
	assert(story_route.has_node("CircuitRoute_04_BLeftRailCollision")
			and story_route.has_node("CircuitRoute_04_BRightRailCollision"),
		"the clean Island 3 arrival still has two visible collision-backed authored rails")
	var actor := load("res://scenes/player_3d.tscn").instantiate() as CharacterBody3D
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.global_position = Vector3(0, 2000, 0)
	await physics_frame
	for assembly in fittings.get_children():
		var rail_height := 2.0 if bool(assembly.get_meta("arrival_sightline_clear", false)) else 4.3
		for side in [-1, 1]:
			var start: Vector3 = assembly.to_global(Vector3(side * 11, rail_height, 0))
			var finish: Vector3 = assembly.to_global(Vector3(side * 15, rail_height, 0))
			assert(not physics.intersect_ray(PhysicsRayQueryParameters3D.create(start, finish, 1)).is_empty())
			actor.global_position = assembly.to_global(Vector3(side * 10, rail_height, 0))
			var contact := actor.move_and_collide(assembly.global_basis.x * side * 6)
			assert(contact != null, "Player passed through bridge parapet")
		actor.global_position = assembly.to_global(Vector3(0, 2.3, -4))
		var obstruction := actor.move_and_collide(assembly.global_basis.z * 8)
		assert(obstruction == null,
			"Player capsule blocked on %s: %s" % [assembly.name, str(obstruction.get_collider().get_path()) if obstruction else "clear"])
	actor.queue_free()
	print("ISLAND_TWO_ARCHITECTURE: PASS — departure gate opens/closes on landing; %d perimeter samples protected; four bridge halves have physical infill" % checked)
	world.queue_free()
	await process_frame
	quit()
