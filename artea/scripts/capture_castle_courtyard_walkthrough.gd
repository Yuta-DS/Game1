extends SceneTree

const TERRACE_Y := 67.73
const ROUTE_Z := 25.66
const CAMERA_OFFSET := Vector3(4.5, 7.2, -7.5)


func _loading_cover() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "WalkthroughLoadingCover"
	layer.layer = 1000
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color("111825")
	# Movie Writer can apply Retina scaling after root.size is assigned. Oversize
	# the cover so no portion of the unrelated hub spawn leaks around its edge.
	background.position = Vector2(-32.0, -32.0)
	background.size = Vector2(4096.0, 4096.0)
	layer.add_child(background)
	var label := Label.new()
	label.text = "ART CASTLE  •  COURTYARD WALK TEST"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color("f2d08b"))
	label.position = Vector2(0.0, root.size.y * 0.42)
	label.size = Vector2(root.size.x, 64.0)
	layer.add_child(label)
	return layer


func _settle(player: CharacterBody3D, position: Vector3) -> bool:
	player.global_position = position
	player.velocity = Vector3.ZERO
	for _frame in 180:
		await physics_frame
		if player.is_on_floor():
			return true
	return false


func _fade_cover(cover: CanvasLayer) -> void:
	for frame in 24:
		var alpha := 1.0 - float(frame + 1) / 24.0
		for child in cover.get_children():
			if child is CanvasItem:
				(child as CanvasItem).modulate.a = alpha
		await process_frame
	cover.queue_free()
	await process_frame


func _face_controller_toward(camera_controller: SpringArm3D,
		direction: Vector3) -> void:
	# NewPlayer maps move_forward through the gameplay camera's yaw. This yaw
	# makes its real Input.get_vector route point along the desired world vector.
	camera_controller.rotation.y = atan2(-direction.x, -direction.z)


func _drive_normal_controller(player: CharacterBody3D,
		camera_controller: SpringArm3D, proof_camera: Camera3D,
		destination: Vector3, max_frames: int) -> Dictionary:
	var lowest_y := player.global_position.y
	var highest_y := player.global_position.y
	var animation_seen := false
	var reached := false
	var stalled := 0
	var best_distance := Vector2(
		player.global_position.x - destination.x,
		player.global_position.z - destination.z).length()
	Input.action_press("move_forward")
	for _frame in max_frames:
		var direction := destination - player.global_position
		direction.y = 0.0
		if direction.length() < 0.38:
			reached = true
			break
		_face_controller_toward(camera_controller, direction.normalized())
		proof_camera.global_position = player.global_position + CAMERA_OFFSET
		proof_camera.look_at(player.global_position + Vector3.UP * 1.2, Vector3.UP)
		await physics_frame
		await process_frame
		lowest_y = minf(lowest_y, player.global_position.y)
		highest_y = maxf(highest_y, player.global_position.y)
		var animation_player := player.get_node_or_null(
			"RogueSkin/AnimationPlayer") as AnimationPlayer
		if animation_player != null and animation_player.is_playing() \
				and animation_player.current_animation in ["Walk", "Run"]:
			animation_seen = true
		var distance := Vector2(
			player.global_position.x - destination.x,
			player.global_position.z - destination.z).length()
		if distance < best_distance - 0.004:
			best_distance = distance
			stalled = 0
		else:
			stalled += 1
		if stalled >= 55:
			break
	Input.action_release("move_forward")
	for _frame in 24:
		proof_camera.global_position = player.global_position + CAMERA_OFFSET
		proof_camera.look_at(player.global_position + Vector3.UP * 1.2, Vector3.UP)
		await physics_frame
		await process_frame
	return {
		"reached": reached,
		"lowest_y": lowest_y,
		"highest_y": highest_y,
		"animation_seen": animation_seen,
	}


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var cover := _loading_cover()
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 90:
		await process_frame
		await physics_frame
	for canvas_candidate in hub.find_children("*", "CanvasLayer", true, false):
		(canvas_candidate as CanvasLayer).visible = false

	var player := hub.get_node_or_null("NewPlayer") as CharacterBody3D
	var fire := hub.get_node_or_null(
		"CastleEntrance/CastleEntrance/CastleCourtyardFire") as Node3D
	if player == null or fire == null:
		push_error("CASTLE_COURTYARD_WALKTHROUGH: player or fire did not load")
		quit(1)
		return
	player.interacting = false
	var controller := player.get_node("CameraController") as SpringArm3D
	var player_camera := controller.get_node("Camera3D") as Camera3D
	player_camera.current = false
	var proof_camera := Camera3D.new()
	proof_camera.fov = 58.0
	proof_camera.near = 0.05
	proof_camera.far = 2000.0
	hub.add_child(proof_camera)
	proof_camera.make_current()

	# Begin on the timber causeway side of its new central gateway. Loading and
	# this setup remain hidden, so the movie contains no unrelated Milo scene or
	# visible teleport.
	var start := Vector3(-14.2, TERRACE_Y + 5.0, ROUTE_Z)
	if not await _settle(player, start):
		push_error("CASTLE_COURTYARD_WALKTHROUGH: player could not settle on bridge")
		quit(1)
		return
	proof_camera.global_position = player.global_position + CAMERA_OFFSET
	proof_camera.look_at(player.global_position + Vector3.UP * 1.2, Vector3.UP)
	for _frame in 20:
		await process_frame
		await physics_frame
	await _fade_cover(cover)

	# Walk naturally through the open bridge gate, beside the live fire and to
	# the foot of the ceremonial stair. The player's own physics process owns
	# velocity, turning, step-up, floor snap and animation for the whole pass.
	var destination := Vector3(-27.55, TERRACE_Y, ROUTE_Z)
	var result := await _drive_normal_controller(player, controller,
		proof_camera, destination, 360)
	for _frame in 75:
		proof_camera.global_position = player.global_position + CAMERA_OFFSET
		proof_camera.look_at(player.global_position + Vector3.UP * 1.2, Vector3.UP)
		await process_frame
		await physics_frame

	var vertical_range := float(result.highest_y) - float(result.lowest_y)
	if not bool(result.reached) or not bool(result.animation_seen) \
			or vertical_range > 0.12:
		push_error("CASTLE_COURTYARD_WALKTHROUGH: failed reached=%s animated=%s range=%.3f"
			% [result.reached, result.animation_seen, vertical_range])
		quit(1)
		return
	print("CASTLE_COURTYARD_WALKTHROUGH: PASS — normal animated controller crossed on one continuous floor; range=%.3f m"
		% vertical_range)
	quit()


func _init() -> void:
	call_deferred("_capture")
