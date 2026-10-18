extends SceneTree

const FLOATING_WORLD := "res://scenes/art_castle_floating_world.tscn"
const KINGDOM_REGIONS := "res://scripts/art_castle_kingdom_regions.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	OS.set_environment("ARTEA_FORCE_WEB_LOD", "1")
	var world := (load(FLOATING_WORLD) as PackedScene).instantiate() as Node3D
	root.add_child(world)
	for _frame in 3:
		await physics_frame
	for district_name in ["CentralSanctuary", "ArrivalIsland",
			"MindSparkDistrict", "HeartMelodyTemple", "CreatorsLightStudio",
			"NorthObservatory", "EastObservatory"]:
		var district := world.get_node(district_name) as Node3D
		var guards := district.find_children("*EdgeRailing", "Node3D", false, false)
		if guards.size() != 1 or int(guards[0].get_meta("bay_count", 0)) < 30:
			_fail("missing continuous civic edge on " + district_name)
			return
	var arrival := world.get_node("ArrivalIsland") as Node3D
	if not _ray_hits_guard(arrival, Vector3(-147, 2, 820), Vector3(-164, 2, 820)):
		_fail("unguarded west edge on the arrival island")
		return
	if _ray_hits_guard(arrival, Vector3(0, 2, 965), Vector3(0, 2, 990)):
		_fail("arrival railing closes the Tree Court bridge")
		return
	var mind := world.get_node("MindSparkDistrict") as Node3D
	if _ray_hits_guard(mind, Vector3(-765, 2, 1640),
			Vector3(-785, 2, 1640)):
		_fail("Mind Spark railing closes the Crown Line station stair")
		return
	world.queue_free()
	await process_frame

	var regions := Node3D.new()
	regions.set_script(load(KINGDOM_REGIONS))
	root.add_child(regions)
	for _frame in 3:
		await physics_frame
	for kingdom_name in ["MindKingdom3000m", "HeartKingdom3000m",
			"CreatorKingdom3000m"]:
		var kingdom := regions.get_node(kingdom_name) as Node3D
		var land := kingdom.get_node("OptimizedLandmass") as Node3D
		var shelf_guards := land.get_node("CivicShelfEdgeGuards") as Node3D
		var bridge_grid := land.get_node("InterIslandBridgeGrid") as Node3D
		if shelf_guards.get_child_count() != 25:
			_fail("shelf edges missing on " + kingdom_name)
			return
		if int(bridge_grid.get_meta("bridge_count", 0)) != 40:
			_fail("bridge grid changed on " + kingdom_name)
			return
		var bridge := bridge_grid.get_node(
			"ShelfBridge_02_02_to_02_03") as Node3D
		if bridge.get_node_or_null("CivicBridgeRailing") == null:
			_fail("shared civic bridge visual missing on " + kingdom_name)
			return
		for side in ["Left", "Right"]:
			if (bridge.get_node("%sSafetyRail" % side) as MeshInstance3D).visible:
				_fail("old glass bridge wall still visible on " + kingdom_name)
				return
		var centre: Vector3 = {
			"MindKingdom3000m": Vector3(-3600, 0, 3940),
			"HeartKingdom3000m": Vector3(0, 0, 7640),
			"CreatorKingdom3000m": Vector3(3600, 0, 3940),
		}[kingdom_name]
		var rise := sin(2.0 * 1.7 + 2.0 * 0.9) * 18.0
		var surface_y := 1.0 + rise
		var east_edge_x := centre.x + 283.4
		if not _ray_hits_guard(shelf_guards,
				Vector3(east_edge_x - 8.0, surface_y + 2.0, centre.z + 90.0),
				Vector3(east_edge_x + 8.0, surface_y + 2.0, centre.z + 90.0)):
			_fail("unprotected central shelf edge on " + kingdom_name)
			return
		if _ray_hits_guard(shelf_guards,
				Vector3(east_edge_x - 8.0, surface_y + 2.0, centre.z),
				Vector3(east_edge_x + 8.0, surface_y + 2.0, centre.z)):
			_fail("shelf railing closes a bridge approach on " + kingdom_name)
			return
	OS.set_environment("ARTEA_FORCE_WEB_LOD", "")
	print("GALAXY_CIVIC_BARRIERS: PASS — island, shelf, bridge and route edges guarded; crossings open")
	quit()


func _ray_hits_guard(owner: Node3D, from: Vector3, to: Vector3) -> bool:
	var space := owner.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	return not hit.is_empty() and str(hit.collider.get_path()).contains("InvisibleEdgeGuard")


func _fail(message: String) -> void:
	push_error("GALAXY_CIVIC_BARRIERS: " + message)
	quit(1)
