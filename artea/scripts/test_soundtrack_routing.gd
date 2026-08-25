extends SceneTree


func _init() -> void:
	var manager_script := load("res://scripts/music_manager.gd") as Script
	var manager: Node = manager_script.new() as Node
	var routes: Dictionary = manager.get("scene_to_track")
	if not routes.has("res://scenes/art_gallery_3d_inprogress.tscn"):
		push_error("SOUNDTRACK_ROUTING_TEST: active gallery has no soundtrack route")
		quit(1)
		return
	if routes.has("res://scenes/ArtGallery.tscn"):
		push_error("SOUNDTRACK_ROUTING_TEST: obsolete gallery still owns the active route")
		quit(1)
		return
	var cloud_scene_text := FileAccess.get_file_as_string("res://scenes/cloud_pop_ui.tscn")
	if not cloud_scene_text.contains("[node name=\"BGmusic\"") \
			or cloud_scene_text.contains("autoplay = true"):
		push_error("SOUNDTRACK_ROUTING_TEST: Cloud Pop would duplicate the global Peace soundtrack")
		quit(1)
		return
	print("SOUNDTRACK_ROUTING_TEST: PASS — active gallery is mapped and Cloud Pop has one music owner")
	quit()
