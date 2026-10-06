extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MILO_GALAXY_FOX_SIZE_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate()
	root.add_child(gallery)
	current_scene = gallery
	var manager := root.get_node_or_null("MiloCompanionManager")
	if manager == null:
		_fail("companion manager is missing")
		return
	manager.call("refresh_companion")
	for _frame in 8:
		await process_frame
	var player := gallery.get_node_or_null("Player3D") as CharacterBody3D
	var milo := manager.call("get_active_milo") as CharacterBody3D
	var fox_visual := player.get_node_or_null("FoxVisuals/Fox") as Node3D \
		if player != null else null
	var milo_visual := milo.get_node_or_null("Model") as Node3D if milo != null else null
	if player == null or milo == null or fox_visual == null or milo_visual == null:
		_fail("live Galaxy fox or Milo visual is missing")
		return
	var fox_height := float(manager.call("_visual_height", player, fox_visual))
	var milo_height := float(manager.call("_visual_height", milo, milo_visual)) * milo.scale.y
	var ratio := milo_height / fox_height if fox_height > 0.001 else 0.0
	print("MILO_GALAXY_SIZE_TRACE: fox=%.4f milo=%.4f scale=%.4f ratio=%.4f" % [
		fox_height, milo_height, milo.scale.y, ratio])
	if absf(ratio - 0.88) > 0.005 or absf(milo.scale.y - 1.80) > 0.03:
		_fail("Milo does not use the fox idle-pose size match (ratio %.4f, scale %.4f)" \
			% [ratio, milo.scale.y])
		return
	if str(milo.get_meta("scene_scale_profile", "")) != \
			"art_galaxy_fox_perceived_height_match":
		_fail("Milo did not receive the Galaxy fox size profile")
		return
	print("MILO_GALAXY_FOX_SIZE_TEST: PASS — Milo matches the Galaxy fox's standing gameplay silhouette")
	quit()
