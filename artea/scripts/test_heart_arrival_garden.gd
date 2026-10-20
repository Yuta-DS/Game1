extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for frame in 8:
		await process_frame
		await physics_frame
	var regions := scene.get_node("ArtCastleFloatingWorld/KingdomRegions3000m")
	var court := regions.get_node("HeartKingdomPlatform/ContinuousHeartPaving") as MeshInstance3D
	var garden := regions.get_node("HeartKingdomPlatform/HeartArrivalGarden")
	var fountain := garden.get_node("MusicalFountain")
	assert(fountain.get_node("SkywardMusicNotes").multimesh.instance_count == 28)
	assert(not garden.has_node("BlossomGrove"), "The arrival trees are replaced by the hedge maze")
	var maze := regions.get_node("HeartKingdomPlatform/HeartMusicMaze")
	assert(fountain.global_position.distance_to(maze.to_global(maze.fountain_position())) < 0.03, "Fountain belongs in the maze clearing")
	# All adjacent paving surfaces share a height but never overlap in area.
	assert(court.mesh.get_surface_count() == 3)
	for surface in court.mesh.get_surface_count():
		for vertex in court.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			assert(is_equal_approx(vertex.y, 0.20))
	var railway := scene.get_node("ArtCastleFloatingWorld/StoryCrownRailway")
	var bridge := railway.get_node("StoryStations/Station_03_heart/KingdomAccessSkybridge")
	var paving: Material = bridge.get_node("CeremonialStep_L_00").material_override
	for name_value in ["FloatingAccessDeck", "CentralLumenRamp", "AccessEnergyConduit"]:
		assert(bridge.get_node(NodePath(name_value)).material_override == paving,
			"Heart approach must use one paving family instead of metal checkerboards")
	# Probe the real station/garden junction: it has a visible, solid floor.
	var point: Vector3 = railway.to_global(Vector3(1722.4, 0.20, 7838.7))
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3, point - Vector3.UP * 2)
	var hit := root.world_3d.direct_space_state.intersect_ray(query)
	assert(not hit.is_empty() and hit.position.y >= point.y - 0.03,
		"Arrival paving and route must not leave a hole at the junction")
	scene.queue_free()
	await process_frame
	print("HEART ARRIVAL GARDEN: PASS")
	quit()
