extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var global := root.get_node("Global")
	global.auth_token = global.OFFLINE_GUEST_TOKEN
	assert(global.is_offline_guest() and not global.has_authenticated_session(),
		"the production guest sentinel is classified as an offline session")
	var start_source := FileAccess.get_file_as_string("res://start_screen.gd")
	var authentication_source := FileAccess.get_file_as_string("res://scripts/authentication.gd")
	assert(start_source.contains(
		"const WORLD_ONE_SCENE := \"res://scenes/art_gallery_3d_inprogress.tscn\""),
		"Offline Guest and standard login target the integrated World One scene")
	assert(authentication_source.contains(
		"const WORLD_ONE_SCENE := \"res://scenes/art_gallery_3d_inprogress.tscn\""),
		"the alternate authentication screen targets the integrated World One scene")
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 8:
		await process_frame
	await physics_frame

	var floating_world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var player := gallery.get_node("Player3D") as CharacterBody3D
	var list_request := gallery.get_node("GalleryManager/ListHTTPRequest") as HTTPRequest
	assert(list_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED,
		"Offline Guest never contacts the gallery API")
	var world_one := floating_world.get_node("MindSparkWorldOne") as MindSparkWorldOne
	assert(world_one != null, "the normal gallery scene owns World One directly")
	assert(world_one.get_parent() == floating_world)
	assert(world_one.position == Vector3(-2200.0, 0.0, 1640.0),
		"the nearby blueprint retains a safe void buffer from the Art Castle districts")
	assert(world_one.force_standalone_blueprint)
	assert(world_one.get_meta("foundation_mode") == "standalone_preview")
	var initial_landing := world_one.to_global(world_one.get_player_arrival_local())
	var spawn_offset := Vector2(
		player.global_position.x - initial_landing.x,
		player.global_position.z - initial_landing.z).length()
	assert(spawn_offset < 0.25,
		"the live character starts over World One's supported arrival apron: player=%s landing=%s" \
		% [str(player.global_position), str(initial_landing)])
	assert(world_one.has_node("WorldOneGeometry"),
		"World One is built before the character is relocated into it")
	var source_gate := floating_world.get_node("MindSparkWorldGate") as MindSparkWorldGate
	assert(source_gate != null and source_gate.gate_enabled,
		"the authored Mind Spark forecourt owns the World One gate")
	var route := floating_world.get_node("WalkRouteToMindSparkWorldGate") as Node3D
	assert(route.find_children("MindRoute_*", "MeshInstance3D", true, false).size() >= 50,
		"a cyan ground route leads from the gallery walkway to the World Gate")

	assert(source_gate.teleport_player(player), "the live source gate accepts the real player")
	var landing := floating_world.to_global(source_gate.destination_world_local)
	assert(player.global_position.distance_to(landing) < 0.25,
		"source gate arrives above Zone 01")
	var query := PhysicsRayQueryParameters3D.create(landing + Vector3.UP * 20.0, landing + Vector3.DOWN * 30.0)
	query.collision_mask = 1
	var hit := floating_world.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty(), "the player lands over Zone 01's collision-backed floor")
	var entry_return := world_one.get_node("WorldOneGeometry/01WorldGateLanding/EntryWorldGate") as MindSparkWorldGate
	assert(entry_return.teleport_player(player), "Zone 01 gate returns to the Art Castle forecourt")
	assert(player.global_position.distance_to(floating_world.to_global(Vector3(-650, 7, 1575))) < 0.25)
	assert(world_one.get_quest_objects().size() == 15, "all functional objects live on the six-island world")
	print("LIVE_MIND_SPARK_ENTRY_TEST: PASS — Art Castle gate enters full six-island World One and returns")
	quit()
