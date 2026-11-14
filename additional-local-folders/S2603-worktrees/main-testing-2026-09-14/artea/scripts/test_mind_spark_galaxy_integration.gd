extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 8:
		await process_frame
	var floating_world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var district := floating_world.get_node("MindSparkDistrict") as Node3D
	var world := floating_world.get_node("MindSparkWorldOne") as MindSparkWorldOne
	assert(world.get_meta("foundation_mode") == "standalone_preview")
	assert(world.force_standalone_blueprint)
	assert(world.position == Vector3(-2200, 0, 1640))
	assert(world.get_node("WorldOneGeometry/MainStoryCircuitRoute") is Node3D)
	assert(world.find_children("WalkableZoneFloor", "MeshInstance3D", true, false).size() == 6)
	var rune_tiles := district.find_children("RuneTile_*", "MeshInstance3D", true, false)
	assert(rune_tiles.size() == 81,
		"the Mind district uses a centered 9x9 cyan-grid forecourt")
	assert(district.find_children("RuneTile_*Collision", "StaticBody3D", true, false).is_empty(),
		"rune inlays must not introduce collision seams over the continuous deck")
	assert(district.get_meta("rune_grid_size") == 9)
	assert(not bool(district.get_meta("requires_jump_from_mind_bridge")))
	var center_tile := district.get_node("RuneTile_04_04") as MeshInstance3D
	assert(is_equal_approx(center_tile.position.x, -600.0))
	assert(is_equal_approx(center_tile.position.z, 1640.0),
		"the central rune tile must lie exactly on the Mind Bridge axis")
	for row in 9:
		for column in 9:
			var tile := district.get_node("RuneTile_%02d_%02d" % [row, column]) as MeshInstance3D
			var mirror := district.get_node("RuneTile_%02d_%02d" % [8 - row, 8 - column]) as MeshInstance3D
			assert(is_equal_approx(tile.position.x + mirror.position.x, -1200.0))
			assert(is_equal_approx(tile.position.z + mirror.position.z, 3280.0),
				"every rune tile needs an exact point-reflected partner")
	var bridge_walkway := floating_world.get_node("MindBridge/Walkway") as MeshInstance3D
	var island_deck := district.get_node("WalkableDeck") as MeshInstance3D
	var bridge_top := bridge_walkway.position.y + (bridge_walkway.mesh as BoxMesh).size.y * 0.5
	var island_top := island_deck.position.y + (island_deck.mesh as CylinderMesh).height * 0.5
	assert(is_equal_approx(bridge_top, island_top) and is_equal_approx(island_top, 0.0),
		"Mind Bridge and island collision deck must share the exact y=0 datum")
	assert(floating_world.get_node("MindSparkWorldGate") is MindSparkWorldGate)
	assert(world.get_quest_objects().size() == 15)
	assert(world.get_node("WorldOneGeometry/05ThoughtStormArena/BossArenaCollisionCollision") is StaticBody3D)
	assert(world.get_node("WorldOneGeometry/06OldestTreeSanctuary/OldestTreeTrunkCollision") is StaticBody3D)
	var station_binding := world.get_node("WorldOneGeometry/OptionalCompletedWorldStationSpur")
	assert(station_binding.get_meta("branches_from_zone") == "05_thought_storm_arena")
	assert(not station_binding.visible and not bool(station_binding.get_meta("blocks_story_route")))
	var remote := floating_world.get_node_or_null("KingdomRegions3000m/MindKingdom3000m/MindSparkWorldOne")
	assert(remote == null, "no duplicate World One remains in the remote 3 km shelf map")
	print("MindSparkGalaxyIntegration: PASS — complete six-island World One is gate-mounted outside the district")
	quit()
