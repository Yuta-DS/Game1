extends SceneTree

const OUT := "res://artifacts/mind_spark_islands_v09"
const ASSETS := "res://assets3D/mind_spark/celestial_islands_v09"
const DETAILS := ["Gateway pumps / supported side service gallery", "Irrigation exchangers / terraced maintenance ring",
	"Five circulation stations / open arched galleries", "Three-cylinder lift engines / braced service gallery",
	"Accumulator banks / pressure distribution", "Eight nutrient pumps / rooted service ring"]
var manifest: Dictionary


func _init() -> void:
	call_deferred("_run")


func _lighting(stage: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("dce1dc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f4ead8")
	env.ambient_light_energy = 0.50
	var environment := WorldEnvironment.new()
	environment.environment = env
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -32, 0)
	key.light_color = Color("fff1dc")
	key.light_energy = 0.65
	key.shadow_enabled = true
	stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, 140, 0)
	fill.light_color = Color("d4e6e5")
	fill.light_energy = 0.24
	stage.add_child(fill)


func _text(parent: Node, value: String, at: Vector2, font_size: int, color := Color("504b40")) -> void:
	var label := Label.new()
	label.text = value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _foundation(index: int) -> Node3D:
	var land := Node3D.new()
	land.add_child((load(manifest.shared_paving) as PackedScene).instantiate())
	land.add_child((load(ASSETS + "/" + manifest.variants[index].file) as PackedScene).instantiate())
	return land


func _camera(stage: Node3D, size: float, position: Vector3, target: Vector3) -> Camera3D:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	camera.near = 0.01
	camera.far = 40
	stage.add_child(camera)
	camera.position = position
	camera.look_at(target)
	camera.make_current()
	return camera


func _save(name: String) -> void:
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUT + "/" + name + ".png")
	assert(result == OK, "Could not save rendered board")
	print("V09_CAPTURE: " + name)


func _run() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "/manifest.json"))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(2400, 1680)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var board := Control.new()
	root.add_child(board)
	var background := ColorRect.new()
	background.size = Vector2(2400,1680)
	background.color = Color("f2eee5")
	board.add_child(background)
	_text(board, "MINDSPARK  /  CELESTIAL ENGINE ISLANDS", Vector2(24,16), 34)
	_text(board, "6 distinct foundations  /  3,000 editable mesh parts each  /  18,000 total", Vector2(24,60), 24)
	_text(board, "Actual game geometry • ivory masonry / warm brass / copper / enamel • map and walking routes retained", Vector2(24,95), 19, Color("7d7666"))
	for index in 6:
		var x := 18+(index%3)*794
		var y := 137+(index/3)*747
		var container := SubViewportContainer.new()
		container.position = Vector2(x,y)
		container.size = Vector2(772,600)
		board.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(772,600)
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		container.add_child(viewport)
		var stage := Node3D.new()
		viewport.add_child(stage)
		_lighting(stage)
		stage.add_child(_foundation(index))
		_camera(stage,3.15,Vector3(2.6,1.55,4.6),Vector3(0,-.75,0))
		var record: Dictionary = manifest.variants[index]
		_text(board, "%02d  %s" % [index+1, str(record.name).to_upper()], Vector2(x+8,y+610), 25)
		_text(board, DETAILS[index], Vector2(x+8,y+646), 19, Color("7d7666"))
		_text(board, "3,000 mesh parts  |  %d new engine components" % int(record.categories["04_Engine_Assemblies"]),Vector2(x+8,y+679),19)
	_text(board,"Part count includes stone blocks, fittings and labelled editable surface patches; runtime meshes are batched. Neutral presentation lighting.",Vector2(24,1630),18,Color("7d7666"))
	await _save("01_six_islands_3000_part_board")
	board.queue_free()
	await process_frame
	root.size=Vector2i(1600,1200)
	for index in 6:
		var stage := Node3D.new()
		root.add_child(stage)
		_lighting(stage)
		stage.add_child(_foundation(index))
		_camera(stage,3.3 if index==5 else 2.95,Vector3(1.5,.85,4.6),Vector3(0,-.78,0))
		var labels := CanvasLayer.new()
		root.add_child(labels)
		_text(labels,"%02d  %s  /  3,000 EDITABLE MESH PARTS" % [index+1,str(manifest.variants[index].name).to_upper()],Vector2(22,18),27)
		_text(labels,DETAILS[index],Vector2(22,58),21)
		_text(labels,"Machine bodies • level glasses • flanges • fasteners • radiators • rounded pipes • supported galleries",Vector2(22,1150),19)
		await _save("island_%02d_architecture_detail" % (index+1))
		stage.queue_free()
		labels.queue_free()
		await process_frame
	# Show the occupied game map as well as the isolated foundation board.
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_celestial_v09_map.json"
	root.add_child(world)
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).hide()
	_lighting(world)
	var map_camera := _camera(world,1850,Vector3(0,2400,1000),Vector3(0,0,30))
	map_camera.near = .5
	map_camera.far = 8000
	await _save("02_existing_map_with_detailed_foundations")
	for index in [2,3]:
		var centre := world.get_zone_position(world.get_zone_ids()[index])
		var radius := world.get_zone_radius(world.get_zone_ids()[index])
		map_camera.size = radius*3.2
		map_camera.position = centre+Vector3(1.8,1.0,2.8)*radius
		map_camera.look_at(centre+Vector3(0,-radius*.55,0))
		await _save("island_%02d_integrated_gameplay" % (index+1))
	quit()
