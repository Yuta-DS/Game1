extends "res://scripts/capture_mind_spark_islands_v11.gd"

const VERDANT_OUT := "res://artifacts/verdant_island_v12"


func _save(name: String) -> void:
	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(VERDANT_OUT + "/" + name + ".png")
	assert(result == OK, "Could not save Verdant render")
	print("VERDANT_CAPTURE: " + name)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1800, 1500)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VERDANT_OUT))
	var stage := Node3D.new()
	root.add_child(stage)
	_lighting(stage)
	stage.add_child((load("res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb") as PackedScene).instantiate())
	stage.add_child((load("res://assets3D/mind_spark/celestial_verdant_v12/island_02.glb") as PackedScene).instantiate())
	var camera := _camera(stage, 4.0, Vector3(1.7, .75, 4.8), Vector3(0, -.86, 0))
	await _save("01_verdant_hanging_gardens")
	camera.position = Vector3(.4, .40, 5)
	camera.look_at(Vector3(0, -.86, 0))
	await _save("02_split_keel_elevation")
	stage.queue_free()
	await process_frame
	if "--architecture-only" in OS.get_cmdline_user_args():
		quit()
		return
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_verdant_v12_map.json"
	root.add_child(world)
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).hide()
	_lighting(world)
	var centre := world.get_zone_position(world.get_zone_ids()[1])
	var radius := world.get_zone_radius(world.get_zone_ids()[1])
	var game_camera := _camera(world, radius*4.0, centre+Vector3(1.7,.9,3.0)*radius, centre+Vector3(0,-radius*.80,0))
	game_camera.near = .5
	game_camera.far = 8000
	await _save("03_verdant_in_game")
	# Reverse three-quarter view avoids the existing bridge crossing the facade.
	game_camera.position = centre+Vector3(-1.4,.9,-3.0)*radius
	game_camera.look_at(centre+Vector3(0,-radius*.80,0))
	await _save("04_verdant_in_game_reverse")
	quit()
