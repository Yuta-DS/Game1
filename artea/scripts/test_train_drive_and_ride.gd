extends SceneTree

const PASSENGER_FRONT_CAR_CENTRE_Z := 1.5
const PASSENGER_REAR_CAR_CENTRE_Z := 18.0
const DRIVER_SIDE_GATE_Z := -15.85
const DRIVER_SIDE_GATE_HALF_LENGTH := 3.525

# Drives the Crown Line the way a player does.
#
# The previous suites only asked the railway about its route geometry, so a
# train whose cab was walled off by its own collision shell — and whose driver
# seat sat inside the engine block — still passed everything. This test starts
# from the player's position on the deck, boards through the same public calls
# the Q handler uses, and holds W and S to confirm the train actually moves.

func _fail(message: String) -> void:
	push_error("TRAIN_DRIVE_TEST: %s" % message)
	quit(1)


func _point_is_inside_solid(space: PhysicsDirectSpaceState3D, point: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not space.intersect_point(query, 8).is_empty()


func _press_train_mode(railway: Node3D, key: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	event.physical_keycode = key
	railway.call("_unhandled_input", event)


func _run() -> void:
	# Mirror art_gallery.gd: the railway lives under an offset floating world
	# while the player sits at the scene root, so every to_global() conversion
	# in the railway is exercised the same way it is in the real game.
	var gallery := Node3D.new()
	gallery.name = "ArtGallery"
	root.add_child(gallery)

	var player := CharacterBody3D.new()
	player.name = "Player3D"
	player.set_script(load("res://player_3d.gd"))
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	shape_node.shape = capsule
	player.add_child(shape_node)
	gallery.add_child(player)

	var floating_world := Node3D.new()
	floating_world.name = "ArtCastleFloatingWorld"
	floating_world.position = Vector3(0.0, 0.0, -480.0)
	gallery.add_child(floating_world)

	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	floating_world.add_child(railway)

	for _i in 10:
		await process_frame

	var space := player.get_world_3d().direct_space_state
	var train: Node3D = railway.get("_train")
	var accents := train.get_node_or_null("RainbowGoldAccentLayout") as Node3D
	if accents == null:
		_fail("the rainbow-and-gold train redesign is missing")
		return
	var snowflake_roofs := accents.get_node_or_null("SnowflakeRoofCrowns") as Node3D
	if snowflake_roofs == null or String(snowflake_roofs.get_meta("roof_shape", "")) \
			!= "six_point_crystal_snowflake" or int(snowflake_roofs.get_meta(
			"snowflake_count", 0)) != 3 or int(snowflake_roofs.get_meta(
			"points_per_snowflake", 0)) != 6 or int(snowflake_roofs.get_meta(
			"curved_arm_segments", 0)) != 3 or not bool(snowflake_roofs.get_meta(
			"connected_to_roof_structure", false)) or not bool(snowflake_roofs.get_meta(
			"measured_to_each_roof_section", false)) or absf(float(snowflake_roofs.get_meta(
			"roof_edge_margin_m", 0.0)) - 0.28) > 0.001 or not bool(snowflake_roofs.get_meta(
			"driving_snowflake_fitted_to_cab", false)) or absf(float(snowflake_roofs.get_meta(
			"driving_roof_center_z_m", 0.0)) - DRIVER_SIDE_GATE_Z) > 0.001 \
			or Vector2(snowflake_roofs.get_meta("driving_roof_half_extents_m", Vector2.ZERO)) \
				.distance_to(Vector2(4.60, DRIVER_SIDE_GATE_HALF_LENGTH)) > 0.001 \
			or absf(float(snowflake_roofs.get_meta(
			"driving_roof_edge_margin_m", 0.0)) - 0.32) > 0.001 \
			or float(snowflake_roofs.get_meta("driving_snowflake_halo_clearance_m", 0.0)) \
				< 0.80 or not bool(snowflake_roofs.get_meta(
			"passenger_clearance_preserved", false)):
		_fail("the curved snowflake roofs are not connected to the train structure")
		return
	var roof_centres := [PASSENGER_FRONT_CAR_CENTRE_Z,
		PASSENGER_REAR_CAR_CENTRE_Z, DRIVER_SIDE_GATE_Z]
	var roof_half_extents := [Vector2(4.78, 6.00), Vector2(4.78, 6.00),
		Vector2(4.60, DRIVER_SIDE_GATE_HALF_LENGTH)]
	var roof_edge_margins := [0.28, 0.28, 0.32]
	var measured_tip_count := 0
	for roof_child in snowflake_roofs.get_children():
		if not String(roof_child.name).contains("_TipGem_"):
			continue
		var name_parts := String(roof_child.name).split("_")
		var roof_index := int(name_parts[1])
		var tip_position: Vector3 = (roof_child as Node3D).position
		var extents: Vector2 = roof_half_extents[roof_index]
		var edge_margin: float = float(roof_edge_margins[roof_index])
		if absf(tip_position.x) > extents.x - edge_margin + 0.001 \
				or absf(tip_position.z - float(roof_centres[roof_index])) \
					> extents.y - edge_margin + 0.001:
			_fail("a measured snowflake point overhangs roof %d: tip=%s extents=%s margin=%.2f" \
				% [roof_index, tip_position, extents, edge_margin])
			return
		measured_tip_count += 1
	if measured_tip_count != 18:
		_fail("not all eighteen snowflake points were measured against their roof")
		return
	var christmas_decor := accents.get_node_or_null("GoldenChristmasExpressDecor") as Node3D
	if christmas_decor == null or String(christmas_decor.get_meta("theme", "")) \
			!= "golden_christmas_express" or bool(christmas_decor.get_meta(
			"engine_wreath", true)) or not bool(christmas_decor.get_meta(
			"engine_front_green_removed", false)) or String(christmas_decor.get_meta(
			"engine_front_style", "")) != "luxury_pearl_crystal_boiler" \
			or not bool(christmas_decor.get_meta("engine_front_symmetrical", false)) \
			or bool(christmas_decor.get_meta("engine_front_added_tank", true)) \
			or bool(christmas_decor.get_meta("engine_front_added_pilot", true)) \
			or not bool(christmas_decor.get_meta("engine_original_tank_enlarged", false)) \
			or absf(float(christmas_decor.get_meta(
			"engine_original_tank_radial_scale", 0.0)) - 1.28) > 0.001 \
			or absf(float(christmas_decor.get_meta(
			"engine_original_tank_length_scale", 0.0)) - 1.18) > 0.001 \
			or not bool(christmas_decor.get_meta(
			"engine_original_crystal_uncovered", false)) \
			or not bool(christmas_decor.get_meta(
			"engine_tank_open_front_collar", false)) \
			or int(christmas_decor.get_meta(
			"engine_tank_longitudinal_rail_count", 0)) != 5 \
			or int(christmas_decor.get_meta(
			"engine_tank_front_jewel_count", 0)) != 6 \
			or not bool(christmas_decor.get_meta(
			"engine_tank_center_left_open", false)) \
			or absf(float(christmas_decor.get_meta(
			"engine_tank_front_collar_z_m", 0.0)) + 25.91) > 0.001 \
			or absf(float(christmas_decor.get_meta(
			"engine_tank_center_y_m", 0.0)) - 4.72) > 0.001 \
			or int(christmas_decor.get_meta(
			"engine_side_wreath_count", 0)) != 2 or int(christmas_decor.get_meta(
			"engine_side_snowflake_crest_count", -1)) != 0 \
			or not bool(christmas_decor.get_meta("green_side_rings_restored", false)) \
			or int(christmas_decor.get_meta(
			"coach_bow_count", 0)) != 4 or int(christmas_decor.get_meta(
			"candy_cane_column_count", 0)) != 8 or int(christmas_decor.get_meta(
			"warm_light_count", 0)) != 36 or int(christmas_decor.get_meta(
			"roof_curve_count", 0)) != 7 or int(christmas_decor.get_meta(
			"roof_christmas_ball_count", 0)) != 51 or String(christmas_decor.get_meta(
			"roof_garland_placement", "")) != "under_top_frame" \
			or int(christmas_decor.get_meta("roof_frame_attachment_count", 0)) != 51 \
			or int(christmas_decor.get_meta("roof_curve_segments_per_line", 0)) != 12 \
			or int(christmas_decor.get_meta(
			"engine_side_curve_segments_per_line", 0)) != 16 \
			or not bool(christmas_decor.get_meta("roof_curve_symmetric", false)) \
			or absf(float(christmas_decor.get_meta("engine_roof_curve_center_z_m", 0.0)) \
				+ 16.20) > 0.001 \
			or absf(float(christmas_decor.get_meta(
			"engine_roof_curve_front_edge_z_m", 0.0)) + 19.82) > 0.001 \
			or absf(float(christmas_decor.get_meta(
			"engine_roof_curve_rear_edge_z_m", 0.0)) + 12.58) > 0.001 \
			or absf(float(christmas_decor.get_meta("engine_roof_curve_span_m", 0.0)) \
				- 7.24) > 0.001 \
			or absf(float(christmas_decor.get_meta("engine_ball_spacing_m", 0.0)) \
				- 0.905) > 0.001 \
			or float(christmas_decor.get_meta("engine_roof_garland_outer_x_m", 0.0)) < 4.25 \
			or float(christmas_decor.get_meta("engine_roof_garland_outer_x_m", 0.0)) > 4.54 \
			or absf(float(christmas_decor.get_meta(
			"engine_roof_purple_frame_front_edge_z_m", 0.0)) + 20.10) > 0.001 \
			or absf(float(christmas_decor.get_meta(
			"engine_roof_purple_frame_rear_edge_z_m", 0.0)) + 12.30) > 0.001 \
			or absf(float(christmas_decor.get_meta(
			"engine_roof_purple_frame_outer_x_m", 0.0)) - 4.54) > 0.001 \
			or absf(float(christmas_decor.get_meta(
			"engine_roof_ball_radius_m", 0.0)) - 0.28) > 0.001 \
			or not bool(christmas_decor.get_meta("engine_roof_garland_measured_from_mesh", false)) \
			or absf(float(christmas_decor.get_meta("engine_roof_edge_inset_m", 0.0)) - 0.12) > 0.001 \
			or not bool(christmas_decor.get_meta(
				"roof_mounts_seated_in_lower_edge", false)) \
			or not bool(christmas_decor.get_meta(
				"engine_roof_garland_flush_underbeam", false)) \
			or not bool(christmas_decor.get_meta(
				"engine_roof_garland_raised_to_requested_edge", false)) \
			or not bool(christmas_decor.get_meta(
				"engine_roof_garland_matches_outermost_edges", false)) \
			or int(christmas_decor.get_meta(
			"engine_roof_short_vertical_mount_count", 0)) != 23 \
			or String(christmas_decor.get_meta(
			"engine_roof_garland_shape", "")) != "u_shape_sides_and_rear" \
			or int(christmas_decor.get_meta(
			"engine_side_light_ball_count", 0)) != 18 \
			or int(christmas_decor.get_meta(
			"engine_rear_light_ball_count", 0)) != 5 \
			or int(christmas_decor.get_meta(
			"engine_front_light_ball_count", -1)) != 0 \
			or absf(float(christmas_decor.get_meta("engine_rear_ball_spacing_m", 0.0)) \
				- float(christmas_decor.get_meta("engine_roof_garland_outer_x_m")) / 3.0) > 0.001 \
			or absf(float(christmas_decor.get_meta("passenger_roof_curve_span_m", 0.0)) \
				- 12.0) > 0.001 \
			or absf(float(christmas_decor.get_meta("passenger_ball_spacing_m", 0.0)) \
				- 2.0) > 0.001 \
			or not bool(christmas_decor.get_meta(
				"roof_curve_reaches_both_end_frames", false)) \
			or absf(float(christmas_decor.get_meta("ornament_drop_m", 0.0)) - 0.40) > 0.001 \
			or int(christmas_decor.get_meta("passenger_roof_curve_count", 0)) != 4 \
			or int(christmas_decor.get_meta("passenger_christmas_ball_count", 0)) != 28 \
			or bool(christmas_decor.get_meta(
			"decorative_collision", true)):
		_fail("the Christmas train decorations are incomplete or obstructive")
		return
	if christmas_decor.get_node_or_null("EngineEvergreenWreath") != null \
			or christmas_decor.get_node_or_null("EngineFrontTankBarrel") != null \
			or christmas_decor.get_node_or_null("EngineFrontTankDome") != null \
			or christmas_decor.get_node_or_null("EngineFrontCrystalHeadlight") != null \
			or christmas_decor.get_node_or_null("EngineFrontWarmCrystalGlow") != null \
			or christmas_decor.get_node_or_null("EngineRoyalPilotTopRail") != null:
		_fail("an added front tank or pilot remains in front of the original boiler")
		return
	if christmas_decor.get_node_or_null("EngineTankFrontGoldCollar") == null \
			or christmas_decor.get_node_or_null("EngineTankFrontCrystalInlay") == null \
			or christmas_decor.get_node_or_null("EngineTankCrownRail_00") == null \
			or christmas_decor.get_node_or_null("EngineTankCrownRail_04") == null \
			or christmas_decor.get_node_or_null("EngineTankFrontJewel_00") == null \
			or christmas_decor.get_node_or_null("EngineTankFrontJewel_05") == null:
		_fail("the luxury trim is not fitted to the original engine tank")
		return
	var roof_ball_counts := [0, 0, 0]
	var roof_curve_segment_counts := [0, 0, 0]
	var roof_ball_min_z := [INF, INF, INF]
	var roof_ball_max_z := [-INF, -INF, -INF]
	var roof_mount_count := 0
	var engine_roof_short_mount_count := 0
	var engine_rear_ball_count := 0
	var engine_rear_curve_segment_count := 0
	var engine_rear_mount_count := 0
	var engine_rear_ball_min_x := INF
	var engine_rear_ball_max_x := -INF
	var side_wreath_count := 0
	var side_bow_count := 0
	var frame_attachment_heights := [8.0, 7.94, 7.94]
	for decoration in christmas_decor.get_children():
		var decoration_name := String(decoration.name)
		if decoration_name.begins_with("EngineSideWreath_"):
			side_wreath_count += 1
		elif decoration_name.begins_with("EngineSideBow"):
			side_bow_count += 1
		elif decoration_name.begins_with("EngineSideSnowflake_"):
			_fail("a side snowflake still overlaps the restored evergreen ring")
			return
		if decoration_name.begins_with("RoofBall_") \
				and decoration is MeshInstance3D and decoration.mesh is SphereMesh:
			var ball_parts := decoration_name.split("_")
			var ball_section := int(ball_parts[1])
			var ball_node_index := int(ball_parts[3])
			roof_ball_counts[ball_section] += 1
			var ball_position := (decoration as Node3D).position
			var ball_z := ball_position.z
			roof_ball_min_z[ball_section] = minf(float(roof_ball_min_z[ball_section]), ball_z)
			roof_ball_max_z[ball_section] = maxf(float(roof_ball_max_z[ball_section]), ball_z)
			if ball_section == 0:
				var mount := christmas_decor.get_node("RoofFrameMount_00_%s_%02d" % [ball_parts[2], ball_node_index]) as MeshInstance3D
				var mount_height := (mount.mesh as CylinderMesh).height
				var offset: Vector3 = decoration.get_meta("roof_pendant_offset", Vector3.ZERO)
				if absf(ball_position.x - mount.position.x - offset.x) > 0.001 \
						or offset.y != 0 or offset.z != 0 or offset.x * ball_position.x < 0 \
						or offset.length() > .801 \
						or absf(ball_position.y - (mount.position.y - mount_height * 0.5 - 0.40)) > 0.001:
					_fail("an engine ornament is detached from its measured roof mount")
					return
				if not offset.is_zero_approx():
					var arm := christmas_decor.get_node_or_null(decoration_name + "_FrameClearanceArm") as MeshInstance3D
					if arm == null:
						_fail("an offset engine ornament has no attached support arm")
						return
					var half_arm := arm.basis.y * (arm.mesh as CylinderMesh).height * .5
					var mount_bottom := mount.position - Vector3.UP * mount_height * .5
					if (arm.position - half_arm).distance_to(mount_bottom) > .001 \
							or (arm.position + half_arm).distance_to(ball_position + Vector3.UP * .40) > .001:
						_fail("an engine ornament's support arm is disconnected")
						return
		elif decoration_name.begins_with("RoofFrameMount_"):
			roof_mount_count += 1
			var mount_parts := decoration_name.split("_")
			var mount_section := int(mount_parts[1])
			if mount_section == 0:
				engine_roof_short_mount_count += 1
			var mount_mesh := (decoration as MeshInstance3D).mesh as CylinderMesh
			var mount_top := (decoration as Node3D).position.y + mount_mesh.height * 0.5
			var expected_top := float(frame_attachment_heights[mount_section])
			if mount_section == 0:
				expected_top = (decoration.get_meta("purple_beam_contact") as Vector3).y + 0.008
			if absf(mount_top - expected_top) > 0.001:
				_fail("a gold garland mount passes through its purple roof beam")
				return
		elif decoration_name.begins_with("RoofCurve_"):
			var curve_parts := decoration_name.split("_")
			var curve_section := int(curve_parts[1])
			roof_curve_segment_counts[curve_section] += 1
			if (decoration as Node3D).position.y >= float(
					frame_attachment_heights[curve_section]):
				_fail("a Christmas garland is not suspended below its top roof frame")
				return
		elif decoration_name.begins_with("EngineRearRoofBall_") \
				and not decoration_name.ends_with("_GoldCap"):
			engine_rear_ball_count += 1
			var rear_ball_position := (decoration as Node3D).position
			engine_rear_ball_min_x = minf(engine_rear_ball_min_x, rear_ball_position.x)
			engine_rear_ball_max_x = maxf(engine_rear_ball_max_x, rear_ball_position.x)
			if absf(rear_ball_position.z + 12.58) > 0.001:
				_fail("a rear driving-roof light ball is not aligned under the purple frame")
				return
		elif decoration_name.begins_with("EngineRearRoofCurve_"):
			engine_rear_curve_segment_count += 1
		elif decoration_name.begins_with("EngineRearRoofFrameMount_"):
			engine_rear_mount_count += 1
			var rear_mount := decoration as MeshInstance3D
			var rear_mount_mesh := rear_mount.mesh as CylinderMesh
			var rear_contact: Vector3 = rear_mount.get_meta("purple_beam_contact")
			if absf(rear_mount.position.y + rear_mount_mesh.height * 0.5 - rear_contact.y - 0.008) > 0.001:
				_fail("a rear driving-roof mount passes through the purple frame")
				return
		elif decoration_name.begins_with("EngineFrontRoof"):
			_fail("light balls were added to the front edge of the driving roof")
			return
	var expected_curve_limits := [
		Vector2(-19.82, -12.58),
		Vector2(PASSENGER_FRONT_CAR_CENTRE_Z - 6.0,
			PASSENGER_FRONT_CAR_CENTRE_Z + 6.0),
		Vector2(PASSENGER_REAR_CAR_CENTRE_Z - 6.0,
			PASSENGER_REAR_CAR_CENTRE_Z + 6.0),
	]
	if roof_ball_counts != [18, 14, 14] or roof_mount_count != 46 \
			or engine_roof_short_mount_count != 18 \
			or roof_curve_segment_counts != [32, 24, 24] \
			or engine_rear_ball_count != 5 or engine_rear_curve_segment_count != 12 \
			or engine_rear_mount_count != 5 \
			or absf(engine_rear_ball_min_x + float(christmas_decor.get_meta("engine_rear_ball_spacing_m")) * 2.0) > 0.001 \
			or absf(engine_rear_ball_max_x - float(christmas_decor.get_meta("engine_rear_ball_spacing_m")) * 2.0) > 0.001 \
			or side_wreath_count != 2 or side_bow_count != 4:
		_fail("the engine and both passenger sections do not have complete hanging garlands")
		return
	for section_index in 3:
		var limits: Vector2 = expected_curve_limits[section_index]
		if absf(float(roof_ball_min_z[section_index]) - limits.x) > 0.001 \
				or absf(float(roof_ball_max_z[section_index]) - limits.y) > 0.001:
			_fail("a hanging garland is not accurately fitted to its measured roof span")
			return
	for accent in accents.get_children():
		if accent.name.begins_with("RainbowSeat") or accent.name.begins_with("GoldSeat"):
			_fail("replacement seat geometry still covers the original train seats")
			return
	for accent in accents.get_children():
		if accent.name.begins_with("CoachSpectrum_") \
				or accent.name.begins_with("CoachRainbowPanel_") \
				or accent.name.begins_with("EngineRainbowPanel_"):
			_fail("rainbow colour escaped the seats onto an exterior train barrier")
			return
	var detailed_train := train.get_node_or_null("BlenderCrownLineTrain") as Node3D
	if detailed_train == null or not bool(detailed_train.get_meta(
			"original_engine_tank_enlarged", false)) \
			or absf(float(detailed_train.get_meta(
			"original_engine_tank_radial_scale", 0.0)) - 1.28) > 0.001 \
			or absf(float(detailed_train.get_meta(
			"original_engine_tank_length_scale", 0.0)) - 1.18) > 0.001 \
			or int(detailed_train.get_meta(
			"original_engine_tank_resized_vertices", 0)) <= 0 \
			or not bool(detailed_train.get_meta(
			"original_botanical_roofs_removed", false)) or int(detailed_train.get_meta(
			"removed_botanical_roof_triangles", 0)) <= 0 or not bool(detailed_train.get_meta(
			"blue_cab_barrier_removed", false)) or int(detailed_train.get_meta(
			"removed_blue_cab_barrier_triangles", 0)) != 108 or not bool(
			detailed_train.get_meta("cab_side_glass_visible", false)) \
			or int(detailed_train.get_meta("cab_side_glass_triangle_count", 0)) != 440 \
			or int(detailed_train.get_meta("cab_side_glass_pane_count", 0)) != 2 \
			or absf(float(detailed_train.get_meta("cab_side_glass_alpha", 0.0)) - 0.22) > 0.001 \
			or not bool(detailed_train.get_meta(
				"cab_side_glass_clipped_to_window_opening", false)) \
			or absf(float(detailed_train.get_meta(
				"cab_side_glass_lower_edge_y_m", 0.0)) - 4.55) > 0.001 \
			or int(detailed_train.get_meta(
				"cab_side_glass_generated_triangle_count", 0)) <= 0 \
			or not bool(detailed_train.get_meta("cab_shoulder_scales_removed", false)) \
			or int(detailed_train.get_meta(
				"removed_cab_shoulder_scale_triangles", 0)) != 1728 \
			or int(detailed_train.get_meta("removed_cab_shoulder_scale_count", 0)) != 16:
		_fail("the clear cab glass or removal of the highlighted window blocks is incomplete")
		return
	if not bool(detailed_train.get_meta("cab_side_pillars_restored", false)) \
			or not bool(detailed_train.get_meta(
				"thin_gold_cab_window_frames_removed", false)) \
			or int(detailed_train.get_meta(
				"removed_cab_window_frame_triangles", 0)) <= 0:
		_fail("the side pillars or the thin gold driver-window frame are incorrect")
		return
	var clear_cab_glass_surfaces := 0
	var lowest_cab_glass_y := INF
	for candidate in detailed_train.find_children("*", "MeshInstance3D", true, false):
		var glass_mesh_instance := candidate as MeshInstance3D
		var glass_mesh := glass_mesh_instance.mesh
		if glass_mesh == null:
			continue
		for surface_index in glass_mesh.get_surface_count():
			var glass_material := glass_mesh.surface_get_material(surface_index) \
				as StandardMaterial3D
			if glass_material == null or glass_material.resource_name != "CabSideClearGlass":
				continue
			clear_cab_glass_surfaces += 1
			var glass_arrays: Array = glass_mesh.surface_get_arrays(surface_index)
			var glass_vertices: PackedVector3Array = glass_arrays[Mesh.ARRAY_VERTEX]
			for glass_vertex in glass_vertices:
				lowest_cab_glass_y = minf(lowest_cab_glass_y,
					train.to_local(glass_mesh_instance.to_global(glass_vertex)).y)
			if glass_material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA \
					or absf(glass_material.albedo_color.a - 0.22) > 0.001 \
					or String(glass_material.get_meta("glass_style", "")) \
						!= "clear_visible_cab_glass":
				_fail("the restored cab glass is not visibly transparent")
				return
	if clear_cab_glass_surfaces != 1:
		_fail("the two restored panes were not isolated onto one clear-glass surface")
		return
	if lowest_cab_glass_y < 4.549:
		_fail("the cab glass extends through the lower wall: lowest y=%.3f" \
			% lowest_cab_glass_y)
		return
	var imported_seat_surfaces := 0
	var mixed_rainbow_seat_surfaces := 0
	var animated_balanced_seat_surfaces := 0
	if detailed_train != null:
		for candidate in detailed_train.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			for surface_index in mesh_instance.mesh.get_surface_count():
				var source := mesh_instance.mesh.surface_get_material(surface_index) \
					as StandardMaterial3D
				if source == null or not source.resource_name.to_lower().contains("seat_navy"):
					continue
				imported_seat_surfaces += 1
				var override := mesh_instance.get_surface_override_material(surface_index) \
					as ShaderMaterial
				if override != null and String(override.get_meta("seat_style", "")) \
						== "original_geometry_mixed_rainbow":
					mixed_rainbow_seat_surfaces += 1
					if bool(override.get_meta("animated_rainbow", false)) \
							and int(override.get_meta("rainbow_colour_count", 0)) == 7 \
							and bool(override.get_meta("equal_colour_distribution", false)) \
							and String(override.get_meta("seat_effect_style", "")) \
								== "golden_aurora_silk" \
							and bool(override.get_meta("warm_luxury_gold_sheen", false)):
						animated_balanced_seat_surfaces += 1
	if imported_seat_surfaces == 0 or mixed_rainbow_seat_surfaces != imported_seat_surfaces:
		_fail("the original train seats are not using the mixed-rainbow material")
		return
	if animated_balanced_seat_surfaces != imported_seat_surfaces:
		_fail("the old seats do not have the balanced seven-colour animation")
		return

	# 1. The cab and every seat must be air the player can stand in. A boarding
	#    point inside a collision box teleports the player into the geometry.
	var driver_point: Vector3 = railway.call("get_driver_interaction_position")
	var driver_seat: Vector3 = railway.call("get_driver_seat_position")
	if _point_is_inside_solid(space, driver_point):
		_fail("driver interaction point is buried inside the train collision shell")
		return
	if _point_is_inside_solid(space, driver_seat):
		_fail("driver seat is buried inside the train collision shell")
		return
	for seat_index in int(railway.call("get_passenger_seat_count")):
		var seat: Vector3 = railway.call("get_passenger_seat_position", seat_index)
		if _point_is_inside_solid(space, seat):
			_fail("passenger seat %d is buried inside the train collision shell" % seat_index)
			return

	# 2. Standing on the front of the deck offers driving; standing at the back
	#    offers a seat. This is the rule the player is told: near the cab you
	#    drive, near a seat you sit.
	var front_deck := train.to_global(Vector3(0.0, 2.4, -3.0))
	var rear_deck := train.to_global(Vector3(0.0, 2.4, 2.8))
	if String(railway.call("get_interaction_mode_for_position", front_deck)) != "drive":
		_fail("standing at the front of the deck does not offer the driver cab")
		return
	if String(railway.call("get_interaction_mode_for_position", rear_deck)) != "sit":
		_fail("standing by the benches does not offer a passenger seat")
		return

	# 3. R explicitly selects driver mode and moves the player to the front cab.
	player.global_position = front_deck
	_press_train_mode(railway, KEY_R)
	if not bool(railway.call("is_driving")):
		_fail("pressing R at the train did not take control of the train")
		return
	if player.global_position.distance_to(driver_seat) > 1.0:
		_fail("pressing R did not move the player into the front driving section")
		return
	if player.call("get_vehicle_pose") != "driver":
		_fail("the player did not use the proper driver seat pose")
		return
	if not bool(player.call("is_train_seated_pose")):
		_fail("the driver character did not enter a seated driving pose")
		return
	var train_forward := -train.global_basis.z.normalized()
	var player_forward := -player.global_basis.z.normalized()
	if player_forward.dot(train_forward) < 0.99:
		_fail("the seated driver is not facing the front of the train")
		return
	# This suite drives through the public method with a fixed delta. Disable the
	# runtime Input poll so an empty test keyboard cannot apply a second, zero
	# throttle command in the same iteration and cancel the command under test.
	railway.set_process(false)
	var horn_count := int(railway.call("get_horn_request_count"))
	_press_train_mode(railway, KEY_H)
	if int(railway.call("get_horn_request_count")) != horn_count + 1:
		_fail("pressing H while driving did not sound the train horn")
		return

	# 4. Hold W: the train must accelerate and cover ground along the route.
	# Cab setup holds the brakes before the first throttle input can move it.
	var setup_position := train.global_position
	for _i in 108:
		railway.call("drive_manual", 0.0, 1.0 / 60.0)
		await process_frame
	if train.global_position.distance_to(setup_position) > 0.01:
		_fail("the train moved while the driver was preparing the cab")
		return
	var start_position := train.global_position
	for _i in 120:
		railway.call("drive_manual", 1.0, 1.0 / 60.0)
		await process_frame
	var forward_travel := train.global_position.distance_to(start_position)
	if forward_travel < 5.0:
		_fail("holding W did not move the train (travelled %.2f m)" % forward_travel)
		return
	if float(railway.call("get_display_speed_kph")) <= 0.0:
		_fail("holding W did not build up any speed")
		return
	# The driver rides in the cab rather than being left behind on the platform.
	if player.global_position.distance_to(railway.call("get_driver_seat_position")) > 1.0:
		_fail("the driver did not stay in the cab while the train moved")
		return

	# 5. Hold S: the train must come back the other way along the same line.
	var reverse_start := train.global_position
	for _i in 240:
		railway.call("drive_manual", -1.0, 1.0 / 60.0)
		await process_frame
	var reversed_toward_origin := train.global_position.distance_to(start_position) \
		< reverse_start.distance_to(start_position)
	if not reversed_toward_origin:
		_fail("holding S did not drive the train back the way it came")
		return

	# 6. Brake to a dock, then Q leaves the cab and hands control back.
	var guard := 0
	while int(railway.call("get_drive_segment")) >= 0 and guard < 3000:
		railway.call("drive_manual", -1.0, 1.0 / 60.0)
		await process_frame
		guard += 1
	if int(railway.call("get_drive_segment")) >= 0:
		_fail("the train never reached a station to disembark at")
		return
	if not bool(railway.call("request_disembark")):
		_fail("Q at a dock did not release the driver")
		return
	if bool(railway.call("is_driving")):
		_fail("leaving the cab did not exit driver mode")
		return
	if player.call("get_vehicle_pose") != "":
		_fail("leaving the cab did not restore the standing player pose")
		return

	# 7. The two passenger sections resolve independently, and T chooses the one
	#    nearest to the player's current position.
	var front_section_seat := int(railway.call("get_nearest_passenger_seat_index",
		train.to_global(Vector3(0.0, 3.45, 4.3))))
	var rear_section_seat := int(railway.call("get_nearest_passenger_seat_index",
		train.to_global(Vector3(0.0, 3.45, 20.8))))
	if int(railway.call("get_passenger_section_for_seat", front_section_seat)) != 0:
		_fail("the front passenger section did not resolve to section 1")
		return
	if int(railway.call("get_passenger_section_for_seat", rear_section_seat)) != 1:
		_fail("the rear passenger section did not resolve to section 2")
		return
	player.global_position = train.to_global(Vector3(0.0, 3.45, 20.8))
	var nearest_seat := int(railway.call("get_nearest_passenger_seat_index",
		player.global_position))
	if nearest_seat < 0:
		_fail("no passenger seat is reachable from the bench deck")
		return
	_press_train_mode(railway, KEY_T)
	if not bool(railway.call("is_passenger_seated")):
		_fail("pressing T at the train did not register the player as a passenger")
		return
	if int(railway.call("get_current_passenger_section")) != 1:
		_fail("pressing T near the rear coach did not choose passenger section 2")
		return
	if player.call("get_vehicle_pose") != "passenger":
		_fail("the passenger did not use the proper seated pose")
		return
	await process_frame
	if player.global_position.distance_to(
			railway.call("get_passenger_seat_position", nearest_seat)) > 1.0:
		_fail("the seated passenger is not actually on the seat")
		return

	print("TRAIN_DRIVE_TEST: PASS — R drives, T sits nearest, H horns, W moves forward and S reverses")
	quit()


func _init() -> void:
	call_deferred("_run")
