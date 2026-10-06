extends SceneTree

const OUTPUT := "res://artifacts/arrival_grand_garden_gate"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1440, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var builder := Node3D.new()
	builder.set_script(load("res://scripts/art_castle_floating_world.gd"))
	builder.call("_build_materials")
	builder.call("_build_arrival_island")
	var island := builder.get_node("ArrivalIsland") as Node3D
	builder.remove_child(island)
	var stage := Node3D.new()
	root.add_child(stage)
	stage.add_child(island)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("182242")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c5d5ff")
	env.ambient_light_energy = 0.75
	environment.environment = env
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff0cf")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	stage.add_child(sun)
	for _frame in 4:
		await process_frame
	var camera := Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.2
	camera.far = 4000.0
	stage.add_child(camera)
	camera.make_current()

	camera.position = Vector3(0.0, 13.0, 686.0)
	camera.look_at(Vector3(0.0, 34.0, 820.0), Vector3.UP)
	await _save("01_grand_gate_approach")

	camera.fov = 58.0
	camera.position = Vector3(118.0, 108.0, 642.0)
	camera.look_at(Vector3(0.0, 12.0, 820.0), Vector3.UP)
	await _save("02_gate_garden_overview")

	camera.fov = 50.0
	camera.position = Vector3(-72.0, 18.0, 735.0)
	camera.look_at(Vector3(0.0, 15.0, 805.0), Vector3.UP)
	await _save("03_fountain_and_gardens")
	print("ARRIVAL_GRAND_GARDEN_GATE_CAPTURE: PASS")
	quit()

func _save(file_name: String) -> void:
	for _frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT, file_name]
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("ARRIVAL_GRAND_GARDEN_GATE_CAPTURE: wrote %s" % path)
