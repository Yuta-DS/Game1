extends SceneTree

const WorldScene := preload("res://scenes/heart_melody/heart_garden_world.tscn")

func _init() -> void: call_deferred("_run")

func _run() -> void:
	var world := WorldScene.instantiate()
	world.persist_progress = false
	world.build_hud = false
	root.add_child(world)
	await process_frame
	var layout := world.get_node("HeartGardenLayout")
	var sectors := layout.find_children("Sector*", "Node3D", true, false)
	assert(sectors.size() == 12, "six cullable sectors per district")
	for sector in sectors:
		assert(sector.has_meta("heart_cull_sector") and sector.has_meta("district"))
	assert(world.ARRIVAL == Vector3(-88, 2, 0))
	assert(world.CLEARINGS == [Vector3(58, 0, -20), Vector3(74, 0, 18)])
	assert(world.get_route_segments().size() >= 20)
	assert(world._seed_shortcut.name == "SeedCanopyCutthrough")
	assert(world._bridge.name == "RestoredRootCrossing")
	assert(world.blooms.size() == 3 and world.drums.size() == 3,
		"three planters and three playable drum flowers")
	assert(world.find_child("AuthoredHeartGate", true, false) != null)
	assert(world.find_child("SongMemoryBench", true, false) != null)
	assert(world.find_child("ComfortLantern", true, false) != null)
	await physics_frame
	for point in [Vector3(-88, 4, 0), Vector3(-43, 4, 42), Vector3(-43, 4, -42),
		Vector3(42, 4, 46), Vector3(42, 4, -46), Vector3(94, 4, 0)]:
		var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 8.0)
		assert(not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
			"visible lobe surface has floor collision at %s" % point)
	var triangles := 0
	var surfaces := 0
	for item in world.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = item.mesh
		if mesh == null: continue
		surfaces += mesh.get_surface_count()
		for surface_index in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface_index)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if indices is PackedInt32Array and not indices.is_empty() else vertices.size()) / 3
	print("HEART_GARDEN_METRICS triangles=", triangles, " surfaces=", surfaces)
	assert(triangles <= 400000, "static triangle budget")
	assert(surfaces <= 550, "total modular surface budget")
	var peak_local_surfaces := 0
	for viewpoint in [Vector3(-88,2,0), Vector3(-24,2,19), Vector3(38,2,0),
		Vector3(58,2,-20), Vector3(74,2,18), Vector3(94,2,0)]:
		var local_surfaces := 0
		for item in world.find_children("*", "MeshInstance3D", true, false):
			if item.global_position.distance_to(viewpoint) <= 42.0 and item.mesh != null:
				local_surfaces += item.mesh.get_surface_count()
		peak_local_surfaces = maxi(peak_local_surfaces, local_surfaces)
	print("HEART_GARDEN_METRICS peak_local_surfaces=", peak_local_surfaces)
	assert(peak_local_surfaces <= 220, "gameplay-camera draw-call budget")
	var required_assets := ["oval_deck_sector", "faceted_cliff_sector", "arch_bay",
		"square_pier", "cornice_span", "gold_rail_span", "gold_rail_post",
		"root_buttress", "growing_vine_bridge", "heart_gate_arch", "heart_route_stone",
		"feeling_planter_a", "feeling_planter_b", "feeling_planter_c", "drum_leaf",
		"drum_sun", "drum_droplet", "listening_blossom", "comfort_lantern",
		"song_memory_bench", "faceted_tree_a", "faceted_tree_b", "flower_cluster",
		"shrub_cluster", "echo_moth_shell", "pulse_slime_shell"]
	for asset in required_assets:
		assert(FileAccess.file_exists("res://assets3D/heart_melody/island_one/glb/%s.glb" % asset))
		assert(FileAccess.file_exists("res://assets3D/heart_melody/island_one/source/%s.blend" % asset))
	print("HEART_GARDEN_ARCHITECTURE: PASS — 12 sectors, ", triangles,
		" triangles, ", surfaces, " surfaces and complete editable kit")
	quit()
