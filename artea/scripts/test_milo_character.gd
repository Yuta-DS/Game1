extends SceneTree

const MiloScene := preload("res://scenes/characters/milo_scholar.tscn")
const MiloNPCScene := preload("res://scenes/milo_animations.tscn")
const HubPlayerScene := preload("res://scenes/entities/NewPlayer.tscn")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MILO_CHARACTER_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var milo := MiloScene.instantiate() as Node3D
	root.add_child(milo)
	await process_frame
	var meshes := milo.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() < 50:
		_fail("Milo must retain the measured part-by-part build, found %d mesh nodes" % meshes.size())
		return
	var shared_cast_skin := milo.get_node_or_null("Model")
	if shared_cast_skin == null or not shared_cast_skin.has_method("is_villager_lowpoly_skin"):
		_fail("Milo is no longer the measured villager-style asset")
		return
	if not shared_cast_skin.has_method("is_measured_target_skin"):
		_fail("Milo is not using the coordinate-measured target skin")
		return
	if not shared_cast_skin.has_method("is_market_cast_style"):
		_fail("Milo is not using the established Artéa market-character style")
		return
	var vertex_count := 0
	var surface_count := 0
	var materials_by_name := {}
	for mesh_node in meshes:
		var part_mesh := mesh_node as MeshInstance3D
		for surface_index in part_mesh.mesh.get_surface_count():
			vertex_count += part_mesh.mesh.surface_get_array_len(surface_index)
			surface_count += 1
			var surface_material := part_mesh.mesh.surface_get_material(surface_index)
			if surface_material != null:
				materials_by_name[surface_material.resource_name] = surface_material
	for required_part in ["Head", "ForeheadMark", "RearHairUpper",
			"RearHairMiddle", "RearHairLower",
			"EarOuter_L", "EarOuter_R", "EarInner_L", "EarInner_R",
			"EarInnerFold_L", "EarInnerFold_R",
			"CheekUpper_L", "CheekUpper_R", "CheekLower_L", "CheekLower_R",
			"FaceMask_L", "FaceMask_R",
			"EyeWhite_L", "EyeWhite_R", "Pupil_L", "Pupil_R",
			"IrisInner_L", "IrisInner_R", "EyeCatchlight_L", "EyeCatchlight_R",
			"EyelidRelaxed_L", "EyelidRelaxed_R",
			"EyelidHalf_L", "EyelidHalf_R",
			"EyelidClosed_L", "EyelidClosed_R",
			"BrowFrame_L", "BrowFrame_R",
			"GlassesRing_L", "GlassesRing_R", "GlassesBridge",
			"GlassesTemple_L", "GlassesTemple_R",
			"Muzzle_L", "Muzzle_R", "MoustachePad_L", "MoustachePad_R",
			"Nose", "Nostril_L", "Nostril_R", "MouthSocket", "Mouth",
			"MouthOpenSmall", "MouthOpenWide", "TongueSmall", "TongueWide",
			"CoatBody",
			"FrontCoatPanel_L", "FrontCoatPanel_R",
			"CoatLapel_L", "CoatLapel_R", "CoatDart_L", "CoatDart_R",
			"GoldLapelEdge_L", "GoldLapelEdge_R",
			"TealCoatLapelPiping_L", "TealCoatLapelPiping_R",
			"GoldCoatFrontEdge_L", "GoldCoatFrontEdge_R",
			"PocketFlap_L", "PocketFlap_R", "GoldPocketTrim_L", "GoldPocketTrim_R",
			"Waistcoat", "WaistcoatFacet_L", "WaistcoatFacet_R",
			"Collar_L", "Collar_R", "Tie", "GoldCoatHem360", "GoldTieClip",
			"BackWaistBelt",
			"BackBeltButton_L", "BackBeltButton_R",
			"RearCoatTail_L", "RearCoatTail_R",
			"SideCoatTail_L", "SideCoatTail_R",
			"GoldSideCoatTailEdge_L", "GoldSideCoatTailEdge_R",
			"BackVentEdge_L", "BackVentEdge_R",
			"CoatSideSeam_L", "CoatSideSeam_R",
			"FrontTailCenterSeam",
			"Sleeve_L", "Sleeve_R", "Cuff_L", "Cuff_R",
			"CuffAccent_L", "CuffAccent_R", "Paw_L", "Paw_R",
			"Trouser_L", "Trouser_R", "Boot_L", "Boot_R", "Sole_L", "Sole_R",
			"MayorCaneShaft", "MayorCaneLowerFerrule", "MayorCaneUpperCollar",
			"MayorCaneHook", "MayorCaneGroundTip"]:
		if milo.find_child(required_part, true, false) == null:
			_fail("measured Milo part is missing: %s" % required_part)
			return
	for removed_crease in ["PawCrease_1_L", "PawCrease_2_L",
			"PawCrease_1_R", "PawCrease_2_R", "CaneGripFingerUpper_R",
			"CaneGripFingerMiddle_R", "CaneGripFingerLower_R", "PawSideCrease_R",
			"PawToeLine_1_L", "PawToeLine_2_L",
			"PawToeLine_1_R", "PawToeLine_2_R",
			"PawThumb_L", "PawThumb_R",
			"PawFinger_1_L", "PawFinger_2_L", "PawFinger_3_L",
			"PawFinger_1_R", "PawFinger_2_R", "PawFinger_3_R",
			"TailStripeUpper"]:
		if milo.find_child(removed_crease, true, false) != null:
			_fail("Milo's paw still contains the scar line %s" % removed_crease)
			return
	for blueprint_excluded_part in ["Brow_L", "Brow_R", "BackYoke",
			"TealBackYokeEdge", "GoldBackYokeEdge",
			"GoldBackBeltEdgeTop", "GoldBackBeltEdgeBottom", "BackCenterSeam",
			"CrownFurCenter",
			"CrownFurMiddle_L", "CrownFurMiddle_R", "CrownFurLower_L",
			"CrownFurLower_R", "Tail", "TailTip"]:
		if milo.find_child(blueprint_excluded_part, true, false) != null:
			_fail("Milo contains the non-blueprint duplicate detail %s" \
					% blueprint_excluded_part)
			return
	# Blueprint-proportion regressions for the corrected hands, trousers and
	# attached side skirt. These checks protect silhouette, not mere node names.
	for paw_name in ["Paw_L", "Paw_R"]:
		var paw := milo.find_child(paw_name, true, false) as MeshInstance3D
		var paw_size := paw.get_aabb().size
		var paw_height := paw_size.y
		if paw_height < 0.17 or paw_height > 0.24:
			_fail("%s has lost its compact rounded hand proportion" % paw_name)
			return
		if paw_size.x < 0.22 or paw_size.x > 0.26:
			_fail("%s no longer has the broad mitten silhouette" % paw_name)
			return
		if paw_size.z < 0.16 or paw_size.z > 0.20:
			_fail("%s side profile is flat or box-like instead of domed" % paw_name)
			return
		if paw.mesh.get_blend_shape_count() != 1 \
				or paw.mesh.get_blend_shape_name(0) != "FingerCurl":
			_fail("%s is not one unified deformable hand object" % paw_name)
			return
	var paw_meshes := milo.find_children("Paw_*", "MeshInstance3D", true, false)
	if paw_meshes.size() != 2:
		_fail("Milo must contain exactly two unified paw objects, found %d" \
			% paw_meshes.size())
		return
	for trouser_name in ["Trouser_L", "Trouser_R"]:
		var trouser := milo.find_child(trouser_name, true, false) as MeshInstance3D
		if trouser.get_aabb().size.y < 0.26:
			_fail("%s no longer bridges the coat and boot" % trouser_name)
			return
	for tail_name in ["SideCoatTail_L", "SideCoatTail_R"]:
		var side_tail := milo.find_child(tail_name, true, false) as MeshInstance3D
		var tail_size := side_tail.get_aabb().size
		if tail_size.y < 0.50 or tail_size.z < 0.24:
			_fail("%s no longer forms the attached side-view coat flap" % tail_name)
			return
	# Facial-shape regression: both purple pupils must remain circular in the
	# front X/Z plane, and the tabby triangle must stay high on the crown.
	for pupil_name in ["Pupil_L", "Pupil_R"]:
		var pupil := milo.find_child(pupil_name, true, false) as MeshInstance3D
		var pupil_size := pupil.get_aabb().size
		if absf(pupil_size.x - pupil_size.y) > 0.008:
			_fail("%s must be circular, got X/Y %.4f/%.4f" \
					% [pupil_name, pupil_size.x, pupil_size.y])
			return
	var forehead_mark := milo.find_child("ForeheadMark", true, false) as MeshInstance3D
	if forehead_mark.get_aabb().get_center().y < 1.82:
		_fail("Milo's forehead triangle has slipped below the crown")
		return
	for ear_name in ["EarOuter_L", "EarOuter_R"]:
		var ear := milo.find_child(ear_name, true, false) as MeshInstance3D
		if ear.get_aabb().size.z < 0.14:
			_fail("%s has lost its natural rear cup" % ear_name)
			return
	# Godot duplicates boundary vertices across material surfaces. This range
	# keeps Milo near the established market-cast density while allowing his
	# separately inspectable mayor details. The six articulated finger meshes
	# add a small, deliberate allowance while keeping the same low-poly style.
	if vertex_count < 2500 or vertex_count > 18500:
		_fail("Milo polygon density is outside the low-poly NPC target: %d vertices" % vertex_count)
		return
	if surface_count < 20:
		_fail("Milo's suit and face material separation is missing")
		return
	for required_material in ["Artea Statue Warm Cream Fur",
			"Artea Statue Caramel Fur Marking",
			"Artea Milo Soft Rose Inner Ear", "Target Mayor Blue",
			"Target Mayor Lapel Blue", "Target Mayor Tailored Panel Blue",
			"Target Lavender", "Target Mint Piping", "Target Gold",
			"Artea Milo Purple Pupil"]:
		if not materials_by_name.has(required_material):
			_fail("Milo's PBR finish is missing %s; found %s" \
				% [required_material, materials_by_name.keys()])
			return
	var coat_material := materials_by_name["Target Mayor Blue"] as BaseMaterial3D
	var lapel_material := materials_by_name["Target Mayor Lapel Blue"] as BaseMaterial3D
	var panel_material := materials_by_name["Target Mayor Tailored Panel Blue"] as BaseMaterial3D
	var fur_material := materials_by_name["Artea Statue Warm Cream Fur"] as BaseMaterial3D
	var piping_material := materials_by_name["Target Mint Piping"] as BaseMaterial3D
	var gold_material := materials_by_name["Target Gold"] as BaseMaterial3D
	var pupil_material := materials_by_name["Artea Milo Purple Pupil"] as BaseMaterial3D
	if coat_material.roughness < 0.68 or fur_material.roughness < 0.40 \
			or fur_material.roughness > 0.52:
		_fail("Milo's coat must remain soft while the statue fur stays satin; got %.3f and %.3f" \
			% [coat_material.roughness, fur_material.roughness])
		return
	if gold_material.metallic < 0.55 or gold_material.roughness > 0.28:
		_fail("Milo's gold trim must retain a polished metallic response")
		return
	if pupil_material.roughness > 0.20:
		_fail("Milo's eyes must retain their readable polished highlight")
		return
	if lapel_material.albedo_color.get_luminance() \
			>= coat_material.albedo_color.get_luminance():
		_fail("Milo's lapels must remain darker than the main navy coat")
		return
	if panel_material.albedo_color.get_luminance() \
			<= coat_material.albedo_color.get_luminance():
		_fail("Milo's tailored panels must remain readable over the main coat")
		return
	if piping_material.albedo_color.g <= piping_material.albedo_color.r \
			or piping_material.albedo_color.b <= piping_material.albedo_color.r:
		_fail("Milo's lapel and rear-collar piping must retain its cyan accent")
		return
	var skeletons := milo.find_children("*", "Skeleton3D", true, false)
	var skeleton := skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	if skeleton == null or skeleton.get_bone_count() < 35:
		_fail("Milo's full-body villager animation skeleton is missing")
		return
	for required_bone in ["root", "chest", "head", "hips",
			"upperarm.l", "lowerarm.l", "wrist.l", "hand.l",
			"upperarm.r", "lowerarm.r", "wrist.r", "hand.r",
			"upperleg.l", "lowerleg.l", "foot.l",
			"upperleg.r", "lowerleg.r", "foot.r"]:
		if skeleton.find_bone(required_bone) < 0:
			_fail("Milo's blueprint rig chain is missing bone %s" % required_bone)
			return
	var animation_players := milo.find_children("*", "AnimationPlayer", true, false)
	var animations := animation_players[0] as AnimationPlayer if not animation_players.is_empty() else null
	if animations == null:
		_fail("AnimationPlayer is missing")
		return
	for clip in ["Idle", "Idle_3", "Wave_One_Hand", "Walk", "Walking", "Cane_Walk",
			"Run", "Running", "Counsellor_Welcome", "Counsellor_Guide",
			"Counsellor_Map", "Counsellor_Tablet", "Counsellor_Encourage",
			"Counsellor_Heart"]:
		if not animations.has_animation(clip):
			_fail("required %s animation is missing" % clip)
			return
	for planted_clip in ["Cane_Walk"]:
		var planted_animation := animations.get_animation(planted_clip)
		for track_index in planted_animation.get_track_count():
			var track_path := str(planted_animation.track_get_path(track_index)).to_lower()
			if track_path.contains("upperarm.l") or track_path.contains("lowerarm.l") \
					or track_path.contains("wrist.l") or track_path.contains("hand.l"):
				_fail("%s must keep the gripping arm planted, but contains %s" \
					% [planted_clip, track_path])
				return
	for counsellor_clip in ["Counsellor_Welcome", "Counsellor_Guide",
			"Counsellor_Map", "Counsellor_Tablet", "Counsellor_Encourage",
			"Counsellor_Heart"]:
		var counsellor_animation := animations.get_animation(counsellor_clip)
		for track_index in counsellor_animation.get_track_count():
			var track_path := str(counsellor_animation.track_get_path(track_index)).to_lower()
			if track_path.contains("upperarm") or track_path.contains("lowerarm") \
					or track_path.contains("wrist") or track_path.contains("hand"):
				_fail("%s must use Milo's connected FK pose, but contains %s" \
					% [counsellor_clip, track_path])
				return
	var npc := MiloNPCScene.instantiate() as Node3D
	if not npc is CharacterBody3D:
		_fail("Milo is not a walking town NPC CharacterBody3D")
		return
	var npc_cast_skin := npc.get_node_or_null("Model")
	if npc_cast_skin == null or not npc_cast_skin.has_method("is_villager_lowpoly_skin"):
		_fail("interactive Milo NPC does not use the shared villager cast asset")
		return
	if npc.get_node_or_null("Area3D/CollisionShape3D") == null:
		_fail("interactive Milo NPC lost its interaction area")
		return
	var name_label := npc.get_node_or_null("MayorMiloName") as Label3D
	if name_label == null or name_label.text != "Mayor Milo":
		_fail("visible Mayor Milo name marker is missing")
		return
	if not is_equal_approx(npc.scale.x, 1.0):
		_fail("reusable Cat Mayor Milo scene must stay at native villager scale")
		return
	if float(npc.get("walk_speed")) <= 0.0 \
			or float(npc.get("follow_stop_distance")) >= float(npc.get("follow_start_distance")):
		_fail("Milo's companion following distances are invalid")
		return
	var plant_sample: Dictionary = npc.call("_sample_cane_gait", 0.05)
	var support_sample: Dictionary = npc.call("_sample_cane_gait", 0.50)
	var recover_sample: Dictionary = npc.call("_sample_cane_gait", 0.90)
	if plant_sample.state != "plant" or support_sample.state != "support" \
			or recover_sample.state != "recover":
		_fail("cane locomotion lost its plant/support/recover gait states")
		return
	if float(support_sample.speed) <= float(plant_sample.speed) \
			or float(support_sample.speed) <= float(recover_sample.speed):
		_fail("Milo must step fastest during cane support, not during plant or recovery")
		return
	var dummy_player := CharacterBody3D.new()
	dummy_player.name = "NewPlayer"
	root.add_child(dummy_player)
	npc.position = Vector3.ZERO
	npc.set("gravity_enabled", false)
	root.add_child(npc)
	await process_frame
	npc.call("set_companion_player", dummy_player, false)
	var pose_props := npc.find_child("CounsellorPoseProps", true, false) as Node3D
	var map_prop := npc.find_child("CounsellorMap", true, false) as Node3D
	var tablet_prop := npc.find_child("CounsellorTablet", true, false) as Node3D
	var sparkles := npc.find_child("CounsellorSparkles", true, false) as Node3D
	var cane := npc.find_child("MayorCaneShaft", true, false) as Node3D
	if pose_props == null or map_prop == null or tablet_prop == null \
			or sparkles == null or cane == null:
		_fail("Milo's counsellor pose props are incomplete")
		return
	npc.call("_on_companion_pose_requested", "map")
	if map_prop.visible or tablet_prop.visible or cane.visible:
		_fail("solid props and cane must remain hidden while the paws are moving")
		return
	await create_timer(0.18).timeout
	var npc_skeleton := npc.find_child("Skeleton3D", true, false) as Skeleton3D
	var moving_hand_l := npc_skeleton.get_bone_global_pose(
		npc_skeleton.find_bone("hand.l")).origin
	var moving_hand_r := npc_skeleton.get_bone_global_pose(
		npc_skeleton.find_bone("hand.r")).origin
	if moving_hand_l.z < 0.15 or moving_hand_r.z < 0.15:
		_fail("moving paws must arc in front of Milo instead of crossing his coat")
		return
	await create_timer(0.24).timeout
	if not map_prop.visible or tablet_prop.visible or cane.visible:
		_fail("map-reading pose must show only the map after both paws settle")
		return
	var map_hand_l := npc_skeleton.get_bone_global_pose(
		npc_skeleton.find_bone("hand.l")).origin
	var map_hand_r := npc_skeleton.get_bone_global_pose(
		npc_skeleton.find_bone("hand.r")).origin
	if map_hand_l.distance_to(Vector3(0.42, 1.05, 0.487)) > 0.01 \
			or map_hand_r.distance_to(Vector3(-0.42, 1.05, 0.487)) > 0.01:
		_fail("both map paws must stay connected to the measured prop edges: %s / %s" \
			% [map_hand_l, map_hand_r])
		return
	var map_grip_l := npc_skeleton.get_bone_global_pose(
		npc_skeleton.find_bone("hand.l")).basis.y.normalized()
	var map_grip_r := npc_skeleton.get_bone_global_pose(
		npc_skeleton.find_bone("hand.r")).basis.y.normalized()
	if map_grip_l.x > -0.65 or map_grip_r.x < 0.65:
		_fail("map paws must wrap inward from the cuffs, got %s and %s" \
			% [map_grip_l, map_grip_r])
		return
	if map_hand_l.z - 0.105 <= 0.376 or map_hand_r.z - 0.105 <= 0.376:
		_fail("map paws penetrate the front surface of the paper")
		return
	npc.call("_on_companion_pose_requested", "tablet")
	await create_timer(0.42).timeout
	if map_prop.visible or not tablet_prop.visible or cane.visible:
		_fail("tablet pose must show only the glowing reflection tablet")
		return
	npc.call("_on_companion_pose_requested", "welcome")
	await create_timer(0.42).timeout
	if map_prop.visible or tablet_prop.visible or not cane.visible:
		_fail("welcome pose must restore Milo's planted walking cane")
		return
	npc.call("_on_companion_pose_requested", "heart")
	await create_timer(0.42).timeout
	var heart_hand := npc_skeleton.get_bone_global_pose(
		npc_skeleton.find_bone("hand.r")).origin
	if heart_hand.distance_to(Vector3(-0.16, 1.20, 0.405)) > 0.01:
		_fail("heart pose paw must contact the front of Milo's waistcoat")
		return
	if heart_hand.z - 0.105 <= 0.29:
		_fail("heart pose paw penetrates Milo's coat")
		return
	npc.position = Vector3(-6.0, 0.0, 0.0)
	var walk_start := npc.position
	npc.call("_begin_pause")
	for _frame in 36:
		await physics_frame
	var horizontal_distance := Vector2(npc.position.x - walk_start.x,
		npc.position.z - walk_start.z).length()
	if horizontal_distance < 0.08:
		_fail("Milo did not physically walk toward his player companion")
		return
	var npc_animation := npc.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if npc_animation == null or npc_animation.current_animation != "Cane_Walk":
		_fail("walking Milo is not using the synchronized Cane_Walk clip")
		return
	if str(npc.call("get_cane_gait_state")).is_empty():
		_fail("walking Milo does not expose an active cane gait state")
		return
	npc.queue_free()
	dummy_player.queue_free()
	await process_frame

	var hub_player := HubPlayerScene.instantiate() as CharacterBody3D
	root.add_child(hub_player)
	await process_frame
	if hub_player.find_child("ProfessorTie", true, false) != null:
		_fail("live hub player was incorrectly replaced by Milo")
		return
	if hub_player.get_node_or_null("RogueSkin/AnimationPlayer") == null:
		_fail("existing fox player locomotion visuals are missing")
		return

	var hub_text := FileAccess.get_file_as_string("res://scenes/New_Hub_World.tscn")
	if not hub_text.contains("Milo_Animations2") or not hub_text.contains("res://scenes/milo_animations.tscn"):
		_fail("production Milo NPC is not placed in the live hub")
		return
	if not hub_text.contains("OriginalCatStatue") \
			or not hub_text.contains("res://meshy ai/Milo_Animations.glb"):
		_fail("the original cat statue is missing beside the Artéa sign")
		return
	if not ProjectSettings.has_setting("autoload/MiloCompanionManager"):
		_fail("live Milo companion lifecycle manager is not registered")
		return

	print("MILO_CHARACTER_TEST: PASS — approved target-matched Mayor Milo, shared villager rig, companion walk, counsellor poses, interaction, player unchanged")
	quit()
