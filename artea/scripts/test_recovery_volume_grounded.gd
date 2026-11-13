extends SceneTree

# The Mind causeway runs through the fall-recovery volumes under World One
# islands 04 and 05. Walking or jumping along it used to trigger a Milo rescue
# even though the player never fell.


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("RECOVERY_VOLUME_GROUNDED_TEST: %s" % message)
	quit(1)


func _run() -> void:
	change_scene_to_file("res://scenes/art_gallery_3d_inprogress.tscn")
	for i in 120:
		await physics_frame
	var scene := current_scene
	var space: PhysicsDirectSpaceState3D = (scene as Node3D).get_world_3d().direct_space_state
	var player := scene.get_node("Player3D") as CharacterBody3D
	var rescue := scene.get_node_or_null("MiloFallRescue")
	if rescue == null:
		_fail("no MiloFallRescue in the gallery")
		return
	for zone_name in ["04HopePathRidge", "05ThoughtStormArena"]:
		var volume := scene.find_child(zone_name, true, false).get_node("PerimeterRecoveryVolume") as Area3D
		var shape := volume.get_child(0) as CollisionShape3D
		var size := (shape.shape as BoxShape3D).size
		var floor_point := Vector3.INF
		for gx in range(-10, 11):
			for gz in range(-10, 11):
				var from := shape.global_position + Vector3(gx * size.x / 22.0, size.y * 0.5, gz * size.z / 22.0)
				var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * size.y)
				query.exclude = [player.get_rid()]
				var hit: Dictionary = space.intersect_ray(query)
				if not hit.is_empty() and hit.normal.y > 0.9 \
						and str(scene.get_path_to(hit.collider)).contains("Causeway"):
					floor_point = hit.position
					break
			if floor_point != Vector3.INF:
				break
		if floor_point == Vector3.INF:
			_fail("no causeway floor inside %s's recovery volume" % zone_name)
			return
		# Standing, then mid-jump: entering the volume airborne just above the
		# deck is what crossing its edge during a jump looks like.
		for case in [["standing on", 1.2, 0.0], ["jumping above", 3.0, 4.0]]:
			player.global_position = floor_point + Vector3(0, 300, 0)
			for i in 5:
				await physics_frame
			var before: int = rescue.get_rescue_count()
			player.global_position = floor_point + Vector3(0, case[1], 0)
			player.velocity = Vector3(0, case[2], 0)
			for i in 150:
				await physics_frame
			if rescue.get_rescue_count() != before:
				_fail("%s the causeway inside %s triggered a rescue" % [case[0], zone_name])
				return
	print("RECOVERY_VOLUME_GROUNDED_TEST: PASS")
	quit()
