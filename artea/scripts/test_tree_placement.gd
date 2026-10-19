extends SceneTree


const STAIR_BASE := Vector2(-1.4, 27.41)
const BIG_TREE_MIN_STAIR_CLEARANCE := 40.0
const GROUND_TOLERANCE := 0.03


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/New_Hub_World.tscn") as PackedScene
	if packed == null:
		_fail("hub scene must load")
		return
	var hub := packed.instantiate()
	root.add_child(hub)
	for _frame in 8:
		await process_frame
	var terrain = hub.get_node_or_null("Environment/Terrain3D")
	if terrain == null or terrain.data == null:
		_fail("terrain data must be available for the placement audit")
		return

	var tree_count := 0
	for district_name in ["District_MindSpark", "District_CreatorsLight", "District_HeartMelody"]:
		var district := hub.get_node(district_name)
		for child in district.get_children():
			if child is not Node3D or not String(child.name).contains("tree"):
				continue
			tree_count += 1
			var tree := child as Node3D
			var ground: float = terrain.data.get_height(tree.global_position)
			if is_nan(ground) or absf(tree.global_position.y - ground) > GROUND_TOLERANCE:
				_fail("%s is not planted on terrain: tree %.3f, ground %.3f" % [
					tree.name, tree.global_position.y, ground])
				return
			var up := tree.global_basis.y.normalized()
			if up.dot(Vector3.UP) < 0.999:
				_fail("%s is tilted instead of planted upright" % tree.name)
				return
	if tree_count != 14:
		_fail("expected all 14 manually planted district trees, found %d" % tree_count)
		return

	var big_tree := hub.get_node("District_CreatorsLight/cl_tree_3") as Node3D
	var big_tree_xz := Vector2(big_tree.global_position.x, big_tree.global_position.z)
	if big_tree_xz.distance_to(STAIR_BASE) < BIG_TREE_MIN_STAIR_CLEARANCE:
		_fail("large tree remains too close to the castle stair")
		return

	var objects := hub.get_node("Environment/Objects")
	for exclusion_name in ["VillagePlazaExclusion", "CreatorsLightTreeExclusion",
			"HeartMelodyTreeExclusion", "CastleRouteTreeExclusion"]:
		var exclusion = objects.get_node_or_null(exclusion_name)
		if exclusion == null or not bool(exclusion.get("negative")) or exclusion.get("shape") == null:
			_fail("tree scatter is missing %s" % exclusion_name)
			return
	var terrain_filter_found := false
	for modifier in objects.modifier_stack.stack:
		var script = modifier.get_script() if modifier != null else null
		if script != null and script.resource_path.ends_with("project_on_terrain3d.gd"):
			terrain_filter_found = bool(modifier.enable_texture_filtering) \
				and int(modifier.target_texture_id) == 0 \
				and is_equal_approx(float(modifier.texture_threshold), 0.5) \
				and float(modifier.max_slope) <= 35.0
	if not terrain_filter_found:
		_fail("scattered trees must stay on gently sloped natural soil")
		return

	hub.queue_free()
	await process_frame
	print("TREE_PLACEMENT_TEST: PASS — 14 grounded trees, protected districts, and clear castle stair")
	quit()


func _fail(message: String) -> void:
	push_error("TREE_PLACEMENT_TEST: %s" % message)
	quit(1)
