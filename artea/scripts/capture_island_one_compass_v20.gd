extends "res://scripts/capture_mind_spark_islands_v11.gd"

const OUTPUT := "res://artifacts/island_one_compass_v20"
const CAPTURE_STATE := "user://capture_island_one_compass_v20.json"


func _save_view(name: String) -> void:
	for _frame in 12:
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	assert(root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK)
	print("ISLAND_ONE_V20_CAPTURE: " + name)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1800, 1400)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	if FileAccess.file_exists(CAPTURE_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAPTURE_STATE))
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = CAPTURE_STATE
	var quest := world.get_node("QuestController") as MindSparkWorldOneQuest
	quest.enabled = false
	root.add_child(world)
	for _frame in 4:
		await process_frame
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).hide()
	_lighting(world)
	var centre := world.get_zone_position("01_world_gate_landing")
	var camera := _camera(world, 245.0,
		centre + Vector3(185, 150, 235), centre + Vector3(0, -22, 8))
	camera.near = 0.1
	camera.far = 8000.0
	await _save_view("01_island_one_aether_station")
	var compass := world.get_island_one_puzzle()
	var canopy := compass.get_node("TriangulatedAetherConservatory") as Node3D
	canopy.hide()
	for label in compass.get_node("PuzzleControls").find_children("*", "Label3D", true, false):
		(label as Label3D).show()
	camera.size = 76.0
	camera.position = centre + Vector3(66, 82, 78)
	camera.look_at(centre + Vector3(0, 3, 12))
	await _save_view("02_three_ring_aether_compass")
	camera.size = 48.0
	camera.position = centre + Vector3(82, 24, 20)
	camera.look_at(centre + Vector3(42, 8, -13))
	await _save_view("03_twin_pressure_regulators")
	canopy.show()
	for label in compass.get_node("PuzzleControls").find_children("*", "Label3D", true, false):
		(label as Label3D).hide()
	assert(compass.solve_for_test().reason == "completed")
	for _frame in 24:
		await process_frame
	camera.size = 96.0
	camera.position = centre + Vector3(68, 56, 118)
	camera.look_at(centre + Vector3(0, 5, 30))
	await _save_view("04_solved_bridge_power_and_sigil")
	if FileAccess.file_exists(CAPTURE_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAPTURE_STATE))
	quit()
