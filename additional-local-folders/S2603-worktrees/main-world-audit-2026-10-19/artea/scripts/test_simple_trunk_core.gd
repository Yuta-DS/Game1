extends SceneTree

## Focused asset regression for the blueprint-approved trunk core.

const TrunkScene := preload("res://assets3D/tree_of_life/trunk_core/glb/simple_trunk_core.glb")
const MANIFEST_PATH := \
	"res://assets3D/tree_of_life/trunk_core/simple_trunk_core_manifest.json"
const COMPONENT_MANIFEST_PATH := \
	"res://assets3D/tree_of_life/trunk_core/tree_of_life_editable_components.json"
const REQUIRED_BLENDER_RENDERS := [
	"res://assets3D/tree_of_life/trunk_core/renders/tree_of_life_blender_hero.png",
	"res://assets3D/tree_of_life/trunk_core/renders/tree_of_life_trunk_detail.png",
	"res://assets3D/tree_of_life/trunk_core/renders/tree_of_life_canopy_detail.png",
	"res://assets3D/tree_of_life/trunk_core/renders/tree_of_life_leaf_mesh_detail.png",
	"res://assets3D/tree_of_life/trunk_core/renders/tree_of_life_root_fiber_detail.png",
	"res://assets3D/tree_of_life/trunk_core/renders/tree_of_life_trunk_fiber_detail.png",
	"res://assets3D/tree_of_life/trunk_core/renders/tree_of_life_heart_crystal_detail.png",
	"res://assets3D/tree_of_life/trunk_core/renders/tree_of_life_blueprint_front.png",
	"res://assets3D/tree_of_life/trunk_core/renders/tree_of_life_root_plan.png",
	"res://assets3D/tree_of_life/trunk_core/renders/tree_of_life_gravity_bough_attachment_detail.png",
	"res://assets3D/tree_of_life/trunk_core/renders/tree_of_life_blueprint_foundation_front.png",
]


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("SIMPLE_TRUNK_CORE_TEST: %s" % message)
	quit(1)


func _triangle_count(mesh: Mesh) -> int:
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		total += indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
	return total


func _run() -> void:
	var core := TrunkScene.instantiate() as Node3D
	root.add_child(core)
	await process_frame
	var required_meshes := [
		"InnerShell", "BarkRibs", "DoorwayArch",
		"HeartRecess", "RootManifold", "EnergyVeins",
		"PrimaryRoots", "SecondaryRootlets", "DoorwayButtresses",
		"FoundationArchitecture",
		"RootEnergyChannels", "HeartFeeders", "CrownVeins",
		"BarkLaths", "GrainGrooves", "EnergyCapillaries",
	]
	var triangles := 0
	var triangle_breakdown := {}
	var material_names: Array[String] = []
	for mesh_name in required_meshes:
		var matches := core.find_children(mesh_name, "MeshInstance3D", true, false)
		if matches.size() != 1:
			_fail("expected one %s mesh, found %d" % [mesh_name, matches.size()])
			return
		var imported_mesh := (matches[0] as MeshInstance3D).mesh
		var mesh_triangles := _triangle_count(imported_mesh)
		triangles += mesh_triangles
		triangle_breakdown[mesh_name] = mesh_triangles
		for surface_index in imported_mesh.get_surface_count():
			var material := imported_mesh.surface_get_material(surface_index)
			if material != null:
				material_names.append(material.resource_name)
	var sockets := core.find_children("SOCKET_Bough_*", "Node3D", true, false)
	if sockets.size() != 8:
		_fail("expected eight bough sockets, found %d" % sockets.size())
		return
	var energy := core.find_children("EnergyVeins", "MeshInstance3D", true, false)[0] \
		as MeshInstance3D
	var energy_arrays := energy.mesh.surface_get_arrays(0)
	var energy_uvs: PackedVector2Array = energy_arrays[Mesh.ARRAY_TEX_UV]
	if energy_uvs.is_empty():
		_fail("energy veins have no longitudinal UV channel")
		return
	if triangles >= 60000:
		_fail("trunk core exceeds the 60,000-triangle budget: %d — %s" % [
			triangles, JSON.stringify(triangle_breakdown)])
		return
	if not FileAccess.file_exists(MANIFEST_PATH):
		_fail("trunk-core manifest is missing")
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	var manifest = JSON.parse_string(file.get_as_text())
	if not manifest is Dictionary:
		_fail("trunk-core manifest is not valid JSON")
		return
	var manifest_dict := manifest as Dictionary
	var dimensions := manifest_dict.get("dimensions_m", {}) as Dictionary
	if not bool(manifest_dict.get("web_compatible", false)) \
			or not is_equal_approx(float(dimensions.get("height", 0.0)), 48.0) \
			or not is_equal_approx(float(dimensions.get("root_diameter", 0.0)), 39.2) \
			or not is_equal_approx(float(dimensions.get("base_trunk_diameter", 0.0)), 18.0) \
			or not is_equal_approx(float(dimensions.get("neck_diameter", 0.0)), 5.0) \
			or not is_equal_approx(float(dimensions.get("doorway_width", 0.0)), 6.0) \
			or not is_equal_approx(float(dimensions.get("doorway_height", 0.0)), 8.0) \
			or not is_equal_approx(float(dimensions.get("heart_center", 0.0)), 14.0) \
			or int(((manifest as Dictionary).get("systems", {}) as Dictionary).get(
				"primary_energy_veins", 0)) != 6 \
			or int(((manifest as Dictionary).get("systems", {}) as Dictionary).get(
				"structural_bark_ribs", 0)) != 12 \
			or int(((manifest as Dictionary).get("systems", {}) as Dictionary).get(
				"bough_sockets", 0)) != 8:
		_fail("manifest does not describe the built Web-compatible GLB")
		return
	var systems := manifest_dict.get("systems", {}) as Dictionary
	if int(systems.get("major_sweeping_boughs", 0)) != 8 \
			or int(systems.get("secondary_canopy_boughs", 0)) != 24 \
			or int(systems.get("co_dominant_crown_leaders", 0)) != 5 \
			or int(systems.get("rising_crown_branchlets", 0)) != 10 \
			or int(systems.get("christmas_tier_boughs", 0)) != 113 \
			or int(systems.get("christmas_central_leaders", 0)) != 1 \
			or int(systems.get("editable_ground_root_fibers", 0)) != 18 \
			or int(systems.get("editable_secondary_rootlets", 0)) != 54 \
			or float((systems.get("primary_root_radius_range_m", [0.0, 0.0]) as Array)[1]) < 2.3 \
			or float((systems.get("secondary_rootlet_radius_range_m", [0.0, 0.0]) as Array)[1]) < 0.7 \
			or float(systems.get("root_energy_maximum_surface_gap_m", 1.0)) > 0.04 \
			or not bool(systems.get("root_energy_channels_embedded_in_bark_grooves", false)) \
			or int(systems.get("doorway_root_buttresses", 0)) != 2 \
			or int(systems.get("continuous_root_cambium_webbing", 0)) != 1 \
			or int(systems.get("primary_root_energy_intakes", 0)) != 18 \
			or int(systems.get("heart_energy_feeders", 0)) != 2 \
			or int(systems.get("crown_energy_veins", 0)) != 16 \
			or int(systems.get("editable_surface_bark_laths", 0)) != 28 \
			or int(systems.get("editable_recessed_grain_grooves", 0)) != 20 \
			or int(systems.get("editable_secondary_energy_capillaries", 0)) != 12 \
			or int(systems.get("runtime_trunk_detail_batches", 0)) != 9 \
			or int(systems.get("foundation_segments", 0)) != 32 \
			or int(systems.get("foundation_stairs", 0)) != 6 \
			or not bool(systems.get("pointed_doorway_arch", false)) \
			or int(systems.get("approved_gravity_bough_tiers", 0)) != 21 \
			or int(systems.get("approved_gravity_bough_instances", 0)) != 128 \
			or int(systems.get("approved_socket_attached_leaf_instances", 0)) < 43000 \
			or float(systems.get(
				"approved_gravity_bough_maximum_socket_error_m", 1.0)) > 0.000001 \
			or int(systems.get("superseded_canopy_objects_hidden", 0)) < 2500 \
			or int(systems.get("editable_gold_mechanical_branch_collars", 0)) != 121 \
			or int(systems.get("heart_astrolabe_orbits", 0)) != 3 \
			or int(systems.get("heart_frame_rune_sockets", 0)) != 8 \
			or int(systems.get("heart_frame_radial_spokes", 0)) != 8 \
			or int(systems.get("foliage_clouds", 0)) != 328 \
			or not is_equal_approx(float(systems.get("lowest_foliage_tier_m", 0.0)), 12.0) \
			or not is_equal_approx(float(systems.get("highest_foliage_tier_m", 0.0)), 62.0) \
			or not bool(systems.get("continuous_root_to_crown_foliage", false)) \
			or int(systems.get("editable_leaf_clusters", 0)) != 328 \
			or int(systems.get("individual_leaves", 0)) < 6232 \
			or int(systems.get("leaf_mesh_faces_per_leaf", 0)) < 11 \
			or float(systems.get("leaf_full_length_min_m", 0.0)) < 4.4 \
			or float(systems.get("leaf_full_length_max_m", 0.0)) < 9.6 \
			or float(systems.get("leaf_full_width_min_m", 0.0)) < 1.67 \
			or float(systems.get("leaf_full_width_max_m", 0.0)) < 3.9 \
			or not is_equal_approx(float(systems.get(
				"leaf_lower_tier_scale_multiplier", 0.0)), 3.0) \
			or not is_equal_approx(float(systems.get(
				"leaf_middle_tier_scale_multiplier", 0.0)), 2.6) \
			or not is_equal_approx(float(systems.get(
				"leaf_crown_tier_scale_multiplier", 0.0)), 2.2) \
			or float(systems.get("leaf_projected_area_multiplier_lower", 0.0)) < 9.0 \
			or float(systems.get("leaf_solidify_thickness_m", 0.0)) < 0.06 \
			or int(systems.get("lilac_flower_plumes", 0)) < 3100:
		_fail("Blender presentation canopy does not match the authored reference hierarchy")
		return
	if not FileAccess.file_exists(COMPONENT_MANIFEST_PATH) \
			or int(manifest_dict.get("editable_component_count", 0)) < 1000:
		_fail("shape-by-shape editable component manifest is missing or incomplete")
		return
	var component_file := FileAccess.open(COMPONENT_MANIFEST_PATH, FileAccess.READ)
	var component_manifest = JSON.parse_string(component_file.get_as_text())
	if not component_manifest is Dictionary:
		_fail("editable component manifest is not valid JSON")
		return
	var component_groups := (component_manifest as Dictionary).get("group_counts", {}) \
		as Dictionary
	if int(component_groups.get("structural_bark_ribs", 0)) != 12 \
			or int(component_groups.get("ground_root_fibers", 0)) != 18 \
			or int(component_groups.get("secondary_rootlets", 0)) != 54 \
			or int(component_groups.get("doorway_root_buttresses", 0)) != 2 \
			or int(component_groups.get("root_cambium_webbing", 0)) != 1 \
			or int(component_groups.get("root_energy_channels", 0)) != 18 \
			or int(component_groups.get("heart_energy_feeders", 0)) != 2 \
			or int(component_groups.get("crown_energy_veins", 0)) != 16:
		_fail("editable component groups do not match the trunk-and-root blueprint")
		return
	for render_path in REQUIRED_BLENDER_RENDERS:
		if not FileAccess.file_exists(render_path):
			_fail("required Blender detail render is missing: %s" % render_path)
			return
	if str(manifest_dict.get("visual_language", "")) \
			!= "pale_buttressed_living_wood_with_cyan_energy_veins" \
			or not material_names.any(func(name: String) -> bool: return "Wood" in name):
		_fail("trunk core is not authored with living-wood materials")
		return
	var transition := manifest_dict.get("root_transition", {}) as Dictionary
	if float(transition.get("radial_overlap_m", 0.0)) < 3.0 \
			or int(transition.get("continuous_buttress_stems", 0)) != 12:
		_fail("trunk core does not overlap the authored root skirt")
		return
	var authored_triangles := int(manifest_dict.get("game_triangles", 60000))
	# Godot triangulates the curve end caps during glTF import, so its count may
	# be marginally higher than Blender's evaluated-mesh count.
	if abs(triangles - authored_triangles) > maxi(128, int(authored_triangles * 0.02)):
		_fail("manifest triangle count %d differs materially from imported GLB count %d" % [
			authored_triangles, triangles])
		return
	print("SIMPLE_TRUNK_CORE_TEST: PASS — 48 m trunk, 18 roots, 54 rootlets, protected 6x8 m doorway, 6 collectors, 2 heart feeders, 16 crown veins, %d triangles" \
		% triangles)
	quit()
