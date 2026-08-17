extends SceneTree

## Captures the live gallery game with the real fox player and gameplay HUD at
## two bridge repairs. This is presentation proof, not a diagnostic render.

const OUTPUT_DIR := "res://artifacts/gameplay_island_bridges"


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	current_scene = gallery
	for _frame in 16:
		await process_frame
		await physics_frame

	var floating_world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var player := gallery.get_node("Player3D") as CharacterBody3D
	var camera := gallery.get_node("Camera3D") as Camera3D
	if player.get_node_or_null("FoxVisuals/Fox") == null:
		push_error("GAMEPLAY_BRIDGE_CAPTURE: real fox visuals are missing")
		quit(1)
		return
	player.set_physics_process(false)
	player.set_process_input(false)
	camera.set_script(null)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 64.0
	camera.near = 0.1
	camera.far = 8000.0
	camera.make_current()

	# The direct Tree of Imagination -> Mind Bridge -> Mind Spark route. This
	# shows the centered rune floor in the real gallery game, with the fox and HUD.
	await _capture_gameplay_view(gallery, player, camera,
		floating_world.to_global(Vector3(-395.0, 0.0, 1640.0)),
		floating_world.to_global(Vector3(-600.0, 0.0, 1640.0)),
		"mind_district_ground_gameplay.png")

	var world_one := floating_world.get_node("MindSparkWorldOne") as MindSparkWorldOne
	world_one.set_world_state("gentle_rain")
	var transit_portal := world_one.get_node(
		"WorldOneGeometry/MindSparkTransitNetwork/Transit_02_to_05") as MindSparkWorldGate
	var portal_approach: Vector3 = transit_portal.get_meta("approach_world_one_local")
	await _capture_gameplay_view(gallery, player, camera,
		world_one.to_global(portal_approach), transit_portal.global_position,
		"mind_spark_island_portal_gameplay.png")
	var route := world_one.get_node("WorldOneGeometry/MainStoryCircuitRoute") as Node3D
	var landing := route.get_node("CircuitRoute_01_B") as MeshInstance3D
	var landing_mesh := landing.mesh as BoxMesh
	var zone_global := world_one.to_global(world_one.get_zone_position("02_living_network_forest"))
	var end_a := landing.to_global(Vector3(0, landing_mesh.size.y * 0.5, -landing_mesh.size.z * 0.5))
	var end_b := landing.to_global(Vector3(0, landing_mesh.size.y * 0.5, landing_mesh.size.z * 0.5))
	var island_end := end_a if end_a.distance_to(zone_global) < end_b.distance_to(zone_global) else end_b
	var bridge_end := end_b if island_end == end_a else end_a
	await _capture_gameplay_view(gallery, player, camera,
		bridge_end.lerp(island_end, 0.18), island_end,
		"living_network_bridge_gameplay.png")

	var shelf := floating_world.get_node(
		"KingdomRegions3000m/MindKingdom3000m/OptimizedLandmass/" \
		+ "InterIslandBridgeGrid/ShelfBridge_00_00_to_00_01") as Node3D
	var shelf_start := floating_world.to_global(shelf.get_meta("walk_start"))
	var shelf_finish := floating_world.to_global(shelf.get_meta("walk_finish"))
	await _capture_gameplay_view(gallery, player, camera,
		shelf_start.lerp(shelf_finish, 0.35), shelf_finish,
		"mind_kingdom_shelf_bridge_gameplay.png")

	print("GAMEPLAY_BRIDGE_CAPTURE: PASS — live fox, HUD, lighting, bridges, and Mind ground captured")
	quit()


func _capture_gameplay_view(gallery: Node3D, player: CharacterBody3D, camera: Camera3D,
		player_position: Vector3, look_destination: Vector3, file_name: String) -> void:
	var forward := Vector3(
		look_destination.x - player_position.x, 0.0,
		look_destination.z - player_position.z).normalized()
	player.global_position = player_position + Vector3.UP * 1.45
	player.velocity = Vector3.ZERO
	player.look_at(player.global_position + forward, Vector3.UP)
	# The imported fox visual faces the node's +Z direction, opposite Godot's
	# conventional -Z look direction. Turn the body so the gameplay camera sees
	# the character from behind, matching normal player control.
	player.rotate_y(PI)
	camera.global_position = player.global_position - forward * 15.5 + Vector3.UP * 7.0
	camera.look_at(player.global_position + forward * 22.0 + Vector3.UP * 2.6, Vector3.UP)
	for _frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var output := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("GAMEPLAY_BRIDGE_CAPTURE: could not save %s: %s" % [output, error_string(error)])
		quit(1)
		return
	print("GAMEPLAY_BRIDGE_CAPTURE: wrote %s" % output)
