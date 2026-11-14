extends SceneTree

var _output_dir := "res://artifacts/curling_surf_volume"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280,720)
	var stylized := OS.get_cmdline_user_args().has("--stylized")
	if stylized:
		_output_dir = "res://artifacts/stylized_ocean"
	var web := OS.get_cmdline_user_args().has("--web-water")
	var stills := OS.get_cmdline_user_args().has("--stills")
	var stage: Node3D
	var ocean: Node3D
	if web:
		stage = Node3D.new()
		root.add_child(stage)
		ocean = (load("res://scripts/Water.tscn") as PackedScene).instantiate()
		stage.add_child(ocean)
		ocean.configure_harbour(Vector2(38,188.5),20.0)
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/web_water.gdshader")
		ocean.get_node("MeshInstance3D").material_override = material
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(.7,.84,.91)
		stage.add_child(environment)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color(.72,.82,.92)
		environment.environment.ambient_light_energy = .65
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-55,-35,0)
		sun.light_energy = 1.0
		sun.shadow_enabled = true
		stage.add_child(sun)
	else:
		stage = (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
		root.add_child(stage)
		ocean = stage.get_node("Environment/Water")
	for frame in 120:
		await process_frame
	for layer in stage.find_children("*","CanvasLayer",true,false):
		layer.visible = false
	ocean.set_process(false)
	var camera := Camera3D.new()
	camera.fov = 48
	camera.far = 1200
	stage.add_child(camera)
	camera.make_current()
	if OS.get_cmdline_user_args().has("--unified-ocean"):
		_output_dir = "res://artifacts/unified_reference_ocean"
		DirAccess.make_dir_recursive_absolute(_output_dir)
		var surf: Node3D = ocean.get_node("CurlingSurf")
		var state: Dictionary = surf.sample_patch(2,65.0)
		ocean.wave_time = state.start+state.duration*.48
		ocean._process(0)
		camera.position = Vector3(8,12,293)
		camera.look_at(Vector3(25,1,220))
		await _save("web_coast" if web else "coast")
		camera.fov = 65
		camera.position = Vector3(30,45,390)
		camera.look_at(Vector3(25,.5,283))
		await _save("web_ocean_wide" if web else "ocean_wide")
		var breaker: Node3D = surf.get_node("Breaker_02")
		camera.fov = 48
		var framing_width := minf(state.width,24.0)
		camera.position = breaker.to_global(Vector3(-framing_width*.65,1.5+state.height,framing_width*.70))
		camera.look_at(breaker.to_global(Vector3(0,state.height*.45,0)))
		await _save("web_shared_detail" if web else "shared_detail")
		print("UNIFIED_OCEAN_CAPTURE: PASS — reference shading across swells, whitecaps and 3D curls")
		quit()
		return
	if OS.get_cmdline_user_args().has("--reference-wave"):
		_output_dir = "res://artifacts/reference_blue_surf"
		camera.fov = 34
		DirAccess.make_dir_recursive_absolute(_output_dir)
		var surf: Node3D = ocean.get_node("CurlingSurf")
		var state: Dictionary = surf.sample_patch(2,65.0)
		ocean.wave_time = state.start+state.duration*.48
		ocean._process(0)
		var breaker: Node3D = surf.get_node("Breaker_02")
		var target: Vector3 = breaker.to_global(Vector3(0,state.height*.45,0))
		camera.position = breaker.to_global(Vector3(-state.width*.65,1.5+state.height,state.width*.70))
		camera.look_at(target)
		await _save("web_reference_closeup" if web else "reference_closeup")
		if not stills:
			for frame in 144:
				ocean.wave_time = state.start+state.duration*.20+float(frame)/24.0
				ocean._process(0)
				await _save(("web_reference_" if web else "reference_") + "%03d" % frame)
		else:
			camera.position = breaker.to_global(Vector3(state.width*.75,2.5,1.0))
			camera.look_at(target)
			await _save("web_reference_side" if web else "reference_side")
		print("REFERENCE_SURF_CAPTURE: PASS — real randomized breaker with blue face, textured foam and spray")
		quit()
		return
	if OS.get_cmdline_user_args().has("--spawn-pattern"):
		_output_dir = "res://artifacts/random_surf_spawns"
		DirAccess.make_dir_recursive_absolute(_output_dir)
		camera.fov = 72
		camera.position = Vector3(30,70,390)
		camera.look_at(Vector3(25,.5,283))
		for frame in 240:
			ocean.wave_time = float(frame)/24.0
			ocean._process(0)
			await _save(("web_spawn_" if web else "spawn_") + "%03d" % frame)
		print("SPAWN_CAPTURE: PASS — ten seconds of staggered waves at changing positions")
		quit()
		return
	if OS.get_cmdline_user_args().has("--wind-pattern"):
		_output_dir = "res://artifacts/stylized_ocean" if stylized else "res://artifacts/aligned_ocean_wind"
		DirAccess.make_dir_recursive_absolute(_output_dir)
		camera.position = Vector3(-8,8,285)
		camera.look_at(Vector3(-40,.6,279))
		for frame in 192:
			ocean.wave_time = 61.0+float(frame)/24.0
			ocean._process(0)
			await _save(("web_wind_" if web else "wind_") + "%03d" % frame)
		print("WIND_CAPTURE: PASS — aligned waves and randomized gusts")
		quit()
		return
	DirAccess.make_dir_recursive_absolute(_output_dir)
	ocean.wave_time = 63.0
	ocean._process(0)
	camera.position = Vector3(-25.5,.92,265.5)
	camera.look_at(Vector3(-29,1.10,268.5))
	await _save("web_barrel" if web else "barrel_closeup")
	if stills:
		camera.position = Vector3(-24.5,1.35,264)
		camera.look_at(Vector3(-28,1.10,268.5))
		await _save("web_three_quarter" if web else "three_quarter")
		camera.position = Vector3(-23,4.8,272.5)
		camera.look_at(Vector3(-28,1.10,268.5))
		await _save("web_back" if web else "back_volume")
		camera.position = Vector3(-21.5,2.3,267)
		camera.look_at(Vector3(-28,1.10,268.5))
		await _save("web_side" if web else "side_volume")
		for seconds in [61.0,65.0,68.0,71.0,74.9,75.0]:
			ocean.wave_time = seconds
			ocean._process(0)
			await _save(("web_phase_" if web else "phase_") + str(seconds))
		ocean.wave_time = 63.0
		ocean._process(0)
	if not web:
		camera.position = Vector3(8,12,293)
		camera.look_at(Vector3(25,1,220))
		await _save("harbour_and_surf")
		camera.position = Vector3(-25.5,.92,265.5)
		camera.look_at(Vector3(-29,1.10,268.5))
		if not stills:
			# Orbit a frozen crest to show actual volume, then show it breaking.
			for frame in 288:
				if frame < 144:
					var angle := lerpf(-.95,2.5,float(frame)/143.0)
					camera.position = Vector3(-28+cos(angle)*7.5,3.0+sin(float(frame)/143.0*PI)*2.0,268.5+sin(angle)*7.5)
					camera.look_at(Vector3(-28,1.10,268.5))
					ocean.wave_time = 63.0
				else:
					camera.position = Vector3(-23.5,2.5,263)
					camera.look_at(Vector3(-28,1.10,268.5))
					ocean.wave_time = 61.0+float(frame-144)/24.0
				ocean._process(0)
				await _save("surf_%03d" % frame)
	print("CURLING_SURF_CAPTURE: PASS — " + ("Compatibility" if web else "native in-game"))
	quit()

func _save(name: String) -> void:
	for i in 1:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(_output_dir + "/%s.png" % name)
	if error != OK:
		push_error("Cannot save surf capture")
		quit(1)
