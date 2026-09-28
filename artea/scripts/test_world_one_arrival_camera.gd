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
	var floor_query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * 3.0,
		player.global_position + Vector3.DOWN * 5.0)
	floor_query.collision_mask = 1
	floor_query.exclude = [player.get_rid()]
	var floor_hit := world.get_world_3d().direct_space_state.intersect_ray(floor_query)
	assert(not floor_hit.is_empty() and (floor_hit.normal as Vector3).y > 0.8,
		"arrival aisle provides a level collision-backed floor")
	var toward_station: Vector3 = camera.global_position.direction_to(station.global_position)
	assert(forward.dot(toward_station) > 0.80,
		"arrival camera presents the first quest station in front of the player")
	print("WORLD_ONE_ARRIVAL_CAMERA_TEST: PASS — distance %.2f m, station alignment %.3f" \
		% [distance, forward.dot(toward_station)])
	gallery.queue_free()
	await process_frame
	quit(0)
