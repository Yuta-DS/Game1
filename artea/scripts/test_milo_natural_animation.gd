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
	milo.set("_cane_cycle_time", 0.29)
	for _frame in 12:
		milo.call("_update_secondary_motion", 1.0 / 60.0)
	var walk_offset: Vector3 = milo.call("get_secondary_motion_offset")
	var foot_offset: Vector3 = milo.call("get_left_foot_motion_offset")
	_check(walk_offset.y > 0.008 and absf(walk_offset.x) > 0.003,
		"walking transfers body weight vertically and laterally")
	_check(walk_offset.length() < 0.035,
		"secondary gait polish stays restrained and cannot detach the feet")
	_check(foot_offset.y > 0.015 and absf(foot_offset.z) > 0.025,
		"the leading shoe has a visible lift and forward footfall")

	milo.call("_set_companion_state", 1) # IDLE_NEAR_PLAYER
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
	await process_frame
	if _failures > 0:
		push_error("MILO_NATURAL_ANIMATION_TEST: %d failure(s)" % _failures)
		quit(1)
		return
	print("MILO_NATURAL_ANIMATION_TEST: PASS — eyelids, blink, focus, grounding, stride weight, and smooth idle settling")
	quit()
