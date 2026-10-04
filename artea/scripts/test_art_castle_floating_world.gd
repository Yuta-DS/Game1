extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("ART_CASTLE_FLOATING_WORLD_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var path := "res://scenes/art_castle_floating_world.tscn"
	if not ResourceLoader.exists(path):
		_fail("playable scene is missing")
		return
	var packed := load(path) as PackedScene
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	await process_frame

	if world.call("get_exploration_size") != Vector2(2000.0, 2000.0):
		_fail("world is not exactly 2000m x 2000m")
		return
	for district in ["CentralSanctuary", "ArrivalIsland", "MindSparkDistrict",
			"HeartMelodyTemple", "CreatorsLightStudio", "WestObservatory",
			"NorthObservatory", "EastObservatory", "SouthObservatory"]:
		if world.get_node_or_null(district) == null:
			_fail("missing explorable district %s" % district)
			return
	for observatory_name in ["WestObservatory", "NorthObservatory",
			"EastObservatory", "SouthObservatory"]:
		var observatory := world.get_node(observatory_name) as Node3D
		var tower_shell := observatory.get_node_or_null("ObservatoryTower") as MeshInstance3D
		if str(observatory.get_meta("architecture_revision", "")) != "faceted_observatory_v3" \
				or not bool(observatory.get_meta("placeholder_rectangle_removed", false)) \
				or tower_shell == null or tower_shell.visible or tower_shell.mesh != null \
				or observatory.get_node_or_null("ObservatoryTowerCollision") == null \
				or observatory.find_children("Observatory*FacetedBody", "MeshInstance3D", true, false).size() != 2 \
				or observatory.find_children("ObservatoryWindowFrame*", "MeshInstance3D", true, false).size() != 4 \
				or observatory.find_children("ObservatorySignalString_*", "MeshInstance3D", true, false).size() != 5 \
				or observatory.find_children("*ObservatoryButtress_*", "MeshInstance3D", true, false).size() != 4:
			_fail("%s still uses the gray rectangular tower prototype" % observatory_name)
			return
	var north_observatory := world.get_node("NorthObservatory") as Node3D
	if not bool(north_observatory.get_meta("clear_of_primary_gate_sightline", false)) \
			or absf(north_observatory.get_node("WalkableDeck").position.x) < 200.0:
		_fail("north observatory still blocks the Heart gate sightline")
		return
	var heart := world.get_node("HeartMelodyTemple") as Node3D
	if str(heart.get_meta("design_revision", "")) != "celestial_conservatory_v14" \
			or not bool(heart.get_meta("flat_rectangle_facade_removed", false)):
		_fail("Heart Melody still uses its placeholder rectangular facade")
		return
	var conservatory := heart.get_node_or_null(
		"HeartMelodyCelestialConservatory") as Node3D
	if conservatory == null \
			or float(conservatory.get_meta("central_opening_width_m", 0.0)) < 48.0 \
			or not bool(conservatory.get_meta("authored_processional_forecourt", false)) \
			or not bool(conservatory.get_meta("layered_hall_side_facades", false)) \
			or int(conservatory.get_meta("distinct_silhouette_count", 0)) != 6:
		_fail("Heart Melody conservatory or its clear entrance is missing")
		return
	var bays := conservatory.get_node_or_null("SixResonanceBays") as Node3D
	if bays == null or not bool(bays.get_meta("complete_360_architecture", false)) \
			or bays.find_children("InstrumentHall_*", "Node3D", true, false).size() != 6 \
			or bays.find_children("RearCyanWindow", "MeshInstance3D", true, false).size() != 6 \
			or bays.find_children("*SideFacadeFrame", "MeshInstance3D", true, false).size() != 12 \
			or bays.find_children("*SideFacadeRecess", "MeshInstance3D", true, false).size() != 12 \
			or bays.find_children("*SidePilaster_*", "MeshInstance3D", true, false).size() != 36 \
			or bays.find_children("*MemoryRegister_*", "MeshInstance3D", true, false).size() != 10 \
			or bays.find_children("HallCollisionCollision", "StaticBody3D", true, false).size() != 6:
		_fail("Heart Melody conservatory does not have six complete 360-degree instrument halls")
		return
	var hall_types: Dictionary = {}
	for hall in bays.find_children("InstrumentHall_*", "Node3D", true, false):
		hall_types[str(hall.get_meta("instrument_type", ""))] = true
	if hall_types.size() != 6:
		_fail("the instrument halls do not have six distinct musical identities")
		return
	if conservatory.find_children("*OrchardTree_*", "Node3D", true, false).size() != 10 \
			or conservatory.find_children("*TowerCollisionCollision", "StaticBody3D", true, false).size() != 2:
		_fail("Heart Melody conservatory landscaping or collision is incomplete")
		return
	if conservatory.find_children("Instrument_*", "Node3D", true, false).size() != 6:
		_fail("Heart Melody musical storytelling remains incomplete")
		return
	if conservatory.find_children("TerraceButtress_*", "MeshInstance3D", true, false).size() != 9 \
			or not bool(conservatory.get_meta("finished_platform_edges", false)):
		_fail("Heart Melody terrace edges and underside remain unfinished")
		return
	var entrance := conservatory.get_node_or_null("GrandResonanceEntrance") as Node3D
	var gardens := conservatory.get_node_or_null("ResonanceOrchardGardens") as Node3D
	if entrance == null or float(entrance.get_meta("principal_route_width_m", 0.0)) < 18.0 \
			or str(entrance.get_meta("design_revision", "")) != "grand_resonance_gate_v4" \
			or not bool(entrance.get_meta("barrier_like_gate_removed", false)) \
			or not bool(entrance.get_meta("finished_bridge_landing", false)) \
			or not bool(entrance.get_meta("musical_focal_monument", false)) \
			or not bool(entrance.get_meta("sculpted_bridge_transition", false)) \
			or not bool(entrance.get_meta("asymmetric_landing_gardens", false)) \
			or not bool(entrance.get_meta("suspended_gate_harp_removed", false)) \
			or int(entrance.get_meta("portal_arch_ring_count", 0)) != 2 \
			or int(entrance.get_meta("vaulted_glass_canopy_panels", 0)) != 4 \
			or int(entrance.get_meta("framed_tower_window_count", 0)) != 4 \
			or entrance.get_node_or_null("WalkablePerformanceStage") == null \
			or entrance.get_node_or_null("ResonanceBridgeLanding") == null \
			or entrance.find_children("FrontOuterArch_*", "MeshInstance3D", true, false).size() != 10 \
			or entrance.find_children("RearOuterArch_*", "MeshInstance3D", true, false).size() != 10 \
			or entrance.find_children("*FacadeRecess", "MeshInstance3D", true, false).size() != 2 \
			or entrance.find_children("*FrontPilaster_*", "MeshInstance3D", true, false).size() != 4 \
			or entrance.find_children("*VaultCanopy", "MeshInstance3D", true, false).size() != 4 \
			or entrance.find_children("*WindowFrameSide_*", "MeshInstance3D", true, false).size() != 8 \
			or entrance.find_children("*FacadeNote_*", "MeshInstance3D", true, false).size() != 12 \
			or entrance.find_children("BridgeTransitionTerrace_*", "MeshInstance3D", true, false).size() != 3 \
			or entrance.find_children("*TransitionWing_*", "MeshInstance3D", true, false).size() != 6 \
			or entrance.find_children("*ProcessionalButtress_*", "MeshInstance3D", true, false).size() != 6 \
			or entrance.find_children("*MusicLedge_*", "MeshInstance3D", true, false).size() != 8 \
			or entrance.find_children("InnerVaultRib*", "MeshInstance3D", true, false).size() != 10 \
			or entrance.find_children("HarmonyRay_*", "MeshInstance3D", true, false).size() != 7 \
			or entrance.find_children("LyreLightString_*", "MeshInstance3D", true, false).size() != 5 \
			or entrance.find_children("LandingHarmonyKey_*", "MeshInstance3D", true, false).size() != 0 \
			or entrance.get_node_or_null("GrandHarmonyLyreEmblem") == null \
			or entrance.get_node_or_null("WestLandingListeningTree") == null \
			or entrance.get_node_or_null("EastLandingTuningSculpture") == null \
			or entrance.get_node_or_null("LeftPediment") != null \
			or entrance.get_node_or_null("RightPediment") != null \
			or entrance.get_node_or_null("SuspendedHarmonyResonator") != null \
			or entrance.find_children("HarpFrame*", "MeshInstance3D", true, false).size() != 0 \
			or entrance.find_children("HarmonyString_*", "MeshInstance3D", true, false).size() != 0:
		_fail("the central music pavilion remains a prototype")
		return
	if conservatory.find_children("CourageFrontGable*", "MeshInstance3D", true, false).size() != 0 \
			or conservatory.find_children("MemoryRoofHarp*", "MeshInstance3D", true, false).size() != 0 \
			or conservatory.find_children("MemoryRoofRib*", "MeshInstance3D", true, false).size() != 0:
		_fail("removed open roof frames were rebuilt")
		return
	if gardens == null or not bool(gardens.get_meta("grounded_landscaping", false)) \
			or gardens.find_children("*CurvedGardenPath_*", "MeshInstance3D", true, false).size() != 12 \
			or gardens.find_children("*WaterSpillway*", "MeshInstance3D", true, false).size() != 0 \
			or gardens.find_children("*PoolShadow", "MeshInstance3D", true, false).size() != 0 \
			or gardens.find_children("*PoolRimStone_*", "MeshInstance3D", true, false).size() != 32 \
			or gardens.find_children("*PoolSanctum", "MeshInstance3D", true, false).size() != 2 \
			or gardens.find_children("*GardenWall_*", "MeshInstance3D", true, false).size() != 0 \
			or gardens.find_children("*ListeningSeat", "MeshInstance3D", true, false).size() != 2:
		_fail("the conservatory gardens are not fully connected and grounded")
		return
	if heart.find_children("MelodyPad_*", "MeshInstance3D", true, false).size() != 0 \
			or heart.find_children("HeartIslandRockMantle", "MeshInstance3D", true, false).size() != 1 \
			or heart.find_children("LivingEdgeLookout_*", "MeshInstance3D", true, false).size() != 10 \
			or heart.find_children("FoundationCrystal_*", "MeshInstance3D", false, false).filter(
				func(node: MeshInstance3D): return node.visible).size() != 0:
		_fail("prototype pads or unfinished conservatory-facing island edges remain")
		return
	var song := world.get_node_or_null(
		"HeartMelodyQuestLandmarks/PersonalSongAmphitheatre") as Node3D
	if song == null or not bool(song.get_meta("gold_ring_removed", false)) \
			or song.get_node_or_null("HarmonyJewelRing") != null \
			or song.get_node_or_null("HarmonyPulse") != null \
			or world.find_children("EmotionResonanceRing", "MeshInstance3D", true, false).size() != 0 \
			or song.find_children("PersonalSongString_*", "MeshInstance3D", true, false).size() != 5 \
			or song.find_children("ListeningSeat_*", "MeshInstance3D", true, false).size() != 12:
		_fail("Heart Melody still contains the oversized gold ring or an unfinished amphitheatre")
		return

	for bridge in ["SouthArrivalBridge", "MindBridge", "HeartBridge", "CreatorBridge",
			"WestObservatoryBridge", "NorthObservatoryBridge", "EastObservatoryBridge",
			"SouthObservatoryBridge"]:
		var bridge_node := world.get_node_or_null(bridge) as Node3D
		if bridge_node == null or bridge_node.get_node_or_null("Walkway") == null:
			_fail("missing connected walkway %s" % bridge)
			return
	var tree_bridge := world.get_node_or_null("SouthArrivalBridge") as Node3D
	var heart_bridge := world.get_node_or_null("HeartBridge") as Node3D
	if not bool(heart_bridge.get_meta("continuous_finish_deck", false)) \
			or int(heart_bridge.get_meta("smooth_landing_count", -1)) != 0 \
			or int(heart_bridge.get_meta("finished_fascia_count", 0)) != 2 \
			or int(heart_bridge.get_meta("arrival_pylon_count", 0)) != 4 \
			or int(heart_bridge.get_meta("parapet_panel_count", 0)) != 22 \
			or heart_bridge.get_node_or_null("HeartBridgeFinishDeck") == null \
			or heart_bridge.find_children("HeartBridgeLanding_*", "MeshInstance3D", true, false).size() != 0 \
			or int(heart_bridge.get_meta("heart_arch_support_count", -1)) != 0 \
			or heart_bridge.find_children("HeartBridgeArchSupport_*", "Node3D", true, false).size() != 0 \
			or heart_bridge.find_children("HeartBridgeParapetPanel_*", "MeshInstance3D", true, false).size() != 22:
		_fail("Heart Melody bridge still has a fragmented prototype surface")
		return
	if tree_bridge.get_meta("visual_style", "") != \
			"castle_arcane_tree_of_life_processional" \
			or tree_bridge.get_meta("performance_profile", "") != "laptop_cpu_low":
		_fail("Tree of Life bridge is missing its Arcane laptop visual profile")
		return
	if not is_equal_approx(float(tree_bridge.get_meta("processional_length_m", 0.0)), 447.0) \
			or not is_equal_approx(float(tree_bridge.get_meta("processional_width_m", 0.0)), 62.0):
		_fail("Tree of Life processional bridge dimensions changed")
		return
	var blender_bridge := tree_bridge.get_node_or_null(
		"ReferenceTreeProcessionalBridge/BlenderTreeProcessionalBridge") as Node3D
	if blender_bridge == null:
		_fail("Tree of Life bridge is missing its Blender-authored visual")
		return
	for component in ["DeckIvory", "CyanLight", "RailGold", "PortalIvory", "PortalGold"]:
		if blender_bridge.find_child(component, true, false) == null:
			_fail("Tree of Life Blender bridge is missing %s" % component)
			return
	if int(tree_bridge.get_meta("blender_editable_module_count", 0)) != 689 \
			or int(tree_bridge.get_meta("blender_runtime_mesh_group_count", 0)) != 9 \
			or int(tree_bridge.get_meta("bridge_runtime_triangle_count", 0)) != 26116:
		_fail("Tree of Life Blender bridge optimization metadata changed")
		return
	for rail in tree_bridge.find_children("SafetyRail*", "MeshInstance3D", true, false):
		if (rail as MeshInstance3D).visible:
			_fail("Tree of Life safety blockout is obscuring its botanical railing")
			return

	var player := world.get_node_or_null("Player3D") as CharacterBody3D
	if player == null or player.position.distance_to(world.call("get_player_spawn")) > 0.1:
		_fail("player does not spawn on the arrival island")
		return
	if player.get_node_or_null("FoxVisuals/Fox") == null:
		_fail("player has no visible fox character")
		return
	if world.get_node_or_null("ReturnToCastleGate") == null:
		_fail("world has no return route to the Art Gallery")
		return
	var minimap := world.get_node_or_null("WorldMapCanvas/ArteaWorldMinimap") as Control
	if minimap == null or not minimap.visible or minimap.call("get_map_context") != "galaxy":
		_fail("standalone Castle Galaxy scene has no visible galaxy minimap")
		return
	if world.call("get_return_scene_path") != "res://scenes/art_gallery_3d_inprogress.tscn":
		_fail("floating world does not return to the Art Gallery")
		return
	if world.find_children("*", "StaticBody3D", true, false).size() < 90:
		_fail("world does not contain enough collision-backed architecture")
		return
	if world.find_children("SkyTower_*", "Node3D", true, false).size() < 12:
		_fail("floating skyline is incomplete")
		return

	print("ART_CASTLE_FLOATING_WORLD_TEST: PASS — world, player, live minimap, and return gate")
	quit()
