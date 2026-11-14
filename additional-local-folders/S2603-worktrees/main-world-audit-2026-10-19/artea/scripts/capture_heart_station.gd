extends SceneTree

func _init() -> void: _run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("JourneyState").treasures["star_of_wisdom"] = true
	change_scene_to_file("res://scenes/art_gallery_3d_inprogress.tscn")
	await process_frame
	await process_frame
	var gallery = current_scene
	var railway = gallery.find_child("StoryCrownRailway", true, false)
	var connection = railway.get_node("HeartMelodyConnection")
	var island = connection.island
	island.test_mode = true
	var player = gallery.get_node("Player3D")
	player.global_position = connection.to_global(connection.walk_points[connection.walk_points.size() / 2] + Vector3.UP * 2)
	for frame in 12: await process_frame
	var camera := Camera3D.new()
	gallery.add_child(camera)
	camera.far = 16000
	camera.global_position = connection.to_global(Vector3(1660, 180, 7800))
	camera.look_at(connection.to_global(Vector3(1460, 30, 7520)))
	camera.make_current()
	for layer in gallery.find_children("*", "CanvasLayer", true, false): layer.hide()
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../work/heart-station-overview.png")
	player.global_position = island.to_global(Vector3(-65, 2, 12))
	for frame in 30: await process_frame
	if island.modal_open: island._close()
	island.camera.make_current()
	island.get_node("HeartHUD").show()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../work/heart-station-arrival.png")
	print("HEART STATION CAPTURE: complete")
	quit()
