extends SceneTree

const Progress = preload("res://scripts/heart_melody/heart_progress.gd")
const Music = preload("res://scripts/heart_melody/musical_fruit_catalog.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var world = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
	world.test_mode = true
	world.progress.path = "res://../work/heart-musical-capture-save.json"
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(world.progress.path + suffix))
	root.add_child(world)
	current_scene = world
	for frame in 45: await process_frame
	if world.modal_open: world._close()

	# Native frame-time sample after all procedural geometry has settled.
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for frame in 180:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
	samples.sort()
	var player_triangles := count_triangles(world.player)
	var musical_triangles := count_triangles(world.musical_garden)
	var metrics := {
		"cpu": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "resolution": str(root.size),
		"sample_frames": samples.size(), "median_ms": samples[90], "p95_ms": samples[171],
		"static_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"scene_triangles": count_triangles(world), "musical_garden_triangles": musical_triangles,
		"player_triangles": player_triangles, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	}
	var report := FileAccess.open("res://../work/heart-musical-performance.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics, "  ")); report.close()
	print("HEART MUSICAL PERFORMANCE ", metrics)

	# Arrival: normal gameplay camera and readable objective/basket HUD.
	world.player.position = Vector3(-65, 2, 12)
	world._camera_update(1.0)
	await _capture("res://../work/heart-musical-arrival.png")
	# Manual documentation views must not be replaced by the gameplay follow
	# camera during the settling frames used by _capture().
	world.set_process(false)

	# Orchard: wide view makes all four large fruit silhouettes legible.
	world.camera.global_position = Vector3(-51, 39, 10)
	world.camera.look_at(Vector3(-50, 4, -23))
	world.get_node("HeartHUD").hide()
	await _capture("res://../work/heart-musical-orchard.png")

	# Instrument gardens: marimba and harp silhouettes with the waterfall terrace.
	world.camera.global_position = Vector3(-5, 21, 6)
	world.camera.look_at(Vector3(-6, 2, -32))
	await _capture("res://../work/heart-musical-instruments.png")

	# Connected route: the permanent flowering root walk keeps both river banks
	# explorable while the Rain Boat remains beside it as an optional activity.
	world.camera.global_position = Vector3(202, 42, 48)
	world.camera.look_at(Vector3(202, 0, -5))
	await _capture("res://../work/heart-connected-root-walk.png")

	# Bell Grove's three chime decks remain one continuous safe footpath even
	# before their musical restoration responses have been completed.
	world.camera.global_position = Vector3(280, 36, 52)
	world.camera.look_at(Vector3(280, 0, 8))
	await _capture("res://../work/heart-connected-bell-walk.png")

	# Complete the local music sequence without touching campaign treasures.
	for fruit_id in Music.FRUIT_ORDER: world.progress.discover_fruit(fruit_id)
	world.progress.set_music_phrase("flowers", Music.FLOWER_PHRASE)
	world.progress.complete_music_activity(Music.ACTIVITY_ORCHARD)
	world.progress.complete_music_activity(Music.ACTIVITY_FLOWERS)
	world.progress.set_music_phrase("marimba", Music.MARIMBA_PHRASE)
	world.progress.complete_music_activity(Music.ACTIVITY_MARIMBA)
	world.progress.set_music_phrase("bells", [Music.BELL_MISSING_NOTE])
	world.progress.complete_music_activity(Music.ACTIVITY_BELLS)
	world.progress.complete_music_activity(Music.ACTIVITY_ENSEMBLE)
	world.musical_garden.refresh()
	world._process(0.0)
	world.camera.global_position = Vector3(54, 25, 70)
	world.camera.look_at(Vector3(30, 2, 43))
	await _capture("res://../work/heart-musical-ensemble.png")

	world.queue_free()
	await process_frame
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path("res://../work/heart-musical-capture-save.json" + suffix))
	quit()

func _capture(path: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func count_triangles(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D and node.mesh: count += node.mesh.get_faces().size() / 3
	for child in node.get_children(): count += count_triangles(child)
	return count
