extends SceneTree
func _init() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280, 800)
	change_scene_to_file("res://scenes/art_gallery_3d_inprogress.tscn")
	await process_frame
	await process_frame
	var scene = current_scene
	var connection = scene.find_child("StoryCrownRailway", true, false).get_node("HeartMelodyConnection")
	var world = connection.island
	world.test_mode = true
	world.player.global_position = connection.to_global(connection.WALK_START + Vector3.UP * 2)
	world.player.velocity = Vector3.ZERO
	for frame in 75: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../work/milo-guide-station.png")
	world.milo_guide.stop()
	world.milo_guide._gap = 0
	world.player.global_position = world.to_global(Vector3(-65, 2, 12))
	for frame in 75:
		if world.modal_open: world._close()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../work/milo-guide-garden.png")
	print("MILO GUIDANCE CAPTURE: PASS")
	quit()
