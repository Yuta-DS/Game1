extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const PlayerScene := preload("res://scenes/player_3d.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 5:
		await physics_frame

	var compass := world.get_island_one_puzzle().get_node("CompassMachine") as Node3D
	assert(compass.get_node_or_null("CompassIvoryDais") == null)
	assert(compass.get_node_or_null("CompassIvoryDaisCollision") == null)
	assert(absf(compass.position.y + 1.8) < 0.01)

	var player := PlayerScene.instantiate() as CharacterBody3D
	root.add_child(player)
	player.set_physics_process(false)
	player.global_position = compass.to_global(Vector3(-21.0, 3.0, 8.0))
	await physics_frame
	var contact := player.move_and_collide(compass.global_transform.basis.x * 9.0, true)
	assert(contact == null, "the player must walk across the former raised platform edge")
	var floor_hit := world.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(player.global_position,
			player.global_position + Vector3.DOWN * 8.0))
	assert(not floor_hit.is_empty(), "the island floor must support the compass court")
	player.queue_free()

	var profile := world.find_child("IslandOneLightingProfile", true, false) as Node3D
	assert(profile != null, "World One must keep its shared three-island lighting profile")
	profile.call("_cache_scene_positions")
	var camera := Camera3D.new()
	root.add_child(camera)
	for zone_index in [0, 2, 4]:
		var zone: Dictionary = MindSparkWorldOne.ZONES[zone_index]
		camera.global_position = world.to_global(world.get_zone_position(str(zone.id))
			+ Vector3.UP * 5.0)
		assert(float(profile.call("_sample_target", camera)) > 0.9,
			"lighting must cover physical island %d" % int(zone.super_island))
	camera.queue_free()
	print("WorldOneCompassMassLighting: PASS — flush compass court and lighting covers all three islands")
	world.queue_free()
	await process_frame
	quit()
