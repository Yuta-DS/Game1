extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("PLAYER_DIRECTION_ANIMATION_TEST: %s" % message)
	for action in ["move_forward", "jump", "attack", "block"]:
		Input.action_release(action)
	quit(1)


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 8:
		await physics_frame
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	var camera := gallery.get_node_or_null("Camera3D") as Camera3D
	var visual := player.get_node_or_null("FoxVisuals") as Node3D if player != null else null
	if player == null or camera == null or visual == null:
		_fail("gallery player, camera, or fox visual is missing")
		return
	var clips: PackedStringArray = player.call("get_available_character_animations")
	for required_clip in ["Idle", "Run", "Jump"]:
		if not clips.has(required_clip):
			_fail("fox import is missing its %s skeletal animation" % required_clip)
			return

	var camera_forward := Vector3(-camera.global_basis.z.x, 0, -camera.global_basis.z.z).normalized()
	var camera_right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
	var controls := {
		"W": player.call("get_camera_relative_move_direction", Vector2(0, -1)),
		"S": player.call("get_camera_relative_move_direction", Vector2(0, 1)),
		"A": player.call("get_camera_relative_move_direction", Vector2(-1, 0)),
		"D": player.call("get_camera_relative_move_direction", Vector2(1, 0)),
	}
	if (controls.W as Vector3).dot(camera_forward) < 0.999 \
			or (controls.S as Vector3).dot(-camera_forward) < 0.999 \
			or (controls.A as Vector3).dot(-camera_right) < 0.999 \
			or (controls.D as Vector3).dot(camera_right) < 0.999:
		_fail("W/S or A/D is reversed relative to the camera")
		return

	for _settle in 90:
		await physics_frame
		if player.is_on_floor():
			break
	Input.action_press("move_forward")
	var travel := Vector3.ZERO
	for _move in 28:
		await physics_frame
		var frame_travel := Vector3(player.velocity.x, 0, player.velocity.z)
		if frame_travel.length() > 0.1:
			travel = frame_travel.normalized()
	Input.action_release("move_forward")
	if player.call("get_animation_state") != "run":
		_fail("moving character does not enter the Run animation state")
		return
	var fox_forward := Vector3(visual.global_basis.z.x, 0, visual.global_basis.z.z).normalized()
	if travel.length() < 0.9 or fox_forward.dot(travel) < 0.85:
		_fail("character body faces away from travel: travel=%s forward=%s dot=%.3f local_yaw=%.3f root_yaw=%.3f" % [
			travel, fox_forward, fox_forward.dot(travel), visual.rotation.y, player.global_rotation.y])
		return

	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var states_seen := {}
	for _jump_frame in 150:
		await physics_frame
		states_seen[player.call("get_animation_state")] = true
		if states_seen.has("jump") and states_seen.has("fall") and states_seen.has("land"):
			break
	for airborne_state in ["jump", "fall", "land"]:
		if not states_seen.has(airborne_state):
			_fail("jump sequence never entered %s animation state" % airborne_state)
			return

	Input.action_press("block")
	await physics_frame
	if player.call("get_animation_state") != "block":
		_fail("shield does not enter the Block animation state")
		return
	Input.action_release("block")
	await physics_frame
	player.call("_start_attack")
	await physics_frame
	if player.call("get_animation_state") != "attack":
		_fail("sword action does not enter the Attack animation state")
		return
	player.call("_finish_attack")
	player.call("_set_blocking", false)
	player.call("take_damage", 10.0, null)
	await physics_frame
	if player.call("get_animation_state") != "hurt":
		_fail("damage does not enter the Hurt animation state")
		return
	player.call("take_damage", 1000.0, null)
	await physics_frame
	if player.call("get_animation_state") != "defeated":
		_fail("zero health does not enter the Defeated animation state")
		return

	print("PLAYER_DIRECTION_ANIMATION_TEST: PASS — conventional controls, matching facing, and all action animation states")
	quit()
