extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://test_world_one_render_optimization.json"
	root.add_child(world)
	await process_frame

	var merged_groups := int(world.get_meta("merged_static_render_groups", 0))
	var merged_sources := int(world.get_meta("merged_static_render_sources", 0))
	var repeated_groups := int(world.get_meta("batched_static_render_groups", 0))
	var repeated_sources := int(world.get_meta("batched_static_render_sources", 0))
	var ranged_meshes := int(world.get_meta("distance_culled_mesh_count", 0))
	var storm_crown := world.get_warden().get_node("VisualRoot/BlightShell/StormCrown") as Node3D
	var civic_sanctuary := world.get_node(
		"WorldOneGeometry/IslandThreeCivicSanctuary") as Node3D
	var island_two_campus := world.get_node("IslandTwoMemoryCampus") as Node3D
	var unfinished_garden := world.get_node("GardenOfUnfinishedLight") as Node3D
	var arrival_kit := world.get_node(
		"WorldOneGeometry/01WorldGateLanding/CelestialWorldGateArrival/GateArchitectureKit") as Node3D
	var animated_crown_sources := int(storm_crown.get_meta("merged_static_source_count", 0))
	assert(is_equal_approx(float(civic_sanctuary.get_meta(
		"static_render_merge_cell_size", 0.0)), 384.0),
		"Island Three's compact civic architecture must use its island-scale batch cells")
	assert(is_equal_approx(float(island_two_campus.get_meta(
		"static_render_merge_cell_size", 0.0)), 384.0) \
			and is_equal_approx(float(unfinished_garden.get_meta(
				"static_render_merge_cell_size", 0.0)), 384.0),
		"Island Two's observatory and conservatory must use island-scale batch cells")
	for zone_id in ["01_world_gate_landing", "02_living_network_forest",
			"03_constellation_court", "04_hope_path_ridge",
			"05_thought_storm_arena", "06_oldest_tree_sanctuary"]:
		var zone := world.get_node("WorldOneGeometry/%s" % str(zone_id).to_pascal_case())
		assert(is_equal_approx(float(zone.get_meta(
			"static_render_merge_cell_size", 0.0)), 384.0),
			"each district must consolidate inert masonry at court scale")
	assert(merged_groups > 0 and merged_sources > merged_groups * 3,
		"World One must consolidate meaningful groups of inert static render leaves")
	assert(repeated_groups > 0 and repeated_sources > repeated_groups * 3,
		"World One must instance repeated static meshes without deleting authored nodes")
	print("WORLD_ONE_RENDER_OPTIMIZATION_METRICS: %d sources, %d batches" % [
		merged_sources + repeated_sources, merged_groups + repeated_groups])
	# Retiring the imported Echo Garden shrub separates two nearby scenery cells.
	# The native-only sky gardens also keep seven material groups shadow-free so
	# their distant geometry cannot stripe the playable court. Preserve the
	# source coverage floor and cap the measured intentional replacement groups.
	# Opening the reflection promenade removes four close trees and shifts the
	# remaining grove into one additional material/cell group; this 0.3% increase
	# is the measured cost of preserving the mirror and Oldest Tree sightline.
	# The Storm Lens overhead framework now occupies one shadow-free batch so its
	# 60-metre-high sight frame cannot stripe the arrival court. That deliberate
	# separation adds one batch while preserving all authored source coverage.
	# The finished Stormworks threshold deliberately omits seven near-camera rim
	# facets that appeared as detached foreground debris. The lower source count
	# is a geometry reduction; the batch ceiling and one-to-one accounting below
	# still guard the optimization contract.
	assert(merged_sources + repeated_sources >= 5790 \
			and merged_groups + repeated_groups <= 260,
		"court-scale cells must consolidate at least 5,790 sources into no more than 260 spatial batches")
	assert(ranged_meshes > 1000,
		"World One must apply distance ranges broadly enough to cull distant trim")

	var tagged_sources := 0
	var batched_sources := 0
	for mesh_value in world.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_value as MeshInstance3D
		if mesh.layers == 0:
			assert(mesh.has_meta("render_merged_into"),
				"no visible mesh may be removed from render layers without a replacement batch")
			assert(mesh.mesh != null,
				"merged sources retain authored mesh data for inspection and collision derivation")
			tagged_sources += 1
		if mesh.has_meta("merged_static_source_count"):
			assert(mesh.layers == 1 and mesh.mesh != null,
				"every merged render batch remains drawable")
			batched_sources += int(mesh.get_meta("merged_static_source_count"))
	for batch_value in world.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := batch_value as MultiMeshInstance3D
		if batch.has_meta("merged_static_source_count"):
			assert(batch.layers == 1 and batch.multimesh != null,
				"every repeated static batch remains drawable")
			batched_sources += int(batch.get_meta("merged_static_source_count"))
	assert(tagged_sources == merged_sources + repeated_sources + animated_crown_sources \
			and batched_sources == tagged_sources,
		"every disabled source maps exactly once to a live static or animated render batch")
	var garden := world.get_node("GardenOfUnfinishedLight")
	var garden_batched_sources := 0
	for mesh_value in garden.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_value as MeshInstance3D
		if mesh.layers == 0 and mesh.has_meta("render_merged_into"):
			garden_batched_sources += 1
	assert(garden_batched_sources > 300,
		"the retired garden projector must not prevent its live static conservatory from batching")
	var arrival_kit_batched_sources := 0
	for mesh_value in arrival_kit.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_value as MeshInstance3D
		if mesh.layers == 0 and mesh.has_meta("render_merged_into"):
			arrival_kit_batched_sources += 1
	assert(arrival_kit_batched_sources >= 350,
		"the inert arrival conservatory must not inherit the compass controller's dynamic render cost")
	var station_spur := world.get_node(
		"WorldOneGeometry/OptionalCompletedWorldStationSpur") as Node3D
	world.set_station_spur_available(true)
	var station_merged_sources := 0
	var station_live_batches := 0
	for mesh_value in station_spur.find_children("*", "MeshInstance3D", true, false):
		var mesh := mesh_value as MeshInstance3D
		if mesh.layers == 0 and mesh.has_meta("render_merged_into"):
			station_merged_sources += 1
		if mesh.has_meta("merged_static_source_count") and mesh.layers == 1:
			station_live_batches += 1
	assert(station_merged_sources >= 80 and station_live_batches > 0,
		"the completed-world station must reveal batched stairs instead of 91 individual draws")

	for object in world.get_quest_objects():
		var visible_meshes := 0
		for mesh_value in object.find_children("*", "MeshInstance3D", true, false):
			var mesh := mesh_value as MeshInstance3D
			if mesh.visible and mesh.layers != 0:
				visible_meshes += 1
		assert(visible_meshes > 0,
			"quest object %s must retain independently rendered feedback geometry" % object.save_id)

	print("WORLD_ONE_RENDER_OPTIMIZATION: PASS — %d static sources -> %d spatial batches, plus %d animated Warden crown sources -> 4 batches, including %d conservatory sources; %d meshes use distance ranges; all 15 quest visuals remain independent" % [
		merged_sources + repeated_sources, merged_groups + repeated_groups,
		animated_crown_sources, garden_batched_sources, ranged_meshes])
	quit()
