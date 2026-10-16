extends SceneTree

const OUTPUT := "res://artifacts/castle_galaxy_observatory_upgrade"

func _init() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 18:
		await process_frame
	for canvas in gallery.find_children("*", "CanvasLayer", true, false):
		(canvas as CanvasLayer).visible = false
	var floating_world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var regions := floating_world.get_node_or_null("KingdomRegions3000m") as Node3D
	if regions != null:
		regions.visible = false
	var camera := gallery.get_node("Camera3D") as Camera3D
	camera.set_script(null)
	camera.near = 0.2
	camera.far = 5000.0
	camera.make_current()

	var forecourt := floating_world.get_node(
		"MindSparkDistrict/MindSparkCeremonialForecourt") as Node3D
	camera.fov = 62.0
	camera.global_position = forecourt.to_global(Vector3(0, 7.2, -58))
	camera.look_at(forecourt.to_global(Vector3(0, 10.0, 1)), Vector3.UP)
	await _save("01_castle_bridge_arrival")

	camera.fov = 52.0
	camera.global_position = forecourt.to_global(Vector3(46, 52.0, -58))
	camera.look_at(forecourt.to_global(Vector3(0, 5.0, -5)), Vector3.UP)
	await _save("02_ceremonial_plaza_overview")

	var world := floating_world.get_node("MindSparkWorldOne") as MindSparkWorldOne
	var puzzle := world.get_island_one_puzzle() as MindSparkIslandOnePuzzle
	camera.fov = 60.0
	camera.global_position = puzzle.to_global(Vector3(0, 7.2, -42))
	camera.look_at(puzzle.to_global(Vector3(0, 13.0, 20)), Vector3.UP)
	await _save("03_signal_observatory_approach")

	camera.fov = 54.0
	camera.global_position = puzzle.to_global(Vector3(100, 70, 120))
	camera.look_at(puzzle.to_global(Vector3(0, 8, 18)), Vector3.UP)
	await _save("04_observatory_court_overview")

	camera.fov = 48.0
	camera.global_position = puzzle.to_global(Vector3(0, 22.0, 69.0))
	camera.look_at(puzzle.to_global(Vector3(0, 22.5, 42.0)), Vector3.UP)
	var targets := puzzle._active_ring_targets()
	puzzle.current_state.outer_ring = (targets[0] + 2) % 8
	puzzle.current_state.middle_ring = (targets[1] + 3) % 8
	puzzle.current_state.inner_ring = (targets[2] + 4) % 8
	puzzle._apply_state(false)
	await _save("05_crown_dials_before")

	puzzle.current_state.outer_ring = targets[0]
	puzzle.current_state.middle_ring = targets[1]
	puzzle.current_state.inner_ring = targets[2]
	puzzle._apply_state(false)
	await _save("06_crown_dials_aligned")
	print("CASTLE_GALAXY_OBSERVATORY_UPGRADE_CAPTURE: PASS")
	quit()

func _save(file_name: String) -> void:
	for _frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [OUTPUT, file_name]
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("CASTLE_GALAXY_OBSERVATORY_UPGRADE_CAPTURE: wrote %s" % path)
