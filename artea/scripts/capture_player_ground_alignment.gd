extends SceneTree


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _frame in 100:
		await process_frame
		await physics_frame
	for canvas_candidate in hub.find_children("*", "CanvasLayer", true, false):
		(canvas_candidate as CanvasLayer).visible = false
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.global_position = Vector3(-24.5, 74.0, 25.66)
	player.velocity = Vector3.ZERO
	for _frame in 180:
		await physics_frame
		if player.is_on_floor():
			break
	player.set_physics_process(false)
	player.set_process_input(false)
	(player.get_node("RogueSkin/AnimationPlayer") as AnimationPlayer).play("Idle")
	# Use the production third-person rig instead of a low, close proof camera.
	# The old angle hid the fox's torso behind its hood and put Milo directly in
	# the silhouette, producing an image that was not representative of play.
	var controller := player.get_node("CameraController") as SpringArm3D
	controller.rotation.x = deg_to_rad(-14.0)
	controller.rotation.y = deg_to_rad(155.0)
	# This is inside the production 4.8–9.2 zoom range and keeps the complete
	# silhouette readable without returning to the distorting close-up.
	controller.spring_length = 5.4
	var camera := controller.get_node("Camera3D") as Camera3D
	camera.make_current()
	for _frame in 30:
		await process_frame
		await RenderingServer.frame_post_draw
	var output := "res://artifacts/castle_court_redesign/player_ground_alignment_fixed.png"
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("PLAYER_GROUND_CAPTURE: could not write image")
		quit(error)
		return
	print("PLAYER_GROUND_CAPTURE: wrote %s origin_y=%.3f skin_y=%.3f" % [
		output, player.global_position.y,
		(player.get_node("RogueSkin") as Node3D).position.y])
	quit()


func _init() -> void:
	call_deferred("_capture")
