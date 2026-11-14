extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery_mode := "--gallery" in OS.get_cmdline_user_args()
	var scene_path := "res://scenes/art_gallery_3d_inprogress.tscn" if gallery_mode \
		else "res://scenes/New_Hub_World.tscn"
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("LIVE_SOUND_AUDIT: hub scene failed to load")
		quit(1)
		return
	var hub := packed.instantiate() as Node3D
	# Scatter is unrelated to named object audio and makes a native diagnostic
	# wait for tens of thousands of placements. Remove only those generated roots
	# before the scene enters the tree; district/castle builders still run.
	for scatter_path in (["Environment/Grass", "Environment/Objects"] if not gallery_mode else []):
		var scatter := hub.get_node_or_null(scatter_path)
		if scatter != null:
			scatter.get_parent().remove_child(scatter)
			scatter.free()
	root.add_child(hub)
	current_scene = hub
	for _frame in 14:
		await process_frame

	var rows: Array[String] = []
	var director := root.get_node_or_null("WorldSpatialAudio")
	for candidate in hub.find_children("*", "Node3D", true, false):
		var node := candidate as Node3D
		var classified: StringName = director.call("classify_world_emitter", node)
		if classified == &"":
			continue
		var active_animation := false
		for animation_candidate in node.find_children("*", "AnimationPlayer", true, false):
			var animation_player := animation_candidate as AnimationPlayer
			if animation_player.is_playing():
				active_animation = true
				break
		var treatment := "emitter" if node.has_meta("spatial_world_emitter") \
			else String(node.get_meta("sound_audit_treatment", "covered_by_parent_or_silent"))
		rows.append("%s | profile=%s | animated=%s | treatment=%s | position=%s" % [
			node.get_path(), String(classified), str(active_animation), treatment,
			str(node.global_position)])
	rows.sort()
	for row in rows:
		print("LIVE_SOUND_OBJECT: %s" % row)
	print("LIVE_SOUND_AUDIT: %d classified object nodes inspected (emitters and intentional silence)" % rows.size())
	quit()
