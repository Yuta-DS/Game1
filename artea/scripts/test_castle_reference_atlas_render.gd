extends SceneTree

const Style := preload("res://scripts/castle_reference_style.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(640, 640)
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color.BLACK
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 1.0
	world.add_child(env)
	# Use the reference keep's actual imported material, not a second texture
	# lookup that can resolve a different renderer-specific import variant.
	var keep := load("res://assets3D/house scenes/castle.tscn").instantiate() as Node3D
	var keep_mesh := keep.get_node("building_castle_red") as MeshInstance3D
	var keep_material := keep_mesh.get_active_material(0) as StandardMaterial3D
	var atlas := keep_material.albedo_texture
	keep.free()
	var pixels := atlas.get_image()
	if pixels.is_compressed():
		pixels.decompress()
	var pairs := []
	for role: String in ["wall", "block", "trim", "floor"]:
		var colour := Style.material(role).albedo_color
		var best := Vector2i.ZERO
		var error := 10.0
		for y in pixels.get_height():
			for x in pixels.get_width():
				var sample := pixels.get_pixel(x, y)
				var distance := Vector3(sample.r-colour.r, sample.g-colour.g, sample.b-colour.b).length_squared()
				if distance < error:
					error = distance
					best = Vector2i(x, y)
		if error > 0.0001:
			push_error("REFERENCE_ATLAS_RENDER_TEST: role absent from original atlas: %s target=%s closest=%s error=%s texture=%s" % [role, colour, pixels.get_pixelv(best), error, atlas.resource_path])
			quit(1)
			return
		var at := Vector3(0, 2.55 - float(pairs.size()) * 1.7, 0)
		var added := Style.box(world, "Added_" + role, Vector3(1.5, 1.5, 0.1), at + Vector3.LEFT, role)
		var reference := Style.box(world, "Atlas_" + role, Vector3(1.5, 1.5, 0.1), at + Vector3.RIGHT, role)
		var material := StandardMaterial3D.new()
		material.albedo_texture = atlas
		material.roughness = 0.92
		material.uv1_scale = Vector3.ZERO
		material.uv1_offset = Vector3((best.x + 0.5) / pixels.get_width(), (best.y + 0.5) / pixels.get_height(), 0)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		reference.material_override = material
		pairs.append([added, reference, role])
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7.5
	world.add_child(camera)
	camera.position = Vector3(0, 0, 8)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	for frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	var pixel_scale := Vector2(picture.get_size()) / root.get_visible_rect().size
	var largest := 0.0
	for pair in pairs:
		var a := picture.get_pixelv(Vector2i(camera.unproject_position(pair[0].global_position) * pixel_scale))
		var b := picture.get_pixelv(Vector2i(camera.unproject_position(pair[1].global_position) * pixel_scale))
		var delta := maxf(absf(a.r-b.r), maxf(absf(a.g-b.g), absf(a.b-b.b)))
		largest = maxf(largest, delta)
		if delta > 0.025 or a.get_luminance() < 0.05:
			push_error("REFERENCE_ATLAS_RENDER_TEST: %s differs from reference texture: %s vs %s" % [pair[2], a, b])
			quit(1)
			return
	print("REFERENCE_ATLAS_RENDER_TEST: PASS — %s, four material roles match original castle atlas under identical lighting; maximum RGB delta %.5f" % [RenderingServer.get_current_rendering_method(), largest])
	quit(0)
