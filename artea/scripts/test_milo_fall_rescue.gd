extends SceneTree

# Milo catches a player who falls off the world and flies them back to the last
# safe ground (milo_fall_rescue.gd). A drop onto a lower floor is not a fall
# off the world and must be left alone.

const PLAYER := preload("res://scenes/entities/NewPlayer.tscn")
const MILO_SCENE := preload("res://scenes/milo_animations.tscn")
const FALL_RESCUE := preload("res://scripts/milo_fall_rescue.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("  FAIL: %s" % message)


func _floor(parent: Node3D, centre: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = centre
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)


func _wait_physics(frames: int) -> void:
	for _i in frames:
		await physics_frame


func _wait_until(condition: Callable, max_frames: int) -> bool:
	for _i in max_frames:
		if condition.call():
			return true
		await physics_frame
	return bool(condition.call())


func _run() -> void:
	# Tweens and timers run in real time; speed the rescue up.
	Engine.time_scale = 3.0
	var world := Node3D.new()
	world.name = "FallRescueTestWorld"
	root.add_child(world)
	# A 20 m square with its top at y = 0 and, off its +x side, a lower floor
	# 20 m down that a legitimate drop can land on.
	_floor(world, Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	_floor(world, Vector3(0, -20.5, 40), Vector3(20, 1, 20))

	var player := PLAYER.instantiate() as CharacterBody3D
	player.position = Vector3(0, 0.05, 0)
	world.add_child(player)
	var milo := MILO_SCENE.instantiate() as CharacterBody3D
	milo.position = Vector3(2, 0, 0)
	world.add_child(milo)
	var rescue := FALL_RESCUE.new()
	world.add_child(rescue)
	rescue.call("set_player", player, milo)
	await _wait_physics(30)

	var safe: Vector3 = rescue.call("get_last_safe_position")
	_check(safe != Vector3.INF and safe.distance_to(Vector3.ZERO) < 0.3,
		"standing mid-floor records safe ground (got %s)" % safe)

	# A foot from the edge is not safe: a rescue there would drop the player
	# straight back off.
	player.global_position = Vector3(9.6, 0.05, 0)
	await _wait_physics(30)
	safe = rescue.call("get_last_safe_position")
	_check(safe.x < 9.25, "ledge edges are never recorded as safe (got %s)" % safe)

	# Walk off into the void.
	var inland: Vector3 = rescue.call("get_last_safe_position")
	player.global_position = Vector3(14, 0.05, 0)
	var started := await _wait_until(func() -> bool: return rescue.call("is_rescuing"), 240)
	_check(started, "a fall with no floor below starts a rescue")
	_check(player.global_position.y > -37.0,
		"the rescue starts soon after the drop (player at %s)" % player.global_position)
	_check(not player.is_physics_processing(), "the player is held while being carried")
	_check(str(milo.call("get_companion_state_name")) == "RESCUING",
		"Milo is flying the rescue")
	_check(player.find_child("MiloRescueBubble", true, false) != null,
		"the player is caught in Milo's bubble")

	var finished := await _wait_until(func() -> bool: return not rescue.call("is_rescuing"), 600)
	_check(finished, "the rescue completes")
	await _wait_physics(20)
	_check(player.is_physics_processing(), "the player is released")
	_check(Vector2(player.global_position.x - inland.x, player.global_position.z - inland.z).length() < 0.5,
		"the player is back on the last safe ground (at %s, expected %s)" % [
			player.global_position, inland])
	_check(player.is_on_floor(), "the player lands on the floor after release")
	_check(not bool(milo.call("is_fall_rescue_active")), "Milo hands control back")
	_check(milo.global_position.distance_to(player.global_position) < 4.0,
		"Milo lands beside the player (%.2f m away)" %
		milo.global_position.distance_to(player.global_position))
	_check(player.find_child("MiloRescueBubble", true, false) == null,
		"the bubble is gone after release")
	_check(int(rescue.call("get_rescue_count")) == 1, "exactly one rescue ran")

	# Dropping onto the lower floor is a jump down, not a fall off the world.
	player.global_position = Vector3(0, 0.05, 9.0)
	await _wait_physics(20)
	player.global_position = Vector3(0, 0.05, 32.0)
	var landed := await _wait_until(func() -> bool:
		return player.is_on_floor() and player.global_position.y < -15.0, 240)
	_check(landed, "the player lands on the lower floor (at %s)" % player.global_position)
	_check(int(rescue.call("get_rescue_count")) == 1,
		"a drop onto a floor below is not rescued")

	# With no safe history, a scene's own respawn point is used as the target.
	var fresh := FALL_RESCUE.new()
	world.add_child(fresh)
	fresh.call("set_player", player, milo)
	rescue.set_physics_process(false)
	_check(bool(fresh.call("rescue", Vector3(0, 0, 0))),
		"a scene can hand a fall over with its own respawn point")
	await _wait_until(func() -> bool: return not fresh.call("is_rescuing"), 600)
	await _wait_physics(20)
	_check(player.global_position.distance_to(Vector3.ZERO) < 1.0,
		"the fallback target is used when nothing safe was recorded (at %s)" %
		player.global_position)

	Engine.time_scale = 1.0
	if _failures == 0:
		print("test_milo_fall_rescue: PASS")
	else:
		printerr("test_milo_fall_rescue: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)
