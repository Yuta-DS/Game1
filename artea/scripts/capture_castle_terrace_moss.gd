extends SceneTree

var output_dir := "res://artifacts/castle_terrace_moss"

func _init() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_dir = argument.trim_prefix("--output=")
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 900)
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
		["01_terrace_near_side", Vector3(-12, 71, 49), Vector3(-27, 67.8, 27.41)],
		["02_terrace_far_side", Vector3(-12, 71, 5.8), Vector3(-27, 67.8, 27.41)],
		["03_castle_terrace_overview", Vector3(7, 81, 53), Vector3(-22, 70, 27.41)],
		["04_pattern_detail", Vector3(-19.5, 68.2, 42), Vector3(-25, 66.6, 34.61)],
	]
	DirAccess.make_dir_recursive_absolute(output_dir)
	for shot in shots:
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := output_dir.path_join("%s.png" % shot[0])
		if root.get_texture().get_image().save_png(path) != OK:
			push_error("TERRACE_MOSS_CAPTURE: failed to save " + path)
			quit(1)
			return
		print("TERRACE_MOSS_CAPTURE: " + path)
	quit(0)
