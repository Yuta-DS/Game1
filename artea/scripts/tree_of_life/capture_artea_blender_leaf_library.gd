extends SceneTree

## Captures only the standalone Blender leaf library after Godot import.

const LeafLibraryScene := preload("res://assets3D/tree_of_life/leaves/glb/artea_leaf_library.glb")
const OUTPUT_PATH := "res://artifacts/tree_of_life_leaves/leaf_library_godot.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var scene := Node3D.new()
	scene.name = "StandaloneArteaLeafLibraryCapture"
	root.add_child(scene)
	current_scene = scene
	_build_environment(scene)
	var library := LeafLibraryScene.instantiate() as Node3D
	library.name = "ImportedStandaloneLeafLibrary"
	# Blender XY leaf planes import as Godot XZ. Rotate the gallery root only so
	# the reusable source geometry faces the orthographic inspection camera.
	library.rotation_degrees.x = 90.0
	scene.add_child(library)
	_add_label(scene, "LIVING LEAF FAN", Vector3(-4.5, 6.55, 0.65), 62)
	_add_label(scene, "MAGIC RUNE LEAF", Vector3(5.65, 6.55, 0.65), 62)
	_add_label(scene, "SOLAR-GLASS SCIENCE LEAF", Vector3(-2.1, -0.25, 0.65), 55)
	_add_label(scene, "EMERALD SENSOR LEAF", Vector3(5.65, -0.25, 0.65), 57)
	_add_label(scene, "STANDALONE EDITABLE LEAF LIBRARY • NO TREE GEOMETRY",
		Vector3(0, -7.0, 0.65), 50, Color("52e5ff"))
	for _frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	if error != OK:
		push_error("ARTEA_BLENDER_LEAF_CAPTURE: %s" % error_string(error))
		quit(1)
		return
	print("ARTEA_BLENDER_LEAF_CAPTURE: PASS — wrote %s" % OUTPUT_PATH)
	quit()


func _build_environment(scene: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("020b1a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("87a6c4")
	environment.ambient_light_energy = 0.90
	var world := WorldEnvironment.new()
	world.environment = environment
	scene.add_child(world)

	var board := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(24.5, 15.5)
	board.mesh = quad
	var board_material := StandardMaterial3D.new()
	board_material.albedo_color = Color("031128")
	board_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	board.material_override = board_material
	board.position.z = -1.3
	scene.add_child(board)

	var key := DirectionalLight3D.new()
	key.light_color = Color("dcefff")
	key.light_energy = 1.85
	key.rotation_degrees = Vector3(-24, -30, 0)
	scene.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("c78cff")
	fill.light_energy = 0.72
	fill.rotation_degrees = Vector3(20, 145, 0)
	scene.add_child(fill)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0
	camera.position = Vector3(0, 0, 20)
	scene.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.make_current()


func _add_label(parent: Node3D, text: String, position: Vector3,
		font_size: int, color := Color("d8bd77")) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = font_size
	label.pixel_size = 0.0045
	label.modulate = color
	label.outline_modulate = Color("07101d")
	label.outline_size = 8
	label.no_depth_test = true
	parent.add_child(label)
