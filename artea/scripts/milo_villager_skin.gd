extends Node3D

# The exported model keeps every measured facial, clothing and body component
# as a separately named mesh while sharing the market-villager skeleton and
# animation library.

const NPC_WALK_SOURCE := preload("res://assets3D/characters/Rogue.glb")
const NPC_CANE_WALK_BONES := [
	"hips", "spine", "chest", "head",
	"upperleg.l", "lowerleg.l", "foot.l", "toes.l",
	"upperleg.r", "lowerleg.r", "foot.r", "toes.r",
	# Keep the complete baked arm timing used by the other humanoid characters.
	# Runtime IK only adjusts the cane-side shoulder/elbow enough to meet the prop.
	"upperarm.l", "lowerarm.l", "wrist.l",
	"upperarm.r", "lowerarm.r", "wrist.r", "hand.r",
]
const FREE_ARM_ROTATION_BONES := [
	"upperarm.r", "lowerarm.r", "hand.r",
]


func is_villager_lowpoly_skin() -> bool:
	return true


func is_measured_target_skin() -> bool:
	return true


func is_market_cast_style() -> bool:
	return true


func _ready() -> void:
	# The speaking shapes are exported as ordinary rigged meshes. They start
	# hidden everywhere; the live companion controller reveals them only while
	# Milo is presenting dialogue.
	var mouth_small := find_child("MouthOpenSmall", true, false) as GeometryInstance3D
	var mouth_wide := find_child("MouthOpenWide", true, false) as GeometryInstance3D
	var tongue_small := find_child("TongueSmall", true, false) as GeometryInstance3D
	var tongue_wide := find_child("TongueWide", true, false) as GeometryInstance3D
	if mouth_small != null:
		mouth_small.visible = false
	if mouth_wide != null:
		mouth_wide.visible = false
	if tongue_small != null:
		tongue_small.visible = false
	if tongue_wide != null:
		tongue_wide.visible = false
	# Relaxed upper lids remain visible at rest. The two deeper blink cards are
	# controlled by the live companion and must never stack in static previews.
	for side in ["L", "R"]:
		var half_lid := find_child("EyelidHalf_%s" % side, true, false) \
			as GeometryInstance3D
		var closed_lid := find_child("EyelidClosed_%s" % side, true, false) \
			as GeometryInstance3D
		if half_lid != null:
			half_lid.visible = false
		if closed_lid != null:
			closed_lid.visible = false
	var animation_player := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		return
	var library := animation_player.get_animation_library("")
	if library == null:
		return
	var aliases := {
		"Idle_3": "Idle",
		"Walk": "Walking_A",
		"Walking": "Walking_A",
		"Cane_Walk": "Milo_Walking",
		"Counsellor_Welcome": "Cheer",
		"Counsellor_Guide": "1H_Ranged_Aiming",
		"Counsellor_Map": "2H_Ranged_Aiming",
		"Counsellor_Tablet": "Use_Item",
		"Counsellor_Encourage": "Cheer",
		"Counsellor_Heart": "Interact",
		"Run": "Running_A",
		"Running": "Running_A",
		"Wave_One_Hand": "Cheer",
	}
	for alias in aliases:
		var source: String = aliases[alias]
		if not library.has_animation(alias) and animation_player.has_animation(source):
			var clip: Animation
			if alias == "Cane_Walk":
				clip = _build_milo_cane_walk(animation_player)
			else:
				clip = animation_player.get_animation(source).duplicate()
			if clip == null:
				continue
			if alias == "Idle_3":
				# The source warrior idle holds its forearms in front of the torso.
				# Milo's approved mayor pose keeps both sleeves relaxed at his sides.
				# All non-arm idle motion (breathing, head, coat and legs) remains.
				for track_index in range(clip.get_track_count() - 1, -1, -1):
					var path := str(clip.track_get_path(track_index)).to_lower()
					if path.contains("upperarm") or path.contains("lowerarm") \
							or path.contains("wrist") or path.contains("hand"):
						clip.remove_track(track_index)
			elif alias.begins_with("Counsellor_"):
				# Donor gestures are driven mostly by Blender IK controls, which do
				# not evaluate as constraints after glTF import. Preserve their head,
				# body and timing motion, then let milo_animations.gd pose the real
				# deforming arm chain directly for readable counsellor silhouettes.
				for track_index in range(clip.get_track_count() - 1, -1, -1):
					var path := str(clip.track_get_path(track_index)).to_lower()
					if path.contains("upperarm") or path.contains("lowerarm") \
							or path.contains("wrist") or path.contains("hand"):
						clip.remove_track(track_index)
			elif alias == "Cane_Walk":
				# Blender owns the complete gait, including stabilized head and weighted
				# torso motion. Runtime IK only preserves foot and cane contact.
				clip.loop_mode = Animation.LOOP_LINEAR
			library.add_animation(alias, clip)


func _build_milo_cane_walk(animation_player: AnimationPlayer) -> Animation:
	if not animation_player.has_animation("Milo_Walking"):
		return _build_npc_cane_walk()
	var clip := animation_player.get_animation("Milo_Walking").duplicate() as Animation
	for track_index in range(clip.get_track_count() - 1, -1, -1):
		var path_text := str(clip.track_get_path(track_index))
		var separator := path_text.rfind(":")
		var bone_name := path_text.substr(separator + 1) if separator >= 0 else ""
		if bone_name not in NPC_CANE_WALK_BONES:
			clip.remove_track(track_index)
			continue
		if clip.track_get_type(track_index) == Animation.TYPE_ROTATION_3D:
			# Blender exports a dense 24 fps pose bake. Shortest-path interpolation
			# gives smooth 60 fps playback without inventing overshoot between poses.
			clip.track_set_interpolation_type(track_index,
				Animation.INTERPOLATION_LINEAR_ANGLE)
			clip.track_set_interpolation_loop_wrap(track_index, true)
	clip.set_meta("milo_blender_authored_walk", true)
	clip.set_meta("milo_source_full_body_walk", true)
	clip.set_meta("milo_free_arm_cubic", false)
	return clip


func _build_npc_cane_walk() -> Animation:
	var source_model := NPC_WALK_SOURCE.instantiate()
	var source_player := source_model.find_child("AnimationPlayer", true, false) \
		as AnimationPlayer
	if source_player == null or not source_player.has_animation("Walking_A"):
		source_model.free()
		return null
	# Blender verification proves this cast rig has the same 41-bone rest axes as
	# Milo's source armature. Copy the body timing without editing local bone axes;
	# milo_animations.gd places the visible free arm with an anatomical IK arc.
	var clip := source_player.get_animation("Walking_A").duplicate() as Animation
	for track_index in range(clip.get_track_count() - 1, -1, -1):
		var path_text := str(clip.track_get_path(track_index))
		var separator := path_text.rfind(":")
		var bone_name := path_text.substr(separator + 1) if separator >= 0 else ""
		if bone_name not in NPC_CANE_WALK_BONES:
			clip.remove_track(track_index)
			continue
		clip.track_set_path(track_index, NodePath(path_text.replace(
			"Rig/Skeleton3D:", "MiloExactTargetRig/Skeleton3D:")))
		if bone_name in FREE_ARM_ROTATION_BONES \
				and clip.track_get_type(track_index) == Animation.TYPE_ROTATION_3D:
			# Preserve the NPC's authored contact/pass timing while smoothing only
			# the unconstrained arm. Shortest-path cubic interpolation removes the
			# visible corners between imported keys without affecting grounded legs.
			clip.track_set_interpolation_type(track_index,
				Animation.INTERPOLATION_CUBIC_ANGLE)
			clip.track_set_interpolation_loop_wrap(track_index, true)
	clip.set_meta("milo_source_full_body_walk", true)
	clip.set_meta("milo_free_arm_cubic", true)
	source_model.free()
	return clip
