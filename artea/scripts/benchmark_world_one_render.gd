extends SceneTree

# Native Compatibility benchmark for the four matched player-height review views.
# It measures consecutive rendered frames with VSync disabled. The result is a
# stable local regression signal; it does not substitute for Web/mobile profiling.
const STATE_PATH := "user://benchmark_world_one_render.json"
const WARMUP_FRAMES := 90
const SAMPLE_FRAMES := 240


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1400, 788)
	root.msaa_3d = Viewport.MSAA_4X
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)

	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") \
		as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STATE_PATH
	world.get_node("QuestController").enabled = false
	stage.add_child(world)
	world.set_island_two_story_state("truth_materialised")
	world.set_quest_gate_open(1, true)
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false

	var containing := load("res://scenes/art_castle_floating_world.tscn").instantiate() as Node3D
	for node_name in ["WorldEnvironment", "Sun", "FillLight"]:
		var node := containing.get_node(node_name)
		containing.remove_child(node)
		node.owner = null
		stage.add_child(node)
	containing.free()

	var camera := Camera3D.new()
	camera.near = .1
	camera.far = 5000.0
	camera.fov = 62.0
	stage.add_child(camera)
	camera.make_current()

	var island_one_hero := world.find_child("EchoGardenHeroBenchmark", true, false) as Node3D
	var evidence := world.get_object_by_kind(QuestObjectDefinition.ObjectKind.EVIDENCE_SCANNER)
	assert(island_one_hero != null and evidence != null)
	var views := [
		["island_one_tree_court", island_one_hero.global_position + Vector3(50, 6, 100),
			island_one_hero.global_position + Vector3(0, 18, 0)],
		["island_two_evidence_court", evidence.to_global(Vector3(0, 5.5, 23)),
			evidence.to_global(Vector3(0, 4.2, 0))],
		["island_three_stormworks", Vector3(300, 27, 28), Vector3(430, 35, 25)],
		["island_three_reflection", Vector3(520, 27, 15), Vector3(650, 34, -58)],
	]

	print("WORLD_ONE_RENDER_SCENE: nodes=%d mesh_instances=%d multimeshes=%d batched_groups=%d removed=%d repeated_groups=%d repeated_sources=%d merged_groups=%d merged_sources=%d ranged_meshes=%d" % [
		_count_nodes(world),
		world.find_children("*", "MeshInstance3D", true, false).size(),
		world.find_children("*", "MultiMeshInstance3D", true, false).size(),
		int(world.get_meta("batched_geometry_groups", 0)),
		int(world.get_meta("batched_geometry_nodes_removed", 0)),
		int(world.get_meta("batched_static_render_groups", 0)),
		int(world.get_meta("batched_static_render_sources", 0)),
		int(world.get_meta("merged_static_render_groups", 0)),
		int(world.get_meta("merged_static_render_sources", 0)),
		int(world.get_meta("distance_culled_mesh_count", 0)),
	])
	for view in views:
		camera.global_position = view[1]
		camera.look_at(view[2], Vector3.UP)
		for frame in WARMUP_FRAMES:
			await RenderingServer.frame_post_draw
		await _measure_view(view[0])

	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)
	quit()


func _measure_view(view_name: String) -> void:
	var frame_ms: Array[float] = []
	var draw_total := 0.0
	var primitive_total := 0.0
	var previous := Time.get_ticks_usec()
	for frame in SAMPLE_FRAMES:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		frame_ms.append((now - previous) / 1000.0)
		previous = now
		draw_total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitive_total += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	frame_ms.sort()
	var total := 0.0
	for value in frame_ms:
		total += value
	print("WORLD_ONE_RENDER: view=%s frames=%d mean_ms=%.3f p50_ms=%.3f p95_ms=%.3f p99_ms=%.3f mean_draws=%.1f mean_primitives=%.0f" % [
		view_name, SAMPLE_FRAMES, total / SAMPLE_FRAMES,
		frame_ms[SAMPLE_FRAMES / 2], frame_ms[int(SAMPLE_FRAMES * .95)],
		frame_ms[int(SAMPLE_FRAMES * .99)], draw_total / SAMPLE_FRAMES,
		primitive_total / SAMPLE_FRAMES,
	])


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count
