extends SceneTree

# Actual gallery scene, fixed camera, native Compatibility throughput benchmark.
# One timestamp per rendered frame (not process_frame + frame_post_draw pairs).
# Does not certify Web/mobile or input-driven traversal.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 180:
		await RenderingServer.frame_post_draw
	var maps: Array[Node] = []
	for node in scene.find_children("*", "Control", true, false):
		var script := node.get_script() as Script
		if script != null and script.resource_path.ends_with("art_castle_minimap.gd"):
			maps.append(node)
	if "--no-map" in OS.get_cmdline_user_args():
		for map in maps:
			map.set_process(false)
	for i in 30:
		await RenderingServer.frame_post_draw
	var samples: Array[float] = []
	var process_samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 600:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		previous = now
	samples.sort()
	process_samples.sort()
	var total := 0.0
	for value in samples: total += value
	print("RENDER_PACING: maps=%d map_updates=%s frames=%d mean_ms=%.3f p50_ms=%.3f p95_ms=%.3f p99_ms=%.3f process_p50_ms=%.3f draw_calls=%d" % [
		maps.size(), not "--no-map" in OS.get_cmdline_user_args(), samples.size(),
		total / samples.size(), samples[300], samples[570], samples[594], process_samples[300],
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	quit()
