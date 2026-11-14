extends Node3D


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
		"Wave_One_Hand": "Cheer",
	}
	for alias in aliases:
		var source: String = aliases[alias]
		if not library.has_animation(alias) and animation_player.has_animation(source):
			var clip := animation_player.get_animation(source).duplicate()
			if alias == "Idle_3":
				for track_index in range(clip.get_track_count() - 1, -1, -1):
					var path := str(clip.track_get_path(track_index)).to_lower()
					if path.contains("upperarm") or path.contains("lowerarm") \
							or path.contains("wrist") or path.contains("hand"):
						clip.remove_track(track_index)
			library.add_animation(alias, clip)
