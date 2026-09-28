extends SceneTree

# Walk both World One sky bridges with the production player capsule. Scene
# hierarchy assertions cannot reveal a lip, gap, or hidden blocker at a seam.
const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const PlayerScene := preload("res://scenes/player_3d.tscn")
const STATE_PATH := "user://test_external_bridge_walk.json"
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
	for link_index in [1, 3]:
		if not await _walk_bridge(world, player, link_index):
			return
	print("MindSparkExternalBridgeWalk: PASS — production player walked both sky bridges without a jump")
	player.queue_free()
	world.queue_free()
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)
	quit()


func _walk_bridge(world: MindSparkWorldOne, player: CharacterBody3D,
		start_index: int) -> bool:
	var source: Dictionary = MindSparkWorldOne.ZONES[start_index]
	var destination: Dictionary = MindSparkWorldOne.ZONES[start_index + 1]
	var source_center: Vector3 = source.position
	var destination_center: Vector3 = destination.position
	var direction := destination_center - source_center
	direction.y = 0.0
	direction = direction.normalized()
	# Include the Island One garden approach; starting at the lip alone missed
	# blockers that a player meets before stepping onto the first sky bridge.
	var start_distance := float(source.radius) - (45.0 if start_index == 1 else 3.5)
	var start := source_center + direction * start_distance
	var finish := destination_center - direction * (float(destination.radius) - 3.5)
	var start_global := world.to_global(start)
	var finish_global := world.to_global(finish)
	player.global_position = start_global + Vector3.UP * 2.5
	player.velocity = Vector3.ZERO
	var grounded := false
	for _frame in 90:
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			grounded = true
			break
	if not grounded:
		return _fail("bridge %d entrance did not support the player" % (start_index + 1))
	var best_distance := _flat_distance(player.global_position, finish_global)
	var stalled_frames := 0
	var airborne_frames := 0
	for _frame in 1200:
		var offset := finish_global - player.global_position
		offset.y = 0.0
		if offset.length() < 1.5:
			if not player.is_on_floor():
				return _fail("bridge %d exit left the player airborne" % (start_index + 1))
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
		if airborne_frames > 6:
			return _fail("bridge %d has a floor gap near %s" % [start_index + 1,
				str(player.global_position)])
		var distance := _flat_distance(player.global_position, finish_global)
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
			return _fail("bridge %d blocked near %s by %s; velocity=%s floor=%s target=%s" % [
				start_index + 1, str(player.global_position), obstruction,
				str(player.velocity), str(player.is_on_floor()), str(finish_global)])
		await physics_frame
	return _fail("bridge %d did not reach its destination" % (start_index + 1))


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _fail(message: String) -> bool:
	push_error("MindSparkExternalBridgeWalk: " + message)
	quit(1)
	return false
