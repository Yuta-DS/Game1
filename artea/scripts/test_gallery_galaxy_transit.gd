extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("GALAXY_TRANSIT_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var hub_scene := load("res://scenes/New_Hub_World.tscn") as PackedScene
	var hub := hub_scene.instantiate()
	root.add_child(hub)
	for _i in 30:
		await process_frame
	if hub.get_node_or_null("SkyRail") != null or hub.get_node_or_null("SkyIsles") != null:
		_fail("train or islands still exist outside the Art Castle")
		return
	var stair := hub.get_node_or_null("CastleStairs/CastleStair") as Node3D
	if stair == null:
		_fail("exterior castle stair failed to build")
		return
	var treads := stair.find_children("StairTread_*", "MeshInstance3D", true, false)
	for tread in treads:
		var horizontal := Vector2(tread.global_position.x, tread.global_position.z)
		if horizontal.distance_to(Vector2(-51.4, 27.41)) < 18.0:
			_fail("stair still overlaps the castle foundation at %s" % tread.global_position)
			return
	# The front door must be real architecture with a real arrival point, or
	# leaving the gallery drops the player back at the hub's default start
	# position on the far side of the map.
	var entrance := hub.get_node_or_null("CastleEntrance") as Node3D
	if entrance == null or entrance.get_node_or_null("CastleEntrance") == null:
		_fail("castle front entrance failed to build")
		return
	if not entrance.has_method("get_spawn_position"):
		_fail("castle entrance exposes no arrival point")
		return
	var spawn: Vector3 = entrance.call("get_spawn_position")
	# The plaza is built outward along +X from the door, so the spawn has to sit
	# beyond the door face and at door height — not on the ground far below.
	# Measured doorway threshold is y=69.33; the player origin is intentionally
	# capsule-height above the upper court, so allow that clearance rather than
	# comparing against the obsolete pre-courtyard castle base (65.8).
	if spawn.x <= -39.8 or absf(spawn.y - 69.33) > 4.0:
		_fail("castle arrival point is not on the front-door plaza: %s" % spawn)
		return

	# The hub's vegetation must actually render. Both scatter roots were
	# authored with visible = false, which is why the world looked bare.
	for veg_path in ["Environment/Grass", "Environment/Objects"]:
		var veg := hub.get_node_or_null(veg_path) as Node3D
		if veg == null:
			_fail("missing vegetation node %s" % veg_path)
			return
		if not veg.visible:
			_fail("%s is hidden, so no foliage renders" % veg_path)
			return
	var grass_items := (hub.get_node("Environment/Grass") as Node3D) \
		.find_children("ScatterItem*", "Node3D", false, false)
	if grass_items.is_empty():
		_fail("grass scatter has no items to place")
		return

	hub.queue_free()
	await process_frame

	var gallery_scene := load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene
	var gallery := gallery_scene.instantiate()
	root.add_child(gallery)
	for _i in 40:
		await process_frame
	var floating_world := gallery.get_node_or_null("ArtCastleFloatingWorld") as Node3D
	var crown_line := floating_world.get_node_or_null("StoryCrownRailway") as Node3D if floating_world != null else null
	if crown_line == null or floating_world == null:
		var child_names: Array[String] = []
		for child in gallery.get_children():
			child_names.append(child.name)
		_fail("Art Castle galaxy transit layer is incomplete; children=%s" % [child_names])
		return
	if gallery.get_node_or_null("FloatingCrownSanctuary") != null:
		_fail("legacy sanctuary bridge still overlaps the gallery entrance")
		return
	if not bool(floating_world.call("is_embedded_in_gallery")) \
			or floating_world.call("get_exploration_size") != Vector2(2000.0, 2000.0):
		_fail("2 km floating island is not embedded in the gallery scene")
		return
	if floating_world.position != Vector3(0.0, 0.0, -480.0):
		_fail("floating world is not shifted to the player-facing side of the gallery wall")
		return
	for district in ["CentralSanctuary", "ArrivalIsland", "MindSparkDistrict",
			"HeartMelodyTemple", "CreatorsLightStudio"]:
		if floating_world.get_node_or_null(district) == null:
			_fail("same-scene floating world is missing %s" % district)
			return
	if floating_world.get_node_or_null("ReturnToCastleGate") != null:
		_fail("embedded world still contains a return teleport")
		return
	if gallery.get_node_or_null("SkyRail") != null or gallery.get_node_or_null("GalaxyIsles") != null \
			or gallery.get_node_or_null("TrainRider") != null:
		_fail("obsolete radial galaxy transit still exists beside the story Crown Line")
		return
	if int(crown_line.call("get_station_count")) != 4 or int(crown_line.call("get_segment_count")) != 3:
		_fail("story Crown Line must have four stations joined by three segments")
		return
	var endpoints: PackedVector3Array = crown_line.call("get_route_endpoints")
	if endpoints[0].distance_to(endpoints[1]) < 500.0:
		_fail("story railway incorrectly closes into a circle")
		return
	var flags := {"star_of_wisdom": false, "harmony_jewel": false, "creators_light": false}
	if not bool(crown_line.call("station_unlocked_with", 1, flags)) \
			or bool(crown_line.call("station_unlocked_with", 2, flags)):
		_fail("Crown Line story-order locks are incorrect at journey start")
		return
	flags.star_of_wisdom = true
	if not bool(crown_line.call("station_unlocked_with", 2, flags)) \
			or bool(crown_line.call("station_unlocked_with", 3, flags)):
		_fail("Star of Wisdom must open Heart Melody only")
		return
	flags.harmony_jewel = true
	if not bool(crown_line.call("station_unlocked_with", 3, flags)):
		_fail("Harmony Jewel must open Creator's Light")
		return
	for landmarks in ["MindSparkQuestLandmarks", "HeartMelodyQuestLandmarks", "CreatorsLightQuestLandmarks"]:
		if floating_world.get_node_or_null(landmarks) == null:
			_fail("story world is missing %s" % landmarks)
			return
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	if crown_line.get("_player") != player:
		_fail("Rainbow Galaxy Train did not bind to the gallery player")
		return
	print("GALAXY_TRANSIT_TEST: PASS — story Crown Line connects four ordered worlds in one 2 km scene")
	quit()
