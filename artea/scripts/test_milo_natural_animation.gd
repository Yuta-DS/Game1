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
	_check(cane_clip != null and cane_clip.get_track_count() >= 14,
		"Milo retargets the town NPC's baked torso and lower-body walk")
	if cane_clip != null:
		for track_index in cane_clip.get_track_count():
			_check(str(cane_clip.track_get_path(track_index)).begins_with(
				"MiloExactTargetRig/Skeleton3D:"),
				"retargeted NPC tracks address Milo's live skeleton")
	_check(milo.find_child("LegIK_L", true, false) is TwoBoneIK3D \
			and milo.find_child("LegIK_R", true, false) is TwoBoneIK3D,
		"deterministic two-bone constraints ground both legs after animation")
	_check(milo.find_child("CaneArmIK", true, false) is TwoBoneIK3D,
		"the cane hand follows the planted prop through its own arm constraint")
	milo.set("_cane_cycle_time", 0.25 * 1.28)
	_check(float(milo.call("get_foot_contact_weight", "l")) > 0.95 \
			and float(milo.call("get_foot_contact_weight", "r")) < 0.05,
		"the left stance foot owns the first supported half-stride")
	_check(float(milo.call("get_cane_contact_weight")) > 0.95,
		"the cane is planted with the contralateral left stance foot")
	milo.call("_reset_cane_gait")
	milo.call("_advance_cane_gait", 0.10, 1.40)
	_check(absf(float(milo.call("get_gait_phase")) - 0.10) < 0.002,
		"gait phase advances from real distance rather than an unrelated timer")

	for side in ["L", "R"]:
		for prefix in ["EyelidRelaxed", "EyelidHalf", "EyelidClosed",
				"Pupil", "IrisInner", "EyeCatchlight"]:
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
	milo.call("_set_companion_state", 2) # FOLLOWING
	milo.velocity = Vector3(1.0, 0.0, 0.0)
	milo.set("_cane_cycle_time", 0.29)
	locomotion_player.play("Cane_Walk")
	locomotion_player.seek(0.27, true)
	locomotion_player.advance(0.0)
	for _frame in 12:
		milo.call("_update_secondary_motion", 1.0 / 60.0)
		milo.call("_update_terrain_grounding", 1.0 / 60.0)
	var left_leg_ik := milo.find_child("LegIK_L", true, false) as TwoBoneIK3D
	var cane_arm_ik := milo.find_child("CaneArmIK", true, false) as TwoBoneIK3D
	_check(left_leg_ik != null and left_leg_ik.get_influence() > 0.5,
		"the planted stance leg is constrained to real floor geometry")
	_check(cane_arm_ik != null and cane_arm_ik.get_influence() > 0.5,
		"the cane hand stays constrained to its moving grip during support")
	var walk_offset: Vector3 = milo.call("get_secondary_motion_offset")
	var foot_offset: Vector3 = milo.call("get_left_foot_motion_offset")
	var left_thigh: Vector3 = milo.call("get_rig_bone_pose_angle", "upperleg.l")
	var right_thigh: Vector3 = milo.call("get_rig_bone_pose_angle", "upperleg.r")
	var left_knee: Vector3 = milo.call("get_rig_bone_pose_angle", "lowerleg.l")
	var right_knee: Vector3 = milo.call("get_rig_bone_pose_angle", "lowerleg.r")
	var cane_arm: Vector3 = milo.call("get_procedural_gait_angle", "upperarm.l")
	var free_arm: Vector3 = milo.call("get_procedural_gait_angle", "upperarm.r")
	_check(absf(walk_offset.x) > 0.002 and walk_offset.length() < 0.020,
		"walking transfers restrained body weight without exaggerated bobbing")
	_check(foot_offset.length() < 0.001,
		"skinned shoes stay attached to the rig instead of moving as whole meshes")
	_check(left_thigh.distance_to(right_thigh) > 8.0,
		"NPC leg curves retarget as an alternating stride on Milo")
	_check(maxf(left_knee.length(), right_knee.length()) > 8.0,
		"the NPC recovery curve folds one knee instead of leaving rigid legs")
	_check(absf(cane_arm.x) < absf(free_arm.x) * 0.65,
		"the cane arm stays supported while the free arm counter-swings")
	var walking_curls: Dictionary = milo.call("get_hand_curl_amounts")
	_check(float(walking_curls.get("Paw_R", 0.0)) > 0.65,
		"the visible cane paw keeps a secure whole-hand grip while walking")
	_check(float(walking_curls.get("Paw_L", 1.0)) < 0.35,
		"the free paw remains relaxed enough to counter-swing")

	milo.call("_set_companion_state", 1) # IDLE_NEAR_PLAYER
	milo.velocity = Vector3.ZERO
	for _frame in 90:
		milo.call("_update_secondary_motion", 1.0 / 60.0)
	var settled_offset: Vector3 = milo.call("get_secondary_motion_offset")
	var settled_foot: Vector3 = milo.call("get_left_foot_motion_offset")
	_check(absf(settled_offset.x) < 0.001 and absf(settled_offset.y) < 0.006,
		"body weight settles cleanly back into the breathing idle")
	_check(settled_foot.length() < 0.001,
		"both feet return to their authored planted pose after walking")

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
	print("MILO_NATURAL_ANIMATION_TEST: PASS — NPC-retargeted leg curves, cane-arm overlay, grounding, blink, focus, and smooth idle settling")
	quit()
