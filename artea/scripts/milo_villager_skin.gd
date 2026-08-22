extends Node3D

# The exported model keeps every measured facial, clothing and body component
# as a separately named mesh while sharing the market-villager skeleton and
# animation library.


func is_villager_lowpoly_skin() -> bool:
	return true


func is_measured_target_skin() -> bool:
	return true


func is_market_cast_style() -> bool:
	return true


func _ready() -> void:
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
		"Cane_Walk": "Walking_A",
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
			var clip := animation_player.get_animation(source).duplicate()
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
				# Keep the walking legs, hips, coat motion and free left-arm swing,
				# but hold the right paw around the cane. In this donor rig the visual
				# right arm uses .l.
				for track_index in range(clip.get_track_count() - 1, -1, -1):
					var path := str(clip.track_get_path(track_index)).to_lower()
					if path.contains("upperarm.l") or path.contains("lowerarm.l") \
							or path.contains("wrist.l") or path.contains("hand.l"):
						clip.remove_track(track_index)
			library.add_animation(alias, clip)
