extends SceneTree

## Fast, focused Godot proof of the production heart builder. It uses the same
## runtime shrine and trunk-facade functions as the world, without submitting
## the unrelated canopy or districts to the software renderer.

const WorldScript := preload("res://scripts/art_castle_floating_world.gd")
const OUTPUT_DIR := "res://artifacts/tree_of_life_godot"


func _init() -> void:
	call_deferred("_capture")


func _save_view(file_name: String) -> bool:
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(
		"%s/%s" % [OUTPUT_DIR, file_name])
	if error != OK:
		push_error("TREE_HEART_SOCKET_CAPTURE: could not save %s" % file_name)
		return false
	return true


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(
		"res://artifacts/tree_of_life_godot"))
	var scene := Node3D.new()
	scene.name = "FocusedProductionHeartSocketProof"
	root.add_child(scene)
	current_scene = scene

	var builder := WorldScript.new()
	var tree := Node3D.new()
	tree.name = "TreeOfImagination"
	tree.set_meta("simple_trunk_core", true)
	scene.add_child(tree)
	# The same authoritative 58k-triangle Blender lower body used by production,
	# followed by its procedural braided facade and heart systems.
	builder.call("_build_blender_blueprint_trunk_root", tree)
	builder.call("_build_reference_trunk_root_facade", tree)
	builder.call("_build_wisdom_heart_shrine", tree)

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("071015")
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color("5f83a0")
	environment_resource.ambient_light_energy = 0.42
	environment.environment = environment_resource
	scene.add_child(environment)

	var key := DirectionalLight3D.new()
	key.name = "WarmTreeKey"
	key.light_color = Color("ffd29a")
	key.light_energy = 1.65
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-32.0, -28.0, 0.0)
	scene.add_child(key)
	var fill := OmniLight3D.new()
	fill.name = "CoolHeartFill"
	fill.position = Vector3(-32.0, 68.0, -104.0)
	fill.light_color = Color("5dbdff")
	fill.light_energy = 3.2
	fill.omni_range = 140.0
	fill.shadow_enabled = false
	scene.add_child(fill)

	var camera := Camera3D.new()
	camera.name = "HeartSocketInspectionCamera"
	camera.fov = 34.0
	camera.near = 0.1
	camera.far = 1000.0
	camera.position = Vector3(0.0, 60.0, -150.0)
	scene.add_child(camera)
	camera.look_at(Vector3(0.0, 54.25, -56.0), Vector3.UP)
	camera.make_current()

	if not await _save_view("blue_heart_frame_closeup.png"):
		quit(1)
		return

	# Player-facing lower-body proof: thick interlocking roots, the protected
	# doorway and surface-fitted cyan energy fibers in one readable frame.
	camera.fov = 34.0
	camera.position = Vector3(0.0, 18.0, -205.0)
	camera.look_at(Vector3(0.0, 22.0, -49.0), Vector3.UP)
	if not await _save_view("root_energy_system_closeup.png"):
		quit(1)
		return

	# Wider implementation inventory: roots, braided trunk, energy routes,
	# embedded heart gear and Dyson sphere together in the actual runtime stack.
	camera.fov = 42.0
	camera.position = Vector3(0.0, 52.0, -240.0)
	camera.look_at(Vector3(0.0, 50.0, -49.0), Vector3.UP)
	if not await _save_view("implemented_tree_systems_overview.png"):
		quit(1)
		return
	print("TREE_HEART_SOCKET_CAPTURE: PASS — production roots, embedded fibers, trunk, heart and Dyson sphere captured")
	quit()
