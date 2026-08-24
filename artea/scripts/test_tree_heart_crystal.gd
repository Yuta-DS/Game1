extends SceneTree

## Focused, low-cost proof for the Tree of Life heart and semantic canopy pass.

const WorldScript := preload("res://scripts/art_castle_floating_world.gd")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("TREE_HEART_CRYSTAL_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var builder := WorldScript.new()
	var tree := Node3D.new()
	tree.name = "FocusedTree"
	tree.set_meta("simple_trunk_core", true)
	root.add_child(tree)
	builder.call("_build_wisdom_heart_shrine", tree)
	builder.call("_build_reference_trunk_root_facade", tree)
	await process_frame
	await process_frame

	var shrine := tree.get_node_or_null("WisdomHeartShrine") as Node3D
	if shrine == null:
		_fail("wisdom heart shrine was not built")
		return
	if shrine.find_children("HeartAstrolabeOrbit_*", "Node3D", true, false).size() != 3 \
			or shrine.find_children("HeartFrameRune_*", "Node3D", true, false).size() != 8 \
			or shrine.find_children("HeartFrameRadialSpoke_*", "MeshInstance3D", true, false).size() != 8 \
			or shrine.find_children("HeartWoodCradleRib_*", "MeshInstance3D", true, false).size() != 6 \
			or shrine.find_children("HeartWoodGearMount_*", "MeshInstance3D", true, false).size() != 8:
		_fail("astrolabe frame hierarchy is incomplete")
		return
	var dyson := shrine.get_node_or_null("HeartDysonSphereSystem") as Node3D
	if dyson == null \
			or not bool(dyson.get_meta("runtime_system", false)) \
			or not bool(dyson.get_meta("attached_to_tree_socket", false)) \
			or int(dyson.get_meta("animated_orbital_axes", 0)) != 3 \
			or int(dyson.get_meta("orbital_energy_collectors", 0)) != 12 \
			or int(dyson.get_meta("inner_power_routes", 0)) != 12 \
			or dyson.find_children("HeartDysonOrbitCollectors_*", "MeshInstance3D", true, false).size() != 3 \
			or dyson.find_children("HeartDysonConcentricRail_*", "MeshInstance3D", true, false).size() != 2 \
			or dyson.get_node_or_null("HeartDysonInnerPowerLattice") == null:
		_fail("runtime Dyson sphere detail system is incomplete or detached")
		return
	var cradle := shrine.get_node_or_null("LivingHeartWoodCradle") as Node3D
	if cradle == null \
			or not bool(cradle.get_meta("mechanics_embedded_not_floating", false)) \
			or int(cradle.get_meta("wood_ribs", 0)) != 6 \
			or int(cradle.get_meta("gear_mounts", 0)) != 8:
		_fail("living-wood gear cradle is incomplete")
		return
	var tree_socket := shrine.get_node_or_null("HeartTreeGearSocket") as Node3D
	if tree_socket == null \
			or not bool(tree_socket.get_meta("embedded_in_living_tree", false)) \
			or str(tree_socket.get_meta("recess_fit", "")) \
				!= "concentric_tree_socket_to_gear_rim" \
			or int(tree_socket.get_meta("wood_anchor_count", 0)) != 8 \
			or int(tree_socket.get_meta("brass_clamp_count", 0)) != 8 \
			or int(tree_socket.get_meta("brass_bolt_count", 0)) != 16 \
			or tree_socket.get_node_or_null("HeartTreeSocketLiner") == null \
			or tree_socket.get_node_or_null("HeartTreeSocketAnchorBundle") == null \
			or tree_socket.get_node_or_null("HeartTreeSocketClampBatch") == null \
			or tree_socket.get_node_or_null("HeartTreeSocketBoltBatch") == null:
		_fail("heart gear is not fitted into its tree socket and clamp system")
		return
	var spin := shrine.get_node_or_null("HeartCrystalSpin") as Node3D
	if spin == null or spin.get_node_or_null("HeartShrineCrystal") == null \
			or spin.get_node_or_null("HeartShrineCrystalCore") == null:
		_fail("faceted diamond or its inner light core is missing")
		return
	var heart_material := (spin.get_node("HeartShrineCrystal") as MeshInstance3D) \
		.material_override as StandardMaterial3D
	if heart_material == null or heart_material.albedo_color.b <= 0.9 \
			or heart_material.albedo_color.b <= heart_material.albedo_color.g:
		_fail("heart diamond is not the approved saturated blue")
		return
	var crystal_cage := shrine.get_node_or_null("HeartCrystalOrganizedCage") as MeshInstance3D
	if crystal_cage == null \
			or str(crystal_cage.get_meta("construction", "")) \
				!= "four_symmetric_prongs_seat_blue_crystal":
		_fail("blue heart crystal is not organized inside its four-prong frame")
		return
	var facade := tree.get_node_or_null("ReferenceTrunkRootFacade") as Node3D
	var root_energy_bundle := tree.get_node_or_null(
		"ReferenceTrunkRootFacade/ReferenceRootEmbeddedEnergyFiberBundle") as MeshInstance3D
	if facade == null \
			or facade.find_children("ReferenceBraidedTrunkRib_*", "MeshInstance3D", true, false).size() != 4 \
			or facade.find_children("ReferenceRootFlare_*", "MeshInstance3D", true, false).size() != 8 \
			or facade.find_children("ReferenceBronzeTrunkBand_*", "MeshInstance3D", true, false).size() != 6 \
			or not bool(facade.get_meta("player_passage_preserved", false)) \
			or root_energy_bundle == null \
			or int(root_energy_bundle.get_meta("strand_count", 0)) != 16 \
			or not bool(root_energy_bundle.get_meta("embedded_not_floating", false)) \
			or float(root_energy_bundle.get_meta("maximum_surface_gap_m", 1.0)) > 0.22:
		_fail("reference trunk/root facade is incomplete")
		return
	await create_timer(0.08).timeout
	if is_zero_approx(spin.rotation.y):
		_fail("heart diamond did not rotate around itself")
		return

	var canopy := Node3D.new()
	root.add_child(canopy)
	var transforms: Array[Transform3D] = [
		Transform3D(Basis.IDENTITY, Vector3.ZERO),
		Transform3D(Basis(Vector3.UP, 0.7), Vector3(8.0, 4.0, 2.0)),
	]
	builder.call("_build_gold_branch_collars", canopy, transforms)
	var collars := canopy.get_node_or_null("PoweredBranchGoldCollarBatch") \
		as MultiMeshInstance3D
	if collars == null or collars.multimesh.instance_count != transforms.size():
		_fail("gold mechanical branch collars are missing")
		return

	var expected := {
		"living_leaf_fan": Color("2cae64"),
		"magic_rune_leaf": Color("a45cff"),
		"solar_glass_science_leaf": Color("24bfff"),
		"emerald_sensor_leaf": Color("62e68f"),
	}
	for family in expected:
		var material := builder.call("_leaf_family_material", family) as StandardMaterial3D
		if material == null or not material.albedo_color.is_equal_approx(expected[family]):
			_fail("%s does not match its semantic leaf colour" % family)
			return

	print("TREE_HEART_CRYSTAL_TEST: PASS — blue rotating heart, fitted tree socket, detailed three-axis Dyson sphere, eight wood anchors and cyan sap")
	quit()
