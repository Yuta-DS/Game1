# Screenshot-only camera tour. Does not save or modify the game scene.
extends SceneTree

var output_dir := "res://artifacts/castle_route_overview"

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=")
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 1100)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = Vector3(-31.1, 69.18, 27.41)
	for frame in 100:
		await process_frame
		await physics_frame
	for layer: CanvasLayer in hub.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	var camera := Camera3D.new()
	camera.fov = 52
	camera.near = 0.05
	camera.far = 2000
	hub.add_child(camera)
	camera.make_current()
	var shots := [
		["01_full_castle_route", Vector3(56, 88, 111), Vector3(-16, 63, 27.41)],
		["02_spiral_stair", Vector3(38, 63, 72), Vector3(-1.4, 47, 27.41)],
		["03_stair_castle_rooftop", Vector3(17, 85, 51), Vector3(-3, 68.5, 27.41)],
		["04_art_castle_front", Vector3(-10, 84, 55), Vector3(-30, 73, 27.41)],
		["05_reverse_stair_view", Vector3(31, 73, -31), Vector3(-2, 47, 27.41)],
		["06_stair_detail", Vector3(16, 59, 45), Vector3(-1.4, 53, 27.41)],
	]
	DirAccess.make_dir_recursive_absolute(output_dir)
	for shot in shots:
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for frame in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := output_dir.path_join("%s.png" % shot[0])
		if root.get_texture().get_image().save_png(path) != OK:
			push_error("CASTLE_OVERVIEW_CAPTURE: could not save " + path)
			quit(1)
			return
		print("CASTLE_OVERVIEW_CAPTURE: " + path)
	quit(0)
