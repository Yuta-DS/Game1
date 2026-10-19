extends SceneTree
## Run with a real rendering backend (not --headless).

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1440, 900)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(hub)
	for frame in 120:
		await process_frame
	for layer in hub.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	var camera := Camera3D.new()
	camera.far = 1000.0
	camera.fov = 60.0
	hub.add_child(camera)
	camera.make_current()
	var port := hub.get_node("Port") as Node3D
	var focus := port.global_position
	DirAccess.make_dir_recursive_absolute("res://artifacts/coastal_style")
	var shots := [
		["01_harbour_in_world", focus + Vector3(25, 18, 30), focus + Vector3(0, 2, 3)],
		["02_boarding_view", focus + Vector3(-12, 6, 23), focus + Vector3(0, 2, 5)],
		["03_coastal_layout", focus + Vector3(0, 65, 32), focus],
		["04_village_reference", Vector3(90, 45, 60), Vector3(90, 20, -20)],
		["05_harbour_detail", focus + Vector3(18, 11, 18), focus + Vector3(1, 2, 2)],
		["06_sea_life", focus + Vector3(9, 5, -17), focus + Vector3(4, 0, -7)],
	]
	for shot in shots:
		camera.global_position = shot[1]
		camera.look_at(shot[2], Vector3.UP)
		for frame in 16:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/coastal_style/%s.png" % shot[0])
		print("COAST_CAPTURE ", shot[0])
	var boat := hub.get_node("Boat") as CharacterBody3D
	var player := hub.get_node("NewPlayer") as CharacterBody3D
	boat.call("board", player)
	Input.action_press("move_forward")
	for frame in 65:
		await physics_frame
	Input.action_release("move_forward")
	camera.global_position = boat.global_position + Vector3(7, 6, 10)
	camera.look_at(boat.global_position + Vector3(0, 2.2, 0), Vector3.UP)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/coastal_style/07_player_sailing.png")
	print("COASTAL_STYLE_CAPTURE: PASS")
	quit()
