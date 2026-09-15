extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed = load("res://milo_fullres.glb") as PackedScene
	assert(packed != null, "GLB failed Godot import")
	var model = packed.instantiate()
	root.add_child(model)
	await process_frame
	var skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	var player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(skeleton != null and player != null)
	assert(skeleton.get_bone_count() == 61)
	for side in ["L", "R"]:
		assert(skeleton.find_bone("thumb_cmc." + side) >= 0)
		for k in 3:
			assert(skeleton.find_bone("palm%d." % k + side) >= 0)
			assert(skeleton.find_bone("finger%d_mid." % k + side) >= 0)
		for digit in ["finger0", "finger1", "finger2", "thumb"]:
			assert(skeleton.find_bone(digit + "." + side) >= 0)
			assert(skeleton.find_bone(digit + "_tip." + side) >= 0)
	var report := {}
	var colored_paws := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if not node.name.begins_with("Milo_Articulated_Paw"): continue
		colored_paws += 1
		for surface in node.mesh.get_surface_count():
			var colors = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			var material = node.mesh.surface_get_material(surface)
			assert(colors != null and colors.size() > 0 and material.vertex_color_use_as_albedo, "Paw colors disabled after import")
	assert(colored_paws == 2)
	report["paw_vertex_colors"] = {"passed": true, "paws": colored_paws}
	for clip in ["Idle", "Walking_A", "Greet", "Guide", "Speak", "Cane_Hold", "Hand_Mechanics"]:
		assert(player.has_animation(clip), "Missing clip: " + clip)
		player.play(clip)
		player.advance(0)
		var animation := player.get_animation(clip)
		var samples := []
		var finger_angles := []
		for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
			player.seek(animation.length * fraction, true)
			player.advance(0)
			for index in skeleton.get_bone_count():
				var transform := skeleton.get_bone_global_pose(index)
				assert(transform.origin.is_finite() and transform.basis.is_finite())
			# glTF/Godot uses +Z forward. Anatomical hand-local +Z is palmar.
			if clip == "Idle":
				for side in ["L", "R"]:
					var hand_pose := skeleton.get_bone_global_pose(skeleton.find_bone("hand." + side))
					var thumb_pose := skeleton.get_bone_global_pose(skeleton.find_bone("thumb." + side))
					assert(hand_pose.basis.z.x * (-1.0 if side == "L" else 1.0) > 0.65, "Resting palm faces outward")
					assert((thumb_pose.origin - hand_pose.origin).z > 0.015, "Resting thumb faces backward")
			if clip == "Greet" and fraction == 0.5:
				var hand_pose := skeleton.get_bone_global_pose(skeleton.find_bone("hand.L"))
				assert(hand_pose.basis.z.z > 0.95, "Greeting shows hand back, not palm")
			if clip == "Cane_Hold":
				var hand_pose := skeleton.get_bone_global_pose(skeleton.find_bone("hand.R"))
				assert(-hand_pose.basis.z.z > 0.95, "Cane grip shows palm, not dorsal surface")
			var bone := skeleton.find_bone("hand.L" if clip != "Walking_A" else "foot.L")
			samples.append(skeleton.get_bone_global_pose(bone).origin)
			if clip == "Hand_Mechanics":
				finger_angles.append(skeleton.get_bone_pose_rotation(skeleton.find_bone("finger1_mid.L")))
		var distance := 0.0
		for sample in samples: distance = maxf(distance, sample.distance_to(samples[0]))
		if clip in ["Walking_A", "Greet", "Guide", "Speak"]:
			assert(distance > 0.02, "Clip has no meaningful joint motion: " + clip)
		report[clip] = {"duration": animation.length, "tracks": animation.get_track_count(), "sampled_joint_travel": distance}
		if clip == "Hand_Mechanics":
			var finger_rotation := 0.0
			for angle in finger_angles:
				finger_rotation = maxf(finger_rotation, (angle as Quaternion).angle_to(finger_angles[0]))
			# Short feline toes distribute curl over base, middle and tip.
			# This middle hinge moves from 4 to 14 degrees; the base also bends.
			assert(finger_rotation > deg_to_rad(8) and finger_rotation < deg_to_rad(12), "Feline toe curl differs from authored range")
			report[clip]["finger_hinge_rotation_deg"] = rad_to_deg(finger_rotation)
	# The redesigned eyes retain their own exported blink controls.
	player.play("Idle")
	player.advance(0)
	player.seek(0.0, true)
	player.advance(0)
	for side in ["L", "R"]:
		assert(skeleton.get_bone_pose_scale(skeleton.find_bone("eye." + side)).y > 0.99)
	player.seek(2.56, true)
	player.advance(0)
	var eye_scales := {}
	for side in ["L", "R"]:
		var vertical_scale := skeleton.get_bone_pose_scale(skeleton.find_bone("eye." + side)).y
		assert(vertical_scale < 0.4, "Redesigned eye does not blink")
		eye_scales[side] = vertical_scale
	report["face_blink"] = {"passed": true, "sample_time": 2.56, "vertical_scales": eye_scales}
	print("MILO_GODOT_IMPORT_PASS ", JSON.stringify(report))
	var evidence := FileAccess.open("res://godot_import_verification.json", FileAccess.WRITE)
	evidence.store_string(JSON.stringify(report, "\t"))
	evidence.close()
	model.queue_free()
	quit(0)
