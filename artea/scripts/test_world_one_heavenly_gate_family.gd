extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := CharacterBody3D.new()
	player.name = "GateInteractionTestPlayer"
	player.add_to_group("Player")
	root.add_child(player)
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	(world.get_node("QuestController") as MindSparkWorldOneQuest).enabled = false
	root.add_child(world)
	for _frame in 8:
		await physics_frame

	var island_one_gate := world.get_island_one_heavenly_star_gate()
	assert(island_one_gate != null)
	var island_one_portico := island_one_gate.get_node(
		"HeavenlyThresholdCourt/HeavenlyGateIvoryPortico") as Node3D
	assert(bool(island_one_portico.get_meta("pink_backdrop_hidden", false)))
	var island_one_arch := island_one_gate.get_node(
		"HeavenlyThresholdCourt/ClassicalHeavenlyHingedPortal") as Node3D
	assert(island_one_arch.has_node("HeavenlyArchOrder_01_32"))
	assert(island_one_arch.has_node("HeavenlyArchOrder_02_32"))
	assert(not island_one_arch.has_node("HeavenlyArchOrder_03_01"))
	for side in ["West", "East"]:
		var backing := island_one_portico.get_node("%sMasonryCore" % side) as MeshInstance3D
		assert(backing.position.y + backing.mesh.get_aabb().position.y <= 0.35
			and backing.position.y + backing.mesh.get_aabb().end.y >= 21.6,
			"each opaque ivory pillar must meet the ground and sloping crown")
		var reservoir := island_one_portico.get_node(
			"%sAetherGlassReservoir" % side) as MeshInstance3D
		assert(reservoir.mesh is CylinderMesh
			and (reservoir.material_override as StandardMaterial3D).transparency
			== BaseMaterial3D.TRANSPARENCY_ALPHA,
			"the ivory pier must hold a round translucent glass cylinder")
		assert(island_one_portico.has_node("%sAetherGlassReservoirCollision" % side))
		assert(island_one_portico.has_node("%sReservoirIvorySocket" % side)
			and island_one_portico.has_node("%sReservoirIvoryCrown" % side))
		var socket := island_one_portico.get_node(
			"%sReservoirIvorySocket" % side) as MeshInstance3D
		assert(socket.position.y + socket.mesh.get_aabb().position.y <= 0.05
			and reservoir.position.y + reservoir.mesh.get_aabb().position.y
			<= socket.position.y + socket.mesh.get_aabb().end.y,
			"the glass cylinder must seat into an ivory base on the ground")
		for band_index in 4:
			assert(island_one_portico.has_node(
				"%sReservoirGiltBand_%02d" % [side, band_index + 1]))
		assert(island_one_portico.has_node("%sArchSpringShoulder" % side))
		assert(island_one_portico.has_node("%sHingeGearMount" % side))
		assert(island_one_portico.has_node("%sWallLanternBracket" % side))
		assert(island_one_portico.has_node("%sWarmWallLantern" % side))
		var support := island_one_portico.get_node("%sCrownSupportPier" % side) as MeshInstance3D
		var support_foot := island_one_portico.get_node("%sCrownSupportFoot" % side) as MeshInstance3D
		assert(support.position.y + support.mesh.get_aabb().end.y >= 19.5,
			"the outer crown sweep must meet a full-height ivory pillar")
		assert(support_foot.position.y + support_foot.mesh.get_aabb().position.y <= 0.05,
			"the crown support must continue to the ground")
		assert(island_one_portico.has_node("%sCrownSupportPierCollision" % side)
			and island_one_portico.has_node("%sCrownSupportFootCollision" % side),
			"the full-height pillars and their bases must block player movement")
		var shoulder_x := -12.5 if side == "West" else 12.5
		var support_bounds := support.mesh.get_aabb()
		assert(absf(support.position.x - shoulder_x) <= support_bounds.size.x * 0.5
			and absf(support.position.z + 4.2) <= support_bounds.size.z * 0.5,
			"the visible pier must sit beneath the crown sweep landing")
		assert(island_one_portico.has_node("%sCrownSupportCapital" % side))
		var riser := island_one_portico.get_node("%sCrownRiser" % side) as MeshInstance3D
		assert(riser.position.y + riser.mesh.get_aabb().position.y <= 18.63,
			"the upper riser must overlap the pier capital")
		assert(riser.position.y + riser.mesh.get_aabb().end.y >= 21.6,
			"the upper riser must reach the sloping crown frame")
		assert(island_one_portico.has_node("%sCrownRiserSeat" % side))
		assert(island_one_portico.has_node("%sCarvedCapital" % side))
		var power_bay := island_one_gate.get_node(
			"HeavenlyThresholdCourt/%sHingeDrivePowerBay" % side) as Node3D
		assert(not power_bay.has_node("AetherLiftReservoir"),
			"the visible glass cylinder must stay integrated with the portico")
		var rotor := island_one_gate.find_child("%sHingeDriveRotor" % side, true, false) as Node3D
		assert(absf(rotor.position.x) <= 10.35 and rotor.scale.x < 0.8,
			"the hinge gear must sit within the ivory pier silhouette")
		var leaf := island_one_gate.get_node("%sGoldenStarLeaf" % side) as AnimatableBody3D
		assert(leaf.has_node("LowerEnamelKickPanel"))
		assert(leaf.has_node("LowerBrassFootRail"))
		var leaf_collision := leaf.get_node("GateLeafCollision") as CollisionShape3D
		assert(leaf_collision.position.y - (leaf_collision.shape as BoxShape3D).size.y * 0.5 >= 1.8,
			"the opening sweep must stay clear of the walkable floor")
	var perimeter := island_one_gate.get_node(
		"HeavenlyThresholdCourt/CollisionBackedGatePerimeter") as Node3D
	assert(float(perimeter.get_meta("clear_opening_width_m", 0.0)) >= 11.8)
	for side in ["West", "East"]:
		assert(perimeter.get_node("%sIvoryDefenceWallCollision" % side) is StaticBody3D)
		assert(perimeter.get_node("%sWingFoundationCollision" % side) is StaticBody3D)
		assert(perimeter.get_node("%sGateTowerConnectorWallCollision" % side) is StaticBody3D)
		assert(perimeter.get_node("%sGateTowerConnectorFoundationCollision" % side) is StaticBody3D)
		assert(perimeter.get_node("%sConnectedBoundaryOuterWallCollision" % side) is StaticBody3D)
		assert(perimeter.get_node_or_null("%sBoundaryReturnWallCollision" % side) == null)
	assert(bool(perimeter.get_meta("covers_gate_flanks", false)))
	assert(bool(perimeter.get_meta("continuous_ground_to_coping", false)))
	assert(bool(perimeter.get_meta("full_frontage_enclosure", false)))
	assert(bool(perimeter.get_meta("side_passages_removed", false)))
	assert(bool(perimeter.get_meta("connected_to_both_gate_towers", false)))
	assert(bool(perimeter.get_meta("height_matches_gate_tower_capitals", false)))
	assert(bool(perimeter.get_meta("styled_to_match_gate_barrier", false)))
	assert(str(perimeter.get_meta("wall_visual_family", "")) == "island_one_two_civic_railing")
	assert(perimeter.has_node("WestBoundaryScrollwork_01BrassMedallion"))
	assert(perimeter.has_node("EastBoundaryPier_01WarmLantern"))
	assert(not (perimeter.get_node("EastBoundaryPier_01WarmLantern") as Node3D).visible,
		"the lantern with a hidden shaft must not float beside the gate pier")
	assert(bool(perimeter.get_meta("outer_end_returns_removed", false)))
	assert(float(perimeter.get_meta("wall_coping_height_m", 0.0)) >= 13.7)
	assert(float(perimeter.get_meta("connected_boundary_span_m", 0.0)) >= 132.0)

	var geometry := world.get_node("WorldOneGeometry") as Node3D
	assert(int(world.get_meta("standardized_heavenly_star_gate_count", 0)) == 2)
	for gate_number in [2, 3]:
		var gate := geometry.get_node(
			"SavedQuestProgressionGates/QuestGate_%d" % gate_number) as AnimatableBody3D
		assert(str(gate.get_meta("gate_visual_family", "")) == "heavenly_star_gate")
		var facade := gate.get_node("HeavenlyStarGateFamilyFacade") as Node3D
		assert(str(facade.get_meta("source_gate", "")) == "IslandOneHeavenlyStarGate")
		assert(float(facade.get_meta("clear_opening_width_m", 0.0)) >= 16.0)
		assert(is_equal_approx(float(facade.get_meta("arch_half_span_m", 0.0)), 9.2))
		assert(facade.has_node("HeavenlyStarKeystone"))
		for segment in 14:
			assert(facade.has_node("GiltCrownReveal_%02d" % (segment + 1)),
				"the gold arch reveal must meet continuously above both leaves")
		assert(facade.has_node("WestHeavenlyPlinth"))
		assert(facade.has_node("EastHeavenlyPlinth"))
		assert(facade.has_node("SharedHeavenlyStarHalo/AstrolabeEmeraldWisdomCrystal"))
		var shared_leaves := facade.get_node("SharedHeavenlyGateLeaves") as Node3D
		assert(shared_leaves.get_node("WestCelestialLeaf/LeafCollision") is CollisionShape3D)
		assert(shared_leaves.get_node("EastCelestialLeaf/LeafCollision") is CollisionShape3D)
		for side in ["West", "East"]:
			var leaf := shared_leaves.get_node("%sCelestialLeaf" % side) as AnimatableBody3D
			var infill := shared_leaves.get_node(
				"%sCelestialLeaf/ArchedEnamelInfill" % side) as MeshInstance3D
			assert(infill.mesh.get_aabb().end.y > 19.5,
				"the enamel leaf must meet its arched frame instead of ending flat")
			assert(infill.mesh.get_aabb().position.y <= 2.91,
				"the enamel backing must meet the ivory threshold")
			assert(is_equal_approx(infill.mesh.get_aabb().size.x, 9.2),
				"each enamel leaf must fill half the framed opening")
			var outer_top := -INF
			var vertices := infill.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for vertex in vertices:
				if absf(vertex.x) < 0.01:
					outer_top = maxf(outer_top, vertex.y)
			assert(absf(outer_top - (13.35 - 0.55 - 0.16)) < 0.02,
				"the outer enamel edge must follow the frame at its spring")
			for segment in 14:
				assert(leaf.has_node("FittedGiltCrown_%02d" % (segment + 1)),
					"the leaf's gold reveal must follow the full ivory frame")
			var lower_panel := leaf.get_node("ThresholdIvoryInfill") as MeshInstance3D
			assert(leaf.has_node("RearThresholdIvoryInfill")
				and leaf.has_node("RearThresholdGiltRail"),
				"both approaches must see a finished threshold")
			var sill := facade.get_node("HeavenlyThresholdSill") as Node3D
			assert(lower_panel.position.y + lower_panel.mesh.get_aabb().position.y <= sill.position.y + 0.25,
				"the shared leaf must meet the threshold instead of floating above it")
			var leaf_collision := leaf.get_node("LeafCollision") as CollisionShape3D
			assert(leaf_collision.position.y - (leaf_collision.shape as BoxShape3D).size.y * 0.5 <= 0.55,
				"the closed gate must block its opening down to the sill")
			assert(leaf.has_node("RearAstrolabeMedallion") and leaf.has_node("RearGiltCrown_10"),
				"both approaches need filigree that follows the fitted gate frame")
		var crown := facade.get_node("HeavenlyCrownArchitecture") as Node3D
		assert((crown.get_node("WestIvoryCrownSweepLower") as Node3D).position.y < 19.0,
			"the shared crown must descend to the shorter tower capital")
		assert(is_equal_approx(absf((shared_leaves.get_node("WestCelestialLeaf") as Node3D).position.x), 9.2),
			"the shared golden leaves must meet their wider tower frame")
		assert(str(gate.get_meta("custom_gate_motion", "")) == "heavenly_star_hinges")

	var island_two_gate := geometry.get_node(
		"SavedQuestProgressionGates/QuestGate_2") as AnimatableBody3D
	var island_two_walls := island_two_gate.get_node(
		"HeavenlyStarGateFamilyFacade/SharedStyledSideWalls") as Node3D
	assert(bool(island_two_walls.get_meta("connected_to_gate_towers", false)))
	assert(float(island_two_walls.get_meta("wall_coping_height_m", 0.0)) >= 13.7)
	assert(island_two_walls.get_node("WestStyledWallMassCollision") is StaticBody3D)
	assert(island_two_walls.get_node("EastStyledWallMassCollision") is StaticBody3D)
	assert(island_two_walls.has_node("WestGateTwoScrollwork_01BrassMedallion"))
	assert(island_two_walls.has_node("EastGateTwoWallPier_01WarmLantern"))
	assert(bool(island_two_walls.get_meta("solid_outer_end_returns_removed", false)))
	assert(not (island_two_gate.get_node("IslandTwoMemoryGate") as Node3D).visible)
	var island_three_gate := geometry.get_node(
		"SavedQuestProgressionGates/QuestGate_4") as AnimatableBody3D
	assert(bool(island_three_gate.get_meta("physical_barrier_removed", false)))
	assert((island_three_gate.get_node("CollisionShape3D") as CollisionShape3D).disabled)
	assert(not island_three_gate.visible)
	assert(not island_three_gate.has_node("HeavenlyStarGateFamilyFacade"))
	assert(not island_three_gate.has_node("IslandGateControl_4"))
	assert(int(world.get_meta("nearby_q_gate_control_count", 0)) == 3)
	var button := island_two_gate.get_node("IslandGateControl_2") as Node3D
	assert(str(button.get_meta("interaction_key", "")) == "Q")
	world.set_quest_gate_open(1, true)
	assert(world.operate_gate_button_for_test(button))
	assert(not world.is_quest_gate_open(1))
	player.global_position = button.global_position
	var q_event := InputEventKey.new()
	q_event.keycode = KEY_Q
	q_event.pressed = true
	world._unhandled_input(q_event)
	assert(world.is_quest_gate_open(1))

	print("WorldOneHeavenlyGateFamily: PASS — complete Island One wall, matching Island Two gates, open Island Three route and nearby Q controls")
	world.queue_free()
	player.queue_free()
	await process_frame
	quit()
