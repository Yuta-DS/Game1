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
	var milo := hub.get_node_or_null("Milo2Gameplay") as CharacterBody3D
	var player := hub.get_node_or_null("NewPlayer") as CharacterBody3D
	if milo == null or player == null:
		_fail("live hub did not instantiate finalized Milo 2 and the player")
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
	var interaction_shape := milo.get_node_or_null("Area3D/CollisionShape3D") \
		as CollisionShape3D
	print("MILO_LIVE_CHAT_RANGE_TRACE: shape=%s radius=%s" % [interaction_shape.shape,
		interaction_shape.shape.radius if interaction_shape != null \
		and interaction_shape.shape is SphereShape3D else "n/a"])
	var prompt := milo.get_node_or_null("InteractionPrompt") as Label3D
	var name_label := milo.get_node_or_null("MayorMiloName") as Label3D
	if interaction_shape == null or not interaction_shape.shape is SphereShape3D \
			or (interaction_shape.shape as SphereShape3D).radius < 4.0:
		_fail("live Milo's Q chat range does not cover his companion distance")
		return
	if prompt == null or name_label == null:
		_fail("live Milo does not expose the visible chat guidance")
		return
	milo._process(0.0)
	if not prompt.visible or not name_label.text.contains("Press Q to chat"):
		_fail("live Milo does not reveal Q chat guidance at companion distance")
		return
	if milo.process_priority >= 0:
		_fail("live Milo cannot win shared Q input over overlapping legacy NPCs")
		return
	if final_position.y < 18.0:
		_fail("Milo fell below the playable hub surface")
		return
	var companion_distance := Vector2(final_position.x - player.global_position.x,
		final_position.z - player.global_position.z).length()
	if companion_distance > 4.0 or companion_distance < 0.9:
		_fail("Milo is not keeping a comfortable companion distance from the player")
		return
	var manager := root.get_node_or_null("MiloCompanionManager")
	if manager == null or manager.call("get_active_milo") != milo:
		_fail("the companion manager did not adopt the hub's authored Milo")
		return
	print("MILO_LIVE_HUB_VISIBILITY_TEST: PASS — finalized Milo 2 is the only live Milo and accompanies the player")
	quit()
