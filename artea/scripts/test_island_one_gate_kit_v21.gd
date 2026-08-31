extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	root.add_child(world)
	for _frame in 5:
		await process_frame

	var gate := world.get_island_one_puzzle()
	assert(gate != null)
	var kit := gate.get_node("GateArchitectureKit") as Node3D
	assert(kit.get_child_count() == 5)
	assert(int(kit.get_meta("component_family_count", 0)) == 22)
	assert(int(kit.get_meta("reusable_variant_count", 0)) == 39)
	assert(int(kit.get_meta("unique_landmark_count", 0)) == 1)
	assert(str(kit.get_meta("application_mode", "")) == "additive_on_existing_island")
	assert(float(kit.get_meta("processional_clearance_m", 0.0)) == 40.0)

	var expected_sections := PackedStringArray([
		"01_CivicTerraceKit",
		"02_AetherConservatoryKit",
		"03_ThresholdStructureKit",
		"04_BeaconTowerKit",
		"05_LandscapeTrimKit",
	])
	var family_total := 0
	var variant_total := 0
	for section_name in expected_sections:
		var section := kit.get_node(section_name) as Node3D
		assert(bool(section.get_meta("reusable_kit_assembly", false)))
		family_total += int(section.get_meta("component_family_count", 0))
		variant_total += int(section.get_meta("reusable_variant_count", 0))
	assert(family_total == 22)
	assert(variant_total == 39)

	var canopy := kit.get_node("02_AetherConservatoryKit") as Node3D
	assert(canopy.find_children("CanopyGlassTriangle_*", "MeshInstance3D", true, false).size() == 144)
	assert(canopy.find_children("LongitudinalGlassMullion_*", "MeshInstance3D", true, false).size() == 2,
		"only the two structural eave rails remain in the clear player corridor")
	assert(canopy.find_children("*SpringBrace_*", "MeshInstance3D", true, false).is_empty(),
		"redundant braces remain removed from the puzzle camera corridor")
	assert(canopy.find_children("VaultRidgeKeystone_*", "MeshInstance3D", true, false).size() == 7)
	assert(canopy.find_children("*IvoryColumn_*", "MeshInstance3D", true, false).size() == 10)
	var threshold := kit.get_node("03_ThresholdStructureKit") as Node3D
	assert(threshold.find_children("IvoryCurvedVoussoir_*", "MeshInstance3D", true, false).size() == 18)
	assert(kit.get_node("04_BeaconTowerKit").get_child_count() == 2)
	assert(kit.get_node("05_LandscapeTrimKit").get_child_count() == 4)

	# The gate remains an additive top-level kit. Its original island architecture
	# and the functional Compass stay independently owned and inspectable.
	var geometry := world.get_node("WorldOneGeometry") as Node3D
	var landing := geometry.get_node("01WorldGateLanding") as Node3D
	var foundation := landing.get_node("ModularFloatingFoundation") as Node3D
	assert(foundation.get_child_count() > 0)
	assert(gate.get_node_or_null("CompassMachine") != null)
	assert(gate.find_children("PuzzleControl_*", "Node3D", true, false).size() == 9,
		"the reusable architecture preserves all base puzzle stations")
	print("IslandOneGateKitV21: PASS — reusable gate kit preserves foundation and puzzle")
	world.queue_free()
	await process_frame
	quit()
