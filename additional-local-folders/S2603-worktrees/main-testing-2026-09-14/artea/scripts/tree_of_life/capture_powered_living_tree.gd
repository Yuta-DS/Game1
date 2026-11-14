extends SceneTree

## Godot-rendered approval views for the layered powered-bough canopy.

const WorldScene := preload("res://scenes/art_castle_floating_world.tscn")
const OUTPUT_DIR := "res://artifacts/tree_of_life_powered_godot"


func _init() -> void:
	call_deferred("_capture")


func _save_view(file_name: String) -> bool:
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("POWERED_TREE_CAPTURE: could not save %s: %s" % [path, error_string(error)])
		return false
	print("POWERED_TREE_CAPTURE: wrote %s" % path)
	return true


func _capture() -> void:
	root.size = Vector2i(1600, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var world := WorldScene.instantiate() as Node3D
	world.call("_build_materials")
	var sanctuary := Node3D.new()
	sanctuary.name = "CentralSanctuary"
	world.add_child(sanctuary)
	var materials := world.get("_materials") as Dictionary
	var hub := Vector3(0.0, 0.0, 1640.0)
	world.call("_add_cylinder", sanctuary, "TreeCourt", hub + Vector3(0.0, 0.1, 0.0),
		128.0, 1.4, materials.stone, true, 64)
	world.call("_build_life_tree", sanctuary, hub)
	world.set_script(null)
	root.add_child(world)
	current_scene = world
	for _frame in 12:
		await process_frame
		await physics_frame

	var tree := world.get_node("CentralSanctuary/TreeOfImagination") as Node3D
	var powered_canopy := tree.get_node("PoweredLivingBoughCanopy") as Node3D
	var branch_batch := powered_canopy.get_node_or_null(
		"PoweredBranchStructureBatch") as MultiMeshInstance3D
	var batched_leaves := 0
	var batched_transfer_nodes := 0
	for child_node in powered_canopy.get_children():
		if child_node is MultiMeshInstance3D:
			var child_batch := child_node as MultiMeshInstance3D
			if child_batch.name.begins_with("PoweredLeafBatch_"):
				batched_leaves += child_batch.multimesh.instance_count
	var transfer_batch := powered_canopy.get_node_or_null(
		"PoweredLeafTransferNodeBatch") as MultiMeshInstance3D
	if transfer_batch != null:
		batched_transfer_nodes = transfer_batch.multimesh.instance_count
		if OS.has_environment("POWERED_DIAG_HIDE_TRANSFER"):
			transfer_batch.visible = false
	var powered_root_fibers := int(powered_canopy.get_meta("powered_root_fiber_meshes", 0))
	var powered_boughs := int(powered_canopy.get_meta("powered_bough_instances", 0))
	if powered_boughs != 480 \
			or branch_batch == null \
			or branch_batch.multimesh.instance_count != 480 \
			or batched_leaves != 1244160 \
			or batched_transfer_nodes != 1244160 \
			or powered_root_fibers < 48:
		push_error("POWERED_TREE_CAPTURE: invalid boughs/leaves/nodes %d/%d/%d"
			% [powered_boughs, batched_leaves, batched_transfer_nodes])
		quit(1)
		return
	var player := world.get_node("Player3D") as CharacterBody3D
	var camera := world.get_node("Camera3D") as Camera3D
	player.visible = false
	player.set_physics_process(false)
	camera.set_script(null)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.near = 0.1
	camera.far = 8000.0
	camera.make_current()
	var center := tree.global_position
	if OS.has_environment("POWERED_CLOSEUP_ONLY"):
		camera.fov = 46.0
		camera.global_position = center + Vector3(112.0, 91.0, -145.0)
		camera.look_at(center + Vector3(34.0, 60.0, -8.0), Vector3.UP)
		if not await _save_view("powered_bough_energy_closeup.png"):
			quit(1)
			return
		print("POWERED_TREE_CAPTURE: PASS closeup-only boughs=%d leaves=%d root_fibers=%d"
			% [powered_boughs, batched_leaves, powered_root_fibers])
		quit()
		return

	# Full front elevation: broad living lower tier, irregular middle tier and
	# shorter crown branches must read as a single rooted organism.
	camera.fov = 54.0
	camera.global_position = center + Vector3(0.0, 102.0, -330.0)
	camera.look_at(center + Vector3(0.0, 69.0, 0.0), Vector3.UP)
	if not await _save_view("powered_living_tree_front.png"):
		quit(1)
		return

	# Three-quarter view proves radial canopy depth and gravity-shaped tips.
	camera.fov = 58.0
	camera.global_position = center + Vector3(255.0, 148.0, -275.0)
	camera.look_at(center + Vector3(0.0, 70.0, 0.0), Vector3.UP)
	if not await _save_view("powered_living_tree_three_quarter.png"):
		quit(1)
		return

	# Canopy detail exposes the animated biofiber route from main limb into
	# lateral, twig and leaf transfer nodes in the real Godot material pipeline.
	camera.fov = 46.0
	camera.global_position = center + Vector3(112.0, 91.0, -145.0)
	camera.look_at(center + Vector3(34.0, 60.0, -8.0), Vector3.UP)
	if not await _save_view("powered_bough_energy_closeup.png"):
		quit(1)
		return

	print("POWERED_TREE_CAPTURE: PASS modules=%d leaves=%d transfer_nodes=%d root_fibers=%d"
		% [int(powered_canopy.get_meta("powered_bough_instances", 0)),
			batched_leaves, batched_transfer_nodes, powered_root_fibers])
	quit()
