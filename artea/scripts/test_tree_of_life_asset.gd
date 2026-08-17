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


func _run() -> void:
	var world := WorldScene.instantiate() as Node3D
	root.add_child(world)
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

	var visual := tree.get_node_or_null("BlenderTreeOfLifeVisual") as Node3D
	if visual == null:
		_fail("optimized Blender visual is missing")
		return
	var game_meshes := visual.find_children("*", "MeshInstance3D", true, false)
	for game_mesh in game_meshes:
		var legacy_mesh := game_mesh as MeshInstance3D
		if (legacy_mesh.name.begins_with("Foliage") or legacy_mesh.name.begins_with("Branches")) \
				and legacy_mesh.visible:
			_fail("legacy low-poly canopy system is still visible beneath the replacement canopy")
			return
	var canopy := tree.get_node_or_null("ReferenceFaithfulCrystalCanopy") as Node3D
	if canopy == null:
		_fail("reference-faithful crystal branch canopy is missing")
		return
	if (canopy.get_meta("leaf_types", []) as Array).size() != 4 \
			or int(canopy.get_meta("leaf_instances", 0)) != 20000 \
			or int(canopy.get_meta("major_limbs", 0)) != 22 \
			or int(canopy.get_meta("secondary_twigs", 0)) != 24 \
			or int(canopy.get_meta("foliage_branch_clusters", 0)) != 159 \
			or int(canopy.get_meta("leaf_support_twigs", 0)) != 1431 \
			or int(canopy.get_meta("leaf_support_cyan_channels", 0)) != 159 \
			or not bool(canopy.get_meta("leaves_attached_to_support_twigs", false)) \
			or int(canopy.get_meta("living_root_trunks", 0)) != 12 \
			or int(canopy.get_meta("secondary_ground_roots", 0)) != 12 \
			or int(canopy.get_meta("entrance_framing_roots", 0)) != 2 \
			or int(canopy.get_meta("doorway_living_root_jambs", 0)) != 2 \
			or int(canopy.get_meta("doorway_editable_joints", 0)) != 8 \
			or int(canopy.get_meta("doorway_electric_fibers", 0)) != 6 \
			or bool(canopy.get_meta("doorway_metal_frame", true)) \
			or int(canopy.get_meta("editable_primary_root_joints", 0)) != 60 \
			or int(canopy.get_meta("editable_secondary_root_joints", 0)) != 36 \
			or int(canopy.get_meta("secondary_root_cyan_inlays", 0)) != 12 \
			or float(canopy.get_meta("powered_root_door_clear_width_m", 0.0)) < 9.5 \
			or float(canopy.get_meta("canopy_diameter_m", 0.0)) < 270.0 \
			or float(canopy.get_meta("root_foundation_diameter_m", 0.0)) < 120.0 \
			or not bool(canopy.get_meta("faces_south_arrival_bridge", false)) \
			or int(canopy.get_meta("powered_route_mesh_crossbars", 0)) != 17 \
			or int(canopy.get_meta("powered_route_deck_plates", 0)) != 12 \
			or int(canopy.get_meta("powered_route_cables", 0)) != 2 \
			or int(canopy.get_meta("root_radial_power_feeders", 0)) != 6 \
			or int(canopy.get_meta("floating_root_relays", 0)) != 8 \
			or int(canopy.get_meta("root_cyan_tributaries", 0)) != 24 \
			or int(canopy.get_meta("root_mechanical_clamp_sets", 0)) != 7 \
			or int(canopy.get_meta("cyan_energy_channels", 0)) != 46 \
			or int(canopy.get_meta("brass_articulation_collars", 0)) != 70:
		_fail("crystal branch or four-family leaf canopy metadata is incomplete")
		return
	var leaf_batches := canopy.find_children("CanopyLeafBatch_*", "MultiMeshInstance3D", true, false)
	var batched_leaf_count := 0
	for batch_node in leaf_batches:
		var batch := batch_node as MultiMeshInstance3D
		batched_leaf_count += batch.multimesh.instance_count
	if leaf_batches.size() != 4 or batched_leaf_count != 20000 \
			or int(canopy.get_meta("runtime_batched_leaf_instances", 0)) != 20000:
		_fail("expected four runtime batches containing 20,000 leaves, found %d batches/%d leaves"
			% [leaf_batches.size(), batched_leaf_count])
		return
	if canopy.find_children("LivingButtressRoot_*", "MeshInstance3D", true, false).size() != 12 \
			or canopy.find_children("SecondaryGroundRoot_*", "MeshInstance3D", true, false).size() != 12:
		_fail("reference root foundation is missing buttress or secondary ground roots")
		return
	if canopy.find_children("LeafSupportTwig_*", "MeshInstance3D", true, false).size() != 1431 \
			or canopy.find_children("LeafSupportCyanChannel_*", "MeshInstance3D", true, false).size() != 159:
		_fail("leaf fans are not fully connected to their ordered support-twig hierarchy")
		return
	if canopy.find_children("PoweredRouteMeshCrossbar_*", "MeshInstance3D", true, false).size() != 17 \
			or canopy.find_children("PoweredRouteDeckPlate_*", "MeshInstance3D", true, false).size() != 12 \
			or canopy.find_children("DoorwayLivingRootJamb_*", "MeshInstance3D", true, false).size() != 2 \
			or canopy.find_children("DoorwayElectricFiber_*", "MeshInstance3D", true, false).size() != 6 \
			or canopy.find_children("EditableDoorwayRootJoint_*", "MeshInstance3D", true, false).size() != 8 \
			or canopy.find_children("EditablePrimaryRootJoint_*", "MeshInstance3D", true, false).size() != 60 \
			or canopy.find_children("EditableSecondaryRootJoint_*", "MeshInstance3D", true, false).size() != 36 \
			or canopy.find_children("SecondaryRootCyanInlay_*", "MeshInstance3D", true, false).size() != 12 \
			or canopy.find_children("FloatingRootRelayCrystal_*", "MeshInstance3D", true, false).size() != 8 \
			or canopy.find_children("RootCyanTributary_*", "MeshInstance3D", true, false).size() != 24:
		_fail("powered root doorway, route mesh, or distributed root technology is incomplete")
		return
	if not canopy.find_children("PoweredRootDoorFrame*", "MeshInstance3D", true, false).is_empty() \
			or not canopy.find_children("PoweredRootDoorBrassClamp*", "MeshInstance3D", true, false).is_empty():
		_fail("freestanding metal doorway frame still exists around the living-root arch")
		return
	var expected_family_counts := {
		"living_leaf_fan": 7500,
		"magic_rune_leaf": 5000,
		"solar_glass_science_leaf": 5000,
		"emerald_sensor_leaf": 2500,
	}
	for family in expected_family_counts:
		var batch := canopy.get_node_or_null("CanopyLeafBatch_%s" % family) as MultiMeshInstance3D
		var actual_count := batch.multimesh.instance_count if batch != null else 0
		if actual_count != int(expected_family_counts[family]):
			_fail("canopy contains %d/%d instances of %s" % [actual_count, expected_family_counts[family], family])
			return
	if not canopy.find_children("*", "CollisionObject3D", true, false).is_empty():
		_fail("decorative crystal canopy must remain collision-free")
		return

	var proxies := tree.get_node_or_null("TreeOfLifeCollisionProxies") as Node3D
	if proxies == null:
		_fail("authored collision proxy system is missing")
		return
	var static_bodies := proxies.find_children("*", "StaticBody3D", true, false)
	var collision_shapes := proxies.find_children("*", "CollisionShape3D", true, false)
	if static_bodies.size() != 14 or collision_shapes.size() != 14:
		_fail("expected 2 trunk and 12 root proxies, found %d bodies/%d shapes"
			% [static_bodies.size(), collision_shapes.size()])
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
		_fail("optimized render systems differ from the ten-system v2 manifest")
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

	print("TREE_OF_LIFE_ASSET_TEST: PASS — %s editable vertices, %s modules, %s game meshes, and production player crossed the doubled south-facing arch" % [
		int(source.get("vertices", 0)), int(source.get("named_mesh_modules", 0)), game_meshes.size()])
	quit()
