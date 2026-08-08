# Developer visual-check utility. Produces two 1280x720 PNG captures of the
# live world using a clean inspection camera.
extends SceneTree


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/New_Hub_World.tscn") as PackedScene
	var hub := packed.instantiate()
	root.add_child(hub)
	for _i in 48:
		await process_frame

	var isles := hub.get_node("SkyIsles") as Node3D
	for isle_id in ["mind", "heart", "creator"]:
		isles.call("set_island_vibrant", isle_id, true)
	var citadel := hub.get_node("LumenCitadel") as Node3D
	citadel.call("set_vibrant", true)
	# Island state changes are intentionally two-second material tweens. Let the
	# vibrant state settle before judging it visually.
	for _i in 150:
		await process_frame

	# Hide gameplay HUD/debug overlays so these captures inspect the world layer.
	for node in hub.find_children("*", "CanvasLayer", true, false):
		var layer := node as CanvasLayer
		layer.visible = false

	var camera := Camera3D.new()
	camera.name = "WorldCaptureCamera"
	camera.fov = 66.0
	camera.far = 900.0
	hub.add_child(camera)
	camera.make_current()

	DirAccess.make_dir_recursive_absolute("res://artifacts")
	await _save_angle(camera, Vector3(-12.0, 82.0, 60.0),
		Vector3(-47.0, 77.0, 28.0), "res://artifacts/castle_station_angle.png")
	await _save_angle(camera, Vector3(0.0, 190.0, 340.0),
		Vector3(0.0, 135.0, 0.0), "res://artifacts/castle_universe_wide.png")
	print("CASTLE_CAPTURE: PASS — wrote two visual-check angles")
	quit()


func _save_angle(camera: Camera3D, position: Vector3, target: Vector3,
		path: String) -> void:
	camera.global_position = position
	camera.look_at(target, Vector3.UP)
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("CASTLE_CAPTURE: failed %s (%s)" % [path, error_string(error)])
