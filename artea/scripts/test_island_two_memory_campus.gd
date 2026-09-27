extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := load("res://scenes/mind_spark/mind_spark_world_one.tscn").instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.get_node("QuestController").enabled = false
	root.add_child(world)
	for frame in 8:
		await physics_frame
	var campus := world.get_node("IslandTwoMemoryCampus") as Node3D
	assert(campus.get_node("MemoryPromenade") is Node3D)
	assert(str(world.get_meta("island_two_layout_revision"))=="observatory_of_understanding_05_heavenly_hierarchy")
	for architecture_name in ["EvidenceObservatory","EvidenceAetherBus",
			"HopeOpticsGallery","HopeMaterialisationConduit","IslandTwoGroupedLandscaping"]:
		assert(campus.get_node(architecture_name) is Node3D,
			"missing Island Two style-alignment assembly: "+architecture_name)
	var observatory := campus.get_node("EvidenceObservatory") as Node3D
	assert(observatory.get_node("CelestialArchiveOrrery") is Node3D)
	assert(observatory.find_children("ArchiveCanopyRib_*","Node3D",true,false).size()==6)
	var gallery := campus.get_node("HopeOpticsGallery") as Node3D
	assert(gallery.find_children("PerspectiveRib_*","Node3D",true,false).size()==6)
	assert(gallery.get_node("TruthFoundryLintel") is Node3D)
	var landscape := campus.get_node("IslandTwoGroupedLandscaping") as Node3D
	assert(landscape.find_children("ObservatoryCanopyTree_*","Node3D",false,false).size()==6)
	for court_name in ["EvidenceReadingCourt","MemoryWeavingCourt",
			"ArchiveLogicCourt","PerspectiveGallery","TruthMaterialisationCourt",
			"EliteGuardianCourt"]:
		assert(campus.get_node(court_name) is Node3D,"missing Island Two gameplay court: "+court_name)
	assert(world.get_node("IslandOneResearchCampus/FocusBellAlcove") is Node3D,
		"the optional Focus Bell belongs to Island One's support route")
	var route := campus.get_node("IslandTwoQuestRoute") as Node3D
	assert(route.find_children("*GuidanceFacet_*","Node3D",true,false).size()>=20,
		"the two quest chapters require a continuous discrete guidance route")
	assert(str(route.get_meta("guidance_style")).contains("no solid coloured line"))
	var ordered := ["world_one.evidence_scanner","world_one.memory_board",
		"world_one.logic_gate","world_one.perspective_lens","world_one.truth_bridge"]
	for route_index in ordered.size():
		var station: QuestObjectBase
		for candidate in world.get_quest_objects():
			if candidate.save_id==ordered[route_index]: station=candidate; break
		assert(station!=null)
		assert(int(station.get_meta("island_two_route_order"))==route_index+1)
		var approach: Vector3=station.get_meta("operator_approach_local")
		var intended := ((station.get_parent() as Node3D).global_basis*(approach-station.position)).normalized()
		assert(station.global_basis.z.normalized().dot(intended)>.995,
			"station must face its incoming player approach: "+station.save_id)
		assert((station.get_meta("front_axis") as Vector3).is_equal_approx(Vector3.BACK),
			"station front-axis metadata must match the authored +Z presentation face")
		assert(float(station.get_meta("minimum_operator_apron_m"))>=4.0)
		assert(station.get_node("IslandTwoStationSolid") is StaticBody3D,
			"every reachable Island Two station needs a simplified solid housing")
	for station in world.get_quest_objects():
		if station.save_id.begins_with("world_one.") and station.has_meta("canonical_layout"):
			assert(station.get_node("IslandTwoStationSolid") is StaticBody3D,
				"optional and required Island Two stations must share the solid housing contract")
	var zones: Dictionary=world.get("_zone_nodes")
	var arrival_arch := (zones["03_constellation_court"] as Node3D).get_node("FearGate") as Node3D
	var incoming := world.get_zone_position("02_living_network_forest") - world.get_zone_position("03_constellation_court")
	incoming.y = 0.0
	incoming = incoming.normalized()
	assert(arrival_arch.position.is_equal_approx(incoming * 138.0))
	assert(arrival_arch.basis.z.normalized().dot(incoming) > .99)
	assert(arrival_arch.has_node("HeavenlyArrivalPorticoDetails/WisdomBeacon"))
	var duplicate_arch := (zones["03_constellation_court"] as Node3D).get_node("Proof_LogicGate") as Node3D
	assert(not duplicate_arch.visible,"legacy Proof/Logic arch must not duplicate the Memory Gate")
	for body in duplicate_arch.find_children("*","CollisionObject3D",true,false):
		assert((body as CollisionObject3D).collision_layer==0)
	var receiver := campus.get_node("EchoSeedArrivalReceiver") as Node3D
	assert(receiver.get_meta("story_role") != null)
	world.set_island_two_story_state("invited")
	assert((receiver.get_node("InvitedHalo") as MeshInstance3D).visible)
	assert(not (receiver.get_node("ReceivedEchoSeed") as MeshInstance3D).visible)
	world.set_island_two_story_state("received")
	assert((receiver.get_node("ReceivedEchoSeed") as MeshInstance3D).visible)
	var bus := campus.get_node("EvidenceAetherBus") as Node3D
	assert((bus.get_node("ArchiveBusReading_01") as Node3D).scale.x == 1.0)
	assert((bus.get_node("ArchiveBusReading_02") as Node3D).scale.x < 0.5)
	world.set_island_two_story_state("archive_open")
	assert((bus.get_node("ArchiveBusReading_07") as Node3D).scale.x == 1.0)
	var conduit := campus.get_node("HopeMaterialisationConduit") as Node3D
	assert(not (conduit.get_node("HopeSignalSegment_01") as Node3D).visible)
	world.set_island_two_story_state("hope_reframed")
	assert((conduit.get_node("HopeSignalSegment_03") as Node3D).visible)
	assert(not (conduit.get_node("HopeSignalSegment_04") as Node3D).visible)
	world.set_island_two_story_state("truth_materialised")
	assert((conduit.get_node("HopeSignalSegment_05") as Node3D).visible)
	var reward := campus.get_node("EliteGuardianCourt/GuardianRewardSocket/RewardHopeCrystal") as Node3D
	assert(not reward.visible)
	world.set_island_two_story_state("guardian_freed")
	assert(reward.visible)
	var memory_nodes := (zones["03_constellation_court"] as Node3D).find_children("MemoryNode","Node3D",true,false)
	var visible_memory_nodes := memory_nodes.filter(func(node): return (node as Node3D).visible).size()
	assert(visible_memory_nodes == memory_nodes.size(),
		"all eight older memory lights should return as restrained archive lanterns")
	for district_id in ["03_constellation_court","04_hope_path_ridge"]:
		for heritage_grove in (zones[district_id] as Node3D).find_children(
				"*DesignedBioTreeGrove","Node3D",false,false):
			assert((heritage_grove as Node3D).visible)
			var visible_trees := heritage_grove.get_children().filter(
				func(node): return node is Node3D and (node as Node3D).visible)
			assert(visible_trees.size() == heritage_grove.get_child_count(),
				"complete legacy grove should be restored rather than selectively deleted")
			for tree in heritage_grove.get_children():
				if not tree is Node3D: continue
				assert((tree as Node3D).get_meta("island_two_palette_override", false),
					"Island Two trees must use the local heavenly garden palette")
				var canopy := (tree as Node3D).find_child("GroveCrownMushroom", true, false) as MeshInstance3D
				if canopy != null:
					var foliage := canopy.material_override as StandardMaterial3D
					assert(foliage.albedo_color.g > foliage.albedo_color.r
						and foliage.albedo_color.g > foliage.albedo_color.b,
						"Island Two canopy must read green rather than violet")
				for body in tree.find_children("*","CollisionObject3D",true,false):
					assert((body as CollisionObject3D).collision_layer==(1 if tree.visible else 0))
	var old_pavilion := (zones["04_hope_path_ridge"] as Node3D).get_node(
		"CelestialHopeUpperDistrict/AetherLiftPavilion") as Node3D
	assert(old_pavilion.visible,"the older pavilion's useful civic architecture must be restored")
	assert(not (old_pavilion.get_node("AetherLiftHalo") as Node3D).visible,
		"oversized halo remains removed so the new Truth Foundry stays dominant")
	assert(not (old_pavilion.get_node("TruthPortal_01") as Node3D).visible,
		"obsolete truth ring remains retired")
	assert((old_pavilion.get_node("TruthPortalPier_01") as Node3D).visible,
		"archive buttress accidentally hidden by the older wildcard is restored")
	assert((zones["04_hope_path_ridge"] as Node3D).get_node(
		"CelestialHopeUpperDistrict/TwinUpperPressureCondenserHouses").visible,
		"legacy foundation-power condenser houses remain visible")
	assert((zones["04_hope_path_ridge"] as Node3D).get_node(
		"CelestialHopeUpperDistrict/CurvedSunriseGardenTerraces").visible,
		"the older curved garden frame must remain part of Island Two")
	var gate := world.get_node("WorldOneGeometry/SavedQuestProgressionGates/QuestGate_2") as AnimatableBody3D
	assert(str(gate.get_meta("custom_gate_motion")) == "island_two_memory_hinges")
	assert(not (gate.get_node("Barrier") as MeshInstance3D).visible)
	assert(gate.has_node("IslandTwoMemoryGate/ArchiveWisdomKeystone"))
	assert(gate.has_node("IslandTwoMemoryGate/WestMemoryLeaf/EvidenceMemoryWingBraceUpper"))
	assert(gate.has_node("IslandTwoMemoryGate/WestMemoryLeaf/HopeMemoryWingBraceUpper"))
	assert(gate.has_node("IslandTwoMemoryGate/EastMemoryLeaf/EvidenceMemoryLeafJewel"))
	assert(gate.has_node("IslandTwoMemoryGate/EastMemoryLeaf/HopeMemoryLeafJewel"))
	assert((gate.get_node("IslandTwoMemoryGate/WestMemoryLeaf") as Node3D).rotation.y == 0.0)
	var brass_bar := gate.get_node("IslandTwoMemoryGate/WestMemoryLeaf/HopeBrassMemoryBar_01") as Node3D
	var closed_bar_position := brass_bar.global_position
	world.set_quest_gate_open(1, true)
	await create_timer(2.4).timeout
	print("GATE_SWEEP: ", gate.get_node("IslandTwoMemoryGate").get_meta("last_obstruction", "clear"))
	assert(brass_bar.global_position.distance_to(closed_bar_position) > 4.0,
		"Door ornament must move with the leaf after static geometry batching")
	assert((gate.get_node("CollisionShape3D") as CollisionShape3D).disabled)
	assert(absf((gate.get_node("IslandTwoMemoryGate/WestMemoryLeaf") as Node3D).rotation.y) > 1.5)
	world.set_quest_gate_open(1, false)
	await create_timer(2.4).timeout
	assert(is_zero_approx((gate.get_node("IslandTwoMemoryGate/WestMemoryLeaf") as Node3D).rotation.y))
	assert(not (gate.get_node("IslandTwoMemoryGate/WestMemoryLeaf/GateLeafCollision") as CollisionShape3D).disabled)
	var obstruction := StaticBody3D.new()
	obstruction.name = "TestPlayerInDoorSweep"
	var obstruction_shape := CollisionShape3D.new()
	var obstruction_box := BoxShape3D.new()
	obstruction_box.size = Vector3(1.5, 3, 1.5)
	obstruction_shape.shape = obstruction_box
	obstruction.add_child(obstruction_shape)
	world.add_child(obstruction)
	obstruction.global_position = gate.to_global(Vector3(-5.3, 6, 2.9))
	await physics_frame
	world.set_quest_gate_open(1, true)
	await create_timer(2.4).timeout
	assert(str(gate.get_node("IslandTwoMemoryGate").get_meta("gate_state")) == "obstructed")
	obstruction.queue_free()
	await process_frame
	await create_timer(2.4).timeout
	assert(str(gate.get_node("IslandTwoMemoryGate").get_meta("gate_state")) == "open")
	var old_bridge := world.get_node("WorldOneGeometry/MainStoryCircuitRoute/CircuitRoute_03_A") as MeshInstance3D
	assert(not old_bridge.visible)
	var ridge_enemies := world.get_enemies().filter(func(enemy): return enemy.encounter_id=="ridge")
	assert(ridge_enemies.size()==2)
	for enemy in ridge_enemies:
		assert(absf((enemy as Node3D).position.x)<=14.1)
		assert(absf((enemy as Node3D).position.z-72.0)<.1)
	world.queue_free()
	await process_frame
	print("ISLAND_TWO_MEMORY_CAMPUS: PASS — revision 05 aligns the arrival portico, details the Memory Gate, applies the green heavenly tree palette and preserves the complete heritage layer")
	quit()
