extends SceneTree

const STORE := "user://test_island_two_memory_benchmark.json"
const WORLD := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var world := WORLD.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STORE
	world.get_node("QuestController").enabled = false
	root.add_child(world)
	for frame in 6:
		await process_frame
	var board: QuestObjectBase
	for object in world.get_quest_objects():
		if object.save_id == "world_one.memory_board":
			board = object
	assert(board != null)
	assert(board.get_meta("preserve_authored_nodes", false))
	board.interaction_enabled = true
	var model := board.get_node("VisualRoot/BlenderModel")
	assert(model.get_meta("memory_board_benchmark", false))
	assert(model.find_children("*", "MeshInstance3D", true, false).size() == 7)
	assert(not board.call("_find_blender_part", "Link0").visible)
	assert(board.interact(&"node", "choose").reason == "wrong_link_reset")
	assert(board.interact(&"node", "notice").progress == 1)
	assert(board.call("_find_blender_part", "NodeCap0").get_meta("selected"))
	assert(not board.call("_find_blender_part", "NodeCap1").get_meta("selected"))
	assert(board.interact(&"node", "name").progress == 2)
	assert(board.call("_find_blender_part", "Link0").visible)
	assert(not board.call("_find_blender_part", "Link1").visible)
	assert(board.interact(&"reset").accepted)
	assert(not board.call("_find_blender_part", "Link0").visible)
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(world, board, "dormant")
	for node in ["notice", "name", "choose"]:
		assert(board.interact(&"node", node).accepted)
	assert(board.current_state.completed)
	assert(board.call("_find_blender_part", "Link1").visible)
	assert(board.call("_find_blender_part", "RewardSeal").visible)
	for geometry in board.get_node("VisualRoot").find_children("*", "GeometryInstance3D", true, false):
		if not model.is_ancestor_of(geometry):
			assert(not geometry.visible, "Legacy surfaces cannot overlap the benchmark")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(world, board, "complete")
	board.configure(board.definition, board.save_id, STORE)
	assert(board.current_state.completed)
	assert(board.call("_find_blender_part", "RewardSeal").visible)
	assert(board.interact().reason == "already_complete")
	world.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	print("ISLAND_TWO_MEMORY_BENCHMARK: PASS — seven meshes, wrong choice, node poses, links, reset, completion and restore")
	quit()

func _capture(world: Node3D, board: Node3D, phase: String) -> void:
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_4X
	if root.get_node_or_null("WorldEnvironment") == null:
		var containing := load("res://scenes/art_castle_floating_world.tscn").instantiate() as Node3D
		for name in ["WorldEnvironment", "Sun", "FillLight"]:
			var light := containing.get_node(name)
			containing.remove_child(light)
			light.owner = null
			root.add_child(light)
		containing.free()
	var camera := Camera3D.new()
	camera.fov = 48
	world.add_child(camera)
	camera.global_position = board.to_global(Vector3(0, 1.7, 3.4))
	camera.look_at(board.to_global(Vector3(0, .95, 0)))
	camera.make_current()
	for frame in 20:
		await process_frame
	RenderingServer.force_draw(false)
	var output := "res://assets3D/mind_spark/quest_kit/memory_board/previews/" + phase + ".png"
	assert(root.get_texture().get_image().save_png(output) == OK)
	camera.queue_free()
	await process_frame
