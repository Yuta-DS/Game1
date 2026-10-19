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
	for kingdom_id in ["mind"]:
		if regions.call("get_kingdom_size", kingdom_id) != Vector2(3000, 3000):
			_fail("%s is not exactly 3000m x 3000m" % kingdom_id)
			return
		var kingdom := regions.get_node_or_null("%sKingdom3000m" % kingdom_id.to_pascal_case())
		if kingdom == null:
			_fail("missing %s region" % kingdom_id)
			return
		if kingdom.get_node_or_null("ExplorationBoundary3000m") == null:
			_fail("%s has no explicit 3 km exploration boundary" % kingdom_id)
			return
		if kingdom.get_node_or_null("ConnectedStoryPath") == null:
			_fail("%s has no connected story path" % kingdom_id)
			return
		var route: Array = regions.call("get_story_route", kingdom_id)
		if route.size() != 8:
			_fail("%s needs eight story chapters, got %d" % [kingdom_id, route.size()])
			return
		for index in route.size():
			var checkpoint_name := "StoryCheckpoint_%02d_%s" % [index + 1, route[index].id]
			if kingdom.get_node_or_null(checkpoint_name) == null:
				_fail("%s is missing %s" % [kingdom_id, checkpoint_name])
				return
	var centers: Dictionary = regions.call("get_kingdom_centers")
	if centers.mind.distance_to(centers.heart) < 3000 \
			or centers.heart.distance_to(centers.creator) < 3000:
		_fail("kingdom footprints overlap instead of being distinct 3 km worlds")
		return
	# The gallery connection is at z=820; all large kingdom centres must now be
	# on its opposite-facing side (+Z), with the furthest world clearly beyond it.
	for kingdom_id in ["mind", "heart", "creator"]:
		if float(centers[kingdom_id].z) <= 820.0:
			_fail("%s was not mirrored to the gallery-facing side" % kingdom_id)
			return
		var nearest_edge_z: float = float(centers[kingdom_id].z) - regions.call("get_kingdom_size", kingdom_id).y * 0.5
		if nearest_edge_z - 820.0 < 1500.0:
			_fail("%s edge is still too close to the Art Castle entrance: %.1fm clearance"
				% [kingdom_id, nearest_edge_z - 820.0])
			return
	print("KINGDOM_REGIONS_3000M_TEST: PASS — 3 km Mind world with 8 checkpoints, Heart and Creator station platforms, distinct regions")
	quit()
