extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://scenes/mind_spark/mind_spark_world_one.tscn") as PackedScene).instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://test_mind_spark_texture_v12.json"
	root.add_child(world)
	for _frame in 4:
		await process_frame
	var geometry := world.get_node("WorldOneGeometry") as Node3D
	var foundation_count := 0
	var detailed_surface_count := 0
	for zone_id in world.get_zone_ids():
		var zone := geometry.get_node(zone_id.to_pascal_case()) as Node3D
		var foundation := zone.get_node_or_null("ModularFloatingFoundation") as Node3D
		var expected_revision := "v12" if zone_id == "02_living_network_forest" else "v11"
		if zone_id == "03_constellation_court":
			expected_revision = "v16"
		elif zone_id == "04_hope_path_ridge":
			expected_revision = "v17"
		if foundation == null or foundation.get_meta("source_revision", "") != expected_revision:
			_fail("%s has no reference-style %s celestial land" % [zone_id, expected_revision])
			return
		foundation_count += 1
		var meshes := foundation.find_children("*", "MeshInstance3D", true, false)
		var expected_meshes := 14 if zone_id == "03_constellation_court" else (10 if zone_id == "04_hope_path_ridge" else 6)
		if meshes.size() != expected_meshes:
			_fail("%s has an incorrect static / moving assembly count" % zone_id)
			return
		detailed_surface_count += meshes.size()
		var variant_index := int(foundation.get_meta("variant_index", 0))
		var family_revision := "v17" if zone_id == "04_hope_path_ridge" else "v11"
		for family in ["CelestialIvoryDeck", "Rock_%s_%02d" % [family_revision, variant_index],
				"Architecture_%s_%02d" % [family_revision, variant_index], "Machinery_%s_%02d" % [family_revision, variant_index],
				"Inlay_%s_%02d" % [family_revision, variant_index], "Railing_%s_%02d" % [family_revision, variant_index]]:
			var visual := foundation.find_child(family, true, false) as MeshInstance3D
			if visual == null or visual.mesh == null or visual.mesh.get_surface_count() == 0:
				_fail("%s is missing actual geometry for %s" % [zone_id, family])
				return
		if foundation.find_children("*", "CollisionObject3D", true, false).size() != 0:
			_fail("celestial visual shell must not introduce route obstacles")
			return
	var sanctuary := geometry.get_node("06OldestTreeSanctuary") as Node3D
	var retired_shell := sanctuary.get_node_or_null("MindSparkBioDataTree") as Node3D
	if retired_shell == null or not retired_shell.get_meta("production_compatibility_shell", false) \
			or not retired_shell.find_children("*", "MeshInstance3D", true, false).is_empty():
		_fail("production sanctuary still constructs the retired Bio-Data Tree")
		return
	# Exercise the retained historical art generator as an isolated fixture;
	# the shipped fused island uses OldestTreeLivingCathedral instead.
	var legacy_fixture := Node3D.new()
	legacy_fixture.name = "BioDataTreeTextureFixture"
	world.add_child(legacy_fixture)
	world.call("_build_bio_data_tree", legacy_fixture, Vector3.ZERO, 1.0, 6)
	var bio_tree := legacy_fixture.get_node("MindSparkBioDataTree") as Node3D
	var base_socket := bio_tree.find_child("BioTreeBaseSocketAssembly", true, false) as Node3D
	if base_socket == null \
			or base_socket.find_children("BioBaseArmorSector_*", "MeshInstance3D", true, false).size() != 12 \
			or base_socket.find_children("BioBaseShoulderPlate_*", "MeshInstance3D", true, false).size() != 12:
		_fail("Bio-Data Tree base socket has no complete twelve-sector armor assembly")
		return
	if base_socket.find_children("BioBaseGoldCollarSegment_*", "MeshInstance3D", true, false).size() != 12 \
			or base_socket.find_children("BioBaseArmorMicroCell_*", "MeshInstance3D", true, false).size() != 48 \
			or base_socket.find_children("BioBaseShoulderCircuitCell_*", "MeshInstance3D", true, false).size() != 36:
		_fail("Bio-Data Tree base socket is missing its nested Lego-like micro assemblies")
		return
	if base_socket.find_children("BioBaseServiceCell_*", "MeshInstance3D", true, false).size() != 12 \
			or base_socket.find_children("BioBaseStatusWindow_*", "MeshInstance3D", true, false).size() != 12 \
			or base_socket.find_children("BioBaseFlowFeed_*", "MeshInstance3D", true, false).size() != 12:
		_fail("Bio-Data Tree base socket has incomplete service and energy transfer components")
		return
	if base_socket.find_children("BioBaseTrunkLock_*", "MeshInstance3D", true, false).size() != 6 \
			or base_socket.find_children("BioBaseTrunkLockInlay_*", "MeshInstance3D", true, false).size() != 6:
		_fail("Bio-Data Tree base socket has no complete six-brace trunk lock")
		return
	var editable_socket_pieces := 0
	for socket_piece in base_socket.find_children("*", "MeshInstance3D", true, false):
		if bool(socket_piece.get_meta("editable_component", false)):
			editable_socket_pieces += 1
	if editable_socket_pieces < 280:
		_fail("Bio-Data Tree base socket has fewer than 280 editable construction pieces")
		return
	var trunk_envelope := float(base_socket.get_meta("trunk_outer_envelope_radius", 0.0))
	var collar_inner := float(base_socket.get_meta("gold_collar_inner_radius", 0.0))
	var collar_clearance := collar_inner - trunk_envelope
	if collar_clearance < 0.25 or collar_clearance > 0.50 \
			or not is_equal_approx(collar_clearance,
				float(base_socket.get_meta("minimum_collar_clearance", -1.0))):
		_fail("Bio-Data Tree collar is not sized to a safe close fit around the trunk")
		return
	for flow_feed in base_socket.find_children("BioBaseFlowFeed_*", "MeshInstance3D", true, false):
		var feed_finish: Vector3 = flow_feed.get_meta("path_end", Vector3.ZERO)
		if not bool(flow_feed.get_meta("collar_safe_route", false)) \
				or Vector2(feed_finish.x, feed_finish.z).length() < 7.10 \
				or feed_finish.y >= 3.50:
			_fail("Bio-Data Tree socket feed crosses or penetrates the gold collar")
			return
	if bio_tree.find_children("BioTrunkBarkCable*", "MeshInstance3D", true, false).size() < 192:
		_fail("Bio-Data Tree trunk is not assembled from enough small bark components")
		return
	if bio_tree.find_children("BioLivingCoreSlice_*", "MeshInstance3D", true, false).size() != 24:
		_fail("Bio-Data Tree has no complete curved modular living core")
		return
	if bio_tree.find_children("BioNutrientChannelCutaway*", "MeshInstance3D", true, false).size() != 24:
		_fail("Bio-Data Tree has no recessed nutrient channel cutaway")
		return
	if bio_tree.find_children("BioDataChannelCutaway*", "MeshInstance3D", true, false).size() != 24:
		_fail("Bio-Data Tree has no recessed data channel cutaway")
		return
	if bio_tree.find_children("BioNutrientFiber*", "MeshInstance3D", true, false).size() != 24:
		_fail("Bio-Data Tree has no complete green nutrient fibre")
		return
	if bio_tree.find_children("BioDataFiber*", "MeshInstance3D", true, false).size() != 24:
		_fail("Bio-Data Tree has no complete cyan data fibre")
		return
	if bio_tree.find_children("BioMagicFiber*", "MeshInstance3D", true, false).size() != 24 \
			or bio_tree.find_children("BioMagicRuneCell*", "MeshInstance3D", true, false).size() != 24:
		_fail("Bio-Data Tree has no complete fine violet magic fibre")
		return
	for fibre_pattern in ["BioNutrientFiber*", "BioDataFiber*", "BioMagicFiber*"]:
		for fibre in bio_tree.find_children(fibre_pattern, "MeshInstance3D", true, false):
			var fibre_mesh := (fibre as MeshInstance3D).mesh as CylinderMesh
			var maximum_allowed := 0.18 if fibre_pattern == "BioNutrientFiber*" else \
				(0.16 if fibre_pattern == "BioDataFiber*" else 0.11)
			if fibre_mesh == null or maxf(fibre_mesh.bottom_radius,
					fibre_mesh.top_radius) > maximum_allowed + 0.001:
				_fail("Bio-Data Tree transport fibre is thicker than its audited limit")
				return
	if bio_tree.find_children("BioBarkGrain*", "MeshInstance3D", true, false).size() != 144:
		_fail("Bio-Data Tree is missing its fine editable wood-grain ridges")
		return
	if bio_tree.find_children("BioBarkKnot*", "MeshInstance3D", true, false).size() != 18:
		_fail("Bio-Data Tree is missing its irregular bark knots")
		return
	if bio_tree.find_children("BioNutrientPulseCell*", "MeshInstance3D", true, false).size() != 24 \
			or bio_tree.find_children("BioDataPulseCell*", "MeshInstance3D", true, false).size() != 24:
		_fail("Bio-Data Tree fibre cutaway has incomplete illuminated packet cells")
		return
	if bio_tree.find_children("BioLeafPanel*", "MeshInstance3D", true, false).size() != 48:
		_fail("Bio-Data Tree must have eight six-cell editable leaf-petal modules")
		return
	if bio_tree.find_children("BioBranchLeaf_*_Cell_*", "MeshInstance3D", true, false).size() != 96:
		_fail("Bio-Data Tree crown must have sixteen six-cell branch leaves")
		return
	if bio_tree.find_children("BioCanopyBranch_??_??", "MeshInstance3D", true, false).size() != 80 \
			or bio_tree.find_children("BioCanopyBranchFiber*", "MeshInstance3D", true, false).size() != 80:
		_fail("Bio-Data Tree crown must have eight ten-segment energized branches")
		return
	if bio_tree.find_children("BioCanopyBranchGrain*", "MeshInstance3D", true, false).size() != 80 \
			or bio_tree.find_children("BioCanopyBranchNutrient*", "MeshInstance3D", true, false).size() != 80:
		_fail("Bio-Data Tree natural branches are missing attached bark and nutrient detail")
		return
	for branch_index in 8:
		var previous_finish := Vector3.ZERO
		for segment_index in 10:
			var branch_name := "BioCanopyBranch_%02d_%02d" % [branch_index + 1, segment_index + 1]
			var branch_piece := bio_tree.find_child(branch_name, true, false) as MeshInstance3D
			var branch_mesh := branch_piece.mesh as CylinderMesh
			var branch_start: Vector3 = branch_piece.get_meta("path_start", Vector3.ZERO)
			var branch_finish: Vector3 = branch_piece.get_meta("path_end", Vector3.ZERO)
			if branch_mesh == null or branch_mesh.radial_segments < 14:
				_fail("Bio-Data Tree branch is not rendered with the audited smooth profile")
				return
			if segment_index > 0 and not branch_start.is_equal_approx(previous_finish):
				_fail("Bio-Data Tree natural branch contains a floating segment gap")
				return
			previous_finish = branch_finish
		var stem := bio_tree.find_child("MushroomStemSocket_%02d" % (branch_index + 1),
			true, false) as MeshInstance3D
		var stem_start: Vector3 = stem.get_meta("path_start", Vector3.ZERO)
		if not previous_finish.is_equal_approx(stem_start):
			_fail("Bio-Data Tree branch does not terminate inside its mushroom socket")
			return
	var mushroom_caps := bio_tree.find_children("BioMushroomCap*", "MeshInstance3D", true, false)
	if mushroom_caps.size() != 9:
		_fail("Bio-Data Tree must have nine layered mushroom caps")
		return
	for mushroom_cap in mushroom_caps:
		if mushroom_cap.get_meta("mushroom_cap_form", "") != "full_biconvex_bubble" \
				or not is_equal_approx(float(mushroom_cap.get_meta("upper_curve", 0.0)),
					float(mushroom_cap.get_meta("lower_curve", -1.0))):
			_fail("Bio-Data Tree mushroom cap is not equally curved above and below")
			return
		if not bool(mushroom_cap.get_meta("seamless_shell", false)):
			_fail("Bio-Data Tree mushroom cap panels must close without gaps")
			return
		var cap_center_y := float(mushroom_cap.get_meta("cap_center_y", 0.0))
		var cap_half_height := float(mushroom_cap.get_meta("cap_half_height", 0.0))
		if cap_center_y - cap_half_height < 68.5 \
				and cap_center_y + cap_half_height > 65.5:
			_fail("Bio-Data Tree mushroom cap overlaps the leaf-petal clearance zone")
			return
	for first_index in mushroom_caps.size():
		var first_cap := mushroom_caps[first_index]
		var first_center: Vector3 = first_cap.get_meta("cap_center", Vector3.ZERO)
		var first_radius := float(first_cap.get_meta("cap_radius", 0.0))
		var first_height := float(first_cap.get_meta("cap_half_height", 0.0))
		for second_index in range(first_index + 1, mushroom_caps.size()):
			var second_cap := mushroom_caps[second_index]
			var second_center: Vector3 = second_cap.get_meta("cap_center", Vector3.ZERO)
			var second_radius := float(second_cap.get_meta("cap_radius", 0.0))
			var second_height := float(second_cap.get_meta("cap_half_height", 0.0))
			var horizontal_gap := Vector2(first_center.x - second_center.x,
				first_center.z - second_center.z).length()
			if absf(first_center.y - second_center.y) < first_height + second_height \
					and horizontal_gap < (first_radius + second_radius) * 0.82:
				_fail("Bio-Data Tree mushroom caps overlap instead of forming organized tiers")
				return
	if bio_tree.find_children("MushroomFacet*", "MeshInstance3D", true, false).size() != 3447:
		_fail("Bio-Data Tree biconvex caps are missing their editable upper shell cells")
		return
	if bio_tree.find_children("MushroomCloudLobe*", "MeshInstance3D", true, false).size() != 0 \
			or bio_tree.find_children("MushroomCloudlet*", "MeshInstance3D", true, false).size() != 0:
		_fail("Bio-Data Tree mushroom cap still contains the superseded cloud cluster")
		return
	if bio_tree.find_children("MushroomGlowStone*", "MeshInstance3D", true, false).size() != 144:
		_fail("Bio-Data Tree mushroom caps are missing their raised shell glow stones")
		return
	if bio_tree.find_children("MushroomEquatorSeal*", "MeshInstance3D", true, false).size() != 216:
		_fail("Bio-Data Tree mushroom caps are missing their modeled equator seals")
		return
	if bio_tree.find_children("MushroomLeafVein*", "MeshInstance3D", true, false).size() != 222:
		_fail("Bio-Data Tree mushroom caps are missing their mirrored leaf veins")
		return
	if bio_tree.find_children("BioHangingNode*", "MeshInstance3D", true, false).size() != 8:
		_fail("Bio-Data Tree must have eight hanging energy nodes")
		return
	if bio_tree.find_children("HangingFilament*", "MeshInstance3D", true, false).size() != 64:
		_fail("Bio-Data Tree hanging nodes are missing segmented fibre filaments")
		return
	if bio_tree.find_children("HangingNodeHalo*", "MeshInstance3D", true, false).size() != 8:
		_fail("Bio-Data Tree hanging nodes are missing their surrounding energy halos")
		return
	for node in bio_tree.find_children("BioHangingNode*", "MeshInstance3D", true, false):
		var node_center: Vector3 = node.get_meta("node_center", Vector3.ZERO)
		var node_radius := float(node.get_meta("node_radius", 0.0))
		for mushroom_cap in mushroom_caps:
			var cap_center: Vector3 = mushroom_cap.get_meta("cap_center", Vector3.ZERO)
			var cap_radius := float(mushroom_cap.get_meta("cap_radius", 0.0))
			var cap_half_height := float(mushroom_cap.get_meta("cap_half_height", 0.0))
			var horizontal_distance := Vector2(node_center.x - cap_center.x,
				node_center.z - cap_center.z).length()
			if absf(node_center.y - cap_center.y) < cap_half_height + node_radius \
					and horizontal_distance < cap_radius + node_radius + 0.8:
				_fail("Bio-Data Tree hanging node overlaps a mushroom cap")
				return
	if bio_tree.find_children("BioCrownCrystal", "MeshInstance3D", true, false).size() != 1:
		_fail("Bio-Data Tree has no crown crystal")
		return
	var crown_crystal := bio_tree.find_child("BioCrownCrystal", true, false) as MeshInstance3D
	if crown_crystal.get_meta("crystal_form", "") != "sharp_double_point_faceted" \
			or int(crown_crystal.get_meta("facet_sides", 0)) != 6:
		_fail("Bio-Data Tree crown crystal is not the sharp six-sided design")
		return
	if bio_tree.find_children("CrownCrystalOutlineUpper*", "MeshInstance3D", true, false).size() != 6 \
			or bio_tree.find_children("CrownCrystalOutlineLower*", "MeshInstance3D", true, false).size() != 6 \
			or bio_tree.find_children("CrownCrystalOutlineGirdle*", "MeshInstance3D", true, false).size() != 6:
		_fail("Bio-Data Tree crown crystal has no complete physical outline")
		return
	if bio_tree.find_children("CrownCrystalInnerSpine", "MeshInstance3D", true, false).size() != 1:
		_fail("Bio-Data Tree crown crystal has no visible internal energy spine")
		return
	var tree_packets := bio_tree.find_children("BioNutrientPacket*", "MeshInstance3D", true, false)
	if tree_packets.size() != 24:
		_fail("Bio-Data Tree has no complete animated nutrient packet chain")
		return
	var tree_packet := tree_packets[0] as Node3D
	var tree_packet_start := tree_packet.position
	for _frame in 20:
		await process_frame
	if tree_packet.position.distance_to(tree_packet_start) < 0.1:
		_fail("Bio-Data Tree nutrient packet did not move upward through the trunk")
		return
	if detailed_surface_count != 48:
		_fail("expected thirty-six static land meshes plus eight moving assemblies, got %d" % detailed_surface_count)
		return
	print("MIND_SPARK_ISLAND_GEOMETRY_DETAIL: PASS — %d celestial foundations, %d batched land meshes; existing Bio-Data Tree detail and animation preserved" % [foundation_count, detailed_surface_count])
	quit()


func _fail(message: String) -> void:
	push_error("MIND_SPARK_ISLAND_GEOMETRY_DETAIL: %s" % message)
	quit(1)
