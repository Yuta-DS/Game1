extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CROWN_TRAIN_DIRECTIONAL_VFX_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	collision.shape = capsule
	player.add_child(collision)
	world.add_child(player)

	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for _frame in 10:
		await process_frame

	var train := railway.get_node_or_null("RainbowGalaxyTrain") as Node3D
	var vfx := train.get_node_or_null("DirectionalRainbowMovementVFX") as Node3D if train != null else null
	var layout := train.get_node_or_null("RainbowGoldAccentLayout") as Node3D if train != null else null
	if train == null or vfx == null or layout == null:
		_fail("live train is missing its directional VFX or rainbow-gold layout")
		return
	if vfx.get_node_or_null("RainbowDirectionTrail") == null \
			or vfx.get_node_or_null("GoldCrownSparkTrail") == null:
		_fail("directional VFX must contain both rainbow and gold particle layers")
		return
	var initial: Dictionary = railway.call("get_directional_vfx_state")
	if bool(initial.emitting) or int(initial.rainbow_colour_count) < 7 \
			or int(initial.gold_accent_count) < 16 or int(initial.visible_echo_count) != 0:
		_fail("docked train must be quiet while retaining a complete rainbow-gold palette")
		return

	player.global_position = railway.call("get_driver_interaction_position")
	if not bool(railway.call("board_as_driver")):
		_fail("could not board the live train to exercise movement VFX")
		return
	# Drive with a deterministic fixed timestep. The live _process() input poll
	# would otherwise see no held keyboard key in this direct-call test and apply
	# an extra zero-throttle command after every commanded frame.
	railway.set_process(false)

	for _frame in 120:
		railway.call("drive_manual", 1.0, 1.0 / 60.0)
		railway.call("_update_train_mechanisms", 1.0 / 60.0)
		await process_frame
	var forward: Dictionary = railway.call("get_directional_vfx_state")
	if not bool(forward.emitting) or float(forward.speed_ratio) <= 0.05:
		_fail("forward motion did not start speed-scaled rainbow VFX")
		return
	if int(forward.visible_echo_count) < 4:
		_fail("forward motion did not build a readable train-shaped blur echo")
		return
	var forward_direction: Vector3 = forward.movement_direction
	var forward_offset: Vector3 = forward.trail_world_position - train.global_position
	if forward_offset.normalized().dot(forward_direction) > -0.80:
		_fail("forward trail is not positioned behind the travel direction")
		return
	for ribbon_position in forward.ribbon_world_positions:
		if ((ribbon_position as Vector3) - train.global_position).dot(forward_direction) >= 0.0:
			_fail("a forward rainbow ribbon crossed onto the front of the train")
			return
	for echo_position in forward.echo_world_positions:
		if ((echo_position as Vector3) - train.global_position).dot(forward_direction) >= 0.0:
			_fail("a forward motion echo crossed onto the front of the train")
			return

	var reversed := false
	for _frame in 300:
		railway.call("drive_manual", -1.0, 1.0 / 60.0)
		railway.call("_update_train_mechanisms", 1.0 / 60.0)
		await process_frame
		var state: Dictionary = railway.call("get_directional_vfx_state")
		if bool(state.emitting) and int(state.visible_echo_count) >= 3 \
				and (state.movement_direction as Vector3).dot(forward_direction) < -0.80:
			reversed = true
			break
	if not reversed:
		_fail("reverse control did not flip the measured VFX direction")
		return
	var backward: Dictionary = railway.call("get_directional_vfx_state")
	var backward_direction: Vector3 = backward.movement_direction
	var backward_offset: Vector3 = backward.trail_world_position - train.global_position
	if backward_offset.normalized().dot(backward_direction) > -0.80:
		_fail("reverse trail is not positioned behind backward travel")
		return
	for ribbon_position in backward.ribbon_world_positions:
		if ((ribbon_position as Vector3) - train.global_position).dot(backward_direction) >= 0.0:
			_fail("a reverse rainbow ribbon crossed onto the front of the train")
			return
	for echo_position in backward.echo_world_positions:
		if ((echo_position as Vector3) - train.global_position).dot(backward_direction) >= 0.0:
			_fail("a reverse motion echo crossed onto the front of the train")
			return

	for _frame in 180:
		railway.call("drive_manual", 0.0, 1.0 / 60.0)
		railway.call("_update_train_mechanisms", 1.0 / 60.0)
		await process_frame
	var stopped: Dictionary = railway.call("get_directional_vfx_state")
	if bool(stopped.emitting) or float(stopped.speed_ratio) > 0.02 \
			or int(stopped.visible_echo_count) != 0:
		_fail("rainbow movement VFX continues after the train stops")
		return

	print("CROWN_TRAIN_DIRECTIONAL_VFX_TEST: PASS — rainbow and gold trails follow forward/reverse motion and stop at rest")
	quit()
