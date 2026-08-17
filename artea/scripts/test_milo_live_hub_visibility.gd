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
	if Vector2(final_position.x - sign.global_position.x,
			final_position.z - sign.global_position.z).length() > 10.0:
		_fail("Milo is not stationed beside the Artéa sign")
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
	if Vector2(final_position.x - player.global_position.x,
			final_position.z - player.global_position.z).length() < 50.0:
		_fail("Milo is still waiting near the player spawn")
		return
	print("MILO_LIVE_HUB_VISIBILITY_TEST: PASS — Milo and original cat statue are beside the Artéa sign")
	quit()
