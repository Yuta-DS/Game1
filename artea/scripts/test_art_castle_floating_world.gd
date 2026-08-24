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

	for bridge in ["SouthArrivalBridge", "MindBridge", "HeartBridge", "CreatorBridge",
			"WestObservatoryBridge", "NorthObservatoryBridge", "EastObservatoryBridge",
			"SouthObservatoryBridge"]:
		var bridge_node := world.get_node_or_null(bridge) as Node3D
		if bridge_node == null or bridge_node.get_node_or_null("Walkway") == null:
			_fail("missing connected walkway %s" % bridge)
			return
	var tree_bridge := world.get_node_or_null("SouthArrivalBridge") as Node3D
	if tree_bridge.get_meta("visual_style", "") != \
			"castle_arcane_tree_of_life_processional" \
			or tree_bridge.get_meta("performance_profile", "") != "laptop_cpu_low":
		_fail("Tree of Life bridge is missing its Arcane laptop visual profile")
		return
	if not is_equal_approx(float(tree_bridge.get_meta("processional_length_m", 0.0)), 447.0) \
			or not is_equal_approx(float(tree_bridge.get_meta("processional_width_m", 0.0)), 62.0):
		_fail("Tree of Life processional bridge dimensions changed")
		return
	for component in ["TreeIvoryProcessionalDeck", "LivingSapInlay",
			"TreeBoughPortal_00", "TreeBoughPortal_01", "TreeBoughPortal_02"]:
		if tree_bridge.get_node_or_null(component) == null:
			_fail("Tree of Life bridge is missing %s" % component)
			return
	if tree_bridge.find_children("TreePylon_*", "MeshInstance3D", true, false).size() != 18 \
			or tree_bridge.find_children("BotanicalVineA_*", "MeshInstance3D", true, false).size() != 16:
		_fail("Tree of Life bridge modular rail rhythm is incomplete")
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
