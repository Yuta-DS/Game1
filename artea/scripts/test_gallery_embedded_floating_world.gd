extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("GALLERY_EMBEDDED_WORLD_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 3:
		await process_frame

	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	var world := gallery.get_node_or_null("ArtCastleFloatingWorld") as Node3D
	if player == null or world == null:
		_fail("gallery and floating world do not share one scene root")
		return
	if world.get_parent() != gallery or not bool(world.call("is_embedded_in_gallery")):
		_fail("floating island still behaves as a separate scene")
		return
	if world.get("_player") != player:
		_fail("embedded island does not reuse the gallery player")
		return
	if world.call("get_exploration_size") != Vector2(2000.0, 2000.0):
		_fail("embedded exploration area is not 2 km x 2 km")
		return
	if world.call("get_kingdom_exploration_size") != Vector2(3000.0, 3000.0):
		_fail("each new kingdom is not 3000m x 3000m")
		return
	var regions := world.get_node_or_null("KingdomRegions3000m") as Node3D
	var story := world.get_node_or_null("ConnectedKingdomStory") as Node3D
	var railway := world.get_node_or_null("StoryCrownRailway") as Node3D
	if regions == null or story == null or railway == null:
		_fail("3 km kingdoms, connected story, and Crown Line do not coexist in the gallery")
		return
	# Heart and Creator are station platforms; Mind lives in World One.
	if regions.get_node_or_null("MindKingdom3000m") != null:
		_fail("the removed Mind 3 km region is back")
		return
	for kingdom_id in ["heart", "creator"]:
		if regions.call("get_kingdom_size", kingdom_id) != Vector2(930, 930):
			_fail("%s region has the wrong exploration size" % kingdom_id)
			return
	if not bool(story.call("story_is_connected")):
		_fail("large kingdom stories are not connected")
		return

	var arrival_deck := world.get_node_or_null("ArrivalIsland/WalkableDeck") as MeshInstance3D
	if arrival_deck == null:
		_fail("floating world's arrival island is missing")
		return
	var island_nearest_edge_z := arrival_deck.global_position.z - 155.0
	if absf(island_nearest_edge_z - 185.0) > 0.1:
		_fail("arrival island edge is not exactly 175m beyond the wall: z=%.2f" % island_nearest_edge_z)
		return
	if arrival_deck.global_position.z <= 10.0:
		_fail("floating journey still begins behind the Art Castle wall at z=10")
		return
	var crown_endpoints: PackedVector3Array = railway.call("get_route_endpoints")
	var gallery_station_global: Vector3 = world.to_global(crown_endpoints[0])
	if gallery_station_global.z <= 10.0:
		_fail("Crown Line station still sits behind the Art Castle wall")
		return
	var approach_bridge := world.get_node_or_null("CastleToGalaxyBridge175m") as Node3D
	if approach_bridge == null or approach_bridge.get_node_or_null("ContinuousWalkway") == null \
			or approach_bridge.get_node_or_null("SafetyRailLeft") == null \
			or approach_bridge.get_node_or_null("SafetyRailRight") == null:
		_fail("175m Art Castle approach bridge is missing walkway or safety rails")
	var front_gate := approach_bridge.get_node_or_null("ReferenceFrontGate") as Node3D
	var blender_asset := front_gate.get_node_or_null("BlenderCastleGalaxyBridgeGate") \
			if front_gate != null else null
	if front_gate == null or blender_asset == null \
			or String(front_gate.get_meta("source_blend", "")).get_extension() != "blend" \
			or int(approach_bridge.get_meta("blender_editable_module_count", 0)) < 1200 \
			or String(approach_bridge.get_meta("bridge_performance_profile", "")) \
					!= "laptop_cpu_low" \
			or int(approach_bridge.get_meta("bridge_runtime_triangle_count", 999999)) >= 130000 \
			or int(approach_bridge.get_meta("blender_runtime_mesh_group_count", 0)) > 16:
		_fail("bridge is not using the laptop-optimized Blender modular asset")
		return
	if float(front_gate.get_meta("clear_opening_width_m", 0.0)) < 13.6 \
			or float(front_gate.get_meta("gate_outer_width_m", 0.0)) < 40.0 \
			or float(front_gate.get_meta("gate_finial_height_m", 0.0)) < 50.0 \
			or float(front_gate.get_meta("rear_wall_setback_m", 0.0)) < 150.0 \
			or not front_gate.find_children("*", "StaticBody3D", true, false).is_empty():
		_fail("enlarged front gate scale, setback, or clear bridge route is incorrect")
		return
	if approach_bridge.get_meta("visual_progression", "") \
			!= "reference_masonry_gate_to_galaxy_light":
		_fail("bridge does not use the supplied masonry-and-gate reference language")
		return
	var walkway := approach_bridge.get_node("ContinuousWalkway") as MeshInstance3D
	var walkway_mesh := walkway.mesh as BoxMesh
	if absf(walkway.global_position.x) > 0.01 or absf(walkway_mesh.size.x - 16.0) > 0.01:
		_fail("wider world walkway is not centred on the red-carpet exit")
		return
	if absf(float(approach_bridge.get_meta("walkway_start_global_z")) - float(
			approach_bridge.get_meta("castle_carpet_end_global_z"))) > 0.01:
		_fail("world walkway does not meet the red carpet at one exact non-overlapping boundary")
		return
	if gallery.get_node_or_null("FloatingCrownSanctuary") != null:
		_fail("legacy diagonal sanctuary bridge still overlaps the castle entrance")
		return
	var minimap := gallery.get_node_or_null("WorldMapCanvas/ArteaWorldMinimap") as Control
	if minimap == null:
		_fail("player minimap was not added to the gallery HUD")
		return
	if minimap.position.x > 30.0 or minimap.position.y > 30.0 or not minimap.visible:
		_fail("player minimap is not visibly anchored at the top-left")
		return
	for hud_path in ["CrownLineHUD", "ConnectedStoryHUD"]:
		var hud := railway.get_node_or_null(hud_path) if hud_path == "CrownLineHUD" \
			else story.get_node_or_null(hud_path)
		if hud == null:
			_fail("%s compatibility state is missing" % hud_path)
			return
		if hud_path == "CrownLineHUD":
			var train_controls := hud.get_node_or_null("TrainControls") as Control
			if train_controls == null or train_controls.anchor_left != 1.0:
				_fail("train instructions must be anchored on the right")
				return
		for control in hud.find_children("*", "Control", true, false):
			if (control as Control).is_visible_in_tree():
				_fail("%s draws a panel before the player reaches the train" % hud_path)
				return
	var ceremony := gallery.get_node_or_null("Ceremony")
	if ceremony != null and ceremony.find_children("*", "PanelContainer", true, false).size() > 0:
		_fail("automatic Milo ceremony banner still covers the gameplay screen")
		return
	if gallery.get_node_or_null("FloatingCrownSanctuary/WorldPortalBridge") != null \
			or gallery.get_node_or_null("FloatingCrownSanctuary/FloatingWorldPortal") != null:
		_fail("removed galaxy bridge or teleport door still exists")
		return
	if world.get_node_or_null("ReturnToCastleGate") != null:
		_fail("same-scene world still contains a return teleport")
		return
	for district in ["CentralSanctuary", "MindSparkDistrict", "CreatorsLightStudio"]:
		if world.get_node_or_null(district) == null:
			_fail("embedded world is missing %s" % district)
			return

	print("GALLERY_EMBEDDED_WORLD_TEST: PASS — centred non-overlapping carpet exit and 175m world bridge")
	quit()
