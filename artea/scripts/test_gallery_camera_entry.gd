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
	assert(float(camera.get("collision_radius")) >= 0.5,
		"the follow camera sweeps a volume wide enough to protect its visible aperture")
	var query := PhysicsPointQueryParameters3D.new()
	query.position = camera.global_position
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	assert(gallery.get_world_3d().direct_space_state.intersect_point(query, 8).is_empty(),
		"the snapped Castle Galaxy entry camera is not embedded in collision geometry")
	var clearance_shape := SphereShape3D.new()
	clearance_shape.radius = float(camera.get("collision_radius")) * .85
	var clearance_query := PhysicsShapeQueryParameters3D.new()
	clearance_query.shape = clearance_shape
	clearance_query.transform = Transform3D(Basis.IDENTITY, camera.global_position)
	clearance_query.collision_mask = 1
	clearance_query.exclude = [player.get_rid()]
	assert(gallery.get_world_3d().direct_space_state.intersect_shape(
		clearance_query, 8).is_empty(),
		"the first visible frame keeps a clear volume around the camera aperture")
	var world_one := gallery.get_node(
		"ArtCastleFloatingWorld/MindSparkWorldOne") as MindSparkWorldOne
	player.global_position = world_one.to_global(
		world_one.get_zone_position("03_constellation_court") + Vector3.UP * 3.0)
	player.velocity = Vector3.ZERO
	for _frame in 90:
		await process_frame
	clearance_query.transform = Transform3D(Basis.IDENTITY, camera.global_position)
	assert(gallery.get_world_3d().direct_space_state.intersect_shape(
		clearance_query, 8).is_empty(),
		"a long World One story teleport preserves camera-volume clearance")
	print("GalleryCameraEntry: PASS — first visible frame uses a volume-safe follow position")
	quit()
