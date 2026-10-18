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
	# The 9x9 forecourt is painted by the deck shader, centred on the deck (and
	# so on the Mind Bridge axis), with no tile nodes or collision seams.
	var forecourt := (district.get_node("WalkableDeck") as MeshInstance3D).material_override as ShaderMaterial
	assert(forecourt != null and int(forecourt.get_shader_parameter("grid_size")) == 9,
		"the Mind district uses a centered 9x9 checkerboard forecourt")
	assert(district.find_children("RuneTile_*", "", true, false).is_empty())
	assert(district.get_meta("rune_grid_size") == 9)
	assert(not bool(district.get_meta("requires_jump_from_mind_bridge")))
	var deck := district.get_node("WalkableDeck") as MeshInstance3D
	assert(is_equal_approx(deck.position.x, -600.0) and is_equal_approx(deck.position.z, 1640.0),
		"the checkerboard centre must lie exactly on the Mind Bridge axis")
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
