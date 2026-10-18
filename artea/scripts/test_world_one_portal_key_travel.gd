extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var gallery := (load("res://scenes/art_gallery_3d_inprogress.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(gallery)
	for _frame in 10:
		await process_frame
	var floating_world := gallery.get_node("ArtCastleFloatingWorld") as Node3D
	var world := floating_world.get_node("MindSparkWorldOne") as MindSparkWorldOne
	var player := gallery.get_node("Player3D") as CharacterBody3D
	player.set_physics_process(false)
	var safe_return := floating_world.to_global(Vector3(-650, 7, 1575))
	var trips := [
		[floating_world.get_node("MindSparkWorldGate") as MindSparkWorldGate,
			floating_world.to_global(world.position + world.get_player_arrival_local())],
		[world.get_node("WorldOneGeometry/01WorldGateLanding/EntryWorldGate") as MindSparkWorldGate,
			safe_return],
		[world.get_node("WorldOneGeometry/06OldestTreeSanctuary/ReturnToArtCastleWorldGate") as MindSparkWorldGate,
			safe_return],
	]
	for trip in trips:
		var portal := trip[0] as MindSparkWorldGate
		var expected := trip[1] as Vector3
		player.global_position = portal.global_position + Vector3.UP * 1.5
		player.velocity = Vector3.ZERO
		for _frame in 4:
			await physics_frame
		if portal.get("_player_inside") != player or not portal.get_node("Prompt").visible:
			_fail("player did not enter %s trigger" % portal.name)
			return
		var q := InputEventKey.new()
		q.keycode = KEY_Q
		q.physical_keycode = KEY_Q
		q.pressed = true
		Input.parse_input_event(q)
		for _frame in 4:
			await physics_frame
		q.pressed = false
		Input.parse_input_event(q)
		if player.global_position.distance_to(expected) > 0.05:
			_fail("Q did not travel through %s; player=%s expected=%s" % [
				portal.name, player.global_position, expected])
			return
	print("WORLD_ONE_PORTAL_KEY_TRAVEL: PASS — production player entered all three triggers and Q activated each portal")
	gallery.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error("WORLD_ONE_PORTAL_KEY_TRAVEL: %s" % message)
	quit(1)
