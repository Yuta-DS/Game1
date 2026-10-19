extends SceneTree

const OUTPUT_DIR := "res://artifacts/mind_spark_island_one_gate_v21"
const GATE_CENTER := Vector3(-860, 2, 170)


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	stage.add_child(world)
	world.set_world_state("waking")
	var geometry := world.get_node("WorldOneGeometry") as Node3D
	for world_child in world.get_children():
		if world_child is Node3D and world_child != geometry:
			(world_child as Node3D).visible = false
	for child in geometry.get_children():
		if child is Node3D:
			(child as Node3D).visible = child.has_meta("zone_id") \
				and str(child.get_meta("zone_id", "")) == "01_world_gate_landing"
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	for existing_environment in world.find_children("*", "WorldEnvironment", true, false):
		(existing_environment as WorldEnvironment).environment = null

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071426")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9aabba")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	environment_node.environment = environment
	stage.add_child(environment_node)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -28, 0)
	key.light_color = Color("fff0cf")
	key.light_energy = 0.88
	key.shadow_enabled = true
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(22, 150, 178)
	rim.light_color = Color("58cbd5")
	rim.light_energy = 0.30
	stage.add_child(rim)

	var camera := Camera3D.new()
	camera.near = 0.5
	camera.far = 2000.0
	stage.add_child(camera)
	camera.make_current()
	for _frame in 12:
		await process_frame

	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 45.0
	camera.position = GATE_CENTER + Vector3(-155, 118, 235)
	camera.look_at(GATE_CENTER + Vector3(0, 13, 0), Vector3.UP)
	await _save("01_gate_architecture_hero")

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 190.0
	camera.position = GATE_CENTER + Vector3(0, 520, 18)
	camera.look_at(GATE_CENTER, Vector3(0, 0, -1))
	await _save("02_gate_reuse_blueprint")

	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 55.0
	camera.position = GATE_CENTER + Vector3(0, 17, 128)
	camera.look_at(GATE_CENTER + Vector3(0, 16, -10), Vector3.UP)
	await _save("03_gate_player_approach")
	print("ISLAND_ONE_GATE_KIT_V21_CAPTURE: PASS")
	quit()


func _save(file_name: String) -> void:
	for _frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("ISLAND_ONE_GATE_KIT_V21_CAPTURE: wrote %s" % path)
