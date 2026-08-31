extends SceneTree
## Exercise the real hub player, terrain and imported harbour collision.

var player: CharacterBody3D
var terrain: Node

func _init() -> void:
	call_deferred("_run")

func _release() -> void:
	for action in ["move_left", "move_right", "move_forward", "move_backward", "jump"]:
		Input.action_release(action)

func _fail(message: String) -> void:
	_release()
	push_error("HARBOUR_SHORE_ACCESS: " + message)
	quit(1)

func _settle() -> bool:
	_release()
	player.velocity = Vector3.ZERO
	for frame in 120:
		await physics_frame
		if player.is_on_floor():
			return true
	return false

func _walk_to(target: Vector3) -> bool:
	var largest_rise := 0.0
	for frame in 300:
		var offset := Vector2(target.x - player.position.x, target.z - player.position.z)
		if offset.length() < .15:
			_release()
			print("SHORE_WALK: reached %s, largest frame rise %.3fm" % [target, largest_rise])
			return true
		var direction := offset.normalized()
		_release()
		Input.action_press("move_right", maxf(direction.x, 0))
		Input.action_press("move_left", maxf(-direction.x, 0))
		Input.action_press("move_backward", maxf(direction.y, 0))
		Input.action_press("move_forward", maxf(-direction.y, 0))
		var previous_y := player.position.y
		await physics_frame
		var rise := player.position.y - previous_y
		largest_rise = maxf(largest_rise, rise)
		if rise > .14:
			_fail("entrance has a jarring step of %.3fm at %s" % [rise, player.position])
			return false
		if player.position.y < .5 or not player.is_on_floor():
			_fail("walking lost floor support at " + str(player.position))
			return false
	_fail("blocked walking toward %s at %s" % [target, player.position])
	return false

func _jump() -> bool:
	if not await _settle():
		_fail("cannot stand before jumping")
		return false
	var start_y := player.position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var peak := player.position.y
	var airborne := false
	for frame in 120:
		await physics_frame
		peak = maxf(peak, player.position.y)
		airborne = airborne or not player.is_on_floor()
		if airborne and player.is_on_floor():
			if peak - start_y < 1.5 or absf(player.position.y - start_y) > .08:
				_fail("jump did not return to the same supported surface")
				return false
			return true
	_fail("jump did not land")
	return false

func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for frame in 120:
		await physics_frame
	player = hub.get_node("NewPlayer") as CharacterBody3D
	terrain = hub.get_node("Environment/Terrain3D")
	player.get_node("CameraController").rotation.y = 0
	for x in [24.0, 26.5, 32.0, 38.0, 43.4, 46.0]:
		var heights := []
		for z in [168.0, 169.0, 170.0, 171.0, 172.0, 173.2]:
			heights.append(snappedf(terrain.data.get_height(Vector3(x, 0, z)), .001))
		print("SHORE_TERRAIN x=%s z=168..173.2 heights=%s" % [x, heights])
	for x in [38.0, 43.4, 26.5]:
		player.position = Vector3(x, terrain.data.get_height(Vector3(x, 0, 168)) + .1, 168)
		if not await _settle():
			_fail("cannot stand on the beach")
			return
		if not await _walk_to(Vector3(x, 0, 173.7)):
			return
		if not await _jump():
			return
		if not await _walk_to(Vector3(x, 0, 171.5)):
			return
		if not await _jump():
			return
		if not await _walk_to(Vector3(x, 0, 168)):
			return
	print("HARBOUR_SHORE_ACCESS: PASS — real player walks both ways to house, entrance and shop without stepping/snags; jumps and lands on deck and slope")
	_release()
	quit()
