extends SceneTree
func _init() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/art_gallery_3d_inprogress.tscn")
	await process_frame
	await process_frame
	var gallery = current_scene
	var connection = gallery.find_child("StoryCrownRailway", true, false).get_node("HeartMelodyConnection")
	var world = connection.island
	world.test_mode = true
	var player = world.player
	for spec in [[Vector3(1500, 4, 7640), "court"], [Vector3(1500, 30, 7570), "slope"], [Vector3(146, 1, 3), "organ"], [Vector3(-60, 1, 12), "guides"]]:
		player.global_position = connection.to_global(spec[0]) if spec[1] in ["court", "slope"] else world.to_global(spec[0])
		player.velocity = Vector3.ZERO
		for frame in 90:
			if world.modal_open: world._close()
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../work/report-fix-" + spec[1] + ".png")
	print("REPORT FIX CAPTURES: PASS")
	quit()
