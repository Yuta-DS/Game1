extends SceneTree

const Botanicals := preload("res://scripts/castle_royal_botanicals.gd")

func _init() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("CASTLE_BOTANICAL_TEST: " + message)
	quit(1)

func _run() -> void:
	var hub := (load("res://scenes/New_Hub_World.tscn") as PackedScene).instantiate()
	root.add_child(hub)
	for frame in 90:
		await process_frame
		await physics_frame
	var plants := hub.get_node_or_null("CastleRoyalBotanicals") as Node3D
	if plants == null or not plants.find_children("*", "CollisionObject3D", true, false).is_empty() \
			or not plants.find_children("*", "CollisionShape3D", true, false).is_empty():
		_fail("missing planting or new snag-prone plant collision")
		return
	var anchors: Array = plants.get_meta("placement_anchors")
	if plants.get_meta("style", "") != "medieval_irregular_wall_moss_and_sparse_ivy":
		_fail("old ornamental wall garlands were not replaced with moss and ivy")
		return
	if anchors.size() < 60 or anchors.size() > 140 \
			or int(plants.get_meta("triangle_count")) > 90000 \
			or int(plants.get_meta("draw_surfaces")) > 9:
		_fail("botanical coverage or web mesh budget is incorrect")
		return
	for zone in ["SpiralOuter", "SpiralInner", "RooftopBorders", "RoyalStair", "GateAndCourt",
			"KeepButtresses", "OriginalKeep", "BridgeBorders", "TowerAndArrival"]:
		if not plants.has_node(zone):
			_fail("planting missing from " + zone)
			return
	for mesh: MeshInstance3D in plants.get_children():
		var mat := mesh.material_override as StandardMaterial3D
		if mat == null or not mat.vertex_color_use_as_albedo or mat.emission_enabled:
			_fail("living palette was replaced with stone or glow")
			return
		var arrays := mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		if vertices.size() != colours.size():
			_fail("fine moss, vein and petal geometry lost its colours")
			return
		for point in vertices:
			if not point.is_finite():
				_fail("invalid botanical vertex")
				return
	for anchor: Dictionary in anchors:
		var source := root.get_node_or_null(anchor.source) as Node3D
		var at: Transform3D = anchor.transform
		var bounds: AABB = anchor.local_bounds
		# Bridge finish is a separate Blender mesh; its original hidden wall is
		# still the collision authority and the correct placement owner.
		if source == null or (not source.is_visible_in_tree() and anchor.zone != "BridgeBorders") \
				or at.basis.y.normalized().dot(Vector3.UP) < 0.999:
			_fail("planting detached from an upright stone owner: %s in %s" % [anchor.source, anchor.zone])
			return
		if bounds.position.z < -0.001 or bounds.end.z > 0.13 or bounds.size.x > 1.3:
			_fail("planting projects into the route instead of staying shallow")
			return
		if anchor.zone == "RoyalStair":
			# All new growth is below the shields' bottom edge; not pasted on crests.
			if at.origin.y + bounds.end.y * at.basis.y.length() > source.global_position.y + 0.12:
				_fail("flower overlaps the royal stair heraldry")
				return
		if anchor.zone == "SpiralOuter":
			for post: MeshInstance3D in hub.find_children("OuterStoneNewel_*", "MeshInstance3D", true, false):
				if (at * bounds).intersects((post.global_transform * post.get_aabb()).grow(0.03)):
					_fail("moss clips through a spiral newel")
					return
		if anchor.has("audited_stone_triangle"):
			var original := source as MeshInstance3D
			var data := original.mesh.surface_get_arrays(0)
			var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
			var index: int = anchor.audited_stone_triangle
			var centre := original.to_global((vertices[indices[index]] + vertices[indices[index+1]] + vertices[indices[index+2]]) / 3)
			if absf(at.origin.distance_to(centre) - 0.016) > 0.001:
				_fail("main keep planting no longer follows the audited stone face")
				return
	var before := plants.get_child_count()
	Botanicals.build(hub)
	if plants.get_child_count() != before:
		_fail("reapplying planting duplicates geometry")
		return
	print("CASTLE_BOTANICAL_TEST: PASS — %d shallow wall-attached clusters across 9 zones, %d triangles, no new colliders; original keep faces and royal shields preserved" % [anchors.size(), plants.get_meta("triangle_count")])
	quit(0)
