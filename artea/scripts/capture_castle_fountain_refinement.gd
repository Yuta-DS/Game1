extends SceneTree

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = Vector3(-30.6, 69.18, 27.41)
	for frame in 100:
		await process_frame
		await physics_frame
	for layer: CanvasLayer in hub.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	var fountain := hub.get_node("CastleStairs/CastleStair/CastleRoyalFountain") as Node3D
	var origin := fountain.global_position
	var camera := Camera3D.new()
	camera.fov = 48
	camera.near = 0.05
	camera.far = 2000
	hub.add_child(camera)
	camera.make_current()
	var shots := [
		["01_fountain_closeup", origin + Vector3(4.8, 3.8, 5.4), origin + Vector3.UP * 1.10],
		["02_fountain_castle_garden", Vector3(11, 78, 40), Vector3(-7, 69, 27.41)],
		["03_water_and_carving", origin + Vector3(2.8, 3.5, 3.4), origin + Vector3.UP * 1.20],
	]
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_fountain_refinement")
	for shot in shots:
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/castle_fountain_refinement/%s.png" % shot[0]
		if root.get_texture().get_image().save_png(path) != OK:
			push_error("FOUNTAIN_CAPTURE: cannot save " + path)
			quit(1)
			return
		print("FOUNTAIN_CAPTURE: " + path)
	if "--record" in OS.get_cmdline_user_args():
		root.size = Vector2i(960, 540)
		camera.global_position = origin + Vector3(4.8, 3.8, 5.4)
		camera.look_at(origin + Vector3.UP * 1.1, Vector3.UP)
		Engine.max_fps = 30
		var frames_dir := "res://artifacts/castle_fountain_refinement/frames"
		DirAccess.make_dir_recursive_absolute(frames_dir)
		for frame in 120:
			await process_frame
			await RenderingServer.frame_post_draw
			var error := root.get_texture().get_image().save_jpg("%s/%04d.jpg" % [frames_dir, frame], 0.90)
			if error != OK:
				push_error("FOUNTAIN_CAPTURE: recording failed: " + error_string(error))
				quit(1)
				return
		print("FOUNTAIN_CAPTURE: 120 animation frames at 30fps")
	quit(0)
