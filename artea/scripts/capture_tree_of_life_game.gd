extends SceneTree

## Captures the live Godot placement with the production world, materials,
## player, and lighting. Blender beauty renders alone cannot prove integration.

const WorldScene := preload("res://scenes/art_castle_floating_world.tscn")
const OUTPUT_DIR := "res://artifacts/tree_of_life_godot"


func _init() -> void:
	call_deferred("_capture")


func _save_view(file_name: String) -> bool:
	print("TREE_OF_LIFE_GAME_CAPTURE: preparing %s" % file_name)
	for _frame in 4:
		await process_frame
	print("TREE_OF_LIFE_GAME_CAPTURE: waiting for rendered frame %s" % file_name)
	await RenderingServer.frame_post_draw
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("TREE_OF_LIFE_GAME_CAPTURE: could not save %s: %s"
			% [path, error_string(error)])
		return false
	print("TREE_OF_LIFE_GAME_CAPTURE: wrote %s" % path)
	return true


func _capture() -> void:
	print("TREE_OF_LIFE_GAME_CAPTURE: building proof scene")
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var world := WorldScene.instantiate() as Node3D
	# Build exactly the production court and tree before the node enters the
	# tree, then detach the full-world generator. This avoids submitting distant
	# districts and decorative flower fields to the renderer without replacing
	# any tree, player, material, or court implementation code.
	world.call("_build_materials")
	var sanctuary := Node3D.new()
	sanctuary.name = "CentralSanctuary"
	world.add_child(sanctuary)
	var materials := world.get("_materials") as Dictionary
	var hub := Vector3(0.0, 0.0, 1640.0)
	world.call("_add_cylinder", sanctuary, "TreeCourt", hub + Vector3(0.0, 0.1, 0.0),
		108.0, 1.4, materials.stone, true, 48)
	world.call("_build_life_tree", sanctuary, hub)
	print("TREE_OF_LIFE_GAME_CAPTURE: production court and tree built")
	world.set_script(null)
	root.add_child(world)
	current_scene = world
	for _frame in 6:
		await process_frame
		await physics_frame

	var tree := world.get_node("CentralSanctuary/TreeOfImagination") as Node3D
	var player := world.get_node("Player3D") as CharacterBody3D
	var camera := world.get_node("Camera3D") as Camera3D
	player.set_physics_process(false)
	player.set_process_input(false)
	camera.set_script(null)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.near = 0.1
	camera.far = 8000.0
	camera.make_current()

	# Player-scale entrance proof: the center arch and cyan route remain open.
	var center := tree.global_position
	player.global_position = center + Vector3(0.0, 1.45, -134.0)
	player.velocity = Vector3.ZERO
	player.look_at(center + Vector3(0.0, 1.45, 0.0), Vector3.UP)
	player.rotate_y(PI)
	camera.fov = 68.0
	camera.global_position = center + Vector3(0.0, 18.0, -168.0)
	camera.look_at(center + Vector3(0.0, 42.0, 0.0), Vector3.UP)
	if not await _save_view("player_entrance.png"):
		quit(1)
		return

	# Powered approach proof: route grating, paired supply cables and the root
	# doorway are inspected from player height before the isolated root elevation.
	player.visible = false
	camera.fov = 58.0
	camera.global_position = center + Vector3(20.0, 15.0, -110.0)
	camera.look_at(center + Vector3(0.0, 8.0, -10.0), Vector3.UP)
	if not await _save_view("powered_root_route.png"):
		quit(1)
		return

	# Straight-on doorway proof: the paired living-root jambs, powered frame,
	# dark chamber and uninterrupted player route must read as one composition.
	camera.fov = 34.0
	camera.global_position = center + Vector3(0.0, 26.0, -146.0)
	camera.look_at(center + Vector3(0.0, 14.0, -8.0), Vector3.UP)
	if not await _save_view("root_doorway_closeup.png"):
		quit(1)
		return

	# Root-foundation proof: a low front three-quarter view isolates the buttress
	# hierarchy, entrance arch, ground roots, bark panels and embedded sap inlays.
	camera.fov = 48.0
	camera.global_position = center + Vector3(0.0, 36.0, -146.0)
	camera.look_at(center + Vector3(0.0, 18.0, -3.0), Vector3.UP)
	if not await _save_view("root_foundation_closeup.png"):
		quit(1)
		return

	# Landmark proof: nature canopy, magic crystals, technical sap conduits,
	# engineered gold systems, and the central passage in the real world.
	camera.fov = 62.0
	camera.global_position = center + Vector3(152.0, 118.0, -184.0)
	camera.look_at(center + Vector3(0.0, 62.0, 0.0), Vector3.UP)
	if not await _save_view("world_isometric.png"):
		quit(1)
		return

	# Orthogonal design checks requested for the foliage hierarchy. These two
	# elevations expose whether every leaf pad has a visible route back through
	# its support twig, secondary branch, and major limb.
	camera.fov = 52.0
	camera.global_position = center + Vector3(0.0, 94.0, -258.0)
	camera.look_at(center + Vector3(0.0, 66.0, 0.0), Vector3.UP)
	if not await _save_view("front_elevation.png"):
		quit(1)
		return

	camera.global_position = center + Vector3(258.0, 94.0, 0.0)
	camera.look_at(center + Vector3(0.0, 66.0, 0.0), Vector3.UP)
	if not await _save_view("side_elevation.png"):
		quit(1)
		return

	print("TREE_OF_LIFE_GAME_CAPTURE: PASS — production placement, front, side, and player entrance captured")
	quit()
