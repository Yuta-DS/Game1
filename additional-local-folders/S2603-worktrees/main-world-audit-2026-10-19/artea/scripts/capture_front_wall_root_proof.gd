extends SceneTree

const OUTPUT_PATH := "res://artifacts/front_wall_root_support_proof.png"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var stage := Node3D.new()
	root.add_child(stage)

	# Build the exact runtime root meshes, then isolate the newly confirmed front
	# pair so their placement is unambiguous in this verification image.
	var builder := Node3D.new()
	builder.set_script(load("res://scripts/hub_lumen_citadel.gd"))
	var foundation := Node3D.new()
	foundation.name = "CastleFoundationProof"
	stage.add_child(foundation)
	builder.set("_foundation", foundation)
	builder.call("_build_giant_tree_foundation")
	var tree := foundation.get_node("GiantTreeFoundation") as Node3D
	for child in tree.get_children():
		(child as Node3D).visible = child.name == "FrontWallCenterSupports"

	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color("123f79")
	blue.roughness = 0.48
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color("7a993f")
	trim.metallic = 0.35
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("79efff")
	glow.emission_enabled = true
	glow.emission = Color("53dfff")
	glow.emission_energy_multiplier = 1.8

	# The bottom-centre of each wall is exactly the target_center stored on its
	# corresponding runtime root: gallery (11.6, 4.15, 0), crystal (29.5, -3.35, 0).
	_add_box(stage, "GalleryEntranceWall", Vector3(0.8, 15.5, 11.0),
		Vector3(11.6, 11.9, 0.0), blue)
	_add_box(stage, "GalleryTopTrim", Vector3(1.05, 0.42, 11.4),
		Vector3(11.6, 19.7, 0.0), trim)
	_add_box(stage, "CrystalWindowWall", Vector3(0.8, 22.0, 16.0),
		Vector3(29.5, 7.65, 0.0), blue)
	_add_box(stage, "CrystalTopTrim", Vector3(1.05, 0.42, 16.4),
		Vector3(29.5, 18.7, 0.0), trim)

	var label := Label3D.new()
	label.text = "✦ ART EXPLORE ✦\nENTER THE GALLERY"
	label.font_size = 34
	label.pixel_size = 0.013
	label.modulate = Color("fff0ae")
	label.outline_size = 8
	label.position = Vector3(12.05, 13.0, 0.0)
	label.rotation_degrees.y = 90.0
	stage.add_child(label)
	for crystal_y in [3.0, 12.2]:
		var crystal := MeshInstance3D.new()
		var crystal_mesh := SphereMesh.new()
		crystal_mesh.radius = 1.2
		crystal_mesh.height = 2.4
		crystal_mesh.radial_segments = 8
		crystal_mesh.rings = 4
		crystal.mesh = crystal_mesh
		crystal.material_override = glow
		crystal.position = Vector3(30.05, crystal_y, 0.0)
		stage.add_child(crystal)

	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("548f3c")
	ground_material.roughness = 1.0
	_add_box(stage, "Ground", Vector3(55.0, 1.0, 42.0),
		Vector3(18.0, -49.6, 0.0), ground_material)

	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-42.0, -48.0, 0.0)
	sunlight.light_energy = 1.45
	sunlight.shadow_enabled = true
	stage.add_child(sunlight)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("87d9ff")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c7e7ff")
	environment.ambient_light_energy = 0.78
	world_environment.environment = environment
	stage.add_child(world_environment)

	var camera := Camera3D.new()
	camera.fov = 58.0
	stage.add_child(camera)
	camera.position = Vector3(72.0, -8.0, 43.0)
	camera.look_at(Vector3(20.0, -11.0, 0.0), Vector3.UP)
	camera.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	var error := root.get_texture().get_image().save_png(OUTPUT_PATH)
	if error != OK:
		push_error("FRONT_ROOT_PROOF: failed %s" % error_string(error))
		quit(1)
		return
	print("FRONT_ROOT_PROOF: PASS — %s" % OUTPUT_PATH)
	quit()

func _add_box(parent: Node3D, name: String, size: Vector3, position: Vector3,
		material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.name = name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
