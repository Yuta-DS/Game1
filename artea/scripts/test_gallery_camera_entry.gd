extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	for _frame in 3:
		await process_frame
	await physics_frame
	var player := gallery.get_node("Player3D") as CharacterBody3D
	var camera := gallery.get_node("Camera3D") as Camera3D
	var focus := player.global_position + (camera.get("follow_look_at_offset") as Vector3)
	assert(camera.global_position.distance_to(focus) > 2.0,
		"the entry camera starts at a real third-person distance instead of inside the player or gallery floor")
	assert(camera.global_position.y > player.global_position.y,
		"the entry camera begins above the player before the first visible frame")
	var query := PhysicsPointQueryParameters3D.new()
	query.position = camera.global_position
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	assert(gallery.get_world_3d().direct_space_state.intersect_point(query, 8).is_empty(),
		"the snapped Castle Galaxy entry camera is not embedded in collision geometry")
	print("GalleryCameraEntry: PASS — first visible frame uses a collision-safe follow position")
	quit()
