extends SceneTree


func _visual_bounds(player: CharacterBody3D) -> AABB:
	var initialized := false
	var bounds := AABB()
	for candidate in player.get_node("RogueSkin").find_children(
			"*", "MeshInstance3D", true, false):
		var mesh_node := candidate as MeshInstance3D
		if mesh_node.mesh == null or not mesh_node.visible:
			continue
		var world_bounds := mesh_node.global_transform * mesh_node.mesh.get_aabb()
		if not initialized:
			bounds = world_bounds
			initialized = true
		else:
			bounds = bounds.merge(world_bounds)
	return bounds


func _run() -> void:
	var floor_mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(20.0, 1.0, 20.0)
	floor_mesh.mesh = box_mesh
	floor_mesh.position.y = -0.5
	root.add_child(floor_mesh)
	var floor_body := StaticBody3D.new()
	floor_mesh.add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box_mesh.size
	floor_shape.shape = box_shape
	floor_body.add_child(floor_shape)

	var player := (load("res://scenes/entities/NewPlayer.tscn") as PackedScene).instantiate() \
		as CharacterBody3D
	root.add_child(player)
	player.global_position = Vector3(0.0, 5.0, 0.0)
	for _frame in 180:
		await physics_frame
		if player.is_on_floor():
			break
	var animation_player := player.get_node(
		"RogueSkin/AnimationPlayer") as AnimationPlayer
	var sampled := 0
	for animation_name in ["Idle", "Walk", "Run"]:
		if animation_player.has_animation(animation_name):
			sampled += 1
			animation_player.play(animation_name)
			for _frame in 20:
				await process_frame
			var bounds := _visual_bounds(player)
			print("PLAYER_GROUND_BOUNDS %s origin_y=%.3f bottom=%.3f top=%.3f skin_y=%.3f"
				% [animation_name, player.global_position.y, bounds.position.y,
					bounds.end.y, (player.get_node("RogueSkin") as Node3D).position.y])
			if bounds.position.y < -0.015:
				push_error("PLAYER_GROUND_ALIGNMENT: %s body enters floor by %.3f m"
					% [animation_name, -bounds.position.y])
				quit(1)
				return
			# A few millimetres is mathematically above the plane but still depth-
			# clips at gameplay distance once the skinned feet animate. Require a
			# small readable clearance so the entire boot renders on top.
			if bounds.position.y < 0.035:
				push_error("PLAYER_GROUND_ALIGNMENT: %s feet have only %.3f m clearance"
					% [animation_name, bounds.position.y])
				quit(1)
				return
			if bounds.position.y > 0.09:
				push_error("PLAYER_GROUND_ALIGNMENT: %s feet float %.3f m above floor"
					% [animation_name, bounds.position.y])
				quit(1)
				return
	if sampled < 2:
		push_error("PLAYER_GROUND_ALIGNMENT: locomotion animations did not load")
		quit(1)
		return
	print("PLAYER_GROUND_ALIGNMENT: PASS — visible feet remain on top of the floor")
	quit()


func _init() -> void:
	call_deferred("_run")
