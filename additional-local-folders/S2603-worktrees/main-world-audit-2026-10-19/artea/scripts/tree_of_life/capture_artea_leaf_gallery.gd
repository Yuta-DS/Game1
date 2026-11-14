extends SceneTree

## Renders the four native Godot leaf constructions in a reference-aligned
## component gallery. This is deliberately independent of Blender.

const LeafFactory := preload("res://scripts/tree_of_life/artea_leaf_factory.gd")
const OUTPUT_PATH := "res://artifacts/tree_of_life_godot/leaf_component_gallery.png"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var scene := Node3D.new()
	scene.name = "ArteaLeafComponentGallery"
	root.add_child(scene)
	current_scene = scene
	_build_environment(scene)

	var living := LeafFactory.create_leaf(LeafFactory.LeafType.LIVING_FAN, "LivingLeafFan_Showcase")
	living.position = Vector3(-5.1, 2.75, 0.0)
	living.rotation.z = -0.08
	living.scale = Vector3.ONE * 0.64
	scene.add_child(living)
	_add_label(scene, "LIVING LEAF FAN", Vector3(-5.1, 6.25, 0.4), Color("d8bd77"), 66)

	var magic := LeafFactory.create_leaf(LeafFactory.LeafType.MAGIC_RUNE, "MagicRuneLeaf_Showcase")
	magic.position = Vector3(2.9, 3.0, 0.0)
	magic.rotation.z = 0.10
	magic.scale = Vector3.ONE * 0.74
	scene.add_child(magic)
	_add_label(scene, "MAGIC RUNE LEAF", Vector3(5.0, 6.25, 0.4), Color("d8bd77"), 66)

	var solar := LeafFactory.create_leaf(LeafFactory.LeafType.SOLAR_GLASS, "SolarGlassLeaf_Showcase")
	solar.position = Vector3(-5.2, -3.55, 0.0)
	solar.rotation.z = -0.08
	solar.scale = Vector3.ONE * 0.74
	scene.add_child(solar)
	_add_label(scene, "SOLAR-GLASS SCIENCE LEAF", Vector3(-3.1, -0.45, 0.4), Color("d8bd77"), 59)

	var sensor := LeafFactory.create_leaf(LeafFactory.LeafType.EMERALD_SENSOR, "EmeraldSensorLeaf_Showcase")
	sensor.position = Vector3(3.4, -3.45, 0.0)
	sensor.rotation.z = 0.06
	sensor.scale = Vector3.ONE * 1.10
	scene.add_child(sensor)
	_add_label(scene, "EMERALD SENSOR LEAF", Vector3(5.2, -0.45, 0.4), Color("d8bd77"), 62)

	_add_label(scene, "ARTÉA • NATURE + MAGIC + TECHNOLOGY + SCIENCE", Vector3(0.0, -6.85, 0.5), Color("54e6ff"), 56)
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	if error != OK:
		push_error("ARTEA_LEAF_GALLERY: capture failed: %s" % error_string(error))
		quit(1)
		return
	print("ARTEA_LEAF_GALLERY: PASS — wrote %s" % OUTPUT_PATH)
	quit()


func _build_environment(scene: Node3D) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("020c1d")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7597b5")
	environment.ambient_light_energy = 0.72
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	scene.add_child(world_environment)

	var board := MeshInstance3D.new()
	board.name = "MidnightBlueprintBoard"
	var board_mesh := QuadMesh.new()
	board_mesh.size = Vector2(25.0, 15.5)
	board.mesh = board_mesh
	var board_material := StandardMaterial3D.new()
	board_material.albedo_color = Color("031128")
	board_material.roughness = 0.95
	board_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	board.material_override = board_material
	board.position.z = -1.2
	scene.add_child(board)

	var divider_material := StandardMaterial3D.new()
	divider_material.albedo_color = Color("7b5b2e")
	divider_material.emission_enabled = true
	divider_material.emission = Color("9c7438")
	divider_material.emission_energy_multiplier = 0.35
	for y in [0.0, -6.2, 6.95]:
		_add_board_line(scene, Vector3(-11.8, y, -0.2), Vector3(11.8, y, -0.2), divider_material)
	_add_board_line(scene, Vector3(0.0, -6.2, -0.2), Vector3(0.0, 6.95, -0.2), divider_material)

	var key := DirectionalLight3D.new()
	key.name = "LeafGalleryKey"
	key.light_color = Color("d7efff")
	key.light_energy = 1.65
	key.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
	scene.add_child(key)
	var rim := OmniLight3D.new()
	rim.name = "CyanLeafRim"
	rim.position = Vector3(-5.0, 3.0, 8.0)
	rim.light_color = Color("42ddff")
	rim.light_energy = 5.0
	rim.omni_range = 18.0
	scene.add_child(rim)

	var camera := Camera3D.new()
	camera.name = "LeafGalleryCamera"
	camera.position = Vector3(0.0, 0.0, 18.5)
	camera.fov = 49.0
	scene.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.make_current()


func _add_board_line(parent: Node3D, start: Vector3, end: Vector3,
		material: Material) -> void:
	var direction := end - start
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.018
	mesh.bottom_radius = 0.018
	mesh.height = direction.length()
	mesh.radial_segments = 5
	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.material_override = material
	line.position = (start + end) * 0.5
	line.quaternion = Quaternion(Vector3.UP, direction.normalized())
	parent.add_child(line)


func _add_label(parent: Node3D, text: String, position: Vector3,
		color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = font_size
	label.pixel_size = 0.0045
	label.modulate = color
	label.outline_modulate = Color("07101d")
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = true
	parent.add_child(label)
