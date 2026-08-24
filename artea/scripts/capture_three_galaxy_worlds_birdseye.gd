extends SceneTree

# Captures the three authored 3 km Art Castle Gallery kingdoms from a true
# orthographic bird's-eye camera. This renders the live runtime-built world,
# not a concept illustration.

const OUTPUT_DIR := "res://artifacts/galaxy_worlds_birdseye"
const CAPTURE_SIZE := Vector2i(1280, 1280)
const CAMERA_HEIGHT := 3600.0
const MAP_SPAN := 3400.0


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = CAPTURE_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	# Load the exact runtime kingdom generator without the unrelated gallery,
	# inner islands, player, trains, UI, and online gallery manager. This gives
	# the same three playable landscapes while making high-resolution overhead
	# rendering practical.
	var world := Node3D.new()
	world.name = "GalaxyBirdseyeWorld"
	root.add_child(world)
	current_scene = world
	var regions := Node3D.new()
	regions.name = "KingdomRegions3000m"
	regions.set_script(load("res://scripts/art_castle_kingdom_regions.gd"))
	world.add_child(regions)
	_grade_kingdom(regions.get_node_or_null("MindKingdom3000m"), Color("a4b9d4"))
	_grade_kingdom(regions.get_node_or_null("HeartKingdom3000m"), Color("789b78"))
	_grade_kingdom(regions.get_node_or_null("CreatorKingdom3000m"), Color("ad8c5e"))

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("090d22")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9aabd0")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.82
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 1.18
	environment_node.environment = environment
	world.add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	sun.light_color = Color("fff0cf")
	sun.light_energy = 0.62
	sun.shadow_enabled = false
	world.add_child(sun)
	for _frame in 3:
		await process_frame

	var camera := Camera3D.new()
	camera.name = "GalaxyWorldBirdseyeCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = MAP_SPAN
	camera.near = 1.0
	camera.far = 9000.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	world.add_child(camera)
	camera.make_current()

	var centres: Dictionary = regions.call("get_kingdom_centers")
	var captures := [
		["mind", "mind_spark_birdseye.png"],
		["heart", "heart_melody_birdseye.png"],
		["creator", "creators_light_birdseye.png"],
	]
	for capture in captures:
		var kingdom_id: String = capture[0]
		var local_centre: Vector3 = centres[kingdom_id]
		var centre := regions.to_global(local_centre)
		camera.global_position = centre + Vector3.UP * CAMERA_HEIGHT
		# A straight-down camera needs a non-parallel up vector. World -Z is the
		# top edge, keeping all three screenshots consistently north-up.
		camera.look_at(centre, Vector3(0.0, 0.0, -1.0))
		for _settle in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s" % [OUTPUT_DIR, capture[1]]
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			_fail("Could not save %s: %s" % [path, error_string(error)])
			return
		print("GALAXY_BIRDSEYE_CAPTURE: wrote %s" % path)

	print("GALAXY_BIRDSEYE_CAPTURE: PASS — captured Mind, Heart, and Creator worlds")
	quit()


func _fail(message: String) -> void:
	push_error("GALAXY_BIRDSEYE_CAPTURE: %s" % message)
	quit(1)


func _grade_kingdom(kingdom: Node, landscape_tint: Color) -> void:
	if kingdom == null:
		return
	for child in kingdom.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if not mesh_instance.material_override is StandardMaterial3D:
			continue
		var original := mesh_instance.material_override as StandardMaterial3D
		var material := original.duplicate() as StandardMaterial3D
		var base := material.albedo_color
		# The shared ivory ground is deliberately pale in the gameplay world. Give
		# it a kingdom-specific cartographic tint for overhead readability.
		if base.r > 0.72 and base.g > 0.72 and base.b > 0.72:
			material.albedo_color = landscape_tint
		else:
			material.albedo_color = Color(
				base.r * 0.78, base.g * 0.78, base.b * 0.78, base.a)
		if material.emission_enabled:
			material.emission_energy_multiplier *= 0.22
		mesh_instance.material_override = material
