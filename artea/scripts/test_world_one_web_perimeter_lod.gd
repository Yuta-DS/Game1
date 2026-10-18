extends SceneTree

const WorldScene := preload("res://scenes/mind_spark/mind_spark_world_one.tscn")
const RailBay := preload("res://assets3D/mind_spark/echo_garden_benchmark/export/rail_bay.glb")
const RailBayWeb := preload("res://assets3D/mind_spark/echo_garden_benchmark/export/rail_bay_web.glb")
const RailPost := preload("res://assets3D/mind_spark/echo_garden_benchmark/export/rail_post.glb")
const RailPostWeb := preload("res://assets3D/mind_spark/echo_garden_benchmark/export/rail_post_web.glb")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bay_full := _scene_stats(RailBay)
	var bay_web := _scene_stats(RailBayWeb)
	var post_full := _scene_stats(RailPost)
	var post_web := _scene_stats(RailPostWeb)
	assert(int(bay_web.triangles) <= int(bay_full.triangles) * 0.21,
		"the Web scrollwork bay must remove at least 79 percent of source triangles")
	assert(int(post_web.triangles) <= int(post_full.triangles) * 0.22,
		"the Web perimeter post must remove at least 78 percent of source triangles")
	assert((bay_web.bounds as AABB).size.distance_to((bay_full.bounds as AABB).size) < 0.02 \
			and (post_web.bounds as AABB).size.distance_to((post_full.bounds as AABB).size) < 0.02,
		"Web perimeter modules must preserve the authored silhouettes and scale")

	OS.set_environment("ARTEA_FORCE_WEB_LOD", "1")
	var world := WorldScene.instantiate() as MindSparkWorldOne
	world.build_hud = false
	world.object_state_store_path = "user://test_world_one_web_perimeter_lod.json"
	root.add_child(world)
	await process_frame
	var island_one_repairs := world.get_node(
		"WorldOneGeometry/IslandOnePerimeterRepairs") as Node3D
	assert(bool(island_one_repairs.get_meta("web_low_poly_perimeter", false)),
		"Island One must also use the reduced Web railing kit")
	assert(island_one_repairs.find_children(
		"rail_bay", "MeshInstance3D", true, false).size() >= 20,
		"Island One must keep its exposed edge barrier")
	var repairs := world.get_node("WorldOneGeometry/IslandTwoPerimeterRepairs") as Node3D
	assert(bool(repairs.get_meta("web_low_poly_perimeter", false)),
		"Island Two must select its Web-only low-poly perimeter kit")
	var bays := repairs.find_children("rail_bay", "MeshInstance3D", true, false)
	var posts := repairs.find_children("rail_post", "MeshInstance3D", true, false)
	assert(bays.size() >= 30 and posts.size() >= 30,
		"the complete Island Two perimeter silhouette must remain authored")
	assert(_mesh_triangles((bays[0] as MeshInstance3D).mesh) <= 1200 \
			and _mesh_triangles((posts[0] as MeshInstance3D).mesh) <= 850,
		"live Web perimeter instances must use the reduced meshes")
	assert(repairs.find_children("RepairedBay_*", "MeshInstance3D", true, false).size() >= 100 \
			and repairs.find_children("RepairedBay_*Collision", "StaticBody3D", true, false).size() >= 100,
		"the independent invisible cliff boundary collision must remain complete")
	var island_three_repairs := world.get_node(
		"WorldOneGeometry/IslandThreePerimeterRepairs") as Node3D
	assert(bool(island_three_repairs.get_meta("web_low_poly_perimeter", false)),
		"Island Three must use the same reduced Web railing kit as Island Two")
	var island_three_bays := island_three_repairs.find_children(
		"rail_bay", "MeshInstance3D", true, false)
	var island_three_posts := island_three_repairs.find_children(
		"rail_post", "MeshInstance3D", true, false)
	assert(island_three_bays.size() >= 35 and island_three_posts.size() >= 35,
		"Island Three keeps the complete shared civic barrier silhouette on Web")
	assert(_mesh_triangles((island_three_bays[0] as MeshInstance3D).mesh) <= 1200 \
			and _mesh_triangles((island_three_posts[0] as MeshInstance3D).mesh) <= 850,
		"Island Three's shared barrier uses the reduced Web meshes")
	for crossing in ["02", "04"]:
		for segment in ["A", "B"]:
			var route_name := "CircuitRoute_%s_%s" % [crossing, segment]
			var route := world.get_node("WorldOneGeometry/MainStoryCircuitRoute") as Node3D
			var barrier := route.get_node_or_null(
				"%sCivicBarrier" % route_name) as Node3D
			assert(barrier != null and str(barrier.get_meta("barrier_style", "")) \
				== "island_one_two_civic_railing",
				"both exposed sky bridges must share the island railing style")
			assert(barrier.find_children("*CyanInset", "MeshInstance3D", true, false).size() >= 2 \
				and barrier.find_children("*CrossA", "MeshInstance3D", true, false).size() >= 2,
				"bridge barrier needs cyan piers and crossed gold rails on both sides")
			for side in ["Left", "Right"]:
				var old_rail := route.get_node("%s%sRail" % [route_name, side]) as MeshInstance3D
				var collision := route.get_node(
					"%s%sRailCollision" % [route_name, side]) as StaticBody3D
				assert(not old_rail.visible and collision != null \
					and ((collision.get_child(0) as CollisionShape3D).shape \
					as BoxShape3D).size.y >= 5.0,
					"styled bridge rails must keep tall fall-prevention collision")
	OS.set_environment("ARTEA_FORCE_WEB_LOD", "")
	if FileAccess.file_exists(world.object_state_store_path):
		DirAccess.remove_absolute(world.object_state_store_path)
	print("WORLD_ONE_WEB_PERIMETER_LOD: PASS — bay %d→%d triangles, post %d→%d; silhouette and collision preserved" % [
		int(bay_full.triangles), int(bay_web.triangles),
		int(post_full.triangles), int(post_web.triangles)])
	quit()


func _scene_stats(scene: PackedScene) -> Dictionary:
	var instance := scene.instantiate() as Node3D
	root.add_child(instance)
	var triangles := 0
	var bounds := AABB()
	var has_bounds := false
	for candidate in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		triangles += _mesh_triangles(mesh_instance.mesh)
		var relative := instance.global_transform.affine_inverse() * mesh_instance.global_transform
		var transformed: AABB = relative * mesh_instance.mesh.get_aabb()
		bounds = bounds.merge(transformed) if has_bounds else transformed
		has_bounds = true
	instance.queue_free()
	return {"triangles": triangles, "bounds": bounds}


func _mesh_triangles(mesh: Mesh) -> int:
	var triangles := 0
	if mesh == null:
		return triangles
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array and not indices.is_empty():
			triangles += indices.size() / 3
		else:
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			if vertices is PackedVector3Array:
				triangles += vertices.size() / 3
	return triangles
