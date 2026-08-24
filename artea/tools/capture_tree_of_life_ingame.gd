extends SceneTree

## Capture the Tree of Life exactly as the game builds it.
##
## The raw GLBs are not what the player sees: art_castle_floating_world.gd hides
## the legacy foliage, batches the crystal canopy leaf families, then replaces
## the whole radial foliage layer with PoweredLivingBoughCanopy. Only the real
## scene produces the real tree, so this instantiates the production world and
## lets it run its own build.
##
## The whole world is far too heavy for one frame on Metal - the GPU fence times
## out and every readback comes back black - so once the build finishes every
## district except the central sanctuary is hidden. The tree then renders alone.
##
##   Godot --path artea --resolution 1280x720 \
##     --script res://tools/capture_tree_of_life_ingame.gd

const WorldScene := preload("res://scenes/art_castle_floating_world.tscn")
const OUTPUT_DIR := "res://artifacts/tree_of_life_ingame"
const GAME_SCALE := 4.20
const HEART_HEIGHT := 20.0 * GAME_SCALE


func _init() -> void:
	call_deferred("_capture")


func _settle(frames: int) -> void:
	for _frame in frames:
		await process_frame
	await RenderingServer.frame_post_draw


func _save(file_name: String) -> void:
	await _settle(30)
	var image := root.get_texture().get_image()
	if image == null:
		print("TREE_INGAME: no image for %s" % file_name)
		return
	# Never overwrite a good capture with a fence-timeout black frame.
	var lit := 0
	for x in range(0, image.get_width(), 16):
		for y in range(0, image.get_height(), 16):
			if image.get_pixel(x, y).get_luminance() > 0.02:
				lit += 1
	if lit == 0:
		print("TREE_INGAME: BLACK FRAME for %s - not saving" % file_name)
		return
	image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	print("TREE_INGAME: wrote %s (%d lit samples)" % [file_name, lit])


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TREE_INGAME: building the production floating world")
	var world := WorldScene.instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	for _frame in 8:
		await process_frame
		await physics_frame

	var sanctuary := world.get_node_or_null("CentralSanctuary") as Node3D
	if sanctuary == null:
		print("TREE_INGAME: no CentralSanctuary - the world did not build")
		quit(1)
		return
	var tree := sanctuary.get_node_or_null("TreeOfImagination") as Node3D
	if tree == null:
		print("TREE_INGAME: no TreeOfImagination under the sanctuary")
		quit(1)
		return
	print("TREE_INGAME: tree found, layers = %s" % [
		tree.get_children().map(func(child: Node) -> String: return child.name)])

	# Drop everything the shot does not need. Terrain, other districts and the
	# bridges are what push a frame past the fence timeout.
	for child in world.get_children():
		var visual := child as Node3D
		if visual != null and visual != sanctuary:
			visual.visible = false
	for child in sanctuary.get_children():
		var visual := child as Node3D
		if visual != null and visual != tree and not visual.name.begins_with("TreeCourt"):
			visual.visible = false
	await _settle(10)

	var camera := Camera3D.new()
	# Use the scene's own WorldEnvironment when it has one. Overriding it with a
	# capture-only environment (glow especially) shows a look the player never
	# sees, which is worse than useless when judging how art reads in game.
	var world_environment := world.find_children("*", "WorldEnvironment", true, false)
	if world_environment.is_empty():
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("121a2b")
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("7286a6")
		environment.ambient_light_energy = 0.6
		camera.environment = environment
		print("TREE_INGAME: scene has no WorldEnvironment, using a neutral one")
	else:
		print("TREE_INGAME: using the scene's WorldEnvironment")
	camera.far = 6000.0
	world.add_child(camera)
	camera.make_current()

	var base := tree.global_position
	var heart := base + Vector3(0.0, HEART_HEIGHT, 0.0)

	camera.fov = 55.0
	camera.global_position = base + Vector3(0.0, HEART_HEIGHT * 0.95, -430.0)
	camera.look_at(base + Vector3(0.0, HEART_HEIGHT * 0.8, 0.0), Vector3.UP)
	await _save("tree_full.png")

	camera.fov = 34.0
	camera.global_position = heart + Vector3(0.0, 10.0, -160.0)
	camera.look_at(heart, Vector3.UP)
	await _save("heart_crystal.png")

	camera.fov = 40.0
	camera.global_position = heart + Vector3(-120.0, 45.0, -120.0)
	camera.look_at(heart, Vector3.UP)
	await _save("heart_crystal_three_quarter.png")

	var shrine := tree.get_node_or_null("WisdomHeartShrine") as Node3D
	if shrine != null:
		var focus := shrine.global_position
		camera.fov = 40.0
		camera.global_position = focus + Vector3(0.0, 5.0, -155.0)
		camera.look_at(focus, Vector3.UP)
		await _save("heart_shrine.png")
		camera.fov = 32.0
		camera.global_position = focus + Vector3(0.0, 3.0, -95.0)
		camera.look_at(focus, Vector3.UP)
		await _save("heart_shrine_closeup.png")
		# Same camera a few seconds later: if the crystal is turning, this frame
		# differs from the one above. A still cannot show rotation on its own.
		await _settle(240)
		await _save("heart_shrine_closeup_later.png")

	# A mid-canopy view, where hanging decoration actually reads. The wide shot
	# renders a 2 unit bauble at about four pixels, which proves nothing.
	camera.fov = 38.0
	camera.global_position = base + Vector3(-60.0, 78.0, -190.0)
	camera.look_at(base + Vector3(0.0, 66.0, 0.0), Vector3.UP)
	await _save("canopy_ornaments.png")

	# Root level, in front of the gate looking up the trunk: the only angle where
	# bark detail is visible at all once the canopy is on.
	camera.fov = 62.0
	camera.global_position = base + Vector3(0.0, 26.0, -215.0)
	camera.look_at(base + Vector3(0.0, 62.0, 0.0), Vector3.UP)
	await _save("trunk_veins.png")

	print("TREE_INGAME: done")
	quit()
