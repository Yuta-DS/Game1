extends SceneTree

const GALLERY_SCENE_PATH := "res://scenes/art_gallery_3d_inprogress.tscn"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# Load after SceneTree autoloads are registered. Preloading this large scene
	# while the --script runner itself is still parsing makes scripts that refer
	# to Global and MusicManager report false compile errors in headless CI.
	var gallery_scene := load(GALLERY_SCENE_PATH) as PackedScene
	var gallery := gallery_scene.instantiate()
	root.add_child(gallery)
	for _frame in 12:
		await process_frame
	await physics_frame
	var player := gallery.get_node("Player3D") as CharacterBody3D
	var camera := gallery.get_node("Camera3D") as Camera3D
	var world := gallery.get_node("ArtCastleFloatingWorld/MindSparkWorldOne") as MindSparkWorldOne
	var arrival := world.to_global(world.get_player_arrival_local())
	assert(Vector2(player.global_position.x - arrival.x,
		player.global_position.z - arrival.z).length() < 0.25,
		"the camera check uses the production World One arrival")
	var focus: Vector3 = player.global_position + camera.follow_look_at_offset
	var distance: float = camera.global_position.distance_to(focus)
	assert(distance >= 10.0 and distance <= 24.0,
		"arrival camera snaps to a readable third-person distance: %.2f m" % distance)
	assert(camera.get_view_mode() == "third",
		"World One opens in third-person view")
	var forward: Vector3 = -camera.global_basis.z
	var station: Node3D
	for object in world.get_quest_objects():
		if object.save_id == "world_one.checkpoint.landing":
			station = object
			break
	assert(station != null, "World One exposes its arrival quest station")
	var station_distance := Vector2(
		player.global_position.x - station.global_position.x,
		player.global_position.z - station.global_position.z).length()
	assert(station_distance >= 18.0 and station_distance <= 30.0,
		"arrival keeps the player out of the crowded operator pocket while the first station remains nearby: %.2f m" \
		% station_distance)
	var arrival_architecture := world.get_node(
		"WorldOneGeometry/01WorldGateLanding/CelestialWorldGateArrival") as Node3D
	var west_tower := arrival_architecture.get_node(
		"GateArchitectureKit/04_BeaconTowerKit/WestAetherLanternTower") as Node3D
	var east_tower := arrival_architecture.get_node(
		"GateArchitectureKit/04_BeaconTowerKit/EastAetherLanternTower") as Node3D
	var nearest_tower_clearance := minf(
		Vector2(player.global_position.x - west_tower.global_position.x,
			player.global_position.z - west_tower.global_position.z).length(),
		Vector2(player.global_position.x - east_tower.global_position.x,
			player.global_position.z - east_tower.global_position.z).length())
	assert(nearest_tower_clearance >= 32.0,
		"arrival vista must clear both lantern towers instead of opening beside a cropped plinth: %.2f m" \
		% nearest_tower_clearance)
	var compass := arrival_architecture.get_node("CompassMachine") as Node3D
	var compass_clearance := Vector2(
		player.global_position.x - compass.global_position.x,
		player.global_position.z - compass.global_position.z).length()
	assert(compass_clearance >= 27.0,
		"arrival must sit beyond the 24 m compass dais so its rings and conduits do not cross the camera: %.2f m" \
		% compass_clearance)
	var floor_query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * 3.0,
		player.global_position + Vector3.DOWN * 5.0)
	floor_query.collision_mask = 1
	floor_query.exclude = [player.get_rid()]
	var floor_hit := world.get_world_3d().direct_space_state.intersect_ray(floor_query)
	assert(not floor_hit.is_empty() and (floor_hit.normal as Vector3).y > 0.8,
		"arrival aisle provides a level collision-backed floor")
	var toward_compass: Vector3 = camera.global_position.direction_to(compass.global_position)
	assert(forward.dot(toward_compass) > 0.92,
		"arrival camera directly presents the Signal Observatory route")
	var return_gate := world.get_node(
		"WorldOneGeometry/01WorldGateLanding/EntryWorldGate") as Node3D
	var toward_return_gate := camera.global_position.direction_to(return_gate.global_position)
	print("WORLD_ONE_ARRIVAL_CAMERA: camera=%s gate=%s backward_alignment=%.3f" % [
		camera.global_position, return_gate.global_position, forward.dot(toward_return_gate)])
	assert(forward.dot(toward_return_gate) < -0.45,
		"the return portal and threshold remain behind the opening camera")
	print("WORLD_ONE_ARRIVAL_CAMERA_TEST: PASS — distance %.2f m, route alignment %.3f" \
		% [distance, forward.dot(toward_compass)])
	gallery.queue_free()
	await process_frame
	quit(0)
