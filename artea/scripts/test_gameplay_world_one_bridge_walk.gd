extends SceneTree

# Exercise the Island One -> Island Two crossing inside the real gallery scene.
# The standalone World One fixture cannot detect overlapping gallery geometry.
const GALLERY_SCENE := "res://scenes/art_gallery_3d_inprogress.tscn"
const WALK_SPEED := 10.0
const GRAVITY := 28.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery := (load(GALLERY_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(gallery)
	current_scene = gallery
	for _frame in 15:
		await physics_frame
	var world := gallery.get_node("ArtCastleFloatingWorld/MindSparkWorldOne") as MindSparkWorldOne
	var player := gallery.get_node("Player3D") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process_input(false)
	var gate := world.get_node("WorldOneGeometry/SavedQuestProgressionGates/QuestGate_1") as AnimatableBody3D
	assert(bool(gate.get_meta("physical_barrier_removed", false)))
	world.set_quest_gate_open(0, false)
	await physics_frame
	assert((gate.get_node("CollisionShape3D") as CollisionShape3D).disabled,
		"restoring a locked quest must not recreate the Island One bridge barrier")
	var source: Dictionary = MindSparkWorldOne.ZONES[1]
	var destination: Dictionary = MindSparkWorldOne.ZONES[2]
	var source_center: Vector3 = source.position
	var destination_center: Vector3 = destination.position
	var direction := destination_center - source_center
	direction.y = 0
	direction = direction.normalized()
	var start := world.to_global(source_center + direction * (float(source.radius) - 45.0))
	var finish := world.to_global(destination_center - direction * (float(destination.radius) - 45.0))
	player.global_position = start + Vector3.UP * 2.5
	player.velocity = Vector3.ZERO
	for _frame in 120:
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			break
	if not player.is_on_floor():
		_fail("Island One approach does not support the live player")
		return
	var best_distance := _flat_distance(player.global_position, finish)
	var stalled_frames := 0
	var airborne_frames := 0
	for _frame in 2200:
		var offset := finish - player.global_position
		offset.y = 0
		if offset.length() < 2.0:
			if not player.is_on_floor():
				_fail("Island Two exit is airborne")
				return
			print("GameplayWorldOneBridgeWalk: PASS — live gallery player crossed Island One to Island Two")
			quit()
			return
		var heading := offset.normalized()
		player.velocity.x = heading.x * WALK_SPEED
		player.velocity.z = heading.z * WALK_SPEED
		player.velocity.y -= GRAVITY / 60.0
		player.move_and_slide()
		airborne_frames = 0 if player.is_on_floor() else airborne_frames + 1
		if airborne_frames > 8:
			_fail("floor gap at %s" % str(player.global_position))
			return
		var distance := _flat_distance(player.global_position, finish)
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
			_fail("blocked at %s by %s target=%s" % [str(player.global_position),
				obstruction, str(finish)])
			return
		await physics_frame
	var obstruction := ""
	for collision_index in player.get_slide_collision_count():
		var collision := player.get_slide_collision(collision_index)
		obstruction += "%s normal=%s; " % [
			str((collision.get_collider() as Node).get_path()),
			str(collision.get_normal())]
	var ray_end := finish
	ray_end.y = player.global_position.y + .3
	var ray := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * .3, ray_end)
	ray.collision_mask = 1
	ray.exclude = [player.get_rid()]
	var ray_hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	_fail("crossing timed out at %s local=%s target=%s best=%.2f velocity=%s real=%s motion=%s hits=%s" % [
		str(player.global_position), str(world.to_local(player.global_position)),
		str(finish), best_distance, str(player.velocity),
		str(player.get_real_velocity()), str(player.get_last_motion()),
		obstruction + " ray=" + str(ray_hit)])


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _fail(message: String) -> void:
	push_error("GameplayWorldOneBridgeWalk: " + message)
	quit(1)
