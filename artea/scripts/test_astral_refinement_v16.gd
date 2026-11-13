extends "res://scripts/test_mind_spark_zone02_route_clearance.gd"


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud=false
	world.object_state_store_path="user://test_astral_v16.json"
	root.add_child(world)
	var player := PlayerScene.instantiate() as CharacterBody3D
	root.add_child(player)
	for _frame in 8:
		await physics_frame
	player.set_physics_process(false)
	var zone := world.get_node("WorldOneGeometry/" + "03_constellation_court".to_pascal_case()) as Node3D
	# Use the actual zone mapping rather than a scene-name assumption.
	if zone == null:
		_fail("Astral zone missing")
		return
	var foundation := zone.get_node("ModularFloatingFoundation") as Node3D
	assert(zone.get_node_or_null("AstralPerimeterBarrier") == null,
		"The retired invisible guard must not cover the current bridge")
	var guard := world.get_node("WorldOneGeometry/IslandTwoPerimeterRepairs") as Node3D
	assert(guard.find_children("RepairedBay_2_*Collision", "StaticBody3D", false, false).size() > 80)
	var centre := world.get_zone_position("03_constellation_court")
	var capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	for angle in [PI/2.0]:
		var outward := Vector3(cos(angle),0,sin(angle))
		assert(await _settle(player,centre+outward*140+Vector3.UP*(capsule.height*.5+.18)))
		var hit_guard := false
		for _frame in 100:
			player.velocity=outward*7+Vector3.DOWN*.5
			player.move_and_slide()
			await physics_frame
			for i in player.get_slide_collision_count():
				var collider := player.get_slide_collision(i).get_collider() as Node
				hit_guard = hit_guard or (collider != null and collider.get_parent() == guard)
		assert(hit_guard,"Player must collide with visible perimeter masonry")
		assert(Vector2(player.position.x-centre.x,player.position.z-centre.z).length()<150.0)
		assert(player.is_on_floor(),"Guard must stop player before floor ends")
	var controller := foundation.get_node("AstralMechanismController")
	controller.set_process(false)
	var wheel := foundation.find_child("WestFlywheel_v16",true,false) as Node3D
	var pinion := foundation.find_child("WestPinion_v16",true,false) as Node3D
	var rod := foundation.find_child("WestConnectingRod_v16",true,false) as Node3D
	var initial := wheel.rotation.x
	controller.advance(.2)
	assert(not is_equal_approx(wheel.rotation.x,initial))
	assert(is_equal_approx(pinion.rotation.x,-wheel.rotation.x*20.0/12.0))
	for _i in 90:
		controller.advance(.1)
		var crank := Vector3(-.88,-1.26+.055*cos(wheel.rotation.x),-.04+.055*sin(wheel.rotation.x))
		var slider := (foundation.find_child("WestCrosshead_v16",true,false) as Node3D).position
		assert(absf(crank.distance_to(slider)-.205)<.00001)
		assert(rod.position.distance_to((crank+slider)*.5)<.00001)
	# Batching may not free live combat handles or editable/animated tree nodes.
	for enemy in world.find_children("*","MindSparkEnemyBase",true,false):
		assert(is_instance_valid(enemy.core) and is_instance_valid(enemy.shell))
	print("ASTRAL_V16: PASS — visible perimeter masonry stops the capsule; duplicate guard absent; 20:12 gears and rod verified")
	quit()
