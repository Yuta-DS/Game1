extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")


func _init() -> void:
	call_deferred("_audit")


func _audit() -> void:
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://audit_world_one_finish.json"
	root.add_child(world)
	for _frame in 4:
		await physics_frame
	var geometry := world.get_node("WorldOneGeometry") as Node3D
	var zones: Dictionary = world.get("_zone_nodes")
	var roots := {
		"island_1": [world.get_node("IslandOneResearchCampus"),
			world.get_island_one_puzzle(), zones["01_world_gate_landing"],
			zones["02_living_network_forest"]],
		"island_2": [world.get_node("IslandTwoMemoryCampus"),
			world.get_node("GardenOfUnfinishedLight"), zones["03_constellation_court"],
			zones["04_hope_path_ridge"]],
		"island_3": [geometry.get_node("IslandThreeCivicSanctuary"),
			zones["05_thought_storm_arena"], zones["06_oldest_tree_sanctuary"]],
	}
	var report := {"islands": {}, "objects": []}
	for island_name in roots:
		var tally := {"visible_meshes": 0, "hidden_meshes": 0,
			"hidden_mesh_groups": {},
			"dormant_hidden_meshes": 0, "retired_hidden_meshes": 0,
			"retired_hidden_mesh_paths": [],
			"active_colliders": 0, "hidden_parent_active_colliders": [],
			"hidden_parent_active_bodies": [],
			"retired_nodes": [], "lights": 0}
		for source in roots[island_name]:
			_scan(source as Node, tally)
		assert(int(tally.hidden_meshes) == int(tally.dormant_hidden_meshes) \
			+ int(tally.retired_hidden_meshes),
			"every hidden mesh must have an audited runtime role on %s" % island_name)
		assert(int(tally.retired_hidden_meshes) == 0,
			"retired geometry remains resident on %s: %s" % [
				island_name, str(tally.retired_hidden_mesh_paths)])
		report.islands[island_name] = tally
	for object in world.get_quest_objects():
		report.objects.append({"save_id": object.save_id,
			"physical_island": int(object.get_meta("physical_island", 0)),
			"position": str(object.global_position),
			"approach": str(object.get_meta("operator_approach_local", ""))})
	var output := "res://artifacts/world_one_finish_audit.json"
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("WORLD_ONE_FINISH_AUDIT: ", output)
	quit()


func _scan(node: Node, tally: Dictionary) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		if _visible_in_tree(node):
			tally.visible_meshes += 1
		else:
			tally.hidden_meshes += 1
			var retired_ancestor := _retired_ancestor(node)
			if retired_ancestor != null:
				tally.retired_hidden_meshes += 1
				tally.retired_hidden_mesh_paths.append(str(node.get_path()))
			else:
				tally.dormant_hidden_meshes += 1
			var group_path := _hidden_group_path(node)
			tally.hidden_mesh_groups[group_path] = int(
				tally.hidden_mesh_groups.get(group_path, 0)) + 1
	if node is Light3D:
		tally.lights += 1
	if node is CollisionObject3D and (node as CollisionObject3D).collision_layer & 1:
		tally.active_colliders += 1
		if not _visible_in_tree(node):
			tally.hidden_parent_active_colliders.append(str(node.get_path()))
			if node is PhysicsBody3D:
				tally.hidden_parent_active_bodies.append(str(node.get_path()))
	if node.has_meta("replaced_by") or node.has_meta("retired_by"):
		tally.retired_nodes.append(str(node.get_path()))
	for child in node.get_children():
		_scan(child, tally)


func _visible_in_tree(node: Node) -> bool:
	var current := node
	while current != null:
		if current is Node3D and not (current as Node3D).visible:
			return false
		current = current.get_parent()
	return true


func _retired_ancestor(node: Node) -> Node:
	var current := node
	while current != null:
		if current.has_meta("replaced_by") or current.has_meta("retired_by"):
			return current
		current = current.get_parent()
	return null


func _hidden_group_path(node: Node) -> String:
	var current := node
	var highest_hidden := node
	while current != null:
		if current is Node3D and not (current as Node3D).visible:
			highest_hidden = current
		current = current.get_parent()
	if highest_hidden == node and node.get_parent() != null:
		highest_hidden = node.get_parent()
	return str(highest_hidden.get_path())
