extends SceneTree

## Asset and gameplay regression for the central Tree of Imagination.
## The Blender source remains richly editable while Godot renders eight joined
## systems and collides only with authored trunk/root proxy shapes.

const WorldScene := preload("res://scenes/art_castle_floating_world.tscn")
const MANIFEST_PATH := "res://assets3D/tree_of_life/tree_of_life_manifest.json"
const WALK_SPEED := 8.0
const MAX_WALK_FRAMES := 2200
const STALL_FRAMES := 90


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("TREE_OF_LIFE_ASSET_TEST: %s" % message)
	quit(1)


func _collider_labels(player: CharacterBody3D) -> String:
	var labels: Array[String] = []
	for index in player.get_slide_collision_count():
		var collision := player.get_slide_collision(index)
		var collider := collision.get_collider()
		if collider is Node:
			labels.append("%s normal=%s" % [(collider as Node).get_path(), collision.get_normal()])
	return "; ".join(labels)


func _settle(player: CharacterBody3D, position: Vector3) -> bool:
	player.global_position = position
	player.velocity = Vector3.ZERO
	for _frame in 240:
		player.velocity.y -= 28.0 / 60.0
		player.move_and_slide()
		await physics_frame
		if player.is_on_floor():
			return true
	return false


func _walk(player: CharacterBody3D, destination: Vector3) -> bool:
	var best_distance := INF
	var stalled := 0
	for _frame in MAX_WALK_FRAMES:
		var delta := destination - player.global_position
		delta.y = 0.0
		var distance := delta.length()
		if distance < 0.75:
			return true
		var was_on_floor := player.is_on_floor()
		var before := player.global_position
		player.velocity.x = delta.normalized().x * WALK_SPEED
		player.velocity.z = delta.normalized().z * WALK_SPEED
		player.velocity.y -= 28.0 / 60.0
		var intended := player.velocity
		player.move_and_slide()
		if player.has_method("_try_step_up"):
			player.call("_try_step_up", was_on_floor, before, intended, 1.0 / 60.0)
		await physics_frame
		var remaining := Vector2(
			player.global_position.x - destination.x,
			player.global_position.z - destination.z).length()
		if remaining < best_distance - 0.015:
			best_distance = remaining
			stalled = 0
		else:
			stalled += 1
		if stalled >= STALL_FRAMES:
			return false
	return false


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _max_socket_pair_gap(pairs: PackedVector3Array) -> float:
	if pairs.size() % 2 != 0:
		return INF
	var maximum := 0.0
	for pair_index in range(0, pairs.size(), 2):
		maximum = maxf(maximum, pairs[pair_index].distance_to(pairs[pair_index + 1]))
	return maximum


func _run() -> void:
	var world := WorldScene.instantiate() as Node3D
	root.add_child(world)
	# This test owns a static Tree of Life review. Unrelated Mind Spark district
	# animation must not retain stale decoration references while the player walk
	# advances hundreds of physics frames.
	for candidate in world.find_children("*", "Node", true, false):
		var candidate_script := candidate.get_script() as Script
		if candidate_script != null and candidate_script.resource_path.ends_with(
				"mind_spark_island_detail_animator.gd"):
			candidate.set_process(false)
	for _frame in 12:
		await physics_frame

	var tree := world.get_node_or_null("CentralSanctuary/TreeOfImagination") as Node3D
	if tree == null:
		_fail("central TreeOfImagination is missing")
		return
	if tree.get_meta("architecture", "") != "nature_magic_technology_engineering":
		_fail("tree architecture metadata is incomplete")
		return
	if int(tree.get_meta("source_editable_vertices", 0)) < 170000:
		_fail("tree does not expose at least 100,000 distinct editable source vertices")
		return
	if float(tree.get_meta("player_clear_path_m", 0.0)) < 9.5:
		_fail("authored player passage is narrower than 9.5 metres")
		return
	if not is_equal_approx(float(tree.get_meta("landmark_scale_multiplier", 0.0)), 2.0) \
			or tree.get_meta("entrance_world_direction", "") != "south":
		_fail("tree is not doubled or its doorway is not aligned to the southern gallery approach")
		return
	if bool(tree.get_meta("canopy_collision", true)):
		_fail("decorative canopy must remain collision-free")
		return
	var south_walkway := world.get_node_or_null("SouthArrivalBridge/Walkway") as Node3D
	if south_walkway == null \
			or not is_equal_approx(south_walkway.global_position.x, tree.global_position.x) \
			or south_walkway.global_position.z >= tree.global_position.z:
		_fail("South Arrival Bridge and root doorway do not share the gallery approach centerline")
		return
	var tree_bridge := world.get_node_or_null("SouthArrivalBridge") as Node3D
	if tree_bridge == null \
			or tree_bridge.get_meta("visual_style", "") != \
				"castle_arcane_tree_of_life_processional" \
			or tree_bridge.get_node_or_null(
				"ReferenceTreeProcessionalBridge/BlenderTreeProcessionalBridge") == null \
			or int(tree_bridge.get_meta("bough_portal_count", 0)) != 3:
		_fail("Tree of Life southern approach is not presented as the Arcane processional bridge")
		return

	var visual := tree.get_node_or_null("BlenderTreeOfLifeVisual") as Node3D
	if visual == null:
		_fail("optimized Blender visual is missing")
		return
	var game_meshes := visual.find_children("*", "MeshInstance3D", true, false)
	var original_trunks := visual.find_children("Trunk*", "MeshInstance3D", true, false)
	var original_roots := visual.find_children("Roots*", "MeshInstance3D", true, false)
	if original_trunks.size() != 1 or original_roots.size() != 1 \
			or (original_trunks[0] as MeshInstance3D).is_visible_in_tree() \
			or (original_roots[0] as MeshInstance3D).is_visible_in_tree() \
			or not bool(tree.get_meta("original_body_superseded_by_blueprint_geometry", false)):
		_fail("legacy trunk/root render systems were not cleanly superseded by the blueprint body")
		return
	var original_crystal := visual.find_children(
		"CrystalTechnology*", "MeshInstance3D", true, false)
	if original_crystal.size() != 1 \
			or (original_crystal[0] as MeshInstance3D).is_visible_in_tree():
		_fail("old joined crystal system must be hidden beneath the detailed heart shrine")
		return
	var blueprint_body := tree.get_node_or_null("BlenderBlueprintTrunkRoot") as Node3D
	var blueprint_meshes := blueprint_body.find_children(
		"*", "MeshInstance3D", true, false) if blueprint_body != null else []
	if blueprint_body == null \
			or blueprint_meshes.size() != 17 \
			or not blueprint_body.scale.is_equal_approx(Vector3.ONE * 3.875) \
			or not bool(blueprint_body.get_meta("authoritative_lower_body", false)) \
			or int(blueprint_body.get_meta("primary_roots", 0)) != 18 \
			or int(blueprint_body.get_meta("secondary_rootlets", 0)) != 54 \
			or int(blueprint_body.get_meta("laptop_runtime_triangles", 0)) != 58904 \
			or tree.get_meta("runtime_trunk_root_source", "") \
				!= "blender_blueprint_trunk_root_v3" \
			or tree.get_meta("runtime_wood_palette", "") \
				!= "deep_heartwood_warm_bark_amber_sunlit_bark_with_cyan_energy":
		_fail("detailed Blender blueprint trunk/root is not the production lower body")
		return
	var embedded_root_fibers := tree.get_node_or_null(
		"ReferenceTrunkRootFacade/ReferenceRootEmbeddedEnergyFiberBundle") as MeshInstance3D
	if embedded_root_fibers == null \
			or int(embedded_root_fibers.get_meta("strand_count", 0)) != 16 \
			or not bool(embedded_root_fibers.get_meta("embedded_not_floating", false)) \
			or float(embedded_root_fibers.get_meta("maximum_surface_gap_m", 1.0)) > 0.22:
		_fail("paired root energy fibers are missing or floating away from thick roots")
		return
	var root_gold_inlay := tree.get_node_or_null(
		"ReferenceTrunkRootFacade/ReferenceRootGoldSlashInlayBundle") as MeshInstance3D
	if root_gold_inlay == null \
			or int(root_gold_inlay.get_meta("slash_paths", 0)) != 8 \
			or not bool(root_gold_inlay.get_meta("pinned_beside_cyan_energy", false)):
		_fail("antique-gold root slash inlays are missing or detached")
		return
	var trunk_gold_inlay := tree.get_node_or_null(
		"ReferenceTrunkRootFacade/ReferenceTrunkGoldSlashInlayBundle") as MeshInstance3D
	if trunk_gold_inlay == null \
			or int(trunk_gold_inlay.get_meta("inlay_paths", 0)) != 4 \
			or not bool(trunk_gold_inlay.get_meta("pinned_to_trunk_ribs", false)):
		_fail("braided antique-gold trunk inlays are missing or detached")
		return
	if str(tree.get_meta("runtime_tree_source", "")) != "original_artea_tree_of_life_v3" \
			or not bool(tree.get_meta("original_big_root_system", false)) \
			or not bool(tree.get_meta("original_braided_trunk_system", false)) \
			or not bool(tree.get_meta("new_style_applied_to_original_mesh", false)) \
			or int(tree.get_meta("original_root_modules", 0)) != 144 \
			or int(tree.get_meta("original_trunk_modules", 0)) != 122:
		_fail("original-tree architecture ownership metadata is incomplete")
		return
	for styled_body in [original_trunks[0], original_roots[0]]:
		var body_mesh := styled_body as MeshInstance3D
		var pale_wood := body_mesh.get_surface_override_material(0) as StandardMaterial3D
		if pale_wood == null or pale_wood.albedo_color.r <= pale_wood.albedo_color.b:
			_fail("original trunk/root mesh did not receive the redesigned living-wood palette")
			return
	var energy_veins := tree.get_node_or_null("TrunkEnergyVeins") as Node3D
	var vein_batches := energy_veins.find_children(
		"TrunkVeinBatch", "MeshInstance3D", true, false) if energy_veins != null else []
	if vein_batches.size() != 1 \
			or int(vein_batches[0].get_meta("veins", 0)) != 18 \
			or int(vein_batches[0].get_meta("segments_per_vein", 0)) != 64 \
			or not bool(vein_batches[0].get_meta("joined_for_laptop_budget", false)) \
			or vein_batches[0].get_meta("flow_extent", "") != "buttress_merge_to_crown" \
			or not bool(vein_batches[0].get_meta("pinned_to_bark", false)):
		_fail("original trunk is missing its bark-following cyan energy-vein treatment")
		return
	var original_branches := visual.find_children("Branches*", "MeshInstance3D", true, false)
	var brass_engineering := visual.find_children(
		"BrassEngineering*", "MeshInstance3D", true, false)
	if original_branches.size() != 1 or brass_engineering.size() != 1 \
			or (original_branches[0] as MeshInstance3D).is_visible_in_tree() \
			or (brass_engineering[0] as MeshInstance3D).is_visible_in_tree():
		_fail("old joined branches or brass fittings remain visible beneath the gravity-bough canopy")
		return
	for pattern in ["FoliageMagic*", "FoliageNature*", "FoliageSolarGlass*"]:
		var foliage := visual.find_children(pattern, "MeshInstance3D", true, false)
		if foliage.size() != 1 or (foliage[0] as MeshInstance3D).is_visible_in_tree():
			_fail("old joined foliage remains visible beneath the laptop gravity-bough canopy")
			return
	if tree.get_node_or_null("ReferenceFaithfulCrystalCanopy") != null \
			or tree.get_node_or_null("PoweredLivingBoughCanopy") != null:
		_fail("older replacement canopy systems are still instantiated")
		return
	var christmas_melody := tree.get_node_or_null(
		"ChristmasTreeMelody3D") as AudioStreamPlayer3D
	var christmas_bells := tree.get_node_or_null(
		"ChristmasTreeBells3D") as AudioStreamPlayer3D
	if christmas_melody == null or christmas_bells == null \
			or not christmas_melody.playing or not christmas_bells.playing \
			or not christmas_melody.stream is AudioStreamWAV \
			or (christmas_melody.stream as AudioStreamWAV).loop_mode \
				!= AudioStreamWAV.LOOP_FORWARD \
			or christmas_melody.attenuation_model \
				!= AudioStreamPlayer3D.ATTENUATION_DISABLED \
			or christmas_melody.max_distance != 0.0 \
			or not bool(tree.get_meta("christmas_ambience", false)) \
			or int(tree.get_meta("christmas_ambience_layers", 0)) != 2 \
			or tree.get_meta("christmas_arrangement", "") \
				!= "purpose_built_festive_bell_orchestra" \
			or not is_equal_approx(float(tree.get_meta(
				"christmas_arrangement_seconds", 0.0)), 32.0) \
			or not is_equal_approx(float(tree.get_meta(
				"christmas_full_volume_distance", 0.0)), 70.0) \
			or not is_equal_approx(float(tree.get_meta(
				"christmas_silent_distance", 0.0)), 620.0) \
			or not bool(tree.get_meta("christmas_fade_uses_player_distance", false)) \
			or not bool(tree.get_meta("christmas_fade_out_is_gradual", false)) \
			or float(tree.get_meta("christmas_fade_out_speed", 1.0)) > 0.28:
		_fail("Tree of Life Christmas ambience is missing its gradual distance fade")
		return
	var audio_test_player := world.get_node_or_null("Player3D") as CharacterBody3D
	if audio_test_player == null:
		_fail("production player is unavailable for the Christmas distance-fade audit")
		return
	var audio_test_origin := audio_test_player.global_position
	audio_test_player.global_position = christmas_melody.global_position + Vector3(5.0, 0.0, 0.0)
	world.call("_update_tree_christmas_ambience", 4.0)
	if christmas_melody.volume_db < -6.0:
		_fail("Christmas ambience does not become loud when the player approaches")
		return
	var near_volume := christmas_melody.volume_db
	audio_test_player.global_position = christmas_melody.global_position + Vector3(800.0, 0.0, 0.0)
	world.call("_update_tree_christmas_ambience", 0.1)
	if christmas_melody.volume_db <= near_volume - 4.0:
		_fail("Christmas ambience disappears too quickly when the player walks away")
		return
	world.call("_update_tree_christmas_ambience", 40.0)
	if christmas_melody.volume_db > -75.0:
		_fail("Christmas ambience does not eventually fade to silence at long range")
		return
	audio_test_player.global_position = audio_test_origin
	var canopy := tree.get_node_or_null("LaptopGravityBoughCanopy") as Node3D
	if canopy == null \
			or int(canopy.get_meta("tier_count", 0)) != 9 \
			or int(canopy.get_meta("major_boughs", 0)) != 195 \
			or int(canopy.get_meta("child_boughs", 0)) != 390 \
			or int(canopy.get_meta("twig_fans", 0)) != 4680 \
			or int(canopy.get_meta("child_boughs_per_major", 0)) != 2 \
			or int(canopy.get_meta("twig_fans_per_child", 0)) != 8 \
			or int(canopy.get_meta("primary_cover_twigs_per_major", 0)) != 8 \
			or not is_equal_approx(float(canopy.get_meta(
				"primary_cover_root_spacing_fraction", 1.0)), 0.135) \
			or not is_equal_approx(float(canopy.get_meta(
				"child_cover_root_spacing_fraction", 1.0)), 0.135) \
			or float(canopy.get_meta("maximum_uncovered_longitudinal_fraction", 1.0)) \
				> 0.1351 \
			or not bool(canopy.get_meta("cover_twigs_follow_parent_bough", false)) \
			or not bool(canopy.get_meta(
				"major_and_child_branch_surface_coverage_audited", false)) \
			or not bool(canopy.get_meta("large_branch_leaf_sleeve_complete", false)) \
			or float(canopy.get_meta("cover_fan_longitudinal_bias", 0.0)) < 0.94 \
			or float(canopy.get_meta("cover_fan_lateral_bias", 1.0)) > 0.20 \
			or int(canopy.get_meta("total_bough_modules", 0)) != 585 \
			or int(canopy.get_meta("leaf_cards", 0)) != 37440 \
			or int(canopy.get_meta("growth_band_count", 0)) != 17 \
			or int(canopy.get_meta("interwhorl_boughs", 0)) != 51 \
			or canopy.get_meta("silhouette", "") != "wide_bottom_tapered_christmas_cone" \
			or canopy.get_meta("graphics_profile", "") != "laptop_low" \
			or not is_equal_approx(float(canopy.get_meta("blueprint_total_height", 0.0)), 496.0) \
			or not is_equal_approx(float(canopy.get_meta("blueprint_max_width", 0.0)), 325.5) \
			or not is_equal_approx(float(canopy.get_meta("reference_size_multiplier", 0.0)), 2.0) \
			or not bool(canopy.get_meta("foliage_masks_central_trunk", false)) \
			or not is_equal_approx(float(canopy.get_meta("inner_child_fork_fraction", 1.0)), 0.04) \
			or not is_equal_approx(float(canopy.get_meta("minimum_twig_length", 0.0)), 10.35) \
			or not is_equal_approx(float(canopy.get_meta(
				"inner_leaf_cover_twig_fraction", 1.0)), 0.02) \
			or not is_equal_approx(float(canopy.get_meta(
				"foliage_density_multiplier", 0.0)), 2.0) \
			or canopy.get_meta("coverage_strategy", "") \
				!= "broad_overlapping_static_leaf_reliefs" \
			or not is_equal_approx(float(canopy.get_meta(
				"leaf_width_multiplier", 0.0)), 1.87) \
			or not is_equal_approx(float(canopy.get_meta(
				"leaf_length_multiplier", 0.0)), 1.30) \
			or canopy.get_meta("coverage_implementation", "") \
				!= "scale_existing_batched_reliefs_no_new_instances" \
			or not bool(canopy.get_meta("leaf_instance_count_unchanged_for_laptop", false)) \
			or int(canopy.get_meta("leaf_batch_count", 0)) != 4:
		_fail("blueprint branch hierarchy or Christmas-cone tier contract is incomplete")
		return
	if not bool(canopy.get_meta("energy_routes_share_wood_centerlines", false)) \
			or not is_zero_approx(float(canopy.get_meta("maximum_energy_surface_gap", INF))) \
			or int(canopy.get_meta("twig_energy_routes_per_fan", 0)) != 1 \
			or not bool(canopy.get_meta("gravity_shaped_branch_curvature", false)) \
			or canopy.get_meta("leaf_orientation_source", "") \
				!= "gravity_leaf_bough.leaf_matrix" \
			or canopy.get_meta("leaf_orientation_pattern", "") \
				!= "alternating_side_terminal_forward" \
			or float(canopy.get_meta("maximum_leaf_roll_degrees", INF)) > 8.01 \
			or not bool(canopy.get_meta("leaf_socket_pivots_aligned_to_twig", false)) \
			or canopy.get_meta("leaf_fit_phase", "") != "reference_hierarchy_complete" \
			or int(canopy.get_meta("leaf_bearing_stems_per_twig_instance", 0)) != 1 \
			or int(canopy.get_meta("leaves_per_twig", 0)) != 8 \
			or canopy.get_meta("gravity_direction", Vector3.ZERO) != Vector3.DOWN \
			or canopy.get_meta("primary_pitch_range_degrees", Vector2.ZERO) \
				!= Vector2(-8.0, 9.0) \
			or canopy.get_meta("twig_gravity_lift_range", Vector2.ZERO) \
				!= Vector2(-0.55, 0.65) \
			or canopy.get_meta("leaf_gravity_pitch_range_degrees", Vector2.ZERO) \
				!= Vector2(-35.0, -10.0) \
			or not bool(canopy.get_meta("branches_and_leaves_share_gravity", false)) \
			or not is_equal_approx(float(canopy.get_meta(
				"christmas_tree_taper_ratio", 0.0)), 0.65625) \
			or not bool(canopy.get_meta("single_dominant_leader", false)) \
			or not bool(canopy.get_meta("uniform_whorl_spacing", false)) \
			or not bool(canopy.get_meta("interwhorl_foliage_overlap", false)) \
			or not bool(canopy.get_meta("distal_tip_gravitropic_recovery", false)):
		_fail("gravity branch fibers are detached from their tapered wood routes")
		return
	var tier_bough_counts: PackedInt32Array = canopy.get_meta(
		"tier_bough_counts", PackedInt32Array())
	var tier_heights: PackedFloat32Array = canopy.get_meta(
		"tier_heights_metres", PackedFloat32Array())
	var tier_reaches: PackedFloat32Array = canopy.get_meta(
		"tier_reaches_metres", PackedFloat32Array())
	var primary_pairs: PackedVector3Array = canopy.get_meta(
		"primary_socket_pairs", PackedVector3Array())
	var child_pairs: PackedVector3Array = canopy.get_meta(
		"child_socket_pairs", PackedVector3Array())
	var twig_pairs: PackedVector3Array = canopy.get_meta(
		"twig_socket_pairs", PackedVector3Array())
	var leaf_pairs: PackedVector3Array = canopy.get_meta(
		"leaf_socket_pairs", PackedVector3Array())
	var leaf_direction_pairs: PackedVector3Array = canopy.get_meta(
		"leaf_direction_pairs", PackedVector3Array())
	if tier_bough_counts != PackedInt32Array([24, 24, 20, 20, 16, 16, 12, 8, 4]) \
			or tier_heights != PackedFloat32Array(
				[14.0, 27.0, 40.0, 53.0, 66.0, 79.0, 92.0, 105.0, 118.0]) \
			or tier_reaches != PackedFloat32Array(
				[42.0, 38.0, 34.0, 30.0, 25.5, 21.0, 16.5, 12.0, 7.0]) \
			or primary_pairs.size() != 390 or _max_socket_pair_gap(primary_pairs) > 0.01 \
			or child_pairs.size() != 780 or _max_socket_pair_gap(child_pairs) > 0.005 \
			or twig_pairs.size() != 9360 or _max_socket_pair_gap(twig_pairs) > 0.003 \
			or leaf_pairs.size() != 74880 or _max_socket_pair_gap(leaf_pairs) > 0.001 \
			or leaf_direction_pairs.size() != 74880 \
			or _max_socket_pair_gap(leaf_direction_pairs) > 0.001:
		_fail("calculated primary, child, twig, or leaf socket attachment gaps exceed contract")
		return
	var old_growth_body := tree.get_node_or_null("OldGrowthTrunkBody") as Node3D
	var detailed_roots := old_growth_body.get_node_or_null(
		"OldGrowthRootSystem") as Node3D if old_growth_body != null else null
	if old_growth_body == null \
			or old_growth_body.get_meta("lower_body_visual_source", "") \
				!= "BlenderBlueprintTrunkRoot" \
			or int(old_growth_body.get_meta("superseded_lower_systems_hidden", 0)) != 6 \
			or not is_equal_approx(float(old_growth_body.get_meta("blueprint_root_spread", 0.0)), 139.5) \
			or not is_equal_approx(float(old_growth_body.get_meta("blueprint_body_height", 0.0)), 186.0) \
			or not is_equal_approx(float(old_growth_body.get_meta("blueprint_doorway_width", 0.0)), 23.25) \
			or not is_equal_approx(float(old_growth_body.get_meta("blueprint_doorway_height", 0.0)), 31.0) \
			or not bool(old_growth_body.get_meta("continuous_root_to_crown", false)) \
			or old_growth_body.find_children(
				"OldGrowthButtressStem_*", "MeshInstance3D", true, false).size() != 2 \
			or old_growth_body.get_node_or_null("OldGrowthCentralLeader") == null \
			or old_growth_body.find_children(
				"OldGrowthCoDominantStem_*", "MeshInstance3D", true, false).size() != 3 \
			or detailed_roots == null \
			or detailed_roots.find_children(
				"OldGrowthPrimaryRoot_*", "MeshInstance3D", true, false).size() != 12 \
			or detailed_roots.find_children(
				"OldGrowthRootlet_*", "MeshInstance3D", true, false).size() != 24 \
			or detailed_roots.find_children(
				"OldGrowthRootSapSeam_*", "MeshInstance3D", true, false).size() != 12 \
			or detailed_roots.find_children(
				"OldGrowthRootletEnergy_*", "MeshInstance3D", true, false).size() != 24 \
			or int(detailed_roots.get_meta("gold_growth_collars", 0)) != 12 \
			or int(detailed_roots.get_meta("gold_root_slash_inlays", 0)) != 12 \
			or detailed_roots.get_node_or_null(
				"OldGrowthRootGoldGrowthCollarBatch") == null \
			or detailed_roots.get_node_or_null(
				"OldGrowthRootGoldSlashInlayBundle") == null \
			or float(detailed_roots.get_meta("max_attachment_gap", 1.0)) > 0.01 \
			or not bool(detailed_roots.get_meta("doorway_corridor_preserved", false)) \
			or float(detailed_roots.get_meta("minimum_south_corridor_clearance", 0.0)) \
				< float(detailed_roots.get_meta("south_corridor_half_width", INF)) \
			or float(detailed_roots.get_meta("minimum_ground_clearance", -INF)) < -0.01 \
			or float(detailed_roots.get_meta("maximum_primary_attachment_gap", INF)) > 0.01 \
			or float(detailed_roots.get_meta("maximum_rootlet_attachment_gap", INF)) > 0.005 \
			or canopy.get_meta("major_attachment", "") != "continuous_trunk_surface" \
			or canopy.get_meta("child_attachment", "") != "parent_bough_centerline" \
			or canopy.get_meta("twig_attachment", "") != "child_bough_centerline" \
			or canopy.get_meta("leaf_attachment", "") \
				!= "visible_tail_to_twig_surface_socket" \
			or canopy.get_meta("leaf_forward_axis", "") \
				!= "local_positive_x_tail_to_tip" \
			or canopy.get_meta("leaf_orientation_frame", "") \
				!= "twig_tangent_plus_gravity_up" \
			or not bool(canopy.get_meta("leaf_tail_is_mesh_origin", false)) \
			or bool(canopy.get_meta("leaf_orientation_randomized", true)) \
			or canopy.get_meta("leaf_visible_tail_uv_alignment", "") \
				!= "godot_top_origin_v_to_brass_cuff" \
			or float(canopy.get_meta("max_major_attachment_gap", 1.0)) > 0.01 \
			or float(canopy.get_meta("max_child_attachment_gap", 1.0)) > 0.01 \
			or float(canopy.get_meta("max_twig_attachment_gap", 1.0)) > 0.01 \
			or float(canopy.get_meta("max_leaf_attachment_gap", 1.0)) > 0.01:
		_fail("old-growth trunk or physically seated branch attachment contract is incomplete")
		return
	var circulation := old_growth_body.get_node_or_null("OldGrowthEnergyNetwork") as Node3D
	if circulation == null \
			or circulation.find_children(
				"OldGrowthButtressFeeder_*", "MeshInstance3D", true, false).size() != 6 \
			or circulation.find_children(
				"OldGrowthHeartFeeder_*", "MeshInstance3D", true, false).size() != 2 \
			or circulation.find_children(
				"OldGrowthButtressCollector_*", "MeshInstance3D", true, false).size() != 6 \
			or int(circulation.get_meta("buttress_collectors", 0)) != 6 \
			or not bool(circulation.get_meta("continuous_to_crown", false)):
		_fail("root-to-heart-to-crown energy circulation is incomplete")
		return
	var crown_convergence := energy_veins.get_node_or_null(
		"CrownVeinConvergenceBatch") as MeshInstance3D
	if crown_convergence == null \
			or int(crown_convergence.get_meta("veins", 0)) != 18 \
			or float(crown_convergence.get_meta("maximum_endpoint_gap", INF)) > 0.001:
		_fail("the eighteen trunk veins do not converge into the crown star socket")
		return
	var structure_batch := canopy.get_node_or_null("PoweredBranchStructureBatch") as MultiMeshInstance3D
	var child_batch := canopy.get_node_or_null("BlueprintChildBoughBatch") as MultiMeshInstance3D
	var twig_batch := canopy.get_node_or_null("BlueprintTwigFanBatch") as MultiMeshInstance3D
	var twig_gold_batch := canopy.get_node_or_null(
		"BlueprintTwigGoldRuneBandBatch") as MultiMeshInstance3D
	var branch_junction_batch := canopy.get_node_or_null(
		"BranchEnergyJunctionBatch") as MultiMeshInstance3D
	var leaf_batches := canopy.find_children("PoweredLeafBatch_*", "MultiMeshInstance3D", true, false)
	var petiole_batches := canopy.find_children(
		"LeafPetioleGoldSocketBatch_*", "MultiMeshInstance3D", true, false)
	var leaf_mesh_style := str(canopy.get_meta("leaf_mesh_style", ""))
	if not leaf_mesh_style in [
			"gravity_leaf_relief", "faceted_pod", "blossom_bud_cluster"]:
		_fail("tree did not select a supported volumetric leaf style")
		return
	var leaf_instances := 0
	var leaf_cluster_instances := 0
	var petiole_instances := 0
	var family_instances := {}
	for leaf_batch_node in leaf_batches:
		var leaf_batch := leaf_batch_node as MultiMeshInstance3D
		var logical_cards := int(leaf_batch.get_meta("logical_leaf_cards", 0))
		leaf_instances += logical_cards
		leaf_cluster_instances += leaf_batch.multimesh.instance_count
		petiole_instances += int(leaf_batch.get_meta("petiole_instances", 0))
		family_instances[leaf_batch.name] = logical_cards
		if not bool(leaf_batch.get_meta("lightweight_lod", false)) \
				or int(leaf_batch.get_meta("growth_layers", 0)) != 1 \
				or int(leaf_batch.get_meta("leaf_cards_per_instance", 0)) \
					!= (12 if leaf_mesh_style == "blossom_bud_cluster" else 1) \
				or not bool(leaf_batch.get_meta("volumetric_leaf_mesh", false)) \
				or str(leaf_batch.get_meta("leaf_mesh_style", "")) != leaf_mesh_style \
				or leaf_batch.multimesh.mesh.get_surface_count() \
					!= (5 if leaf_mesh_style == "blossom_bud_cluster" else 3) \
				or not bool(leaf_batch.get_meta(
					"leaf_and_socket_single_instance", false)) \
				or not bool(leaf_batch.get_meta(
					"wood_and_gold_share_leaf_transform", false)) \
				or leaf_batch.get_meta("tail_socket_local", Vector3.INF) != Vector3.ZERO \
				or leaf_batch.get_meta("gold_design", "") != "three_notch_rune_sleeve":
			_fail("leaf batch is not using the single-layer laptop card LOD")
			return
	if structure_batch == null or structure_batch.multimesh.instance_count != 195 \
			or child_batch == null or child_batch.multimesh.instance_count != 390 \
			or twig_batch == null or twig_batch.multimesh.instance_count != 4680 \
			or twig_gold_batch == null \
			or twig_gold_batch.multimesh.instance_count != 4680 \
			or branch_junction_batch == null \
			or branch_junction_batch.multimesh.instance_count != 195 \
			or int(branch_junction_batch.get_meta("junction_count", 0)) != 195 \
			or not bool(branch_junction_batch.get_meta(
				"connects_trunk_to_every_primary_bough", false)) \
			or not bool(canopy.get_meta("root_to_every_branch_energy_continuity", false)) \
			or int(canopy.get_meta("heart_niche_culled_leaf_instances", 0)) <= 0 \
			or not bool(canopy.get_meta("heart_frame_visibility_preserved", false)) \
			or not bool(canopy.get_meta("small_branch_leaf_visibility_audited", false)) \
			or int(canopy.get_meta("visible_small_branches_without_leaves", -1)) != 0 \
			or int(canopy.get_meta("minimum_visible_leaves_per_visible_twig", 0)) < 4 \
			or twig_gold_batch.multimesh.mesh.get_surface_count() != 3 \
			or int(twig_gold_batch.get_meta("bands_per_twig", 0)) != 3 \
			or not bool(twig_gold_batch.get_meta("surface_seated", false)) \
			or int(canopy.get_meta("twig_gold_rune_bands", 0)) != 14040 \
			or not bool(canopy.get_meta("twig_gold_bands_follow_surface", false)) \
			or leaf_batches.size() != 4 \
			or not petiole_batches.is_empty() \
			or leaf_instances != 37440 \
			or leaf_cluster_instances \
				!= (3120 if leaf_mesh_style == "blossom_bud_cluster" else 37440) \
			or petiole_instances != leaf_cluster_instances \
			or int(canopy.get_meta("leaf_petiole_instances", 0)) != petiole_instances \
			or not bool(canopy.get_meta("branch_leaf_coverage_audited", false)) \
			or not bool(canopy.get_meta("branch_leaf_coverage_complete", false)) \
			or int(canopy.get_meta("minimum_leaves_per_leaf_twig", 0)) != 8 \
			or int(canopy.get_meta("leaf_twigs_per_primary_hierarchy", 0)) != 24 \
			or int(canopy.get_meta("logical_leaves_per_primary_hierarchy", 0)) != 192 \
			or int(canopy.get_meta("logical_leaf_total_from_branch_hierarchy", 0)) \
				!= 37440 \
			or int(canopy.get_meta("leaf_gold_socket_sleeves", 0)) != petiole_instances \
			or float(canopy.get_meta("leaf_petiole_attachment_gap", INF)) > 0.001 \
			or not bool(canopy.get_meta("leaf_cuff_girth_drives_twig_floor", false)) \
			or canopy.get_meta("leaf_socket_gold_design", "") \
				!= "three_notch_rune_sleeve" \
			or int(family_instances.get("PoweredLeafBatch_living_leaf_fan", 0)) != 14040 \
			or int(family_instances.get("PoweredLeafBatch_magic_rune_leaf", 0)) != 9360 \
			or int(family_instances.get("PoweredLeafBatch_emerald_sensor_leaf", 0)) != 4680 \
			or int(family_instances.get("PoweredLeafBatch_solar_glass_science_leaf", 0)) != 9360 \
			or int(structure_batch.get_meta("embedded_energy_routes", 0)) != 195 \
			or int(child_batch.get_meta("embedded_energy_routes", 0)) != 390 \
			or int(twig_batch.get_meta("embedded_energy_routes", 0)) != 4680 \
			or canopy.get_node_or_null("BlueprintPrimaryEnergyBatch") != null \
			or canopy.get_node_or_null("BlueprintChildEnergyBatch") != null \
			or canopy.get_node_or_null("BlueprintTwigEnergyBatch") != null \
			or int(canopy.get_meta("gold_branch_collar_instances", 0)) != 585 \
			or canopy.get_node_or_null("PoweredLeafTransferNodeBatch") != null:
		_fail("blueprint canopy counts, energy routing, or laptop instance budget drifted")
		return
	if leaf_mesh_style == "gravity_leaf_relief" \
			and canopy.get_meta("leaf_source_asset", "") \
			!= "res://assets3D/tree_of_life/gravity_leaf_bough/glb/gravity_leaf_bough_runtime.glb":
		_fail("August gravity leaf style is not sourced from its Web runtime GLB")
		return
	var wisdom_star := visual.find_children("WisdomStar*", "MeshInstance3D", true, false)
	if wisdom_star.size() != 1 or not (wisdom_star[0] as MeshInstance3D).is_visible_in_tree() \
			or not bool(wisdom_star[0].get_meta("canopy_crown_logo", false)) \
			or not bool(tree.get_meta("gold_star_preserved", false)) \
			or canopy.get_node_or_null("BlueprintGoldCrownStar") == null \
			or int(canopy.get_meta("gold_crown_star_instances", 0)) != 1:
		_fail("original gold Wisdom Star is not preserved at the canopy crown")
		return

	var heart_shrine := tree.get_node_or_null("WisdomHeartShrine") as Node3D
	if heart_shrine == null \
			or heart_shrine.find_children("HeartAstrolabeOrbit_*", "Node3D", true, false).size() != 3 \
			or heart_shrine.find_children("HeartFrameRune_*", "Node3D", true, false).size() != 8 \
			or heart_shrine.find_children("HeartFrameRadialSpoke_*", "MeshInstance3D", true, false).size() != 8 \
			or heart_shrine.find_children("HeartWoodCradleRib_*", "MeshInstance3D", true, false).size() != 6 \
			or heart_shrine.find_children("HeartWoodGearMount_*", "MeshInstance3D", true, false).size() != 8:
		_fail("heart crystal is missing its three orbits, eight rune sockets, or eight radial spokes")
		return
	var wood_cradle := heart_shrine.get_node_or_null("LivingHeartWoodCradle") as Node3D
	if wood_cradle == null \
			or not bool(wood_cradle.get_meta("mechanics_embedded_not_floating", false)) \
			or int(wood_cradle.get_meta("wood_ribs", 0)) != 6 \
			or int(wood_cradle.get_meta("gear_mounts", 0)) != 8:
		_fail("heart gears are not seated inside the living-wood trunk cradle")
		return
	var main_gear := heart_shrine.get_node_or_null("HeartGearMain") as Node3D
	var main_teeth := main_gear.find_children(
		"HeartGearMain_Tooth_*", "MeshInstance3D", false, false) \
		if main_gear != null else []
	if main_gear == null \
			or main_teeth.size() != 20 \
			or not bool(main_gear.get_meta("continuous_load_bearing_rim", false)) \
			or not bool(main_gear.get_meta("teeth_connected_to_rim", false)) \
			or int(main_gear.get_meta("connected_tooth_count", 0)) != 20 \
			or not bool(main_gear.get_meta("open_crystal_aperture", false)) \
			or float(main_gear.get_meta("tooth_root_overlap_m", 0.0)) < 1.9 \
			or not main_gear.find_children(
				"HeartGearMain_Spoke_*", "MeshInstance3D", false, false).is_empty():
		_fail("main gear teeth are detached from the rim or obstruct the crystal aperture")
		return
	for tooth_node in main_teeth:
		if not bool(tooth_node.get_meta("connected_to_continuous_rim", false)) \
				or float(tooth_node.get_meta("radial_root_overlap_m", 0.0)) < 1.9:
			_fail("a main gear tooth does not overlap the continuous rim")
			return
	var suspension := heart_shrine.get_node_or_null(
		"HeartCrystalFloatingSuspension") as MeshInstance3D
	if suspension == null \
			or int(suspension.get_meta("terminal_count", 0)) != 2 \
			or not bool(suspension.get_meta("crystal_face_clear", false)) \
			or float(suspension.get_meta("minimum_crystal_clearance_m", 0.0)) < 1.0 \
			or not bool(suspension.get_meta(
				"floating_crystal_supported_by_energy_field", false)):
		_fail("crystal is not floating cleanly between its two suspension terminals")
		return
	var heart_spin := heart_shrine.get_node_or_null("HeartCrystalSpin") as Node3D
	var heart_crystal := heart_shrine.get_node_or_null(
		"HeartCrystalSpin/HeartShrineCrystal") as Node3D
	var heart_mandorla := heart_shrine.get_node_or_null(
		"HeartCrystalGoldMandorla") as MeshInstance3D
	if heart_spin == null \
			or bool(heart_spin.get_meta("outer_heart_locked_front", true)) \
			or not bool(heart_spin.get_meta("whole_crystal_rotates_about_itself", false)) \
			or heart_spin.get_meta("rotation_axis", "") != "local_y" \
			or not bool(heart_spin.get_meta("internal_core_rotates_with_shell", false)) \
			or heart_crystal == null \
			or heart_crystal.get_meta("crystal_shape", "") != "blender_cut_heart_diamond" \
			or not bool(heart_crystal.get_meta("diamond_taper", false)) \
			or not bool(heart_crystal.get_meta("triangular_facet_geometry", false)) \
			or not bool(heart_crystal.get_meta("blender_authored", false)) \
			or not bool(heart_crystal.get_meta("closed_realistic_3d_shell", false)) \
			or int(heart_crystal.get_meta("outer_triangular_facets", 0)) != 24 \
			or int(heart_crystal.get_meta("girdle_facets", 0)) != 12 \
			or int(heart_crystal.get_meta("internal_core_facets", 0)) != 8 \
			or int(heart_crystal.get_meta("internal_inclusions", 0)) != 6 \
			or int(heart_crystal.get_meta("blender_mesh_objects", 0)) != 8 \
			or heart_crystal.get_meta("runtime_glb", "") \
				!= "res://assets3D/tree_of_life/heart_crystal/glb/realistic_heart_crystal.glb" \
			or heart_mandorla == null \
			or heart_mandorla.get_meta("frame_shape", "") != "heart_mandorla" \
			or not bool(heart_mandorla.get_meta("seated_inside_main_gear", false)):
		_fail("rotating Blender heart-diamond crystal or its gold mandorla is incomplete")
		return

	var proxies := tree.get_node_or_null("TreeOfLifeCollisionProxies") as Node3D
	if proxies == null:
		_fail("authored collision proxy system is missing")
		return
	var static_bodies := proxies.find_children("*", "StaticBody3D", true, false)
	var collision_shapes := proxies.find_children("*", "CollisionShape3D", true, false)
	if static_bodies.size() != 14 or collision_shapes.size() != 14:
		_fail("expected 2 original-trunk and 12 big-root proxies, found %d bodies/%d shapes"
			% [static_bodies.size(), collision_shapes.size()])
		return
	if proxies.find_children("TrunkPillar*", "StaticBody3D", true, false).size() != 2 \
			or proxies.find_children("SimpleTrunkDoorway*", "StaticBody3D", true, false).size() != 0:
		_fail("original gothic passage collision is not the authoritative two-pillar layout")
		return

	var manifest := _load_manifest()
	if manifest.is_empty():
		_fail("editable-source manifest is missing or invalid")
		return
	var source := manifest.get("source", {}) as Dictionary
	var game_export := manifest.get("game_export", {}) as Dictionary
	var design := manifest.get("design", {}) as Dictionary
	if game_meshes.size() != int(game_export.get("mesh_nodes", 0)) \
			or game_meshes.size() != 10:
		_fail("laptop profile must keep ten authored render systems without canopy copies")
		return
	if int(tree.get_meta("source_named_modules", 0)) != int(source.get("named_mesh_modules", -1)) \
			or int(tree.get_meta("game_render_systems", 0)) != int(game_export.get("mesh_nodes", -1)):
		_fail("Godot tree metadata drifted from the Blender manifest")
		return
	if int(source.get("vertices", 0)) < 170000 \
			or int(source.get("named_mesh_modules", 0)) < 1300 \
			or int(source.get("leaf_modules", 0)) < 4900 \
			or int(source.get("leaf_power_nodes", 0)) < 44 \
			or int(source.get("leaf_tech_spines", 0)) < 88 \
			or float((manifest.get("design", {}) as Dictionary).get("player_clear_path_m", 0.0)) < 9.5:
		_fail("manifest does not prove the required editable detail")
		return
	if manifest.get("version", 0) != 3 \
			or (manifest.get("blueprint_references", []) as Array).size() != 4 \
			or design.get("silhouette", "") != "braided_twin_trunk_gothic_arch" \
			or design.get("foliage_style", "") != "dense_crystal_powered_branch_fans" \
			or (design.get("leaf_families", []) as Array).size() != 4 \
			or not is_equal_approx(float(design.get("foundation_depth_m", 0.0)), 14.0):
		_fail("v3 asset is not bound to the crystal-powered leaf blueprint")
		return

	# Drive the real production CharacterBody3D capsule through the widest
	# ceremonial arch. This catches accidental trunk/root collision overlap.
	var player := world.get_node_or_null("Player3D") as CharacterBody3D
	if player == null:
		_fail("production player is missing")
		return
	player.set_physics_process(false)
	var tree_center := tree.global_position
	var start := tree_center + Vector3(0.0, 4.0, -98.0)
	var destination := tree_center + Vector3(0.0, 4.0, 98.0)
	if not await _settle(player, start):
		_fail("production player cannot stand at the south tree entrance")
		return
	if not await _walk(player, destination):
		_fail("player is blocked beneath the tree at %s; collisions: %s"
			% [player.global_position, _collider_labels(player)])
		return
	if not await _walk(player, start):
		_fail("player is blocked returning north-to-south beneath the tree at %s; collisions: %s"
			% [player.global_position, _collider_labels(player)])
		return

	print("TREE_SMALL_BRANCH_LEAF_AUDIT: PASS — %s visible bare twigs, %s intentionally hidden leafless aperture twigs, minimum %s attached visible leaves per rendered twig" % [
		int(canopy.get_meta("visible_small_branches_without_leaves", -1)),
		int(canopy.get_meta("heart_niche_hidden_leafless_twigs", -1)),
		int(canopy.get_meta("minimum_visible_leaves_per_visible_twig", -1))])
	print("TREE_OF_LIFE_ASSET_TEST: PASS — %s editable vertices, %s modules, %s game meshes, and production player crossed the clear south-facing arch" % [
		int(source.get("vertices", 0)), int(source.get("named_mesh_modules", 0)), game_meshes.size()])
	quit()
