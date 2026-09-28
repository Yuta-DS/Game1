extends SceneTree

# A continuous production-capsule route through Island Three. Unlike landing
# probes, this detects seams and invisible blockers between quest operators.
const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const PlayerScene := preload("res://scenes/player_3d.tscn")
const STATE_PATH := "user://test_island_three_walk.json"
const WALK_SPEED := 14.0
const GRAVITY := 28.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STATE_PATH
	root.add_child(world)
	for _frame in 5:
		await physics_frame
	var player := PlayerScene.instantiate() as CharacterBody3D
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process_input(false)
	var arena: Vector3 = MindSparkWorldOne.ZONES[4].position
	var positions := {}
	for object in world.get_quest_objects():
		if int(object.get_meta("physical_island", 0)) != 3:
			continue
		var approach: Vector3 = object.get_meta("operator_approach_local")
		positions[object.save_id] = (object.get_parent() as Node3D).to_global(approach)
	player.global_position = world.to_global(arena + Vector3(-135, 4, 0))
	player.velocity = Vector3.ZERO
	if not await _land(player):
		_fail("bridge arrival has no supporting floor")
		return
	var route := [
		["arrival axis", world.to_global(arena + Vector3(-110, 0, 0))],
		["lens approach", positions["world_one.warden_anchor.1"]],
		["west court", world.to_global(arena + Vector3(-64, 0, -12))],
		["west garden bypass", world.to_global(arena + Vector3(-80, 0, -82))],
		["north court", world.to_global(arena + Vector3(-14, 0, -82))],
		["forge outer flank", world.to_global(arena + Vector3(-30, 0, -130))],
		["forge approach", positions["world_one.warden_anchor.2"]],
		["east court", world.to_global(arena + Vector3(80, 0, -83))],
		["archive outer flank", world.to_global(arena + Vector3(120, 0, 10))],
		["archive approach", positions["world_one.warden_anchor.3"]],
		["archive garden egress", world.to_global(arena + Vector3(120, 0, 85))],
		["south court", world.to_global(arena + Vector3(65, 0, 55))],
		["rain lane", world.to_global(arena + Vector3(0, 0, 55))],
		["rain approach", positions["world_one.calm_rain_basin"]],
		["court return", world.to_global(arena + Vector3(38, 0, 35))],
		["promenade entry", world.to_global(arena + Vector3(65, 0, -8))],
		["promenade middle", world.to_global(arena + Vector3(112, 0, -31))],
		["reflection approach", positions["world_one.identity_reflection"]],
	]
	for stop in route:
		if not await _walk_to(player, stop[1], stop[0]):
			return
	print("MindSparkIslandThreeWalk: PASS — arrival, all five quest operators and tree promenade continuously traversed")
	player.queue_free()
	world.queue_free()
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)
	quit()


func _land(player: CharacterBody3D) -> bool:
	for _frame in 120:
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			return true
	return false


func _walk_to(player: CharacterBody3D, target: Vector3, label: String) -> bool:
	var best_distance := _flat_distance(player.global_position, target)
	var stalled_frames := 0
	var airborne_frames := 0
	for _frame in 1000:
		var offset := target - player.global_position
		offset.y = 0
		if offset.length() < 2.0:
			if not player.is_on_floor():
				return _fail("%s reached while airborne at %s" % [label, str(player.global_position)])
			return true
		var heading := offset.normalized()
		player.velocity.x = heading.x * WALK_SPEED
		player.velocity.z = heading.z * WALK_SPEED
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		if player.is_on_floor():
			airborne_frames = 0
		else:
			airborne_frames += 1
		if airborne_frames > 8:
			return _fail("%s has a floor gap near %s" % [label, str(player.global_position)])
		var distance := _flat_distance(player.global_position, target)
		if distance < best_distance - .02:
			best_distance = distance
			stalled_frames = 0
		else:
			stalled_frames += 1
		if stalled_frames > 90:
			var obstruction := ""
			for collision_index in player.get_slide_collision_count():
				var collision := player.get_slide_collision(collision_index)
				obstruction += "%s normal=%s; " % [
					str((collision.get_collider() as Node).get_path()),
					str(collision.get_normal())]
			return _fail("%s blocked near %s by %s target=%s" % [
				label, str(player.global_position), obstruction, str(target)])
		await physics_frame
	return _fail("%s timed out near %s target=%s" % [label,
		str(player.global_position), str(target)])


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _fail(message: String) -> bool:
	push_error("MindSparkIslandThreeWalk: " + message)
	quit(1)
	return false
