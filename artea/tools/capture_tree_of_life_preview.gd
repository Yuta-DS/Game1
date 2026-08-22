extends SceneTree

## Render the Tree of Life on its own, away from the floating world.
##
## capture_tree_of_life_game.gd builds the whole production island first, and on
## a Metal backend that first frame can exceed the GPU fence timeout - every
## saved image then comes out black. This loads only the tree GLB, its canopy and
## a camera, so the frame is cheap enough to finish, and it waits for several
## presented frames before reading the viewport back.
##
##   Godot --path artea --script res://tools/capture_tree_of_life_preview.gd

const TreeScene := preload("res://assets3D/tree_of_life/glb/artea_tree_of_life.glb")
const CanopyScene := preload("res://assets3D/tree_of_life/canopy/glb/crystal_branch_canopy.glb")
const OUTPUT_DIR := "res://artifacts/tree_of_life_preview"
const GAME_SCALE := 3.30

# The heart crystal sits at Blender z=20, which is up in Godot after import.
const HEART_HEIGHT := 20.0 * GAME_SCALE


func _init() -> void:
	call_deferred("_capture")


func _settle(frames: int) -> void:
	for _frame in frames:
		await process_frame
	await RenderingServer.frame_post_draw


func _save(camera: Camera3D, file_name: String) -> void:
	await _settle(24)
	var image := root.get_texture().get_image()
	if image == null:
		print("TREE_PREVIEW: no image for %s" % file_name)
		return
	# A fence timeout leaves the framebuffer untouched, so check before writing
	# rather than silently overwriting a good capture with black.
	var non_black := 0
	for x in range(0, image.get_width(), 16):
		for y in range(0, image.get_height(), 16):
			if image.get_pixel(x, y).get_luminance() > 0.02:
				non_black += 1
	if non_black == 0:
		print("TREE_PREVIEW: BLACK FRAME for %s - not saving" % file_name)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	image.save_png(path)
	print("TREE_PREVIEW: wrote %s (%d sampled lit pixels)" % [path, non_black])


func _capture() -> void:
	print("TREE_PREVIEW: building isolated tree scene")
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world

	var tree := TreeScene.instantiate() as Node3D
	tree.scale = Vector3.ONE * GAME_SCALE
	world.add_child(tree)

	var canopy := CanopyScene.instantiate() as Node3D
	canopy.scale = Vector3.ONE * GAME_SCALE
	canopy.rotation.y = PI
	world.add_child(canopy)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	sun.light_energy = 1.5
	world.add_child(sun)

	# The heart crystal is emissive, so a dim ambient keeps it reading as the
	# brightest thing in frame rather than being washed out.
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1b2436")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6d7f9c")
	environment.ambient_light_energy = 0.55
	environment.glow_enabled = true
	var camera := Camera3D.new()
	camera.environment = environment
	camera.far = 4000.0
	world.add_child(camera)
	camera.make_current()

	var heart := Vector3(0.0, HEART_HEIGHT, 0.0)

	# Whole tree, from the south approach the game uses.
	camera.fov = 55.0
	camera.global_position = Vector3(0.0, HEART_HEIGHT * 0.9, -330.0)
	camera.look_at(Vector3(0.0, HEART_HEIGHT * 0.75, 0.0), Vector3.UP)
	await _save(camera, "tree_full.png")

	# The heart crystal itself.
	camera.fov = 32.0
	camera.global_position = heart + Vector3(0.0, 12.0, -150.0)
	camera.look_at(heart, Vector3.UP)
	await _save(camera, "heart_crystal.png")

	# Three-quarter view so the brass housing rings around the crystal read.
	camera.fov = 38.0
	camera.global_position = heart + Vector3(-115.0, 42.0, -115.0)
	camera.look_at(heart, Vector3.UP)
	await _save(camera, "heart_crystal_three_quarter.png")

	print("TREE_PREVIEW: done")
	quit()
