extends SceneTree

const OUTPUT_DIR := "res://artifacts/mind_spark_super_island_one_3000"
const ISLAND_CENTER := Vector3(-765, 2, 127.5)


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
	world.object_state_store_path = "user://capture_super_island_one_3000.json"
	stage.add_child(world)
	world.set_world_state("waking")
	var geometry := world.get_node("WorldOneGeometry") as Node3D
	for world_child in world.get_children():
		if world_child is Node3D and world_child != geometry:
			(world_child as Node3D).visible = false
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false
	for existing_environment in world.find_children("*", "WorldEnvironment", true, false):
		(existing_environment as WorldEnvironment).environment = null

	# Isolate only the first fused island while retaining its two live gameplay
	# districts. This is an implementation proof, not a detached Blender render.
	var fusions := geometry.get_node("ThreeFusedSuperIslands") as Node3D
	for child_index in range(1, fusions.get_child_count()):
		(fusions.get_child(child_index) as Node3D).visible = false
	for child in geometry.get_children():
		if not (child is Node3D):
			continue
		var keep := child == fusions or (child.has_meta("zone_id") \
			and str(child.get_meta("zone_id", "")) in [
				"01_world_gate_landing", "02_living_network_forest"
			])
		(child as Node3D).visible = keep

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071426")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("91a7b8")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	environment_node.environment = environment
	stage.add_child(environment_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46, -34, 0)
	key.light_color = Color("fff0cf")
	key.light_energy = 0.82
	key.shadow_enabled = true
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(24, 145, 178)
	rim.light_color = Color("4ccbd7")
	rim.light_energy = 0.31
	stage.add_child(rim)
	var under := DirectionalLight3D.new()
	under.rotation_degrees = Vector3(34, 10, 180)
	under.light_color = Color("d9aa63")
	under.light_energy = 0.36
	stage.add_child(under)

	var camera := Camera3D.new()
	camera.near = 0.5
	camera.far = 3000.0
	stage.add_child(camera)
	camera.make_current()
	for _frame in 12:
		await process_frame

	# Hero view: reads the conservatory, living crown, fused waist, civic rim,
	# engine galleries and the pointed rock keel in one composition.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 46.0
	camera.position = ISLAND_CENTER + Vector3(-245, 185, 360)
	camera.look_at(ISLAND_CENTER + Vector3(0, -22, 0), Vector3.UP)
	await _save("01_island_one_hero")

	# Gameplay blueprint: proves the two old districts now form one readable
	# walkable machine with distinct puzzle and reflection zones.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 350.0
	camera.position = ISLAND_CENTER + Vector3(0, 900, 40)
	camera.look_at(ISLAND_CENTER, Vector3(0, 0, -1))
	await _save("02_island_one_gameplay_blueprint")

	# Underside audit: the machinery must fill the service ring and visibly
	# transfer load into the faceted keel instead of hanging as decoration.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 48.0
	camera.position = ISLAND_CENTER + Vector3(-245, -28, 350)
	camera.look_at(ISLAND_CENTER + Vector3(0, -45, 0), Vector3.UP)
	await _save("03_island_one_lift_undercroft")
	print("MIND_SPARK_SUPER_ISLAND_ONE_CAPTURE: PASS")
	quit()


func _save(file_name: String) -> void:
	for _frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	var error := root.get_texture().get_image().save_png(path)
	assert(error == OK, "could not save %s" % path)
	print("MIND_SPARK_SUPER_ISLAND_ONE_CAPTURE: wrote %s" % path)
