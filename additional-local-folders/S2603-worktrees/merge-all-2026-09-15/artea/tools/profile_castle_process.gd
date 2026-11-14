extends SceneTree

# Attribute the castle's per-frame CPU time to the scripts causing it.
#
# The render monitors say the castle issues only ~369 draw calls but spends
# ~16 ms of a ~16 ms frame inside TIME_PROCESS, so the cost is script work, not
# drawing. This disables each processing node in turn and reports what the frame
# gets back, which attributes the time without needing an external profiler.

const TARGET := "res://scenes/art_gallery_3d_inprogress.tscn"
const SAMPLE_FRAMES := 40


func _initialize() -> void:
	var scene := (load(TARGET) as PackedScene).instantiate()
	root.add_child(scene)
	for _i in 60:
		await process_frame

	var processing: Array[Node] = []
	var stack: Array = [scene]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node.get_script() == null:
			continue
		if node.is_processing() or node.is_physics_processing():
			processing.append(node)

	print("nodes with _process/_physics_process and a script: ", processing.size())
	var baseline := await _measure()
	print("baseline: %s" % _fmt(baseline))
	print("")

	# Group by script, since the interesting unit is "which system costs this",
	# not "which of 40 identical nodes".
	var by_script: Dictionary = {}
	for node in processing:
		var path := str((node.get_script() as Script).resource_path)
		if not by_script.has(path):
			by_script[path] = []
		(by_script[path] as Array).append(node)

	var rows: Array = []
	for path in by_script:
		var nodes: Array = by_script[path]
		for node in nodes:
			(node as Node).set_process(false)
			(node as Node).set_physics_process(false)
		var without := await _measure()
		for node in nodes:
			(node as Node).set_process(true)
			(node as Node).set_physics_process(true)
		await _measure()
		rows.append([path.get_file(), nodes.size(),
			baseline["process"] - without["process"],
			baseline["frame"] - without["frame"]])

	rows.sort_custom(func(a, b): return a[2] > b[2])
	print("%-46s %6s %14s %14s" % ["script", "nodes", "process saved", "frame saved"])
	for row in rows:
		print("%-46s %6d %11.2f ms %11.2f ms" % row)
	quit()


func _measure() -> Dictionary:
	# Let the change settle before sampling.
	for _i in 8:
		await process_frame
	var frame_total := 0.0
	var process_total := 0.0
	for _i in SAMPLE_FRAMES:
		var start := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		frame_total += float(Time.get_ticks_usec() - start) / 1000.0
		process_total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	return {
		"frame": frame_total / float(SAMPLE_FRAMES),
		"process": process_total / float(SAMPLE_FRAMES),
	}


func _fmt(m: Dictionary) -> String:
	return "frame %6.2f ms   process %6.2f ms" % [m["frame"], m["process"]]
