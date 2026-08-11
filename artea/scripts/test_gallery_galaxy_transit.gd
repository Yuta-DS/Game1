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
	var rail := gallery.get_node_or_null("SkyRail") as Node3D
	var isles := gallery.get_node_or_null("GalaxyIsles") as Node3D
	var rider := gallery.get_node_or_null("TrainRider") as Node3D
	if rail == null or isles == null or rider == null:
		var child_names: Array[String] = []
		for child in gallery.get_children():
			child_names.append(child.name)
		_fail("Art Castle galaxy transit layer is incomplete; children=%s" % [child_names])
		return
	if rail.get_node_or_null("GrandStation") == null:
		_fail("galaxy train court did not build")
		return
	for isle_id in ["mind", "heart", "creator"]:
		if isles.get_node_or_null("SkyIsle_%s" % isle_id) == null:
			_fail("galaxy world is missing %s island" % isle_id)
			return
	var stations: Dictionary = rider.get("_stations")
	if stations.size() != 6:
		_fail("expected six selectable galaxy train stations, got %d" % stations.size())
		return
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	if rider.get("_player") != player:
		_fail("galaxy train rider did not bind to gallery player")
		return
	print("GALAXY_TRANSIT_TEST: PASS — exterior clear; 3 islands and 6 rides live inside Art Castle")
	quit()
