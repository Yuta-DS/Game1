extends SceneTree

const MILO_SCENE := preload("res://scenes/milo_animations.tscn")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("  FAIL: %s" % message)


func _run() -> void:
	var floor := StaticBody3D.new()
	floor.name = "MiloGroundingTestFloor"
	floor.collision_layer = 1
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(12.0, 0.10, 12.0)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.05
	floor.add_child(floor_shape)
	root.add_child(floor)
	var player := CharacterBody3D.new()
	player.name = "NewPlayer"
	player.add_to_group("player")
	player.position = Vector3(4.0, 0.0, 2.0)
	root.add_child(player)

	var milo := MILO_SCENE.instantiate() as CharacterBody3D
	milo.set("gravity_enabled", false)
	root.add_child(milo)
	await process_frame
	milo.call("set_companion_player", player, false)
	var locomotion_player := milo.find_child("AnimationPlayer", true, false) \
		as AnimationPlayer
	var cane_clip := locomotion_player.get_animation("Cane_Walk") \
		if locomotion_player != null else null
	_check(cane_clip != null and cane_clip.get_track_count() >= 20,
		"Milo loads the complete Blender-authored full-body walk")
	if cane_clip != null:
		var track_paths: Array[String] = []
		var free_upper_track := -1
		var head_rotation_track := -1
		for track_index in cane_clip.get_track_count():
			var track_path := str(cane_clip.track_get_path(track_index))
			track_paths.append(track_path)
			if track_path.ends_with(":upperarm.r") \
					and cane_clip.track_get_type(track_index) \
					== Animation.TYPE_ROTATION_3D:
				free_upper_track = track_index
			if track_path.ends_with(":head") \
					and cane_clip.track_get_type(track_index) \
					== Animation.TYPE_ROTATION_3D:
				head_rotation_track = track_index
			if cane_clip.track_get_type(track_index) == Animation.TYPE_ROTATION_3D:
				_check(cane_clip.track_get_interpolation_type(track_index) \
						== Animation.INTERPOLATION_LINEAR_ANGLE,
					"Blender rotations use smooth shortest-path interpolation")
			_check(track_path.begins_with(
				"MiloExactTargetRig/Skeleton3D:"),
				"Blender-authored tracks address Milo's live skeleton")
		for baked_arm_bone in ["upperarm.l", "lowerarm.l",
				"upperarm.r", "lowerarm.r", "hand.r"]:
			_check(track_paths.any(func(path: String) -> bool:
				return path.ends_with(":" + baked_arm_bone)),
				"the Blender clip drives Milo's baked %s track" % baked_arm_bone)
		_check(bool(cane_clip.get_meta("milo_blender_authored_walk", false)),
			"Milo uses the dedicated Blender-authored walk instead of a runtime hybrid")
		var cane_plant_pose: Dictionary = milo.call("_sample_cane_hand_pose", 0.0)
		var cane_lift_pose: Dictionary = milo.call("_sample_cane_hand_pose", 0.60)
		# Recovery still trails and flexes, but no longer drives the elbow into the
		# deep fold that split the continuous sleeve into two visible tiers.
		_check(float(cane_lift_pose.elbow_z) < -0.21 \
				and float(cane_plant_pose.elbow_z) > -0.18,
			"the cane elbow trails moderately during lift and extends for the next plant")
		_check(float(cane_lift_pose.reach) < float(cane_plant_pose.reach) - 0.018,
			"the cane arm keeps a gentle recovery flex without forming a sharp hinge")
		_check((cane_plant_pose.grip as Vector3).z \
				- (cane_lift_pose.grip as Vector3).z > 0.13,
			"the hand carries the handle forward with the recovering stick")
		if free_upper_track >= 0:
			var first_rotation := cane_clip.track_get_key_value(
				free_upper_track, 0) as Quaternion
			var largest_swing := 0.0
			for key_index in cane_clip.track_get_key_count(free_upper_track):
				var key_rotation := cane_clip.track_get_key_value(
					free_upper_track, key_index) as Quaternion
				largest_swing = maxf(largest_swing,
					rad_to_deg(first_rotation.angle_to(key_rotation)))
			_check(largest_swing > 12.0,
				"the free shoulder retains its authored walking arc")
			var last_rotation := cane_clip.track_get_key_value(free_upper_track,
				cane_clip.track_get_key_count(free_upper_track) - 1) as Quaternion
			_check(rad_to_deg(first_rotation.angle_to(last_rotation)) < 1.0,
				"the free-arm curve closes without a loop pop")
			var previous_sample := cane_clip.rotation_track_interpolate(
				free_upper_track, 0.0)
			var largest_frame_step := 0.0
			for sample_index in range(1, 61):
				var sample_time := cane_clip.length * float(sample_index) / 60.0
				var sample := cane_clip.rotation_track_interpolate(
					free_upper_track, sample_time)
				largest_frame_step = maxf(largest_frame_step,
					rad_to_deg(previous_sample.angle_to(sample)))
				previous_sample = sample
			_check(largest_frame_step < 8.0,
				"the free shoulder advances smoothly without a visible frame jump")
		_check(head_rotation_track >= 0 \
				and cane_clip.track_get_key_count(head_rotation_track) >= 24,
			"the head has a dense authored motion curve instead of a static mannequin pose")
		if head_rotation_track >= 0:
			var first_head := cane_clip.track_get_key_value(
				head_rotation_track, 0) as Quaternion
			var last_head := cane_clip.track_get_key_value(head_rotation_track,
				cane_clip.track_get_key_count(head_rotation_track) - 1) as Quaternion
			_check(rad_to_deg(first_head.angle_to(last_head)) < 1.0,
				"the stabilized head curve closes without a loop snap")
			var previous_head := cane_clip.rotation_track_interpolate(
				head_rotation_track, 0.0)
			var largest_head_step := 0.0
			for sample_index in range(1, 61):
				var sample_time := cane_clip.length * float(sample_index) / 60.0
				var sampled_head := cane_clip.rotation_track_interpolate(
					head_rotation_track, sample_time)
				largest_head_step = maxf(largest_head_step,
					rad_to_deg(previous_head.angle_to(sampled_head)))
				previous_head = sampled_head
			_check(largest_head_step < 3.0,
				"the head advances smoothly at 60 fps without a mannequin jerk")
		var gait_skeleton := milo.find_child("Skeleton3D", true, false) as Skeleton3D
		if gait_skeleton != null:
			var left_foot_bone := gait_skeleton.find_bone("foot.l")
			locomotion_player.play("Cane_Walk", 0.0)
			locomotion_player.seek(0.0, true)
			locomotion_player.advance(0.0)
			var heel_strike_z := gait_skeleton.get_bone_global_pose(
				left_foot_bone).origin.z
			locomotion_player.seek(cane_clip.length * 0.4375, true)
			locomotion_player.advance(0.0)
			var toe_off_z := gait_skeleton.get_bone_global_pose(
				left_foot_bone).origin.z
			var donor_foot_travel := absf(heel_strike_z - toe_off_z)
			var calibrated_root_travel := 0.88 * 0.4375
			_check(absf(donor_foot_travel - calibrated_root_travel) < 0.06,
				"root travel matches the donor stance foot instead of creating glide")
	_check(milo.find_child("LegIK_L", true, false) is TwoBoneIK3D \
			and milo.find_child("LegIK_R", true, false) is TwoBoneIK3D,
		"deterministic two-bone constraints ground both legs after animation")
	_check(milo.find_child("CaneArmIK", true, false) is SkeletonIK3D,
		"the complete cane arm follows the reachable handle with palm orientation")
	_check(milo.find_child("FreeArmIK", true, false) is TwoBoneIK3D,
		"the free shoulder, elbow and wrist follow an anatomical two-bone arc")
	var free_target_node := milo.find_child("MiloFreeWristTarget", true, false) \
		as Node3D
	var live_skeleton := milo.find_child("Skeleton3D", true, false) as Skeleton3D
	if free_target_node != null and live_skeleton != null and cane_clip != null:
		# Exercise the live locomotion owner; merely seeking Cane_Walk while Milo is
		# still in IDLE leaves the procedural wrist at its neutral side target.
		milo.call("_set_companion_state", 2) # FOLLOWING
		milo.velocity = Vector3(0.0, 0.0, 1.10)
		var right_foot_index := live_skeleton.find_bone("foot.r")
		var hips_index := live_skeleton.find_bone("hips")
		var arm_offsets: Array[float] = []
		var leg_offsets: Array[float] = []
		for phase in [0.0, 0.5]:
			locomotion_player.play("Cane_Walk", 0.0)
			locomotion_player.seek(cane_clip.length * phase, true)
			locomotion_player.advance(0.0)
			milo.set("_cane_cycle_time", phase * 1.28)
			milo.call("_update_secondary_motion", 1.0 / 60.0)
			var shoulder_world: Vector3 = milo.call(
				"_bone_world_position", "upperarm.r")
			arm_offsets.append(milo.to_local(free_target_node.global_position).z \
				- milo.to_local(shoulder_world).z)
			leg_offsets.append(
				live_skeleton.get_bone_global_pose(right_foot_index).origin.z \
				- live_skeleton.get_bone_global_pose(hips_index).origin.z)
		_check((arm_offsets[0] - arm_offsets[1]) \
			* (leg_offsets[0] - leg_offsets[1]) < 0.0,
			"the free arm counter-swings opposite its same-side leg")
	var grip_target := milo.find_child("MiloCaneGripTarget", true, false) as Node3D
	var cane_hook := milo.find_child("MayorCaneHook", true, false) as MeshInstance3D
	_check(grip_target != null and cane_hook != null,
		"the oriented hand target is built from the physical cane hook")
	_check(grip_target != null and grip_target.global_position.y > 0.54,
		"the fitted cane reaches a relaxed wrist height instead of locking the elbow")
	milo.set("_cane_cycle_time", 0.0)
	_check(float(milo.call("get_foot_contact_weight", "l")) > 0.45 \
			and float(milo.call("get_foot_contact_weight", "r")) < 0.05,
		"the left heel owns contact at the donor clip's first heel strike")
	milo.set("_cane_cycle_time", 0.50 * 1.28)
	_check(float(milo.call("get_foot_contact_weight", "r")) > 0.45 \
			and float(milo.call("get_foot_contact_weight", "l")) < 0.05,
		"the right heel owns contact at the opposing half-cycle heel strike")
	milo.set("_cane_cycle_time", 0.25 * 1.28)
	_check(float(milo.call("get_foot_contact_weight", "l")) > 0.95 \
			and float(milo.call("get_foot_contact_weight", "r")) < 0.05,
		"the left stance foot owns the first supported half-stride")
	_check(float(milo.call("get_cane_contact_weight")) > 0.95,
		"the cane is planted with the contralateral left stance foot")
	milo.call("_set_companion_state", 2) # FOLLOWING
	milo.velocity = Vector3(0.0, 0.0, 1.10)
	milo.set("_cane_cycle_time", 0.25 * 1.28)
	for _frame in 4:
		milo.call("_update_secondary_motion", 1.0 / 60.0)
		milo.call("_update_terrain_grounding", 1.0 / 60.0)
	milo.set("_cane_cycle_time", 0.46 * 1.28)
	milo.call("_update_secondary_motion", 1.0 / 60.0)
	milo.call("_update_terrain_grounding", 1.0 / 60.0)
	var recovery_start_tip: Vector3 = milo.call("_cane_tip_world_position")
	milo.set("_cane_cycle_time", 0.90 * 1.28)
	for _frame in 4:
		milo.call("_update_secondary_motion", 1.0 / 60.0)
		milo.call("_update_terrain_grounding", 1.0 / 60.0)
	var recovery_end_tip: Vector3 = milo.call("_cane_tip_world_position")
	_check(milo.to_local(recovery_end_tip).z \
			> milo.to_local(recovery_start_tip).z + 0.025,
		"the released cane swings forward to its next contact instead of backward")
	milo.set_physics_process(false)
	milo.set_process(false)
	await _check_cane_recovery_cycle(player)
	milo.call("_reset_cane_gait")
	milo.call("_advance_cane_gait", 0.10, 1.40)
	_check(absf(float(milo.call("get_gait_phase")) - 0.1591) < 0.002,
		"gait phase advances from real distance calibrated to donor foot travel")

	for side in ["L", "R"]:
		for prefix in ["PrototypeEyeWhite", "EyelidHalf", "EyelidClosed",
				"Pupil", "PrototypeBrow", "PrototypeMoustache"]:
			_check(milo.find_child("%s_%s" % [prefix, side], true, false) != null,
				"the live face includes %s_%s" % [prefix, side])
	_check(str(milo.call("get_blink_shape")) == "relaxed",
		"Milo begins with a relaxed open gaze")
	milo.call("trigger_blink")
	milo.call("_update_eye_animation", 0.02)
	_check(str(milo.call("get_blink_shape")) == "half",
		"blink closes through a half-lid anticipation")
	milo.call("_update_eye_animation", 0.06)
	_check(str(milo.call("get_blink_shape")) == "closed",
		"blink reaches a fully closed readable lid")
	milo.call("_update_eye_animation", 0.08)
	_check(str(milo.call("get_blink_shape")) == "half",
		"blink opens through the same soft intermediate shape")
	milo.call("_update_eye_animation", 0.06)
	_check(str(milo.call("get_blink_shape")) == "relaxed",
		"blink restores the neutral eye without stacked cards")

	for _frame in 45:
		milo.call("_update_eye_animation", 1.0 / 60.0)
	var gaze_offset: Vector3 = milo.call("get_gaze_offset")
	_check(absf(gaze_offset.x) > 0.001,
		"the iris gently focuses toward an off-centre player")
	_check(absf(gaze_offset.x) <= 0.0101 and absf(gaze_offset.z) <= 0.0061,
		"player focus remains subtle instead of becoming sliding doll eyes")

	var shadow := milo.get_node_or_null("MiloContactShadow") as MeshInstance3D
	_check(shadow != null and shadow.mesh is QuadMesh,
		"a dedicated soft contact shadow grounds Milo's shoes")
	_check(shadow != null and shadow.cast_shadow \
		== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"the contact patch cannot create a second hard shadow")
	var cane_shadow := milo.get_node_or_null("MiloCaneContactShadow") \
		as MeshInstance3D
	_check(cane_shadow != null and cane_shadow.mesh is QuadMesh,
		"a second soft patch grounds the cane tip")
	_check(cane_shadow != null and cane_shadow.position.x > 0.48,
		"the cane contact patch stays aligned beneath the authored right-side tip")

	# Sample a quarter-stride where weight has moved visibly across the body.
	milo.set_physics_process(false)
	milo.call("_set_companion_state", 2) # FOLLOWING
	milo.velocity = Vector3(1.0, 0.0, 0.0)
	milo.set("_cane_cycle_time", 0.29)
	locomotion_player.play("Cane_Walk")
	locomotion_player.seek(0.27, true)
	locomotion_player.advance(0.0)
	locomotion_player.pause()
	for _frame in 12:
		milo.call("_update_secondary_motion", 1.0 / 60.0)
		milo.call("_update_terrain_grounding", 1.0 / 60.0)
	# Skeleton modifiers resolve after the authored animation pose. Give the
	# constraints several rendered frames to settle after this intentionally
	# discontinuous test seek before measuring the evaluated bones.
	for _modifier_frame in 6:
		await process_frame
	var left_leg_ik := milo.find_child("LegIK_L", true, false) as TwoBoneIK3D
	var cane_arm_ik := milo.find_child("CaneArmIK", true, false) as SkeletonIK3D
	var free_arm_ik := milo.find_child("FreeArmIK", true, false) as TwoBoneIK3D
	_check(left_leg_ik != null and left_leg_ik.get_influence() > 0.5,
		"the planted stance leg is constrained to real floor geometry")
	_check(cane_arm_ik != null and cane_arm_ik.get_influence() > 0.5,
		"the cane hand stays constrained to its moving grip during support")
	_check(free_arm_ik != null and free_arm_ik.get_influence() > 0.5,
		"the free arm uses its stable anatomical solver while walking")
	var free_elbow_flex := float(milo.call("get_free_elbow_flex_degrees"))
	_check(free_elbow_flex >= 4.0 and free_elbow_flex <= 35.0,
		"the free elbow remains softly flexed without the sideways sleeve kink")
	var free_wrist: Vector3 = milo.call("get_free_wrist_world_position")
	var free_target: Vector3 = milo.call("get_free_wrist_target_world_position")
	_check(free_wrist.distance_to(free_target) < 0.045,
		"the visible free wrist follows its smooth shoulder-length arc")
	var cane_elbow_flex := float(milo.call("get_cane_elbow_flex_degrees"))
	_check(cane_elbow_flex >= 15.0 and cane_elbow_flex <= 45.0,
		"the cane elbow stays safely flexed around the clinical working target "
		+ "(%.2f degrees)" % cane_elbow_flex)
	var cane_elbow_pole := milo.find_child("MiloCaneElbowPole", true, false) \
		as Node3D
	if cane_elbow_pole != null:
		var cane_shoulder_world: Vector3 = milo.call(
			"_cane_chain_world_position", "upperarm.l")
		var pole_offset := milo.global_transform.basis.inverse() \
			* (cane_elbow_pole.global_position - cane_shoulder_world)
		_check(absf(pole_offset.x) <= 0.04 and pole_offset.z < -0.14,
			"the cane elbow bends backward with only minimal sideways coat clearance")
	var free_elbow_pole := milo.find_child("MiloFreeElbowPole", true, false) \
		as Node3D
	if free_elbow_pole != null:
		var free_shoulder_world: Vector3 = milo.call(
			"_free_chain_world_position", "upperarm.r")
		var free_pole_offset := milo.global_transform.basis.inverse() \
			* (free_elbow_pole.global_position - free_shoulder_world)
		_check(absf(free_pole_offset.x) <= 0.04 and free_pole_offset.z < -0.14,
			"the free elbow bends backward instead of flaring sideways")
	var cane_paw_grip: Vector3 = milo.call("get_cane_paw_grip_world_position")
	var physical_grip: Vector3 = milo.call("_cane_hook_world_position")
	_check(cane_paw_grip.distance_to(physical_grip) < 0.025,
		"the visible cane-paw grip remains physically attached to the handle")
	var walk_offset: Vector3 = milo.call("get_secondary_motion_offset")
	var foot_offset: Vector3 = milo.call("get_left_foot_motion_offset")
	var left_thigh: Vector3 = milo.call("get_rig_bone_pose_angle", "upperleg.l")
	var right_thigh: Vector3 = milo.call("get_rig_bone_pose_angle", "upperleg.r")
	var left_knee: Vector3 = milo.call("get_rig_bone_pose_angle", "lowerleg.l")
	var right_knee: Vector3 = milo.call("get_rig_bone_pose_angle", "lowerleg.r")
	var cane_arm: Vector3 = milo.call("get_rig_bone_pose_angle", "upperarm.l")
	var free_arm: Vector3 = milo.call("get_rig_bone_pose_angle", "upperarm.r")
	_check(walk_offset.length() < 0.001,
		"the native NPC clip owns body weight transfer without a second root wobble")
	_check(foot_offset.length() < 0.001,
		"skinned shoes stay attached to the rig instead of moving as whole meshes")
	_check(left_thigh.distance_to(right_thigh) > 8.0,
		"NPC leg curves retarget as an alternating stride on Milo")
	_check(maxf(left_knee.length(), right_knee.length()) > 8.0,
		"the NPC recovery curve folds one knee instead of leaving rigid legs")
	var loaded_pose: Dictionary = milo.call("_sample_cane_hand_pose", 0.12)
	var recovery_pose: Dictionary = milo.call("_sample_cane_hand_pose", 0.75)
	_check((loaded_pose.grip as Vector3).distance_to(recovery_pose.grip) > 0.06,
		"the authored cane hand travels visibly from loaded support into recovery")
	_check(cane_arm.length() > 2.0 and free_arm.length() > 2.0,
		"both complete arm chains retain evaluated walking movement")
	var walking_curls: Dictionary = milo.call("get_hand_curl_amounts")
	_check(float(walking_curls.get("Paw_R", 0.0)) > 0.65,
		"the visible cane paw keeps a secure whole-hand grip while walking")
	_check(float(walking_curls.get("Paw_L", 1.0)) < 0.35,
		"the free paw remains relaxed enough to counter-swing")

	milo.call("_set_companion_state", 1) # IDLE_NEAR_PLAYER
	milo.velocity = Vector3.ZERO
	locomotion_player.play("Idle_3", 0.0)
	for _frame in 90:
		milo.call("_update_secondary_motion", 1.0 / 60.0)
		milo.call("_update_terrain_grounding", 1.0 / 60.0)
	# Let AnimationPlayer's 0.22 s cross-fade and both arm modifiers finish in
	# real frame time; tight update calls alone do not advance the animation clock.
	for _modifier_frame in 20:
		await process_frame
	var settled_offset: Vector3 = milo.call("get_secondary_motion_offset")
	var settled_foot: Vector3 = milo.call("get_left_foot_motion_offset")
	_check(absf(settled_offset.x) < 0.001 and absf(settled_offset.y) < 0.006,
		"body weight settles cleanly back into the breathing idle")
	_check(settled_foot.length() < 0.001,
		"both feet return to their authored planted pose after walking")
	var idle_cane_shoulder: Vector3 = milo.call(
		"_cane_chain_world_position", "upperarm.l")
	var idle_cane_wrist: Vector3 = milo.call("get_cane_wrist_world_position")
	var idle_free_shoulder: Vector3 = milo.call(
		"_free_chain_world_position", "upperarm.r")
	var idle_free_wrist: Vector3 = milo.call("get_free_wrist_world_position")
	_check(cane_arm_ik.get_influence() > 0.95
			and idle_cane_wrist.y < idle_cane_shoulder.y - 0.12,
		"the idle cane arm remains down on the stick instead of sweeping overhead")
	_check(free_arm_ik.get_influence() > 0.95
			and idle_free_wrist.y < idle_free_shoulder.y - 0.12,
		"the free arm returns smoothly to a relaxed side pose after walking")
	_check(milo.to_local(idle_free_wrist).x
			< milo.to_local(idle_free_shoulder).x - 0.15,
		"the relaxed free wrist keeps a visible gap from the coat")
	var idle_grip_error := (milo.call("get_cane_paw_grip_world_position") \
		as Vector3).distance_to(milo.call("_cane_hook_world_position") as Vector3)
	# The marker sits at the sculpted palm centre; the 3.4 cm hook offset remains
	# well inside the 17 cm-wide closed paw while still catching a detached fist.
	_check(idle_grip_error < 0.040,
		"the idle cane paw stays physically wrapped around the handle (%.3f m)" \
			% idle_grip_error)

	# The blueprint requires one sculpted object per hand. Exercise each hand's
	# single whole-hand deformation and prove both sides curl together.
	milo.call("_on_companion_speech_requested",
		"Let us explore this together.")
	for _frame in 18:
		milo.call("_update_speaking", 1.0 / 60.0)
		milo.call("_update_secondary_motion", 1.0 / 60.0)
	var hand_curls: Dictionary = milo.call("get_hand_curl_amounts")
	var curl_values: Array[float] = []
	for hand_name in ["Paw_L", "Paw_R"]:
		var hand_mesh := milo.find_child(hand_name, true, false) as MeshInstance3D
		_check(hand_mesh != null and hand_mesh.get_aabb().size.z \
				> hand_mesh.get_aabb().size.x * 1.35,
			"%s palm and finger row face outward toward Milo's side (bounds %s)" \
			% [hand_name, str(hand_mesh.get_aabb().size) if hand_mesh != null \
			else "missing"])
		_check(hand_curls.has(hand_name),
			"%s participates as one unified deforming object" % hand_name)
		if hand_curls.has(hand_name):
			var amount := float(hand_curls[hand_name])
			curl_values.append(amount)
			_check(amount > 0.45,
				"%s visibly curls its sculpted finger row" % hand_name)
	if curl_values.size() == 2:
		_check(absf(curl_values[0] - curl_values[1]) < 0.01,
			"both unified hand meshes curl simultaneously")

	milo.queue_free()
	player.queue_free()
	floor.queue_free()
	await process_frame
	if _failures > 0:
		push_error("MILO_NATURAL_ANIMATION_TEST: %d failure(s)" % _failures)
		quit(1)
		return
	print("MILO_NATURAL_ANIMATION_TEST: PASS — Blender full-body gait, stabilized head, readable two-hand motion, cane contact, grounding, blink, and smooth idle settling")
	quit()


func _check_cane_recovery_cycle(player: CharacterBody3D) -> void:
	# Use a fresh rig so earlier test seeks cannot contaminate the continuous
	# modifier trajectory. The former recovery compressed the elbow to 76 degrees
	# and turned the forearm more than 13 degrees in one rendered frame.
	var probe := MILO_SCENE.instantiate() as CharacterBody3D
	probe.set("gravity_enabled", false)
	root.add_child(probe)
	await process_frame
	probe.set_physics_process(false)
	probe.set_process(false)
	probe.call("set_companion_player", player, false)
	probe.call("_set_companion_state", 2) # FOLLOWING
	var largest_cane_flex := 0.0
	var largest_forearm_step := 0.0
	var previous_forearm := Vector3.ZERO
	for cycle_frame in 80:
		var delta := 1.0 / 60.0
		probe.velocity = Vector3(0.0, 0.0, 1.10)
		probe.position.z += 1.10 * delta
		probe.call("_advance_cane_gait", delta, 1.10)
		probe.call("_play_animation", "Cane_Walk")
		probe.call("_update_locomotion_playback", 1.10, 1.10)
		probe.call("_update_secondary_motion", delta)
		probe.call("_update_terrain_grounding", delta)
		await process_frame
		await process_frame
		var shoulder: Vector3 = probe.call(
			"_cane_chain_world_position", "upperarm.l")
		var elbow: Vector3 = probe.call(
			"_cane_chain_world_position", "lowerarm.l")
		var wrist: Vector3 = probe.call(
			"_cane_chain_world_position", "wrist.l")
		largest_cane_flex = maxf(largest_cane_flex,
			float(probe.call("get_cane_elbow_flex_degrees")))
		var forearm_direction := (wrist - elbow).normalized()
		if cycle_frame > 0:
			largest_forearm_step = maxf(largest_forearm_step,
				rad_to_deg(previous_forearm.angle_to(forearm_direction)))
		previous_forearm = forearm_direction
		_check(shoulder.distance_to(elbow) > 0.20,
			"the upper sleeve retains its connected bone length during recovery")
	_check(largest_cane_flex < 48.0,
		"the cane elbow stays below the former extreme recovery fold (%.2f)" \
			% largest_cane_flex)
	_check(largest_forearm_step < 7.0,
		"the cane forearm advances smoothly without a one-frame flip (%.2f)" \
			% largest_forearm_step)
	probe.queue_free()
	await process_frame
