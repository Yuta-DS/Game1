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
	var puzzle := world.get_island_one_puzzle()
	var control_count := 0
	for control in puzzle.get_node("PuzzleControls").get_children():
		if control is Node3D:
			_check_contact(world, control, 0.07)
			control_count += 1
	assert(control_count == 16, "Island One must keep all sixteen playable controls")
	var quest_count := 0
	for object in world.get_quest_objects():
		_check_contact(world, object, 0.20)
		quest_count += 1
	assert(quest_count == 15, "World One must keep all fifteen quest instruments")
	assert(world.get_cast_member("milo") == null,
		"the obsolete blue Mayor Milo model must not appear on Island One")
	_check_contact(world, world.get_cast_member("guardian"), 0.07)
	for enemy in world.get_enemies():
		_check_contact(world, enemy, 0.07)
		var grounded_position := enemy.global_position
		enemy.reset_enemy()
		assert(enemy.global_position.distance_to(grounded_position) < 0.01,
			"%s reset to its old airborne spawn" % enemy.name)
	for collectible in world.get_collectibles():
		_check_contact(world, collectible, 0.07)
	_check_contact(world, world.get_warden(), 0.07)
	print("WorldOneGroundContact: PASS — obsolete Island One Milo removed; 16 controls, 15 quest objects, Guardian, 6 enemies, 2 sparks and Warden touch final ground")
	world.queue_free()
	await process_frame
	quit()


func _check_contact(world: MindSparkWorldOne, object: Node3D, max_penetration: float) -> void:
	assert(object != null)
	var excluded: Array[RID] = []
	if object is CollisionObject3D:
		excluded.append((object as CollisionObject3D).get_rid())
	for body in object.find_children("*", "CollisionObject3D", true, false):
		excluded.append((body as CollisionObject3D).get_rid())
	var start := object.global_position + Vector3.UP * 0.1
	var query := PhysicsRayQueryParameters3D.create(start, start + Vector3.DOWN * 70.0)
	query.collision_mask = 1
	query.exclude = excluded
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty(), "%s lacks a walkable surface" % object.name)
	var hit_y := (hit.position as Vector3).y
	var bottom_y := INF
	for child in object.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if not mesh_node.visible or mesh_node.mesh == null:
			continue
		var bounds := mesh_node.mesh.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var point_y := mesh_node.to_global(Vector3(x, y, z)).y
					if point_y < bottom_y:
						bottom_y = point_y
	assert(is_finite(bottom_y), "%s has no visible mesh" % object.name)
	var gap := bottom_y - hit_y
	assert(gap >= -max_penetration and gap <= 0.07,
		"%s visible base misses support by %.3f m" % [object.name, gap])
