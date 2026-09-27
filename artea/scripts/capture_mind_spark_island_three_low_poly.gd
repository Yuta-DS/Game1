extends SceneTree

const OUTPUT_DIR := "res://artifacts/mind_spark_island_three_low_poly"
const STATE_PATH := "user://capture_mind_spark_island_three_low_poly.json"
const SHOTS := [
	{"name": "01_bridge_arrival_and_full_island", "eye": Vector3(135, 285, 455), "look": Vector3(535, 34, -10), "fov": 54.0},
	{"name": "02_storm_court_and_three_landmarks", "eye": Vector3(220, 135, 260), "look": Vector3(440, 34, 0), "fov": 48.0},
	{"name": "03_rain_harvest_observatory", "eye": Vector3(335, 105, 260), "look": Vector3(430, 38, 105), "fov": 45.0},
	{"name": "04_reflection_court_and_oldest_tree", "eye": Vector3(520, 130, -250), "look": Vector3(650, 56, -55), "fov": 48.0},
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1400, 788)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = STATE_PATH
	stage.add_child(world)
	for label in world.find_children("*", "Label3D", true, false):
		(label as Label3D).visible = false

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071126")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8fa9d0")
	environment.ambient_light_energy = .52
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -42, 0)
	sun.light_color = Color("fff0cf")
	sun.light_energy = .92
	sun.shadow_enabled = true
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 130, 0)
	fill.light_color = Color("5edbf1")
	fill.light_energy = .34
	stage.add_child(fill)
	var camera := Camera3D.new()
	camera.near = .5
	camera.far = 5000.0
	stage.add_child(camera)
	camera.make_current()
	for _frame in 8:
		await process_frame
	for shot in SHOTS:
		camera.position = shot.eye
		camera.fov = float(shot.fov)
		camera.look_at(shot.look, Vector3.UP)
		for _frame in 4:
			await process_frame
		_save_frame(str(shot.name))

	for object in world.get_quest_objects():
		if int(object.get_meta("physical_island", 0)) == 3:
			object.current_state["completed"] = true
	world.call("_refresh_island_three_completion_visuals")
	world.set_world_state("gentle_rain")
	camera.position = Vector3(235, 160, 300)
	camera.fov = 50.0
	camera.look_at(Vector3(545, 42, 0), Vector3.UP)
	for _frame in 5:
		await process_frame
	_save_frame("05_completed_island_awakened")
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(STATE_PATH)
	print("MindSparkIslandThreeLowPolyCapture: PASS")
	quit()


func _save_frame(file_name: String) -> void:
	var path := "%s/%s.png" % [OUTPUT_DIR, file_name]
	var image := root.get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		push_error("Failed to capture %s" % path)
		quit(1)
		return
	print("Island 3 capture wrote %s" % path)
