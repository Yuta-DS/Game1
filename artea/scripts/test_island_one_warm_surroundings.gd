extends SceneTree

const STORE := "user://test_island_one_warm_surroundings.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STORE
	world.get_node("QuestController").enabled = false
	root.add_child(world)
	for frame in 8:
		await process_frame
	var materials: Dictionary = world.get("_materials")
	assert(materials.gold.albedo_color.is_equal_approx(Color("f0c85a")), "Other islands retain shared gold")
	assert(materials.cyan.albedo_color.is_equal_approx(Color("2cd7e8")), "Other islands retain shared cyan")
	world.set_world_state("waking")
	assert(is_equal_approx(materials.gold.emission_energy_multiplier, 1.05), "World-state lighting remains functional")
	world.set_world_state("sleeping")
	for name in ["HighHeavenlyArrivalLight", "HighPuzzleCompositionLight", "ElevatedTreeCrownLight"]:
		var light := world.find_child(name, true, false) as OmniLight3D
		assert(light != null and light.light_energy <= 1.15)
		assert(light.position.y >= 36.0, "Preserve elevated light placement")
	var puzzle := world.get_island_one_puzzle()
	assert(puzzle.find_children("QuestPurposeLabel", "Label3D", true, false).size() == 16)
	for label in puzzle.find_children("QuestPurposeLabel", "Label3D", true, false):
		assert(label.visibility_range_end == 28.0)
		assert(label.font_size == 42 and is_equal_approx(label.pixel_size, 0.008))
		assert(label.outline_size == 14 and bool(label.get_meta("player_camera_readable", false)))
	var refined := 0
	for mesh in world.find_children("*", "GeometryInstance3D", true, false):
		var material := mesh.material_override as StandardMaterial3D
		if material != null and material.albedo_color.is_equal_approx(Color("c5a366")) and not material.emission_enabled:
			refined += 1
	assert(refined > 0, "Local scenery finish survives static batching")
	assert(not puzzle.interact_control("echo_beacon").accepted)
	if "--capture" in OS.get_cmdline_user_args():
		await _capture(world, puzzle)
	print("ISLAND_ONE_WARM_SURROUNDINGS: PASS — local finishes, shared palette preserved, high lights, 16 labels, locked beacon")
	world.queue_free()
	await process_frame
	if FileAccess.file_exists(STORE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE))
	quit()

func _capture(world: Node3D, puzzle: Node3D) -> void:
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_4X
	var containing := load("res://scenes/art_castle_floating_world.tscn").instantiate() as Node3D
	for name in ["WorldEnvironment", "Sun", "FillLight"]:
		var light := containing.get_node(name)
		containing.remove_child(light)
		light.owner = null
		root.add_child(light)
	containing.free()
	var camera := Camera3D.new()
	camera.fov = 58.0
	world.add_child(camera)
	camera.make_current()
	var output := "res://artifacts/island_one_warm_surroundings"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for id in ["weight_prism", "echo_question", "middle_ring"]:
		var control := puzzle.get_node("PuzzleControls/PuzzleControl_%s" % id) as Node3D
		# Inspect from the real interaction distance. The broad imported shrub
		# batch used to fill this frame; keeping this close composition makes the
		# capture a regression image for both the machine and its readable label.
		camera.global_position = control.to_global(Vector3(-7.5, 3.2, -0.3))
		camera.look_at(control.to_global(Vector3(0, 2.9, 0)))
		await create_timer(1.0).timeout
		for frame in 12:
			await process_frame
		RenderingServer.force_draw(false)
		assert(root.get_texture().get_image().save_png(output + "/" + id + ".png") == OK)
	assert(camera.environment != null)
	assert(camera.environment.ambient_light_color.is_equal_approx(Color("f0dfc8")))
	camera.global_position += Vector3(10000, 10000, 10000)
	await create_timer(1.0).timeout
	assert(camera.environment == null, "Restore original camera environment outside Island One")
	assert(is_equal_approx(root.get_node("Sun").light_energy,1.25),"Restore shared sunlight after leaving Island One")
	assert(is_equal_approx(root.get_node("FillLight").light_energy,.32),"Restore shared fill light")
