# Real renderer proof, isolated from Terrain3D. Run with mobile and gl_compatibility.
extends SceneTree

const Torch := preload("res://scripts/castle_parapet_torch.gd")
const Garden := preload("res://scripts/castle_rooftop_garden.gd")
const Bot := preload("res://scripts/castle_royal_botanicals.gd")
const Style := preload("res://scripts/castle_reference_style.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(960, 640)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("334349")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.55
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-30,0)
	world.add_child(sun)
	var stairs := Node3D.new()
	stairs.name = "CastleStairs"
	world.add_child(stairs)
	var stair := Node3D.new()
	stair.name = "CastleStair"
	stairs.add_child(stair)
	Style.box(stair,"Wall",Vector3(3.0,1.4,0.4),Vector3(0,0.7,0.3))
	Style.cluster(stair,Vector3(0.1,0.65,0.509),Vector3.BACK,0.8)
	Bot.build(world)
	var bed := Node3D.new()
	world.add_child(bed)
	bed.position = Vector3(0,0,1.45)
	Garden._box(bed,"Bed",Vector3(2.65,0.32,1.42),Vector3(0,0.16,0),Style.material())
	Garden._box(bed,"Soil",Vector3(2.35,0.02,1.12),Vector3(0,0.314,0),Garden._material(Color("514331")))
	Garden.Herbs.build(bed)
	var torch := Torch.build(world,Vector3(-0.90,1.4,0.30),0.5)
	torch.set_process(false)
	var flame := (torch.get_node("LiveFlames") as MeshInstance3D).material_override as ShaderMaterial
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(3.2,3.2,5.4)
	camera.look_at(Vector3(0,0.9,0.6),Vector3.UP)
	camera.fov = 44
	camera.make_current()
	for frame in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	flame.set_shader_parameter("flame_time",0.47)
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	var green := 0
	var fire := 0
	var changed_fire := 0
	for y in range(0,after.get_height(),2):
		for x in range(0,after.get_width(),2):
			var p := after.get_pixel(x,y)
			var old := before.get_pixel(x,y)
			if p.g > p.r*1.025 and p.g > p.b*1.1:
				green += 1
			if p.r > 0.75 and p.r > p.g*1.05 and p.g > p.b*1.25:
				fire += 1
				if absf(p.r-old.r)+absf(p.g-old.g)+absf(p.b-old.b) > 0.025:
					changed_fire += 1
	if green < 500 or fire < 20 or changed_fire < 10:
		push_error("MEDIEVAL_RENDER_TEST: foliage/fire missing or animation static: green=%d fire=%d changed=%d" % [green,fire,changed_fire])
		quit(1)
		return
	var method := RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_medieval_garden")
	before.save_png("res://artifacts/castle_medieval_garden/render_%s_before.png" % method)
	after.save_png("res://artifacts/castle_medieval_garden/render_%s_after.png" % method)
	print("MEDIEVAL_RENDER_TEST: PASS — %s: %d green samples, %d flame samples, %d animated flame changes" % [method,green,fire,changed_fire])
	quit(0)
