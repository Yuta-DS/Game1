extends SceneTree

const SHOTS := [
	["01_royal_entrance", Vector3(-21.0, 80.0, 39.0), Vector3(-36.0, 78.0, 27.41)],
	["02_door_frame", Vector3(-27.8, 84.4, 29.6), Vector3(-39.8, 82.8, 27.41)],
	["03_stair_detail", Vector3(-27.3, 75.8, 33.0), Vector3(-35.3, 73.8, 27.41)],
	["04_stair_underside", Vector3(-35.4, 70.8, 27.41), Vector3(-37.0, 75.0, 27.41)],
]

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
	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.05
	camera.far = 2000.0
	hub.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts/royal_castle_entry")
	for shot in SHOTS:
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://artifacts/royal_castle_entry/%s.png" % shot[0]
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("ROYAL_ENTRY_CAPTURE: " + error_string(error))
			quit(1)
			return
		print("ROYAL_ENTRY_CAPTURE: " + path)
	quit(0)
