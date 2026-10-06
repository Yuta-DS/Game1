extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var full_hub := OS.get_cmdline_user_args().has("--hub")
	var stage: Node3D
	var ocean: Node3D
	if full_hub:
		stage = (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
		root.add_child(stage)
		ocean = stage.get_node("Environment/Water")
	else:
		stage = Node3D.new()
		root.add_child(stage)
		ocean = (load("res://scripts/Water.tscn") as PackedScene).instantiate()
		stage.add_child(ocean)
		ocean.configure_harbour(Vector2(38,188.5),20.0)
	if OS.get_cmdline_user_args().has("--web-water"):
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/web_water.gdshader")
		ocean.get_node("MeshInstance3D").material_override = material
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-35,0)
	stage.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 48
	stage.add_child(camera)
	camera.position = Vector3(-24.5,2.8,264)
	camera.look_at(Vector3(-28,1.1,268.5))
	camera.make_current()
	var sample_start := 61.0
	var warm_time := 63.0
	if OS.get_cmdline_user_args().has("--hero"):
		var surf: Node3D = ocean.get_node("CurlingSurf")
		var state: Dictionary = surf.sample_patch(2,65.0)
		warm_time = state.start+state.duration*.48
		sample_start = state.start+state.duration*.20
		ocean.wave_time = warm_time
		ocean._process(0)
		var breaker: Node3D = surf.get_node("Breaker_02")
		camera.fov = 34
		camera.position = breaker.to_global(Vector3(-state.width*.65,1.5+state.height,state.width*.70))
		camera.look_at(breaker.to_global(Vector3(0,state.height*.45,0)))
	if full_hub:
		camera.position = Vector3(8,12,293)
		camera.look_at(Vector3(25,1,220))
	ocean.set_process(false)
	for frame in 90:
		ocean.wave_time = warm_time
		ocean._process(0)
		await process_frame
	var samples := PackedFloat64Array()
	var previous := Time.get_ticks_usec()
	for frame in 240:
		ocean.wave_time = sample_start+float(frame)/40.0
		ocean._process(0)
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now-previous)/1000.0)
		previous = now
	samples.sort()
	print("OCEAN_BENCHMARK: renderer=%s 1280x720 median=%.2fms p95=%.2fms draws=%d primitives=%d scene=%s (uncapped, no screenshot readback)" % [RenderingServer.get_current_rendering_method(),samples[120],samples[228],Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"full hub" if full_hub else "isolated ocean"])
	quit()
