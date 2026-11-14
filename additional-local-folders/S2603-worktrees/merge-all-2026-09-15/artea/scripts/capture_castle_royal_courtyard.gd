extends SceneTree

const SHOTS := [
	["01_courtyard_overview", Vector3(-10.5, 84.5, 42.0), Vector3(-24.0, 69.4, 27.41)],
	["02_ground_and_fire", Vector3(-17.4, 79.5, 36.0), Vector3(-24.0, 68.4, 27.41)],
	["03_stair_landing", Vector3(-24.8, 72.6, 37.3), Vector3(-29.2, 68.7, 27.41)],
	["04_player_on_paving", Vector3(-18.0, 71.0, 32.4), Vector3(-23.0, 69.0, 29.5)],
	["05_wide_gate", Vector3(-9.0, 74.0, 28.8), Vector3(-24.5, 70.2, 27.41)],
]

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = Vector3(-23.0, 67.97, 29.5)
	for frame in 100:
		await process_frame
		await physics_frame
	for layer: CanvasLayer in hub.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.05
	camera.far = 2000.0
	hub.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/royal_courtyard_implementation")
	for shot in SHOTS:
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/royal_courtyard_implementation/%s.png" % shot[0]
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("COURTYARD_CAPTURE: " + error_string(error))
			quit(1)
			return
		print("COURTYARD_CAPTURE: " + path)
	quit(0)
