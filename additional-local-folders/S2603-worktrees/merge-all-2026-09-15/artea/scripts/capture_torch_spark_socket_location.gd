extends SceneTree

const OUTPUT_DIR := "res://artifacts/torch_spark_socket_location"
const WORLD_SCENE := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var stage := Node3D.new()
	stage.name = "TorchSparkSocketCaptureStage"
	root.add_child(stage)
	current_scene = stage

	var world := WORLD_SCENE.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://capture_torch_spark_socket_location.json"
	stage.add_child(world)
	world.set_world_state("waking")

	var socket: QuestObjectBase
	for object in world.get_quest_objects():
		object.persist_state = false
		if object.save_id == "world_one.spark_socket":
			socket = object
		else:
			object.visible = false
	if socket == null:
		push_error("TORCH_SPARK_SOCKET_CAPTURE: runtime socket missing")
		quit(1)
		return

	socket.set_meta("available_sparks", 3)
	socket.prompt.visible = true
	socket.status.visible = true
	socket.icon.visible = true

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("071126")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("82a9d8")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.42
	environment_node.environment = environment
	stage.add_child(environment_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -32, 0)
	key.light_color = Color("fff0d0")
	key.light_energy = 0.82
	key.shadow_enabled = true
	stage.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-24, 150, 0)
	rim.light_color = Color("65dfff")
	rim.light_energy = 0.34
	stage.add_child(rim)

	var camera := Camera3D.new()
	camera.near = 0.15
	camera.far = 5000.0
	stage.add_child(camera)
	camera.make_current()

	for _frame in 18:
		await process_frame
		await RenderingServer.frame_post_draw

	var focus := socket.global_position + Vector3(0, 7.0, 0)
	await _shoot(camera, "00_living_network_forest_location", focus + Vector3(-52, 25, 58), focus + Vector3(0, 3, 0), 51.0)
	await _shoot(camera, "01_torch_spark_socket_0_of_3", focus + Vector3(22, 12, 28), focus, 43.0)

	socket.interact(&"place_spark")
	await _settle()
	await _shoot(camera, "02_torch_spark_socket_1_of_3", focus + Vector3(22, 12, 28), focus, 43.0)

	socket.interact(&"place_spark")
	await _settle()
	await _shoot(camera, "03_torch_spark_socket_2_of_3", focus + Vector3(22, 12, 28), focus, 43.0)

	socket.interact(&"place_spark")
	await _settle()
	await _shoot(camera, "04_torch_spark_socket_3_of_3_linked_task_open", focus + Vector3(22, 12, 28), focus, 43.0)
	socket.prompt.visible = false
	socket.status.visible = false
	socket.icon.visible = false
	await _shoot(camera, "05_completed_crystal_three_quarter", focus + Vector3(-18, 10, 24), focus + Vector3(0, 1, 0), 38.0)
	await _shoot(camera, "06_completed_crystal_side_detail", focus + Vector3(25, 8, -3), focus + Vector3(0, 1.5, 0), 34.0)
	await _shoot(camera, "07_completed_crystal_high_angle", focus + Vector3(18, 28, 22), focus + Vector3(0, 0.5, 0), 36.0)

	print("TORCH_SPARK_SOCKET_CAPTURE: PASS — wrote 8 real in-game location screenshots")
	quit()


func _settle() -> void:
	for _frame in 5:
		await process_frame
		await RenderingServer.frame_post_draw


func _shoot(camera: Camera3D, filename: String, eye: Vector3, look: Vector3, fov: float) -> void:
	camera.fov = fov
	camera.global_position = eye
	camera.look_at(look, Vector3.UP)
	await _settle()
	var output := "%s/%s.png" % [OUTPUT_DIR, filename]
	var image := root.get_texture().get_image()
	var error := image.save_png(output)
	if error != OK:
		push_error("TORCH_SPARK_SOCKET_CAPTURE: %s" % error_string(error))
		quit(1)
		return
	print("TORCH_SPARK_SOCKET_CAPTURE: wrote %s" % output)
