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
	var forecourt := district.get_node("MindSparkCeremonialForecourt") as Node3D
	assert(str(forecourt.get_meta("design_revision", "")) == "celestial_gate_garden_v4")
	assert(forecourt.get_meta("footprint_m") == Vector2(64.0, 54.0))
	assert(float(forecourt.get_meta("clear_processional_lane_m", 0.0)) >= 18.0)
	assert(bool(forecourt.get_meta("functional_gate_transform_preserved", false)))
	assert(district.find_children("RuneTile_*", "MeshInstance3D", true, false).is_empty())
	assert(district.find_children("*RuinWall*", "MeshInstance3D", true, false).is_empty())
	var processional := forecourt.get_node("IvoryProcessionalWalk") as Node3D
	assert(processional.find_children("FacetedPaver_*", "MeshInstance3D", true, false).size() == 7)
	assert(processional.find_children("CyanThreshold_*", "MeshInstance3D", true, false).size() == 6)
	var gatehouse := forecourt.get_node("CelestialGatehouse") as Node3D
	assert(float(gatehouse.get_meta("clear_opening_width_m", 0.0)) >= 28.0)
	assert(gatehouse.find_children("*TowerFoundationCollision", "StaticBody3D", true, false).size() == 2)
	assert(gatehouse.find_children("*TowerShaftCollision", "StaticBody3D", true, false).size() == 2)
	var portal_cradle := gatehouse.get_node("WorldGatePortalCradle") as Node3D
	assert(bool(portal_cradle.get_meta("functional_portal_remains_independent", false)))
	assert(bool(portal_cradle.get_meta("opening_collision_free", false)))
	assert(portal_cradle.find_children("*PortalButtress", "MeshInstance3D", true, false).size() == 2)
	assert(portal_cradle.get_node_or_null("PortalArchitecturalBezel") is MeshInstance3D)
	assert(portal_cradle.find_children("PortalBezelClamp_*", "MeshInstance3D", true, false).size() == 3)
	var terraces := forecourt.get_node("SideTerraceGardens") as Node3D
	assert(terraces.find_children("*GardenTerraceCollision", "StaticBody3D", true, false).size() == 2)
	assert(terraces.find_children("SolidWarmTrunkCollision", "StaticBody3D", true, false).size() == 6)
	var plinths := forecourt.get_node("ConstellationPlinths") as Node3D
	assert(plinths.find_children("ConstellationPlinth_*", "MeshInstance3D", true, false).size() == 3)
	assert(plinths.find_children("ConstellationPlinth_*Collision", "StaticBody3D", true, false).size() == 3)
	var rear_garden := forecourt.get_node("RearConstellationGarden") as Node3D
	assert(float(rear_garden.get_meta("central_axis_clear_width_m", 0.0)) >= 14.0)
	var lighting := forecourt.get_node("CeremonialLightingRig") as Node3D
	assert(lighting.find_children("*WarmKey", "OmniLight3D", true, false).size() == 2)
	assert(lighting.get_node_or_null("ProcessionalCoolFill") is OmniLight3D)
	assert(not bool(district.get_meta("requires_jump_from_mind_bridge")))
	var bridge_walkway := floating_world.get_node("MindBridge/Walkway") as MeshInstance3D
	var island_deck := district.get_node("WalkableDeck") as MeshInstance3D
	var bridge_top := bridge_walkway.position.y + (bridge_walkway.mesh as BoxMesh).size.y * 0.5
	var island_top := island_deck.position.y + (island_deck.mesh as CylinderMesh).height * 0.5
	assert(is_equal_approx(bridge_top, island_top) and is_equal_approx(island_top, 0.0),
		"Mind Bridge and island collision deck must share the exact y=0 datum")
	var mind_gate := floating_world.get_node("MindSparkWorldGate") as MindSparkWorldGate
	assert(mind_gate != null)
	assert(is_equal_approx(float(mind_gate.get_meta("ceremonial_visual_scale", 0.0)), 1.18))
	assert(world.get_quest_objects().size() == 15)
	assert(world.get_node("WorldOneGeometry/05ThoughtStormArena/BossArenaCollisionCollision") is StaticBody3D)
	assert(world.get_node("WorldOneGeometry/06OldestTreeSanctuary/OldestTreeTrunkCollision") is StaticBody3D)
	var station_binding := world.get_node("WorldOneGeometry/OptionalCompletedWorldStationSpur")
	assert(station_binding.get_meta("branches_from_zone") == "05_thought_storm_arena")
	assert(not station_binding.visible and not bool(station_binding.get_meta("blocks_story_route")))
	var remote := floating_world.get_node_or_null("KingdomRegions3000m/MindKingdom3000m/MindSparkWorldOne")
	assert(remote == null, "no duplicate World One remains in the remote 3 km shelf map")
	print("MindSparkGalaxyIntegration: PASS — complete three-island/six-district World One is gate-mounted outside the district")
	gallery.queue_free()
	await process_frame
	await process_frame
	quit()
