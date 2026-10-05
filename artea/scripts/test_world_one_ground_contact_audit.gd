extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 10:
		await physics_frame

	var per_island := {1: 0, 2: 0, 3: 0}
	for object in world.get_quest_objects():
		var island := int(object.get_meta("physical_island", 0))
		assert(island in per_island)
		per_island[island] += 1
		assert(object.has_node("GroundContactPlinth/IvoryContactShoe"))
		assert(object.has_node("GroundContactPlinth/CharcoalContactShadow"))
		assert(float(object.get_meta("ground_clearance_m", 1.0)) <= 0.0051)
		var excluded: Array[RID] = []
		for body_value in object.find_children("*", "CollisionObject3D", true, false):
			excluded.append((body_value as CollisionObject3D).get_rid())
		var parent := object.get_parent() as Node3D
		var probe := parent.to_global(object.get_meta("operator_approach_local"))
		var ray := PhysicsRayQueryParameters3D.create(
			probe + Vector3.UP * 0.25,
			probe + Vector3.DOWN * 0.50)
		ray.collision_mask = 1
		ray.exclude = excluded
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		assert(not hit.is_empty(), "%s has no final support beneath its visible base" % object.save_id)
		assert(absf(object.global_position.y - float((hit.position as Vector3).y)) <= 0.006,
			"%s does not match its support surface" % object.save_id)
	assert(per_island == {1: 5, 2: 5, 3: 5})

	var geometry := world.get_node("WorldOneGeometry") as Node3D
	for button in geometry.find_children("*GateControl*", "Node3D", true, false):
		assert(bool((button as Node3D).get_meta("ground_contact", false)))
		assert((button as Node3D).has_node("GroundedButtonPlinthCollision"))
	assert(geometry.find_children("*GateControl*", "Node3D", true, false).size() == 4)
	var environment_collision := geometry.get_node("ThreeIslandVisibleObjectCollisions") as StaticBody3D
	assert(int(environment_collision.get_meta("collision_shape_count", 0)) >= 500,
		"the wider Island 1–3 environment audit lost substantial grounded-object collision")

	print("WorldOneGroundContactAudit: PASS — 15 quest objects and 4 gate controls match physical ground across Islands 1–3")
	world.queue_free()
	await process_frame
	quit()
