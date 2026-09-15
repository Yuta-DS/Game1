extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var path := "/Users/davidsovann/S2603/milo-redesign/milo_redesign.glb"
	var error := doc.append_from_file(path, state)
	check(error == OK, "GLB imports")
	if error != OK:
		quit(1)
		return
	var model := doc.generate_scene(state)
	var milo := load("res://scenes/milo_animations.tscn").instantiate() as CharacterBody3D
	var skin := milo.get_node("Model")
	var original := skin.get_node("Model")
	skin.remove_child(original)
	original.free()
	model.name = "Model"
	skin.add_child(model)
	milo.set("gravity_enabled", false)
	root.add_child(milo)
	await process_frame
	milo.set_process(false)
	milo.set_physics_process(false)
	var skeleton := milo.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := milo.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(skeleton != null, "shared skeleton exists")
	check(player != null, "AnimationPlayer exists")
	if skeleton == null or player == null:
		quit(1)
		return
	for bone in ["head","chest","hand.l","hand.r","upperarm.l","lowerarm.l","upperarm.r","lowerarm.r","upperleg.l","lowerleg.l","foot.l","foot.r"]:
		check(skeleton.find_bone(bone) >= 0, "bone " + bone)
	for part in ["Sleeve_L","Sleeve_R","Paw_L","Paw_R","MayorCaneHook","MayorCaneGroundTip","MouthOpenSmall","MouthOpenWide","EyelidClosed_L","CompassNorth"]:
		check(milo.find_child(part, true, false) != null, "part " + part)
	for clip in ["Cane_Walk","Idle_3","Counsellor_Welcome","Milo_Redesign_Idle","Milo_Redesign_Welcome","Milo_Redesign_Listen"]:
		check(player.has_animation(clip), "clip " + clip)
	for side in ["L","R"]:
		var sleeve := milo.find_child("Sleeve_" + side, true, false) as MeshInstance3D
		check(sleeve != null and sleeve.skin != null, "AnyCreature sleeve is skinned: " + side)
		var paw := milo.find_child("Paw_" + side, true, false) as MeshInstance3D
		check(paw.mesh.get_blend_shape_count() == 1, "finger curl preserved " + side)
	# Test actual exported bone motion rather than clip-name presence alone.
	var hand := skeleton.find_bone("hand.r")
	var cane_hand := skeleton.find_bone("hand.l")
	player.play("Milo_Redesign_Welcome")
	player.seek(0, true)
	player.advance(0)
	var hand_start := skeleton.get_bone_global_pose(hand).origin
	var cane_start := skeleton.get_bone_global_pose(cane_hand).origin
	player.seek(player.get_animation("Milo_Redesign_Welcome").length * .5, true)
	player.advance(0)
	check(skeleton.get_bone_global_pose(hand).origin.distance_to(hand_start) > .10,
		"welcome gesture moves the free hand more than 10 cm")
	check(skeleton.get_bone_global_pose(cane_hand).origin.distance_to(cane_start) < .01,
		"welcome keeps cane hand fixed")
	player.play("Cane_Walk")
	player.seek(0, true)
	player.advance(0)
	var foot := skeleton.find_bone("foot.l")
	var start_foot := skeleton.get_bone_global_pose(foot).origin
	player.seek(player.get_animation("Cane_Walk").length*.4, true)
	player.advance(0)
	check(skeleton.get_bone_global_pose(foot).origin.distance_to(start_foot) > .04,
		"preserved walk moves the foot")
	milo.call("_set_mouth_shape", "wide")
	check(milo.call("get_mouth_shape") == "wide", "speech state switches")
	milo.call("_set_mouth_shape", "closed")
	milo.call("trigger_blink")
	milo.call("_update_eye_animation", .10)
	check(milo.call("get_blink_shape") != "relaxed", "blink state advances")
	print("MILO_REDESIGN_TEST: ", "PASS" if failures == 0 else "FAIL", " failures=", failures,
		" bones=", skeleton.get_bone_count(), " animations=", player.get_animation_list().size())
	milo.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
