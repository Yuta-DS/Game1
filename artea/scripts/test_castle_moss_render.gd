extends SceneTree

const Moss := preload("res://scripts/castle_stair_moss.gd")
const Style := preload("res://scripts/castle_reference_style.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(640,480)
	var world := Node3D.new()
	root.add_child(world)
	var stairs := Node3D.new()
	stairs.name = "CastleStairs"
	world.add_child(stairs)
	var stair := Node3D.new()
	stair.name = "CastleStair"
	stairs.add_child(stair)
	var wall := Style.box(stair,"MasonryTower",Vector3(5,5,0.5),Vector3.ZERO)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("35404a")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	world.add_child(env)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6
	camera.position = Vector3(0,0,8)
	camera.look_at(Vector3.ZERO,Vector3.UP)
	camera.make_current()
	Moss.apply(world)
	var moss := wall.material_overlay as ShaderMaterial
	var method := RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute("res://artifacts/castle_moss_pattern")
	var baseline := Vector2i.ZERO
	var reduced := Vector2i.ZERO
	var pattern_edges := Vector2i.ZERO
	var image: Image
	# Sample several real castle heights/locations: one small random patch is
	# not representative of a forty-metre tower's total retained coverage.
	for at: Vector3 in [Vector3(-1.4,29,27.41),Vector3(-1.4,39,27.41),
			Vector3(-1.4,49,27.41),Vector3(-1.4,59,27.41),Vector3(-1.4,67,27.41),
			Vector3(7,40,27),Vector3(-7,50,27),Vector3(-35,73,27),Vector3(0,50,35)]:
		wall.position = at
		camera.position = at+Vector3(0,0,8)
		camera.look_at(at,Vector3.UP)
		moss.set_shader_parameter("remaining_fraction",1.0)
		for frame in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		image = root.get_texture().get_image()
		var pixel_scale := Vector2(image.get_size())/root.get_visible_rect().size
		var first := camera.unproject_position(at+Vector3(-2.4,2.4,0.25))*pixel_scale
		var last := camera.unproject_position(at+Vector3(2.4,-2.4,0.25))*pixel_scale
		baseline += _moss_samples(image,first,last)
		moss.set_shader_parameter("remaining_fraction",Moss.COVERAGE)
		for frame in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		image = root.get_texture().get_image()
		reduced += _moss_samples(image,first,last)
		pattern_edges += _pattern_transitions(image,first,last)
	var retained := float(reduced.x)/maxi(1,baseline.x)
	if retained < 0.06 or retained > 0.22:
		push_error("MOSS_RENDER_TEST: expected restrained 6–22%% coverage matching the keep; measured %.1f%%" % (retained*100.0))
		quit(1)
		return
	# Repeated clear-stone breaks distinguish the small colonies from the former
	# metre-wide rounded blobs. Average over all sample walls, not one lucky seed.
	var edges_per_row := float(pattern_edges.x)/maxi(1,pattern_edges.y)
	if edges_per_row < 3.0:
		push_error("MOSS_RENDER_TEST: pattern reverted to broad uninterrupted blobs: %.2f transitions/row" % edges_per_row)
		quit(1)
		return
	image.save_png("res://artifacts/castle_moss_pattern/moss_wall_%s.png" % method)
	var stable := image.get_data()
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().get_data() != stable:
		push_error("MOSS_RENDER_TEST: scattered moss shifts between frames")
		quit(1)
		return
	# Same material on a horizontal top must become invisible. This verifies the
	# shader's orientation mask using real pixels, not just source-text checks.
	wall.position = Vector3.ZERO
	(wall.mesh as BoxMesh).size = Vector3(5,0.2,5)
	camera.position = Vector3(0,8,0)
	camera.look_at(Vector3.ZERO,Vector3.BACK)
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	var green := 0
	for y in range(140,340,2):
		for x in range(220,420,2):
			var colour := image.get_pixel(x,y)
			if colour.g > colour.r*1.06 and colour.g > colour.b*1.2:
				green += 1
	if green != 0:
		push_error("MOSS_RENDER_TEST: moss painted a horizontal walking/coping face")
		quit(1)
		return
	print("MOSS_RENDER_TEST: PASS — %s, %.1f%% of full-coat coverage retained; %.2f colony edges/row; pattern stable; horizontal face unchanged" % [method,retained*100.0,edges_per_row])
	quit(0)

func _moss_samples(image: Image, first: Vector2, last: Vector2) -> Vector2i:
	var counts := Vector2i.ZERO
	for y in range(clampi(int(first.y),0,image.get_height()-1),clampi(int(last.y),0,image.get_height()),2):
		for x in range(clampi(int(first.x),0,image.get_width()-1),clampi(int(last.x),0,image.get_width()),2):
			var colour := image.get_pixel(x,y)
			if colour.g > colour.r*1.06 and colour.g > colour.b*1.2:
				counts.x += 1
			counts.y += 1
	return counts

func _pattern_transitions(image: Image, first: Vector2, last: Vector2) -> Vector2i:
	var counts := Vector2i.ZERO
	# Coarse sampling ignores single-pixel texture specks and measures silhouette.
	for y in range(clampi(int(first.y),0,image.get_height()-1),clampi(int(last.y),0,image.get_height()),8):
		var previous := false
		var initial := true
		for x in range(clampi(int(first.x),0,image.get_width()-1),clampi(int(last.x),0,image.get_width()),4):
			var colour := image.get_pixel(x,y)
			var green := colour.g > colour.r*1.06 and colour.g > colour.b*1.2
			if not initial and green != previous:
				counts.x += 1
			previous = green
			initial = false
		counts.y += 1
	return counts
