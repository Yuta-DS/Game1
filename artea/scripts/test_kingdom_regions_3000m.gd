extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("KINGDOM_REGIONS_3000M_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var regions := Node3D.new()
	regions.name = "KingdomRegions3000m"
	regions.set_script(load("res://scripts/art_castle_kingdom_regions.gd"))
	world.add_child(regions)
	await process_frame
	# Heart and Creator are one fountain-island-sized platform each, holding the
	# station's access-bridge landing.
	for kingdom_id in ["heart", "creator"]:
		var platform := regions.get_node_or_null("%sKingdomPlatform" % kingdom_id.to_pascal_case()) as Node3D
		if platform == null or platform.get_node_or_null("WalkableDeck") == null:
			_fail("missing %s station platform" % kingdom_id)
			return
		if regions.get_node_or_null("%sKingdom3000m" % kingdom_id.to_pascal_case()) != null:
			_fail("%s still builds the 3 km grey kingdom" % kingdom_id)
			return
		var landing: Vector3 = (regions.call("get_story_route", kingdom_id) as Array)[0].position
		var deck := platform.get_node("WalkableDeck") as Node3D
		if Vector2(landing.x, landing.z).distance_to(Vector2(deck.position.x, deck.position.z)) \
				> regions.call("get_kingdom_size", kingdom_id).x * 0.5 - 5.0:
			_fail("%s access-bridge landing is not on its platform" % kingdom_id)
			return
	# Mind's old unreachable 3 km region was removed; Mind Spark is World One.
	if regions.get_node_or_null("MindKingdom3000m") != null:
		_fail("the removed Mind 3 km region is back")
		return
	if (regions.call("get_story_route", "mind") as Array).size() != 0:
		_fail("Mind still has story checkpoints in the removed region")
		return
	# A fall near World One must recover onto the Mind district island (centre
	# (-600, 1640), radius 175; the Mind station stair lands on its rim), not
	# into the void where the region stood.
	var respawn: Vector3 = regions.call("get_safe_respawn", Vector3(-3000, -130, 1260))
	if Vector2(respawn.x, respawn.z).distance_to(Vector2(-600, 1640)) > 175.0:
		_fail("a fall near World One recovers off the Mind district: %s" % respawn)
		return
	var centers: Dictionary = regions.call("get_kingdom_centers")
	if centers.has("mind") or centers.heart.distance_to(centers.creator) < 3000:
		_fail("kingdom footprints overlap or the removed Mind region is still reported")
		return
	# The gallery connection is at z=820; all large kingdom centres must now be
	# on its opposite-facing side (+Z), with the furthest world clearly beyond it.
	for kingdom_id in ["heart", "creator"]:
		if float(centers[kingdom_id].z) <= 820.0:
			_fail("%s was not mirrored to the gallery-facing side" % kingdom_id)
			return
		var nearest_edge_z: float = float(centers[kingdom_id].z) - regions.call("get_kingdom_size", kingdom_id).y * 0.5
		if nearest_edge_z - 820.0 < 1500.0:
			_fail("%s edge is still too close to the Art Castle entrance: %.1fm clearance"
				% [kingdom_id, nearest_edge_z - 820.0])
			return
	print("KINGDOM_REGIONS_3000M_TEST: PASS — Heart and Creator station platforms, distinct regions, old Mind region gone and Mind falls recover on the Mind district")
	quit()
