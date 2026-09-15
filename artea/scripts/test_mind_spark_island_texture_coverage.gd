extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://test_mind_spark_texture_v12.json"
	root.add_child(world)
	for _frame in 4: await process_frame
	var geometry := world.get_node("WorldOneGeometry") as Node3D
	var foundation_count := 0
	var detailed_surface_count := 0
	for zone_id in world.get_zone_ids():
		var zone := geometry.get_node(zone_id.to_pascal_case()) as Node3D
		var foundation := zone.get_node_or_null("ModularFloatingFoundation") as Node3D
		var expected_revision := "v12" if zone_id == "02_living_network_forest" else "v11"
		if zone_id == "03_constellation_court": expected_revision = "v16"
		elif zone_id == "04_hope_path_ridge": expected_revision = "v17"
		if foundation == null or foundation.get_meta("source_revision", "") != expected_revision:
			_fail("%s has no reference-style %s celestial land" % [zone_id, expected_revision]); return
		foundation_count += 1
		var meshes := foundation.find_children("*", "MeshInstance3D", true, false)
		var expected_meshes := 14 if zone_id == "03_constellation_court" else (10 if zone_id == "04_hope_path_ridge" else 6)
		if meshes.size() != expected_meshes:
			_fail("%s has an incorrect static / moving assembly count" % zone_id); return
		detailed_surface_count += meshes.size()
		var variant_index := int(foundation.get_meta("variant_index", 0))
		var family_revision := "v17" if zone_id == "04_hope_path_ridge" else "v11"
		for family in ["CelestialIvoryDeck", "Rock_%s_%02d" % [family_revision, variant_index],
				"Architecture_%s_%02d" % [family_revision, variant_index], "Machinery_%s_%02d" % [family_revision, variant_index],
				"Inlay_%s_%02d" % [family_revision, variant_index], "Railing_%s_%02d" % [family_revision, variant_index]]:
			var visual := foundation.find_child(family, true, false) as MeshInstance3D
			if visual == null or visual.mesh == null or visual.mesh.get_surface_count() == 0:
				_fail("%s is missing actual geometry for %s" % [zone_id, family]); return
		if foundation.find_children("*", "CollisionObject3D", true, false).size() != 0:
			_fail("celestial visual shell must not introduce route obstacles"); return
	var storm := geometry.get_node("05ThoughtStormArena") as Node3D
	if not world.find_children("LayeredStormRing_*", "MeshInstance3D", true, false).is_empty():
		_fail("unsupported tornado rings remain in the production storm arena"); return
	if str(storm.get_meta("storm_landmark_design", "")) != "grounded_regulator_array" \
			or int(storm.get_meta("storm_regulator_count", 0)) not in [6, 8] \
			or int(storm.get_meta("unsupported_tornado_rings", -1)) != 0:
		_fail("storm arena does not declare its grounded regulator-array contract"); return
	var compass_floor := world.find_child("StormCompassCivicFloor", true, false) as Node3D
	if compass_floor == null or not bool(compass_floor.get_meta("replaces_electric_grid", false)):
		_fail("storm arena has no architectural compass floor replacing the electric grid"); return
	var island_three := world.get_island_three_experience()
	var production_station_count := 0
	for station_id in island_three.station_ids():
		var station := island_three.find_child(str(station_id).to_pascal_case(), true, false)
		if station == null:
			for candidate in island_three.find_children("*", "Node3D", true, false):
				if str(candidate.get_meta("station_id", "")) == station_id:
					station = candidate; break
		if station != null and bool(station.get_meta("low_poly_production_object", false)):
			production_station_count += 1
	if production_station_count != 7:
		_fail("all seven Island Three interaction stations must use the low-poly production kit"); return
	var sanctuary := geometry.get_node("06OldestTreeSanctuary") as Node3D
	var engine := world.find_child("MindSparkBioDataTree", true, false) as Node3D
	if engine == null or str(engine.get_meta("visible_design", "")) != "Crown Wisdom Engine" \
			or not bool(engine.get_meta("replaces_organic_tree", false)):
		_fail("sanctuary has no Crown Wisdom Engine compatibility landmark"); return
	for required in ["EngineFoundation", "AetherReactor", "WisdomCrownOuter", "WisdomCrownGlass", "StarOfWisdomReward"]:
		if engine.find_child(required, true, false) == null:
			_fail("Crown Wisdom Engine is missing " + required); return
	var sanctuary_modules := 0
	for module in get_nodes_in_group("mind_spark_organized_tree"):
		if str(module.get_meta("zone_id", "")) == "06_oldest_tree_sanctuary":
			sanctuary_modules += 1
			if not bool(module.get_meta("replaces_organic_tree", false)):
				_fail("an organic tree remains in the mechanical sanctuary module ring"); return
	if sanctuary_modules != 24:
		_fail("mechanical sanctuary must retain its 24-part landmark rhythm"); return
	if detailed_surface_count != 48:
		_fail("expected forty-eight authored foundation surfaces, got %d" % detailed_surface_count); return
	print("MIND_SPARK_ISLAND_GEOMETRY_DETAIL: PASS — %d celestial foundations; tornado and tree visuals replaced by grounded machinery" % foundation_count)
	quit()

func _fail(message: String) -> void:
	push_error("MIND_SPARK_ISLAND_GEOMETRY_DETAIL: " + message)
	quit(1)
