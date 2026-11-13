# Isolated real renderer test: no Terrain3D dependency; suitable for both
# native mobile and the GL compatibility rendering path used by Web.
extends SceneTree

const Botanicals := preload("res://scripts/castle_royal_botanicals.gd")
const Style := preload("res://scripts/castle_reference_style.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(640, 480)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("26343f")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -30, 0)
	world.add_child(light)
	var stairs := Node3D.new()
	stairs.name = "CastleStairs"
	world.add_child(stairs)
	var stair := Node3D.new()
	stair.name = "CastleStair"
	stairs.add_child(stair)
	Style.box(stair, "StoneWall", Vector3(2.5, 1.8, 0.30), Vector3.ZERO, "wall")
	Style.cluster(stair, Vector3(0, -0.1, 0.157), Vector3.BACK, 0.8)
	Botanicals.build(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0.1, 0.3, 2.6)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.fov = 45
	camera.make_current()
	for frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var green_pixels := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var pixel := image.get_pixel(x, y)
			if pixel.g > pixel.r * 1.08 and pixel.g > pixel.b * 1.10:
				green_pixels += 1
	if green_pixels < 200:
		push_error("BOTANICAL_RENDER_TEST: living green detail missing/repainted: %d green pixels" % green_pixels)
		quit(1)
		return
	var method := RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_botanical_garden")
	image.save_png("res://artifacts/castle_botanical_garden/botanical_%s.png" % method)
	print("BOTANICAL_RENDER_TEST: PASS — %s, %d visible green samples" % [method, green_pixels])
	quit(0)
