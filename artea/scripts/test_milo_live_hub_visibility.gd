extends SceneTree

const HubScene := preload("res://scenes/New_Hub_World.tscn")


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MILO_LIVE_HUB_VISIBILITY_TEST: %s" % message)
	quit(1)


func _run() -> void:
	var hub := HubScene.instantiate()
	root.add_child(hub)
	current_scene = hub
	await process_frame
	var milo := hub.get_node_or_null("Milo_Animations2") as CharacterBody3D
	var player := hub.get_node_or_null("NewPlayer") as CharacterBody3D
	var sign := hub.get_node_or_null("Artéa_Signpost_1027230400_texture") as Node3D
	var statue := hub.get_node_or_null("OriginalCatStatue") as Node3D
	if milo == null or player == null or sign == null or statue == null:
		_fail("live hub did not instantiate Milo, the sign, the statue, and the player")
		return
	var initial_position := milo.global_position
	for _frame in 180:
		await physics_frame
	var final_position := milo.global_position
	print("MILO_LIVE_HUB_TRACE: player=%s initial=%s final=%s visible=%s label=%s" % [
		player.global_position, initial_position, final_position,
		milo.is_visible_in_tree(), milo.get_node_or_null("MayorMiloName") != null])
	if not milo.is_visible_in_tree():
		_fail("Milo is hidden in the live hub")
		return
	if final_position.y < 18.0:
		_fail("Milo fell below the playable hub surface")
		return
	var companion_distance := Vector2(final_position.x - player.global_position.x,
		final_position.z - player.global_position.z).length()
	if companion_distance > 4.0 or companion_distance < 0.9:
		_fail("Milo is not keeping a comfortable companion distance from the player")
		return
	print("MILO_STATUE_TRACE: sign=%s statue=%s distance=%.2f descendants=%s" % [
		sign.global_position, statue.global_position,
		Vector2(statue.global_position.x - sign.global_position.x,
			statue.global_position.z - sign.global_position.z).length(),
		statue.find_children("*", "", true, false).map(func(node): return node.name)])
	if Vector2(statue.global_position.x - sign.global_position.x,
			statue.global_position.z - sign.global_position.z).length() > 12.0 \
			or statue.find_child("char1", true, false) == null:
		_fail("the original cat statue is not visibly restored beside the Artéa sign")
		return
	if absf(wrapf(statue.rotation_degrees.y, 0.0, 360.0) - 280.4) > 0.2:
		_fail("the original cat statue is not facing the requested opposite direction")
		return
	for mesh_node in statue.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var statue_material := mesh_instance.get_active_material(surface_index)
			if statue_material is BaseMaterial3D:
				var solid := statue_material as BaseMaterial3D
				if solid.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
						or solid.no_depth_test \
						or solid.cull_mode != BaseMaterial3D.CULL_BACK:
					_fail("the original cat statue still has a see-through surface")
					return
	var manager := root.get_node_or_null("MiloCompanionManager")
	if manager == null or manager.call("get_active_milo") != milo:
		_fail("the companion manager did not adopt the hub's authored Milo")
		return
	print("MILO_LIVE_HUB_VISIBILITY_TEST: PASS — live Milo accompanies the player and the original cat statue remains beside the sign")
	quit()
