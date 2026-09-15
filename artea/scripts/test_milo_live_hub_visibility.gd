extends SceneTree

const HUB_SCENE_PATH := "res://scenes/New_Hub_World.tscn"


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("MILO_LIVE_HUB_VISIBILITY_TEST: %s" % message)
	quit(1)


func _visual_height(character: Node3D, visual_root: Node3D) -> float:
	var combined := AABB()
	var has_bounds := false
	for node in visual_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var root_local := character.global_transform.affine_inverse() \
			* mesh_instance.global_transform
		var bounds := root_local * mesh_instance.get_aabb()
		combined = combined.merge(bounds) if has_bounds else bounds
		has_bounds = true
	return combined.size.y if has_bounds else 0.0


func _run() -> void:
	var hub := (load(HUB_SCENE_PATH) as PackedScene).instantiate()
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
	var milo_model := milo.get_node_or_null("Model") as Node3D
	var player_model := player.get_node_or_null("RogueSkin") as Node3D
	if milo_model == null or player_model == null:
		_fail("live Milo or player visual root is missing")
		return
	var milo_height := _visual_height(milo, milo_model)
	var player_height := _visual_height(player, player_model)
	var height_ratio := milo_height / player_height if player_height > 0.0 else 0.0
	print("MILO_LIVE_SIZE_TRACE: milo=%0.3f player=%0.3f ratio=%0.3f" % [
		milo_height, player_height, height_ratio])
	if height_ratio < 0.95 or height_ratio > 1.05:
		_fail("Milo is not normalized to the playable character's visual height")
		return
	var body_shape := milo.get_node_or_null("CollisionShape3D") \
		as CollisionShape3D
	if body_shape == null or not body_shape.shape is CapsuleShape3D \
			or absf((body_shape.shape as CapsuleShape3D).height - 2.0) > 0.001:
		_fail("Milo's body collision does not match the normalized cast scale")
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
		_fail("live Milo's T chat range does not cover his companion distance")
		return
	if prompt == null or name_label == null:
		_fail("live Milo does not expose the visible chat guidance")
		return
	milo._process(0.0)
	if prompt.visible or not name_label.text.contains("Press T to chat"):
		_fail("live Milo does not expose one clean T chat guidance label")
		return
	if milo.process_priority >= 0:
		_fail("live Milo cannot prioritize his dedicated talk input")
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
	hub.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit()
