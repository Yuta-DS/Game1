extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const STORE := "user://weight_benchmark_test.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STORE
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for frame in 8:
		await physics_frame
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	var control := puzzle.get_node("PuzzleControls/PuzzleControl_weight_prism") as Node3D
	var art := control.get_node("WeightPrismBenchmark") as Node3D
	var beam := art.find_child("BalanceBeam", true, false) as Node3D
	var left := art.find_child("ChamberLeft", true, false) as Node3D
	var right := art.find_child("ChamberRight", true, false) as Node3D
	for choice in 3:
		assert(puzzle.interact_control("weight_prism").accepted)
		await create_timer(0.55).timeout
		var expected: float = [-0.12, 0.0, 0.12][choice]
		assert(is_equal_approx(beam.rotation.z, expected), "Beam must reflect the selected seed")
		assert(left.global_basis.y.normalized().dot(Vector3.UP) > 0.999,
			"Left chamber remains upright during balance motion")
		assert(right.global_basis.y.normalized().dot(Vector3.UP) > 0.999,
			"Right chamber remains upright during balance motion")
	# Superseded animations must not overwrite the newest player choice.
	for press in 5:
		assert(puzzle.interact_control("weight_prism").accepted)
	await create_timer(0.55).timeout
	var final_choice := int(puzzle.current_state.weight_prism)
	assert(is_equal_approx(beam.rotation.z, [-0.12, 0.0, 0.12][final_choice]))
	art.call("set_choice", -1, false)
	puzzle.call("_apply_state", false)
	assert(is_equal_approx(beam.rotation.z, [-0.12, 0.0, 0.12][final_choice]),
		"Restoring saved state restores the same art pose")
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1200, 900)
		# Reuse the real containing scene's lighting without building another world.
		var containing_scene := load("res://scenes/art_castle_floating_world.tscn") as PackedScene
		var containing := containing_scene.instantiate()
		for light_name in ["WorldEnvironment", "Sun", "FillLight"]:
			var light_node := containing.get_node(light_name)
			containing.remove_child(light_node)
			light_node.owner = null
			root.add_child(light_node)
		containing.free()
		var camera := Camera3D.new()
		camera.fov = 48
		world.add_child(camera)
		camera.global_position = control.to_global(Vector3(-11, 4.0, -0.5))
		camera.look_at(control.to_global(Vector3(0, 2.9, 0)))
		camera.make_current()
		await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(
			"res://assets3D/mind_spark/quest_kit/weight_prism/previews/in_game.png")
	print("WEIGHT_BENCHMARK: PASS — all choices, upright chambers, rapid input, state restoration")
	world.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	quit()
