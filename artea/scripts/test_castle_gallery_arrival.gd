extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("CASTLE_GALLERY_ARRIVAL_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var hub := Node3D.new()
	hub.name = "CastleEntranceTestHub"
	root.add_child(hub)
	current_scene = hub
	var castle := Node3D.new()
	castle.name = "building_castle_red2"
	hub.add_child(castle)
	var door := Area3D.new()
	door.name = "Art_Gallery"
	door.set_script(load("res://scripts/teleport_Art_Gallery.gd"))
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = BoxShape3D.new()
	door.add_child(collision)
	hub.add_child(door)
	var traveller := CharacterBody3D.new()
	traveller.name = "Player"
	hub.add_child(traveller)
	await process_frame
	door.call("_on_body_entered", traveller)

	var gallery: Node3D = null
	for _attempt in 300:
		await create_timer(0.1).timeout
		if current_scene != null \
				and current_scene.scene_file_path == "res://scenes/art_gallery_3d_inprogress.tscn":
			gallery = current_scene as Node3D
			break
	if gallery == null:
		_fail("walking through the castle door did not load the gallery")
		return
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	var entry := gallery.get_node_or_null("CastleGalleryEntry") as Marker3D
	if player == null or entry == null \
			or player.global_position.distance_to(entry.global_position) > 0.75:
		_fail("doorway arrival did not put the player inside the gallery")
		return
	var spawn := gallery.get_node_or_null("SpawnPoint") as Node3D
	if spawn == null or spawn.global_position.distance_to(entry.global_position) > 0.75 \
			or spawn.get_meta("world", "") != "gallery":
		_fail("gallery arrival did not update its spawn marker")
		return
	var floor_probe := PhysicsRayQueryParameters3D.create(
		entry.global_position + Vector3.UP * 2.0,
		entry.global_position + Vector3.DOWN * 3.0)
	var floor_hit: Dictionary = gallery.get_world_3d().direct_space_state.intersect_ray(floor_probe)
	if floor_hit.is_empty():
		_fail("gallery arrival has no collision-backed floor")
		return
	var global := root.get_node_or_null("Global")
	if global == null or str(global.pending_spawn_point) != "":
		_fail("the doorway arrival was not consumed")
		return
	print("CASTLE_GALLERY_ARRIVAL_TEST: PASS — entering the castle door loads the gallery and places the player inside")
	quit()
