# Isolated from native Terrain3D: exercise the actual fountain in both mobile
# and GL compatibility, including shader compilation and rendered water motion.
extends SceneTree

const Fountain := preload("res://scripts/castle_royal_fountain.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(640, 480)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("26343f")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -35, 0)
	world.add_child(light)
	Fountain.build(world, Vector3.ZERO, Vector3.ZERO)
	var fountain := world.get_node("CastleRoyalFountain")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(3.8, 3.4, 4.5)
	camera.look_at(Vector3(0, 1.1, 0), Vector3.UP)
	camera.fov = 45
	camera.make_current()
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	var spray := fountain.get_node("LowerImpactSpray") as MultiMeshInstance3D
	var before_drop := spray.multimesh.get_instance_transform(0).origin
	var water := fountain.find_child("LowerBasinWater", true, false) as MeshInstance3D
	var before_time := float((water.material_override as ShaderMaterial).get_shader_parameter("flow_time"))
	while float((water.material_override as ShaderMaterial).get_shader_parameter("flow_time")) < before_time + 0.30:
		await process_frame
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	var changed := 0
	for y in range(0, after.get_height(), 2):
		for x in range(0, after.get_width(), 2):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			if absf(a.r-b.r) + absf(a.g-b.g) + absf(a.b-b.b) > 0.04:
				changed += 1
	if changed < 25 or spray.multimesh.get_instance_transform(0).origin.distance_to(before_drop) < 0.001:
		push_error("FOUNTAIN_RENDER_TEST: no real water/spray motion: %d changed pixels" % changed)
		quit(1)
		return
	var method := RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_fountain_refinement")
	after.save_png("res://artifacts/castle_fountain_refinement/render_%s.png" % method)
	print("FOUNTAIN_RENDER_TEST: PASS — %s: animated water changed %d sampled pixels; instanced droplets move" % [method, changed])
	quit(0)
