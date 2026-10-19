extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("TRAIN_STATION_PHYSICALITY_TEST: %s" % message)
	quit(1)


func _gate_clear(space: PhysicsDirectSpaceState3D, train: Node3D,
		gate_z: float) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	var start := train.to_global(Vector3(-8.75, 2.4, gate_z))
	var finish := train.to_global(Vector3(0.0, 2.4, gate_z))
	query.transform = Transform3D(Basis.IDENTITY, start)
	query.motion = finish - start
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var travel := space.cast_motion(query)
	return not travel.is_empty() and travel[0] >= 0.95


func _run() -> void:
	var world := Node3D.new()
	world.name = "ArtCastleFloatingWorld"
	root.add_child(world)
	var player := CharacterBody3D.new()
	player.name = "Player3D"
	var player_shape := CollisionShape3D.new()
	var player_capsule := CapsuleShape3D.new()
	player_capsule.radius = 0.5
	player_capsule.height = 1.8
	player_shape.shape = player_capsule
	player.add_child(player_shape)
	world.add_child(player)
	var railway := Node3D.new()
	railway.name = "StoryCrownRailway"
	railway.set_script(load("res://scripts/art_castle_story_railway.gd"))
	world.add_child(railway)
	for _frame in 4:
		await physics_frame

	for station_index in 4:
		var station_id: String = ["gallery", "mind", "heart", "creator"][station_index]
		var station := railway.get_node("StoryStations/Station_%02d_%s" % [
			station_index + 1, station_id]) as Node3D
		if String(station.get_meta("physicality_policy", "")).is_empty():
			_fail("station %d has no explicit physicality policy" % (station_index + 1))
			return
		var structure := station.get_node("FloatingDockStructure") as Node3D
		if structure.get_node_or_null("SuspendedFoundationCollision") == null:
			_fail("station %d floating foundation is still a ghost mesh" % (station_index + 1))
			return
		var supports := station.get_node(
			"BioMagitechPavilion/BranchingSupportColumns") as Node3D
		if supports.find_children(
				"LivingColumn_*Collision", "StaticBody3D", false, false).size() != 4:
			_fail("station %d roof columns are not physically touchable" % (station_index + 1))
			return
		var canopy := station.get_node(
			"BioMagitechPavilion/LivingCrystalCanopy") as Node3D
		if canopy.find_children(
				"SolarGlassPetal_*Collision", "StaticBody3D", false, false).size() != 12:
			_fail("station %d roof petals do not support landing players" % (station_index + 1))
			return
		for planter_name in ["CrystalPlanter_L", "CrystalPlanter_R"]:
			var planter := station.get_node("BioMagitechPavilion/%s" % planter_name) as Node3D
			if planter.find_children(
					"GrowthCrystal_*Collision", "StaticBody3D", false, false).size() != 3:
				_fail("station %d %s crystals are ghost objects" % [
					station_index + 1, planter_name])
				return
		if station_index == 1:
			if station.get_node_or_null("KingdomAccessSkybridge") != null \
					or station.get_node_or_null("AccessRamp") != null \
					or not bool(station.get_meta("long_access_bridge_removed", false)):
				_fail("Mind Spark station still contains the retired longest bridge")
				return
			var station_solids := station.get_node_or_null(
				"MindSparkStationVisibleObjectCollisions") as StaticBody3D
			if station_solids == null \
					or int(station_solids.get_meta("collision_shape_count", 0)) < 20:
				_fail("Mind Spark station forecourt objects are not comprehensively physical")
				return
		else:
			var bridge := station.get_node("KingdomAccessSkybridge") as Node3D
			for crystal_node in bridge.find_children(
					"AscentCrystalNode_*", "Node3D", false, false):
				if crystal_node.get_node_or_null("GardenPlinthCollision") == null \
						or crystal_node.get_node_or_null("WayfindingCrystalCollision") == null:
					_fail("station %d bridge crystal garden is not physical" % (station_index + 1))
					return

	var space := world.get_world_3d().direct_space_state
	var first_support := railway.get_node(
		"StoryStations/Station_01_gallery/BioMagitechPavilion/BranchingSupportColumns/" \
		+ "LivingColumn_L_00") as MeshInstance3D
	var ray := PhysicsRayQueryParameters3D.create(
		first_support.global_position + Vector3.RIGHT * 2.0,
		first_support.global_position - Vector3.RIGHT * 2.0, 1)
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or not String((hit.collider as Node).name).begins_with("LivingColumn_"):
		_fail("a real physics ray passes through a visible station column")
		return

	var train := railway.get_node("RainbowGalaxyTrain") as Node3D
	for gate_z in [-15.85, -8.35, 9.75]:
		if not _gate_clear(space, train, gate_z):
			_fail("player capsule cannot pass through train gate z=%.2f" % gate_z)
			return
	if String(railway.call("get_interaction_mode_for_position",
			railway.call("get_driver_interaction_position"))) != "drive":
		_fail("reachable driver position does not activate driving")
		return
	if String(railway.call("get_interaction_mode_for_position",
			railway.call("get_passenger_seat_position", 0))) != "sit":
		_fail("reachable passenger position does not activate seating")
		return

	print("TRAIN_STATION_PHYSICALITY_TEST: PASS — station solids are touchable and all three train gates remain reachable")
	quit()
