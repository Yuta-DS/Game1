extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CROWN_TRAIN_WALKABLE_PLATFORM_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)

	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	var player_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .5
	capsule.height = 1.8
	player_shape.shape = capsule
	player.add_child(player_shape)
	world.add_child(player)

	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for _frame in 16:
		await process_frame
		await physics_frame

	var train := railway.get_node_or_null("RainbowGalaxyTrain") as Node3D
	if train == null:
		_fail("train was not created")
		return
	if not train is AnimatableBody3D:
		_fail("complete train is not the authoritative moving platform")
		return
	var platform := train as AnimatableBody3D
	var solid_shape_count := platform.find_children("*", "CollisionShape3D", false, false).size()
	if not platform.sync_to_physics or platform.collision_layer != 1 \
			or String(platform.get_meta("mass_model", "")) != "infinite_mass_moving_platform":
		_fail("train shell is not configured as a synchronized solid platform")
		return
	if solid_shape_count < 30:
		_fail("collision coverage does not include the complete player-facing train shell")
		return

	# A player dropped above the coach must land on its floor rather than passing
	# through to the monorail below.
	player.call("set_input_enabled", false)
	player.global_position = train.to_global(Vector3(0.0, 3.0, 0.0))
	player.velocity = Vector3.ZERO
	for _frame in 45:
		await physics_frame
	if not player.is_on_floor() or player.global_position.y < train.global_position.y + 2.0:
		_fail("player did not land and stand on the passenger deck")
		return

	# Move the parent train while the character walks freely. Godot should apply
	# the AnimatableBody platform velocity and preserve the player's local place.
	railway.set("_riding", true)
	var local_before := train.to_local(player.global_position)
	for _frame in 30:
		train.position.x += .10
		await physics_frame
	var local_after := train.to_local(player.global_position)
	if Vector2(local_after.x - local_before.x, local_after.z - local_before.z).length() > .45:
		_fail("moving train slid out from underneath the walking player")
		return

	# Jumping begins from the moving deck and must produce a real upward arc.
	player.call("set_input_enabled", true)
	var jump_start_y := player.global_position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var jump_peak_y := player.global_position.y
	for _frame in 18:
		await physics_frame
		jump_peak_y = maxf(jump_peak_y, player.global_position.y)
	if jump_peak_y < jump_start_y + .35:
		_fail("player could not jump from the train platform")
		return

	# Side guards and roof proxies must also answer physics queries as train mass.
	var space := world.get_world_3d().direct_space_state
	var side_query := PhysicsRayQueryParameters3D.create(
		train.to_global(Vector3(8.0, 2.0, 4.35)),
		train.to_global(Vector3(4.0, 2.0, 4.35)), 1)
	var side_hit := space.intersect_ray(side_query)
	var gate_query := PhysicsRayQueryParameters3D.create(
		train.to_global(Vector3(8.0, 2.0, 0.0)),
		train.to_global(Vector3(4.4, 2.0, 0.0)), 1)
	var gate_hit := space.intersect_ray(gate_query)
	var roof_query := PhysicsRayQueryParameters3D.create(
		train.to_global(Vector3(0.0, 10.0, 15.0)),
		train.to_global(Vector3(0.0, 5.0, 15.0)), 1)
	var roof_hit := space.intersect_ray(roof_query)
	if side_hit.is_empty() or not side_hit.collider is AnimatableBody3D \
			or roof_hit.is_empty() or not roof_hit.collider is AnimatableBody3D:
		_fail("player-facing walls or roof still allow pass-through")
		return
	if not gate_hit.is_empty():
		_fail("coach side rail still blocks the centre jump/walk boarding gate")
		return

	print("CROWN_TRAIN_WALKABLE_PLATFORM_TEST: PASS — flexible boarding, solid infinite-mass shells, moving-platform walking, and train jumping work")
	quit()
