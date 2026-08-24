extends SceneTree


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _i in 80:
		await process_frame
	for node in gallery.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	# Architectural captures hide the parked train and floating labels so the
	# pavilion, resonance arches, and ceremonial ascent can be judged directly.
	var railway := gallery.get_node_or_null("ArtCastleFloatingWorld/StoryCrownRailway") as Node3D
	var train := railway.get_node_or_null("RainbowGalaxyTrain") as Node3D if railway != null else null
	if train != null:
		train.visible = false
	for label_candidate in gallery.find_children("*", "Label3D", true, false):
		(label_candidate as Label3D).visible = false
	var camera := gallery.get_node("Camera3D") as Camera3D
	camera.set_script(null)
	camera.global_position = Vector3(10.0, 13.0, 31.0)
	camera.look_at(Vector3(-21.5, 3.5, 15.0), Vector3.UP)
	await _save("res://artifacts/art_castle_galaxy_transit.png")
	# The embedded floating world is offset by z=-480, so Gallery Station's
	# authored (260, 28, 820) position is global (260, 28, 340).
	camera.fov = 58.0
	camera.global_position = Vector3(174.0, 62.0, 286.0)
	camera.look_at(Vector3(250.0, 35.0, 340.0), Vector3.UP)
	await _save("res://artifacts/rainbow_station_bio_magitech_hero.png")
	camera.fov = 62.0
	camera.global_position = Vector3(260.0, 45.0, 257.0)
	camera.look_at(Vector3(260.0, 35.0, 340.0), Vector3.UP)
	await _save("res://artifacts/rainbow_station_bio_magitech_side.png")
	camera.fov = 64.0
	camera.global_position = Vector3(166.0, 18.0, 340.0)
	camera.look_at(Vector3(250.0, 34.0, 340.0), Vector3.UP)
	await _save("res://artifacts/rainbow_station_player_approach.png")
	camera.fov = 55.0
	camera.global_position = Vector3(118.0, 58.0, 410.0)
	camera.look_at(Vector3(218.0, 33.0, 340.0), Vector3.UP)
	await _save("res://artifacts/rainbow_station_blueprint_match.png")
	gallery.queue_free()
	await process_frame

	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _i in 50:
		await process_frame
	for node in hub.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = false
	var inspect := Camera3D.new()
	inspect.fov = 68.0
	hub.add_child(inspect)
	inspect.make_current()
	inspect.global_position = Vector3(-5.0, 55.0, -8.0)
	inspect.look_at(Vector3(-31.0, 50.0, 13.0), Vector3.UP)
	await _save("res://artifacts/castle_stair_clearance.png")
	print("GALAXY_CAPTURE: PASS")
	quit()


func _save(path: String) -> void:
	for _i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("GALAXY_CAPTURE: failed %s" % path)
