# Run with both mobile and gl_compatibility. This catches mismatched sRGB
# handling between StandardMaterial stone and the colour-only floor shaders.
extends SceneTree

const Style := preload("res://scripts/castle_reference_style.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(640, 320)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 1.0
	world.add_child(environment)
	var stone := Style.box(world, "ReferenceStone", Vector3(1.5, 0.1, 1.5), Vector3(-1, 0, 0), "floor")
	var floor_mesh := Style.box(world, "DressedTread", Vector3(1.5, 0.1, 1.5), Vector3(1, 0, 0), "floor")
	var shader := ShaderMaterial.new()
	shader.shader = load("res://shaders/castle_courtyard_stone.gdshader")
	shader.set_shader_parameter("dressed_treads", true)
	floor_mesh.material_override = shader
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5
	world.add_child(camera)
	camera.position = Vector3(0, 5, 0)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	camera.make_current()
	for frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var a := camera.unproject_position(stone.global_position)
	var b := camera.unproject_position(floor_mesh.global_position)
	# Project stretch keeps logical camera coordinates independent of window
	# pixels. Convert them before sampling (including HiDPI desktops).
	var pixel_scale := Vector2(picture.get_size()) / root.get_visible_rect().size
	var first := picture.get_pixelv(Vector2i(a * pixel_scale))
	var second := picture.get_pixelv(Vector2i(b * pixel_scale))
	var difference := maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b)))
	if difference > 0.025 or first.get_luminance() < 0.05:
		push_error("CASTLE_MATERIAL_RENDER_TEST: stone/shader colour mismatch: %s vs %s" % [first, second])
		quit(1)
		return
	print("CASTLE_MATERIAL_RENDER_TEST: PASS — %s, StandardMaterial and floor shader delta %.5f" % [RenderingServer.get_current_rendering_method(), difference])
	quit(0)
