extends SceneTree

const OUT := "res://artifacts/mind_spark_islands_v08"
const LABELS := ["01  SUN GATE", "02  VERDANT ENGINE GARDENS", "03  ASTRAL OBSERVATORY",
	"04  DAWN VIADUCT", "05  STORMWORKS BASTION", "06  CROWNROOT SANCTUARY"]
const DETAILS := ["Carved gateway arches + ceremonial sun inlay", "Stepped terraces + three condenser houses",
	"Open arcades + supported orbital rings", "Twin load arches + slender sweeping supports",
	"Octagonal armour + copper pressure banks", "Flared stone petals + tapering root supports"]


func _init() -> void:
	call_deferred("_run")


func _lighting(stage: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("e1e4df")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f4ead8")
	env.ambient_light_energy = 0.35
	var env_node := WorldEnvironment.new()
	env_node.environment = env
	stage.add_child(env_node)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -32, 0)
	key.light_color = Color("fff1dc")
	key.light_energy = 0.55
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, 140, 0)
	fill.light_color = Color("d4e6e5")
	fill.light_energy = 0.20
	stage.add_child(fill)


func _label(parent: Node, text: String, position: Vector2, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _save(filename: String) -> void:
	for _frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT + "/" + filename + ".png") == OK)
	print("V08_CAPTURE: " + filename)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1800, 1220)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_island_variants_v08.json"
	world.visible = false
	root.add_child(world)
	var board := Control.new()
	root.add_child(board)
	var bg := ColorRect.new()
	bg.color = Color("f2eee5")
	bg.size = Vector2(1800, 1220)
	board.add_child(bg)
	_label(board, "MINDSPARK  /  SIX ISLANDS, ONE CELESTIAL DESIGN FAMILY", Vector2(24, 18), 28, Color("4d493f"))
	_label(board, "Actual game assets  •  shared ivory / brass / stone palette  •  unchanged playable footprints", Vector2(24, 56), 18, Color("777062"))
	for index in 6:
		var x := 18 + (index % 3) * 594
		var y := 100 + (index / 3) * 554
		var container := SubViewportContainer.new()
		container.position = Vector2(x, y)
		container.size = Vector2(576, 480)
		board.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(576, 480)
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		var stage := Node3D.new()
		viewport.add_child(stage)
		_lighting(stage)
		var source := world.get_node("WorldOneGeometry/" + world.get_zone_ids()[index].to_pascal_case() + "/ModularFloatingFoundation") as Node3D
		var land := source.duplicate() as Node3D
		land.transform = Transform3D.IDENTITY
		stage.add_child(land)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 3.0
		camera.near = 0.01
		camera.far = 30
		stage.add_child(camera)
		camera.position = Vector3(2.6, 1.55, 4.6)
		camera.look_at(Vector3(0, -0.75, 0))
		camera.make_current()
		_label(board, LABELS[index], Vector2(x+8, y+485), 22, Color("4d493f"))
		_label(board, DETAILS[index], Vector2(x+8, y+515), 16, Color("777062"))
	await _save("01_six_designs_comparison")
	board.queue_free()
	await process_frame
	root.size = Vector2i(1600, 1000)
	world.visible = true
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).hide()
	_lighting(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.5
	camera.far = 8000
	world.add_child(camera)
	camera.make_current()
	camera.size = 1570
	camera.position = Vector3(0, 2400, 1000)
	camera.look_at(Vector3(0, 0, 30))
	await _save("02_existing_map_new_island_family")
	for index in 6:
		var center := world.get_zone_position(world.get_zone_ids()[index])
		var radius := world.get_zone_radius(world.get_zone_ids()[index])
		camera.size = radius * 3.2
		camera.position = center + Vector3(1.8, 1.0, 2.8) * radius
		camera.look_at(center + Vector3(0, -radius*.55, 0))
		await _save("island_%02d_gameplay" % (index+1))
	quit()
