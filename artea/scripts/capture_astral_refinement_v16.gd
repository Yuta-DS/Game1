extends "res://scripts/capture_mind_spark_islands_v11.gd"

const V16_OUT := "res://artifacts/astral_refinement_v16"


func _lighting(stage: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("d8e0df")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f4f0e8")
	env.ambient_light_energy = 0.28
	var environment := WorldEnvironment.new()
	environment.environment = env
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -28, 0)
	key.light_color = Color("fff8ee")
	key.light_energy = 0.27
	key.shadow_enabled = true
	key.shadow_blur = 3.0
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(18, 145, 0)
	fill.light_color = Color("d6e8ed")
	fill.light_energy = 0.10
	stage.add_child(fill)


func save_view(name: String) -> void:
	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(V16_OUT + "/" + name + ".png") == OK)
	print("ASTRAL_V16_CAPTURE: " + name)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1800,1600)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(V16_OUT))
	var stage := Node3D.new()
	root.add_child(stage)
	_lighting(stage)
	stage.add_child((load("res://assets3D/mind_spark/celestial_islands_v08/shared_paving.glb") as PackedScene).instantiate())
	stage.add_child((load("res://assets3D/mind_spark/celestial_astral_v16/island_03.glb") as PackedScene).instantiate())
	var camera := _camera(stage,4.15,Vector3(1.8,.95,5.0),Vector3(0,-.77,0))
	await save_view("01_refined_island")
	camera.size=2.35
	camera.position=Vector3(4,-.55,1.4)
	camera.look_at(Vector3(.65,-.8,0))
	await save_view("02_integrated_side_engine")
	stage.queue_free()
	await process_frame
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud=false
	world.object_state_store_path="user://capture_astral_v16.json"
	root.add_child(world)
	for label in world.find_children("*","Label3D",true,false):
		(label as Label3D).hide()
	_lighting(world)
	var centre := world.get_zone_position("03_constellation_court")
	var camera_world := _camera(world,175*4.15,centre+Vector3(-1.4,.9,-3)*175,centre+Vector3(0,-175*.75,0))
	camera_world.near=.1
	camera_world.far=8000
	for _frame in 60:
		await process_frame
	var started := Time.get_ticks_usec()
	var draws := 0.0
	for _frame in 120:
		await process_frame
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var metrics := {"renderer":"native OpenGL compatibility", "resolution":"1800x1600", "samples":120,
		"mean_fps":120.0 / (float(Time.get_ticks_usec()-started)/1000000.0),
		"mean_draw_calls":draws/120.0, "video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"scope":"Occupied six-island scene, fixed Astral overview, Apple M2 Pro. Not a browser/mobile benchmark."}
	var metrics_file := FileAccess.open(V16_OUT+"/native_render_metrics.json",FileAccess.WRITE)
	metrics_file.store_string(JSON.stringify(metrics,"\t"))
	metrics_file.close()
	await save_view("03_refined_island_in_game")
	var player := (load("res://scenes/player_3d.tscn") as PackedScene).instantiate() as CharacterBody3D
	world.add_child(player)
	player.set_physics_process(false)
	player.position=centre+Vector3(170,1.1,0)
	# Show the actual collision capsule for scale, not the legacy offset proxy.
	(player.get_node("MeshInstance3D") as MeshInstance3D).position=Vector3.ZERO
	camera_world.make_current()
	camera_world.size=13
	camera_world.position=centre+Vector3(164,5,8)
	camera_world.look_at(centre+Vector3(173,1.6,0))
	await save_view("04_player_scale_guardrail")
	quit()
