extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://scenes/heart_melody/heart_melody_world.tscn").instantiate()
	world.test_mode = true
	world.progress.path = "user://capture_heart_unused.json"
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(world.progress.path + suffix))
	root.add_child(world)
	current_scene = world
	for i in 60: await process_frame
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 180:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	var guide_triangles := 0
	for child in world.get_node("IslandOne").get_children():
		if child.get_script() == load("res://scripts/mind_spark/mind_spark_shared_guide.gd"): guide_triangles += count_triangles(child)
	var family_max := {"tree": 0, "planter": 0}
	for child in world.find_children("*", "Node3D", true, false):
		if child.has_meta("art_family"):
			var family: String = child.get_meta("art_family")
			family_max[family] = maxi(family_max[family], count_triangles(child))
	var player_triangles := count_triangles(world.player)
	var companion_triangles := count_triangles(world.get_node("WonderfulCounsellorMilo")) if world.has_node("WonderfulCounsellorMilo") else 0
	var metrics := {"cpu": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "resolution": str(root.size), "sample_frames": samples.size(), "median_ms": samples[90], "p95_ms": samples[171], "static_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "environment_triangles": count_triangles(world) - guide_triangles - player_triangles - companion_triangles, "shared_guides_triangles": guide_triangles, "player_triangles": player_triangles, "companion_triangles": companion_triangles, "largest_family_triangles": family_max, "drum_flower_triangles": count_triangles(world.drums[0])}
	var report := FileAccess.open("res://../work/heart-performance.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(metrics, "  "))
	report.close()
	print("HEART PERFORMANCE ", metrics)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../work/heart-arrival.png")
	world._planter(0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../work/heart-planter.png")
	world._close()
	for i in 3: world.progress.plant(i, 6)
	world._refresh_plants()
	world.player.position = Vector3(7, 1, 9)
	world._camera_update(1)
	world._phrase_panel()
	world._camera_update(1)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../work/heart-phrase.png")
	world.progress.edit_phrase([0, 2, 1])
	world.progress.solve()
	world.progress.clear_wave(1)
	world.progress.clear_wave(2)
	world._apply_restoration()
	world._close()
	world.player.position = Vector3(75, 1, 8)
	world._camera_update(1)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../work/heart-overlook.png")
	world.queue_free()
	quit()

func count_triangles(node: Node) -> int:
	var count := 0
	if node is MeshInstance3D and node.mesh: count += node.mesh.get_faces().size() / 3
	for child in node.get_children(): count += count_triangles(child)
	return count
