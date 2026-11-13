# Checks the front entrance and the vegetation inside the REAL hub scene.
#
# Split out from test_castle_universe.gd on purpose: that test goes on to load
# the Art Castle gallery scene, which is heavy enough to dominate the run. This
# stops after the hub so the entrance, the arrival point and the foliage have a
# feedback loop that finishes.
extends SceneTree


func _fail(message: String) -> void:
	push_error("HUB_ENTRANCE_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for _i in 30:
		await process_frame

	# 1. The front door is real architecture, not an invisible trigger.
	var entrance := hub.get_node_or_null("CastleEntrance") as Node3D
	if entrance == null:
		_fail("CastleEntrance node is not in the hub scene")
		return
	var rig := entrance.get_node_or_null("CastleEntrance") as Node3D
	if rig == null:
		_fail("entrance did not build inside the hub")
		return
	var meshes := rig.find_children("*", "MeshInstance3D", true, false)
	var bodies := rig.find_children("*", "StaticBody3D", true, false)
	if meshes.size() < 30 or bodies.is_empty():
		_fail("entrance is bare in-scene: %d meshes, %d bodies"
			% [meshes.size(), bodies.size()])
		return

	# 2. The arrival point is out on the plaza at door height, so leaving the
	#    gallery puts the player on the doorstep rather than across the map.
	#
	#    Measured door (probe_castle_door.gd): (-39.8, 69.33, 27.41) facing +X,
	#    so the plaza runs further positive in x.
	var spawn: Vector3 = entrance.call("get_spawn_position")
	if spawn.x <= -39.8 or absf(spawn.y - 69.33) > 4.0:
		_fail("arrival point is not on the front-door plaza: %s" % spawn)
		return

	# 3. The plaza must sit clear of the castle's floating foundation
	#    (16.5 m radius) rather than inside the rock.
	if Vector2(spawn.x, spawn.z).distance_to(Vector2(-51.4, 27.41)) < 16.5:
		_fail("arrival point sits inside the castle foundation: %s" % spawn)
		return

	# 4. Vegetation actually renders. Both scatter roots shipped visible=false,
	#    and Grass had no items at all, which is why the world looked bare.
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

	print("HUB_ENTRANCE_TEST: PASS — entrance %d meshes / %d bodies, arrival %s, %d grass items"
		% [meshes.size(), bodies.size(), spawn, grass_items.size()])
	quit()


func _init() -> void:
	call_deferred("_run")
