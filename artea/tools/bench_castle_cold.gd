extends SceneTree

# Reproducible cold-entry benchmark for the Art Castle. Run in a fresh process
# with .godot/shader_cache removed, so the numbers are what a player actually
# gets on a cold entry rather than what a warmed editor session reports.
#
#   --  phase 1: enter the castle the way the game does (loading screen)
#   --  phase 2: stand still and record frame times
#   --  phase 3: walk the player out north into the world, recording frame
#               times as the streaming director reveals cells
#
# Phase 3 is the one that matters for judging the two changes together: culling
# only pays off if revealing a cell is cheap, and revealing a cell is only cheap
# if its shaders were compiled up front.
#
# Set ARTEA_BENCH_NO_WARMUP=1 / ARTEA_BENCH_NO_CULL=1 to disable either change
# and get the baseline to compare against.

const SceneLoader = preload("res://scripts/scene_loader.gd")

const TARGET := "res://scenes/art_gallery_3d_inprogress.tscn"
const WALK_STEPS := 60
const WALK_TO := Vector3(0.0, 30.0, -900.0)


func _initialize() -> void:
	var no_warmup := OS.get_environment("ARTEA_BENCH_NO_WARMUP") == "1"
	var no_cull := OS.get_environment("ARTEA_BENCH_NO_CULL") == "1"
	print("=== cold castle benchmark (warmup=%s cull=%s) ===" % [
		"off" if no_warmup else "on", "off" if no_cull else "on"])

	if no_warmup:
		# Skipping the warmup is what the build did before; emulate it by
		# telling the loading screen there is nothing to warm.
		Engine.set_meta("artea_skip_shader_warmup", true)

	var start := Time.get_ticks_msec()
	SceneLoader.change_scene_with_loading(self, TARGET)
	var loading_ms := await _wait_for_loading_screen()
	print("load (loading screen up -> handover): %d ms" % loading_ms)
	print("total from request to playable      : %d ms" % (Time.get_ticks_msec() - start))

	var castle := current_scene
	if castle == null:
		print("FAILED: no castle scene")
		quit(1)
		return
	var director := castle.find_child("WorldStreamingDirector", true, false)
	if director != null and no_cull:
		director.set_process(false)
		director.call("show_all_managed_cells")
		for _i in 10:
			await process_frame

	# Phase 2 -- standing still.
	var idle := await _record(90)
	print("idle       : %s   visible instances %d" % [_summary(idle), _visible_count(castle)])
	print("             %s" % _monitors())

	# Phase 3 -- walking out of the castle into the world.
	var player := castle.get_node_or_null("Player3D") as Node3D
	if player == null:
		print("FAILED: no player")
		quit(1)
		return
	var from := player.global_position
	var worst := 0.0
	var samples: Array[float] = []
	for step in WALK_STEPS:
		player.global_position = from.lerp(WALK_TO, float(step) / float(WALK_STEPS - 1))
		var frame := await _one_frame()
		samples.append(frame)
		worst = maxf(worst, frame)
	print("walking out: %s   visible instances %d" % [_summary(samples), _visible_count(castle)])
	print("             %s" % _monitors())
	if director != null:
		print("director   : %d cells, %d visible" % [
			director.call("get_cell_count"), director.call("get_visible_cell_count")])
	quit()


func _wait_for_loading_screen() -> int:
	var start := Time.get_ticks_msec()
	var deadline := start + 120000
	# The loading screen frees itself when it hands over.
	var seen := false
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var found := false
		for child in root.get_children():
			var child_script := child.get_script() as Script
			if child_script != null and str(child_script.resource_path).ends_with("loading_scene.gd"):
				found = true
				break
		if found:
			seen = true
		elif seen:
			break
	return Time.get_ticks_msec() - start


func _one_frame() -> float:
	var start := Time.get_ticks_usec()
	await process_frame
	await RenderingServer.frame_post_draw
	return float(Time.get_ticks_usec() - start) / 1000.0


func _record(count: int) -> Array[float]:
	var samples: Array[float] = []
	for _i in count:
		samples.append(await _one_frame())
	return samples


func _summary(samples: Array[float]) -> String:
	if samples.is_empty():
		return "no samples"
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	var p95: float = sorted[clampi(int(float(sorted.size()) * 0.95), 0, sorted.size() - 1)]
	return "mean %6.2f ms  median %6.2f ms  p95 %6.2f ms  worst %7.2f ms" % [
		total / float(sorted.size()), sorted[sorted.size() / 2], p95, sorted[sorted.size() - 1]]


## What the renderer itself reports. On a desktop GPU the frame time is not
## draw-call bound, so these are the numbers that actually say whether the
## culling is doing its job -- a WebGL2 context pays far more per draw call than
## this machine does.
func _monitors() -> String:
	return "draw calls %5d  primitives %9d  process %5.2f ms  physics %5.2f ms" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0]


func _visible_count(scene: Node) -> int:
	var total := 0
	var stack: Array = [scene]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is VisualInstance3D and not (n is Light3D) and (n as Node3D).is_visible_in_tree():
			total += 1
	return total
