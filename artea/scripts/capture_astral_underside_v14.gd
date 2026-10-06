extends "res://scripts/capture_mind_spark_islands_v11.gd"

const ASTRAL_OUT := "res://artifacts/astral_underside_v14"


func _save(name: String) -> void:
	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(ASTRAL_OUT + "/" + name + ".png") == OK)
	print("ASTRAL_V14_CAPTURE: " + name)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1800, 1600)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ASTRAL_OUT))
	var stage := Node3D.new()
	root.add_child(stage)
	_lighting(stage)
	stage.add_child((load("res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb") as PackedScene).instantiate())
	stage.add_child((load("res://assets3D/mind_spark/celestial_astral_v14/island_03.glb") as PackedScene).instantiate())
	var camera := _camera(stage, 4.15, Vector3(1.8,.95,5.0), Vector3(0,-.77,0))
	await _save("01_completed_astral_island")
	camera.position = Vector3(4.2,-.2,3.2)
	camera.look_at(Vector3(0,-.88,0))
	await _save("02_side_engine_and_gallery")
	camera.position = Vector3(-2.4,-.1,-5)
	camera.look_at(Vector3(0,-.88,0))
	await _save("03_rear_condenser_and_gallery")
	camera.size = 2.4
	camera.position = Vector3(3,-1.4,-4)
	camera.look_at(Vector3(0,-1.30,0))
	await _save("04_underside_closeup")
	stage.queue_free()
	await process_frame
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_astral_v14.json"
	root.add_child(world)
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).hide()
	_lighting(world)
	var centre := world.get_zone_position(world.get_zone_ids()[2])
	var radius := world.get_zone_radius(world.get_zone_ids()[2])
	var game_camera := _camera(world,radius*4.15,centre+Vector3(-1.4,.9,-3.0)*radius,centre+Vector3(0,-radius*.75,0))
	game_camera.near = .5
	game_camera.far = 8000
	await _save("05_completed_island_in_game")
	quit()
