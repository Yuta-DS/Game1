extends "res://scripts/capture_mind_spark_islands_v11.gd"

const OUTPUT := "res://artifacts/hope_viaduct_v17"


func save_view(name: String) -> void:
	for _frame in 12:
		await process_frame
	# Headless Godot 4.7 can miss frame_post_draw when the render completed
	# before this coroutine connected. Force and consume a fresh frame instead.
	RenderingServer.force_draw(false)
	await process_frame
	assert(root.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK)
	print("DAWN_V17_CAPTURE: " + name)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1800, 1500)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var stage := Node3D.new()
	root.add_child(stage)
	_lighting(stage)
	stage.add_child((load("res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb") as PackedScene).instantiate())
	stage.add_child((load("res://assets3D/mind_spark/celestial_dawn_v17/island_04.glb") as PackedScene).instantiate())
	var camera := _camera(stage, 3.8, Vector3(2.4, 1.15, 4.7), Vector3(0, -0.82, 0))
	await save_view("01_dawn_wing_viaduct")
	camera.size = 2.45
	camera.position = Vector3(2.7, -0.25, 2.7)
	camera.look_at(Vector3(0, -1.05, -0.24))
	await save_view("02_lift_engine_and_wings")
	stage.queue_free()
	await process_frame
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_dawn_v17.json"
	root.add_child(world)
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).hide()
	_lighting(world)
	var centre := world.get_zone_position("04_hope_path_ridge")
	var camera_world := _camera(world, 120.0 * 4.0,
		centre + Vector3(-1.7, 1.05, -3.0) * 120.0,
		centre + Vector3(0, -78, 0))
	camera_world.near = 0.1
	camera_world.far = 8000
	await save_view("03_hope_path_in_game")
	camera_world.size = 150
	camera_world.position = centre + Vector3(150, 115, 170)
	camera_world.look_at(centre + Vector3(0, 14, 28))
	await save_view("05_above_ground_celestial_court")
	camera_world.size = 82
	camera_world.position = centre + Vector3(92, 38, -92)
	camera_world.look_at(centre + Vector3(0, 13, 40))
	await save_view("06_aether_lift_pavilion")
	var player := (load("res://scenes/player_3d.tscn") as PackedScene).instantiate() as CharacterBody3D
	world.add_child(player)
	player.set_physics_process(false)
	player.position = centre + Vector3(116, 1.1, 0)
	(player.get_node("MeshInstance3D") as MeshInstance3D).position = Vector3.ZERO
	camera_world.size = 13
	camera_world.position = centre + Vector3(110, 5, 8)
	camera_world.look_at(centre + Vector3(118, 1.5, 0))
	await save_view("04_player_scale_guard")
	quit()
