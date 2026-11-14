extends "res://scripts/test_mind_spark_zone02_route_clearance.gd"


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://test_dawn_v17.json"
	root.add_child(world)
	var player := PlayerScene.instantiate() as CharacterBody3D
	root.add_child(player)
	for _frame in 8:
		await physics_frame
	player.set_physics_process(false)
	var zone := world.get_node("WorldOneGeometry/" + "04_hope_path_ridge".to_pascal_case()) as Node3D
	assert(zone != null)
	var foundation := zone.get_node("ModularFloatingFoundation") as Node3D
	var guard := zone.get_node("DawnPerimeterBarrier") as StaticBody3D
	assert(guard != null and guard.get_child_count() > 100)
	var centre := world.get_zone_position("04_hope_path_ridge")
	var capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	for angle in [deg_to_rad(60.0), deg_to_rad(120.0), deg_to_rad(180.0), deg_to_rad(270.0)]:
		var outward := Vector3(cos(angle), 0, sin(angle))
		assert(await _settle(player, centre + outward * 116.0 + Vector3.UP * (capsule.height * 0.5 + 0.18)))
		var hit_guard := false
		for _frame in 100:
			player.velocity = outward * 7.0 + Vector3.DOWN * 0.5
			player.move_and_slide()
			await physics_frame
			for collision_index in player.get_slide_collision_count():
				hit_guard = hit_guard or player.get_slide_collision(collision_index).get_collider() == guard
		assert(hit_guard, "Player must collide with the visible Dawn guard")
		assert(Vector2(player.position.x-centre.x, player.position.z-centre.z).length() < 119.2)
		assert(player.is_on_floor(), "Guard must stop player before the floor ends")
	var controller := foundation.get_node("DawnViaductController")
	var upper_district := zone.get_node("CelestialHopeUpperDistrict") as Node3D
	assert(upper_district != null)
	assert(upper_district.get_meta("above_ground_revision", "") == "v18")
	var pavilion := upper_district.get_node("AetherLiftPavilion") as Node3D
	assert(pavilion != null)
	assert(pavilion.find_children("PavilionIvoryColumn_*", "MeshInstance3D", true, false).size() == 8)
	assert(pavilion.find_children("TruthPortal_*", "MeshInstance3D", true, false).size() == 3)
	var condensers := upper_district.get_node("TwinUpperPressureCondenserHouses") as Node3D
	assert(condensers.find_children("*UpperCondenserIvoryDrum", "MeshInstance3D", true, false).size() == 2)
	assert(upper_district.get_node("CurvedSunriseGardenTerraces") != null)
	controller.set_process(false)
	var wheel := foundation.find_child("WestSunFlywheel", true, false) as Node3D
	var pinion := foundation.find_child("WestLiftPinion", true, false) as Node3D
	if wheel == null:
		wheel = foundation.find_child("WestSunFlywheel_v17", true, false) as Node3D
		pinion = foundation.find_child("WestLiftPinion_v17", true, false) as Node3D
	var initial := wheel.rotation.x
	controller.advance(0.2)
	assert(not is_equal_approx(wheel.rotation.x, initial))
	assert(is_equal_approx(pinion.rotation.x, -wheel.rotation.x * 20.0 / 12.0))
	player.queue_free()
	world.queue_free()
	await process_frame
	var district_host := Node3D.new()
	district_host.name = "ArtCastleFloatingWorld"
	root.add_child(district_host)
	var district_world := WorldScene.instantiate() as MindSparkWorldOne
	district_world.build_hud = false
	district_world.object_state_store_path = "user://test_dawn_v17_district.json"
	district_host.add_child(district_world)
	for _frame in 8:
		await process_frame
	var course := district_world.find_child("HopePathPhysicalTraversal", true, false) as Node3D
	assert(course != null)
	for index in 4:
		assert(course.get_node_or_null("JumpableDataBlock_%02dCollision" % (index + 1)) is StaticBody3D)
	assert(course.find_child("AccessibleWalkLaneCollision", true, false) != null)
	print("DAWN_V18: PASS — upper pavilion, truth portals, condenser houses and gardens built; real guard, gears, jump course and accessible lane retained")
	quit()
