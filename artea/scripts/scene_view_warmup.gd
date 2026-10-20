extends RefCounted

## Prepare the real gallery geometry/lighting while the opaque loader owns
## the screen. Synthetic quads do not exercise every real draw configuration.
## Only the camera and visual streaming change; players and physics stay put.
static func run(scene: Node, progress: Callable = Callable()) -> int:
	var world := scene.find_child("ArtCastleFloatingWorld", true, false) as Node3D
	if world == null: return 0
	var camera := world.get_viewport().get_camera_3d()
	if camera == null: return 0
	var tree := scene.get_tree()
	var saved_transform := camera.global_transform
	var saved_process := camera.is_processing()
	var saved_input := camera.is_processing_unhandled_input()
	var director := world.get_node_or_null("WorldStreamingDirector")
	var streaming := false
	var cells: Array[Dictionary] = []
	if director != null:
		streaming = director.is_processing()
		director.set_process(false)
		for cell in director.get("_cells"): cells.append({"cell": cell, "shown": cell.shown})
		director.show_all_managed_cells()
	camera.set_process(false)
	camera.set_process_unhandled_input(false)
	var poses: Array[Transform3D] = []
	# A complete turn from the actual arrival point, including ceiling/floor
	# angles. The player's first turn now hits the real renderer's cache.
	for turn in 8:
		var pose := saved_transform
		pose.basis = Basis(Vector3.UP, turn * TAU / 8.0) * saved_transform.basis
		poses.append(pose)
	# Nearby views of the connected world prepare the music court, garden,
	# tree and studio without moving the player into their interaction zones.
	for name in ["HeartMusicCircle", "HeartMelodyIslandOne", "TreeOfImagination", "CreatorStudio"]:
		var anchor := world.find_child(name, true, false) as Node3D
		if anchor == null: continue
		var focus := anchor.global_position + Vector3.UP * (20.0 if name == "TreeOfImagination" else 3.0)
		var radius := 60.0 if name == "TreeOfImagination" else 35.0
		for turn in 4:
			var eye := focus + Vector3(sin(turn * PI / 2) * radius, 22.0, cos(turn * PI / 2) * radius)
			poses.append(Transform3D(Basis.looking_at(focus - eye), eye))
	var drawn := 0
	for pose in poses:
		if not is_instance_valid(camera) or not is_instance_valid(scene): break
		camera.global_transform = pose
		# process_frame precedes node processing and rendering. Two boundaries
		# ensure the selected view has actually reached the renderer.
		await tree.process_frame
		await tree.process_frame
		drawn += 1
		if progress.is_valid(): progress.call(float(drawn) / poses.size())
	if is_instance_valid(camera):
		camera.global_transform = saved_transform
		camera.set_process(saved_process)
		camera.set_process_unhandled_input(saved_input)
	if is_instance_valid(director):
		for record in cells: director._set_cell_visible(record.cell, record.shown)
		director.set_process(streaming)
	print("SCENE VIEW WARMUP ", drawn, "/", poses.size(), " real views")
	return drawn
