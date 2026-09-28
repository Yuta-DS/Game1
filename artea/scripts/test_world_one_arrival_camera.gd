extends SceneTree

const GALLERY_SCENE := preload("res://scenes/art_gallery_3d_inprogress.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery := GALLERY_SCENE.instantiate()
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
	var toward_station: Vector3 = camera.global_position.direction_to(station.global_position)
	assert(forward.dot(toward_station) > 0.80,
		"arrival camera presents the first quest station in front of the player")
	print("WORLD_ONE_ARRIVAL_CAMERA_TEST: PASS — distance %.2f m, station alignment %.3f" \
		% [distance, forward.dot(toward_station)])
	gallery.queue_free()
	await process_frame
	quit(0)
