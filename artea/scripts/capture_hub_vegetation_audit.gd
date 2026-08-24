extends SceneTree

const OVERVIEW_PATH := "res://artifacts/hub_vegetation_overview.png"
const PLAYER_PATH := "res://artifacts/hub_vegetation_player_view.png"
const COAST_PATH := "res://artifacts/hub_sea_sky_coast.png"
const HORIZON_PATH := "res://artifacts/hub_sea_sky_horizon.png"
const VEGETATION_CLOSE_PATH := "res://artifacts/hub_3d_grass_flowers_close.png"
const VILLAGE_BRICK_PATH := "res://artifacts/hub_village_brick_plaza.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(hub)
	for _frame in 90:
		await process_frame
	for layer in hub.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false

	var camera := Camera3D.new()
	camera.far = 800.0
	hub.add_child(camera)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute("res://artifacts")

	var flower_output := hub.get_node_or_null(
		"Environment/Grass/ScatterOutput/ScatterItemFlowerRed") as Node3D
	var flower_multimeshes: Array = flower_output.find_children(
		"MultiMeshInstance3D*", "MultiMeshInstance3D", true, false) if flower_output != null else []
	var flower_target: Vector3
	var close_position: Vector3
	var preview: Node3D
	if flower_multimeshes.is_empty():
		# The runtime scatter can finish after an automated capture starts. Build a
		# small preview from the exact production scenes so their solid geometry is
		# still visually audited instead of silently skipping the close view.
		preview = _build_vegetation_preview()
		hub.add_child(preview)
		preview.global_position = Vector3(0, 900.0, 0)
		flower_target = preview.global_position + Vector3(0, 0.3, 0)
		close_position = flower_target + Vector3(2.4, 1.3, 2.4)
	else:
		var flower_multimesh := flower_multimeshes[0] as MultiMeshInstance3D
		flower_target = (flower_multimesh.global_transform \
			* flower_multimesh.multimesh.get_instance_transform(0)).origin + Vector3(0, 0.22, 0)
		close_position = flower_target + Vector3(1.8, 1.05, 1.8)
	camera.fov = 54.0
	if not await _save(camera, close_position, flower_target, VEGETATION_CLOSE_PATH):
		quit(1)
		return
	if preview != null:
		preview.queue_free()

	camera.fov = 60.0
	if not await _save(camera, Vector3(90.0, 78.0, 65.0),
			Vector3(90.0, 20.0, -30.0), VILLAGE_BRICK_PATH):
		quit(1)
		return

	camera.fov = 62.0
	if not await _save(camera, Vector3(0.0, 300.0, 0.0), Vector3(0.0, 20.0, 0.0), OVERVIEW_PATH):
		quit(1)
		return
	camera.fov = 68.0
	if not await _save(camera, Vector3(12.0, 28.5, -12.0), Vector3(-2.0, 25.0, 18.0), PLAYER_PATH):
		quit(1)
		return
	camera.fov = 66.0
	if not await _save(camera, Vector3(-168.0, 18.0, 15.0), Vector3(-310.0, 3.0, 10.0), COAST_PATH):
		quit(1)
		return
	camera.fov = 58.0
	if not await _save(camera, Vector3(-125.0, 44.0, 65.0), Vector3(-330.0, 5.0, 20.0), HORIZON_PATH):
		quit(1)
		return

	print("HUB_VEGETATION_CAPTURE: PASS — wrote vegetation and sea/sky audit views")
	quit()


func _build_vegetation_preview() -> Node3D:
	var preview := Node3D.new()
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(8.0, 5.0)
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.18, 0.42, 0.12)
	ground_material.roughness = 1.0
	ground_mesh.material = ground_material
	ground.mesh = ground_mesh
	preview.add_child(ground)

	var grass_scene := load("res://scenes/vegetation/grass_clump_3d.tscn") as PackedScene
	for position in [Vector3(-1.7, 0, -0.8), Vector3(-1.1, 0, 0.45),
			Vector3(-0.45, 0, -0.55), Vector3(0.45, 0, 0.7),
			Vector3(1.15, 0, -0.5), Vector3(1.75, 0, 0.5)]:
		var grass := grass_scene.instantiate() as Node3D
		grass.position = position
		grass.scale = Vector3.ONE * 1.35
		preview.add_child(grass)

	var rainbow_names := ["red", "orange", "yellow", "green", "blue", "indigo", "violet"]
	for index in rainbow_names.size():
		var color_name: String = rainbow_names[index]
		var flower_scene := load("res://scenes/vegetation/wildflower_%s_3d.tscn" % color_name) \
			as PackedScene
		var flower := flower_scene.instantiate() as Node3D
		flower.position = Vector3(-2.25 + index * 0.75, 0, -0.2 + (index % 2) * 0.45)
		flower.scale = Vector3.ONE * 1.35
		preview.add_child(flower)
	return preview


func _save(camera: Camera3D, position: Vector3, target: Vector3, path: String) -> bool:
	camera.global_position = position
	camera.look_at(target, Vector3.UP)
	for _frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("HUB_VEGETATION_CAPTURE: failed %s: %s" % [path, error_string(error)])
		return false
	return true
